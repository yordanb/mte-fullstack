-- V43: Proker Midlife Injector Primer (replace injector primer 16.000 jam).
-- Sumber: data sample excel/data program kerja/midlife injector primer.xlsx,
-- sheet "04. INJECTOR DAN TURBO" — 1 baris per unit (50 unit), berisi:
--   NO | UNIT MODEL | PRODUCT | UNIT TYPE | C/N | HM NOW
--   LIFETIME (formula, tidak diimpor)
--   PENGGANTIAN 1 : 12 kolom posisi injector 1..12
--   PENGGANTIAN 2 : 12 kolom posisi injector 1..12
--   PENGGANTIAN 3 : 12 kolom posisi injector 1..12
--
-- Tiap sel = HM saat injector posisi tsb diganti, atau teks "PLAN" bila baru
-- direncanakan. Model: master unit + satu baris per (penggantian ke-, posisi).
-- Derivat dihitung API: umur injector = HM NOW - HM penggantian terakhir.

CREATE TABLE IF NOT EXISTS injector_unit (
  cn           VARCHAR(20) PRIMARY KEY,           -- WP405, WP1190, ...
  no           INT NULL,
  unit_model   TEXT NULL,                         -- WATER PRIMER / WATERFILL / ...
  product      TEXT NULL,                         -- MULTIFLO / KSB / DREDGER PUMP
  unit_type    TEXT NULL,                         -- MF-420E-C27 / RF-85MV C7.1 / ...
  hm_now       NUMERIC(12,2) NULL,
  interval_hm  NUMERIC(12,2) NOT NULL DEFAULT 16000,
  aktif        BOOLEAN NOT NULL DEFAULT TRUE,
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS injector_replacement (
  id           BIGSERIAL PRIMARY KEY,
  cn           VARCHAR(20) NOT NULL REFERENCES injector_unit(cn) ON DELETE CASCADE,
  seq          SMALLINT NOT NULL CHECK (seq BETWEEN 1 AND 9),      -- PENGGANTIAN ke-
  position     SMALLINT NOT NULL CHECK (position BETWEEN 1 AND 24),-- nomor injector
  hm           NUMERIC(12,2) NULL,                 -- NULL bila masih PLAN
  status       VARCHAR(8) NOT NULL DEFAULT 'DONE'
               CHECK (status IN ('DONE', 'PLAN')),
  note         TEXT NULL,
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT injector_replacement_uq UNIQUE (cn, seq, position)
);

CREATE INDEX IF NOT EXISTS idx_injector_repl_cn ON injector_replacement (cn, seq, position);
CREATE INDEX IF NOT EXISTS idx_injector_repl_hm ON injector_replacement (hm DESC);
CREATE INDEX IF NOT EXISTS idx_injector_unit_product ON injector_unit (product);

DROP TRIGGER IF EXISTS trg_injector_unit_updated ON injector_unit;
CREATE TRIGGER trg_injector_unit_updated BEFORE UPDATE ON injector_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_injector_repl_updated ON injector_replacement;
CREATE TRIGGER trg_injector_repl_updated BEFORE UPDATE ON injector_replacement
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerinjector" di group Technical Expert.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss','proker',
    'prokerbooster','prokerinjector'
  ));

-- Izin mengikuti menu "proker" supaya tidak perlu diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerinjector', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete) VALUES
  ('admin',        'prokerinjector', TRUE, TRUE, TRUE, TRUE),
  ('inputer',      'prokerinjector', TRUE, TRUE, TRUE, FALSE),
  ('mekanik',      'prokerinjector', TRUE, TRUE, TRUE, FALSE),
  ('planner',      'prokerinjector', TRUE, TRUE, TRUE, FALSE),
  ('adm te',       'prokerinjector', TRUE, TRUE, TRUE, FALSE),
  ('group leader', 'prokerinjector', TRUE, FALSE, FALSE, FALSE),
  ('section head', 'prokerinjector', TRUE, FALSE, FALSE, FALSE),
  ('viewer',       'prokerinjector', TRUE, FALSE, FALSE, FALSE)
ON CONFLICT (role, menu) DO NOTHING;
