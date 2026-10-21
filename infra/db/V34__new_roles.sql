-- V34: Tambah role planner, group leader, section head, adm te
-- Inheritance (di deps.py):
--   planner      → inherit inputer  (full write, no delete)
--   group leader → inherit mekanik  (write activity/equipment/riwayat, no delete)
--   section head → inherit viewer   (read-only)
--   adm te       → inherit inputer  (full write, no delete)

-- 1. Update users_role_check
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer',
    'planner','group leader','section head','adm te'));

-- 2. Update role_permissions_role_check
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_role_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_role_check
  CHECK (role IN ('admin','inputer','mekanik','viewer',
    'planner','group leader','section head','adm te'));

-- 3. Seed default permissions untuk role baru
--    planner = copy dari inputer
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'planner', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role='inputer'
ON CONFLICT (role,menu) DO NOTHING;

--    group leader = copy dari mekanik
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'group leader', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role='mekanik'
ON CONFLICT (role,menu) DO NOTHING;

--    section head = copy dari viewer
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'section head', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role='viewer'
ON CONFLICT (role,menu) DO NOTHING;

--    adm te = copy dari inputer
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete)
SELECT 'adm te', menu, can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE role='inputer'
ON CONFLICT (role,menu) DO NOTHING;