"""Manpower Inovasi — snapshot bulanan RptInnovatorMonthly.

Sumber Excel: `RptInnovatorMonthly <Bln> <Thn>.xlsx`, sheet `Report`, 28 kolom:
NRP .. INNOVATOR ALL. Satu baris = satu orang pada bulan tersebut.

Karena komposisi manpower bisa berubah tiap bulan (masuk/keluar/pindah dept),
tiap file disimpan sebagai snapshot bulan sendiri di `manpower_month` dengan
kunci (periode, nrp). Import ulang bulan yang sama akan memperbarui baris dan
menghapus baris yang sudah tidak ada di file terbaru, sehingga snapshot selalu
sama persis dengan file terakhir.

Periode dibaca dari nama file ("Agt 26" -> 2026-08-01). Bila nama file tidak
memuat bulan, periode bisa dikirim manual lewat form `periode` (YYYY-MM).

Data ini dipakai untuk coverage pembuatan SS per bulan:
  * coverage innovator = COUNT(innovator_ss > 0) / COUNT(*) * 100
  * SS per manpower    = SUM(ss_closed) / COUNT(*)

Kebijakan data: hanya baris DEPT = SPL2 yang disimpan (lihat `DEPT_ALLOW`).
"""
import datetime as dt
import io
import json
import logging
import re

import openpyxl
from fastapi import (
    APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, UploadFile,
)
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_menu
from app.db.session import get_db, SessionLocal

router = APIRouter(prefix="/v1/manpower", tags=["manpower"])
log = logging.getLogger("manpower")

# Kebijakan data: hanya DEPT SPL2 yang disimpan. Baris DEPT lain dilewati dan
# dilaporkan sebagai `skipped_dept` pada ringkasan import.
DEPT_ALLOW: set[str] = {"SPL2"}

# --- Pengelompokan manpower (halaman "Manpower") ---------------------------
# Section/Crew/Status disimpan per NRP di `manpower_profile`, terpisah dari
# snapshot bulanan, sehingga tidak hilang saat import ulang.
SECTIONS = [
    "Big Wheel - PCH", "SPEX Mobile - Lighting",
    "SPEX Pumping - Fabrication", "LCE", "MTE", "Tyre", "Dept Head",
]
CREWS = [
    "Big Wheel", "PCH", "Mobile", "Lighting", "Pumping", "Tyre",
    "MTE", "LCE",
]
# Section Tyre tidak memakai status Mekanik: hanya Staff atau Repairman.
STATUSES = ["Staff", "Mekanik", "Repairman"]
EMPTY = "__EMPTY__"   # nilai filter untuk "belum diisi"

# Tebakan awal (section, crew, status) dari JABATAN. Nilai yang tidak ada di
# tabel ini ditebak lewat kata kunci pada `classify()`; semuanya bisa dikoreksi
# manual di halaman Manpower.
_JABATAN_MAP: dict[str, tuple[str | None, str | None, str | None]] = {
    "SITE SUPPORT EQUIP. MECHANIC": ("SPEX Mobile - Lighting", "Mobile", "Mekanik"),
    "COAL HAULER EQUIP. MECHANIC": ("Big Wheel - PCH", "PCH", "Mekanik"),
    "WHEEL TYPE MECHANIC": ("Big Wheel - PCH", "Big Wheel", "Mekanik"),
    "PUMPING & ELECTRICAL GL": ("SPEX Pumping - Fabrication", "Pumping", "Staff"),
    "TYRE UTILIZATION GL": ("Tyre", "Tyre", "Staff"),
    "TYRE REPAIRMAN": ("Tyre", "Tyre", "Repairman"),
    "LIFE CYCLE EXPERT": ("LCE", "LCE", "Staff"),
    "COAL HAULER EQUIP. GL": ("Big Wheel - PCH", "PCH", "Staff"),
    "LIGHT TRUCK & LIFTING GL": ("SPEX Mobile - Lighting", "Lighting", "Staff"),
    "WHEEL TYPE GL": ("Big Wheel - PCH", "Big Wheel", "Staff"),
    "GENERAL CREW - PLANT 2": ("SPEX Pumping - Fabrication", "Pumping", "Staff"),
    "SSE MAINTENANCE TECHNICAL EXPERT": ("MTE", "MTE", "Staff"),
    "FABRICATION GL": ("SPEX Pumping - Fabrication", "Pumping", "Staff"),
    "TYRE REPAIR & MAINT. GL": ("Tyre", "Tyre", "Staff"),
    "SSE TYPE MAINT. PROCESS EXPERT TL": ("MTE", "MTE", "Staff"),
    "TYRE MAINT. EXPERT TL": ("Tyre", "Tyre", "Staff"),
    "TYRE LIFE CYCLE & TECH. EXPERT": ("Tyre", "Tyre", "Staff"),
    "DRIVER TADANO": ("SPEX Mobile - Lighting", "Mobile", "Mekanik"),
    "LIFE CYCLE EXPERT TL": ("LCE", "LCE", "Staff"),
    "PLANT 2 EXPERT COORDINATOR": ("SPEX Pumping - Fabrication", "Pumping", "Staff"),
    "WHEEL MAINTENANCE TECHNICAL EXPERT": ("MTE", "MTE", "Staff"),
    "WHEEL TYPE MAINT. PROCESS EXPERT TL": ("MTE", "MTE", "Staff"),
    "TYRE UTILIZATION GL TRAINEE": ("Tyre", "Tyre", "Staff"),
    "PUMPING & ELECTRICAL GL TRAINEE": ("SPEX Pumping - Fabrication", "Pumping", "Staff"),
    "LIFE CYCLE EXPERT TRAINEE": ("LCE", "LCE", "Staff"),
}


