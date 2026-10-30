-- Isi Crew untuk Section MTE / LCE / FABRICATION pada data lama (sekali jalan).
--
-- Aturan baru (lihat `classify()` di apps/api/app/api/v1/manpower.py):
--   Section 'MTE'                     -> Crew 'MTE'
--   Section 'LCE'                     -> Crew 'LCE'
--   Section 'SPEX Pumping - Fabrication' -> Crew 'Pumping'
--
-- Yang diisi HANYA baris yang crew-nya masih kosong dan masih hasil tebakan
-- (auto = TRUE). Baris yang sudah dikoreksi manual (auto = FALSE) tidak
-- disentuh, dan crew yang sudah terisi tidak ditimpa.
--
-- Prasyarat: V48, V49, dan V50 (Crew 'MTE'/'LCE').
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_crew_mte_lce.sql

\set ON_ERROR_STOP on
BEGIN;

-- Kondisi sebelum: baris tanpa crew pada bulan terakhir.
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COUNT(*) AS tanpa_crew
FROM manpower_month m
JOIN manpower_profile p ON p.nrp = m.nrp
WHERE m.periode = (SELECT MAX(periode) FROM manpower_month)
  AND p.crew IS NULL
GROUP BY 2
ORDER BY tanpa_crew DESC;

WITH upd AS (
  UPDATE manpower_profile p
     SET crew = CASE p.section
                  WHEN 'MTE' THEN 'MTE'
                  WHEN 'LCE' THEN 'LCE'
                  WHEN 'SPEX Pumping - Fabrication' THEN 'Pumping'
                END,
         updated_by = 'validasi: crew MTE/LCE',
         updated_at = now()
   WHERE p.auto                       -- hanya hasil tebakan
     AND p.crew IS NULL               -- crew yang sudah diisi tidak ditimpa
     AND p.section IN ('MTE', 'LCE', 'SPEX Pumping - Fabrication')
  RETURNING p.nrp
)
SELECT 'diperbarui' AS catatan, COUNT(*) AS jumlah FROM upd;

-- Kondisi sesudah: distribusi crew bulan terakhir.
SELECT 'SESUDAH' AS tahap,
       COALESCE(p.crew, '(kosong)') AS crew,
       COUNT(*) AS jumlah
FROM manpower_month m
JOIN manpower_profile p ON p.nrp = m.nrp
WHERE m.periode = (SELECT MAX(periode) FROM manpower_month)
GROUP BY 2
ORDER BY jumlah DESC, 2;

COMMIT;

-- Verifikasi akhir: baris hasil tebakan pada Section MTE/LCE/FABRICATION yang
-- crew-nya masih kosong. Hasilnya harus 0.
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM manpower_profile
WHERE auto
  AND crew IS NULL
  AND section IN ('MTE', 'LCE', 'SPEX Pumping - Fabrication');
