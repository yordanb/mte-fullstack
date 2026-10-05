-- V8 aktivitas harian + foto (volume /data/uploads, path di DB).
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NULL,
  category TEXT NULL,
  cn VARCHAR(20) NULL REFERENCES equipment(cn) ON DELETE SET NULL,
  created_by VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_act_date ON activities (date DESC);
CREATE INDEX IF NOT EXISTS idx_act_cn ON activities (cn);

CREATE TABLE IF NOT EXISTS activity_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,          -- nama file di disk
  orig_name TEXT NULL,
  content_type TEXT NULL,
  size BIGINT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_actphoto_act ON activity_photos (activity_id);

DROP TRIGGER IF EXISTS trg_activities_updated ON activities;
CREATE TRIGGER trg_activities_updated BEFORE UPDATE ON activities
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
