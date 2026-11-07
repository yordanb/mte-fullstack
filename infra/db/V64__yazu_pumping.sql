-- V64: Modul baru "Yazu Pumping P2H" — checklist inspeksi unit pompa
-- (Primer / MHP / Booster) sync dari Google Sheets + pivot HM bulanan.
--
-- Satu tabel menampung ketiga kategori dengan kolom `kategori`
-- ('primer' | 'mhp' | 'booster'). Kolom gabungan (union) dari ketiga sheet;
-- kolom yang tidak ada di suatu kategori dibiarkan NULL.
--
-- Nomor kolom ruas kiri migrasi melanjutkan V63 (terakhir V63).
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V64__yazu_pumping.sql
--
-- Idempoten & aman rerun (CREATE TABLE IF NOT EXISTS + upsert).

-- ── 1. Tabel utama ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS yazu_pumping (
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
  -- Checklist umum (ketiga kategori)
  fungsi_loto              VARCHAR(50),
  fungsi_emergency_stop    VARCHAR(50),
  fungsi_control_panel     VARCHAR(50),
  backlog                  TEXT,
  level_oil_engine         VARCHAR(50),
  level_water_coolant      VARCHAR(50),
  level_grease_autolube    VARCHAR(50),
  kondisi_gland_packing    VARCHAR(50),
  fire_suppression         VARCHAR(50),
  apar                     VARCHAR(50),
  komentar                 TEXT,
  layak_operasi            VARCHAR(50),
  -- Kolom khas per kategori
  fungsi_attachment        VARCHAR(50),   -- primer & mhp
  level_oli_vacuum         VARCHAR(50),   -- primer
  level_oli_transmisi      VARCHAR(50),   -- mhp
  fungsi_ac                VARCHAR(50),   -- mhp
  fungsi_panel_motor_355kw VARCHAR(50),   -- booster
  synced_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (kategori, waktu, id_unit)
);

CREATE INDEX IF NOT EXISTS idx_yazu_pumping_kategori_waktu
  ON yazu_pumping (kategori, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_yazu_pumping_unit
  ON yazu_pumping (id_unit);

-- ── 2. Tabel log sync ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS yazu_pumping_sync_log (
  id              SERIAL PRIMARY KEY,
  started_at      TIMESTAMPTZ NOT NULL,
  finished_at     TIMESTAMPTZ,
  status          VARCHAR(20) NOT NULL,           -- 'success' | 'error'
  rows_total      INTEGER,
  rows_upserted   INTEGER,
  error_msg       TEXT
);

-- ── 3. Izin menu: tambah 'yazupumping' ──────────────────────────────────────
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting',
    'yazupumping','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo'
  ));

-- Jaring pengaman: admin selalu punya akses penuh ke menu baru.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
VALUES ('admin', 'yazupumping', TRUE, TRUE, TRUE, TRUE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view = TRUE, can_add = TRUE, can_edit = TRUE, can_delete = TRUE;

-- Salin izin dari "yazu_lighting" untuk role lain (akses yang sudah jalan
-- dianggap berlaku sama untuk modul Pumping), bila belum ada.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'yazupumping', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'yazu_lighting'
ON CONFLICT (role, menu) DO NOTHING;
