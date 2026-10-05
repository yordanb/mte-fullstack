-- V4: lab_no alfanumerik (P24001526) + condition CAUTION
-- Materialized view menyimpan tipe lama, harus dibuat ulang.
DROP MATERIALIZED VIEW IF EXISTS mv_latest_status;
ALTER TABLE oil_lab_result ALTER COLUMN lab_no TYPE TEXT;
ALTER TABLE oil_lab_result DROP CONSTRAINT IF EXISTS oil_lab_result_condition_check;
ALTER TABLE oil_lab_result ADD CONSTRAINT oil_lab_result_condition_check
  CHECK ("condition" IS NULL OR "condition" IN ('NORMAL', 'CRITICAL', 'WARNING', 'CAUTION'));
CREATE MATERIALIZED VIEW mv_latest_status AS
SELECT DISTINCT ON (vesselid, unit_id) *
FROM oil_lab_result
ORDER BY vesselid, unit_id, sample_date DESC, lab_no DESC;
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_latest ON mv_latest_status (vesselid, unit_id);
