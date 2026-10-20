-- V28: Evidence foto/file untuk progress riwayat

CREATE TABLE IF NOT EXISTS riwayat_progress_photos (
    id          SERIAL PRIMARY KEY,
    progress_id INTEGER NOT NULL REFERENCES riwayat_progress(id) ON DELETE CASCADE,
    filename    TEXT NOT NULL,
    orig_name   TEXT NOT NULL,
    content_type TEXT,
    size        BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_riwayat_progress_photos_pid ON riwayat_progress_photos (progress_id);