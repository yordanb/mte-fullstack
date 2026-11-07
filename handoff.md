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

> **Catatan (2026-11-04)**: teks asli bagian ini terpotong literal
> (`...[truncated 615 chars]`) sejak commit `145442e` dan tidak pernah
> masuk repo. Isi di bawah **direkonstruksi** dari kebiasaan repo —
> koreksi bila ada aturan lama yang belum tercakup.

- Kerja di branch turun dari `main` (pola `mobile/<topik>` /
  `web/<topik>` / `chore/<topik>`; mis. `mobile/safety-bomak-r1bi`,
  `web/activity-timeline`) — jangan commit langsung ke `main`.
- Setelah selesai & merge ke `main`, tandai di §9 dokumen ini dengan
  "(sudah merge ke main)" (pola commit `docs: tandai ...`).
- **Migrasi DB**: buat file `infra/db/V<n>__nama.sql`; cek dulu nomor
  di folder — pernah bentrok (V18: projects vs timeline). Penerapan di
  VPS manual, tanpa migration runner.
- **Verifikasi wajib sebelum menyatakan selesai**: mobile `flutter
  analyze` + `flutter test` (+ APK terbuild); web `npx tsc --noEmit` +
  `vite build`.
- **Perintah cepat**: backend+web lokal `docker compose up -d --build`
  (§2); mobile `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8802`.
- Jangan commit file kerja non-kode (mis. `data-manpower/*`, hasil
  build); deploy VPS (pull + migrasi + rebuild container) dijalankan
  manual oleh user — jangan asumsikan akses SSH.

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
- **SEMUA MILESTONE MOBILE SELESAI (M1–M7).** Sisa: uji E2E vs produksi +
  build release (keystore) bila diperlukan.
- **Mobile Safety Bomak+R1BI (2026-10-14, sudah merge ke main)**:
  halaman `/bomak` + menu drawer (gate `bomak.view`): switch Bomak/R1BI,
  navigasi bulan, filter section/risiko/cari, Sync (timeout 10 mnt,
  `bomak.add`), salin WA via clipboard (format persis web), tabel 13/10
  kolom + badge P1-P5/HIGH RISK + thumb Drive, cakupan per section,
  pengecualian 7 poin, paginasi 20. `permMenus` mobile jadi 12 aktual.
  `analyze` bersih, 28 test lolos, APK terbuild.
- **Dashboard parameter merah (2026-10-14, sudah merge ke main)**:
  kartu dashboard kini menampilkan parameter ber-grade bukan-N
  (nama + nilai, merah, ` - `-separated, urutan VISC..Na) di bawah info
  lab. `LabRow` diperluas dengan vals/grades dari 43 kolom API
  (sebelumnya tidak dibawa). `analyze` bersih, 29 test lolos, APK terbuild.
- **Koreksi kartu dashboard (2026-10-14, sudah merge ke main)**:
  nomor lab + tanggal analysis dihapus; hanya `Sample dd/MM/yyyy`.
- **Paritas web 14-16 Okt (2026-10-16, sudah merge ke main)**:
  role `mekanik` + 13 menu (`staging`), guard toggle izin (auto-uncheck
  write saat uncheck view), Activity `shift` field + toggle Shift 1/2
  (kategori Daily Check Dragflow), 3 kategori baru, tab DC Dragflow
  (6 pasang EX/WP × tanggal, HM S1 biru / S2 amber), hapus stat P6/FU
  kosong di Bomak. `analyze` bersih, 31 test, APK terbuild.
- **Minute of Meeting mobile (2026-10-17, branch mobile/mom)**:
  mobile screen untuk MoM — list meeting (filter Open/Closed +
  kategori), detail meeting + action items (checkbox toggle complete,
  badge priority/status, overdue indicator), form meeting + item
  (bottom sheet). `permMenus` 14 (`mom`), menu drawer "Meeting",
  route `/mom`. `analyze` bersih, 31 test, APK terbuild.
