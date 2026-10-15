-- V21: Staging Pump Configuration — master grup + konfigurasi per bulan + riwayat perubahan.
-- Pump CN FK ke equipment (kategori PUMPING). Konfigurasi versioned per periode 'YYYY-MM'.

CREATE TABLE IF NOT EXISTS staging_pump_groups (
    id          SERIAL PRIMARY KEY,
    group_no    INTEGER NOT NULL,
    sump_name   TEXT,
    system_type TEXT NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging_pump_items (
    id         SERIAL PRIMARY KEY,
    group_id   INTEGER NOT NULL REFERENCES staging_pump_groups(id) ON DELETE CASCADE,
    period     TEXT NOT NULL,
    pump_cn    VARCHAR(20) NOT NULL REFERENCES equipment(cn),
    role_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(group_id, period, role_order)
);
CREATE INDEX IF NOT EXISTS idx_staging_items_period ON staging_pump_items(period);
CREATE INDEX IF NOT EXISTS idx_staging_items_group_period ON staging_pump_items(group_id, period);

CREATE TABLE IF NOT EXISTS staging_pump_changes (
    id          SERIAL PRIMARY KEY,
    group_id    INTEGER NOT NULL REFERENCES staging_pump_groups(id) ON DELETE CASCADE,
    period      TEXT NOT NULL,
    change_type TEXT NOT NULL,
    pump_cn     VARCHAR(20),
    from_value  TEXT,
    to_value    TEXT,
    changed_by  TEXT NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staging_changes_period ON staging_pump_changes(period);
CREATE INDEX IF NOT EXISTS idx_staging_changes_group ON staging_pump_changes(group_id);

DROP TRIGGER IF EXISTS trg_staging_group_updated ON staging_pump_groups;
CREATE TRIGGER trg_staging_group_updated BEFORE UPDATE ON staging_pump_groups
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu 'staging' di matriks izin
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN ('dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','import'));

INSERT INTO role_permissions(role,menu,can_view,can_add,can_edit,can_delete) VALUES
  ('admin','staging',TRUE,TRUE,TRUE,TRUE),
  ('inputer','staging',TRUE,TRUE,TRUE,TRUE),
  ('viewer','staging',TRUE,FALSE,FALSE,FALSE)
ON CONFLICT (role,menu) DO NOTHING;
