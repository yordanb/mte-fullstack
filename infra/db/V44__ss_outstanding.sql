-- V44: SS — dukungan upload ReportOutstandingSS (SS yang belum dinilai).
--
-- Sebelumnya import SS hanya menerima ReportSSClosedDistrict (SS yang sudah
-- dinilai: ada GRADE/KATEGORI/REWARD). File ReportOutstandingSS_KIDE.xlsx
-- berisi SS yang masih berjalan dengan kolom berbeda:
--   NO SS | TANGGAL LAPORAN | NAMA | NRP | DEPT | DIVISI | DISTRIK | JUDUL |
--   MANAGEMENT | STATUS
--
-- Baris outstanding disimpan di tabel yang sama (kunci no_ss) supaya saat SS
-- tsb akhirnya dinilai dan masuk ReportSSClosedDistrict, baris yang sama
-- berubah menjadi approved (grade terisi, outstanding = FALSE) tanpa duplikat.
--
-- Kolom tambahan:
--   divisi        : DIVISI (OPRT/PLAN/ENGI/...) — hanya ada di file outstanding
--   management    : nama penanggung jawab management pada file outstanding
--   status_ss     : tahap workflow di file outstanding
--                   (Menunggu Penilaian Oleh SH / GL, SS revisi, Input Penilaian, ...)
--   outstanding   : TRUE bila SS masih berjalan (belum dinilai & belum approved)
--   outstanding_at: kapan terakhir terlihat di file outstanding

ALTER TABLE ss_report
  ADD COLUMN IF NOT EXISTS divisi         TEXT NULL,
  ADD COLUMN IF NOT EXISTS management     TEXT NULL,
  ADD COLUMN IF NOT EXISTS status_ss      TEXT NULL,
  ADD COLUMN IF NOT EXISTS outstanding    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS outstanding_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_ss_outstanding ON ss_report (outstanding);
CREATE INDEX IF NOT EXISTS idx_ss_status_ss ON ss_report (status_ss);

-- Data lama (semuanya dari ReportSSClosedDistrict) otomatis outstanding = FALSE.
