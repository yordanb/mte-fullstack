-- V9: role inputer (ganti operator) + matriks izin per menu.
-- Urutan penting: drop CHECK lama dulu (inputer belum lolos CHECK lama).
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
UPDATE users SET role='inputer' WHERE role='operator';
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin','inputer','viewer'));
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'viewer';

CREATE TABLE IF NOT EXISTS role_permissions (
  role VARCHAR(20) NOT NULL CHECK (role IN ('admin','inputer','viewer')),
  menu VARCHAR(20) NOT NULL CHECK (menu IN
    ('dashboard','dbr','performance','activity','equipment','vessel','import')),
  can_view BOOLEAN NOT NULL DEFAULT FALSE,
  can_add BOOLEAN NOT NULL DEFAULT FALSE,
  can_edit BOOLEAN NOT NULL DEFAULT FALSE,
  can_delete BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (role, menu)
);

-- Seed default (DO NOTHING agar kustomisasi admin tak tertimpa saat rerun).
-- admin: penuh. inputer: lihat semua + tulis di activity/equipment/import.
-- viewer: lihat semua kecuali import, tanpa tulis.
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'admin', m, TRUE, TRUE, TRUE, TRUE FROM (VALUES
  ('dashboard'),('dbr'),('performance'),('activity'),('equipment'),('vessel'),('import')) AS t(m)
ON CONFLICT (role,menu) DO NOTHING;

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'inputer', m, TRUE,
  m IN ('activity','equipment','import'),
  m IN ('activity','equipment','import'),
  m IN ('activity','equipment','import')
FROM (VALUES
  ('dashboard'),('dbr'),('performance'),('activity'),('equipment'),('vessel'),('import')) AS t(m)
ON CONFLICT (role,menu) DO NOTHING;

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'viewer', m, m <> 'import', FALSE, FALSE, FALSE FROM (VALUES
  ('dashboard'),('dbr'),('performance'),('activity'),('equipment'),('vessel'),('import')) AS t(m)
ON CONFLICT (role,menu) DO NOTHING;
