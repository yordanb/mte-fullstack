-- V39: Suggestion System (SS) — data ReportSSClosedDistrict (KIDE) + menu "Sugestion System".
-- Sumber: data sample excel/data ss/ReportSSClosedDistrict_KIDE_<periode>.xlsx
-- Satu baris = satu NO SS (terbukti 0 duplikat di 4 file 2023-2026), jadi import memakai
-- UPSERT berbasis no_ss: file baru menambah baris baru & memperbarui baris yang sudah ada.

CREATE TABLE IF NOT EXISTS ss_report (
  id                BIGSERIAL PRIMARY KEY,
  no_ss             VARCHAR(40) NOT NULL,          -- SS/KIDE/2026/3255575
  tgl_laporan       DATE NULL,                     -- TANGGAL LAPORAN (ide masuk)
  judul             TEXT NULL,
  pencetus          TEXT NULL,                     -- PENCETUS IDE
  nrp               TEXT NULL,                     -- campur: 61080686 / KIER18021 / MM230379
  dept              TEXT NULL,                     -- SPL1 / SPL2 / STYR / PPD
  distrik           TEXT NULL,                     -- KIDE
  manfaat_fin       NUMERIC(18,2) NULL,            -- MANFAAT FINANCIAL (hanya ~1% terisi)
  tgl_menilai       DATE NULL,                     -- TANGGAL MENILAI (dasar periode file)
  dinilai_oleh      TEXT NULL,                     -- penilai (bisa kosong)
  grade             VARCHAR(2) NULL,               -- A..F
  kualitas          TEXT NULL,                     -- Breakthrough/Excellent/... (Break -> dinormalkan)
  kategori          TEXT NULL,                     -- teks asli dari Excel
  kategori_norm     TEXT NULL,                     -- kategori kanonik (29 varian -> ~12)
  reward            NUMERIC(14,2) NOT NULL DEFAULT 0,
  status_karyawan   TEXT NULL,                     -- PAMA / LS / kosong
  import_id         UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ss_report_no_ss_key UNIQUE (no_ss)
);

CREATE INDEX IF NOT EXISTS idx_ss_tgl_menilai ON ss_report (tgl_menilai DESC);
CREATE INDEX IF NOT EXISTS idx_ss_tgl_laporan ON ss_report (tgl_laporan DESC);
CREATE INDEX IF NOT EXISTS idx_ss_nrp ON ss_report (nrp);
CREATE INDEX IF NOT EXISTS idx_ss_dept ON ss_report (dept);
CREATE INDEX IF NOT EXISTS idx_ss_grade ON ss_report (grade);
CREATE INDEX IF NOT EXISTS idx_ss_kategori ON ss_report (kategori_norm);
CREATE INDEX IF NOT EXISTS idx_ss_status ON ss_report (status_karyawan);

-- Menu "ss" pada matriks izin (grup menu baru: Agent).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss'
  ));

-- Hak akses: HANYA admin yang boleh melihat. Role lain tetap dibuatkan baris
-- (semua FALSE) agar matriks izin di halaman Users menampilkan menu ini.
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','ss',TRUE,TRUE,TRUE,TRUE),
  ('inputer','ss',FALSE,FALSE,FALSE,FALSE),
  ('mekanik','ss',FALSE,FALSE,FALSE,FALSE),
  ('viewer','ss',FALSE,FALSE,FALSE,FALSE),
  ('planner','ss',FALSE,FALSE,FALSE,FALSE),
  ('group leader','ss',FALSE,FALSE,FALSE,FALSE),
  ('section head','ss',FALSE,FALSE,FALSE,FALSE),
  ('adm te','ss',FALSE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
