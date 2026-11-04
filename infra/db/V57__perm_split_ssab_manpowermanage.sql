-- V57: Pecahkan izin supaya SETIAP halaman terpetakan hak aksesnya sendiri:
--   "ss" (Sugestion System)  vs "ssab" (SS AB)   — sebelumnya berbagi "ss"
--   "manpower" (Inovasi)      vs "manpowermanage" (Manajemen Manpower) — sebelumnya berbagi "manpower"
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V57__perm_split_ssab_manpowermanage.sql

ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','yazudc','ewacs','tarsupport','ss','ssab','proker',
    'prokerbooster','prokerinjector','manpower','manpowermanage','hourmeter'
  ));

-- ── ssab: salin izin dari "ss" (akses yang sudah jalan tidak berubah) ──
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'ssab', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'ss'
ON CONFLICT (role, menu) DO NOTHING;

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'ssab', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'ssab');

-- ── manpowermanage: salin izin dari "manpower" ──
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'manpowermanage', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'manpower'
ON CONFLICT (role, menu) DO NOTHING;

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'manpowermanage', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'manpowermanage');
