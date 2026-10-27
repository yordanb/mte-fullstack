-- V42: Proker Midlife Eng Booster (program kerja midlife engine pompa booster).
-- Sumber: data sample excel/data program kerja/midlife pompa booster.xlsx,
-- sheet "01. OVH DAN ML ENG" — 1 baris per unit (39 unit), berisi:
--   identitas unit + HM NOW + interval midlife (20.000 jam)
--   kolom OVH     : HM + tanggal overhaul / ganti engine
--   kolom MIDLIFE : HM + tanggal midlife engine
--   REMARKS       : catatan bebas (REPLACE NEW ENGINE, OFFHIRE, ...)
--
-- Kolom turunan pada sheet TIDAK disimpan (dihitung ulang oleh API):
--   NEXT PLAN HM = MAX(OVH, MIDLIFE) + interval   (kolom I)
--   Hours to Go  = NEXT PLAN HM - HM NOW          (kolom H)
--   LIFETIME EG  = HM NOW - OVH HM                (kolom Q)
--   LIFETIME MID = |HM NOW - MIDLIFE HM|          (kolom R)
-- Kolom J (NEXT PLAN DATE) rusak (#REF!) sehingga tidak diimpor.
--
-- Model: master unit + riwayat event engine (OVH / MIDLIFE). Upsert event
-- memakai (cn, kind, hm) sehingga event baru menambah riwayat, sedangkan
-- upload ulang file yang sama hanya memperbarui tanggal/catatan.

CREATE TABLE IF NOT EXISTS booster_unit (
  cn           VARCHAR(20) PRIMARY KEY,           -- WP328, GS1269, ...
  no           INT NULL,                          -- kolom NO
  unit_model   TEXT NULL,                         -- SINGLE BOOSTER / SINGLE BOOSTER MEB / GS SWP 06
  product      TEXT NULL,                         -- WARMAN / MULTIFLO / KOMATSU
  unit_type    TEXT NULL,                         -- EWP420 EGS630-6 / MEB-420EXHV WEG / ...
  hm_now       NUMERIC(12,2) NULL,                -- HM NOW saat file dibuat
  interval_hm  NUMERIC(12,2) NOT NULL DEFAULT 20000,
  remarks      TEXT NULL,
  aktif        BOOLEAN NOT NULL DEFAULT TRUE,
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS booster_event (
  id           BIGSERIAL PRIMARY KEY,
  cn           VARCHAR(20) NOT NULL REFERENCES booster_unit(cn) ON DELETE CASCADE,
  kind         VARCHAR(10) NOT NULL CHECK (kind IN ('OVH', 'MIDLIFE')),
  hm           NUMERIC(12,2) NOT NULL,            -- HM saat event
  service_date DATE NULL,                         -- tanggal event (boleh kosong)
  note         TEXT NULL,
  import_id    UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT booster_event_uq UNIQUE (cn, kind, hm)
);

CREATE INDEX IF NOT EXISTS idx_booster_event_cn ON booster_event (cn, hm DESC);
CREATE INDEX IF NOT EXISTS idx_booster_event_date ON booster_event (service_date DESC);
CREATE INDEX IF NOT EXISTS idx_booster_event_kind ON booster_event (kind);
CREATE INDEX IF NOT EXISTS idx_booster_unit_product ON booster_unit (product);

DROP TRIGGER IF EXISTS trg_booster_unit_updated ON booster_unit;
CREATE TRIGGER trg_booster_unit_updated BEFORE UPDATE ON booster_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_booster_event_updated ON booster_event;
CREATE TRIGGER trg_booster_event_updated BEFORE UPDATE ON booster_event
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerbooster" di group Technical Expert.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss','proker',
    'prokerbooster'
  ));

-- Izin mengikuti menu "proker" supaya tidak perlu diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerbooster', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'proker'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman bila baris "proker" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete) VALUES
  ('admin',        'prokerbooster', TRUE, TRUE, TRUE, TRUE),
  ('inputer',      'prokerbooster', TRUE, TRUE, TRUE, FALSE),
  ('mekanik',      'prokerbooster', TRUE, TRUE, TRUE, FALSE),
  ('planner',      'prokerbooster', TRUE, TRUE, TRUE, FALSE),
  ('adm te',       'prokerbooster', TRUE, TRUE, TRUE, FALSE),
  ('group leader', 'prokerbooster', TRUE, FALSE, FALSE, FALSE),
  ('section head', 'prokerbooster', TRUE, FALSE, FALSE, FALSE),
  ('viewer',       'prokerbooster', TRUE, FALSE, FALSE, FALSE)
ON CONFLICT (role, menu) DO NOTHING;
