







CREATE EXTENSION IF NOT EXISTS "uuid-ossp";




CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  phone         VARCHAR(20),
  role          VARCHAR(20) NOT NULL DEFAULT 'donatur'
                CHECK (role IN ('donatur', 'admin_panti')),
  avatar_url    TEXT,
  biometric_enabled BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);





CREATE TABLE IF NOT EXISTS sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_hash    TEXT NOT NULL,
  device_info     TEXT,
  ip_address      INET,
  is_revoked      BOOLEAN DEFAULT FALSE,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_hash ON sessions(refresh_hash);




CREATE TABLE IF NOT EXISTS orphanages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        VARCHAR(150) NOT NULL,
  city        VARCHAR(100) NOT NULL,
  address     TEXT,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  phone       VARCHAR(20),
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS children (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  orphanage_id    UUID NOT NULL REFERENCES orphanages(id) ON DELETE CASCADE,
  alias           VARCHAR(100) NOT NULL,
  age             INTEGER NOT NULL,
  gender          CHAR(1) CHECK (gender IN ('L', 'P')),
  need_category   VARCHAR(50) NOT NULL,
  story_summary   TEXT,
  avatar          TEXT,
  status          VARCHAR(20) DEFAULT 'Tersedia'
                  CHECK (status IN ('Tersedia', 'Disponsori', 'Nonaktif')),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_children_orphanage ON children(orphanage_id);
CREATE INDEX IF NOT EXISTS idx_children_status ON children(status);




CREATE TABLE IF NOT EXISTS sponsorship_packages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category    VARCHAR(50) NOT NULL,
  name        VARCHAR(100) NOT NULL,
  amount_idr  BIGINT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS sponsorships (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id),
  child_id    UUID NOT NULL REFERENCES children(id),
  package_id  UUID NOT NULL REFERENCES sponsorship_packages(id),
  frequency   VARCHAR(20) DEFAULT 'monthly' CHECK (frequency IN ('once', 'monthly')),
  status      VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended')),
  started_at  TIMESTAMPTZ DEFAULT NOW(),
  ended_at    TIMESTAMPTZ
);


CREATE UNIQUE INDEX IF NOT EXISTS idx_sponsorship_unique_active
  ON sponsorships(user_id, child_id) WHERE status = 'active';




CREATE TABLE IF NOT EXISTS donations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sponsorship_id  UUID REFERENCES sponsorships(id),
  user_id         UUID NOT NULL REFERENCES users(id),
  amount_original NUMERIC(15,2) NOT NULL,
  currency        VARCHAR(10) NOT NULL DEFAULT 'IDR',
  rate_used       NUMERIC(20,6),
  amount_idr      NUMERIC(15,2) NOT NULL,
  source          VARCHAR(20) DEFAULT 'app' CHECK (source IN ('app', 'iot', 'offline')),
  local_id        TEXT UNIQUE,
  status          VARCHAR(20) DEFAULT 'completed',
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_donations_user ON donations(user_id);
CREATE INDEX IF NOT EXISTS idx_donations_local ON donations(local_id);