def classify(jabatan: str | None) -> tuple[str | None, str | None, str | None]:
    """Tebak (section, crew, status) dari JABATAN. Semua None bila tidak yakin."""
    raw = (jabatan or "").strip()
    if not raw:
        return None, None, None
    j = " ".join(raw.upper().split())
    if j in _JABATAN_MAP:
        return _JABATAN_MAP[j]

    status = "Mekanik" if any(
        k in j for k in ("MECHANIC", "REPAIRMAN", "DRIVER", "TECHNICIAN")) else "Staff"
    section: str | None = None
    crew: str | None = None
    if "DEPARTMENT HEAD" in j or "DEPT HEAD" in j:
        section = "Dept Head"
    elif "TYRE" in j:
        # Semua yang berbau TYRE masuk Section + Crew Tyre. Section Tyre tidak
        # punya Mekanik: jabatan tyre repairman -> Repairman, selain itu
        # (GL / expert / trainee) -> Staff.
        section, crew = "Tyre", "Tyre"
        status = "Repairman" if "REPAIRMAN" in j else "Staff"
    elif "LIFE CYCLE" in j:
        section, crew = "LCE", "LCE"
    elif "FABRICATION" in j:
        section, crew = "SPEX Pumping - Fabrication", "Pumping"
    elif "PUMPING" in j or "ELECTRICAL" in j or "PLANT 2" in j:
        section, crew = "SPEX Pumping - Fabrication", "Pumping"
    elif "COAL HAULER" in j:
        section, crew = "Big Wheel - PCH", "PCH"
    elif "WHEEL" in j:
        section, crew = "Big Wheel - PCH", "Big Wheel"
    elif "LIGHT TRUCK" in j or "LIFTING" in j:
        section, crew = "SPEX Mobile - Lighting", "Lighting"
    elif "SITE SUPPORT" in j or "TADANO" in j:
        section, crew = "SPEX Mobile - Lighting", "Mobile"
    elif "SSE" in j or "EXPERT" in j:
        section, crew = "MTE", "MTE"
    return section, crew, status


def _pick(value, allowed: list[str], field: str) -> str | None:
    """Validasi nilai pilihan; string kosong = None (dikosongkan)."""
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    for a in allowed:
        if a.lower() == s.lower():
            return a
    raise HTTPException(400, f"{field} tidak dikenal: {value}")

SHEET = "Report"
HEADERS = [
    "NRP", "NAME", "JABATAN", "DEPT", "DIV", "DISTRIK",
    "JUMLAH DT CLOSED", "FASILITATOR DT", "LEADER DT", "MEMBER DT",
    "JUMLAH QCP CLOSED", "FASILITATOR QCP CLOSED", "LEADER QCP CLOSED",
    "MEMBER QCP CLOSED", "JUMLAH QCC CLOSED", "FASILITATOR QCC CLOSED",
    "LEADER QCC CLOSED", "MEMBER QCC CLOSED",
    "SS KELAS A", "SS KELAS B", "SS KELAS C", "SS KELAS D", "SS KELAS E",
    "SS KELAS F", "JUMLAH SS CLOSED", "INNOVATOR SS", "INNOVATOR QCC",
    "INNOVATOR ALL",
]

# Kolom sumber -> kolom tabel (selain identitas).
NUM_FIELDS = [
    ("JUMLAH DT CLOSED", "dt_closed"),
    ("FASILITATOR DT", "dt_fasilitator"),
    ("LEADER DT", "dt_leader"),
    ("MEMBER DT", "dt_member"),
    ("JUMLAH QCP CLOSED", "qcp_closed"),
    ("FASILITATOR QCP CLOSED", "qcp_fasilitator"),
    ("LEADER QCP CLOSED", "qcp_leader"),
    ("MEMBER QCP CLOSED", "qcp_member"),
    ("JUMLAH QCC CLOSED", "qcc_closed"),
    ("FASILITATOR QCC CLOSED", "qcc_fasilitator"),
    ("LEADER QCC CLOSED", "qcc_leader"),
    ("MEMBER QCC CLOSED", "qcc_member"),
    ("SS KELAS A", "ss_a"),
    ("SS KELAS B", "ss_b"),
    ("SS KELAS C", "ss_c"),
    ("SS KELAS D", "ss_d"),
    ("SS KELAS E", "ss_e"),
    ("SS KELAS F", "ss_f"),
    ("JUMLAH SS CLOSED", "ss_closed"),
    ("INNOVATOR SS", "innovator_ss"),
    ("INNOVATOR QCC", "innovator_qcc"),
    ("INNOVATOR ALL", "innovator_all"),
]
NUM_COLS = ["dt_closed", "dt_fasilitator", "dt_leader", "dt_member",
            "qcp_closed", "qcp_fasilitator", "qcp_leader", "qcp_member",
            "qcc_closed", "qcc_fasilitator", "qcc_leader", "qcc_member",
            "ss_a", "ss_b", "ss_c", "ss_d", "ss_e", "ss_f", "ss_closed",
            "innovator_ss", "innovator_qcc", "innovator_all"]
