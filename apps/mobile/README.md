# mte_data_center — Aplikasi Mobile MTE Data Center

Aplikasi Android (Flutter) untuk **MTE Data Center** — paritas fitur dengan web
dashboard (`apps/web`). Backend & kontrak endpoint sama dengan web (FastAPI,
`/api`), sehingga label, perilaku, dan warna dipertahankan semirip mungkin.

- Package: `id.mibt` / `mte_data_center`
- Arsitektur: **Riverpod** (state) + **GoRouter** (routing), Clean Architecture
  per fitur: `lib/src/features/<fitur>/{domain,data,presentation}`.
- Backend default: `https://mte2.mibt.my.id/api` (lihat `app_config.dart`).

## Menjalankan

```bash
cd apps/mobile
flutter pub get

# Emulator Android → host API lokal (8802):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8802

# Perangkat fisik → ganti dengan IP LAN mesin dev:
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8802
```

Produksi wajib memakai prefix `/api` (nginx strip prefix, pola web). Tanpa
`--dart-define`, aplikasi memakai default produksi.

## Menu / Fitur

Menu drawer meniru grup web (`Layout.tsx`). Seluruh menu web sudah tersedia:

| Grup | Menu mobile |
|---|---|
| Monitoring | Dashboard Oil Lab, DBR Breakdown, Performance, Timeline Mingguan |
| Operasional | Activity, Yazu P2H, Yazu Daily Check, Bomak R1BI, Equipment, Staging Pump, Meeting (MoM), Riwayat, Project, Update Data |
| Follow Up | FUI, Suggestion FUI, Report Follow Up |
| Technical Expert | Hourmeter, PPM*, Measurement*, Ewacs Performance, TAR Support*, Proker (GMC/Booster/Injector/Thermostat) |
| Agent | Suggestion System, SS AB, Manpower, Manpower Inovasi |
| Administrasi | Users*, Audit Log* |

\* placeholder / khusus admin, mengikuti web.

**Catatan penting:**
- **Staging Pump** versi mobile disederhanakan: tampilan kartu/tabel + pindah
  pump lewat dialog (bukan drag-and-drop seperti web).
- Grafik web (ApexCharts) diganti visual Flutter (`fl_chart` / `CustomPaint`).
- Export PDF (FUI) disembunyikan seperti web; Export CSV memakai dialog
  "simpan file" Android.

## Verifikasi sebelum commit

```bash
flutter analyze lib
flutter test
flutter build apk --debug
```

Baseline saat ini: `analyze` bersih, seluruh test lolos, APK debug terbuild.

## Struktur

```
lib/src/
  core/        auth, network (dio + refresh), router, tema, widget bersama
  features/    satu folder per menu: domain (model), data (api), presentation (UI)
```

Kontrak kerja & aturan sinkronisasi dengan web ada di `../../handoff.md`.
