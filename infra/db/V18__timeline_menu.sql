-- V18: ganti menu vessel -> timeline (halaman Timeline Mingguan).
-- Hak vessel tiap role diwariskan ke timeline; default sisanya view-only.
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
UPDATE role_permissions SET menu='timeline' WHERE menu='vessel';
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check CHECK (menu IN
  ('dashboard','dbr','performance','activity','equipment','fui','sugfui','fureport','timeline','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','timeline',TRUE,TRUE,TRUE,TRUE),
  ('inputer','timeline',TRUE,FALSE,FALSE,FALSE),
  ('viewer','timeline',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