CREATE TABLE IF NOT EXISTS ledger_blocks (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  block_index  INTEGER NOT NULL UNIQUE,
  block_type   VARCHAR(30) NOT NULL,
  ref_id       UUID,
  payload_hash TEXT NOT NULL,
  prev_hash    TEXT NOT NULL,
  hash         TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS progress_reports (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_id     UUID NOT NULL REFERENCES children(id),
  period       VARCHAR(20) NOT NULL,
  summary      TEXT NOT NULL,
  evidence_url TEXT,
  ledger_ref   UUID REFERENCES ledger_blocks(id),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS letters (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES users(id),
  child_id     UUID NOT NULL REFERENCES children(id),
  content      TEXT NOT NULL,
  ai_generated BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS call_schedules (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sponsorship_id  UUID NOT NULL REFERENCES sponsorships(id),
  scheduled_at_utc TIMESTAMPTZ NOT NULL,
  donor_timezone  VARCHAR(50),
  status          VARCHAR(20) DEFAULT 'scheduled',
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS iot_devices (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  orphanage_id UUID NOT NULL REFERENCES orphanages(id),
  device_name  VARCHAR(100) NOT NULL,
  device_key   TEXT NOT NULL,
  is_active    BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS iot_events (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id    UUID NOT NULL REFERENCES iot_devices(id),
  amount_sim   BIGINT NOT NULL,
  ledger_ref   UUID REFERENCES ledger_blocks(id),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);




CREATE TABLE IF NOT EXISTS step_logs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id),
  log_date   DATE NOT NULL,
  steps      INTEGER DEFAULT 0,
  points     INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, log_date)
);




CREATE TABLE IF NOT EXISTS game_scores (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id),
  score      INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_scores_user ON game_scores(user_id);




CREATE TABLE IF NOT EXISTS feedback (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID REFERENCES users(id),
  suggestion TEXT,
  impression TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE feedback ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS user_email TEXT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS saran TEXT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS kesan TEXT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS rating INTEGER NOT NULL DEFAULT 5
  CHECK (rating BETWEEN 1 AND 5);
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Kuliah PAM';

CREATE INDEX IF NOT EXISTS idx_feedback_created_at
  ON feedback (created_at DESC);

UPDATE feedback
SET saran = COALESCE(saran, suggestion, ''),
    kesan = COALESCE(kesan, impression, '')
WHERE saran IS NULL OR kesan IS NULL;



CREATE TABLE IF NOT EXISTS push_tokens (
  token      TEXT PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);



INSERT INTO orphanages (id, name, city, address, latitude, longitude, phone, description) VALUES
  ('a0000001-0000-0000-0000-000000000001', 'Panti Asuhan Al-Ikhlas',      'Jakarta',   'Jl. Damai No. 12, Jakarta Selatan',  -6.2607, 106.8120, '021-111111', 'Panti asuhan yang berdiri sejak 1995'),
  ('a0000001-0000-0000-0000-000000000002', 'Panti Asuhan Cahaya Hati',   'Bandung',   'Jl. Merdeka No. 45, Bandung',        -6.9175, 107.6191, '022-222222', 'Panti asuhan dengan fokus pendidikan'),
  ('a0000001-0000-0000-0000-000000000003', 'Panti Asuhan Bunga Bangsa',  'Surabaya',  'Jl. Pahlawan No. 7, Surabaya',       -7.2575, 112.7521, '031-333333', 'Panti asuhan dengan 50 anak binaan'),
  ('a0000001-0000-0000-0000-000000000004', 'Panti Asuhan Tunas Muda',    'Yogyakarta','Jl. Gejayan No. 22, Yogyakarta',     -7.7669, 110.3806, '0274-44444', 'Fokus pada anak usia sekolah'),
  ('a0000001-0000-0000-0000-000000000005', 'Panti Asuhan Harapan Baru',  'Semarang',  'Jl. Pemuda No. 88, Semarang',        -6.9932, 110.4203, '024-555555', 'Panti asuhan aktif sejak 2005')
ON CONFLICT DO NOTHING;



INSERT INTO sponsorship_packages (id, category, name, amount_idr, description) VALUES
  ('b0000001-0000-0000-0000-000000000001', 'Pendidikan', 'Paket Buku & Alat Tulis',  150000, 'Memenuhi kebutuhan buku pelajaran dan perlengkapan sekolah'),
  ('b0000001-0000-0000-0000-000000000002', 'Pendidikan', 'Paket Seragam Sekolah',    250000, 'Seragam SD/SMP lengkap untuk satu tahun'),
  ('b0000001-0000-0000-0000-000000000003', 'Kesehatan',  'Paket Vitamin Bulanan',    100000, 'Suplemen vitamin untuk menjaga kesehatan anak'),
  ('b0000001-0000-0000-0000-000000000004', 'Kesehatan',  'Paket Pemeriksaan Dokter', 300000, 'Biaya kunjungan dokter dan obat-obatan'),
  ('b0000001-0000-0000-0000-000000000005', 'Gizi',       'Paket Makanan Bergizi',    200000, 'Memenuhi kebutuhan gizi sehari-hari selama satu bulan'),
  ('b0000001-0000-0000-0000-000000000006', 'Umum',       'Paket Kasih Sayang',       500000, 'Paket lengkap mencakup kebutuhan pendidikan, gizi, dan kesehatan')
ON CONFLICT DO NOTHING;



INSERT INTO children (orphanage_id, alias, age, gender, need_category, story_summary, avatar, status) VALUES
  ('a0000001-0000-0000-0000-000000000001', 'Bintang',  10, 'L', 'Pendidikan', 'Bintang adalah anak periang yang bercita-cita menjadi dokter.',  'avatar_bintang.png',  'Tersedia'),
  ('a0000001-0000-0000-0000-000000000001', 'Bulan',     8, 'P', 'Gizi',       'Bulan senang menggambar dan membutuhkan dukungan gizi yang baik.','avatar_bulan.png',    'Tersedia'),
  ('a0000001-0000-0000-0000-000000000002', 'Awan',     12, 'L', 'Kesehatan',  'Awan memiliki semangat belajar tinggi meski sering sakit.',       'avatar_awan.png',     'Tersedia'),
  ('a0000001-0000-0000-0000-000000000002', 'Mentari',   9, 'P', 'Pendidikan', 'Mentari ingin menjadi guru dan sangat rajin membaca buku.',       'avatar_mentari.png',  'Tersedia'),
  ('a0000001-0000-0000-0000-000000000003', 'Langit',   11, 'L', 'Umum',       'Langit suka bermain musik dan membutuhkan dukungan umum.',        'avatar_langit.png',   'Tersedia'),
  ('a0000001-0000-0000-0000-000000000003', 'Pelangi',   7, 'P', 'Gizi',       'Pelangi anak yang ceria dan membutuhkan asupan gizi yang cukup.', 'avatar_pelangi.png',  'Tersedia'),
  ('a0000001-0000-0000-0000-000000000004', 'Rizky',    13, 'L', 'Pendidikan', 'Rizky berprestasi di sekolah dan ingin melanjutkan ke SMA.',      'avatar_rizky.png',    'Tersedia'),
  ('a0000001-0000-0000-0000-000000000005', 'Sari',     10, 'P', 'Kesehatan',  'Sari membutuhkan dukungan biaya kesehatan rutin.',                'avatar_sari.png',     'Tersedia')
ON CONFLICT DO NOTHING;




INSERT INTO ledger_blocks (block_index, block_type, ref_id, payload_hash, prev_hash, hash) VALUES
  (0, 'GENESIS', NULL,
   '0000000000000000000000000000000000000000000000000000000000000000',
   '0',
   'GENESIS_ASUHKITA_2026_HASH_CHAIN_INITIALIZED'
  )
ON CONFLICT DO NOTHING;
