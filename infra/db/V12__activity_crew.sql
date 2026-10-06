-- V12 kolom crew pada aktivitas (wajib di aplikasi, NULL untuk data lama).
ALTER TABLE activities ADD COLUMN IF NOT EXISTS crew TEXT NULL;
CREATE INDEX IF NOT EXISTS idx_act_crew ON activities (crew);
CREATE INDEX IF NOT EXISTS idx_act_cat ON activities (category);
