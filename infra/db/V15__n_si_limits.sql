-- V15 lengkapi limit Si (dipakai laporan PAMA; Excel tak punya N Si jadi selalu NULL).
ALTER TABLE oil_lab_result ADD COLUMN IF NOT EXISTS n_si NUMERIC(10,2) NULL;
ALTER TABLE oil_lab_result ADD COLUMN IF NOT EXISTS n_si_max NUMERIC(10,2) NULL;
