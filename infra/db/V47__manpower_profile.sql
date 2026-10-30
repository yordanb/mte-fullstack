-- V47: pengelompokan manpower (halaman "Manpower").
--
-- Sumber data: `manpower_month` (snapshot bulanan RptInnovatorMonthly).
-- Pengelompokan (Section / Crew / Status) berlaku PER ORANG (NRP), bukan per
-- bulan: orang yang sama tetap berada di kelompok yang sama walau snapshot
-- bulan berikutnya berbeda komposisi manpower.
--
-- Karena disimpan di tabel sendiri, import ulang manpower tidak menghapus
-- pengelompokan yang sudah diisi manual.
--
-- Section : daftar tetap
--   "Big Wheel - PCH", "SPEX Mobile - Lighting", "SPEX Pumping - Fabrication",
--   "LCE", "MTE", "Dept Head"
-- Crew    : "Big Wheel", "PCH", "Mobile", "Lighting", "Pumping"
-- Status  : "Staff", "Mekanik"
--
-- Isi awal: halaman Manpower menjalankan "isi otomatis dari jabatan" sekali
-- saat tabel masih kosong (kolom `auto` = TRUE). Hasil tebakan bisa dikoreksi
-- manual; kolom `auto` berubah FALSE.

CREATE TABLE IF NOT EXISTS manpower_profile (
  nrp         TEXT PRIMARY KEY,
  section     TEXT NULL,
  crew        TEXT NULL,
  status      TEXT NULL,
  auto        BOOLEAN NOT NULL DEFAULT FALSE,   -- TRUE bila masih hasil tebakan
  updated_by  TEXT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT manpower_profile_section_check CHECK (
    section IS NULL OR section IN (
      'Big Wheel - PCH', 'SPEX Mobile - Lighting',
      'SPEX Pumping - Fabrication', 'LCE', 'MTE', 'Dept Head'
    )
  ),
  CONSTRAINT manpower_profile_crew_check CHECK (
    crew IS NULL OR crew IN ('Big Wheel', 'PCH', 'Mobile', 'Lighting', 'Pumping')
  ),
  CONSTRAINT manpower_profile_status_check CHECK (
    status IS NULL OR status IN ('Staff', 'Mekanik')
  )
);

CREATE INDEX IF NOT EXISTS idx_manpower_profile_section ON manpower_profile (section);
CREATE INDEX IF NOT EXISTS idx_manpower_profile_crew ON manpower_profile (crew);
CREATE INDEX IF NOT EXISTS idx_manpower_profile_status ON manpower_profile (status);

DROP TRIGGER IF EXISTS trg_manpower_profile_updated ON manpower_profile;
CREATE TRIGGER trg_manpower_profile_updated BEFORE UPDATE ON manpower_profile
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
