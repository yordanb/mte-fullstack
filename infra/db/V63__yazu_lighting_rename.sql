-- V63: Rename modul "Yazu" → "Yazu Lighting".
--
-- Perubahan nama (agar konsisten dengan penamaan sumber data Lighting):
--   tabel  yazu                 → yazu_lighting
--   tabel  yazu_sync_log        → yazu_lighting_sync_log
--   tabel  yazu_dc              → yazu_dc_lighting
--   tabel  yazu_dc_sync_log     → yazu_dc_lighting_sync_log
--   menu   'yazu'               → 'yazu_lighting'   (Yazu Lighting P2H)
--   menu   'yazudc'             → 'yazudc_lighting' (Yazu Lighting Daily Check)
--   path   /v1/yazu             → /v1/yazu-lighting        (backend)
--   path   /v1/yazu-dc          → /v1/yazu-dc-lighting     (backend)
--
-- Index & sequence ikut berpindah otomatis saat RENAME (nama index boleh tetap;
-- tidak ada logika aplikasi yang mengandalkan nama index).
--
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V63__yazu_lighting_rename.sql
-- Aman rerun: rename memakai IF EXISTS (lewati bila tabel lama sudah tidak ada);
-- constraint memakai DROP IF EXISTS; baris izin memakai ON CONFLICT DO NOTHING/DELETE.

-- ── 1. Rename tabel + sync log ──────────────────────────────────────────────
ALTER TABLE IF EXISTS yazu            RENAME TO yazu_lighting;
ALTER TABLE IF EXISTS yazu_sync_log   RENAME TO yazu_lighting_sync_log;
ALTER TABLE IF EXISTS yazu_dc         RENAME TO yazu_dc_lighting;
ALTER TABLE IF EXISTS yazu_dc_sync_log RENAME TO yazu_dc_lighting_sync_log;

-- ── 2. Perbarui fungsi helper (nama sama, tak perlu diubah) ─────────────────
-- yazu_wita_date(timestamptz) tetap dipakai di index; tidak ada rename.

-- ── 3. Constraint izin menu: ganti 'yazu','yazudc' → '*_lighting' ────────────
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu_lighting','yazudc_lighting','ewacs',
    'tarsupport','ss','ssab','proker','prokerbooster','prokerinjector',
    'manpower','manpowermanage','hourmeter','prokerthermo'
  ));

-- ── 4. Migrasi baris izin existing: 'yazu' → 'yazu_lighting' ────────────────
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'yazu_lighting', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'yazu'
ON CONFLICT (role, menu) DO NOTHING;

DELETE FROM role_permissions WHERE menu = 'yazu';

-- Jaring pengaman: admin selalu punya akses penuh.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
VALUES ('admin', 'yazu_lighting', TRUE, TRUE, TRUE, TRUE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view = TRUE, can_add = TRUE, can_edit = TRUE, can_delete = TRUE;

-- ── 5. Migrasi baris izin existing: 'yazudc' → 'yazudc_lighting' ────────────
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'yazudc_lighting', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'yazudc'
ON CONFLICT (role, menu) DO NOTHING;

DELETE FROM role_permissions WHERE menu = 'yazudc';

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
VALUES ('admin', 'yazudc_lighting', TRUE, TRUE, TRUE, TRUE)
ON CONFLICT (role, menu) DO UPDATE
  SET can_view = TRUE, can_add = TRUE, can_edit = TRUE, can_delete = TRUE;
