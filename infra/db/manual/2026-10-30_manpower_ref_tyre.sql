-- Validasi data manpower terhadap daftar referensi NRP Section/Crew Tyre.
--
-- Sumber daftar : data-manpower/nrp staff tyre.txt     (14 NRP)
--                 data-manpower/nrp repairman tyre.txt  (6 NRP)
-- Total NRP     : 20
--
-- Diterapkan untuk setiap NRP:
--   Section = 'Tyre'
--   Crew    = 'Tyre'
--   Status  = 'Staff' atau 'Repairman' sesuai file referensi
--   auto    = FALSE (hasil validasi manual, tidak akan ditimpa tombol
--             "Isi otomatis dari jabatan")
--
-- Hasil kroscek snapshot Jan-Okt 2026: seluruh 20 NRP ditemukan, dan
-- tebakan dari JABATAN sudah sama dengan referensi. Skrip ini tetap dijalankan
-- agar nilainya terkunci (auto = FALSE) dan tidak bergeser bila jabatan
-- berubah pada file manpower bulan berikutnya.
--
-- Catatan: ada 2 orang berjabatan TYRE di snapshot yang tidak ada di file
-- referensi (61220719 IVAN MAULANA RAHARJA, 61250541 AZAM ALFIAN); keduanya
-- tidak diubah karena tetap hasil tebakan otomatis.
--
-- Prasyarat: V48 (Section/Status) dan V49 (Crew 'Tyre').
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_ref_tyre.sql

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE ref_tyre (
  nrp    TEXT PRIMARY KEY,
  status TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO ref_tyre (nrp, status) VALUES
  ('47080067', 'Repairman'),
  ('47100031', 'Repairman'),
  ('47100032', 'Repairman'),
  ('47110026', 'Repairman'),
  ('47250040', 'Repairman'),
  ('47250041', 'Repairman'),
  ('47060016', 'Staff'),
  ('47060017', 'Staff'),
  ('47070019', 'Staff'),
  ('47080068', 'Staff'),
  ('47080069', 'Staff'),
  ('47080086', 'Staff'),
  ('47080087', 'Staff'),
  ('47080088', 'Staff'),
  ('47100086', 'Staff'),
  ('61080877', 'Staff'),
  ('61102572', 'Staff'),
  ('61122039', 'Staff'),
  ('61140407', 'Staff'),
  ('61232560', 'Staff');

-- Kondisi sebelum perubahan (bukti untuk log psql).
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       p.auto,
       COUNT(*) AS jumlah
FROM ref_tyre r
LEFT JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4, 5
ORDER BY jumlah DESC, 2, 3, 4;

INSERT INTO manpower_profile (nrp, section, crew, status, auto, updated_by)
SELECT r.nrp, 'Tyre', 'Tyre', r.status, FALSE, 'validasi: nrp staff/repairman tyre'
FROM ref_tyre r
ON CONFLICT (nrp) DO UPDATE SET
  section    = EXCLUDED.section,
  crew       = EXCLUDED.crew,
  status     = EXCLUDED.status,
  auto       = FALSE,
  updated_by = EXCLUDED.updated_by,
  updated_at = now();

-- Ringkasan hasil.
SELECT 'SESUDAH' AS tahap, p.section, p.crew, p.status, COUNT(*) AS jumlah
FROM ref_tyre r
JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4
ORDER BY p.status, jumlah DESC;

-- NRP referensi yang belum ada di snapshot manpower.
SELECT 'belum ada di snapshot' AS catatan, r.nrp, r.status
FROM ref_tyre r
WHERE NOT EXISTS (SELECT 1 FROM manpower_month m WHERE m.nrp = r.nrp)
ORDER BY r.nrp;

COMMIT;

-- Verifikasi akhir: hasilnya harus 0.
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM manpower_profile p
JOIN (VALUES
    ('47080067', 'Repairman'),
    ('47100031', 'Repairman'),
    ('47100032', 'Repairman'),
    ('47110026', 'Repairman'),
    ('47250040', 'Repairman'),
    ('47250041', 'Repairman'),
    ('47060016', 'Staff'),
    ('47060017', 'Staff'),
    ('47070019', 'Staff'),
    ('47080068', 'Staff'),
    ('47080069', 'Staff'),
    ('47080086', 'Staff'),
    ('47080087', 'Staff'),
    ('47080088', 'Staff'),
    ('47100086', 'Staff'),
    ('61080877', 'Staff'),
    ('61102572', 'Staff'),
    ('61122039', 'Staff'),
    ('61140407', 'Staff'),
    ('61232560', 'Staff')
) AS x(nrp, status) ON x.nrp = p.nrp
WHERE p.section IS DISTINCT FROM 'Tyre'
   OR p.crew    IS DISTINCT FROM 'Tyre'
   OR p.status  IS DISTINCT FROM x.status;
