-- V10 audit log aktivitas (login + akses API). Ditulis middleware, kecuali /health & /docs.
CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID NULL,
  username TEXT NULL,          -- snapshot (tetap ada walau user dihapus)
  role VARCHAR(20) NULL,
  method VARCHAR(10) NOT NULL,
  path TEXT NOT NULL,
  status INT NOT NULL,
  ip VARCHAR(45) NULL,
  user_agent TEXT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs (username, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_path ON audit_logs (path, created_at DESC);
