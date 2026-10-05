-- V3 progress import agar upload puluhan ribu baris terpantau
ALTER TABLE imports ADD COLUMN IF NOT EXISTS processed_rows INT NOT NULL DEFAULT 0;
ALTER TABLE imports DROP CONSTRAINT IF EXISTS imports_status_check;
ALTER TABLE imports ADD CONSTRAINT imports_status_check
  CHECK (status IN ('PENDING','PROCESSING','VALIDATED','COMMITTED','FAILED'));
