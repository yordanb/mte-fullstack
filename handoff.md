# Handoff — Aplikasi Flutter Android (MTE Data Center)

Dokumen untuk sesi/tab paralel yang mengerjakan aplikasi mobile Android.
Backend dan web sudah jadi dan stabil — mobile cukup menjadi **klien API yang sama**.
Repo: `mte-fullstack`, branch `main`.

## 1. Gambaran

- **Backend**: FastAPI + PostgreSQL 16. Semua logika (auth, validasi, agregasi) di server.
- **Web**: React+Vite+Tailwind (referensi tampilan & perilaku — tiru alurnya).
- **Mobile (yang dibangun)**: Flutter Android, konsumsi API di bawah via JSON + Bearer token.

## 2. Menjalankan backend lokal (untuk dev mobile)

```bash
cp .env.example .env   # isi password & secret
docker compose up -d --build
# API:   http://localhost:8802  (docs interaktif: /docs)
# Web:   http://localhost:8803  (pembanding tampilan)
# DB:    localhost:5446
```

Dari emulator Android, `localhost` = emulator itu sendiri → pakai
`http://10.0.2.2:8802`. Dari HP fisik, pakai IP LAN laptop + pastikan API bisa
diakses (jangan hardcode IP VPS produksi di build debug).

Akun awal: `admin` (dibuat otomatis dari `ADMIN_USERNAME`/`ADMIN_PASSWORD` di `.env`).

## 3. Auth

| Endpoint | Body | Respons |
|---|---|---|
| `POST /v1/auth/login` | `{username, password}` | `{access_token, refresh_token, role, username}` |
| `POST /v1/auth/refresh` | `{refresh_token}` | `{access_token}` |
| `GET /v1/users/me` | header Bearer | `{username, role, avatar_url, permissions}` |

- Semua request lain: header `Authorization: Bearer <access_token>`.
- Token akses hidup **60 menit** (`JWT_EXP_MIN`); refresh token 7 hari.
  Web tidak memakai refresh — mobile **disarankan pakai**: saat 401, coba refresh
  sekali, kalau gagal → lempar ke login.
- Saat 401 final → hapus token tersimpan → halaman login.
- Role: `admin`, `inputer`, `viewer`.
  - Baca (GET): semua role boleh (kecuali endpoint `/v1/admin/*` khusus admin).
  - Tulis (POST/PATCH/PUT/DELETE): `inputer` + `admin`. `viewer` read-only.
  - Backend mengembalikan **403** bila role tak cukup, **404** bila data tak ada,
    **400/409** untuk validasi (`{detail: "pesan"}`).

## 4. Izin per menu (`permissions` dari `/v1/users/me`)

```json
{ "dashboard": {"view":true,"add":false,"edit":false,"delete":false}, ... }
```

Menu: `dashboard, dbr, performance, activity, equipment, fui, sugfui, fureport,
timeline, import`. `admin` selalu penuh. Sembunyikan menu/tombol
tanpa izin (backend tetap menegakkan via 403).

## 5. Kontrak endpoint

Base path di bawah prefix `/v1`. Pagination: `{total, page, page_size, data: [...]}`.
Tanggal kirim sebagai `YYYY-MM-DD`; CN selalu **UPPERCASE**.

**Oil lab** (116 kolom, kunci `lab_no` teks):
- `GET /results/latest-per-unit?limit=&prefix=&condition=` — 1 baris terbaru per
  (vesselid, unit_id). Dipakai dashboard. `prefix` = 2 huruf (TL/GS/WP),
  `condition` cth `CRITICAL`.
- `GET /results?vesselid=&unit_id=&limit=&before=` — 20 terbaru per vessel (limit ≤100).
- `GET /results/units?vesselid=` → `{data: [unit_id...]}` (daftar component 1 vessel).
- `GET /results/{lab_no}` — detail 1 baris full-column.

**Import Excel oli**:
- `POST /imports?dry_run=true|false` (multipart `file`) → dry-run: `{total, ok, fail,
  errors[50], preview}`; commit (202): `{import_id, status: PROCESSING}`.
- `GET /imports/{import_id}` → `{status, total_rows, processed_rows, ok_rows,
  fail_rows}` — polling tiap 2 detik untuk progress bar (2 tahap: baca lalu simpan).
- `GET /imports/latest` → upload **oli** terakhir (DBR dikecualikan) untuk label last update.

