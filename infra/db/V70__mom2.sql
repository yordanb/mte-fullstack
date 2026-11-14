-- V70: Minute of Meeting 2 — format weekly SPEX Pumping (MOM 2)
-- Meeting: periode (W2 November 2026), tanggal, peserta, status open/closed
-- Items: tabel flat seperti Excel — ISSUED (topik), NEED SUPPORT (deskripsi),
--        BY (pelapor), PIC (kode role), DUE DATE (date + flag fleksibel),
--        STATUS (open/progress/close), REMARK.

CREATE TABLE IF NOT EXISTS mom2_meetings (
    id           SERIAL PRIMARY KEY,
    period       TEXT NOT NULL,              -- contoh: 'W2 November 2026'
    week         INTEGER,                    -- 1..5 (dari periode)
    meeting_date DATE NOT NULL,
    participants TEXT,                       -- 'PIC : Pak Abu S, ...'
    status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
    created_by   VARCHAR(100),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mom2_meetings_date ON mom2_meetings (meeting_date DESC);
CREATE INDEX IF NOT EXISTS idx_mom2_meetings_status ON mom2_meetings (status);

CREATE TABLE IF NOT EXISTS mom2_items (
    id              SERIAL PRIMARY KEY,
    meeting_id      INTEGER NOT NULL REFERENCES mom2_meetings(id) ON DELETE CASCADE,
    seq             INTEGER NOT NULL DEFAULT 0,        -- nomor urut (NO)
    topic           TEXT,                              -- kolom ISSUED
    description     TEXT NOT NULL,                     -- kolom NEED SUPPORT (boleh multiline)
    reporter        VARCHAR(100),                      -- kolom BY
    pic             VARCHAR(100),                      -- kode role, contoh 'GL, SH'
    due_date        DATE,
    due_flex        BOOLEAN NOT NULL DEFAULT FALSE,    -- TRUE = tanggal fleksibel/rentang ('21/22/2026')
    due_text        TEXT,                              -- teks asli dari Excel untuk referensi
    status          TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','progress','close')),
    remark          TEXT,
    carried_from_id INTEGER REFERENCES mom2_items(id) ON DELETE SET NULL, -- item minggu lalu asal
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mom2_items_meeting ON mom2_items (meeting_id);
CREATE INDEX IF NOT EXISTS idx_mom2_items_status ON mom2_items (status);

DROP TRIGGER IF EXISTS trg_mom2_meetings_updated ON mom2_meetings;
CREATE TRIGGER trg_mom2_meetings_updated BEFORE UPDATE ON mom2_meetings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_mom2_items_updated ON mom2_items;
CREATE TRIGGER trg_mom2_items_updated BEFORE UPDATE ON mom2_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu 'mom2' di matriks izin
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel'
  ));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','mom2',TRUE,TRUE,TRUE,TRUE),
  ('inputer','mom2',TRUE,TRUE,TRUE,TRUE),
  ('mekanik','mom2',TRUE,TRUE,TRUE,FALSE),
  ('viewer','mom2',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
