-- V67: Modul baru "Yazu Pumping Daily Check" — checklist harian unit pompa
-- (Primer / MHP / Booster) sync dari Google Sheets + pivot HM bulanan.
--
-- Konsep sama dengan "Yazu Pumping P2H" (V64) tetapi header sheet lebih
-- ringkas: tanpa kolom level & kebocoran, cukup fungsi Loto/Emergency
-- Stop/Control Panel, `Backlog` (JSON item OPEN/CLOSED), Komentar, dan
-- Layak Operasi.
--
-- Nomor kolom ruas kiri migrasi melanjutkan V66 (terakhir V66).
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V67__yazu_pumping_dc.sql
--
-- Idempoten & aman rerun (CREATE TABLE IF NOT EXISTS + upsert).

-- ── 1. Tabel utama ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS yazu_pumping_dc (
  id              SERIAL PRIMARY KEY,
  kategori        VARCHAR(20)  NOT NULL,          -- 'primer' | 'mhp' | 'booster'
  waktu           TIMESTAMPTZ  NOT NULL,
  id_unit         VARCHAR(50)  NOT NULL,
  hm              BIGINT,
  nama            VARCHAR(255),
  nrp             VARCHAR(50),
  role            VARCHAR(100),                   -- kolom "Role" di sheet
  lokasi          VARCHAR(255),
  link_lokasi     TEXT,
  akurasi         INTEGER,
  -- Checklist Daily Check (ketiga kategori)
  backlog               TEXT,                     -- JSON item OPEN/CLOSED
  fungsi_loto               VARCHAR(50),
  fungsi_emergency_stop     VARCHAR(50),
  fungsi_control_panel      VARCHAR(50),
  komentar                  TEXT,
  layak_operasi             VARCHAR(50),
  synced_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (kategori, waktu, id_unit)
);

CREATE INDEX IF NOT EXISTS idx_yazu_pumping_dc_kategori_waktu
  ON yazu_pumping_dc (kategori, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_yazu_pumping_dc_unit
  ON yazu_pumping_dc (id_unit);

-- ── 2. Tabel log sync ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS yazu_pumping_dc_sync_log (
  id              SERIAL PRIMARY KEY,
  started_at      TIMESTAMPTZ NOT NULL,
  finished_at     TIMESTAMPTZ,
  status          VARCHAR(20) NOT NULL,           -- 'success' | 'error'
  rows_total      INTEGER,
  rows_upserted   INTEGER,
  error_msg       TEXT
);

-- ── 3. Izin menu: tambah 'yazupumpingdc' ────────────────────────────────────
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel'
  ));

-- Jaring pengaman: admin selalu punya akses penuh ke menu baru.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
VALUES ('admin', 'yazupumpingdc', TRUE, TRUE, TRUE, TRUE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view = TRUE, can_add = TRUE, can_edit = TRUE, can_delete = TRUE;

-- Salin izin dari "yazupumping" untuk role lain (akses P2H dianggap berlaku
-- sama untuk Daily Check), bila belum ada.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'yazupumpingdc', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'yazupumping'
ON CONFLICT (role, menu) DO NOTHING;
