-- V54: tabel Hourmeter — pencatatan HM bulanan per unit (upload Excel manual).
-- Sumber: sheet "HM_Manual" (mis. "hm pumping okt 26.xlsx")
--   Baris judul : tanggal periode (mis. 2026-10-01), merged A1:D1
--   Header      : No | EGI | CN Unit | <opening 31-8> | 1..31 | Max
--   Baris data  : opening + nilai HM sparse per hari (tampil ribuan '46.383')
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V54__hourmeter.sql

CREATE TABLE IF NOT EXISTS hourmeter_opening (
  id          SERIAL PRIMARY KEY,
  period      VARCHAR(7) NOT NULL,            -- 'YYYY-MM'
  cn          VARCHAR(50) NOT NULL,
  egi         VARCHAR(100),
  opening     BIGINT,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  uploaded_by VARCHAR(100),
  UNIQUE(period, cn)
);

CREATE TABLE IF NOT EXISTS hourmeter_daily (
  id     SERIAL PRIMARY KEY,
  period VARCHAR(7) NOT NULL,
  cn     VARCHAR(50) NOT NULL,
  day    SMALLINT NOT NULL CHECK (day BETWEEN 1 AND 31),
  hm     BIGINT NOT NULL,
  UNIQUE(period, cn, day)
);

CREATE INDEX IF NOT EXISTS idx_hourmeter_daily_period ON hourmeter_daily (period);
CREATE INDEX IF NOT EXISTS idx_hourmeter_daily_cn     ON hourmeter_daily (cn);
CREATE TABLE IF NOT EXISTS hourmeter_upload_log (
  id           SERIAL PRIMARY KEY,
  period       VARCHAR(7),
  filename     VARCHAR(255),
  rows_units   INTEGER,
  rows_values  INTEGER,
  status       VARCHAR(20) DEFAULT 'success',
  error_msg    TEXT,
  uploaded_by  VARCHAR(100),
  uploaded_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Menu "Hourmeter" pada matriks izin (grup Technical Expert, menu posisi teratas).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss','proker',
    'prokerbooster','prokerinjector','manpower','hourmeter'
  ));

-- Izin mengikuti menu "measurement" (TE lain juga begitu) — jaring pengaman
-- seed eksplisit bila menu itu belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'hourmeter', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'measurement'
ON CONFLICT (role, menu) DO NOTHING;

INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete) VALUES
  ('admin',        'hourmeter', TRUE, TRUE,  TRUE,  TRUE),
  ('inputer',      'hourmeter', TRUE, TRUE,  TRUE,  FALSE),
  ('mekanik',      'hourmeter', TRUE, TRUE,  TRUE,  FALSE),
  ('planner',      'hourmeter', TRUE, TRUE,  TRUE,  FALSE),
  ('adm te',       'hourmeter', TRUE, TRUE,  TRUE,  FALSE),
  ('group leader', 'hourmeter', TRUE, FALSE, FALSE, FALSE),
  ('section head', 'hourmeter', TRUE, FALSE, FALSE, FALSE),
  ('viewer',       'hourmeter', TRUE, FALSE, FALSE, FALSE)
ON CONFLICT (role, menu) DO NOTHING;
