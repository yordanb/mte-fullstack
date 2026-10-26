# MTE Data Center — Fullstack Monitoring Plant

Aplikasi monitoring terpusat untuk plant: **report analisa oli**, **DBR breakdown**,
**performance breakdown**, **master equipment**, **FUI follow-up**, **activity + foto**,
**staging pump**, **Minute of Meeting**, **riwayat issue**, **project management**,
**safety (Bomak 6 PAS + R1BI)**, dan grup **Technical Expert**
(PPM, Measurement, Yazu, Ewacs Performance, TAR Support).

Backend **FastAPI + PostgreSQL**, web **React + Vite + Tailwind**,
mobile **Flutter Android** (`apps/mobile`, Riverpod + GoRouter),
semua berjalan sebagai container Docker di VPS dan diupdate via `git pull`.

> Terakhir diperbarui: 26 Okt 2026 — migrasi terakhir `V38`.

## Arsitektur & Port

| Service | Container | Image/Build | Port host → container |
|---|---|---|---|
| Database | `mte-fs-db` | `postgres:16-alpine` | `5446 → 5432` |
| Backend API | `mte-fs-api` | `./apps/api` | `8802 → 8000` |
| Web dashboard | `mte-fs-web` | `./apps/web` | `8803 → 80` |
| Foto/file upload | volume `uploads` | — | `/data/uploads` di api |

Alur data:
- File `.xlsx` diupload via menu **Update Data** (oli) atau tombol upload di **DBR Breakdown**
  → divalidasi → disimpan ke PostgreSQL oleh background job (progress dipolling dari web).
- CSV breakdown ditarik dari sistem sumber lalu diupload di **Ewacs Performance** (upsert).
- Google Sheets publik (Bomak 6 PAS, R1BI, Yazu) ditarik via tombol **Sync** + cron.
- File `~$*` (lock Excel) diabaikan git (lihat `.gitignore`).

## Fitur Web

Sidebar berkelompok collapsible: **Monitoring / Operasional / Follow Up / Technical Expert /
Administrasi**, autohide overlay, ikon per menu, dark mode penuh, notifikasi
(import + aktivitas), profil (avatar + ganti password), dan auto-logout.