TEXT_COLS = ["nama", "jabatan", "dept", "divisi", "distrik"]
COLS = ["periode", "nrp", *TEXT_COLS, *NUM_COLS]

BATCH = 2000

# Nama bulan di file: Jan, Feb, Mar, Apr, Mei, Jun, Jul, Agt, Sept, Okt, ...
MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "mei": 5, "may": 5, "jun": 6,
    "jul": 7, "agt": 8, "agu": 8, "aug": 8, "sep": 9, "sept": 9, "okt": 10,
    "oct": 10, "nov": 11, "des": 12, "dec": 12,
}
_MONTH_RE = re.compile(
    r"(?i)\b(jan|feb|mar|apr|mei|may|jun|jul|agt|agu|aug|sep|sept|okt|oct|nov|des|dec)\b"
    r"[\s._-]*(\d{2,4})"
)
_ISO_RE = re.compile(r"(\d{4})[-_/.](\d{1,2})")


# --------------------------------------------------------------------------- util
def _txt(v) -> str | None:
    if v is None:
        return None
    s = str(v).replace("\xa0", " ").strip()
    return s or None


def _int(v) -> int:
    if v is None:
        return 0
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, (int, float)):
        return int(round(v))
    s = str(v).replace("\xa0", "").replace(",", ".").strip()
    if not s:
        return 0
    try:
        return int(round(float(s)))
    except ValueError:
        return 0


def _month_start(year: int, month: int) -> dt.date:
    return dt.date(year, month, 1)


def period_from_filename(name: str) -> dt.date | None:
    """Ambil periode dari nama file, mis. 'RptInnovatorMonthly Agt 26.xlsx'."""
    base = name.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    found = list(_MONTH_RE.finditer(base))
    if found:
        m = found[-1]
        month = MONTHS.get(m.group(1).lower())
        year = int(m.group(2))
        if len(m.group(2)) == 2:
            year += 2000
        if month and 2000 <= year <= 2100:
            return _month_start(year, month)
    iso = list(_ISO_RE.finditer(base))
    if iso:
        m = iso[-1]
        month = int(m.group(2))
        if 1 <= month <= 12:
            return _month_start(int(m.group(1)), month)
    return None


def parse_period(value: str | None) -> dt.date | None:
    """'2026-08' / '2026-08-01' -> date(2026, 8, 1)."""
    if not value:
        return None
    s = str(value).strip()
    m = re.match(r"^(\d{4})[-/](\d{1,2})(?:[-/]\d{1,2})?$", s)
    if not m:
        raise ValueError(f"periode tidak valid: {value} (format YYYY-MM)")
    month = int(m.group(2))
    if not 1 <= month <= 12:
        raise ValueError(f"bulan tidak valid: {value}")
    return _month_start(int(m.group(1)), month)


def _parse(content: bytes, fname: str, override: dt.date | None
           ) -> tuple[dt.date, list[dict], list[dict], int, int]:
    """Baca satu workbook -> (periode, rows, errors, duplicates, skipped).

    Hanya baris dengan DEPT di `DEPT_ALLOW` yang dikembalikan; sisanya dihitung
    sebagai `skipped` dan tidak masuk database.
    """
    periode = override or period_from_filename(fname)
    if not periode:
        raise ValueError(
            "periode tidak terdeteksi dari nama file; pilih bulan manual "
            "(format YYYY-MM)"
        )
    wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    try:
        sheet = SHEET if SHEET in wb.sheetnames else wb.sheetnames[0]
        ws = wb[sheet]
        it = ws.iter_rows(values_only=True)
        header = [str(h).strip().upper() if h is not None else "" for h in next(it)]
        idx: dict[str, int] = {}
        for i, h in enumerate(header):
            if h and h not in idx:
                idx[h] = i
        missing = [h for h in HEADERS if h not in idx]
        if missing:
            raise ValueError(f"kolom wajib hilang: {', '.join(missing)}")

        rows: dict[str, dict] = {}
        errors: list[dict] = []
        duplicates = 0
        skipped = 0
        for rno, r in enumerate(it, start=2):
            if r is None:
                continue
            if all(v is None or (isinstance(v, str) and not v.strip()) for v in r):
                continue

            def g(name: str):
                i = idx[name]
                return r[i] if i < len(r) else None

            dept = (_txt(g("DEPT")) or "").strip().upper()
            if DEPT_ALLOW and dept not in DEPT_ALLOW:
                skipped += 1
                continue

            nrp = (_txt(g("NRP")) or "").upper()
            if not nrp:
                errors.append({"file": fname, "row": rno, "error": "NRP kosong"})
                continue
            row = {
                "periode": periode,
                "nrp": nrp,
                "nama": _txt(g("NAME")),
                "jabatan": _txt(g("JABATAN")),
                "dept": dept or None,
                "divisi": (_txt(g("DIV")) or "").upper() or None,
                "distrik": (_txt(g("DISTRIK")) or "").upper() or None,
            }
            for src, col in NUM_FIELDS:
                row[col] = _int(g(src))
            if nrp in rows:
                duplicates += 1
            rows[nrp] = row
        return periode, list(rows.values()), errors, duplicates, skipped
    finally:
        wb.close()


