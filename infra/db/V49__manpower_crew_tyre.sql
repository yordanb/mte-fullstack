-- V49: tambah Crew "Tyre" pada pengelompokan manpower.
--
-- Orang berjabatan TYRE... masuk Section + Crew Tyre (lihat `classify()` di
-- apps/api/app/api/v1/manpower.py). Constraint crew di V47 hanya mengizinkan
-- daftar lama, jadi diganti. Baris lama tetap valid karena nilai lamanya masih
-- termasuk daftar baru.
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V49__manpower_crew_tyre.sql

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_crew_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_crew_check CHECK (
    crew IS NULL OR crew IN (
      'Big Wheel', 'PCH', 'Mobile', 'Lighting', 'Pumping', 'Tyre'
    )
  );

-- Ringkasan (muncul di output psql).
SELECT COALESCE(crew, '(kosong)') AS crew, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1
ORDER BY jumlah DESC, 1;
