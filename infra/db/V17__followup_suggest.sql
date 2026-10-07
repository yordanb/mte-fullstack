-- V17 saran follow-up per sample oli + menu report.
CREATE TABLE IF NOT EXISTS followup_suggests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_no TEXT NOT NULL,
  suggestion TEXT NOT NULL,
  pic VARCHAR(100) NULL,
  created_by VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fusug_lab ON followup_suggests (lab_no, created_at DESC);

ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check CHECK (menu IN
  ('dashboard','dbr','performance','activity','equipment','fui','sugfui','fureport','vessel','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','fureport',TRUE,TRUE,TRUE,TRUE),
  ('inputer','fureport',TRUE,TRUE,FALSE,FALSE),
  ('viewer','fureport',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
