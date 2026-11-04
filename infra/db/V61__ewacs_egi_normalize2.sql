-- V61: Ewacs — normalisasi lanjutan penulisan EGI pada ewacs_breakdown.
-- Varian yang diperbaiki:
--   "LEGRA 140" → "LEGRA140"   (spasi dihilangkan)
--   "RF-85MW"   → "RF85MW"     (tanda hubung dihilangkan)
--   "EGS630-6"  → "EGS6306"
--   "EGS63060"  → "EGS6306"
-- Pencocokan mengabaikan besar/kecil huruf & spasi. Idempoten (aman dijalankan ulang).

UPDATE ewacs_breakdown
SET egi = 'LEGRA140'
WHERE UPPER(REPLACE(egi, ' ', '')) = 'LEGRA140'
  AND egi <> 'LEGRA140';

UPDATE ewacs_breakdown
SET egi = 'RF85MW'
WHERE UPPER(REPLACE(egi, ' ', '')) = 'RF-85MW';

UPDATE ewacs_breakdown
SET egi = 'EGS6306'
WHERE UPPER(REPLACE(egi, ' ', '')) IN ('EGS630-6', 'EGS63060');
