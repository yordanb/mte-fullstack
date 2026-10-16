-- V23: Tambah kolom shift ke activities untuk Daily Check Dragflow
ALTER TABLE activities ADD COLUMN IF NOT EXISTS shift SMALLINT NULL;
