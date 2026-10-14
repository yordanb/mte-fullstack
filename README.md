# MTE Data Center — Fullstack Monitoring (Oil Lab + DBR + Equipment + FUI + Activity + Safety)

Aplikasi monitoring terpusat untuk **report analisa oli**, **daily breakdown (DBR)**,
**performance breakdown**, **master equipment**, **FUI follow-up**,
**activity + foto**, **project management**, dan **safety (Bomak 6 PAS + R1BI)** —
dipakai harian oleh tim plant.
Backend **FastAPI + PostgreSQL**, frontend web **React + Vite + Tailwind**,
mobile **Flutter Android** (`apps/mobile`, Riverpod + GoRouter),
semua berjalan sebagai container Docker di VPS dan diupdate via `git pull`.

## Arsitektur & Port

| Service | Container | Image/Build | Port host → container |
|---|---|---|---|
| Database | `mte-fs-db` | `postgres:16-alpine` | `5446 → 5432` |
| Backend API | `mte-fs-api` | `./apps/api` | `8802 → 8000` |
| Web dashboard | `mte-fs-web` | `./apps/web` | `8803 → 80` |
| Foto upload | volume `uploads` | — | `/data/uploads` di api |

Alur data: file `.xlsx` diupload via menu **Update Data** → divalidasi →
disimpan ke PostgreSQL oleh background job (progress dipolling dari web) →
ditampilkan di Dashboard / DBR / Performance / Equipment.
Google Sheets publik (Bomak, R1BI) ditarik via tombol Sync + cron.
File `~$*` (lock Excel) diabaikan git (lihat `.gitignore`).

## Fitur Web

Sidebar berkelompok collapsible (Monitoring / Operasional / Follow Up / Administrasi),
autohide overlay, ikon per menu, dark mode penuh, notifikasi (import + aktivitas),
profil (avatar + ganti password), dan auto-logout.

| Menu | Isi |
|---|---|
| **Dashboard** | Data oli terbaru per vessel+unit, pencarian vessel/unit, filter radio Critical (TL/GS/WP), statistik Total/CRITICAL/NORMAL, pagination 10/20/50, label last update khusus oli. Singkatan Unit Id otomatis (FINAL DRIVE→FD, TRANSMISSION→TM, DIFFERENTIAL→DIFF, TANDEM→TDM, HYDRAULIC→HYD, dst — hanya tampilan). |
| **DBR Breakdown** | Tabel 11 kolom (Start/Finish/Total/WO/Notif disembunyikan), filter rentang tanggal (date-picker), C/N, dropdown Code (termasuk opsi baris kosong), pagination, checkbox *Sembunyikan CONTINUE*. Format tanggal `12 Jul 26`. |
| **Performance** | Frekuensi breakdown: granularitas Harian/Mingguan/Bulanan + prefix + code + *Kecualikan CONTINUE* (default on — menghitung **kejadian**, bukan hari downtime). Grafik ApexCharts (batang-tumpuk 6 prefix + garis total, lazy-load) + Pareto Top 10 Trouble/Section/Code/Code Number + kartu ringkasan. |
| **Activity** | Kalender bulanan + drawer harian + tab Rekap. Form: crew (wajib, datalist), kategori, CN (validasi master), HM, multi-foto (progress + anti double-submit). Filter crew/kategori + sembunyikan CONTINUE. |
| **Timeline Mingguan** | Ringkasan Activity per rentang tanggal untuk presentasi management. |
| **Bomak R1BI** | Safety 6 PAS + R1BI dari Google Sheets (switch tampilan, tombol Sync + cron per sumber): cakupan section bulan berjalan, pengecualian per poin / sorot HIGH RISK, tabel responsif + thumbnail eviden Drive, salin WA bernomor. |
| **Equipment** | Master 330 unit: Code Number, Unit Type, Product, Model, Engine (`MERK - MODEL`), Status; sortir kolom server-side, filter kategori/aktif, ikon mata (detail + serial komponen), Ubah via modal, + Tambah Unit. |
| **FUI** | Dossier per unit (ketik CN): kartu equipment (+serial), 10 DBR terbaru (Code USM, tanpa CONTINUE), 10 oil terakhir per component. Tombol Export PDF/PAMA **disembunyikan sementara** (`SHOW_FUI_EXPORT`). |
| **Suggestion FUI** | Unit aktif yang sample terakhirnya non-NORMAL + masing-masing 3 oil terakhir, per kategori; tombol *Suggest Follow Up* per baris non-NORMAL (inputer+). |
| **Report Follow Up** | Semua oil terakhir non-NORMAL + status Sudah/Belum suggest + saran terakhir; filter kategori/cari/status; riwayat suggest per lab. |
| **Project** | Project → Tahap (rencana tanggal + bobot) → Update (progress, status RAG, foto eviden); progress agregat, status Terlambat otomatis, timeline vs hari ini. |
| **Update Data** | Kartu gaya SAP Fiori: *Report Analisa Oli* (Dry-run + Commit + progress 2 tahap) dan *DBR Breakdown* (Upload + progress). |
| **Users** (admin) | CRUD user (admin/inputer/viewer) + matriks izin per menu (Lihat/Tambah/Ubah/Hapus). |
| **Audit Log** (admin) | Siapa login/akses apa/dari mana (termasuk login gagal), filter + pagination. |

