-- V59: Proker Thermostat CAT — program kerja replace thermostat engine
-- Caterpillar (interval 12.000 jam), grup menu Technical Expert.
--
-- Sumber Excel: "proker thermostat engine caterpillar.xlsx",
-- sheet "05. MIDLIFE COOLING SISTEM", 1 baris per unit (flat):
--   NO | UNIT MODEL | PRODUCT | UNIT TYPE | C/N | HM NOW | DEVIASI | LIFETIME
--   LAST (HM|DATE) | MODIF 74°C (HM|DATE|REMAKS|WR|ETA PARTS|ETA EXEC)
--   RADIATOR CHECK BY THERMA (HM|DATE|UPPER|LOWER|REMARK)
-- DEVIASI & LIFETIME adalah formula di sheet → tidak disimpan, dihitung saat baca:
--   deviasi  = hm_now - (COALESCE(last_hm,0) + interval_hm)
--   lifetime = hm_now - COALESCE(modif_hm, 0)
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V59__proker_thermostat.sql

CREATE TABLE IF NOT EXISTS thermo_unit (
  cn           VARCHAR(50) PRIMARY KEY,
  no           INTEGER,
  unit_model   VARCHAR(100),
  product      VARCHAR(100),
  unit_type    VARCHAR(100),
  hm_now       BIGINT,
  interval_hm  DOUBLE PRECISION NOT NULL DEFAULT 12000,
  -- LAST: penggantian thermostat terakhir
  last_hm      BIGINT,
  last_date    DATE,
  -- MODIF 74°C: modifikasi thermostat 74°C + rencana
  modif_hm     BIGINT,
  modif_date   DATE,
  modif_status VARCHAR(20),      -- DONE / NOT YET
  wr           VARCHAR(100),
  eta_parts    DATE,
  eta_exec     DATE,
  -- RADIATOR CHECK BY THERMA (termal)
  rad_hm       BIGINT,
  rad_date     DATE,
  rad_upper    DOUBLE PRECISION, -- suhu upper (°C)
  rad_lower    DOUBLE PRECISION, -- suhu lower (°C)
  rad_remark   VARCHAR(255),
  import_id    VARCHAR(64),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_thermo_unit_updated ON thermo_unit;
CREATE TRIGGER trg_thermo_unit_updated BEFORE UPDATE ON thermo_unit
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "prokerthermo" pada matriks izin (grup Technical Expert).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','yazudc','ewacs','tarsupport','ss','ssab','proker',
    'prokerbooster','prokerinjector','manpower','manpowermanage','hourmeter','prokerthermo'
  ));

-- Izin mengikuti menu "prokerinjector" (satu keluarga proker midlife) —
-- akses lama tidak berubah; bisa diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'prokerthermo', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'prokerinjector'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman: admin selalu penuh bila baris injector belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT 'admin', 'prokerthermo', TRUE, TRUE, TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM role_permissions WHERE role = 'admin' AND menu = 'prokerthermo');
