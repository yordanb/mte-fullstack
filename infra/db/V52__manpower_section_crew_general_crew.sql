-- V52: izinkan nilai "General Crew" (dan "Tyre") pada Section & Crew
-- manpower_profile.
--
-- Menu dropdown halaman Manpower kini menawarkan "General Crew" pada
-- Section/Crew (lihat SECTIONS/CREWS di apps/api/app/api/v1/manpower.py),
-- tetapi CHECK constraint dari V47 (Section) dan V50 (Crew) belum
-- mengizinkannya sehingga simpan menghasilkan error 500:
--   update or insert on table "manpower_profile" violates check constraint.
--
-- Section: daftar baru = V47 + 'Tyre' + 'General Crew'
--          ('Tyre' sudah tersedia di daftar Python sejak V49)
-- Crew   : daftar baru = V50 + 'General Crew'
--
-- Status sudah diizinkan oleh V51. Baris lama tetap valid karena semua
-- nilai lama masih ada di daftar baru.
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V52__manpower_section_crew_general_crew.sql

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_section_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_section_check CHECK (
    section IS NULL OR section IN (
      'Big Wheel - PCH', 'SPEX Mobile - Lighting',
      'SPEX Pumping - Fabrication', 'LCE', 'MTE', 'Tyre', 'Dept Head',
      'General Crew'
    )
  );

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_crew_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_crew_check CHECK (
    crew IS NULL OR crew IN (
      'Big Wheel', 'PCH', 'Mobile', 'Lighting', 'Pumping', 'Tyre',
      'MTE', 'LCE', 'General Crew'
    )
  );

-- Ringkasan (muncul di output psql).
SELECT 'section' AS dimensi, COALESCE(section, '(kosong)') AS nilai, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1, 2
UNION ALL
SELECT 'crew', COALESCE(crew, '(kosong)'), COUNT(*)
FROM manpower_profile
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