- **Catatan migrasi ganda V18**: `V18__projects.sql` (tab sebelah) vs
  `V18__timeline_menu.sql` (sesi ini) — urutan alfabet menaruh projects
  dulu; state akhir CHECK dari V19 mencakup semuanya. Jangan
  terapkan-ulang V18 timeline di VPS bila V19 sudah masuk (ALTER akan
  gagal bila baris project/bomak sudah ada).
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
- **Suggestion System mobile + web SS (2026-10-31, sudah merge ke main)**:
  fitur `ss` baru (`lib/src/features/ss/*`: api, models, providers, page)
  — KPI, target crew, trend (grafik), records, filter; route `/ss` +
  menu drawer "Suggestion System"; test regresi `ss_test.dart`. API
  `/v1/ss/*` digate `require_role("admin")` — praktis masih admin-only.
  Web: kartu SS 3 kolom ≥ md (768px) + tinggi grafik dipangkas ~25%.
  Gradle pindah JDK 21 (`android/gradle.properties`). Catatan: `ss`
  belum masuk `permMenus` mobile (matriks izin Users, masih 14 menu;
  backend `MENUS` sudah 29) — **sudah dibereskan 2026-11-04, lihat entri
  "Sinkron izin menu/role"**.
  `analyze` bersih, test lolos, APK terbuild.
- **Fix pasangan DC Dragflow EX339 (2026-10-31, sudah merge ke main)**:
  pair EX339 diubah WP1039 → WP1309 (mobile `activity_page.dart` + web
  `Pages.tsx`). `flutter analyze` + build web lolos.
- **Paritas web terbaru (per 2026-11-04, (1) & (2) sudah merge ke main;
  (3) menunggu modul Proker di mobile)**:
  (1) form Activity web — Kategori dropdown (tanpa ketik manual) + opsi
  "Replace Gland Packing", centang "DC Dragflow" di kanan Tanggal (auto
  kategori Daily Check Dragflow + Shift + crew Pumping) — commit
  `4934628`; (2) DBR Breakdown — tombol toggle "Pumping" di kanan
  checkbox "Sembunyikan CONTINUE" (C/N diawali WP, semua code; param
  `prefix=WP` sudah ada) — `ce41a49`; (3) tombol "Refresh HM" di web
  Proker, Proker Booster, Proker Injector, Proker Thermostat CAT
  (`Thermostat.tsx`) — `b04f818`. Normalisasi EGI Ewacs (V60/V61 +
  `EGI_FIX`) murni server-side — tidak perlu aksi mobile.
- **Paritas web Nov 2026 (2026-11-04, sudah merge ke main)**:
  - Activity form (web `4934628`): Kategori select-only — bawaan `ACT_CATS`
    + kategori dari data `GET /activities/filters` + opsi "Replace Gland
    Packing" + kategori lama saat ubah; crew juga select-only (crew lama
    ikut bila di luar daftar); checkbox "DC Dragflow" di samping Tanggal →
    auto kategori Daily Check Dragflow + crew Pumping + pilihan Shift
    muncul (batal = kategori kembali & shift direset); saat DC: CN dropdown
    6 pasangan EX-WP (nilai lama tampil "(data lama)"), kategori terkunci,
    validasi wajib CN + HM + Shift. `activityCrews`/`activityCats`/
    `dragflowPairs` pindah ke `activity_models.dart` (EX339-WP1309 kini
    satu sumber untuk form + tab DC Dragflow).
  - DBR Breakdown (web `ce41a49`): FilterChip "Pumping" — kirim
    `prefix=WP`, semua code (dropdown Code dikosongkan + nonaktif).
  - DBR + Dashboard (web `aaed7e8`): baris "Last update" upload DBR
    (`GET /imports/latest?sheet=DBR` — pastikan API `imports.py` terbaru
    sudah di-deploy di VPS, sebelum itu parameter `sheet` diabaikan),
    dashboard jadi "Last update: dd/mm/yyyy hh:mm oleh user" + judul & menu
    drawer "Dashboard Oil Lab" (web `aaed7e8`).
  - Info-level `flutter analyze` lama dirapikan (dangling doc comment
    `safety_models.dart`, guard `context.mounted` → `mounted` di Users).
  - `analyze` bersih, 41 test lolos (5 test baru), APK debug terbuild.
