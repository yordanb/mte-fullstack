-- V60: Ewacs — normalisasi penulisan EGI yang salah pada ewacs_breakdown.
-- Varian salah tulis: "LS4-2000" → "LS42000" dan "LS4-6000" → "LS46000".
-- Pencocokan mengabaikan besar/kecil huruf & spasi, sehingga varian seperti
-- "ls4-2000" atau "LS4 - 2000" ikut diperbaiki. Idempoten (aman dijalankan ulang).

UPDATE ewacs_breakdown
SET egi = 'LS42000'
WHERE UPPER(REPLACE(egi, ' ', '')) = 'LS4-2000';

UPDATE ewacs_breakdown
SET egi = 'LS46000'
WHERE UPPER(REPLACE(egi, ' ', '')) = 'LS4-6000';
