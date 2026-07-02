-- LOOP SEED DATA (dev bypass personas + live property inventory)

-- Dev bypass personas (fixed UUIDs referenced by the app's dev-login)
INSERT INTO loop_users (id, email, name, role, wallet_credit_points) VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin@loop.ae', 'Amira Al Rashid', 'admin', 0),
  ('00000000-0000-0000-0000-000000000002', 'owner@loop.ae', 'Khalid Mansoor', 'owner', 0),
  ('00000000-0000-0000-0000-000000000003', 'user@loop.ae', 'Sofia Laurent', 'user', 2500)
ON CONFLICT (id) DO NOTHING;

-- Secondary owner for inventory variety
INSERT INTO loop_users (id, email, name, role, wallet_credit_points) VALUES
  ('00000000-0000-0000-0000-000000000004', 'owner2@loop.ae', 'Fatima Haddad', 'owner', 0)
ON CONFLICT (id) DO NOTHING;

-- Live properties
INSERT INTO properties (id, owner_id, title, neighborhood, target_revenue, sira_lock_active, pml_document_url, status, image_url, bedrooms, bathrooms, sqft) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Marina Pinnacle Sky Loft', 'Dubai Marina', 12500, TRUE, '/docs/pml-marina-pinnacle.pdf', 'live', '/images/properties/marina-loft.png', 2, 2, 1450),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Burj Vista Signature Suite', 'Downtown', 18200, TRUE, '/docs/pml-burj-vista.pdf', 'live', '/images/properties/downtown-suite.png', 3, 3, 2100),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 'Palm Frond Beach Residence', 'Palm Jumeirah', 24000, TRUE, '/docs/pml-palm-frond.pdf', 'live', '/images/properties/palm-residence.png', 4, 4, 3200),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', 'JVC Serenity Garden Flat', 'JVC', 6800, TRUE, '/docs/pml-jvc-serenity.pdf', 'live', '/images/properties/jvc-flat.png', 1, 1, 850),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 'Marina Quays Waterfront Studio', 'Dubai Marina', 8400, TRUE, '/docs/pml-marina-quays.pdf', 'live', '/images/properties/marina-studio.png', 1, 1, 720),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000004', 'Opera District Penthouse', 'Downtown', 32000, TRUE, '/docs/pml-opera-penthouse.pdf', 'live', '/images/properties/opera-penthouse.png', 4, 5, 4100),
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000002', 'Palm West Beach Villa Wing', 'Palm Jumeirah', 28500, TRUE, '/docs/pml-palm-west.pdf', 'live', '/images/properties/palm-villa.png', 3, 4, 2900),
  ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000004', 'JVC Bloom Twin Terrace', 'JVC', 7900, TRUE, '/docs/pml-jvc-bloom.pdf', 'live', '/images/properties/jvc-terrace.png', 2, 2, 1100),
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000002', 'Marina Gate Horizon Duplex', 'Dubai Marina', 15800, FALSE, '/docs/pml-marina-gate.pdf', 'pending_review', '/images/properties/marina-duplex.png', 3, 3, 1900)
ON CONFLICT (id) DO NOTHING;

-- Pending verification documents for the admin console
INSERT INTO verification_documents (user_id, property_id, kind, file_name, status) VALUES
  ('00000000-0000-0000-0000-000000000003', NULL, 'passport', 'sofia-laurent-passport.pdf', 'pending'),
  ('00000000-0000-0000-0000-000000000003', NULL, 'emirates_id', 'sofia-laurent-eid.pdf', 'pending'),
  ('00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000009', 'pml', 'pml-marina-gate.pdf', 'pending')
ON CONFLICT DO NOTHING;

-- Existing active fluid-living subscription for the demo subscriber
INSERT INTO subscriptions (id, user_id, property_id, duration_type, has_car_rental, has_deep_cleaning, has_gym_cowork_access, base_price, tourism_tax) VALUES
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'fluid_living', FALSE, TRUE, TRUE, 12500, 0)
ON CONFLICT (id) DO NOTHING;
