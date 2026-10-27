-- V40: Proker (program kerja pompa primer 2.000 hours).
-- Sumber: data sample excel/data program kerja/gmc pompa primer.xlsx, sheet "02. GMC".
-- Bentuk asli = matriks 49 unit x 11 periode (tiap periode 3 kolom: HM | DATE | MEKANIK).
-- Dipecah menjadi 2 tabel: master unit (model/product/type/cn) + riwayat eksekusi
-- (hm/tanggal/mekanik). Satu baris riwayat = satu unit pada satu periode.
-- Import bersifat UPSERT pada (cn, period): baris baru ditambah, baris lama diperbarui.

CREATE TABLE IF NOT EXISTS proker_unit (
  cn           VARCHAR(20) PRIMARY KEY,              -- nomor unit / C/N: WP405, WP1190, ...
  no           INT NULL,                             -- kolom NO pada sheet
  unit_model   TEXT NULL,                            -- WATER PRIMER / WATERFILL / ...
  product      TEXT NULL,                            -- MULTIFLO / DREDGER PUMP / KSB
  unit_type    TEXT NULL,                            -- MF-420E-C27 / RF-85MV C7.1 / ...
  hm_now       NUMERIC(12,2) NULL,                   -- HM NOW saat file dibuat
  aktif        BOOLEAN NOT NULL DEFAULT TRUE,
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS proker_execution (
  id           BIGSERIAL PRIMARY KEY,
  cn           VARCHAR(20) NOT NULL REFERENCES proker_unit(cn) ON DELETE CASCADE,
  period       TEXT NOT NULL,                        -- label asli sheet: '2025 - Pertama'
  period_year  SMALLINT NULL,                        -- 2025
  period_seq   SMALLINT NULL,                        -- Pertama=1, Kedua=2, Ketiga=3
  hm           NUMERIC(12,2) NULL,                   -- HM saat proker (NULL bila masih PLAN)
  service_date DATE NULL,                            -- kolom DATE
  mekanik      TEXT NULL,                            -- teks asli (nama tim / catatan)
  status       VARCHAR(8) NOT NULL DEFAULT 'DONE'
               CHECK (status IN ('DONE', 'PLAN', 'LATE', 'MISSED')),
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT proker_execution_uq UNIQUE (cn, period)
);

CREATE INDEX IF NOT EXISTS idx_proker_exec_cn_date ON proker_execution (cn, service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exec_date ON proker_execution (service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exec_status ON proker_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_exec_year ON proker_execution (period_year, period_seq);
CREATE INDEX IF NOT EXISTS idx_proker_unit_model ON proker_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_unit_updated ON proker_unit;
CREATE TRIGGER trg_proker_unit_updated BEFORE UPDATE ON proker_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_execution_updated ON proker_execution;
CREATE TRIGGER trg_proker_execution_updated BEFORE UPDATE ON proker_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "proker" di group Technical Expert (matriks izin halaman Users).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss','proker'
  ));

-- Seed default: admin penuh; inputer/mekanik/planner/adm te boleh input-ubah
-- (tanpa hapus); group leader/section head/viewer hanya melihat.
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','proker',TRUE,TRUE,TRUE,TRUE),
  ('inputer','proker',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','proker',TRUE,TRUE,TRUE,FALSE),
  ('planner','proker',TRUE,TRUE,TRUE,FALSE),
  ('adm te','proker',TRUE,TRUE,TRUE,FALSE),
  ('group leader','proker',TRUE,FALSE,FALSE,FALSE),
  ('section head','proker',TRUE,FALSE,FALSE,FALSE),
  ('viewer','proker',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