Perilaku sesi: **auto-logout saat idle (admin 60 mnt, lainnya 45 mnt)** dan logout
otomatis saat server menolak token (401). Token akses 60 mnt (`JWT_EXP_MIN`).

## API (base `/api`, auth Bearer JWT; tulis = `inputer`/`admin`, baca = semua role)

| Method & Path | Fungsi |
|---|---|
| `POST /v1/auth/login` | Login → access/refresh token + role |
| `POST /v1/auth/refresh` | Refresh access token |
| `GET /v1/results/latest-per-unit?limit&prefix&condition` | 1 baris terbaru per vessel+unit |
| `GET /v1/results?vesselid&unit_id&limit&before` | 20 terbaru per vessel (≤100) |
| `GET /v1/results/units?vesselid` | Daftar unit_id 1 vessel |
| `POST /v1/imports?dry_run=` | Upload Excel oli (dry-run / commit background) |
| `GET /v1/imports/latest` , `GET /v1/imports/{id}` | Upload oli terakhir / progress polling |
| `POST /v1/dbr/imports` | Upload Excel DBR (background) |
| `GET /v1/dbr/records?...&exclude_continue` | Tabel DBR (default 30 hari; `code=__EMPTY__`) |
| `GET /v1/dbr/codes` , `GET /v1/dbr/stats?...` | Dropdown Code / agregat frekuensi + Pareto |
| `GET /v1/equipment?...&sort&order` / `GET /v1/equipment/{cn}` | List + sortir server-side / detail |
| `POST /v1/equipment` / `PATCH /v1/equipment/{cn}` | Tambah (409 bila ada) / ubah |
| `GET /v1/fui/suggestions?category` | Unit non-NORMAL + 3 oil terakhir |
| `POST /v1/fui/suggests` / `GET /v1/fui/suggests?lab_no` | Simpan / riwayat suggest |
| `GET /v1/fui/suggest-report?...` | Oil terakhir non-NORMAL + status suggest |
| `GET /v1/fui/report.pdf?cn` , `GET /v1/fui/pama.pdf?cn` | Laporan PDF (disembunyikan di UI) |
| CRUD `/v1/activities` + `/photos` | Kalender/rekap activity + foto (`?token=` untuk `<img>`) |
| CRUD `/v1/projects` + stages/updates/photos | Project management |
| `POST /v1/safety/sync` , `GET /v1/safety/coverage|records|export|latest-sync` | Bomak 6 PAS |
| `POST /v1/r1bi/sync` , `GET /v1/r1bi/...` | R1BI (struktur sama) |
| `GET /v1/users/me|password|avatar|notifications` | Profil + notifikasi |
| `GET/POST/PATCH/DELETE /v1/admin/users` | Kelola user (proteksi admin terakhir) |
| `GET/PUT /v1/admin/permissions` , `GET /v1/admin/audit` | Matriks izin / audit log |

