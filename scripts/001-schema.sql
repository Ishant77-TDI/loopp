-- =========================================================================
-- LOOP PLATFORM PRODUCTION DATA SCHEMAS (POSTGRESQL / SUPABASE CORE)
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. SYSTEM CUSTOM ENUMERATIONS (STATE SAFEGUARDS)
DO $$ BEGIN
  CREATE TYPE user_role_type AS ENUM ('admin', 'owner', 'user');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE neighborhood_type AS ENUM ('Dubai Marina', 'Downtown', 'JVC', 'Palm Jumeirah');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE verification_status_type AS ENUM ('pending_review', 'live', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE stay_horizon_type AS ENUM ('short_stay', 'fluid_living');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE point_ledger_type AS ENUM ('accrual_base', 'accrual_addon', 'redemption_discount');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE doc_kind_type AS ENUM ('passport', 'emirates_id', 'pml');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE doc_status_type AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. USERS TABLE (THE REWARDS WALLET INFRASTRUCTURE)
CREATE TABLE IF NOT EXISTS loop_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  role user_role_type NOT NULL DEFAULT 'user',
  wallet_credit_points INT DEFAULT 0 CHECK (wallet_credit_points >= 0),
  wallet_aed_value DECIMAL(10, 2) GENERATED ALWAYS AS (wallet_credit_points / 10.00) STORED,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. PROPERTIES TABLE (ASSET-LIGHT LANDLORD MANAGEMENT REGISTER)
CREATE TABLE IF NOT EXISTS properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES loop_users(id) ON DELETE CASCADE NOT NULL,
  title VARCHAR(255) NOT NULL,
  neighborhood neighborhood_type NOT NULL,
  target_revenue DECIMAL(10, 2) NOT NULL CHECK (target_revenue > 0),
  sira_lock_active BOOLEAN DEFAULT TRUE NOT NULL,
  pml_document_url TEXT NOT NULL,
  status verification_status_type DEFAULT 'pending_review' NOT NULL,
  image_url TEXT,
  bedrooms INT DEFAULT 1 NOT NULL,
  bathrooms INT DEFAULT 1 NOT NULL,
  sqft INT DEFAULT 800 NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. SUBSCRIPTIONS TABLE (THE AUTOMATED BILLING CORE & INVOICER)
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES loop_users(id) ON DELETE RESTRICT NOT NULL,
  property_id UUID REFERENCES properties(id) ON DELETE RESTRICT NOT NULL,
  duration_type stay_horizon_type NOT NULL,
  has_car_rental BOOLEAN DEFAULT FALSE NOT NULL,
  has_deep_cleaning BOOLEAN DEFAULT FALSE NOT NULL,
  has_gym_cowork_access BOOLEAN DEFAULT FALSE NOT NULL,
  base_price DECIMAL(10, 2) NOT NULL CHECK (base_price >= 0),
  addons_total DECIMAL(10, 2) GENERATED ALWAYS AS (
    (CASE WHEN has_car_rental THEN 2500.00 ELSE 0.00 END) +
    (CASE WHEN has_deep_cleaning THEN 400.00 ELSE 0.00 END) +
    (CASE WHEN has_gym_cowork_access THEN 600.00 ELSE 0.00 END)
  ) STORED,
  tourism_tax DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  points_redeemed INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  monthly_grand_total DECIMAL(10, 2) GENERATED ALWAYS AS (
    base_price +
    ((CASE WHEN has_car_rental THEN 2500.00 ELSE 0.00 END) +
     (CASE WHEN has_deep_cleaning THEN 400.00 ELSE 0.00 END) +
     (CASE WHEN has_gym_cowork_access THEN 600.00 ELSE 0.00 END)) +
    tourism_tax
  ) STORED,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. LOYALTY LEDGER TABLE (POINTS AUDIT TRAIL)
CREATE TABLE IF NOT EXISTS loyalty_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES loop_users(id) ON DELETE CASCADE NOT NULL,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  transaction_type point_ledger_type NOT NULL,
  points_amount INT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. SWAP HISTORY (FLUID LIVING SWAP ENGINE TIMELINE)
CREATE TABLE IF NOT EXISTS swap_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE NOT NULL,
  from_property_id UUID REFERENCES properties(id) NOT NULL,
  to_property_id UUID REFERENCES properties(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. VERIFICATION DOCUMENTS (ADMIN CONSOLE QUEUE)
CREATE TABLE IF NOT EXISTS verification_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES loop_users(id) ON DELETE CASCADE NOT NULL,
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  kind doc_kind_type NOT NULL,
  file_name TEXT NOT NULL,
  status doc_status_type NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. ADMIN 20% YIELD RECONCILIATION VIEW
CREATE OR REPLACE VIEW admin_revenue_dashboard AS
SELECT
  s.id AS subscription_id,
  s.created_at,
  s.duration_type,
  s.monthly_grand_total,
  s.tourism_tax AS compliance_escrow_allocation,
  (s.base_price * 0.20) AS platform_property_fee,
  s.addons_total AS platform_lifestyle_revenue,
  ((s.base_price * 0.20) + s.addons_total) AS total_loop_net_commission,
  (s.base_price * 0.80) AS landlord_payout_share
FROM subscriptions s
WHERE s.is_active = TRUE;

-- 9. CASHBACK AUTOMATION (1% BASE / 5% ADD-ONS, 10 POINTS = 1 AED)
CREATE OR REPLACE FUNCTION process_subscription_cashback()
RETURNS TRIGGER AS $$
DECLARE
  base_points INT;
  addon_points INT;
BEGIN
  base_points := FLOOR(NEW.base_price * 0.01 * 10);
  addon_points := FLOOR(NEW.addons_total * 0.05 * 10);

  IF base_points > 0 THEN
    INSERT INTO loyalty_ledger (user_id, subscription_id, transaction_type, points_amount)
    VALUES (NEW.user_id, NEW.id, 'accrual_base', base_points);
  END IF;

  IF addon_points > 0 THEN
    INSERT INTO loyalty_ledger (user_id, subscription_id, transaction_type, points_amount)
    VALUES (NEW.user_id, NEW.id, 'accrual_addon', addon_points);
  END IF;

  IF NEW.points_redeemed > 0 THEN
    INSERT INTO loyalty_ledger (user_id, subscription_id, transaction_type, points_amount)
    VALUES (NEW.user_id, NEW.id, 'redemption_discount', -NEW.points_redeemed);
  END IF;

  UPDATE loop_users
  SET wallet_credit_points = GREATEST(0, wallet_credit_points + base_points + addon_points - NEW.points_redeemed)
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subscription_cashback ON subscriptions;
CREATE TRIGGER trg_subscription_cashback
AFTER INSERT ON subscriptions
FOR EACH ROW EXECUTE FUNCTION process_subscription_cashback();
