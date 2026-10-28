-- V46: kebijakan data hanya DEPT SPL2.
--
-- Keputusan: seluruh data yang dipakai aplikasi hanya untuk DEPT SPL2.
--   * import SS dan import Manpower sekarang melewati baris DEPT selain SPL2
--   * baris lama (hasil import sebelum filter aktif) dibersihkan di sini
--
-- Dashboard SS dan Manpower akan ikut berubah: SPL1/STYR tidak lagi muncul.
--
-- Baris yang dihapus disimpan dulu ke tabel arsip supaya masih bisa dipulihkan
-- bila ternyata dibutuhkan:
--   INSERT INTO ss_report SELECT * FROM ss_report_nonspl2_archive
--     ON CONFLICT (no_ss) DO NOTHING;
--   INSERT INTO manpower_month SELECT * FROM manpower_month_nonspl2_archive
--     ON CONFLICT (periode, nrp) DO NOTHING;
-- Tabel arsip boleh dihapus kapan saja setelah yakin:
--   DROP TABLE IF EXISTS ss_report_nonspl2_archive, manpower_month_nonspl2_archive;

DO $$
BEGIN
  IF to_regclass('public.ss_report_nonspl2_archive') IS NULL THEN
    CREATE TABLE public.ss_report_nonspl2_archive AS
      SELECT * FROM ss_report
      WHERE dept IS NULL OR UPPER(TRIM(dept)) <> 'SPL2';
  END IF;

  IF to_regclass('public.manpower_month_nonspl2_archive') IS NULL THEN
    CREATE TABLE public.manpower_month_nonspl2_archive AS
      SELECT * FROM manpower_month
      WHERE dept IS NULL OR UPPER(TRIM(dept)) <> 'SPL2';
  END IF;
END $$;

DELETE FROM ss_report
WHERE dept IS NULL OR UPPER(TRIM(dept)) <> 'SPL2';

DELETE FROM manpower_month
WHERE dept IS NULL OR UPPER(TRIM(dept)) <> 'SPL2';

-- Ringkasan sisa data (muncul di output psql).
SELECT 'ss_report' AS tabel, COUNT(*) AS baris_tersisa,
       COUNT(*) FILTER (WHERE dept = 'SPL2') AS spl2
FROM ss_report
UNION ALL
SELECT 'manpower_month', COUNT(*), COUNT(*) FILTER (WHERE dept = 'SPL2')
FROM manpower_month;
