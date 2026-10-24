-- V37: Ewacs — import jadi UPSERT, bukan full replace.
-- Natural key satu baris breakdown: (tanggal, cn, shift, kode, start_bd).
-- Index unik ini menjaga agar satu baris tidak pernah tersimpan dua kali;
-- import berikutnya memperbarui baris yang sudah ada (bukan menghapus semua).

-- 1) Bersihkan duplikat lama bila ada (simpan id terbesar = baris terbaru).
DELETE FROM ewacs_breakdown a
USING ewacs_breakdown b
WHERE a.id < b.id
  AND a.tanggal = b.tanggal
  AND a.cn = b.cn
  AND a.kode = b.kode
  AND COALESCE(a.shift, '') = COALESCE(b.shift, '')
  AND COALESCE(a.start_bd, '') = COALESCE(b.start_bd, '');

-- 2) Unique index pada natural key (dipakai sebagai dasar upsert).
CREATE UNIQUE INDEX IF NOT EXISTS uq_ewacs_natural_key
  ON ewacs_breakdown (tanggal, cn, COALESCE(shift, ''), kode, COALESCE(start_bd, ''));
