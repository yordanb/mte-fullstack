-- V5 DBR daily breakdown
CREATE TABLE IF NOT EXISTS dbr_records (
  id BIGSERIAL PRIMARY KEY,
  date DATE NOT NULL,
  cn VARCHAR(50) NOT NULL,
  cn_prefix CHAR(2) GENERATED ALWAYS AS (LEFT(UPPER(TRIM(BOTH FROM COALESCE(cn,''))), 2)) STORED,
  section VARCHAR(50) NULL,
  trouble TEXT NULL,
  code VARCHAR(50) NULL,
  hm_start TEXT NULL,
  loc VARCHAR(100) NULL,
  start_breakdown TEXT NULL,
  start_time TEXT NULL,
  finish_time TEXT NULL,
  total TEXT NULL,
  wo VARCHAR(100) NULL,
  notification TEXT NULL,
  action TEXT NULL,
  mechanic VARCHAR(200) NULL,
  gl VARCHAR(200) NULL,
  import_id UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT dbr_unique UNIQUE (date, cn, start_breakdown)
);
CREATE INDEX IF NOT EXISTS idx_dbr_date ON dbr_records (date DESC);
CREATE INDEX IF NOT EXISTS idx_dbr_cn_date ON dbr_records (cn, date DESC);
CREATE INDEX IF NOT EXISTS idx_dbr_prefix_date ON dbr_records (cn_prefix, date DESC);
CREATE INDEX IF NOT EXISTS idx_dbr_code_date ON dbr_records (code, date DESC);
