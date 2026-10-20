-- V27: Riwayat — issue tracking dengan progress timeline + parts requirement
-- 3 tabel: riwayat_issues, riwayat_progress, riwayat_parts

CREATE TABLE IF NOT EXISTS riwayat_issues (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    cn          VARCHAR(20) REFERENCES equipment(cn) ON DELETE SET NULL,
    category     TEXT NOT NULL DEFAULT 'Breakdown Unscheduled'
        CHECK (category IN ('Breakdown Unscheduled','Breakdown Scheduled','Maintenance Rutin','Inspection','Modification','Lainnya')),
    status      TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','in_progress','waiting_part','waiting_crew','closed')),
    start_date  DATE NOT NULL,
    end_date    DATE,
    description TEXT,
    created_by  VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_riwayat_issues_status ON riwayat_issues (status);
CREATE INDEX IF NOT EXISTS idx_riwayat_issues_cn ON riwayat_issues (cn);
CREATE INDEX IF NOT EXISTS idx_riwayat_issues_start ON riwayat_issues (start_date DESC);

CREATE TABLE IF NOT EXISTS riwayat_progress (
    id          SERIAL PRIMARY KEY,
    issue_id   INTEGER NOT NULL REFERENCES riwayat_issues(id) ON DELETE CASCADE,
    seq         INTEGER NOT NULL DEFAULT 0,
    log_date    TIMESTAMPTZ NOT NULL DEFAULT now(),
    description TEXT NOT NULL,
    part_required BOOLEAN NOT NULL DEFAULT FALSE,
    created_by  VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_riwayat_progress_issue ON riwayat_progress (issue_id);
CREATE INDEX IF NOT EXISTS idx_riwayat_progress_date ON riwayat_progress (log_date DESC);

CREATE TABLE IF NOT EXISTS riwayat_parts (
    id          SERIAL PRIMARY KEY,
    issue_id   INTEGER NOT NULL REFERENCES riwayat_issues(id) ON DELETE CASCADE,
    part_name   TEXT NOT NULL,
    qty         INTEGER NOT NULL DEFAULT 1,
    status      TEXT NOT NULL DEFAULT 'needed'
        CHECK (status IN ('needed','ordered','received','installed','cancelled')),
    eta         DATE,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_riwayat_parts_issue ON riwayat_parts (issue_id);

DROP TRIGGER IF EXISTS trg_riwayat_issues_updated ON riwayat_issues;
CREATE TRIGGER trg_riwayat_issues_updated BEFORE UPDATE ON riwayat_issues
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_riwayat_progress_updated ON riwayat_progress;
CREATE TRIGGER trg_riwayat_progress_updated BEFORE UPDATE ON riwayat_progress
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_riwayat_parts_updated ON riwayat_parts;
CREATE TRIGGER trg_riwayat_parts_updated BEFORE UPDATE ON riwayat_parts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu 'riwayat' di matriks izin
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN ('dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','riwayat',TRUE,TRUE,TRUE,TRUE),
  ('inputer','riwayat',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','riwayat',TRUE,TRUE,TRUE,FALSE),
  ('viewer','riwayat',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;