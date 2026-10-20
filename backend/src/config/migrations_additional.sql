-- ============================================================
-- File: backend/src/config/migrations_additional.sql
-- Fungsi: Tabel tambahan yang belum ada di migrations.sql utama
-- Cara pakai: Jalankan di Supabase SQL Editor SETELAH migrations.sql
-- ============================================================

-- ==================== TABEL: exchange_rates ====================
-- Cache kurs mata uang dari API eksternal (Frankfurter)
-- FR-24: kurs diambil dari API eksternal, dengan cadangan kurs terakhir di database
CREATE TABLE IF NOT EXISTS exchange_rates (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  currency    VARCHAR(10) NOT NULL,   -- 'USD', 'SGD', 'EUR', 'SAR'
  rate_to_idr NUMERIC(20,6) NOT NULL, -- 1 unit mata uang = X IDR
  fetched_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exchange_rates_currency ON exchange_rates(currency, fetched_at DESC);

-- Data kurs cadangan statis (fallback jika API gagal)
-- FR-24: cadangan kurs terakhir di database
INSERT INTO exchange_rates (currency, rate_to_idr, fetched_at) VALUES
  ('USD', 16000.000000, NOW()),
  ('SGD', 12000.000000, NOW()),
  ('EUR', 17000.000000, NOW()),
  ('SAR',  4300.000000, NOW())
ON CONFLICT DO NOTHING;


-- ==================== TABEL: certificates ====================
-- Sertifikat orang tua asuh dengan kode verifikasi
-- FR-29: Sertifikat dengan kode verifikasi dan QR berisi hash blok
-- FR-30: Sertifikat dapat diverifikasi publik
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


-- ==================== UPDATE: users tabel ====================
-- Tambah kolom phone_enc jika belum ada (FR-11: nomor HP dienkripsi AES-256 di SQLite)
-- Di PostgreSQL, phone boleh plain text (enkripsi AES hanya di SQLite/lokal)
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();


-- ==================== TRIGGER: update updated_at otomatis ====================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Pasang trigger ke tabel users
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ==================== VIEW: user_goodness_points ====================
-- View untuk menampilkan total poin kebaikan per user (badge di profil)
-- FR-48: Langkah dan skor dikonversi menjadi poin kebaikan
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


-- ==================== IOT: Device seed untuk demo ====================
-- Device dummy untuk demo simulasi Postman (FR-54)
-- device_key: 'demo_device_key_001' (sesuaikan di .env atau ganti saat production)
INSERT INTO iot_devices (id, orphanage_id, device_name, device_key) VALUES
  ('c0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000001',
   'Kotak Amal Al-Ikhlas #1',
   'demo_device_key_001')
ON CONFLICT DO NOTHING;