_UPSERT = text(f"""
INSERT INTO manpower_month ({', '.join(COLS)}, import_id)
VALUES ({', '.join(':' + c for c in COLS)}, :import_id)
ON CONFLICT (periode, nrp) DO UPDATE SET
  {', '.join(f'{c} = EXCLUDED.{c}' for c in COLS if c not in ('periode', 'nrp'))},
  import_id = EXCLUDED.import_id,
  updated_at = now()
""")


async def _existing(db: AsyncSession, periods: list[dt.date]) -> set[tuple[dt.date, str]]:
    if not periods:
        return set()
    rows = (await db.execute(text(
        "SELECT periode, nrp FROM manpower_month WHERE periode = ANY(:ps)"),
        {"ps": periods})).mappings().all()
    return {(r["periode"], r["nrp"]) for r in rows}


async def _ensure_profiles(db: AsyncSession, rows: list[dict], by: str | None) -> int:
    """Buat profil (beserta tebakan dari JABATAN) untuk NRP yang belum punya.

    Profil yang sudah ada tidak diubah, sehingga koreksi manual aman.
    """
    if not rows:
        return 0
    nrps = sorted({r["nrp"] for r in rows if r.get("nrp")})
    if not nrps:
        return 0
    have = set((await db.execute(
        text("SELECT nrp FROM manpower_profile WHERE nrp = ANY(:n)"), {"n": nrps})).scalars())
    payload = []
    for r in rows:
        nrp = r.get("nrp")
        if not nrp or nrp in have:
            continue
        section, crew, status = classify(r.get("jabatan"))
        payload.append({"nrp": nrp, "section": section, "crew": crew, "status": status,
                        "auto": bool(section or crew or status), "by": by})
        have.add(nrp)
    if payload:
        await db.execute(text(
            "INSERT INTO manpower_profile (nrp, section, crew, status, auto, updated_by) "
            "VALUES (:nrp, :section, :crew, :status, :auto, :by) "
            "ON CONFLICT (nrp) DO NOTHING"), payload)
    return len(payload)


