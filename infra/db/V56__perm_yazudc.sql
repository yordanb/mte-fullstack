-- V56: Pecah izin menu Yazu jadi dua baris: "yazu" (Yazu P2H) dan "yazudc"
-- (Yazu Daily Check) agar bisa diatur terpisah di halaman Manajemen User.
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V56__perm_yazudc.sql

ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','yazudc','ewacs','tarsupport','ss','proker',
    'prokerbooster','prokerinjector','manpower','hourmeter'
  ));

-- Seed: salin izin dari "yazu" → "yazudc" supaya akses yang sudah jalan tidak berubah;
-- ke depan bisa dipisah lewat matriks izin di Manajemen User.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'yazudc', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'yazu'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman bila menu "yazu" belum pernah di-seed: default minimal admin.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', menu, TRUE, TRUE, TRUE, TRUE
FROM role_permissions WHERE menu = 'yazu'
  AND NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'yazudc')
ON CONFLICT (role, menu) DO NOTHING;
