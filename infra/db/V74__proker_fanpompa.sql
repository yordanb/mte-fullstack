-- V74: Proker Fan Drive Pompa Primer — upgrade pulley drive unit pompa
-- primer seri MF.
--
-- Sumber Excel: "proker fan drive pompa primer.xlsx", sheet "08. FAN DRIVE"
-- — satu jenis pekerjaan per unit. Header tiga baris: baris 2 = NO/UNIT
-- MODEL/PRODUCT/UNIT TYPE/C/N + label grup "UPGRADE PULLEY FANDRIVE"
-- (merge F2:K2), baris 3 = DATE | HM | REMARKS | WO | WR.
-- Tidak ada kolom status: baris eksekusi ada bila DATE/HM/REMARKS terisi;
-- status selalu DONE. WO (work order) dan WR (work request) disimpan sebagai
-- teks. Tanggal bisa berupa teks Indonesia ("05 Juli 2024").
--
-- Struktur & alur SAMA dengan modul proker lain: import memecah matriks
-- menjadi proker_fanpompa_unit + proker_fanpompa_execution, upsert berbasis
-- (cn, period, work_type). Tidak ada interval HM (upgrade sekali jalan).
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V74__proker_fanpompa.sql

CREATE TABLE IF NOT EXISTS proker_fanpompa_unit (
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

CREATE TABLE IF NOT EXISTS proker_fanpompa_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_fanpompa_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- label grup sumber
  period_year   INTEGER,
  work_type     VARCHAR(100) NOT NULL,          -- "UPGRADE PULLEY FANDRIVE"
  hm            NUMERIC(12,2) NULL,
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- REMARKS
  wo            VARCHAR(100) NULL,              -- work order
  wr            VARCHAR(100) NULL,              -- work request
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_fanpompa_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_fanpompa_exec_cn_date
  ON proker_fanpompa_execution (cn, service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fanpompa_exec_date
  ON proker_fanpompa_execution (service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fanpompa_exec_status
  ON proker_fanpompa_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_fanpompa_unit_model
  ON proker_fanpompa_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_fanpompa_unit_updated ON proker_fanpompa_unit;
CREATE TRIGGER trg_proker_fanpompa_unit_updated BEFORE UPDATE ON proker_fanpompa_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_fanpompa_execution_updated ON proker_fanpompa_execution;
CREATE TRIGGER trg_proker_fanpompa_execution_updated BEFORE UPDATE ON proker_fanpompa_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerfandpompa" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V73) + 'prokerfandpompa'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb',
    'prokerfandpompa'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerfandpompa', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerfandpompa', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerfandpompa');
