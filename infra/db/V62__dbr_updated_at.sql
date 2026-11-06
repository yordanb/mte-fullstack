-- V62: kolom audit `updated_at` pada dbr_records.
--
-- Latar: label "Last update" di halaman DBR Breakdown sebelumnya bersumber dari
-- `imports.created_at` (waktu upload dimulai), bukan dari waktu data DBR benar-
-- benar berubah. Karena import memakai UPSERT (ON CONFLICT (date, cn,
-- start_breakdown) DO UPDATE), baris yang diperbarui tidak meninggalkan jejak
-- waktu sama sekali: `created_at` tetap waktu insert pertama.
--
-- Solusi: tambah kolom `updated_at` + trigger yang mengisinya otomatis pada
-- setiap UPDATE — sama seperti `oil_lab_result` (lihat V1). Idempoten:
-- ADD COLUMN IF NOT EXISTS + DROP/CREATE FUNCTION/TRIGGER.
--
-- Backfill: baris lama diset ke `created_at` agar label tidak menggantung pada
-- kolom NULL sebelum ada UPDATE berikutnya.
--
-- Rerun aman.

ALTER TABLE dbr_records
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE dbr_records SET updated_at = created_at WHERE updated_at IS NULL;

-- updated_at otomatis (fungsi set_updated_at() sudah dibuat di V1)
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dbr_updated ON dbr_records;
CREATE TRIGGER trg_dbr_updated BEFORE UPDATE ON dbr_records
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Percepat MAX(updated_at) + pencarian import terbaru pada label Last update.
CREATE INDEX IF NOT EXISTS idx_dbr_updated_at ON dbr_records (updated_at DESC);
