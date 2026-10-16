-- V24: Tambah role 'mekanik' ke users + role_permissions
-- Mekanik: lihat semua menu (kecuali import), tulis di activity & equipment

-- 1. Update users_role_check
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer'));

-- 2. Update role_permissions_role_check
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_role_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer'));

-- 3. Update role_permissions_menu_check (semua menu sampai V21)
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN ('dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','import'));

-- 4. Seed default permissions untuk mekanik
--    Lihat semua (kecuali import), tulis hanya di activity & equipment
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'mekanik', m,
  m <> 'import',
  m IN ('activity','equipment'),
  m IN ('activity','equipment'),
  m IN ('activity','equipment')
FROM (VALUES
  ('dashboard'),('dbr'),('performance'),('activity'),('equipment'),
  ('fui'),('sugfui'),('fureport'),('timeline'),('project'),('bomak'),('staging'),('import')
) AS t(m)
ON CONFLICT (role,menu) DO NOTHING;
