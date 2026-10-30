-- Selaraskan Status "General Crew" pada data lama (sekali jalan).
--
-- Aturan baru (lihat `classify()` di apps/api/app/api/v1/manpower.py):
--   JABATAN mengandung "GENERAL CREW" -> Section 'SPEX Pumping - Fabrication',
--   Crew 'Pumping', Status 'General Crew'.
--
-- Yang diubah HANYA baris yang masih hasil tebakan (auto = TRUE). Baris yang
-- sudah dikoreksi manual (auto = FALSE) tidak disentuh.
--
-- Status General Crew dikecualikan dari perhitungan performa (coverage SS,
-- innovator, SS per manpower, rasio Staff/Mekanik). Total manpower tetap utuh.
--
-- Prasyarat: V51 (Status 'General Crew').
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/manual/2026-10-30_manpower_general_crew.sql

\set ON_ERROR_STOP on
BEGIN;

-- NRP dengan jabatan GENERAL CREW pada snapshot terakhirnya.
CREATE TEMP TABLE gc_target ON COMMIT DROP AS
SELECT DISTINCT ON (m.nrp) m.nrp, m.jabatan
FROM manpower_month m
WHERE UPPER(m.jabatan) LIKE '%GENERAL CREW%'
ORDER BY m.nrp, m.periode DESC;

-- Kondisi sebelum perubahan (bukti untuk log psql).
SELECT 'SEBELUM' AS tahap,
       COALESCE(p.section, '(kosong)') AS section,
       COALESCE(p.crew, '(kosong)')    AS crew,
       COALESCE(p.status, '(kosong)')  AS status,
       p.auto,
       COUNT(*) AS jumlah
FROM gc_target t
LEFT JOIN manpower_profile p ON p.nrp = t.nrp
GROUP BY 2, 3, 4, 5
ORDER BY jumlah DESC, 2, 3, 4;

WITH upd AS (
  UPDATE manpower_profile p
     SET section    = 'SPEX Pumping - Fabrication',
         crew       = 'Pumping',
         status     = 'General Crew',
         updated_by = 'validasi: status general crew',
         updated_at = now()
    FROM gc_target t
   WHERE p.nrp = t.nrp
     AND p.auto                       -- hanya hasil tebakan
  RETURNING p.nrp
)
SELECT 'diperbarui' AS catatan, COUNT(*) AS jumlah FROM upd;

-- Ringkasan hasil.
SELECT 'SESUDAH' AS tahap, p.section, p.crew, p.status, p.auto, COUNT(*) AS jumlah
FROM gc_target t
JOIN manpower_profile p ON p.nrp = t.nrp
GROUP BY 2, 3, 4, 5
ORDER BY jumlah DESC;

-- Baris hasil tebakan yang tidak ikut diubah karena sudah dikoreksi manual.
SELECT 'dikoreksi manual (tidak diubah)' AS catatan, p.nrp, p.section, p.crew, p.status
FROM gc_target t
JOIN manpower_profile p ON p.nrp = t.nrp
WHERE NOT p.auto
ORDER BY p.nrp;

COMMIT;

-- Verifikasi akhir: hasilnya harus 0.
SELECT 'MASIH BELUM SESUAI' AS catatan, COUNT(*) AS jumlah
FROM (
  SELECT DISTINCT ON (m.nrp) m.nrp
  FROM manpower_month m
  WHERE UPPER(m.jabatan) LIKE '%GENERAL CREW%'
  ORDER BY m.nrp, m.periode DESC
) t
JOIN manpower_profile p ON p.nrp = t.nrp
WHERE p.auto
  AND (p.section IS DISTINCT FROM 'SPEX Pumping - Fabrication'
       OR p.crew   IS DISTINCT FROM 'Pumping'
       OR p.status IS DISTINCT FROM 'General Crew');
