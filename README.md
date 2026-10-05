# MTE Data Center — Fullstack Monitoring (Oil Lab + DBR Breakdown + Equipment)

Aplikasi monitoring terpusat untuk **report analisa oli**, **daily breakdown (DBR)**,
**performance breakdown**, dan **master equipment** — dipakai harian oleh tim plant.
Backend **FastAPI + PostgreSQL**, frontend **React + Vite + Tailwind**, mobile **Flutter**
(rencana), semua berjalan sebagai container Docker di VPS dan diupdate via `git pull`.

## Arsitektur & Port

| Service | Container | Image/Build | Port host → container |
|---|---|---|---|
| Database | `mte-fs-db` | `postgres:16-alpine` | `5446 → 5432` |
| Backend API | `mte-fs-api` | `./apps/api` | `8802 → 8000` |
| Web dashboard | `mte-fs-web` | `./apps/web` | `8803 → 80` |

Alur data: file `.xlsx` diupload via menu **Update Data** → divalidasi →
disimpan ke PostgreSQL oleh background job (progress dipolling dari web) →
ditampilkan di Dashboard / DBR / Performance / Equipment.
File `~$*` (lock Excel) diabaikan git (lihat `.gitignore`).

## Fitur Web

| Menu | Isi |
|---|---|
| **Dashboard** | Data oli terbaru per vessel+unit, pencarian vessel/unit, filter radio Critical (TL/GS/WP), statistik Total/CRITICAL/NORMAL, pagination 10/20/50, label last update khusus oli. Singkatan Unit Id otomatis (FINAL DRIVE LEFT→FD LH, TRANSMISSION→TM, dst — 17 entri, hanya tampilan). |
| **DBR Breakdown** | Tabel 16→11 kolom (Start/Finish/Total/WO/Notif disembunyikan), filter rentang tanggal (date-picker), C/N, dropdown Code (termasuk opsi baris kosong), pagination, checkbox *Sembunyikan CONTINUE* (sembunyikan baris carry-over). Format tanggal `12 Jul 26`. |
| **Performance** | Dashboard frekuensi breakdown: filter tanggal + granularitas Harian/Mingguan/Bulanan + prefix + code + checkbox *Kecualikan CONTINUE* (default on — grafik menghitung **kejadian**, bukan hari downtime). Grafik batang-tumpuk 6 prefix teratas + garis total, 3 Pareto (Top 10 Trouble/Section/Code), 4 kartu ringkasan. |
| **Equipment** | Master 330 unit: tabel Code Number, Unit Type, Product, Operasional (+kategori, model, lokasi, status, aktif), filter kategori/aktif, ikon mata (popup detail lengkap + serial komponen), Ubah via modal, + Tambah Unit. Baris nonaktif abu-abu. |
| **Data Vessel** | Tampilan sama dengan Dashboard (pencarian per vessel). |
| **Update Data** | Kartu gaya SAP Fiori: *Report Analisa Oli* (Dry-run + Commit + progress 2 tahap) dan *DBR Breakdown* (Upload + progress). |

Perilaku sesi: **auto-logout setelah 30 menit tanpa aktivitas** (mouse/klik/ketik/sentuh)
dan logout otomatis saat server menolak token (401) — tidak ada lagi error 401
membingungkan setelah lama idle.

## API (base `/api`, auth Bearer JWT, role `operator`/`admin` untuk tulis)

| Method & Path | Fungsi |
|---|---|
| `POST /v1/auth/login` | Login, dapat access token (default exp 60 mnt, lihat `JWT_EXP_MIN`) |
| `GET /v1/results? vesselid&unit_id&limit` | 20 data oli terbaru per vessel |
| `GET /v1/results/latest-per-unit?limit&prefix&condition` | 1 baris terbaru per vessel+unit (default dashboard) |
| `GET /v1/fleet/alerts?prefix` | Status terakhir non-NORMAL per prefix (legacy, tak dipakai menu) |
| `POST /v1/imports?dry_run=` | Upload Excel oli (dry-run validasi / commit background + progress) |
| `GET /v1/imports/latest` | Upload **oli** terakhir (DBR dikecualikan — untuk label last update) |
| `GET /v1/imports/{id}` | Status/progress import (polling tiap 2 dtk) |
| `POST /v1/dbr/imports` | Upload Excel DBR (background + progress) |
| `GET /v1/dbr/records?date_from&date_to&cn&prefix&code&page` | Tabel DBR (default 30 hari terakhir; `code=__EMPTY__` = baris kosong) |
| `GET /v1/dbr/codes` | Daftar Code untuk dropdown |
| `GET /v1/dbr/stats?date_from&date_to&granularity&prefix&code&exclude_continue` | Frekuensi per periode×prefix + Pareto + ringkasan (default 90 hari, mingguan, CONTINUE dikecualikan) |
| `GET /v1/equipment?...` / `GET /v1/equipment/{cn}` | List (search/kategori/prefix/aktif + pagination) & detail unit |
| `POST /v1/equipment` / `PATCH /v1/equipment/{cn}` | Tambah (409 jika CN ada) & ubah unit |