- **Sinkron izin menu/role mobile dengan backend (2026-11-04, sudah merge
  ke main)**: `user_models.dart` — `userRoles` 4 → 9
  (`admin, inputer, mekanik, viewer, planner, group leader, section head,
  adm te, adm lce`) + `permMenus` 14 → 29 persis urutan backend `MENUS`
  (users.py:15; tambah `riwayat, ppm, measurement, yazu, yazudc, ewacs,
  tarsupport, ss, ssab, proker, prokerbooster, prokerinjector,
  prokerthermo, manpower, manpowermanage` — catatan lama soal `ss` di
  entri SS 2026-10-31 kini beres). Baru: `permMatrixRoles` (8 role
  non-admin, mirror web Users.tsx:97) dan `menuLabel()` (label ramah baris
  matriks, web Users.tsx:110). `users_page.dart`: matriks izin memakai 8
  role itu + `menuLabel` (sebelumnya hanya inputer/mekanik/viewer).
  Hanya menyentuh halaman Users; dropdown Tambah/Ubah user otomatis
  ikut 9 role (default tetap inputer). `analyze` bersih, 42 test lolos
  (2 test lama diganti 3 test baru), APK debug terbuild.
- **Modul SS AB di mobile (2026-11-04, sudah merge ke main)**: paritas
  web `SsAb.tsx` (commit `db0c0a4`) — halaman baru
  `lib/src/features/ssab/*` (domain/api/providers/page) + route `/ssab`
  + menu drawer "SS AB" (gating `can('ssab','view')` seperti web).
  Isi: filter tahun (default tahun berjalan; opsi dari `years` API),
  6 kartu KPI (total, grade A/B + %, reward, manfaat, pencetus) ,
  kalender 12 bulan (jumlah A/B per bulan + reward, bulan berjalan
  disorot, bulan depan "–"), tabel Per Dept + bar proporsi, tabel
  Detail SS AB (client-side pagination 25/50/100/200, 500 baris
  terbaru) + tombol Export CSV `GET /v1/ss/ab/export`, dan tabel
  "Menunggu Penilaian oleh PM" (filter chips per manajemen, substring)
  + Export CSV `GET /v1/ss/ab/export-waiting`. Export CSV memakai
  `FilePicker.saveFile(bytes:)` (file_picker sudah ada — dialog SAF
  Android, tanpa dependensi baru); nama file mengikuti web
  (`ss_ab_{tahun}_{tgl}.csv`, `ss_waiting_pm_{tgl}.csv`). API gate
  `require_role("admin")` — praktis admin-only seperti web. `analyze`
  bersih, 50 test lolos (8 test baru `ssab_test.dart`), APK debug
  terbuild.
