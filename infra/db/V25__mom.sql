-- V25: Minute of Meeting — tabel meetings + action items
-- Meeting: judul, tanggal, lokasi, kategori, status open/closed
-- Items: no urut, deskripsi, PIC, due date, priority, status, notes

CREATE TABLE IF NOT EXISTS mom_meetings (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    meeting_date DATE NOT NULL,
    location    TEXT,
    category    TEXT NOT NULL DEFAULT 'Operasional',
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
    created_by  VARCHAR(100),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mom_meetings_date ON mom_meetings (meeting_date DESC);
CREATE INDEX IF NOT EXISTS idx_mom_meetings_status ON mom_meetings (status);

CREATE TABLE IF NOT EXISTS mom_items (
    id          SERIAL PRIMARY KEY,
    meeting_id  INTEGER NOT NULL REFERENCES mom_meetings(id) ON DELETE CASCADE,
    item_no     INTEGER NOT NULL DEFAULT 0,
    description TEXT NOT NULL,
    pic         VARCHAR(100),
    due_date    DATE,
    priority    TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('high','medium','low')),
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed')),
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mom_items_meeting ON mom_items (meeting_id);
CREATE INDEX IF NOT EXISTS idx_mom_items_status ON mom_items (status);

DROP TRIGGER IF EXISTS trg_mom_meetings_updated ON mom_meetings;
CREATE TRIGGER trg_mom_meetings_updated BEFORE UPDATE ON mom_meetings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_mom_items_updated ON mom_items;
CREATE TRIGGER trg_mom_items_updated BEFORE UPDATE ON mom_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu 'mom' di matriks izin
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN ('dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','mom',TRUE,TRUE,TRUE,TRUE),
  ('inputer','mom',TRUE,TRUE,TRUE,TRUE),
  ('mekanik','mom',TRUE,TRUE,TRUE,FALSE),
  ('viewer','mom',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
