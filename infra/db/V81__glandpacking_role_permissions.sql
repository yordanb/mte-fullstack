-- V81: Gland Packing permission seed
-- Add glandpacking to CHECK constraint on role_permissions
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','mom2','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','yazupumping',
    'yazupumpingdc','ewacs','tarsupport','ss','ssab','proker','prokerbooster',
    'prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo',
    'prokerpanel','prokerexhaust','prokerexhaustmits','prokerfandrebb',
    'prokerfandpompa','prokergmc','prokerfsbooster','prokerfsprimer',
    'prokerponton','prokersummary','glandpacking'
  ));
-- Seed default permission for glandpacking (view only for all roles, add/edit for admin)
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'glandpacking', TRUE, FALSE, FALSE, FALSE
FROM (SELECT 'admin' AS role UNION ALL SELECT 'inputer' UNION ALL SELECT 'mekanik' UNION ALL SELECT 'viewer') AS roles
ON CONFLICT (role, menu) DO NOTHING;
-- Admin has full permissions
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'glandpacking', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'glandpacking'
);