








CREATE TABLE IF NOT EXISTS exchange_rates (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  currency    VARCHAR(10) NOT NULL,
  rate_to_idr NUMERIC(20,6) NOT NULL,
  fetched_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_currency ON exchange_rates(currency, fetched_at DESC);



INSERT INTO exchange_rates (currency, rate_to_idr, fetched_at) VALUES
  ('USD', 16000.000000, NOW()),
  ('SGD', 12000.000000, NOW()),
  ('EUR', 17000.000000, NOW()),
  ('SAR',  4300.000000, NOW())
ON CONFLICT DO NOTHING;






CREATE TABLE IF NOT EXISTS certificates (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sponsorship_id      UUID NOT NULL REFERENCES sponsorships(id),
  donor_id            UUID NOT NULL REFERENCES users(id),
  child_alias         VARCHAR(100) NOT NULL,
  orphanage_name      VARCHAR(150) NOT NULL,
  package_name        VARCHAR(100) NOT NULL,
  verification_code   VARCHAR(20) UNIQUE NOT NULL,
  ledger_block_id     UUID REFERENCES ledger_blocks(id),
  issued_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_certificates_code ON certificates(verification_code);
CREATE INDEX IF NOT EXISTS idx_certificates_donor ON certificates(donor_id);





ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();



CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';


DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();





CREATE OR REPLACE VIEW user_goodness_points AS
SELECT
  u.id AS user_id,
  u.name,
  COALESCE(step.step_points, 0) AS step_points,
  COALESCE(game.game_points, 0) AS game_points,
  COALESCE(step.step_points, 0) + COALESCE(game.game_points, 0) AS total_points
FROM users u
LEFT JOIN (
  SELECT user_id, SUM(points) AS step_points FROM step_logs GROUP BY user_id
) step ON u.id = step.user_id
LEFT JOIN (
  SELECT user_id, SUM(FLOOR(score / 10)) AS game_points FROM game_scores GROUP BY user_id
) game ON u.id = game.user_id;





INSERT INTO iot_devices (id, orphanage_id, device_name, device_key) VALUES
  ('c0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000001',
   'Kotak Amal Al-Ikhlas #1',
   'demo_device_key_001')
ON CONFLICT DO NOTHING;
