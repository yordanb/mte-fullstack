-- V36: menu baru "TAR Support" di grup Technical Expert
-- Halaman masih placeholder (konten kosong), tapi menu + izin sudah disiapkan.

-- 1) Perluas CHECK constraint menu permission matrix
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport'
  ));

-- 2) Seed default: admin full, inputer+mekanik+planner+group leader+adm te write-no-delete,
--    viewer+section head read-only
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','tarsupport',TRUE,TRUE,TRUE,TRUE),
  ('inputer','tarsupport',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','tarsupport',TRUE,TRUE,TRUE,FALSE),
  ('viewer','tarsupport',TRUE,FALSE,FALSE,FALSE),
  ('planner','tarsupport',TRUE,TRUE,TRUE,FALSE),
  ('group leader','tarsupport',TRUE,TRUE,TRUE,FALSE),
  ('section head','tarsupport',TRUE,FALSE,FALSE,FALSE),
  ('adm te','tarsupport',TRUE,TRUE,TRUE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
