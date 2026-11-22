CREATE TABLE glandpacking_replacement (
  id SERIAL PRIMARY KEY,
  cn VARCHAR(50) NOT NULL,
  hm_replace INT NOT NULL,
  replace_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by VARCHAR(50) NOT NULL DEFAULT 'system',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uix_glandpacking_replacement_cn_date
  ON glandpacking_replacement (cn, replace_date);