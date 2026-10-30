-- V48: daftar pilihan Section/Status pada pengelompokan manpower diperluas.
--
-- Tambahan:
--   Section : "Tyre"      (Section Tyre tidak memakai status Mekanik)
--   Status  : "Repairman" (jabatan tyre repairman)
--
-- Constraint di V47 hanya mengizinkan daftar lama, jadi keduanya diganti.
-- Baris yang sudah ada tetap valid karena nilai lama masih termasuk daftar baru.

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_section_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_section_check CHECK (
    section IS NULL OR section IN (
      'Big Wheel - PCH', 'SPEX Mobile - Lighting',
      'SPEX Pumping - Fabrication', 'LCE', 'MTE', 'Tyre', 'Dept Head'
    )
  );

ALTER TABLE manpower_profile
  DROP CONSTRAINT IF EXISTS manpower_profile_status_check;
ALTER TABLE manpower_profile
  ADD CONSTRAINT manpower_profile_status_check CHECK (
    status IS NULL OR status IN ('Staff', 'Mekanik', 'Repairman')
  );

-- Ringkasan (muncul di output psql).
SELECT 'section' AS dimensi, COALESCE(section, '(kosong)') AS nilai, COUNT(*) AS jumlah
FROM manpower_profile
GROUP BY 1, 2
UNION ALL
SELECT 'status', COALESCE(status, '(kosong)'), COUNT(*)
FROM manpower_profile
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