**DBR breakdown** (kunci unik `date+cn+start_breakdown`):
- `POST /dbr/imports` (multipart, 202, pola sama seperti import oli).
- `GET /dbr/records?date_from&date_to&cn&prefix&code&page` — default 30 hari terakhir;
  `code=__EMPTY__` = baris Code kosong; `exclude_continue=true` buang carry-over.
- `GET /dbr/codes` → `{data: [...]}` dropdown.
- `GET /dbr/stats?date_from&date_to&granularity=day|week|month&prefix&code&exclude_continue=true`
  → `{granularity, excluded_continue, series:[{period, prefix, n}], top_trouble,
  top_section, top_code, top_cn:[{k,v}], summary:{total, units, days, empty_code}}`.
  Default 90 hari, mingguan. Frekuensi = **hitung baris** (dengan CONTINUE = hari
  downtime; tanpa CONTINUE = kejadian breakdown).

**Equipment** (330 unit, PK `cn`, kategori `BIGWHEEL/LIGHTING/MOBILE/PUMPING`):
- `GET /equipment?search&category&prefix&aktif&page` (aktif=true/false).
- `GET /equipment/{cn}` (404 bila tak ada) • `POST /equipment` (409 bila CN ada) •
  `PATCH /equipment/{cn}` (parsial; tanggal/angka string diterima, diparse server).

**FUI / Follow-up** (read-only semua role; tulis inputer+admin):
- `GET /fui/suggestions?category=` → unit aktif yang sample terakhirnya non-NORMAL
  + masing-masing 3 oil terakhir (maks 600 baris).
- `POST /fui/suggests {lab_no, suggestion, pic?}` → 201 `{id}` (riwayat banyak per lab).
- `GET /fui/suggests?lab_no=` → riwayat 1 sample.
- `GET /fui/suggest-report?category&search&has_suggest&page` → oil terakhir
  non-NORMAL per unit + `suggest_count` + suggest terbaru.
- `GET /fui/report.pdf?cn=` dan `GET /fui/pama.pdf?cn=` → file PDF (header Bearer,
  atau unduh via blob). **Catatan: tombol export disembunyikan di web karena
  hasilnya belum sesuai — endpoint tetap hidup, jangan jadikan fitur utama mobile.**

**Activity + foto** (kalender):
- `GET /activities/month?year&month` → `{counts: {"YYYY-MM-DD": n}}` (dot kalender).
- `GET /activities?date=` → list + `photos` (jumlah) + `cover_id`.
- `GET /activities/recap?year&month&crew&category` → rekap sebulan (maks 500).
- `GET /activities/{id}` → detail + `photos:[{id, orig_name, ...}]`.
- `POST /activities` (multipart: `date,title,description?,category?,crew(wajib),cn?,hm?,files[]`)
  → 201. CN divalidasi ke master equipment (400 bila tak ada).
- `PATCH /activities/{id}` (JSON parsial; tanggal string `YYYY-MM-DD` OK).
- `DELETE /activities/{id}` (file ikut terhapus).
- `POST /activities/{id}/photos` (multipart `files[]`, **khusus admin**).
- `DELETE /activities/{id}/photos/{pid}`.
- `GET /activities/{id}/photos/{pid}` → file gambar. **`<img>`/Image.network tak bisa
  kirim header → endpoint ini juga terima `?token=<access_token>`**. Pola URL:
  `/api/v1/activities/{aid}/photos/{pid}?token=...` (web pakai base `/api` karena
  reverse-proxy; mobile langsung ke host API tanpa `/api` — sesuaikan base URL).

**User / admin** (khusus `admin`, kecuali tercatat lain):
- `GET /v1/users/me`, `PATCH /v1/users/password {old_password, new_password}`,
  `POST /v1/users/avatar` (multipart image ≤5MB), `GET /v1/users/avatar/{username}`
  (mendukung `?token=`, 404 bila belum ada foto → tampilkan inisial),
  `GET /v1/users/notifications` → `{imports[5], activities[5]}`.
- `GET/POST /v1/admin/users`, `PATCH/DELETE /v1/admin/users/{username}`
  (proteksi: tak bisa hapus diri sendiri / kehabisan admin).
- `GET/PUT /v1/admin/permissions` (baris admin terkunci).
- `GET /v1/admin/audit?date_from&date_to&username&path&page` → log
  (waktu, user, role, method, path, status, IP, user-agent).

## 6. Aturan bisnis yang wajib ditiru

- **CONTINUE**: 40,8% baris DBR adalah carry-over (`ACTION=CONTINUE`). Frekuensi
  kejadian = kecualikan CONTINUE; hari downtime = sertakan. Jangan campur tanpa label.
