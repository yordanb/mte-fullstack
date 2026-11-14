-- V71: Proker General Repair Exhaust Primer — program kerja general repair
-- exhaust primer (6.000 jam), grup menu Technical Expert.
--
-- Sumber Excel: "proker general repair exhaust primer.xlsx",
-- sheet "03. EXHAUST LINE" — matriks unit x (tahun x jenis pekerjaan).
-- Tiap grup (tahun, work_type) memakai 3 kolom berurutan:
--   HM | DATE | REMARKS   (2022: HM | DATE | MEKANIK)
--
-- Struktur & alur SAMA dengan Proker GMC Panel Booster (V65), hanya berbeda:
--   * kunci unik eksekusi memuat WORK TYPE ( Exhaust Manifold / Repair Muffler /
--     Thermoblanket / Tube As ) karena satu tahun bisa punya beberapa jenis
--     pekerjaan — upsert berbasis (cn, period, work_type)
--   * kolom ke-3 disimpan sebagai "remark" (isi bebas: nama mekanik atau
--     keterangan pekerjaan seperti REGASKET / REPLACE / INSTALL)
--   * interval 6.000 jam (judul sheet: GENERAL REPAIR EXHAUST PRIMER (6.000 H))
--
-- Import memecah matriks menjadi:
--   * proker_exhaust_unit      — identitas unit (cn, model, product, type, hm_now)
--   * proker_exhaust_execution — riwayat eksekusi (period, work_type, hm, tanggal, remark, status)
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V71__proker_exhaust.sql

CREATE TABLE IF NOT EXISTS proker_exhaust_unit (
  cn            VARCHAR(50) PRIMARY KEY,
  no            INTEGER,
  unit_model    VARCHAR(255),
  product       VARCHAR(255),
  unit_type     VARCHAR(255),
  hm_now        NUMERIC(12,2),                 -- HM sekarang (dari grup periode terakhir)
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS proker_exhaust_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_exhaust_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- label tahun dari header ("2022", "2023", ...)
  period_year   INTEGER,
  work_type     VARCHAR(100) NOT NULL,          -- jenis pekerjaan dari header baris 3
  hm            NUMERIC(12,2) NULL,             -- HM saat proker (NULL bila masih PLAN)
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- REMARKS / MEKANIK (isi bebas)
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',   -- DONE | PLAN | LATE | MISSED
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_exhaust_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_exhaust_exec_cn_date
  ON proker_exhaust_execution (cn, service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_exec_date
  ON proker_exhaust_execution (service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_exec_status
  ON proker_exhaust_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_exec_year
  ON proker_exhaust_execution (period_year, work_type);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_unit_model
  ON proker_exhaust_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_exhaust_unit_updated ON proker_exhaust_unit;
CREATE TRIGGER trg_proker_exhaust_unit_updated BEFORE UPDATE ON proker_exhaust_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_exhaust_execution_updated ON proker_exhaust_execution;
CREATE TRIGGER trg_proker_exhaust_execution_updated BEFORE UPDATE ON proker_exhaust_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerexhaust" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V70) + 'prokerexhaust'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerexhaust', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerexhaust', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerexhaust');
