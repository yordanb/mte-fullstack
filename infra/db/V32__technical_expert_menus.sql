-- V32: Tambah menu PPM & Measurement di group Technical Expert

-- Tambah ke menu check constraint
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import', 'ppm', 'measurement'
  ));

-- Seed default: admin full, inputer+mekanik write-no-delete, viewer read-only
INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','ppm',TRUE,TRUE,TRUE,TRUE),
  ('admin','measurement',TRUE,TRUE,TRUE,TRUE),
  ('inputer','ppm',TRUE,TRUE,TRUE,FALSE),
  ('inputer','measurement',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','ppm',TRUE,TRUE,TRUE,FALSE),
  ('mekanik','measurement',TRUE, TRUE,TRUE,FALSE),
  ('viewer','ppm',TRUE,FALSE,FALSE,FALSE),
  ('viewer','measurement',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;