| Grup | Menu | Isi |
|---|---|---|
| Monitoring | **Dashboard** | Data oli terbaru per vessel+unit, pencarian vessel/unit, filter radio Critical (TL/GS/WP), statistik Total/CRITICAL/NORMAL, pagination 10/20/50, label last update khusus oli. Singkatan Unit Id otomatis (FINAL DRIVE→FD, TRANSMISSION→TM, DIFFERENTIAL→DIFF, TANDEM→TDM, HYDRAULIC→HYD, dst — hanya tampilan). |
| Monitoring | **DBR Breakdown** | Tabel 11 kolom (Start/Finish/Total/WO/Notif disembunyikan), filter rentang tanggal (date-picker), C/N, dropdown Code (termasuk opsi baris kosong), pagination, checkbox *Sembunyikan CONTINUE*. Format tanggal `12 Jul 26`. |
| Monitoring | **Performance** | Frekuensi breakdown: granularitas Harian/Mingguan/Bulanan + prefix + code + *Kecualikan CONTINUE* (default on — menghitung **kejadian**, bukan hari downtime). ApexCharts (batang-tumpuk 6 prefix + garis total, lazy-load) + Pareto Top 10 Trouble/Section/Code/Code Number + kartu ringkasan. |
| Monitoring | **Timeline Mingguan** | Ringkasan Activity per rentang tanggal untuk presentasi management. |
| Operasional | **Activity** | Kalender bulanan + drawer harian + tab Rekap. Form: tanggal (DatePicker kalender), crew (wajib, **dropdown tertutup**), kategori, CN, shift, HM, multi-foto. Kategori **Daily Check Dragflow** punya layout khusus: CN jadi dropdown pasangan `EX - WP` (disimpan sebagai kode `WPxxx`), Shift wajib, dan tabel pivot HM per shift. Detail aktivitas: klik foto → **lightbox review** (navigasi ←/→, Esc), tombol **Download** di thumbnail & lightbox, tombol hapus foto. |
| Operasional | **Bomak R1BI** | Safety 6 PAS + R1BI dari Google Sheets (switch tampilan, tombol Sync + cron per sumber): cakupan section bulan berjalan, pengecualian per poin / sorot HIGH RISK, tabel responsif + thumbnail eviden Drive, salin WA bernomor format `nama - tanggal by <staff>` (nama staff disingkat Title Case: kata pertama utuh + inisial kata berikutnya, mis. `YOYOK KRISTIANTO` → `Yoyok K`). |
| Operasional | **Equipment** | Master 330 unit: Code Number, Unit Type, Product, Model, Engine (`MERK - MODEL`), Status; sortir kolom server-side, filter kategori/aktif, ikon mata (detail + serial komponen), Ubah via modal, + Tambah Unit. |
| Operasional | **Staging Pump** | Konfigurasi staging pump **versioned per periode `YYYY-MM`**: grup + sump + system type, urutan pompa per grup dengan **drag & drop** (dnd-kit), salin konfigurasi periode lain, riwayat perubahan (siapa, kapan, dari → ke). |
| Operasional | **Minute of Meeting** | Meeting (judul, tanggal, lokasi, kategori, status open/closed) → agenda → action items (PIC, due date, priority high/medium/low, status open/in_progress/closed, notes). Copy meeting sebelumnya + carry item antar meeting. |
| Operasional | **Riwayat** | Issue tracking per CN: kategori (Breakdown Un/Scheduled, Maintenance Rutin, Inspection, Modification, Lainnya), status (open/in_progress/waiting_part/waiting_crew/closed), progress timeline, parts requirement (needed/ordered/received/installed/cancelled + ETA), evidence foto/file dengan keterangan + lightbox. Kartu daftar issue menampilkan **progress terakhir + tanggal update**. |
| Operasional | **Project** | Project → Tahap (rencana tanggal + bobot) → Update (progress, status RAG, foto eviden); progress agregat, status Terlambat otomatis, timeline vs hari ini. |
| Operasional | **Update Data** | Kartu gaya SAP Fiori: *Report Analisa Oli* (Dry-run + Commit + progress 2 tahap) dan *DBR Breakdown* (Upload + progress). |
| Follow Up | **FUI** | Dossier per unit (ketik CN): kartu equipment (+serial), 10 DBR terbaru (Code USM, tanpa CONTINUE), 10 oil terakhir per component. Tombol Export PDF/PAMA **disembunyikan sementara** (`SHOW_FUI_EXPORT`). |
| Follow Up | **Suggestion FUI** | Unit aktif yang sample terakhirnya non-NORMAL + masing-masing 3 oil terakhir, per kategori; tombol *Suggest Follow Up* per baris non-NORMAL (inputer+). |
| Follow Up | **Report Follow Up** | Semua oil terakhir non-NORMAL + status Sudah/Belum suggest + saran terakhir; filter kategori/cari/status; riwayat suggest per lab. |
| Technical Expert | **PPM** | Placeholder (konten menyusul). |
| Technical Expert | **Measurement** | Placeholder (konten menyusul). |
| Technical Expert | **Yazu** | Pivot **HM bulanan** per unit dari checklist inspeksi unit (sync Google Sheets), sticky header + scroll internal (vertikal & horizontal). Deteksi anomali kenaikan HM harian: **merah** bila delta `< 0` (HM mundur) atau `> 24`, **oranye** 14–24, **hijau** 10–14, normal 0–10. Delta dinormalisasi bila ada hari kosong (`delta / gap hari`). |
| Technical Expert | **Ewacs Performance** | KPI **Physical Availability** + **Ratio SCM vs USM** (persentase), filter tanggal / EGI / Crew / CN, grafik tren PA harian + batang durasi SCM vs USM per tanggal, tabel detail breakdown, dan **Import CSV** (admin) dengan semantik **upsert**: baris dengan key sama diperbarui, baris baru ditambah, data tanggal/unit lain tidak dihapus. |
| Technical Expert | **TAR Support** | Placeholder (konten menyusul). |
| Administrasi | **Users** (admin) | CRUD user + matriks izin per menu (Lihat/Tambah/Ubah/Hapus) untuk 8 role. |
| Administrasi | **Audit Log** (admin) | Siapa login/akses apa/dari mana (termasuk login gagal), filter + pagination. |

Perilaku sesi: **auto-logout saat idle (admin 60 mnt, lainnya 45 mnt)** dan logout
otomatis saat server menolak token (401). Token akses 60 mnt (`JWT_EXP_MIN`).

## Role & Perizinan

