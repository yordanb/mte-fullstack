-- V11 avatar user untuk menu profil.
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar TEXT NULL;
