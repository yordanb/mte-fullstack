-- V73: Proker Rebearing Fan Drive Replacement Primer — riwayat penggantian
-- (rebearing) fan drive unit pompa primer.
--
-- Sumber Excel: "proker rebearing fan drive primer.xlsx", sheet
-- "08. FAN DRIVE" — matriks unit x penggantian ke-n. Header tiga baris:
-- baris 2 = NO/UNIT MODEL/PRODUCT/UNIT TYPE/C/N + label "PENGGANTIAN 1..5"
-- (merge 2 kolom per grup; label "PENGGANTIAN 5" muncul dua kali — dinorma-
-- lisasi menjadi urutan 1..6 berdasarkan posisi), baris 3 = HM | DATE.
-- Tidak ada kolom status: baris eksekusi ada bila HM atau DATE terisi;
-- status selalu DONE. Tanggal bisa berupa teks Indonesia ("05 Juli 2024").
--
-- Struktur & alur SAMA dengan modul proker lain: import memecah matriks
-- menjadi proker_fandrebb_unit + proker_fandrebb_execution, upsert berbasis
-- (cn, period, work_type). work_type tetap "REBEARING FAN DRIVE".
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V73__proker_fandrebb.sql

CREATE TABLE IF NOT EXISTS proker_fandrebb_unit (
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

CREATE TABLE IF NOT EXISTS proker_fandrebb_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_fandrebb_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- "PENGGANTIAN 1..6"
  period_year   INTEGER,                        -- tidak ada di label sumber
  work_type     VARCHAR(100) NOT NULL DEFAULT 'REBEARING FAN DRIVE',
  hm            NUMERIC(12,2) NULL,
  service_date  DATE NULL,
  remark        TEXT NULL,
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_fandrebb_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_fandrebb_exec_cn_date
  ON proker_fandrebb_execution (cn, service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fandrebb_exec_date
  ON proker_fandrebb_execution (service_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_proker_fandrebb_exec_status
  ON proker_fandrebb_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_fandrebb_unit_model
  ON proker_fandrebb_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_fandrebb_unit_updated ON proker_fandrebb_unit;
CREATE TRIGGER trg_proker_fandrebb_unit_updated BEFORE UPDATE ON proker_fandrebb_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_fandrebb_execution_updated ON proker_fandrebb_execution;
CREATE TRIGGER trg_proker_fandrebb_execution_updated BEFORE UPDATE ON proker_fandrebb_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerfandrebb" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V72) + 'prokerfandrebb'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerfandrebb', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerfandrebb', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerfandrebb');
