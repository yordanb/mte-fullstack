-- Selaraskan pengelompokan manpower untuk Section "Tyre" (sekali jalan).
--
-- Aturan baru (lihat `classify()` di apps/api/app/api/v1/manpower.py):
--   jabatan memuat TYRE            -> Section 'Tyre', Crew tetap 'Big Wheel'
--   jabatan memuat TYRE ... REPAIRMAN -> Status 'Repairman'
--   jabatan TYRE lainnya (GL/expert/trainee) -> Status 'Staff'
--   Section Tyre tidak memakai Status 'Mekanik'.
--
-- Yang diubah HANYA baris hasil tebakan (auto = TRUE). Baris yang sudah
-- dikoreksi manual (auto = FALSE) tidak disentuh.
--
-- Prasyarat: constraint baru dari V48 (Section 'Tyre', Status 'Repairman').
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V48__manpower_tyre_repairman.sql
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_tyre_section.sql

\set ON_ERROR_STOP on
BEGIN;

-- Kondisi sebelum perubahan, khusus orang berjabatan TYRE.
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       p.auto,
       COUNT(*) AS jumlah
FROM manpower_month m
JOIN manpower_profile p ON p.nrp = m.nrp
WHERE m.periode = (SELECT MAX(periode) FROM manpower_month)
  AND UPPER(COALESCE(m.jabatan, '')) LIKE '%TYRE%'
GROUP BY 2, 3, 4, 5
ORDER BY jumlah DESC;

WITH latest AS (
  SELECT DISTINCT ON (m.nrp) m.nrp, m.jabatan
  FROM manpower_month m
  ORDER BY m.nrp, m.periode DESC
), upd AS (
  UPDATE manpower_profile p
     SET section    = 'Tyre',
         crew       = COALESCE(p.crew, 'Big Wheel'),
         status     = CASE WHEN UPPER(l.jabatan) LIKE '%REPAIRMAN%'
                           THEN 'Repairman' ELSE 'Staff' END,
         updated_by = 'validasi: section tyre',
         updated_at = now()
    FROM latest l
   WHERE l.nrp = p.nrp
     AND p.auto                              -- hanya hasil tebakan
     AND UPPER(COALESCE(l.jabatan, '')) LIKE '%TYRE%'
     AND (p.section IS DISTINCT FROM 'Tyre'
          OR p.status IS DISTINCT FROM (CASE WHEN UPPER(l.jabatan) LIKE '%REPAIRMAN%'
                                             THEN 'Repairman' ELSE 'Staff' END))
  RETURNING p.nrp
)
SELECT 'diperbarui' AS catatan, COUNT(*) AS jumlah FROM upd;

-- Kondisi sesudah.
SELECT 'SESUDAH' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       p.auto,
       COUNT(*) AS jumlah
FROM manpower_month m
JOIN manpower_profile p ON p.nrp = m.nrp
WHERE m.periode = (SELECT MAX(periode) FROM manpower_month)
  AND UPPER(COALESCE(m.jabatan, '')) LIKE '%TYRE%'
GROUP BY 2, 3, 4, 5
ORDER BY jumlah DESC;

COMMIT;

-- Verifikasi akhir: baris hasil tebakan berjabatan TYRE yang belum 'Tyre',
-- atau masih berstatus 'Mekanik'. Hasilnya harus 0.
WITH latest AS (
  SELECT DISTINCT ON (m.nrp) m.nrp, m.jabatan
  FROM manpower_month m
  ORDER BY m.nrp, m.periode DESC
)
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM manpower_profile p
JOIN latest l ON l.nrp = p.nrp
WHERE p.auto
  AND UPPER(COALESCE(l.jabatan, '')) LIKE '%TYRE%'
  AND (p.section IS DISTINCT FROM 'Tyre' OR p.status = 'Mekanik');
