-- V38: koreksi zona waktu data Yazu yang sudah tersimpan.
--
-- Penyebab: kolom "Waktu" di Google Sheets berisi jam lokal site (WITA / GMT+8),
-- tetapi di-insert sebagai datetime naive ke kolom TIMESTAMPTZ sehingga dibaca
-- sebagai UTC. Akibatnya semua baris tersimpan 8 jam lebih maju; 48,5% baris
-- (semua entri jam 16:00–23:59 WITA) jatuh ke tanggal berikutnya di pivot.
--
-- Perbaikan kode: apps/api/app/api/v1/yazu.py (_parse_waktu → tzinfo=Asia/Makassar).
-- Migrasi ini menggeser data lama 8 jam ke belakang.
--
-- Guard: hanya dijalankan bila data terlihat "di masa depan" (waktu terbesar
-- > now() + 30 menit), sehingga aman dijalankan berulang (idempoten).
-- Jalankan SEBELUM container api baru dijalankan, agar baris lama tidak
-- berbenturan dengan baris baru (UNIQUE(waktu, id_unit)).

DO $$
DECLARE
    n_rows   BIGINT;
    t_max    TIMESTAMPTZ;
    t_now    TIMESTAMPTZ := now();
BEGIN
    SELECT COUNT(*), MAX(waktu) INTO n_rows, t_max FROM yazu;

    IF n_rows = 0 THEN
        RAISE NOTICE 'V38: tabel yazu kosong — tidak ada yang digeser.';
        RETURN;
    END IF;

    IF t_max > t_now + INTERVAL '30 minutes' THEN
        UPDATE yazu SET waktu = waktu - INTERVAL '8 hours';
        RAISE NOTICE 'V38: % baris yazu digeser -8 jam (max lama %, max baru %).',
                     n_rows, t_max, t_max - INTERVAL '8 hours';
    ELSE
        RAISE NOTICE 'V38: data sudah benar (max %), tidak ada perubahan.', t_max;
    END IF;
END $$;

-- Verifikasi cepat (opsional, lihat 5 baris terakhir):
-- SELECT waktu, (waktu AT TIME ZONE 'Asia/Makassar') AS waktu_wita, id_unit
-- FROM yazu ORDER BY waktu DESC LIMIT 5;
