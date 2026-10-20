-- V30: Evidence foto/file untuk part request di riwayat

CREATE TABLE IF NOT EXISTS riwayat_part_photos (
    id          SERIAL PRIMARY KEY,
    part_id     INTEGER NOT NULL REFERENCES riwayat_parts(id) ON DELETE CASCADE,
    filename    TEXT NOT NULL,
    orig_name   TEXT NOT NULL,
    content_type TEXT,
    size        BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_riwayat_part_photos_pid ON riwayat_part_photos (part_id);