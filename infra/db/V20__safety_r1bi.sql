-- V20 inspeksi R1BI (Google Form kedua) + kolom sumber di log sync.
CREATE TABLE IF NOT EXISTS safety_r1bi (
  id BIGSERIAL PRIMARY KEY,
  submitted_at TIMESTAMPTZ NOT NULL,
  tanggal DATE NULL,
  nama TEXT NULL,
  nrp VARCHAR(50) NOT NULL DEFAULT '',
  jabatan TEXT NULL,
  section TEXT NULL,
  grade TEXT NULL,
  staff_ribi TEXT NULL,
  aktivitas TEXT NULL,
  lokasi TEXT NULL,
  job_desc TEXT NULL,
  bahaya_desc TEXT NULL,
  pengendalian_desc TEXT NULL,
  tgl_ribi DATE NULL,
  foto_area_url TEXT NULL,
  foto_area_file TEXT NULL,
  foto_jsa_url TEXT NULL,
  foto_jsa_file TEXT NULL,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT safety_r1bi_unique UNIQUE (submitted_at, nrp, nama)
);
CREATE INDEX IF NOT EXISTS idx_r1bi_tanggal ON safety_r1bi (tanggal DESC);
CREATE INDEX IF NOT EXISTS idx_r1bi_section ON safety_r1bi (section, tanggal DESC);
CREATE INDEX IF NOT EXISTS idx_r1bi_submitted ON safety_r1bi (submitted_at DESC);

ALTER TABLE safety_sync_log ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'bomak';