## Database (`infra/db`, dijalankan berurutan)

| File | Isi |
|---|---|
| `V1__oil_lab_result.sql` | `imports`, `oil_lab_result` (116 kolom), index, `mv_latest_status`, trigger `updated_at` |
| `V2__auth.sql` | `users` + seed admin |
| `V3__imports_progress.sql` | `processed_rows` + status `PROCESSING` (progress bar) |
| `V4__labno_text_caution.sql` | `lab_no` TEXT + condition `CAUTION` |
| `V5__dbr.sql` | `dbr_records` (16 kolom, `UNIQUE(date,cn,start_breakdown)`, `cn_prefix` turunan) |
| `V6__equipment.sql` | `equipment` (`cn` PK, kategori, `specs` JSONB, trigger `updated_at`) |
| `V7__equipment_seed.sql` | 330 unit, idempoten (`ON CONFLICT DO UPDATE`) — **dihasilkan**, jangan edit manual |

Fresh install: file `V1–V7` otomatis jalan via `/docker-entrypoint-initdb.d`.
Database lama: jalankan manual file yang belum pernah diterapkan (lihat riwayat di bawah).

## Struktur Repo

```
apps/api/      FastAPI (app/api/v1: auth, results, fleet, imports, dbr, equipment;
               app/services: excel_map.py, dbr_map.py; app/core, app/db)
apps/web/      React+Vite+Tailwind (pages: Dashboard/DBR/Performance/Equipment/Import;
               components: Layout, Widgets; api/client.ts; recharts untuk grafik)
infra/db/      Migrasi SQL V1..V7
scripts/       build_equipment_seed.py (generator V7 dari data-equipment/)
data-equipment/ 4 dump sumber equipment (tb_bigwheel/lighting/spex_mobile/spex_pumping)
data sample excel/ Contoh file + DBR_format.xlsx (file lock ~$* diabaikan)
docker-compose.yml  db:5446, api:8802, web:8803
.env.example   Template env (copy ke .env, JANGAN commit)
```

## Aturan Bisnis / Parsing Penting

- **Excel oli**: desimal koma Indonesia (`4,9`), `lab_no` teks, grade `N/A/C`,
  condition `NORMAL/CRITICAL/CAUTION`, `ND`/`-` → NULL, Oil Change `Y/N` → `Yes/No`.
  Import batch 2000 (~21 round-trip untuk 41 rb baris).
- **Excel DBR**: 21.039 baris; `####` (kolom sempit Excel) disimpan mentah;
  `SECTION` typo (`HAUILER`, spasi) ditoleransi; duplikat di-upsert via
  `(date, cn, start_breakdown)`.
- **CONTINUE**: 8.588 baris DBR (40,8%) adalah carry-over perbaikan multi-hari
  (mis. WP855: 176/195 baris). Statistik Performance **mengecualikannya secara
  default** agar menghitung kejadian, bukan hari downtime.
- **Equipment**: 330 unit gabungan 4 sumber; `NaT`→NULL, tanggal `ADARO/ERKA`→NULL
  (tahun/bulan dipertahankan), newline di-trim. GS256 ganda dimenangkan versi pumping.
- Batas upload default 50 MB (`MAX_UPLOAD_MB`).

## Menjalankan Lokal

```bash
cp .env.example .env   # isi password & secret, samakan DATABASE_URL
docker compose up -d --build
# web:   http://localhost:8803
# api:   http://localhost:8802  (docs: /docs)
# db:    localhost:5446
```

## Deploy / Update VPS

```bash
cd /opt/projects/mte-fullstack
unset DATABASE_URL   # wajib: agar compose baca DATABASE_URL dari .env, bukan shell
git pull --rebase origin main
# HANYA jika ada migrasi baru yang belum diterapkan, mis:
# docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V6__equipment.sql
# docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V7__equipment_seed.sql
docker compose up -d --build api web
```

Riwayat migrasi VPS: V3+V4 (progress + lab_no/CAUTION) → V5 (DBR) → V6+V7 (equipment).
File migrasi hanya dijalankan sekali; `V7` aman di-rerun.

## Troubleshooting

| Gejala | Cek |
|---|---|
| Web blank total | F12 Console → error JS (pernah: hook di luar komponen); pastikan `web` di-rebuild setelah pull + hard-refresh |
| `401` setelah idle | Normal: token exp 60 mnt; app auto-logout (30 mnt idle / saat 401) → login ulang |
| Progress macet di "memproses" | Wajar untuk file besar (parse di background); tunggu bar tahap-1 `Membaca & validasi` |
| Dry-run/commit `fail>0` | Lihat 50 error pertama di respons; umumnya header tak dikenal / Lab No kosong / DATE invalid |
| `File terlalu besar` | Naikkan `MAX_UPLOAD_MB` di `.env` lalu `up -d api` |
| Migrasi gagal `already exists` | Normal bila rerun: semua objek pakai `IF NOT EXISTS`; kecuali `V7` yang memang idempoten |
