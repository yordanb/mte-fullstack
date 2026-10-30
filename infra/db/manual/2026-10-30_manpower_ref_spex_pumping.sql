-- Validasi data manpower terhadap daftar referensi NRP mekanik SPEX Pumping.
--
-- CATATAN: seluruh NRP di file ini sudah termasuk dalam versi gabungan
-- `2026-10-30_manpower_ref_crew_mekanik.sql` (5 crew). Pakai file gabungan bila
-- ingin menerapkan semua crew sekaligus; file ini tetap boleh dijalankan
-- sendiri (idempoten, hasilnya sama untuk crew Pumping).
--
-- Sumber daftar : data-manpower/nrp mekanik spex pumping.txt
-- Jumlah NRP    : 44
-- Diterapkan    : Section = 'SPEX Pumping - Fabrication'
--                 Crew    = 'Pumping'
--                 Status  = 'Mekanik'
--                 auto    = FALSE (hasil validasi manual, jadi tidak akan
--                           ditimpa tombol "Isi otomatis dari jabatan")
--
-- Hasil kroscek snapshot (Jan-Okt 2026): 41 NRP ada, 3 NRP belum muncul di
-- snapshot. NRP yang belum ada tetap dibuatkan profil supaya pengelompokannya
-- sudah benar begitu muncul di file manpower bulan berikutnya.
--
-- File ini TIDAK dijalankan otomatis oleh container (bukan pola V<angka>__),
-- jadi aman dijalankan manual, sekali atau berulang (idempoten):
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_ref_spex_pumping.sql

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE ref_pumping (nrp TEXT PRIMARY KEY) ON COMMIT DROP;

INSERT INTO ref_pumping (nrp) VALUES
  ('47220061'),
  ('47230022'),
  ('47230023'),
  ('47240006'),
  ('47240008'),
  ('47240086'),
  ('47250038'),
  ('50416132'),
  ('50417264'),
  ('50422231'),
  ('61080670'),
  ('61110634'),
  ('61112018'),
  ('61112294'),
  ('61121921'),
  ('61130239'),
  ('61130241'),
  ('61130427'),
  ('61130605'),
  ('61130734'),
  ('61140078'),
  ('61140380'),
  ('61150242'),
  ('61150605'),
  ('61160006'),
  ('61160025'),
  ('61160032'),
  ('61160033'),
  ('61171418'),
  ('61180730'),
  ('61180982'),
  ('61181735'),
  ('61181748'),
  ('61190043'),
  ('61190082'),
  ('61221718'),
  ('61240027'),
  ('61240074'),
  ('61240186'),
  ('61240187'),
  ('61240196'),
  ('61240305'),
  ('83110018'),
  ('83170011');

-- Kondisi sebelum perubahan (bukti untuk log psql).
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       COUNT(*)                        AS jumlah
FROM ref_pumping r
LEFT JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4
ORDER BY jumlah DESC, 2, 3, 4;

-- Terapkan pengelompokan referensi (buat profil bila belum ada).
INSERT INTO manpower_profile (nrp, section, crew, status, auto, updated_by)
SELECT r.nrp, 'SPEX Pumping - Fabrication', 'Pumping', 'Mekanik', FALSE,
       'validasi: nrp mekanik spex pumping'
FROM ref_pumping r
ON CONFLICT (nrp) DO UPDATE SET
  section    = EXCLUDED.section,
  crew       = EXCLUDED.crew,
  status     = EXCLUDED.status,
  auto       = FALSE,
  updated_by = EXCLUDED.updated_by,
  updated_at = now();

-- Ringkasan hasil.
SELECT 'SESUDAH' AS tahap,
       p.section,
       p.crew,
       p.status,
       COUNT(*) AS jumlah
FROM ref_pumping r
JOIN manpower_profile p ON p.nrp = r.nrp
GROUP BY 2, 3, 4
ORDER BY jumlah DESC;

-- NRP referensi yang belum ada di snapshot manpower: profilnya sudah siap,
-- tetapi belum bisa tampil di halaman Manpower.
SELECT 'belum ada di snapshot' AS catatan, r.nrp
FROM ref_pumping r
WHERE NOT EXISTS (SELECT 1 FROM manpower_month m WHERE m.nrp = r.nrp)
ORDER BY r.nrp;

COMMIT;

-- Verifikasi akhir: hasilnya harus 0.
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM manpower_profile
WHERE nrp IN (SELECT nrp FROM (VALUES
    ('47220061'),
    ('47230022'),
    ('47230023'),
    ('47240006'),
    ('47240008'),
    ('47240086'),
    ('47250038'),
    ('50416132'),
    ('50417264'),
    ('50422231'),
    ('61080670'),
    ('61110634'),
    ('61112018'),
    ('61112294'),
    ('61121921'),
    ('61130239'),
    ('61130241'),
    ('61130427'),
    ('61130605'),
    ('61130734'),
    ('61140078'),
    ('61140380'),
    ('61150242'),
    ('61150605'),
    ('61160006'),
    ('61160025'),
    ('61160032'),
    ('61160033'),
    ('61171418'),
    ('61180730'),
    ('61180982'),
    ('61181735'),
    ('61181748'),
    ('61190043'),
    ('61190082'),
    ('61221718'),
    ('61240027'),
    ('61240074'),
    ('61240186'),
    ('61240187'),
    ('61240196'),
    ('61240305'),
    ('83110018'),
    ('83170011')
) AS t(nrp))
  AND (section IS DISTINCT FROM 'SPEX Pumping - Fabrication'
       OR crew    IS DISTINCT FROM 'Pumping'
       OR status  IS DISTINCT FROM 'Mekanik');
