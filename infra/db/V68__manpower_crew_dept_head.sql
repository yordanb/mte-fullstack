-- V68: tambah Crew "Dept Head" pada pengelompokan manpower.
--
-- Kategori "Dept Head" ditambahkan ke daftar opsi CREWS di
-- apps/api/app/api/v1/manpower.py agar selaras dengan Section (Dept Head
-- sudah ada di daftar Section sejak V47). Namun CHECK constraint crew di
-- tabel manpower_profile (V50 + 'General Crew' dari V52) belum
-- mengizinkannya, sehingga saat menyimpan Crew "Dept Head" gagal dengan
-- HTTP 500:
--   update or insert on table "manpower_profile"
--   violates check constraint "manpower_profile_crew_check".
--
-- Crew: daftar baru = V52 + 'Dept Head'.
-- Section & Status tidak diubah ('Dept Head' & General Crew sudah
-- diizinkan oleh V47/V48/V52/V51). Baris lama tetap valid karena semua
-- nilai lama masih ada di daftar baru.
--
-- Jalankan:
--   docker compose up -d --build api   -- atau manual:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V68__manpower_crew_dept_head.sql

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_crew_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_crew_check CHECK (
    crew IS NULL OR crew IN (
      'Big Wheel', 'PCH', 'Mobile', 'Lighting', 'Pumping', 'Tyre',
      'MTE', 'LCE', 'Dept Head', 'General Crew'
    )
  );

-- Ringkasan (muncul di output psql).
SELECT COALESCE(crew, '(kosong)') AS crew, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1
ORDER BY jumlah DESC, 1;