| Role | Hak default | Mewarisi (backend) |
|---|---|---|
| `admin` | full semua menu | — |
| `inputer` | tulis (tanpa hapus) | — |
| `mekanik` | tulis Activity & Equipment | — |
| `viewer` | baca saja | — |
| `planner` | seperti inputer | `inputer` |
| `group leader` | seperti mekanik | `mekanik` |
| `section head` | baca saja | `viewer` |
| `adm te` | seperti inputer | `inputer` |

Pewarisan didefinisikan di `apps/api/app/core/deps.py` (`ROLE_INHERITS`), sehingga
`require_role("inputer")` otomatis menerima role yang mewarisinya — tidak perlu
mengubah setiap endpoint. Matriks izin per menu (`role_permissions`) diatur dari
menu **Users**; menu baru wajib menambah key-nya di `role_permissions_menu_check`.

## API (base `/api`, auth Bearer JWT; tulis = role di atas, baca = semua role)

| Area | Method & Path |
|---|---|
| Auth | `POST /v1/auth/login` · `POST /v1/auth/refresh` · `GET /v1/auth/me` |
| Hasil oli | `GET /v1/results/latest-per-unit` · `GET /v1/results` · `GET /v1/results/units` · `GET /v1/results/{lab_no}` |
| Import oli | `POST /v1/imports?dry_run=` · `GET /v1/imports/latest` · `GET /v1/imports/{import_id}` |
| DBR | `POST /v1/dbr/imports` · `GET /v1/dbr/records` · `GET /v1/dbr/codes` · `GET /v1/dbr/stats` |
| Fleet | `GET /v1/fleet/alerts` · `GET /v1/fleet/latest` |
| Equipment | `GET /v1/equipment` · `GET /v1/equipment/{cn}` · `POST /v1/equipment` · `PATCH /v1/equipment/{cn}` |
| FUI | `GET /v1/fui/suggestions` · `POST /v1/fui/suggests` · `GET /v1/fui/suggests` · `GET /v1/fui/suggest-report` · `GET /v1/fui/report.pdf` · `GET /v1/fui/pama.pdf` |
| Activity | `GET /v1/activities/month` · `/recap` · `/filters` · `GET/POST/PATCH/DELETE /v1/activities` · `POST /v1/activities/{aid}/photos` · `GET/DELETE /v1/activities/{aid}/photos/{pid}` (`?token=` untuk `<img>`) |
| Project | `GET/POST/PATCH/DELETE /v1/projects` + `/stages`, `/updates`, foto eviden |
| Staging Pump | `GET/POST/PATCH/DELETE /v1/staging/groups` · `POST /v1/staging/groups/{gid}/pumps` · `PATCH/DELETE /v1/staging/pumps/{pid}` · `POST /v1/staging/reorder` · `POST /v1/staging/move` · `POST /v1/staging/copy` · `GET /v1/staging/changes` · `GET /v1/staging/equipment` |
| MOM | `GET/POST/PATCH/DELETE /v1/mom/meetings` · `POST /v1/mom/meetings/copy` · `POST /v1/mom/meetings/{mid}/carry/{item_id}` · CRUD agendas & items |
| Riwayat | `GET/POST/PATCH/DELETE /v1/riwayat/issues` · progress & parts CRUD · foto progress/part (upload, notes, delete, serve) |
| Safety | `POST /v1/safety/sync` · `GET /v1/safety/{latest-sync,coverage,records,export}` |
| R1BI | `POST /v1/r1bi/sync` · `GET /v1/r1bi/{latest-sync,coverage,records,export}` |
| Yazu | `POST /v1/yazu/sync` · `GET /v1/yazu/{stats,units,pivot,raw}` |
| Ewacs | `POST /v1/ewacs/import` · `GET /v1/ewacs/{filters,kpi,trend,detail}` · `DELETE /v1/ewacs/all` (admin) |
| Users | `GET /v1/users/me` · `PATCH /v1/users/password` · `POST /v1/users/avatar` · `GET /v1/users/avatar/{username}` · `GET /v1/users/notifications` |
| Admin | CRUD `/v1/admin/users` · `GET/PUT /v1/admin/permissions` · `GET /v1/admin/audit` |

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
| `V12__activity_crew.sql` / `V13__activity_hm.sql` | Kolom `crew` / `hm` pada activities |
| `V14__fui_menu.sql` / `V16__sugfui_menu.sql` | Menu `fui` / `sugfui` di matriks |
| `V15__n_si_limits.sql` | Kolom `n_si`/`n_si_max` yang terlewat di V1 |
| `V17__followup_suggest.sql` | `followup_suggests` + menu `fureport` |
| `V18__projects.sql` / `V18__timeline_menu.sql` | Project (4 tabel) / menu `timeline` |
| `V19__safety_pas.sql` | `safety_pas` + `safety_sync_log` + menu `bomak` |
| `V20__safety_r1bi.sql` | `safety_r1bi` + kolom `source` di log sync |
| `V21__staging_pump.sql` / `V22__staging_defer_constraint.sql` | Staging pump (grup, item per periode, log perubahan) / UNIQUE `role_order` jadi DEFERRABLE |
| `V23__activity_shift.sql` | Kolom `shift` pada activities (Daily Check Dragflow) |
| `V24__role_mekanik.sql` | Role `mekanik` |
| `V25__mom.sql` / `V26__mom_agendas.sql` | Meeting + action items / agenda per meeting |
| `V27__riwayat.sql` | `riwayat_issues`, `riwayat_progress`, `riwayat_parts` |
| `V28__riwayat_photos.sql` | Evidence foto progress |
| `V29__riwayat_parts_progress.sql` / `V30__riwayat_part_photos.sql` | Part terkait progress / foto part request |
| `V31__photo_notes.sql` | Kolom `notes` untuk evidence foto |
| `V32__technical_expert_menus.sql` | Menu `ppm` & `measurement` (grup Technical Expert) |
| `V33__yazu_table.sql` | Tabel `yazu` + menu `yazu` |
| `V34__new_roles.sql` | Role `planner`, `group leader`, `section head`, `adm te` |
| `V35__ewacs.sql` | `ewacs_breakdown` + index + menu `ewacs` |
| `V36__tar_support.sql` | Menu `tarsupport` (grup Technical Expert) |
| `V37__ewacs_upsert.sql` | Dedupe + unique index natural key Ewacs (`tanggal, cn, shift, kode, start_bd`) |
| `V38__yazu_timezone_fix.sql` | Koreksi data Yazu lama: `waktu` digeser −8 jam (naive WITA yang tersimpan sebagai UTC); idempoten dengan guard |

