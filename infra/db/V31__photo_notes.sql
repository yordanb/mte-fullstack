-- V31: Tambah kolom notes (keterangan) untuk evidence foto

ALTER TABLE riwayat_progress_photos ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE riwayat_part_photos ADD COLUMN IF NOT EXISTS notes TEXT;