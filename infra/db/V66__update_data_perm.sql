-- V66: "Update Data" (menu "import") jadi gerbang izin tersendiri.
--
-- Sebelumnya kartu upload di halaman Update Data tidak konsisten:
--   * Sugestion System  -> hard-code admin (tidak ikut matriks izin);
--   * Manpower Inovasi  -> ikut izin halaman "manpower";
--   * Report Oli / DBR  -> cek izin menu "import" (sudah benar).
-- Akibatnya sebuah role tidak bisa diberi hak upload di Update Data tanpa
-- sekaligus diberi akses ke halaman sumber (SS / Manpower).
--
-- Mulai sekarang SEMUA upload di Update Data mengikuti izin menu "import":
--   * halaman butuh "import.view", tombol upload butuh "import.add";
--   * backend POST /v1/imports, /v1/dbr/imports, /v1/ss/import,
--     /v1/manpower/import memakai require_menu("import","add").
-- Dengan begitu admin cukup mencentang izin menu "import" per role di halaman
-- Users, tanpa menyentuh izin halaman "ss"/"manpower".
--
-- Default: hanya admin + "adm te" yang boleh membuka & upload.
-- Role lain FALSE; admin dapat mengaktifkannya kapan saja lewat halaman Users.
--
-- Apply: docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V66__update_data_perm.sql

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete) VALUES
  ('admin',        'import', TRUE,  TRUE,  TRUE,  TRUE),
  ('adm te',       'import', TRUE,  TRUE,  TRUE,  FALSE),
  ('inputer',      'import', FALSE, FALSE, FALSE, FALSE),
  ('mekanik',      'import', FALSE, FALSE, FALSE, FALSE),
  ('viewer',       'import', FALSE, FALSE, FALSE, FALSE),
  ('planner',      'import', FALSE, FALSE, FALSE, FALSE),
  ('group leader', 'import', FALSE, FALSE, FALSE, FALSE),
  ('section head', 'import', FALSE, FALSE, FALSE, FALSE),
  ('adm lce',      'import', FALSE, FALSE, FALSE, FALSE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view   = EXCLUDED.can_view,
      can_add    = EXCLUDED.can_add,
      can_edit   = EXCLUDED.can_edit,
      can_delete = EXCLUDED.can_delete;
