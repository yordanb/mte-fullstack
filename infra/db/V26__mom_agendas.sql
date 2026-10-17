-- V26: Agenda meeting — grouping action items per agenda topic
-- Satu meeting bisa punya beberapa agenda, masing-masing punya discussion + items

CREATE TABLE IF NOT EXISTS mom_agendas (
    id          SERIAL PRIMARY KEY,
    meeting_id  INTEGER NOT NULL REFERENCES mom_meetings(id) ON DELETE CASCADE,
    seq         INTEGER NOT NULL DEFAULT 0,
    title       TEXT NOT NULL,
    discussion  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mom_agendas_meeting ON mom_agendas (meeting_id);

-- Link items ke agenda (nullable untuk backward compat)
ALTER TABLE mom_items ADD COLUMN IF NOT EXISTS agenda_id INTEGER REFERENCES mom_agendas(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_mom_items_agenda ON mom_items (agenda_id);

DROP TRIGGER IF EXISTS trg_mom_agendas_updated ON mom_agendas;
CREATE TRIGGER trg_mom_agendas_updated BEFORE UPDATE ON mom_agendas
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Backfill: buat default agenda untuk meeting yang sudah punya items tanpa agenda
INSERT INTO mom_agendas(meeting_id, seq, title, discussion)
SELECT m.id, 0, 'General', NULL
FROM mom_meetings m
WHERE EXISTS (SELECT 1 FROM mom_items i WHERE i.meeting_id = m.id AND i.agenda_id IS NULL)
ON CONFLICT DO NOTHING;

-- Link orphan items ke default agenda
UPDATE mom_items i
SET agenda_id = a.id
FROM mom_agendas a
WHERE i.meeting_id = a.meeting_id
  AND i.agenda_id IS NULL
  AND a.title = 'General';
