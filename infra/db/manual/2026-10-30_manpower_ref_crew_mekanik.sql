-- Validasi data manpower terhadap daftar referensi NRP mekanik per crew.
--
-- Sumber daftar : data-manpower/*.txt (5 file)
--   nrp mekanik big wheel.txt      Big Wheel - PCH              Big Wheel  20 NRP
--   nrp mekanik pch.txt            Big Wheel - PCH              PCH        25 NRP
--   nrp mekanik spex mobile.txt    SPEX Mobile - Lighting       Mobile     31 NRP
--   nrp mekanik spex lighting.txt  SPEX Mobile - Lighting       Lighting   26 NRP
--   nrp mekanik spex pumping.txt   SPEX Pumping - Fabrication   Pumping    44 NRP
-- Total NRP     : 146
--
-- Diterapkan untuk setiap NRP:
--   Section = sesuai crew (lihat tabel di bawah)
--   Crew    = sesuai file referensi
--   Status  = 'Mekanik'
--   auto    = FALSE (hasil validasi manual, tidak akan ditimpa tombol
--             "Isi otomatis dari jabatan")
--
-- Target per crew:
--   Big Wheel - PCH              Big Wheel  20
--   Big Wheel - PCH              PCH        25
--   SPEX Mobile - Lighting       Lighting   26
--   SPEX Mobile - Lighting       Mobile     31
--   SPEX Pumping - Fabrication   Pumping    44
--
-- File ini TIDAK dijalankan otomatis oleh container (bukan pola V<angka>__),
-- jadi aman dijalankan manual, sekali atau berulang (idempoten):
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_ref_crew_mekanik.sql
--
-- Catatan: dari 10 snapshot Jan-Okt 2026 hanya 128 NRP yang ditemukan; 18 NRP
-- sisanya (semua berawalan 504) belum ada di file manpower sama sekali. NRP
-- tersebut tetap dibuatkan profil agar pengelompokannya benar begitu muncul.

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE ref_crew (
  nrp     TEXT PRIMARY KEY,
  section TEXT NOT NULL,
  crew    TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO ref_crew (nrp, section, crew) VALUES
  ('47180020', 'Big Wheel - PCH', 'Big Wheel'),
  ('47230120', 'Big Wheel - PCH', 'Big Wheel'),
  ('47230121', 'Big Wheel - PCH', 'Big Wheel'),
  ('47240087', 'Big Wheel - PCH', 'Big Wheel'),
  ('50415902', 'Big Wheel - PCH', 'Big Wheel'),
  ('61091683', 'Big Wheel - PCH', 'Big Wheel'),
  ('61091938', 'Big Wheel - PCH', 'Big Wheel'),
  ('61091940', 'Big Wheel - PCH', 'Big Wheel'),
  ('61112257', 'Big Wheel - PCH', 'Big Wheel'),
  ('61120176', 'Big Wheel - PCH', 'Big Wheel'),
  ('61130606', 'Big Wheel - PCH', 'Big Wheel'),
  ('61130617', 'Big Wheel - PCH', 'Big Wheel'),
  ('61160021', 'Big Wheel - PCH', 'Big Wheel'),
  ('61171499', 'Big Wheel - PCH', 'Big Wheel'),
  ('61180997', 'Big Wheel - PCH', 'Big Wheel'),
  ('61190627', 'Big Wheel - PCH', 'Big Wheel'),
  ('61240188', 'Big Wheel - PCH', 'Big Wheel'),
  ('61240189', 'Big Wheel - PCH', 'Big Wheel'),
  ('61240190', 'Big Wheel - PCH', 'Big Wheel'),
  ('84100049', 'Big Wheel - PCH', 'Big Wheel'),
  ('47090047', 'Big Wheel - PCH', 'PCH'),
  ('47090085', 'Big Wheel - PCH', 'PCH'),
  ('47100078', 'Big Wheel - PCH', 'PCH'),
  ('47180018', 'Big Wheel - PCH', 'PCH'),
  ('47180022', 'Big Wheel - PCH', 'PCH'),
  ('47230010', 'Big Wheel - PCH', 'PCH'),
  ('47230021', 'Big Wheel - PCH', 'PCH'),
  ('47240005', 'Big Wheel - PCH', 'PCH'),
  ('50412516', 'Big Wheel - PCH', 'PCH'),
  ('50413694', 'Big Wheel - PCH', 'PCH'),
  ('50415871', 'Big Wheel - PCH', 'PCH'),
  ('50422141', 'Big Wheel - PCH', 'PCH'),
  ('50422232', 'Big Wheel - PCH', 'PCH'),
  ('50422349', 'Big Wheel - PCH', 'PCH'),
  ('61091089', 'Big Wheel - PCH', 'PCH'),
  ('61091253', 'Big Wheel - PCH', 'PCH'),
  ('61091689', 'Big Wheel - PCH', 'PCH'),
  ('61091943', 'Big Wheel - PCH', 'PCH'),
  ('61110614', 'Big Wheel - PCH', 'PCH'),
  ('61130616', 'Big Wheel - PCH', 'PCH'),
  ('61180996', 'Big Wheel - PCH', 'PCH'),
  ('61181505', 'Big Wheel - PCH', 'PCH'),
  ('61232298', 'Big Wheel - PCH', 'PCH'),
  ('61240849', 'Big Wheel - PCH', 'PCH'),
  ('84220019', 'Big Wheel - PCH', 'PCH'),
  ('47130029', 'SPEX Mobile - Lighting', 'Lighting'),
  ('47180021', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50422197', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50422443', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50423135', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50424010', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50424019', 'SPEX Mobile - Lighting', 'Lighting'),
  ('50424021', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61091087', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61091851', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61111054', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61121966', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61130028', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61140468', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61150612', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61160005', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61160007', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61160009', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61230180', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240025', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240185', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240304', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240306', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240440', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61240851', 'SPEX Mobile - Lighting', 'Lighting'),
  ('61250447', 'SPEX Mobile - Lighting', 'Lighting'),
  ('47100038', 'SPEX Mobile - Lighting', 'Mobile'),
  ('47130026', 'SPEX Mobile - Lighting', 'Mobile'),
  ('47130028', 'SPEX Mobile - Lighting', 'Mobile'),
  ('47230012', 'SPEX Mobile - Lighting', 'Mobile'),
  ('47240085', 'SPEX Mobile - Lighting', 'Mobile'),
  ('50421049', 'SPEX Mobile - Lighting', 'Mobile'),
  ('50423091', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61070360', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61091686', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61091947', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61101013', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61102067', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61102185', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61110607', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61111055', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61120306', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61121967', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130019', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130020', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130024', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130169', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130275', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61130372', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61140066', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61160003', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61171679', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61171680', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61181506', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61240184', 'SPEX Mobile - Lighting', 'Mobile'),
  ('61240307', 'SPEX Mobile - Lighting', 'Mobile'),
  ('84230013', 'SPEX Mobile - Lighting', 'Mobile'),
  ('47220061', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47230022', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47230023', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47240006', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47240008', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47240086', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('47250038', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('50416132', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('50417264', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('50422231', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61080670', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61110634', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61112018', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61112294', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61121921', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61130239', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61130241', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61130427', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61130605', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61130734', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61140078', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61140380', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61150242', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61150605', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61160006', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61160025', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61160032', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61160033', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61171418', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61180730', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61180982', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61181735', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61181748', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61190043', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61190082', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61221718', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240027', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240074', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240186', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240187', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240196', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('61240305', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('83110018', 'SPEX Pumping - Fabrication', 'Pumping'),
  ('83170011', 'SPEX Pumping - Fabrication', 'Pumping');

-- Kondisi sebelum perubahan (bukti untuk log psql).
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       COUNT(*)                        AS jumlah
FROM ref_crew r
LEFT JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4
ORDER BY jumlah DESC, 2, 3, 4;

-- Terapkan pengelompokan referensi (buat profil bila belum ada).
INSERT INTO manpower_profile (nrp, section, crew, status, auto, updated_by)
SELECT r.nrp, r.section, r.crew, 'Mekanik', FALSE, 'validasi: nrp mekanik per crew'
FROM ref_crew r
ON CONFLICT (nrp) DO UPDATE SET
  section    = EXCLUDED.section,
  crew       = EXCLUDED.crew,
  status     = EXCLUDED.status,
  auto       = FALSE,
  updated_by = EXCLUDED.updated_by,
  updated_at = now();

-- Ringkasan hasil per section/crew.
SELECT 'SESUDAH' AS tahap, p.section, p.crew, p.status, COUNT(*) AS jumlah
FROM ref_crew r
JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4
ORDER BY p.section, p.crew;

-- NRP referensi yang belum ada di snapshot manpower: profilnya sudah siap,
-- tetapi belum bisa tampil di halaman Manpower.
SELECT 'belum ada di snapshot' AS catatan, r.nrp, r.section, r.crew
FROM ref_crew r
WHERE NOT EXISTS (SELECT 1 FROM manpower_month m WHERE m.nrp = r.nrp)
ORDER BY r.section, r.crew, r.nrp;

COMMIT;

-- Verifikasi akhir: hasilnya harus 0.
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM manpower_profile p
JOIN (VALUES
('47180020', 'Big Wheel - PCH', 'Big Wheel'),
    ('47230120', 'Big Wheel - PCH', 'Big Wheel'),
    ('47230121', 'Big Wheel - PCH', 'Big Wheel'),
    ('47240087', 'Big Wheel - PCH', 'Big Wheel'),
    ('50415902', 'Big Wheel - PCH', 'Big Wheel'),
    ('61091683', 'Big Wheel - PCH', 'Big Wheel'),
    ('61091938', 'Big Wheel - PCH', 'Big Wheel'),
    ('61091940', 'Big Wheel - PCH', 'Big Wheel'),
    ('61112257', 'Big Wheel - PCH', 'Big Wheel'),
    ('61120176', 'Big Wheel - PCH', 'Big Wheel'),
    ('61130606', 'Big Wheel - PCH', 'Big Wheel'),
    ('61130617', 'Big Wheel - PCH', 'Big Wheel'),
    ('61160021', 'Big Wheel - PCH', 'Big Wheel'),
    ('61171499', 'Big Wheel - PCH', 'Big Wheel'),
    ('61180997', 'Big Wheel - PCH', 'Big Wheel'),
    ('61190627', 'Big Wheel - PCH', 'Big Wheel'),
    ('61240188', 'Big Wheel - PCH', 'Big Wheel'),
    ('61240189', 'Big Wheel - PCH', 'Big Wheel'),
    ('61240190', 'Big Wheel - PCH', 'Big Wheel'),
    ('84100049', 'Big Wheel - PCH', 'Big Wheel'),
    ('47090047', 'Big Wheel - PCH', 'PCH'),
    ('47090085', 'Big Wheel - PCH', 'PCH'),
    ('47100078', 'Big Wheel - PCH', 'PCH'),
    ('47180018', 'Big Wheel - PCH', 'PCH'),
    ('47180022', 'Big Wheel - PCH', 'PCH'),
    ('47230010', 'Big Wheel - PCH', 'PCH'),
    ('47230021', 'Big Wheel - PCH', 'PCH'),
    ('47240005', 'Big Wheel - PCH', 'PCH'),
    ('50412516', 'Big Wheel - PCH', 'PCH'),
    ('50413694', 'Big Wheel - PCH', 'PCH'),
    ('50415871', 'Big Wheel - PCH', 'PCH'),
    ('50422141', 'Big Wheel - PCH', 'PCH'),
    ('50422232', 'Big Wheel - PCH', 'PCH'),
    ('50422349', 'Big Wheel - PCH', 'PCH'),
    ('61091089', 'Big Wheel - PCH', 'PCH'),
    ('61091253', 'Big Wheel - PCH', 'PCH'),
    ('61091689', 'Big Wheel - PCH', 'PCH'),
    ('61091943', 'Big Wheel - PCH', 'PCH'),
    ('61110614', 'Big Wheel - PCH', 'PCH'),
    ('61130616', 'Big Wheel - PCH', 'PCH'),
    ('61180996', 'Big Wheel - PCH', 'PCH'),
    ('61181505', 'Big Wheel - PCH', 'PCH'),
    ('61232298', 'Big Wheel - PCH', 'PCH'),
    ('61240849', 'Big Wheel - PCH', 'PCH'),
    ('84220019', 'Big Wheel - PCH', 'PCH'),
    ('47130029', 'SPEX Mobile - Lighting', 'Lighting'),
    ('47180021', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50422197', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50422443', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50423135', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50424010', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50424019', 'SPEX Mobile - Lighting', 'Lighting'),
    ('50424021', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61091087', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61091851', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61111054', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61121966', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61130028', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61140468', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61150612', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61160005', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61160007', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61160009', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61230180', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240025', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240185', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240304', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240306', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240440', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61240851', 'SPEX Mobile - Lighting', 'Lighting'),
    ('61250447', 'SPEX Mobile - Lighting', 'Lighting'),
    ('47100038', 'SPEX Mobile - Lighting', 'Mobile'),
    ('47130026', 'SPEX Mobile - Lighting', 'Mobile'),
    ('47130028', 'SPEX Mobile - Lighting', 'Mobile'),
    ('47230012', 'SPEX Mobile - Lighting', 'Mobile'),
    ('47240085', 'SPEX Mobile - Lighting', 'Mobile'),
    ('50421049', 'SPEX Mobile - Lighting', 'Mobile'),
    ('50423091', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61070360', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61091686', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61091947', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61101013', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61102067', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61102185', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61110607', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61111055', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61120306', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61121967', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130019', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130020', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130024', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130169', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130275', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61130372', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61140066', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61160003', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61171679', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61171680', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61181506', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61240184', 'SPEX Mobile - Lighting', 'Mobile'),
    ('61240307', 'SPEX Mobile - Lighting', 'Mobile'),
    ('84230013', 'SPEX Mobile - Lighting', 'Mobile'),
    ('47220061', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47230022', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47230023', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47240006', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47240008', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47240086', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('47250038', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('50416132', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('50417264', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('50422231', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61080670', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61110634', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61112018', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61112294', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61121921', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61130239', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61130241', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61130427', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61130605', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61130734', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61140078', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61140380', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61150242', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61150605', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61160006', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61160025', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61160032', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61160033', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61171418', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61180730', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61180982', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61181735', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61181748', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61190043', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61190082', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61221718', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240027', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240074', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240186', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240187', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240196', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('61240305', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('83110018', 'SPEX Pumping - Fabrication', 'Pumping'),
    ('83170011', 'SPEX Pumping - Fabrication', 'Pumping')
) AS x(nrp, section, crew) ON x.nrp = p.nrp
WHERE p.section IS DISTINCT FROM x.section
   OR p.crew    IS DISTINCT FROM x.crew
   OR p.status  IS DISTINCT FROM 'Mekanik';
