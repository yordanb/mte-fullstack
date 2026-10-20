-- V29: Link part ke progress entry tertentu (nullable, kompatibel dengan data lama)

ALTER TABLE riwayat_parts ADD COLUMN IF NOT EXISTS progress_id INTEGER
    REFERENCES riwayat_progress(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_riwayat_parts_progress ON riwayat_parts (progress_id)
    WHERE progress_id IS NOT NULL;