- **Singkatan Unit Id** (tampilan dashboard oli saja, DB mentah):
  FINAL DRIVE LEFT/RIGHT→FD LH/RH (+varian FRONT/REAR/CENTER→FR/RR/CTR),
  FINAL DRIVE→FD, DIFFERENTIAL(+CENTER/FRONT/REAR)→DIFF(+CTR/FR/RR),
  TRANSMISSION→TM, TANDEM LEFT/RIGHT→TDM LH/RH, HYDRAULIC→HYD.
- **Format tanggal tampil**: `12 Jul 26` (DBR), `dd/mm/yyyy hh:mm` (log).
  Input/filter tanggal selalu `YYYY-MM-DD` dan **zona lokal perangkat**
  (jangan `toISOString`/UTC — pernah off-by-one).
- **Desimal Indonesia** di Excel oli (`4,9`), `ND`/`-` → NULL.
- **Duplikat DBR** di-upsert via `(date, cn, start_breakdown)`.
- **GS256** ganda (lighting vs pumping) — versi pumping yang dipakai.
- **Auto-logout web saat idle: admin 60 menit, lainnya 45 menit** (timer reset tiap
  aktivitas; 401 dari server juga melempar ke login) — mobile tiru sesuai kebutuhan.
- **Foto tanpa batas jumlah** (streaming upload + progress bar + cegah double-submit);
  avatar dibatasi 5MB.
- **`mv_latest_status`** di-refresh tiap commit import oli (sumber report follow-up).

## 7. Checklist parity fitur (acuan: menu web)

Dashboard oli (latest per unit + cari + filter Critical + last update) • DBR tabel +
filter + sembunyikan CONTINUE • Performance (grafik + Pareto, pakai chart lib
Flutter) • Equipment (cari/filter/sort/tambah/ubah/detail) • FUI dossier per CN •
Suggestion FUI • Report Follow Up + Suggest • Activity kalender + rekap + foto •
Update Data (upload oli/DBR + progress) • Users + izin (admin) • Audit Log (admin) •
profil (avatar + ganti password) + dark mode + notifikasi.

## 8. Perintah & alur kerja paralel

- Kerja di branch turun
...[truncated 615 chars]

## 9. Progress mobile Flutter (MTE Data Center)

- **M1 SELESAI (2026-10-08)**: project `apps/mobile` (`id.mibt/mte_data_center`).
  Login + refresh-once-401 + guard route + dashboard oli (latest per unit,
  cari vessel, filter Critical TL/GS/WP, last update) + dark mode + logout.
  `flutter analyze` bersih, `flutter test` lolos, APK debug terbuild.
- **Keputusan yang mengikat sesi paralel**:
  - Default `baseUrl = https://mte2.mibt.my.id/api` (`app_config.dart:7`).
    Dev lokal/emulator wajib override:
    `--dart-define=API_BASE_URL=http://10.0.2.2:8802`.
    `/api` wajib di produksi (nginx strip prefix, pola web); langsung
    `http://host:8802` tanpa `/api` hanya untuk dev langsung-ke-API.
  - `minSdk = 23` (`android/app/build.gradle.kts`) — syarat
    `flutter_secure_storage` v10.
  - Kunci storage: `mte_access/mte_refresh/mte_role/mte_username/mte_perm/mte_theme`.
  - `crit` dashboard = `condition != NORMAL` (WARNING ikut, sama seperti web).
- **M2 SELESAI (2026-10-08, Activity)**: kalender bulanan (dot jumlah,
  minggu mulai Senin) + list harian + tab rekap + filter crew/kategori +
  detail + foto (`?token=`, tap = pratinjau) + tambah/ubah/hapus aktivitas +
  tambah/hapus foto. Upload multipart `files[]` + progress bar + cegah
  double-submit; tambah-foto saat ubah khusus admin; gating tombol
  `activity.add/edit/delete`. Crew `Pumping/Lighting/Mobile/Grader/PCH`,
  kategori `Proker/FUI/USM/SCM` (bebas ketik). `analyze` bersih, 6 test
  lolos, APK debug terbuild.
- **M3 SELESAI (2026-10-08, DBR)**: tabel 11 kolom + filter tanggal/CN/code
  (dropdown `GET /dbr/codes` + `__EMPTY__` = Code kosong) + sembunyikan
  CONTINUE client-side (tidak dikirim ke server, sama seperti web) +
  paginasi server page_size 20 + tanggal tampil `fmtDdbr`. Default 30 hari
  terakhir. `analyze` bersih, 8 test lolos, APK debug terbuild.
