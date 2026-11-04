-- V55: Tambah role "adm lce" (admin LCE) — inherit inputer seperti "adm te".
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V55__role_adm_lce.sql

-- 1. Update users_role_check
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer',
    'planner','group leader','section head','adm te','adm lce'));

-- 2. Update role_permissions_role_check
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_role_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer',
    'planner','group leader','section head','adm te','adm lce'));

-- 3. Seed default permissions: copy dari "adm te" (inputer-equivalent)
--    Bisa disesuaikan lewat matriks izin di halaman Manajemen User.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'adm lce', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role = 'adm te'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman bila baris "adm te" belum pernah di-seed
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'adm lce', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role = 'inputer'
  AND NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'adm lce')
ON CONFLICT (role, menu) DO NOTHING;