async def _run(import_id: str, files: list[tuple[str, bytes]], override: dt.date | None,
               username: str | None = None):
    async with SessionLocal() as db:
        try:
            merged: dict[tuple[dt.date, str], dict] = {}
            periods: set[dt.date] = set()
            errors: list[dict] = []
            duplicates = 0
            skipped_dept = 0
            total = 0

            for fname, content in files:
                try:
                    periode, rows, errs, dup, skipped = _parse(content, fname, override)
                except Exception as e:  # noqa: BLE001
                    errors.append({"file": fname, "error": str(e)})
                    continue
                periods.add(periode)
                duplicates += dup
                skipped_dept += skipped
                errors.extend(errs[:50])
                total += len(rows) + len(errs) + skipped
                for row in rows:
                    merged[(periode, row["nrp"])] = row
                await db.execute(text(
                    "UPDATE imports SET total_rows=:t, processed_rows=0 WHERE id=:i"),
                    {"t": total, "i": import_id})
                await db.commit()

            if not merged:
                detail = "; ".join(str(e.get("error") or e.get("file")) for e in errors[:5])
                raise ValueError(
                    "tidak ada baris yang bisa diimpor" + (f": {detail}" if detail else ""))

            old_keys = await _existing(db, sorted(periods))
            new_keys = set(merged)
            inserted = len(new_keys - old_keys)
            updated = len(new_keys & old_keys)
            deleted = len(old_keys - new_keys)

            values = list(merged.values())
            done = 0
            for i in range(0, len(values), BATCH):
                batch = values[i:i + BATCH]
                await db.execute(_UPSERT, [{**b, "import_id": import_id} for b in batch])
                done += len(batch)
                await db.execute(text(
                    "UPDATE imports SET processed_rows=:p, ok_rows=:o WHERE id=:i"),
                    {"p": done, "o": done, "i": import_id})
                await db.commit()

            # Snapshot harus sama persis dengan file terbaru: buang baris lama
            # pada periode yang di-upload tapi tidak ada lagi di file ini.
            await db.execute(text(
                "DELETE FROM manpower_month "
                "WHERE periode = ANY(:ps) AND import_id IS DISTINCT FROM :i"),
                {"ps": sorted(periods), "i": import_id})
            await db.commit()

            # NRP baru langsung diberi kelompok awal hasil tebakan jabatan.
            profiles_created = await _ensure_profiles(
                db, values, by=f"import: {username}" if username else "import")
            await db.commit()

            summary = {
                "inserted": inserted,
                "updated": updated,
                "deleted": deleted,
                "duplicates": duplicates,
                "skipped_dept": skipped_dept,
                "profiles_created": profiles_created,
                "dept_filter": sorted(DEPT_ALLOW),
                "periods": [p.strftime("%Y-%m") for p in sorted(periods)],
                "files": [f for f, _ in files],
                "total_rows": total,
                "errors": errors[:50],
            }
            await db.execute(text(
                "UPDATE imports SET status='COMMITTED', total_rows=:t, ok_rows=:o, "
                "fail_rows=:f, processed_rows=:p, errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"t": total, "o": len(values), "f": len(errors), "p": total,
                 "e": json.dumps(summary, default=str), "i": import_id})
            await db.commit()
            log.info("manpower import %s: %s periode, %s inserted, %s updated, %s deleted, "
                     "%s dilewati (DEPT %s)",
                     import_id, len(periods), inserted, updated, deleted, skipped_dept,
                     sorted(DEPT_ALLOW))
        except Exception as e:  # noqa: BLE001
            await db.rollback()
            await db.execute(text(
                "UPDATE imports SET status='FAILED', errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"e": json.dumps({"error": str(e)}, default=str), "i": import_id})
            await db.commit()
            log.exception("manpower import gagal: %s", e)


# --------------------------------------------------------------------------- import
@router.post("/import", dependencies=[Depends(require_menu("manpower", "add"))],
             status_code=202)
async def import_xlsx(
    bg: BackgroundTasks,
    files: list[UploadFile] = File(...),
    periode: str | None = Form(None),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Upload 1..n file RptInnovatorMonthly (.xlsx). Periode dibaca dari nama file."""
    if not files:
        raise HTTPException(400, "Tidak ada file")
    try:
        override = parse_period(periode)
    except ValueError as e:
        raise HTTPException(400, str(e))
    payload: list[tuple[str, bytes]] = []
    limit = settings.max_upload_mb * 1024 * 1024
    for f in files:
        content = await f.read()
        if len(content) > limit:
            raise HTTPException(413, f"{f.filename}: file terlalu besar")
        if not content:
            raise HTTPException(400, f"{f.filename}: file kosong")
        payload.append((f.filename or "upload.xlsx", content))
    if not override and not any(period_from_filename(n) for n, _ in payload):
        raise HTTPException(
            400, "Periode tidak terdeteksi dari nama file. Pilih bulan manual.")
    label = ", ".join(name for name, _ in payload)
    res = await db.execute(text(
        "INSERT INTO imports(filename,sheet,status,total_rows,uploaded_by) "
        "VALUES (:fn,'MANPOWER','PROCESSING',0,:u) RETURNING id"),
        {"fn": label[:300], "u": user["username"]})
    import_id = str(res.scalar_one())
    await db.commit()
    bg.add_task(_run, import_id, payload, override, user["username"])
    return {"import_id": import_id, "status": "PROCESSING", "files": len(payload)}


@router.get("/import/{import_id}", dependencies=[Depends(require_menu("manpower", "view"))])
async def import_status(import_id: str, db: AsyncSession = Depends(get_db)):
    row = (await db.execute(text(
        "SELECT id, filename, status, total_rows, ok_rows, fail_rows, processed_rows, "
        "uploaded_by, created_at, errors FROM imports WHERE id=:i AND sheet='MANPOWER'"),
        {"i": import_id})).mappings().first()
    if not row:
        raise HTTPException(404, "import_id tidak ditemukan")
    return dict(row)


# --------------------------------------------------------------------------- agregat
_ROW_SELECT = (
    "nrp, nama, jabatan, dept, divisi, distrik, dt_closed, qcp_closed, qcc_closed, "
    "ss_a, ss_b, ss_c, ss_d, ss_e, ss_f, ss_closed, innovator_ss, innovator_qcc, "
    "innovator_all"
)


def _where(periode: dt.date, dept: str | None, divisi: str | None,
           search: str | None = None) -> tuple[str, dict]:
    conds = ["periode = :periode"]
    p: dict = {"periode": periode}
    if dept:
        conds.append("dept = :dept")
        p["dept"] = dept
    if divisi:
        conds.append("divisi = :divisi")
        p["divisi"] = divisi
    if search:
        conds.append("(nama ILIKE :q OR nrp ILIKE :q OR jabatan ILIKE :q)")
        p["q"] = f"%{search}%"
    return " AND ".join(conds), p


@router.get("/periods", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_periods(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text("""
        SELECT to_char(periode, 'YYYY-MM') AS periode,
               COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE innovator_ss > 0) AS innovator_ss,
               SUM(ss_closed) AS ss_closed,
               MAX(updated_at) AS updated_at
        FROM manpower_month
        GROUP BY periode ORDER BY periode DESC
    """))).mappings().all()
    out = []
    for r in rows:
        mp = r["manpower"] or 0
        out.append({
            "periode": r["periode"],
            "manpower": mp,
            "innovator_ss": r["innovator_ss"] or 0,
            "ss_closed": int(r["ss_closed"] or 0),
            "coverage_pct": round((r["innovator_ss"] or 0) / mp * 100, 1) if mp else 0,
            "updated_at": str(r["updated_at"]) if r["updated_at"] else None,
        })
    return out


@router.get("/trend", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_trend(
    dept: str | None = Query(None),
    divisi: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    conds, p = [], {}
    if dept:
        conds.append("dept = :dept")
        p["dept"] = dept
    if divisi:
        conds.append("divisi = :divisi")
        p["divisi"] = divisi
    where = ("WHERE " + " AND ".join(conds)) if conds else ""
    rows = (await db.execute(text(f"""
        SELECT to_char(periode, 'YYYY-MM') AS periode,
               COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE innovator_ss > 0) AS innovator_ss,
               SUM(ss_closed) AS ss_closed
        FROM manpower_month {where}
        GROUP BY periode ORDER BY periode
    """), p)).mappings().all()
    out = []
    for r in rows:
        mp = r["manpower"] or 0
        out.append({
            "periode": r["periode"],
            "manpower": mp,
            "innovator_ss": r["innovator_ss"] or 0,
            "ss_closed": int(r["ss_closed"] or 0),
            "coverage_pct": round((r["innovator_ss"] or 0) / mp * 100, 1) if mp else 0,
        })
    return out


@router.get("/summary", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_summary(
    periode: str = Query(...),
    dept: str | None = Query(None),
    divisi: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    try:
        per = parse_period(periode)
    except ValueError as e:
        raise HTTPException(400, str(e))
    where, p = _where(per, dept, divisi)
    row = (await db.execute(text(f"""
        SELECT COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE innovator_ss > 0) AS innovator_ss,
               COUNT(*) FILTER (WHERE innovator_qcc > 0) AS innovator_qcc,
               COUNT(*) FILTER (WHERE innovator_all > 0) AS innovator_all,
               COALESCE(SUM(ss_closed), 0) AS ss_closed,
               COALESCE(SUM(dt_closed), 0) AS dt_closed,
               COALESCE(SUM(qcp_closed), 0) AS qcp_closed,
               COALESCE(SUM(qcc_closed), 0) AS qcc_closed,
               MAX(updated_at) AS updated_at
        FROM manpower_month WHERE {where}
    """), p)).mappings().first()
    mp = row["manpower"] or 0
    innov = row["innovator_ss"] or 0
    ssd = int(row["ss_closed"] or 0)

    # Rincian per dept selalu untuk seluruh periode (mengikuti filter divisi saja)
    # supaya tabel tetap informatif walau filter dept dipilih.
    dw, dp = _where(per, None, divisi)
    breaks = (await db.execute(text(f"""
        SELECT COALESCE(NULLIF(TRIM(dept), ''), '(kosong)') AS dept,
               COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE innovator_ss > 0) AS innovator_ss,
               COALESCE(SUM(ss_closed), 0) AS ss_closed
        FROM manpower_month WHERE {dw}
        GROUP BY 1 ORDER BY manpower DESC, 1
    """), dp)).mappings().all()
    dept_rows = []
    for b in breaks:
        m = b["manpower"] or 0
        dept_rows.append({
            "dept": b["dept"],
            "manpower": m,
            "innovator_ss": b["innovator_ss"] or 0,
            "coverage_pct": round((b["innovator_ss"] or 0) / m * 100, 1) if m else 0,
            "ss_closed": int(b["ss_closed"] or 0),
            "ss_per_manpower": round(int(b["ss_closed"] or 0) / m, 2) if m else 0,
        })

    return {
        "periode": per.strftime("%Y-%m"),
        "manpower": mp,
        "innovator_ss": innov,
        "innovator_qcc": row["innovator_qcc"] or 0,
        "innovator_all": row["innovator_all"] or 0,
        "coverage_pct": round(innov / mp * 100, 1) if mp else 0,
        "ss_closed": ssd,
        "ss_per_manpower": round(ssd / mp, 2) if mp else 0,
        "dt_closed": int(row["dt_closed"] or 0),
        "qcp_closed": int(row["qcp_closed"] or 0),
        "qcc_closed": int(row["qcc_closed"] or 0),
        "updated_at": str(row["updated_at"]) if row["updated_at"] else None,
        "dept": dept_rows,
    }


_SORTS = ("nama", "nrp", "dept", "jabatan", "ss_closed", "innovator_ss",
          "dt_closed", "qcp_closed", "qcc_closed")


@router.get("/records", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_records(
    periode: str = Query(...),
    dept: str | None = Query(None),
    divisi: str | None = Query(None),
    search: str | None = Query(None),
    innovator: bool | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=200),
    sort: str = Query("nama"),
    dir: str = Query("asc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    try:
        per = parse_period(periode)
    except ValueError as e:
        raise HTTPException(400, str(e))
    where, p = _where(per, dept, divisi, search)
    if innovator is not None:
        where += " AND (innovator_ss > 0)" if innovator else " AND (innovator_ss = 0)"
    if sort not in _SORTS:
        sort = "nama"
    p["lim"] = page_size
    p["off"] = (page - 1) * page_size
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM manpower_month WHERE {where}"), p)).scalar() or 0
    rows = (await db.execute(text(
        f"SELECT {_ROW_SELECT} FROM manpower_month WHERE {where} "
        f"ORDER BY {sort} {dir.upper()} NULLS LAST, nrp LIMIT :lim OFFSET :off"),
        p)).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}

# --------------------------------------------------------------------------- kelola
# Halaman "Manpower" (grup Agent): dashboard + pengelompokan Section/Crew/Status.
# Pengelompokan disimpan per NRP di `manpower_profile`; data orang (nama,
# jabatan, dept, dll) tetap diambil dari snapshot bulan yang dipilih.
_MANAGE_SORTS = ("nrp", "nama", "jabatan", "dept", "section", "crew", "status",
                 "ss_closed", "innovator_all")

_MANAGE_SELECT = """
  m.nrp, m.nama, m.jabatan, m.dept, m.divisi, m.distrik,
  p.section, p.crew, p.status, COALESCE(p.auto, FALSE) AS auto_filled,
  m.ss_closed, m.innovator_ss, m.innovator_all