- **M4 SELESAI (2026-10-08, Performance)**: kartu ringkasan (total, unit,
  hari, rata-rata) + grafik frekuensi stacked-bar per prefix top 6 +
  Lainnya + tooltip total (fl_chart, ganti ApexCharts) + 4 Pareto
  (Trouble/Section/Code/CN) + filter tanggal/granularitas/prefix/code +
  Kecualikan CONTINUE default true + label jumlah baris dikecualikan.
  Default 90 hari mingguan. `fl_chart` dipatok **0.69.2** (1.1.0 tidak
  kompatibel dengan Flutter 3.32.5). `analyze` bersih, 12 test lolos,
  APK debug terbuild.
- **M5 SELESAI (2026-10-08, Equipment)**: cari CN/type (uppercase) +
  filter kategori/aktif + sort header server (tanda panah, default cn asc) +
  tambah unit (CN + kategori wajib, 409 bila duplikat) + ubah 11 field +
  aktif + detail penuh (18 field + Komponen/Serial specs) + paginasi 20 +
  baris nonaktif redup. Tombol tambah/ubah gated `equipment.add/edit`.
  `analyze` bersih, 15 test lolos, APK debug terbuild.
- **Fix backend import (2026-10-08, di luar milestone mobile)**: header
  Excel kini di-strip + validasi fail-fast 400 (`Header hilang`/`Sheet
  tidak ditemukan) di `dbr.py`/`imports.py` — menutup kasus DBR
  `ok=0 fail=148` akibat header `DATE` tidak persis. Perlu
  `docker compose up -d --build api` di VPS.
- **M6 SELESAI (2026-10-08, FUI)**: dossier per CN (info equipment +
  10 DBR USM tanpa CONTINUE server-side + 10 oil per component) + Suggestion
  (kategori default MOBILE, grup vessel/unit, tombol Suggest bila bukan
  viewer, form saran+PIC) + Report Follow Up (filter kategori/cari/status
  Sudah-Belum, badge, saran terakhir, Riwayat per lab, paginasi 20).
  Tabel oil bersama (sel merah bila grade bukan N). Export PDF diskip
  (disembunyikan di web). `analyze` bersih, 18 test lolos, APK terbuild.
- **M7 SELESAI (2026-10-08, Update Data + Users + Audit + Profil)**:
  Update Data 2 tile (oli Dry-run/Commit + DBR Upload, file_picker .xlsx,
  polling 2 dtk, dry-run tampil ok/fail + 10 error + preview, gate
  `import.view/add`); Users admin (tambah/ubah role+password/hapus +
  matriks izin inputer/viewer × 10 menu, tulis-butuh-lihat, refreshMe);
  Audit admin (filter 7 hari/username/path + badge status + paginasi);
  Profil (avatar ?token= + inisial fallback, ganti foto, ganti password);
  Notifikasi (5 import + 5 aktivitas, lonceng di AppBar).
  `file_picker` v11 API `FilePicker.pickFiles` (tanpa `.platform`).
  `analyze` bersih, 22 test lolos, APK terbuild.
- **SEMUA MILESTONE MOBILE SELESAI.** Sisa: uji E2E vs produksi + build
  release (keystore) bila diperlukan.
- **Web Timeline Mingguan (2026-10-09, branch web/activity-timeline)**:
  menu baru `apps/web/src/pages/Timeline.tsx` — timeline Activity per
  rentang tanggal (maks 31 hari, default 7 hari terakhir) + filter crew/
  kategori, ringkasan (total, hari aktif, foto, hari tersibuk), mini grafik
  per hari, foto cover + expand foto per kegiatan, tombol Cetak/PDF.
  Izin ikut `activity.view`. `tsc` + `vite build` lolos.
  Revisi: infografis horizontal ala template (kapsul hari 7 warna di rel
  panah + kartu selang-seling atas/bawah + konektor lengkung + klik kartu
  lompat ke detail).
- **Izin menu vessel -> timeline (2026-10-09, branch chore/menu-permissions)**:
  `vessel` dihapus dari matriks, `timeline` ditambahkan (backend MENUS +
  migrasi V18 + web Users/Layout/App + mobile permMenus; alias vessel
  dihapus). Hak vessel lama diwariskan ke timeline via UPDATE. V18 harus
  diterapkan manual di VPS (tanpa migration runner).