Fresh install: otomatis via `/docker-entrypoint-initdb.d` (urut abjad = urut versi).
Database lama: jalankan manual file yang belum diterapkan (lihat riwayat di bawah).

## Struktur Repo

```
apps/api/      FastAPI — app/api/v1: auth, results, fleet, imports, dbr, equipment,
               activities, projects, staging, mom, riwayat, safety, r1bi, fui, yazu,
               ewacs, users; app/services: excel_map, dbr_map, safety_sync, r1bi_sync,
               fui_pdf, pama_pdf
apps/web/      React+Vite+Tailwind — pages: Dashboard/DBR/Performance/Activity/Timeline/
               Safety/Ribi/Equipment/Staging/Mom/Riwayat/FUI/Project/Ppm/Measurement/
               Yazu/Ewacs/TarSupport/Users/Audit/Login (ApexCharts lazy-load)
apps/mobile/   Flutter (Riverpod + GoRouter, Clean Architecture per feature)
infra/db/      Migrasi SQL V1..V37
scripts/       build_equipment_seed.py (generator V7), analyze_staging_pompa.py
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
  Semua input tanggal di UI memakai **DatePicker** flatpickr (kalender, tanpa ketik manual).
- **Activity**: crew wajib & hanya pilih (tanpa input bebas), CN validasi master,
  foto tanpa batas jumlah (progress + anti double-submit), tambah foto saat Ubah khusus admin.
  Kategori **Daily Check Dragflow**: CN disimpan sebagai **kode `WPxxx`** (bukan label
  `EXxxx - WPxxx`) karena pivot HM mencari key `${wp}|${date}|${shift}`.
- **Riwayat**: progress `log_date` bertimestamp; kartu daftar memakai
  `LEFT JOIN LATERAL` (progress terbaru per issue) agar tidak duplikat baris.
- **Staging**: konfigurasi per periode `YYYY-MM`; `role_order` UNIQUE DEFERRABLE
  supaya reorder satu statement tidak bentrok.
- **Ewacs**: import = **upsert** dengan natural key `(tanggal, cn, shift, kode, start_bd)`.
  Baris sekey diperbarui, baris baru ditambah, baris basi hanya dihapus di dalam scope
  `tanggal+cn` yang ada di file — periode/unit lain tidak disentuh. CSV: `tanggal`
  `YYYYMMDD`, `Durasi_2` dalam jam, `Kode_1` SCM/USM/TSM/TUM/ICM/ISM.
  PA = `(24 × unit × hari − (durasi SCM+USM)) / (24 × unit × hari) × 100%`.
- **Yazu**: HM harian dari checklist inspeksi; anomali delta `< 0` (HM mundur) atau `> 24`
  ditandai merah, 14–24 oranye, 10–14 hijau. Kolom `Waktu` di sheet = **jam lokal WITA
  (GMT+8)**, di-parse sebagai datetime **tz-aware** (`Asia/Makassar`) sebelum masuk
  `TIMESTAMPTZ` — naive datetime akan dibaca sebagai UTC dan menggeser tanggal +8 jam.
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
# docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V37__ewacs_upsert.sql
docker compose up -d --build api web
```

