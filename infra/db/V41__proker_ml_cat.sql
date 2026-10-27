-- V41: Proker dipersempit menjadi "Proker Midlife Eng CAT".
-- Menu "proker" tetap dipakai, tetapi hanya unit ber-engine Caterpillar yang
-- ditampilkan. Data hasil import tetap disimpan seluruhnya (agar upload ulang
-- idempoten); penyaringan CAT dilakukan saat baca.
--
-- Sumber engine: tabel `equipment` (engine_merk/engine_model). Untuk C/N yang
-- belum terdaftar di equipment, engine diturunkan dari unit_type
-- (C27 / C32 / C7.1 = Caterpillar).

ALTER TABLE proker_unit ADD COLUMN IF NOT EXISTS engine_model TEXT NULL;
ALTER TABLE proker_unit ADD COLUMN IF NOT EXISTS engine_merk  TEXT NULL;

-- 1) Ambil dari master equipment.
UPDATE proker_unit u
SET engine_merk = CASE
      WHEN e.engine_merk IS NULL OR TRIM(e.engine_merk) = '' THEN NULL
      WHEN UPPER(TRIM(e.engine_merk)) LIKE 'CAT%' THEN 'CAT'
      ELSE UPPER(TRIM(e.engine_merk))
    END,
    engine_model = NULLIF(TRIM(REGEXP_REPLACE(
      REPLACE(UPPER(COALESCE(e.engine_model, '')), ',', '.'), '^CAT\s+', '')), '')
FROM equipment e
WHERE e.cn = u.cn
  AND u.engine_merk IS NULL
  AND u.engine_model IS NULL;

-- 2) Normalisasi merk Caterpillar (CAT / CATERPILLAR).
UPDATE proker_unit
SET engine_merk = 'CAT'
WHERE engine_merk IS NOT NULL AND UPPER(TRIM(engine_merk)) LIKE 'CAT%'
  AND engine_merk <> 'CAT';

-- 3) Fallback: turunkan engine dari tipe unit (C27 / C32 / C7.1 = CAT).
UPDATE proker_unit
SET engine_merk = 'CAT',
    engine_model = COALESCE(
      NULLIF(engine_model, ''),
      (REGEXP_MATCH(COALESCE(unit_type, ''), '(C27|C32|C7\.?1)', 'i'))[1]
    )
WHERE (engine_merk IS NULL OR engine_merk = '')
  AND COALESCE(unit_type, '') ~* '(C27|C32|C7\.?1)';

CREATE INDEX IF NOT EXISTS idx_proker_unit_engine ON proker_unit (engine_merk);

-- Cek hasil: harus 46 unit CAT (3 unit non-CAT tetap tersimpan, tidak ditampilkan).
--   SELECT engine_merk, engine_model, COUNT(*) FROM proker_unit
--   GROUP BY 1, 2 ORDER BY 1, 2;
