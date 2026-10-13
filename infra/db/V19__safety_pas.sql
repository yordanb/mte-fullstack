-- V19 inspeksi safety 6 PAS (Google Form) + sync log + menu bomak.
CREATE TABLE IF NOT EXISTS safety_pas (
  id BIGSERIAL PRIMARY KEY,
  submitted_at TIMESTAMPTZ NOT NULL,
  pengawas_nama TEXT NULL,
  pengawas_nrp VARCHAR(50) NOT NULL DEFAULT '',
  mekanik_nama TEXT NULL,
  mekanik_nrp VARCHAR(50) NOT NULL DEFAULT '',
  grade TEXT NULL,
  section TEXT NULL,
  doc6pas_url TEXT NULL,
  doc6pas_file TEXT NULL,
  bisa6pas TEXT NULL,
  p1_doa TEXT NULL,
  p2_apd TEXT NULL,
  p2_stretch TEXT NULL,
  p3_housekeeping TEXT NULL,
  p3_doc TEXT NULL,
  p3_desc TEXT NULL,
  p4_alat TEXT NULL,
  p4_doc TEXT NULL,
  p4_desc TEXT NULL,
  p5_prosedur TEXT NULL,
  vlog_url TEXT NULL,
  vlog_file TEXT NULL,
  vlog_desc TEXT NULL,
  p6_tindakan TEXT NULL,
  p6_desc TEXT NULL,
  followup TEXT NULL,
  area_bomak TEXT NULL,
  job_desc TEXT NULL,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT safety_pas_unique UNIQUE (submitted_at, mekanik_nrp, pengawas_nrp)
);
CREATE INDEX IF NOT EXISTS idx_spas_submitted ON safety_pas (submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_spas_section ON safety_pas (section, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_spas_mekanik ON safety_pas (mekanik_nrp, submitted_at DESC);

CREATE TABLE IF NOT EXISTS safety_sync_log (
  id BIGSERIAL PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ NULL,
  fetched INT NOT NULL DEFAULT 0,
  ok_rows INT NOT NULL DEFAULT 0,
  fail_rows INT NOT NULL DEFAULT 0,
  synced_by VARCHAR(100) NULL
);

ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check CHECK (menu IN
  ('dashboard','dbr','performance','activity','timeline','equipment','fui','sugfui','fureport',
   'project','bomak','vessel','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','bomak',TRUE,TRUE,TRUE,TRUE),
  ('inputer','bomak',TRUE,TRUE,FALSE,FALSE),
  ('viewer','bomak',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
