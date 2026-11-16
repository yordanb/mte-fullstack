-- V77: Proker Fire Suppression Primer — program pemasangan/pemeriksaan
-- fire suppression unit pompa primer.
--
-- Sumber Excel: "proker firesupression primer.xlsx", sheet
-- "10. FIRE SUPPRESSION" — format FLAT satu baris per unit:
-- baris 2 = NO | UNIT MODEL | PRODUCT | UNIT TYPE | C/N | DATE | STATUS |
-- REMARK. STATUS berisi "DONE" / kosong / centang "V" (dengan tanggal);
-- kosong tanpa tanggal -> NOT YET, "V" atau kosong dengan tanggal -> DONE.
-- Tidak ada kolom HM — program satu kali jalan per unit, tanpa interval.
-- Tanggal bisa teks Indonesia ("05 Juli 2024").
--
-- Struktur & alur SAMA dengan modul proker lain: import menulis
-- proker_fsprimer_unit + proker_fsprimer_execution, upsert berbasis
-- (cn, period, work_type) dengan period tetap "FIRE SUPPRESSION".
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V77__proker_fsprimer.sql

CREATE TABLE IF NOT EXISTS proker_fsprimer_unit (
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

CREATE TABLE IF NOT EXISTS proker_fsprimer_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_fsprimer_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- "FIRE SUPPRESSION"
  period_year   INTEGER,
  work_type     VARCHAR(100) NOT NULL DEFAULT 'FIRE SUPPRESSION PRIMER',
  hm            NUMERIC(12,2) NULL,
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- REMARK
  status        VARCHAR(20) NOT NULL DEFAULT 'NOT YET',
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_fsprimer_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_fsprimer_exec_cn_date
  ON proker_fsprimer_execution (cn, service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fsprimer_exec_date
  ON proker_fsprimer_execution (service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fsprimer_exec_status
  ON proker_fsprimer_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_fsprimer_unit_model
  ON proker_fsprimer_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_fsprimer_unit_updated ON proker_fsprimer_unit;
CREATE TRIGGER trg_proker_fsprimer_unit_updated BEFORE UPDATE ON proker_fsprimer_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_fsprimer_execution_updated ON proker_fsprimer_execution;
CREATE TRIGGER trg_proker_fsprimer_execution_updated BEFORE UPDATE ON proker_fsprimer_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerfsprimer" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V76) + 'prokerfsprimer'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb',
    'prokerfandpompa','prokergmc','prokerfsbooster','prokerfsprimer'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerfsprimer', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerfsprimer', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerfsprimer');
