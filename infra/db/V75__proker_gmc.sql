-- V75: Proker GMC Motor Booster (2.000 jam) — program kerja GMC (general
-- maintenance check) motor booster.
--
-- Sumber Excel: "proker gmc motor.xlsx", sheet "07. GMC MOTOR" — matriks
-- unit x tahun. Header tiga baris: baris 2 = NO/UNIT MODEL/PRODUCT/UNIT TYPE
-- PANEL/C/N + label periode tahun (merge 3 kolom: 2025, 2026), baris 3 =
-- HM | DATE | MEKANIK. Tidak ada kolom status: baris eksekusi ada bila
-- HM/DATE/MEKANIK terisi; status selalu DONE. MEKANIK (nama mekanik
-- pelaksana) disimpan di remark. Interval GMC 2.000 jam.
--
-- Struktur & alur SAMA dengan modul proker lain: import memecah matriks
-- menjadi proker_gmc_unit + proker_gmc_execution, upsert berbasis
-- (cn, period, work_type). work_type tetap "GMC MOTOR".
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V75__proker_gmc.sql

CREATE TABLE IF NOT EXISTS proker_gmc_unit (
  cn            VARCHAR(50) PRIMARY KEY,
  no            INTEGER,
  unit_model    VARCHAR(255),
  product       VARCHAR(255),
  unit_type     VARCHAR(255),
  hm_now        NUMERIC(12,2),
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS proker_gmc_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_gmc_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- "2025" / "2026"
  period_year   INTEGER,                        -- tahun dari label periode
  work_type     VARCHAR(100) NOT NULL DEFAULT 'GMC MOTOR',
  hm            NUMERIC(12,2) NULL,
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- MEKANIK (nama mekanik)
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_gmc_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_gmc_exec_cn_date
  ON proker_gmc_execution (cn, service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_gmc_exec_date
  ON proker_gmc_execution (service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_gmc_exec_status
  ON proker_gmc_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_gmc_exec_year
  ON proker_gmc_execution (period_year);
CREATE INDEX IF NOT EXISTS idx_proker_gmc_unit_model
  ON proker_gmc_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_gmc_unit_updated ON proker_gmc_unit;
CREATE TRIGGER trg_proker_gmc_unit_updated BEFORE UPDATE ON proker_gmc_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_gmc_execution_updated ON proker_gmc_execution;
CREATE TRIGGER trg_proker_gmc_execution_updated BEFORE UPDATE ON proker_gmc_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokergmc" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V74) + 'prokergmc'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb',
    'prokerfandpompa','prokergmc'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokergmc', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokergmc', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokergmc');
