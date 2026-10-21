-- V35: Ewacs Performance — tabel breakdown dari CSV import
-- KPI: Physical Availability, Ratio SCM vs USM

CREATE TABLE IF NOT EXISTS ewacs_breakdown (
  id              BIGSERIAL PRIMARY KEY,
  tanggal         DATE NOT NULL,
  crew           TEXT,
  cn             TEXT NOT NULL,           -- CN_1 unit code
  egi            TEXT,                    -- EGI_1 equipment model
  trouble_desc   TEXT,                    -- TroubleDescription_1
  shift          TEXT,
  kode           TEXT NOT NULL,           -- Kode_1: SCM/USM/TSM/TUM/ICM/ISM
  wo             TEXT,                    -- WO_1 work order
  lokasi         TEXT,                    -- Lokasi_1
  start_bd       TEXT,                    -- StartBD_1 "HH:MM"
  mekanik_datang TEXT,                    -- MekanikDatang_1
  rfu           TEXT,                     -- RFU_1 "HH:MM"
  operator_datang TEXT,                  -- Operatordatang_2
  durasi        NUMERIC(10,2) NOT NULL DEFAULT 0,  -- Durasi_2 dalam jam
  hm_start      NUMERIC(12,2),             -- HMStart_1
  hm_rfu_mek   NUMERIC(12,2),             -- HMRFUMek_1
  hm_rfu_opt   NUMERIC(12,2),             -- HMRFUOpt_1
  gl_plant     TEXT,                       -- GLPlant_1
  mekanik      TEXT,                       -- Mekanik_1
  action       TEXT,                       -- Action_1
  id_lastupdate TEXT,                      -- ID_lastupdate
  imported_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index untuk filter performa
CREATE INDEX IF NOT EXISTS idx_ewacs_tanggal ON ewacs_breakdown (tanggal);
CREATE INDEX IF NOT EXISTS idx_ewacs_cn ON ewacs_breakdown (cn);
CREATE INDEX IF NOT EXISTS idx_ewacs_egi ON ewacs_breakdown (egi);
CREATE INDEX IF NOT EXISTS idx_ewacs_crew ON ewacs_breakdown (crew);
CREATE INDEX IF NOT EXISTS idx_ewacs_kode ON ewacs_breakdown (kode);

-- Tambah menu 'ewacs' ke permission matrix
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs'
  ));

-- Seed default: admin full, inputer+mekanik+planner+group leader+adm te write-no-delete,
-- viewer+section head read-only
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','ewacs',TRUE,TRUE,TRUE,TRUE),
  ('inputer','ewacs',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','ewacs',TRUE,TRUE,TRUE,FALSE),
  ('viewer','ewacs',TRUE,FALSE,FALSE,FALSE),
  ('planner','ewacs',TRUE,TRUE,TRUE,FALSE),
  ('group leader','ewacs',TRUE,TRUE,TRUE,FALSE),
  ('section head','ewacs',TRUE,FALSE,FALSE,FALSE),
  ('adm te','ewacs',TRUE,TRUE,TRUE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;