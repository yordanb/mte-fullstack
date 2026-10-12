-- V18 project management: project -> tahap -> update + foto eviden.
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NULL,
  pic VARCHAR(100) NULL,
  cn VARCHAR(20) NULL REFERENCES equipment(cn) ON DELETE SET NULL,
  crew TEXT NULL,
  target_date DATE NULL,
  created_by VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_proj_target ON projects (target_date);

CREATE TABLE IF NOT EXISTS project_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  plan_start DATE NULL,
  plan_end DATE NULL,
  weight NUMERIC(6,2) NOT NULL DEFAULT 0,
  sort INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_stage_dates CHECK (plan_end IS NULL OR plan_start IS NULL OR plan_end >= plan_start)
);
CREATE INDEX IF NOT EXISTS idx_stage_proj ON project_stages (project_id, sort);

CREATE TABLE IF NOT EXISTS project_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id UUID NOT NULL REFERENCES project_stages(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  progress INT NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  status VARCHAR(20) NOT NULL DEFAULT 'BELUM_MULAI'
    CHECK (status IN ('BELUM_MULAI','ON_TRACK','AT_RISK','TERLAMBAT','SELESAI')),
  note TEXT NULL,
  created_by VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_upd_stage ON project_updates (stage_id, date DESC);

CREATE TABLE IF NOT EXISTS project_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  update_id UUID NOT NULL REFERENCES project_updates(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  orig_name TEXT NULL,
  content_type TEXT NULL,
  size BIGINT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_projphoto_upd ON project_photos (update_id);

DROP TRIGGER IF EXISTS trg_projects_updated ON projects;
CREATE TRIGGER trg_projects_updated BEFORE UPDATE ON projects
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check CHECK (menu IN
  ('dashboard','dbr','performance','activity','timeline','equipment','fui','sugfui','fureport',
   'project','vessel','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','project',TRUE,TRUE,TRUE,TRUE),
  ('inputer','project',TRUE,TRUE,TRUE,TRUE),
  ('viewer','project',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
