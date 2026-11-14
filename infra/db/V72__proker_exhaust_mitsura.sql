-- V72: Proker General Repair Exhaust Primer Mitsura — program kerja general
-- repair exhaust primer Mitsura (6.000 jam), grup menu Technical Expert.
--
-- Sumber Excel: "proker general repair exhaust primer mitsura.xlsx",
-- sheet "03. EXHAUST LINE" — matriks checklist unit x jenis pekerjaan,
-- SATU periode "2024 / 2025" (merge F2:Q2).
--
-- Berbeda dari Proker Exhaust Primer (V71), tiap jenis pekerjaan bisa:
--   * 1 kolom STATUS saja, atau
--   * 3 kolom HM | DATE | STATUS
-- dan isi sel berupa checklist: V = selesai, X = tidak/belum, NA/No data =
-- tidak berlaku, PLAN = rencana, angka = HM, tanggal, teks = temuan/catatan.
--
-- Pemetaan status: DONE (V / angka / tanggal), MISSED (X), PLAN (PLAN),
-- NA (NA / No data), NOTE (teks temuan — teks asli disimpan di remark).
--
-- Struktur & alur SAMA dengan Proker Exhaust Primer (V71): import memecah
-- matriks menjadi proker_exhaust_mitsura_unit + proker_exhaust_mitsura_execution,
-- upsert berbasis (cn, period, work_type).
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V72__proker_exhaust_mitsura.sql

CREATE TABLE IF NOT EXISTS proker_exhaust_mitsura_unit (
  cn            VARCHAR(50) PRIMARY KEY,
  no            INTEGER,
  unit_model    VARCHAR(255),
  product       VARCHAR(255),
  unit_type     VARCHAR(255),
  hm_now        NUMERIC(12,2),                 -- HM sekarang (angka terkanan yang terisi)
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS proker_exhaust_mitsura_execution (
  id            SERIAL PRIMARY KEY,
  cn            VARCHAR(50) NOT NULL
                  REFERENCES proker_exhaust_mitsura_unit(cn) ON DELETE CASCADE,
  period        VARCHAR(50) NOT NULL,           -- label periode dari header ("2024 / 2025")
  period_year   INTEGER,
  work_type     VARCHAR(100) NOT NULL,          -- jenis pekerjaan dari header baris 3
  hm            NUMERIC(12,2) NULL,             -- HM saat proker (NULL bila tidak dicatat)
  service_date  DATE NULL,
  remark        TEXT NULL,                      -- teks asli sel (temuan/catatan)
  status        VARCHAR(20) NOT NULL DEFAULT 'DONE',   -- DONE | PLAN | MISSED | NA | NOTE
  import_id     VARCHAR(64),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT proker_exhaust_mitsura_execution_uq UNIQUE (cn, period, work_type)
);

CREATE INDEX IF NOT EXISTS idx_proker_exhaust_mits_exec_cn_date
  ON proker_exhaust_mitsura_execution (cn, service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_mits_exec_date
  ON proker_exhaust_mitsura_execution (service_date DESC);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_mits_exec_status
  ON proker_exhaust_mitsura_execution (status);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_mits_exec_year
  ON proker_exhaust_mitsura_execution (period_year, work_type);
CREATE INDEX IF NOT EXISTS idx_proker_exhaust_mits_unit_model
  ON proker_exhaust_mitsura_unit (unit_model);

DROP TRIGGER IF EXISTS trg_proker_exhaust_mitsura_unit_updated ON proker_exhaust_mitsura_unit;
CREATE TRIGGER trg_proker_exhaust_mitsura_unit_updated BEFORE UPDATE ON proker_exhaust_mitsura_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_proker_exhaust_mitsura_execution_updated ON proker_exhaust_mitsura_execution;
CREATE TRIGGER trg_proker_exhaust_mitsura_execution_updated BEFORE UPDATE ON proker_exhaust_mitsura_execution
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerexhaustmits" (matriks izin halaman Users).
-- Daftar menu disamakan dengan definisi terakhir (V71) + 'prokerexhaustmits'.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits'
  ));

-- Izin mengikuti menu "proker" (satu keluarga proker) supaya tidak perlu
-- diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerexhaustmits', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerexhaustmits', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerexhaustmits');
