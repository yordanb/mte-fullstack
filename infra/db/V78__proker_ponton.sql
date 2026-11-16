-- V78: Proker General Repair Ponton (EVERY YEAR) — program general repair
-- ponton tahunan.
--
-- Sumber Excel: "proker general repair ponton.xlsx", sheet
-- "09. GENERAL PONTON" — matriks unit x tahun. Header dua baris:
-- baris 2 = NO/UNIT MODEL/PRODUCT/UNIT TYPE/C/N/TYPE PONTON + label periode
-- tahun (merge 3 kolom: 2024, 2025, 2026) + blok tambahan
-- TYPE PONTON | KONDISI PONTON | ANODA ZINK (merge R2:T2) | REMARKS
-- (merge U2:U3), baris 3 = HM | DATE | MEKANIK per grup tahun dan
-- HM | DATE | STATUS untuk ANODA ZINK.
-- Kolom HM grup tahun bisa berisi teks "DONE" (tanpa HM) — dibaca status
-- DONE. Sel "#REF!" (formula rusak) dibaca NULL. ANODA ZINK disimpan sebagai
-- eksekusi terpisah dengan work_type "ANODA ZINK"; MEKANIK -> remark.
-- Tidak ada interval HM — program tahunan (judul file "EVERY YEAR").
--
-- Struktur & alur SAMA dengan modul proker lain: import menulis
-- proker_ponton_unit + proker_ponton_execution, upsert berbasis
-- (cn, period, work_type).
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V78__proker_ponton.sql

CREATE TABLE IF NOT EXISTS proker_ponton_unit (
  cn             VARCHAR(50) PRIMARY KEY,
  no             INTEGER,
  unit_model     VARCHAR(255),
  product        VARCHAR(255),
  unit_type      VARCHAR(255),
  type_ponton    VARCHAR(255),                  -- kolom F: model ponton (420E, DRAGER, ...)
  type_detail    VARCHAR(255),                  -- blok TYPE PONTON: "36 holes", "Skidding", ...
  kondisi        VARCHAR(255),                  -- blok KONDISI PONTON: "ok", "tipis 4 mm", ...
  remark         TEXT NULL,                     -- blok REMARKS
  hm_now         NUMERIC(12,2),
  import_id      VARCHAR(64),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS proker_ponton_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_ponton_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- "2024"/"2025"/"2026"/"ANODA ZINK"
  period_year   INTEGER,                        -- tahun dari label periode
  work_type     VARCHAR(100) NOT NULL,          -- "GENERAL REPAIR PONTON" / "ANODA ZINK"
  hm            NUMERIC(12,2) NULL,
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- MEKANIK
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_ponton_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_ponton_exec_cn_date
  ON proker_ponton_execution (cn, service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_ponton_exec_date
  ON proker_ponton_execution (service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_ponton_exec_status
  ON proker_ponton_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_ponton_exec_year
  ON proker_ponton_execution (period_year);
CREATE INDEX IF NOT EXISTS idx_proker_ponton_unit_model
  ON proker_ponton_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_ponton_unit_updated ON proker_ponton_unit;
CREATE TRIGGER trg_proker_ponton_unit_updated BEFORE UPDATE ON proker_ponton_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_ponton_execution_updated ON proker_ponton_execution;
CREATE TRIGGER trg_proker_ponton_execution_updated BEFORE UPDATE ON proker_ponton_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerponton" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V77) + 'prokerponton'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb',
    'prokerfandpompa','prokergmc','prokerfsbooster','prokerfsprimer',
    'prokerponton'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerponton', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerponton', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerponton');
