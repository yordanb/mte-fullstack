-- V51: tambah Status "General Crew" pada pengelompokan manpower.
--
-- Status ini dipakai untuk karyawan berjabatan "GENERAL CREW - PLANT 2".
-- General Crew TIDAK dihitung pada perhitungan performa di kedua halaman:
--   - Manpower Inovasi : coverage SS, innovator, SS per manpower
--   - Manpower         : persentase Staff / Mekanik / Repairman
-- Total manpower tetap ditampilkan penuh (termasuk General Crew).
--
-- Constraint di V48 hanya mengizinkan Staff/Mekanik/Repairman, jadi diganti.
-- Baris yang sudah ada tetap valid karena nilai lama masih termasuk daftar baru.
--
-- Jalankan:
--   docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V51__manpower_general_crew.sql

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_status_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_status_check CHECK (
    status IS NULL OR status IN ('Staff', 'Mekanik', 'Repairman', 'General Crew')
  );

-- Ringkasan (muncul di output psql).
SELECT COALESCE(status, '(kosong)') AS status, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1
ORDER BY jumlah DESC, 1;