Error selalu `{detail: "..."}` dan ditampilkan verbatim oleh web (helper `errMsg`).

## Database (`infra/db`, dijalankan berurutan)

| File | Isi |
|---|---|
| `V1__oil_lab_result.sql` | `imports`, `oil_lab_result` (116 kolom), index, `mv_latest_status`, trigger `updated_at` |
| `V2__auth.sql` | `users` + seed admin |
| `V3__imports_progress.sql` | `processed_rows` + status `PROCESSING` (progress bar) |
| `V4__labno_text_caution.sql` | `lab_no` TEXT + condition `CAUTION` |
| `V5__dbr.sql` | `dbr_records` (16 kolom, `UNIQUE(date,cn,start_breakdown)`, `cn_prefix`) |
| `V6__equipment.sql` / `V7__equipment_seed.sql` | `equipment` + 330 unit (**dihasilkan**, jangan edit manual) |
| `V8__activities.sql` | `activities` + `activity_photos` (volume) |
| `V9__roles_permissions.sql` | Role `admin/inputer/viewer` + matriks `role_permissions` |
| `V10__audit_logs.sql` | `audit_logs` (middleware + login logging) |
| `V11__user_avatar.sql` | Kolom `users.avatar` |
| `V12__activity_crew.sql` / `V13__activity_hm.sql` | Kolom `crew` / `hm` |
| `V14__fui_menu.sql` / `V16__sugfui_menu.sql` | Menu `fui` / `sugfui` di matriks |
| `V15__n_si_limits.sql` | Kolom `n_si`/`n_si_max` yang terlewat di V1 |
| `V17__followup_suggest.sql` | `followup_suggests` + menu `fureport` |
| `V18__projects.sql` / `V18__timeline_menu.sql` | Project (4 tabel) / menu `timeline` |
| `V19__safety_pas.sql` | `safety_pas` + `safety_sync_log` + menu `bomak` |
| `V20__safety_r1bi.sql` | `safety_r1bi` + kolom `source` di log sync |

Fresh install: otomatis via `/docker-entrypoint-initdb.d` (urut abjad = urut versi).
Database lama: jalankan manual file yang belum diterapkan (lihat riwayat di bawah).

## Struktur Repo

```
apps/api/      FastAPI (app/api/v1: auth, results, fleet, imports, dbr, equipment,
               activities, projects, safety, r1bi, fui, users; app/services:
               excel_map, dbr_map, safety_sync, r1bi_sync, fui_pdf, pama_pdf)
apps/web/      React+Vite+Tailwind (pages: Dashboard/DBR/Performance/Activity/Timeline/
               Safety/Ribi/Equipment/FUI/Users/Audit/Project/Login; ApexCharts lazy-load)
apps/mobile/   Flutter (Riverpod + GoRouter, Clean Architecture per feature)
infra/db/      Migrasi SQL V1..V20
scripts/       build_equipment_seed.py (generator V7 dari data-equipment/)
data-equipment/ 4 dump sumber equipment
data sample excel/ Contoh file + DBR_format.xlsx (lock ~$* diabaikan)
handoff.md     Kontrak kerja tab Flutter paralel
docker-compose.yml  db:5446, api:8802, web:8803 (+ volume uploads)
.env.example   Template env (copy ke .env, JANGAN commit)
```

## Aturan Bisnis / Parsing Penting

- **Excel oli**: desimal koma Indonesia (`4,9`), `lab_no` teks, grade `N/A/C`,
  condition `NORMAL/CRITICAL/CAUTION`, `ND`/`-` → NULL. Import batch 2000.