- **Modul Proker (2026-11-05, sudah merge ke main)**: paritas tampilan
  4 halaman web (Proker.tsx, ProkerBooster.tsx, ProkerInjector.tsx,
  Thermostat.tsx) — scope disepakati: **tampilan + Refresh HM saja**
  (tanpa form edit/tambah/hapus dan tanpa import XLSX di mobile).
  `lib/src/features/proker/*`: models/api/providers/widgets + 4 halaman
  (`proker_primer_page.dart` = GMC Pompa Primer, `proker_booster_page.dart`
  = Midlife Eng Booster, `proker_injector_page.dart` = Midlife Injector
  Primer, `proker_thermostat_page.dart` = Thermostat CAT) + route
  `/proker`, `/prokerbooster`, `/prokerinjector`, `/prokerthermo` + 4 menu
  drawer (urutan meniru web Layout.tsx:37-40, gating `can(key,'view')`
  seperti web). Tiap halaman: pengantar + KPI 2×2, filter (cari debounce
  400 ms / product / model [+ engine di primer] [+ chip "Hanya jatuh
  tempo" di booster/injector/thermostat]) + Reset, daftar unit kartu
  dengan paginasi server page_size 50 (‹ ›), detail bottom sheet 92%:
  primer = riwayat eksekusi + Δ HM kronologis + badge Midlife Eng;
  booster = OVH/Midlife terakhir + riwayat + Δ HM urut HM naik + badge
  remarks; injector = grid 12 posisi (PLAN/umur hijau-kuning-merah
  ambang 80%/100% interval) + riwayat per nomor penggantian "P{seq}";
  thermostat = detail dari baris terpilih (backend tanpa endpoint detail
  per unit, sama seperti web) — HM/deviasi/lifetime/modif 74°C (kosong =
  NOT YET) + radiator check (WR/ETA parts/ETA exec/suhu atas-bawah).
  Tombol **Refresh HM** di tiap halaman, gate `can(key,'add')` (backend
  `require_menu(...,"add")`, timeout 120 dtk), pesan snackbar persis web
  ("Refresh HM selesai: {updated} unit diperbarui · {unchanged} sudah
  terbaru · {not_found} tidak ditemukan di sumber data"); sukses ->
  invalidasi stats/filters/units/detail. Status/label paritas web: proker
  DONE=Selesai/PLAN=Rencana/LATE=Terlambat/MISSED=Terlewat; booster
  OVH/Midlife; injector DONE=Terpasang/PLAN=Rencana. `analyze` bersih,
  63 test lolos (13 test baru `proker_test.dart`), APK debug terbuild.
- **Sinkron fitur web terbaru (2026-11-06, sudah merge ke main)**:
  menyelaraskan seluruh perubahan web terbaru ke aplikasi mobile.
  - **Grup A — Timeline Mingguan + sumber "Last update"** (commit `b426d3f`):
    halaman `/timeline` (rentang maks 31 hari, default 7 hari, filter
    crew/kategori, ringkasan, grafik mini per hari, foto cover + expand,
    tombol Cetak/PDF diabaikan sesuai web); "Last update" dashboard kini
    dari `updated_at`/`updated_by` `/v1/results/latest-per-unit` dan DBR
    dari `/v1/dbr/records` (bukan lagi `/v1/imports/latest`).
  - **Grup B — Hourmeter, Yazu P2H, Yazu Daily Check, Ewacs, placeholder**
    (commit `09d2d81`): `hourmeter` (upload XLSX + rekap bulanan),
    `yazu`/`yazudc` (satu `YazuPageBase` dipakai bersama, beda prefix +
    gate menu), `ewacs` (grafik Apex web diganti visual CustomPaint),
    halaman placeholder web (PPM/Measurement/TAR Support) ditiru sebagai
    halaman placeholder khusus. 16 file, 7 test baru.
  - **Modul Riwayat (issue tracking)**: paritas web `Riwayat.tsx` — daftar
    issue (tab status/kategori/kartu) + detail (timeline progress, parts,
    foto evidence) + form buat/edit + upload/hapus evidence; route
    `/riwayat` + `/riwayat/:id`; 14 test (`riwayat_test.dart`).
  - **Modul Project Management**: paritas web `Project.tsx` — daftar
    (filter cari/status, kartu progress, paging 20) + detail bottom sheet
    (timeline tahapan, kartu tahap, update progress + foto eviden) + form
    project/tahap/update (multipart + progress upload) + hapus bertingkat;
    route `/project`; 9 test (`project_test.dart`).
  - **Modul Manpower Inovasi + Manpower (pengelompokan)**: paritas web
    `Manpower.tsx` + `ManpowerGroup.tsx` — KPI grid, tren batang (ganti
    ApexCharts), rincian per dept/section/crew, tabel data, isi otomatis
    dari jabatan, edit inline per NRP, aksi massal; route `/manpower` +
    `/manpowermanage`; 10 test (`manpower_test.dart`).
  - **Modul Staging Pump (versi sederhana)**: paritas web `Staging.tsx`
    tanpa drag-drop dnd-kit — navigasi periode, tampilan kartu (untaian
    pump Primer → Booster berwarna) + tabel, tambah grup (format cepat +
    validasi CN ke master equipment PUMPING), ubah/hapus grup, tambah/hapus
    pump, **pindah pump via dialog** (pilih grup tujuan + posisi), copy
    konfigurasi dari bulan lain, panel riwayat perubahan; route `/staging`
    + menu drawer, gate `staging.view/edit` (role inputer/admin untuk
    mutasi). 18 test (`staging_test.dart`) — menutup bug off-by-one
    `stagingShiftPeriod` yang ditemukan saat uji.
  - Dengan ini **seluruh menu web sudah ada di mobile** (gap menu kosong).
    `flutter analyze lib` bersih, **131 test lolos**, APK debug terbuild.
- **Rename modul Yazu → Yazu Lighting (2026-11-07, sudah merge ke main,
  branch `mobile/yazu-lighting-rename`, commit `ad2efe7`; merge `41d50a6`)**: rename menyeluruh
  sesuai permintaan — tabel DB, key menu matriks izin, label menu, judul
  halaman, dan path API; backend + web + mobile diubah bersamaan.
  - **DB** `infra/db/V63__yazu_lighting_rename.sql`: `yazu`→`yazu_lighting`,
    `yazu_sync_log`→`yazu_lighting_sync_log`, `yazu_dc`→`yazu_dc_lighting`,
    `yazu_dc_sync_log`→`yazu_dc_lighting_sync_log`; CHECK
    `role_permissions_menu_check` `'yazu','yazudc'`→`'*_lighting'` + migrasi
    baris izin existing + jaring pengaman admin. **Perlu diterapkan manual di
    VPS.**
  - **Backend**: prefix `/v1/yazu`→`/v1/yazu-lighting`, `/v1/yazu-dc`→
    `/v1/yazu-dc-lighting`; `require_menu`/SQL/tag/log `*_lighting`;
    `users.py` MENUS, `hm_sync.py` (baca `yazu_dc_lighting`), `main.py`
    label scheduler, docstring refresh HM proker/booster/injector/thermostat.
    Nama konfigurasi internal (`yazu_sheet_id`, dst.) dan nama modul Python
    dibiarkan (internal, tidak terlihat user).
  - **Web**: `client.ts` path baru; `Layout.tsx` key+label "Yazu Lighting
    P2H"/"Yazu Lighting Daily Check"; `App.tsx` key; `Yazu.tsx`/
    `YazuDailyCheck.tsx` `can()` + komentar; `Users.tsx` MENUS+label; tooltip
    Refresh HM di 4 halaman Proker.
  - **Mobile**: `yazu_page.dart` judul/menuKey/prefix + cek `_isDc`;
    `app_scaffold.dart` label+key menu (path route tetap `/yazu`,`/yazudc`);
    `user_models.dart` `permMenus` + `menuLabel`; test `m7_test.dart`
    disesuaikan. `flutter analyze lib` bersih, **131 test lolos**, `tsc` web
    bersih, modul Python compile OK, APK debug terbuild.
- **Modul Yazu Pumping P2H (2026-11-07, sudah merge ke main, branch
  `mobile/yazu-pumping-p2h`, commit `d58136d`; merge `a17fb24`)**:
  halaman baru grup **Operasional** menu **"Yazu Pumping P2H"** — checklist
  inspeksi unit pompa dari satu Google Sheets
  (`1QhRDCBnimoD4GserO9X-DB2cR4IvPafEG-gBxYsLsRI`) dengan **3 kategori tab:
  Primer / MHP / Booster** (gid `1513255410` / `138785798` / `754306640`).
  Tampilan paritas Yazu Lighting P2H: pivot HM bulanan + anomali + 1 tombol
  **Sync Manual** (menarik ketiga tab sekaligus) + filter bulan/tahun.
  - **DB** `infra/db/V64__yazu_pumping.sql`: satu tabel `yazu_pumping` +
    kolom `kategori` ('primer'|'mhp'|'booster'), UNIQUE (kategori,waktu,id_unit);
    `yazu_pumping_sync_log`; menu `yazupumping` (salin izin dari `yazu_lighting`).
  - **Backend** `app/api/v1/yazu_pumping.py` prefix `/v1/yazu-pumping`
    (`sync`/`stats`/`units`/`pivot?kategori=`/`raw`). Parsing **berdasarkan nama
    header** (bukan index) karena kolom antar tab beda tipis: primer (Level Oli
    Vacuum), mhp (Level Oli Transmisi, Fungsi AC), booster (Fungsi Panel Motor
    355KW). `main.py` scheduler 06:00/18:00 ikut menarik pumping; `users.py`
    MENUS + `config.py` (sheet id + 3 gid).
  - **Web** `pages/YazuPumping.tsx` (tab kategori + pivot + anomali, reuse
    helper Yazu.tsx) + `client.ts` (5 fungsi) + `Layout.tsx`/`App.tsx`/
    `Users.tsx` (menu key `yazupumping`, label "Yazu Pumping P2H", ikon pompa).
  - **Mobile** `features/yazu/presentation/yazu_pumping_page.dart` (tab +
    pivot + anomali; reuse `yazu_models.dart` & `yazuComputeDeltas`); `YazuApi`
    dapat param `kategori` + `yazuPumpingApiProvider`; provider
    `yazuPumpingKategori`/`Month`/`Pivot`/`Stats`; route `/yazupumping`;
    `app_scaffold.dart` + `user_models.dart` (`permMenus` jadi 30 + `menuLabel`).
  - Verifikasi: `flutter analyze lib` bersih, **131 test lolos**, `tsc` +
    `vite build` web lolos, modul Python compile OK + parser diuji langsung ke
    3 CSV (semua header ter mapping), APK debug terbuild.
