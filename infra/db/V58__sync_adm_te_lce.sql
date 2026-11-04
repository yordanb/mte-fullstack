-- V58: Tombol "Sync Manual" mengikuti matriks izin — beri role "adm te" &
-- "adm lce" akses sync (centang "Tambah") pada menu yazu & yazudc.
--
-- Backend /v1/yazu/sync & /v1/yazu-dc/sync kini require_menu(menu,'add'):
--   admin                → bypass (tombol selalu tampil)
--   adm te / adm lce     → di-UPDATE jadi can_add=TRUE oleh migrasi ini
--   role lain            → tetap can_add=FALSE (tombol tidak tampil, 403 bila dipaksa)
--
-- Baris (adm te / adm lce) x (yazu / yazudc) sudah ada (V33+V34+V55+V56 seed
-- menyalin dari inputer dengan can_add=FALSE) → pakai ON CONFLICT DO UPDATE,
-- bukan DO NOTHING, agar baris lama ikut dicangkan TRUE.
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V58__sync_adm_te_lce.sql

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
VALUES
  ('adm te',  'yazu',   TRUE, TRUE, TRUE, FALSE),
  ('adm te',  'yazudc', TRUE, TRUE, TRUE, FALSE),
  ('adm lce', 'yazu',   TRUE, TRUE, TRUE, FALSE),
  ('adm lce', 'yazudc', TRUE, TRUE, TRUE, FALSE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view = TRUE,
      can_add  = TRUE;