- **Excel DBR**: `####` disimpan mentah; typo `SECTION` ditoleransi; header toleran
  spasi; duplikat di-upsert via `(date, cn, start_breakdown)`.
- **CONTINUE**: 40,8% baris DBR adalah carry-over multi-hari. Statistik menghitung
  **kejadian** (tanpa CONTINUE) vs **hari downtime** (dengan CONTINUE) — jangan campur.
- **Equipment**: `NaT`→NULL, tanggal `ADARO/ERKA`→NULL, GS256 dimenangkan pumping.
- **Tanggal**: selalu zona lokal perangkat (`todayLocal`), jangan `toISOString`/UTC.
- **Activity**: crew wajib, CN validasi master, foto tanpa batas jumlah (progress +
  anti double-submit), tambah foto saat Ubah khusus admin.
- **Safety**: timestamp form dayfirst zona WITA (+8); kunci upsert tanggal+NRP+nama;
  thumbnail Drive fallback ke link bila tak publik.
- Batas upload default 50 MB (`MAX_UPLOAD_MB`); avatar 5 MB.

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
# HANYA migrasi yang belum diterapkan, mis:
# docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V20__safety_r1bi.sql
docker compose up -d --build api web
```

Riwayat migrasi VPS: V3+V4 → V5 → V6+V7 → V8 → V9+V10+V11 → V12+V13 →
V14+V15+V16 → V17 → V18 → V19 → V20. Rerun aman (semua `IF NOT EXISTS`/upsert).

## Sinkronisasi Safety (cron)

Tombol Sync ada di halaman (inputer+). Untuk otomatis harian, cron VPS:

```cron
0 5 * * * curl -s -X POST http://localhost:8802/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"ADMIN_PASS"}' | python3 -c "import sys,json,urllib.request; t=json.load(sys.stdin)['access_token']; r=urllib.request.Request('http://localhost:8802/v1/safety/sync', headers={'Authorization':'Bearer '+t}, method='POST'); print(urllib.request.urlopen(r, timeout=300).read().decode())"
15 5 * * * curl -s -X POST http://localhost:8802/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"ADMIN_PASS"}' | python3 -c "import sys,json,urllib.request; t=json.load(sys.stdin)['access_token']; r=urllib.request.Request('http://localhost:8802/v1/r1bi/sync', headers={'Authorization':'Bearer '+t}, method='POST'); print(urllib.request.urlopen(r, timeout=600).read().decode())"
```

(pola curl+login lengkap seperti sebelumnya; timeout 300/600 dtk).

## Troubleshooting

| Gejala | Cek |
|---|---|
| Web blank total | F12 Console → error JS; pastikan `web` di-rebuild setelah pull + hard-refresh (Ctrl+Shift+R) |
| Tampilan lama tak berubah | `git log` di VPS = commit terbaru? rebuild jalan (bukan cache)? hard-refresh? |
| `401` setelah idle | Normal: token exp 60 mnt; auto-logout (admin 60/idle lain 45 mnt, atau saat 401) → login ulang |
| Error `gagal: ... 4xx` | Web menampilkan `detail` server verbatim — ikuti pesannya |
| `500` + traceback SQL | Kirim blok `sqlalchemy.exc...` + `[parameters: ...]` dari `docker logs mte-fs-api` |
| Progress macet di "memproses" | Wajar untuk file besar (parse di background) |
| Dry-run/commit `fail>0` | Lihat 50 error pertama; umumnya header tak dikenal / Lab No kosong / DATE invalid |
| `File terlalu besar` | Naikkan `MAX_UPLOAD_MB` di `.env` + pastikan Nginx `client_max_body_size` cukup |
| Karakter `â€¢` | Pernah: double-encoding di source — cek byte file, bukan header/charset |
| Migrasi gagal `already exists` | Normal bila rerun: semua objek pakai `IF NOT EXISTS` |
