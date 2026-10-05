-- V6 master equipment: referensi cn untuk oil_lab_result & dbr_records.
-- Satu baris per unit (cn unik). Kolom komponen per kategori di specs JSONB.
-- Seed data: infra/db/V7__equipment_seed.sql (dihasilkan scripts/build_equipment_seed.py).
CREATE TABLE IF NOT EXISTS equipment (
  cn VARCHAR(20) PRIMARY KEY,
  cn_prefix CHAR(2) GENERATED ALWAYS AS (LEFT(UPPER(TRIM(BOTH FROM cn)), 2)) STORED,
  category VARCHAR(20) NOT NULL
    CHECK (category IN ('BIGWHEEL','LIGHTING','MOBILE','PUMPING')),
  unit_model TEXT NULL,
  unit_type TEXT NULL,
  unit_product TEXT NULL,
  cn_serial_no TEXT NULL,
  cn_year SMALLINT NULL,
  cn_lokasi TEXT NULL,
  status TEXT NULL,
  operasional TEXT NULL,
  pump_group TEXT NULL,
  engine_model TEXT NULL,
  engine_merk TEXT NULL,
  engine_serial_no TEXT NULL,
  arrived_date DATE NULL,
  arrived_year SMALLINT NULL,   -- tahun kedatangan (tetap terisi walau tgl/bln tak valid)
  arrived_month SMALLINT NULL,  -- 1-12, NULL bila tak valid
  arrived_hm NUMERIC(12,2) NULL,
  lokasi TEXT NULL,
  remark TEXT NULL,
  offhire TEXT NULL,
  aktif BOOLEAN NOT NULL DEFAULT TRUE,
  specs JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_eq_prefix ON equipment (cn_prefix);
CREATE INDEX IF NOT EXISTS idx_eq_cat ON equipment (category) WHERE aktif;
CREATE INDEX IF NOT EXISTS idx_eq_unit_type ON equipment (unit_type);
DROP TRIGGER IF EXISTS trg_equipment_updated ON equipment;
CREATE TRIGGER trg_equipment_updated BEFORE UPDATE ON equipment
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
