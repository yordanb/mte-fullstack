-- V50: tambah Crew "MTE" dan "LCE".
--
-- Orang dengan Section MTE / LCE sekarang juga diberi Crew MTE / LCE, dan
-- FABRICATION GL (Section SPEX Pumping - Fabrication) masuk Crew "Pumping".
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V50__manpower_crew_mte_lce.sql

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_crew_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_crew_check CHECK (
    crew IS NULL OR crew IN (
      'Big Wheel', 'PCH', 'Mobile', 'Lighting', 'Pumping', 'Tyre',
      'MTE', 'LCE'
    )
  );

-- Ringkasan (muncul di output psql).
SELECT COALESCE(crew, '(kosong)') AS crew, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1
ORDER BY jumlah DESC, 1;
