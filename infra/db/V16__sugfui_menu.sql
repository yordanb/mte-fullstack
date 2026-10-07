-- V16 menu Suggestion FUI pada matriks izin.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check CHECK (menu IN
  ('dashboard','dbr','performance','activity','equipment','fui','sugfui','vessel','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','sugfui',TRUE,TRUE,TRUE,TRUE),
  ('inputer','sugfui',TRUE,FALSE,FALSE,FALSE),
  ('viewer','sugfui',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
