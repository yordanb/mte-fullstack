-- V33: Tabel yazu (sync dari Google Sheets checklist inspeksi unit)
-- + menu permission "yazu" di group Technical Expert

-- ─── Tabel yazu ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS yazu (
  id              SERIAL PRIMARY KEY,
  waktu           TIMESTAMPTZ NOT NULL,
  id_unit         VARCHAR(50)  NOT NULL,
  nama            VARCHAR(255),
  nrp             VARCHAR(50),
  lokasi          VARCHAR(255),
  hm              BIGINT,
  layak_operasi   VARCHAR(10),
  user_field      VARCHAR(255),   -- kolom "USER" di sheet (reserved keyword)
  akurasi         INTEGER,
  link_lokasi     TEXT,
  coment          TEXT,
  engine_oil_level          VARCHAR(10),
  radiator_water_level      VARCHAR(10),
  fuel_level                VARCHAR(10),
  radiator_hose             VARCHAR(10),
  battery_level             VARCHAR(10),
  check_kebocoran           VARCHAR(10),
  main_breaker              VARCHAR(10),
  handle_tower              VARCHAR(10),
  cover_condition           VARCHAR(10),
  tower_condition           VARCHAR(10),
  lamp_condition            VARCHAR(255),
  kebersihan_unit           VARCHAR(10),
  noise_engine              VARCHAR(10),
  noise_generator           VARCHAR(10),
  jumlah_lamp_nyala         INTEGER,
  emergency_stop            VARCHAR(10),
  lock_out                  VARCHAR(10),
  apar                      VARCHAR(50),
  temuan_status             VARCHAR(50),    -- idx 30: "TEMUAN CLOSED" / kosong
  pic                       VARCHAR(255),   -- idx 31: PIC yang close temuan
  pic_nrp                   VARCHAR(50),    -- idx 32: NRP PIC
  action_comment            TEXT,
  synced_at                 TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(waktu, id_unit)
);

CREATE INDEX IF NOT EXISTS idx_yazu_waktu     ON yazu (waktu);
CREATE INDEX IF NOT EXISTS idx_yazu_unit      ON yazu (id_unit);
CREATE INDEX IF NOT EXISTS idx_yazu_unit_day  ON yazu (id_unit, (waktu::date));

-- Tabel log sync yazu (track kapan terakhir sync berhasil/gagal)
CREATE TABLE IF NOT EXISTS yazu_sync_log (
  id          SERIAL PRIMARY KEY,
  started_at  TIMESTAMPTZ DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status      VARCHAR(20),        -- success | error
  rows_total  INTEGER,
  rows_upserted INTEGER,
  error_msg   TEXT
);

-- ─── Menu permission ──────────────────────────────────────
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu'
  ));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','yazu',TRUE,TRUE,TRUE,TRUE),
  ('inputer','yazu',TRUE,FALSE,FALSE,FALSE),
  ('mekanik','yazu',TRUE,FALSE,FALSE,FALSE),
  ('viewer','yazu',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
