-- V13 hourmeter pada aktivitas (analisa lifetime per unit).
ALTER TABLE activities ADD COLUMN IF NOT EXISTS hm NUMERIC(12,2) NULL;