"""


def _manage_where(periode: dt.date, dept: str | None = None, section: str | None = None,
                  crew: str | None = None, status: str | None = None,
                  search: str | None = None) -> tuple[str, dict]:
    conds = ["m.periode = :periode"]
    p: dict = {"periode": periode}
    if dept:
        conds.append("m.dept = :dept")
        p["dept"] = dept
    if search:
        conds.append("(m.nama ILIKE :q OR m.nrp ILIKE :q OR m.jabatan ILIKE :q "
                     "OR p.section ILIKE :q)")
        p["q"] = f"%{search}%"
    for col, val, key in (("p.section", section, "section"),
                          ("p.crew", crew, "crew"),
                          ("p.status", status, "status")):
        if not val:
            continue
        if val == EMPTY:
            conds.append(f"{col} IS NULL")
        else:
            conds.append(f"{col} = :{key}")
            p[key] = val
    return " AND ".join(conds), p


def _breakdown_dim(dim: str) -> str:
    return (
        " SELECT COALESCE(p." + dim + ", '(belum diisi)') AS label, COUNT(*) AS total,"
        "        COUNT(*) FILTER (WHERE p.status = 'Staff') AS staff,"
        "        COUNT(*) FILTER (WHERE p.status = 'Mekanik') AS mekanik,"
        "        COUNT(*) FILTER (WHERE p.status = 'Repairman') AS repairman"
        " FROM manpower_month m LEFT JOIN manpower_profile p ON p.nrp = m.nrp"
        " WHERE {where} GROUP BY 1 ORDER BY total DESC, 1"
    )


@router.get("/manage", dependencies=[Depends(require_menu("manpower", "view"))])
async def manage_dashboard(
    periode: str | None = Query(None),
    dept: str | None = Query(None),
    section: str | None = Query(None),
    crew: str | None = Query(None),
    status: str | None = Query(None),
    search: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=200),
    sort: str = Query("nama"),
    dir: str = Query("asc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    """Ringkasan + daftar manpower beserta kelompoknya untuk satu bulan."""
    if periode:
        try:
            per = parse_period(periode)
        except ValueError as e:
            raise HTTPException(400, str(e))
    else:
        per = (await db.execute(text("SELECT MAX(periode) FROM manpower_month"))).scalar()
    if not per:
        return {"periode": None, "manpower": 0, "classified": 0, "unclassified": 0,
                "staff": 0, "mekanik": 0, "repairman": 0, "by_section": [],
                "by_crew": [], "by_status": [], "sections": SECTIONS, "crews": CREWS,
                "statuses": STATUSES, "depts": [], "total": 0, "page": 1,
                "page_size": page_size, "data": [], "profiled": 0}

    # KPI mengikuti seluruh filter; rincian per dimensi mengabaikan filter
    # dimensi itu sendiri supaya tetap bisa dibandingkan.
    w, p = _manage_where(per, dept, section, crew, status, search)
    s = (await db.execute(text(f"""
        SELECT COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE p.section IS NOT NULL AND p.crew IS NOT NULL
                                  AND p.status IS NOT NULL) AS classified,
               COUNT(*) FILTER (WHERE p.status = 'Staff') AS staff,
               COUNT(*) FILTER (WHERE p.status = 'Mekanik') AS mekanik,
               COUNT(*) FILTER (WHERE p.status = 'Repairman') AS repairman,
               COUNT(p.nrp) AS profiled
        FROM manpower_month m LEFT JOIN manpower_profile p ON p.nrp = m.nrp
        WHERE {w}
    """), p)).mappings().first()

    async def breakdown(dim: str, **skip):
        ww, pp = _manage_where(per, dept, **{**dict(section=section, crew=crew,
                                                    status=status), **skip}, search=search)
        rows = (await db.execute(text(_breakdown_dim(dim).format(where=ww)),
                                 pp)).mappings().all()
        return [{"label": r["label"], "total": int(r["total"] or 0),
                 "staff": int(r["staff"] or 0), "mekanik": int(r["mekanik"] or 0),
                 "repairman": int(r["repairman"] or 0)}
                for r in rows]

    by_section = await breakdown("section", section=None)
    by_crew = await breakdown("crew", crew=None)
    by_status = await breakdown("status", status=None)

    depts = [r[0] for r in (await db.execute(text(
        "SELECT DISTINCT dept FROM manpower_month WHERE periode = :p "
        "AND dept IS NOT NULL ORDER BY 1"), {"p": per})).all()]

    if sort not in _MANAGE_SORTS:
        sort = "nama"
    # `nrp` ada di kedua tabel, jadi kolom pengurutan harus diberi alias.
    sort_expr = ("m." if sort in ("nrp", "nama", "jabatan", "dept", "ss_closed",
                                  "innovator_all") else "p.") + sort
    p["lim"] = page_size
    p["off"] = (page - 1) * page_size
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM manpower_month m "
        f"LEFT JOIN manpower_profile p ON p.nrp = m.nrp WHERE {w}"), p)).scalar() or 0
    rows = (await db.execute(text(
        f"SELECT {_MANAGE_SELECT} FROM manpower_month m "
        f"LEFT JOIN manpower_profile p ON p.nrp = m.nrp WHERE {w} "
        f"ORDER BY {sort_expr} {dir.upper()} NULLS LAST, m.nrp LIMIT :lim OFFSET :off"),
        p)).mappings().all()

    manpower = int(s["manpower"] or 0)
    profiled = int(s["profiled"] or 0)
    classified = int(s["classified"] or 0)
    return {
        "periode": per.strftime("%Y-%m"),
        "manpower": manpower,
        "profiled": profiled,
        "classified": classified,
        "unclassified": manpower - classified,
        "staff": int(s["staff"] or 0),
        "mekanik": int(s["mekanik"] or 0),
        "repairman": int(s["repairman"] or 0),
        "by_section": by_section,
        "by_crew": by_crew,
        "by_status": by_status,
        "sections": SECTIONS,
        "crews": CREWS,
        "statuses": STATUSES,
        "depts": depts,
        "total": total,
        "page": page,
        "page_size": page_size,
        "data": [dict(r) for r in rows],
    }


@router.patch("/manage/{nrp}", dependencies=[Depends(require_menu("manpower", "edit"))])
async def update_profile(nrp: str, body: dict, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    """Ubah pengelompokan satu orang. Kirim "" untuk mengosongkan."""
    key = (nrp or "").strip().upper()
    if not key:
        raise HTTPException(400, "NRP kosong")
    exists = (await db.execute(text(
        "SELECT 1 FROM manpower_month WHERE nrp = :n LIMIT 1"), {"n": key})).scalar()
    if not exists:
        raise HTTPException(404, "NRP tidak ditemukan pada data manpower")

    sets, params = [], {"n": key, "u": user["username"]}
    for field, allowed in (("section", SECTIONS), ("crew", CREWS), ("status", STATUSES)):
        if field in body:
            sets.append(f"{field} = :{field}")
            params[field] = _pick(body[field], allowed, field)
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")

    await db.execute(text(
        "INSERT INTO manpower_profile (nrp) VALUES (:n) "
        "ON CONFLICT (nrp) DO NOTHING"), {"n": key})
    await db.execute(text(
        f"UPDATE manpower_profile SET {', '.join(sets)}, auto = FALSE, "
        f"updated_by = :u, updated_at = now() WHERE nrp = :n"), params)
    await db.commit()
    row = (await db.execute(text(
        "SELECT nrp, section, crew, status, auto AS auto_filled, updated_by, updated_at "
        "FROM manpower_profile WHERE nrp = :n"), {"n": key})).mappings().first()
    return dict(row) if row else {"nrp": key}


@router.post("/manage/bulk", dependencies=[Depends(require_menu("manpower", "edit"))])
async def bulk_update(body: dict, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    """Ubah pengelompokan banyak orang sekaligus (field yang dikirim saja)."""
    nrps = sorted({str(n).strip().upper() for n in (body.get("nrps") or [])
                   if str(n).strip()})
    if not nrps:
        raise HTTPException(400, "Pilih minimal satu baris")
    sets, params = [], {"n": nrps, "u": user["username"]}
    for field, allowed in (("section", SECTIONS), ("crew", CREWS), ("status", STATUSES)):
        if field in body:
            sets.append(f"{field} = :{field}")
            params[field] = _pick(body[field], allowed, field)
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")

    await db.execute(text(
        "INSERT INTO manpower_profile (nrp) VALUES (:n) "
        "ON CONFLICT (nrp) DO NOTHING"), [{"n": x} for x in nrps])
    res = await db.execute(text(
        f"UPDATE manpower_profile SET {', '.join(sets)}, auto = FALSE, "
        f"updated_by = :u, updated_at = now() WHERE nrp = ANY(:n)"), params)
    await db.commit()
    return {"updated": res.rowcount or 0, "nrps": len(nrps)}


@router.post("/manage/autofill", dependencies=[Depends(require_menu("manpower", "edit"))])
async def autofill(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    """Isi Section/Crew/Status yang masih kosong dari JABATAN terbaru.

    Hanya mengisi kolom yang kosong; nilai yang sudah diisi manual tidak diubah.
    """
    rows = (await db.execute(text("""
        SELECT DISTINCT ON (m.nrp) m.nrp, m.jabatan, p.nrp AS profil
        FROM manpower_month m
        LEFT JOIN manpower_profile p ON p.nrp = m.nrp
        WHERE p.nrp IS NULL OR p.section IS NULL OR p.crew IS NULL OR p.status IS NULL
        ORDER BY m.nrp, m.periode DESC
    """))).mappings().all()

    new_rows: list[dict] = []
    upd_rows: list[dict] = []
    skipped = 0
    for r in rows:
        section, crew, status = classify(r["jabatan"])
        if not (section or crew or status):
            skipped += 1
            continue
        item = {"nrp": r["nrp"], "section": section, "crew": crew, "status": status,
                "by": user["username"]}
        (upd_rows if r["profil"] else new_rows).append(item)

    if new_rows:
        await db.execute(text(
            "INSERT INTO manpower_profile (nrp, section, crew, status, auto, updated_by) "
            "VALUES (:nrp, :section, :crew, :status, TRUE, :by) "
            "ON CONFLICT (nrp) DO NOTHING"), new_rows)
    if upd_rows:
        await db.execute(text("""
            UPDATE manpower_profile SET
              section = COALESCE(section, :section),
              crew    = COALESCE(crew, :crew),
              status  = COALESCE(status, :status),
              updated_by = :by,
              updated_at = now()
            WHERE nrp = :nrp
        """), upd_rows)
    await db.commit()
    total = len(new_rows) + len(upd_rows)
    log.info("manpower autofill: %s baru, %s dilengkapi, %s tanpa tebakan",
             len(new_rows), len(upd_rows), skipped)
    return {"checked": len(rows), "created": len(new_rows), "filled": len(upd_rows),
            "updated": total, "skipped": skipped}
