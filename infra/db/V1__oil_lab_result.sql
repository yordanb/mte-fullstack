-- MTE Oil Lab Schema v1
-- Sumber: data sample excel/Rpt_Data_All_Lab.xlsx (sheet Rpt_Data_All_Lab, header row 4, data row 5+)
-- Mapping typo header Excel -> kolom DB:
--   "Grade C" -> grade_cr, "Gradet Bn" -> grade_tbn, "NFuel" -> n_fuel, "NO xi Max" -> n_oxi_max
-- Kolom A-B Excel (kosong) dibuang.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tracking setiap upload Excel (wajib karena data sering ditambah)
CREATE TABLE imports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  sheet TEXT NOT NULL DEFAULT 'Rpt_Data_All_Lab',
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING','VALIDATED','COMMITTED','FAILED')),
  total_rows INT NOT NULL DEFAULT 0,
  ok_rows INT NOT NULL DEFAULT 0,
  fail_rows INT NOT NULL DEFAULT 0,
  errors JSONB NULL,
  uploaded_by VARCHAR(100) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE oil_lab_result (
  -- audit / keys
  id BIGSERIAL PRIMARY KEY,
  lab_no BIGINT NOT NULL UNIQUE,  -- Excel bertipe teks, di-cast ke BIGINT saat import
  import_id UUID NULL REFERENCES imports(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- identitas unit (116 kolom Excel -> 1:1 ke bawah)
  unit_id VARCHAR(100) NULL,
  model VARCHAR(100) NULL,
  make VARCHAR(100) NULL,
  district VARCHAR(50) NULL,
  lab_name VARCHAR(50) NULL,
  vesselid VARCHAR(50) NULL,
  vessel_prefix CHAR(2) GENERATED ALWAYS AS (LEFT(UPPER(TRIM(BOTH FROM COALESCE(vesselid,''))), 2)) STORED,
  customer_id VARCHAR(100) NULL,
  companyname VARCHAR(100) NULL,
  oil_brand VARCHAR(100) NULL,
  oil_change VARCHAR(20) NULL CHECK (oil_change IS NULL OR oil_change IN ('Yes','No')),
  oil_weight VARCHAR(50) NULL,
  driver VARCHAR(100) NULL,
  oil_capacity INT NULL,
  oil_capacity_units VARCHAR(20) NULL,
  unit_time INT NULL,
  unit_time_oils INT NULL,
  oil_time_units VARCHAR(20) NULL,
  user_sample_id VARCHAR(50) NULL, -- NOTE: di sampel berisi 'NORMAL', perlu validasi ke lab
  sample_date TIMESTAMPTZ NULL,
  date_taken TIMESTAMPTZ NULL,

  -- limit bawah (N_*) — tidak ada N Si di Excel, jadi tidak ada n_si
  n_al NUMERIC(10,2) NULL, n_cr NUMERIC(10,2) NULL, n_cu NUMERIC(10,2) NULL,
  n_fe NUMERIC(10,2) NULL, n_pb NUMERIC(10,2) NULL, n_sn NUMERIC(10,2) NULL,
  n_k NUMERIC(10,2) NULL, n_na NUMERIC(10,2) NULL,
  n_water NUMERIC(10,2) NULL, n_oxi NUMERIC(10,2) NULL, n_visc NUMERIC(10,2) NULL,
  n_gly NUMERIC(10,2) NULL, n_fuel NUMERIC(10,2) NULL, n_tbn NUMERIC(10,2) NULL,
  n_nitr NUMERIC(10,2) NULL, n_soot NUMERIC(10,2) NULL, n_tan NUMERIC(10,2) NULL,
  n_mg NUMERIC(10,2) NULL, n_ag NUMERIC(10,2) NULL, n_zn NUMERIC(10,2) NULL,

  -- limit atas (*_max)
  n_al_max NUMERIC(10,2) NULL, n_cr_max NUMERIC(10,2) NULL, n_cu_max NUMERIC(10,2) NULL,
  n_fe_max NUMERIC(10,2) NULL, n_pb_max NUMERIC(10,2) NULL, n_sn_max NUMERIC(10,2) NULL,
  n_k_max NUMERIC(10,2) NULL, n_na_max NUMERIC(10,2) NULL,
  n_water_max NUMERIC(10,2) NULL, n_oxi_max NUMERIC(10,2) NULL, n_visc_max NUMERIC(10,2) NULL,
  n_gly_max NUMERIC(10,2) NULL, n_fuel_max NUMERIC(10,2) NULL, n_tbn_max NUMERIC(10,2) NULL,
  n_nitr_max NUMERIC(10,2) NULL, n_soot_max NUMERIC(10,2) NULL, n_tan_max NUMERIC(10,2) NULL,
  n_mg_max NUMERIC(10,2) NULL, n_ag_max NUMERIC(10,2) NULL, n_zn_max NUMERIC(10,2) NULL,

  -- grade (N=Normal, A=Abnormal di sampel)
  grade_al VARCHAR(5) NULL CHECK (grade_al IS NULL OR grade_al IN ('N','A','C')),
  grade_cr VARCHAR(5) NULL CHECK (grade_cr IS NULL OR grade_cr IN ('N','A','C')),
  grade_cu VARCHAR(5) NULL CHECK (grade_cu IS NULL OR grade_cu IN ('N','A','C')),
  grade_fe VARCHAR(5) NULL CHECK (grade_fe IS NULL OR grade_fe IN ('N','A','C')),
  grade_pb VARCHAR(5) NULL CHECK (grade_pb IS NULL OR grade_pb IN ('N','A','C')),
  grade_sn VARCHAR(5) NULL CHECK (grade_sn IS NULL OR grade_sn IN ('N','A','C')),
  grade_si VARCHAR(5) NULL CHECK (grade_si IS NULL OR grade_si IN ('N','A','C')),
  grade_k VARCHAR(5) NULL CHECK (grade_k IS NULL OR grade_k IN ('N','A','C')),
  grade_na VARCHAR(5) NULL CHECK (grade_na IS NULL OR grade_na IN ('N','A','C')),
  grade_water VARCHAR(5) NULL CHECK (grade_water IS NULL OR grade_water IN ('N','A','C')),
  grade_visc VARCHAR(5) NULL CHECK (grade_visc IS NULL OR grade_visc IN ('N','A','C')),
  grade_oxi VARCHAR(5) NULL CHECK (grade_oxi IS NULL OR grade_oxi IN ('N','A','C')),
  grade_gly VARCHAR(5) NULL CHECK (grade_gly IS NULL OR grade_gly IN ('N','A','C')),
  grade_fuel VARCHAR(5) NULL CHECK (grade_fuel IS NULL OR grade_fuel IN ('N','A','C')),
  grade_tbn VARCHAR(5) NULL CHECK (grade_tbn IS NULL OR grade_tbn IN ('N','A','C')),
  grade_nitr VARCHAR(5) NULL CHECK (grade_nitr IS NULL OR grade_nitr IN ('N','A','C')),
  grade_soot VARCHAR(5) NULL CHECK (grade_soot IS NULL OR grade_soot IN ('N','A','C')),
  grade_tan VARCHAR(5) NULL CHECK (grade_tan IS NULL OR grade_tan IN ('N','A','C')),
  grade_mg VARCHAR(5) NULL CHECK (grade_mg IS NULL OR grade_mg IN ('N','A','C')),
  grade_ag VARCHAR(5) NULL CHECK (grade_ag IS NULL OR grade_ag IN ('N','A','C')),
  grade_zn VARCHAR(5) NULL CHECK (grade_zn IS NULL OR grade_zn IN ('N','A','C')),

  -- nilai ukur aktual
  al NUMERIC(10,2) NULL, cr NUMERIC(10,2) NULL, cu NUMERIC(10,2) NULL,
  fe NUMERIC(10,2) NULL, pb NUMERIC(10,2) NULL, sn NUMERIC(10,2) NULL,
  si NUMERIC(10,2) NULL, k NUMERIC(10,2) NULL, na NUMERIC(10,2) NULL,
  water NUMERIC(10,2) NULL, visc NUMERIC(10,2) NULL, oxi NUMERIC(10,2) NULL,
  gly NUMERIC(10,2) NULL, fuel NUMERIC(10,2) NULL, tbn NUMERIC(10,2) NULL,
  nitr NUMERIC(10,2) NULL, soot NUMERIC(10,2) NULL, tan NUMERIC(10,2) NULL,
  mg NUMERIC(10,2) NULL, ag NUMERIC(10,2) NULL, zn NUMERIC(10,2) NULL,

  -- diagnosis
  english_description TEXT NULL,
  nvosaid VARCHAR(50) NULL,
  "condition" VARCHAR(20) NULL CHECK ("condition" IS NULL OR "condition" IN ('NORMAL','CRITICAL','WARNING')),
  iso4406 VARCHAR(50) NULL,
  pqindex INT NULL,
  colorcode NUMERIC(10,2) NULL,
  empat_um INT NULL, enam_um INT NULL, limabelas_um INT NULL,
  seq_i VARCHAR(50) NULL, seq_i_code INT NULL,
  seq_ii VARCHAR(50) NULL, seq_iii VARCHAR(50) NULL
);

-- Index pola query utama (20 data terbaru)
CREATE INDEX idx_oil_vessel_date ON oil_lab_result (vesselid, sample_date DESC, lab_no DESC);
CREATE INDEX idx_oil_vessel_unit_date ON oil_lab_result (vesselid, unit_id, sample_date DESC);
-- Fleet alert: prefix 2 huruf + non-NORMAL, partial index agar kecil
CREATE INDEX idx_oil_prefix_conddate ON oil_lab_result (vessel_prefix, sample_date DESC)
  WHERE "condition" IS DISTINCT FROM 'NORMAL';
CREATE INDEX idx_oil_district_date ON oil_lab_result (district, sample_date DESC);
CREATE INDEX idx_oil_sample_date ON oil_lab_result (sample_date DESC);

-- Status terakhir per unit untuk dashboard fleet (refresh tiap import)
CREATE MATERIALIZED VIEW mv_latest_status AS
SELECT DISTINCT ON (vesselid, unit_id) *
FROM oil_lab_result
ORDER BY vesselid, unit_id, sample_date DESC, lab_no DESC;
CREATE UNIQUE INDEX idx_mv_latest ON mv_latest_status (vesselid, unit_id);

-- updated_at otomatis
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_oil_updated ON oil_lab_result;
CREATE TRIGGER trg_oil_updated BEFORE UPDATE ON oil_lab_result
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
