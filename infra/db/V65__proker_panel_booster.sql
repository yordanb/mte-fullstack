-- V65: Proker GMC Panel Booster — program kerja GMC Panel Booster (2.000 jam),
-- grup menu Technical Expert.
--
-- Sumber Excel: "proker gmc panel booster.xlsx", sheet "07. GMC PANEL"
-- matriks 51 unit x N periode. Tiap periode memakai 3 kolom berurutan:
--   HM | DATE | MEKANIK
--
-- Struktur & alur SAMA dengan Proker GMC Pompa Primer (V40/V41), hanya
-- berbeda tabel + menu. Berbeda dari Proker CAT, halaman ini TIDAK difilter
-- engine CAT: unit di sini ber-product WARMAN / MULTIFLO / KOMATSU, dst.
--
-- Import memecah matriks menjadi:
--   * proker_panel_unit      — identitas unit (cn, model, product, type, hm_now)
--   * proker_panel_execution — riwayat eksekusi (period, hm, tanggal, mekanik, status)
--
-- Upsert berbasis (cn, period), jadi meng-upload file yang sama/lebih baru
-- hanya memperbarui baris lama tanpa menghapus data di luar file.
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V65__proker_panel_booster.sql

CREATE TABLE IF NOT EXISTS proker_panel_unit (
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

CREATE TABLE IF NOT EXISTS proker_panel_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_panel_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- label periode dari header ("2022", "2024 - Pertama")
  period_year   INTEGER,
  period_seq    INTEGER,
  hm            NUMERIC(12,2) NULL,             -- HM saat proker (NULL bila masih PLAN)
  service_date  DATE NULL,
  mekanik       TEXT NULL,
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',   -- DONE | PLAN | LATE | MISSED
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_panel_execution_uq UNIQUE (cn, period)
);

CREATE INDEX IF NOT EXISTS idx_proker_panel_exec_cn_date
  ON proker_panel_execution (cn, service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_panel_exec_date
  ON proker_panel_execution (service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_panel_exec_status
  ON proker_panel_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_panel_exec_year
  ON proker_panel_execution (period_year, period_seq);
CREATE INDEX IF NOT EXISTS idx_proker_panel_unit_model
  ON proker_panel_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_panel_unit_updated ON proker_panel_unit;
CREATE TRIGGER trg_proker_panel_unit_updated BEFORE UPDATE ON proker_panel_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_panel_execution_updated ON proker_panel_execution;
CREATE TRIGGER trg_proker_panel_execution_updated BEFORE UPDATE ON proker_panel_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerpanel" di group Technical Expert (matriks izin halaman Users).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'ewacs','tarsupport','ss','ssab','proker','prokerbooster','prokerinjector',
    'manpower','manpowermanage','hourmeter','prokerthermo','prokerpanel'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerpanel', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerpanel', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerpanel');