Riwayat migrasi VPS: V3+V4 → V5 → V6+V7 → V8 → V9+V10+V11 → V12+V13 →
V14+V15+V16 → V17 → V18 → V19 → V20 → V21+V22 → V23+V24 → V25+V26 →
V27..V31 → V32 → V33 → V34 → V35 → V36 → V37 → V38.
Rerun aman (semua `IF NOT EXISTS`/upsert).

Catatan: menambah menu baru berarti memperbarui `role_permissions_menu_check`
(drop + add) dan idealnya menambah key di `MENUS` backend + frontend.

## Sinkronisasi Google Sheets (cron)

Tombol Sync ada di halaman terkait (inputer+). Untuk otomatis harian, cron VPS:

```cron
0 5 * * * curl -s -X POST http://localhost:8802/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"ADMIN_PASS"}' | python3 -c "import sys,json,urllib.request; t=json.load(sys.stdin)['access_token']; r=urllib.request.Request('http://localhost:8802/v1/safety/sync', headers={'Authorization':'Bearer '+t}, method='POST'); print(urllib.request.urlopen(r, timeout=300).read().decode())"
15 5 * * * curl -s -X POST http://localhost:8802/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"ADMIN_PASS"}' | python3 -c "import sys,json,urllib.request; t=json.load(sys.stdin)['access_token']; r=urllib.request.Request('http://localhost:8802/v1/r1bi/sync', headers={'Authorization':'Bearer '+t}, method='POST'); print(urllib.request.urlopen(r, timeout=600).read().decode())"
30 5 * * * curl -s -X POST http://localhost:8802/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"ADMIN_PASS"}' | python3 -c "import sys,json,urllib.request; t=json.load(sys.stdin)['access_token']; r=urllib.request.Request('http://localhost:8802/v1/yazu/sync', headers={'Authorization':'Bearer '+t}, method='POST'); print(urllib.request.urlopen(r, timeout=600).read().decode())"
```

## Troubleshooting

| Gejala | Cek |
|---|---|
| Web blank total | F12 Console → error JS; pastikan `web` di-rebuild setelah pull + hard-refresh (Ctrl+Shift+R) |
| Tampilan lama tak berubah | `git log` di VPS = commit terbaru? rebuild jalan (bukan cache)? hard-refresh? |
| Menu baru tidak muncul | Migrasi menu belum dijalankan (`role_permissions` belum punya baris untuk menu itu) |
| `401` setelah idle | Normal: token exp 60 mnt; auto-logout (admin 60/idle lain 45 mnt, atau saat 401) → login ulang |
| Error `gagal: ... 4xx` | Web menampilkan `detail` server verbatim — ikuti pesannya |
| `500` + traceback SQL | Kirim blok `sqlalchemy.exc...` + `[parameters: ...]` dari `docker logs mte-fs-api` |
| Progress macet di "memproses" | Wajar untuk file besar (parse di background) |
| Dry-run/commit `fail>0` | Lihat 50 error pertama; umumnya header tak dikenal / Lab No kosong / DATE invalid |
| Import Ewacs menghapus data | Sudah diperbaiki di `V37` + commit `26b7dac` (upsert, bukan replace) |
| `File terlalu besar` | Naikkan `MAX_UPLOAD_MB` di `.env` + pastikan Nginx `client_max_body_size` cukup |
| Karakter `â€¢` | Pernah: double-encoding di source — cek byte file, bukan header/charset |
| Migrasi gagal `already exists` | Normal bila rerun: semua objek pakai `IF NOT EXISTS` |
