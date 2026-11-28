-- V82: Seed permission untuk menu MOM2
-- Migration V79 sudah menambah MOM/MOM2 ke CHECK constraint, tapi belum
-- meng-seed baris permission untuk MOM2. Pemanggilan backend
-- require_menu("mom2", ...) memakai bool_or() — kalau tidak ada baris,
-- hasilnya false → akses ditolak / menu tidak tampil.

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

-- Izin MOM2 diwarisi dari MOM (satu keluarga MOM)
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'mom2', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'mom'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman untuk admin & role dasar bila row MOM2 belum ada
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'mom2', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'mom2'
);

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'inputer', 'mom2', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'inputer' AND menu = 'mom2'
);

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'mekanik', 'mom2', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'mekanik' AND menu = 'mom2'
);

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'viewer', 'mom2', TRUE, FALSE, FALSE, FALSE
WHERE NOT EXISTS (
  SELECT 1 FROM role_permissions WHERE role = 'viewer' AND menu = 'mom2'
);
