-- V69: Hourmeter — catat kapan nilai HM harian terakhir tercatat di database.
-- Dipakai tab "HM Dragflow" (kolom "HM Tercatat") dan bisa dipakai modul lain
-- yang perlu tahu kapan pembacaan HM terakhir masuk (upload Excel / input cepat).
-- Backfill: baris lama memakai waktu upload terakhir pada periode + unit itu,
-- fallback ke periode (tanggal 1) bila log upload tidak ada.
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V69__hourmeter_daily_updated.sql

ALTER TABLE hourmeter_daily ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

UPDATE hourmeter_daily d
SET updated_at = COALESCE(
  (SELECT MAX(l.uploaded_at) FROM hourmeter_upload_log l WHERE l.period = d.period),
  (d.period || '-01')::timestamptz
)
WHERE d.updated_at IS NULL;

ALTER TABLE hourmeter_daily ALTER COLUMN updated_at SET DEFAULT NOW();
UPDATE hourmeter_daily SET updated_at = NOW() WHERE updated_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hourmeter_daily_cn_updated
  ON hourmeter_daily (cn, updated_at DESC);
