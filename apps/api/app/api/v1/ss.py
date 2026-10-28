"""Suggestion System (SS) — import ReportSSClosedDistrict (KIDE) + dashboard.

Sumber Excel: `ReportSSClosedDistrict_<distrik>_<periode>.xlsx`, sheet `Report`,
15 kolom (NO SS .. STATUS KARYAWAN). Periode file dibagi berdasarkan
TANGGAL MENILAI (bukan TANGGAL LAPORAN), sehingga filter default dashboard
memakai tanggal menilai.

Import bersifat UPSERT pada `no_ss` (0 duplikat NO SS di 4 file 2023-2026):
baris baru ditambahkan, baris lama diperbarui, data di luar file tidak dihapus.
"""
import csv
import datetime
import io
import json
import logging
import re

import openpyxl
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_role
from app.db.session import get_db, SessionLocal

router = APIRouter(prefix="/v1/ss", tags=["ss"])
log = logging.getLogger("ss")

SHEET = "Report"
HEADERS = [
    "NO SS", "TANGGAL LAPORAN", "JUDUL", "PENCETUS IDE", "NRP", "DEPT", "DISTRIK",
    "MANFAAT FINANCIAL", "TANGGAL MENILAI", "DINILAI OLEH", "GRADE SS",
    "KUALITAS SS", "KATEGORI SS", "REWARD SS", "STATUS KARYAWAN",
]
# ReportOutstandingSS — SS yang belum dinilai (kolom penilaian belum ada).
OUTSTANDING_HEADERS = [
    "NO SS", "TANGGAL LAPORAN", "NAMA", "NRP", "DEPT", "DISTRIK", "JUDUL", "STATUS",
]
COLS = [
    "no_ss", "tgl_laporan", "judul", "pencetus", "nrp", "dept", "distrik",
    "manfaat_fin", "tgl_menilai", "dinilai_oleh", "grade", "kualitas",
    "kategori", "kategori_norm", "reward", "status_karyawan",
]
BATCH = 2000
MAX_EXPORT = 100000

# 29 varian teks di sumber -> ~12 kategori kanonik.
KATEGORI_MAP = {
    "productivity": "Productivity",
    "peningkatan produktivitas": "Productivity",
    "peningkatan produktifitas": "Productivity",
    "maintenance": "Maintenance",
    "administration": "Administration",
    "administrasi": "Administration",
    "she": "SHE",
    "k3lh": "SHE",
    "peningkatan efisiensi": "Efficiency",
    "peningkatan sdm": "People & Competency",
    "people and competency": "People & Competency",
    "digitalization": "Digitalization",
    "corporate image": "Corporate Image",
    "delay": "Delay",
    "coal production": "Coal Production",
    "csr": "CSR",
}


def _norm_kategori(raw: str | None) -> str | None:
    s = (raw or "").strip()
    if not s:
        return None
    key = re.sub(r"\s+", " ", s.lower())
    if key in KATEGORI_MAP:
        return KATEGORI_MAP[key]
    if key.startswith("cre"):
        return "CRE"
    return s


def _norm_kualitas(raw: str | None) -> str | None:
    s = (raw or "").strip()
    if not s:
        return None
    # Typo sumber: grade A dengan kualitas "Break" (7 baris).
    if s.lower() in ("break", "breakthrough"):
        return "Breakthrough"
    return s


def _txt(v) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def _date(v) -> datetime.date | None:
    if v is None or v == "":
        return None
    if isinstance(v, datetime.datetime):
        return v.date()
    if isinstance(v, datetime.date):
        return v
    s = str(v).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%d/%m/%y"):
        try:
            return datetime.datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def _num(v) -> float | None:
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).replace(",", "").strip()
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _data_rows(content: bytes, fname: str) -> tuple[list[dict], list[dict]]:
    """Baca satu workbook -> (rows, errors). Raises ValueError bila header kurang.

    Mendukung dua format:
      * ReportSSClosedDistrict (SS sudah dinilai) — 15 kolom penilaian lengkap.
      * ReportOutstandingSS    (SS masih berjalan) — 10 kolom, status workflow.
    Tiap baris diberi penanda `_kind` = 'closed' | 'outstanding'.
    """
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
        if all(h in idx for h in HEADERS):
            kind = "closed"
        elif all(h in idx for h in OUTSTANDING_HEADERS) and "PENCETUS IDE" not in idx:
            kind = "outstanding"
        else:
            missing = [h for h in HEADERS if h not in idx]
            raise ValueError(
                "format tidak dikenali. Untuk ReportSSClosedDistrict kolom wajib hilang: "
                f"{', '.join(missing)}; untuk ReportOutstandingSS dibutuhkan: "
                f"{', '.join(OUTSTANDING_HEADERS)}"
            )
        rows: list[dict] = []
        errors: list[dict] = []
        for rno, r in enumerate(it, start=2):
            if r is None:
                continue
            if all(v is None or (isinstance(v, str) and not v.strip()) for v in r):
                continue

            def g(name: str):
                i = idx[name]
                return r[i] if i < len(r) else None

            no_ss = (_txt(g("NO SS")) or "").upper()
            if not no_ss:
                errors.append({"file": fname, "row": rno, "error": "NO SS kosong"})
                continue
            try:
                if kind == "outstanding":
                    rows.append({
                        "_kind": "outstanding",
                        "no_ss": no_ss,
                        "tgl_laporan": _date(g("TANGGAL LAPORAN")),
                        "judul": _txt(g("JUDUL")),
                        "pencetus": _txt(g("NAMA")),
                        "nrp": _txt(g("NRP")),
                        "dept": (_txt(g("DEPT")) or "").upper() or None,
                        "distrik": _txt(g("DISTRIK")),
                        "divisi": (_txt(g("DIVISI")) or "").upper() or None,
                        "management": _txt(g("MANAGEMENT")),
                        "status_ss": _txt(g("STATUS")),
                    })
                    continue
                kategori = _txt(g("KATEGORI SS"))
                grade = (_txt(g("GRADE SS")) or "").upper()[:2] or None
                rows.append({
                    "_kind": "closed",
                    "no_ss": no_ss,
                    "tgl_laporan": _date(g("TANGGAL LAPORAN")),
                    "judul": _txt(g("JUDUL")),
                    "pencetus": _txt(g("PENCETUS IDE")),
                    "nrp": _txt(g("NRP")),
                    "dept": (_txt(g("DEPT")) or "").upper() or None,
                    "distrik": _txt(g("DISTRIK")),
                    "manfaat_fin": _num(g("MANFAAT FINANCIAL")),
                    "tgl_menilai": _date(g("TANGGAL MENILAI")),
                    "dinilai_oleh": _txt(g("DINILAI OLEH")),
                    "grade": grade,
                    "kualitas": _norm_kualitas(_txt(g("KUALITAS SS"))),
                    "kategori": kategori,
                    "kategori_norm": _norm_kategori(kategori),
                    "reward": _num(g("REWARD SS")) or 0,
                    "status_karyawan": (_txt(g("STATUS KARYAWAN")) or "").upper() or None,
                })
            except Exception as e:  # noqa: BLE001
                errors.append({"file": fname, "row": rno, "error": str(e)})
        return rows, errors
    finally:
        wb.close()


# --- upsert ReportSSClosedDistrict: SS sudah dinilai -> approved -------------
_UPSERT_CLOSED = text(f"""
INSERT INTO ss_report ({', '.join(COLS)}, import_id, outstanding, status_ss)
VALUES ({', '.join(':' + c for c in COLS)}, :import_id, FALSE, NULL)
ON CONFLICT (no_ss) DO UPDATE SET
  tgl_laporan=COALESCE(EXCLUDED.tgl_laporan, ss_report.tgl_laporan),
  judul=COALESCE(EXCLUDED.judul, ss_report.judul),
  pencetus=COALESCE(EXCLUDED.pencetus, ss_report.pencetus),
  nrp=COALESCE(EXCLUDED.nrp, ss_report.nrp),
  dept=COALESCE(EXCLUDED.dept, ss_report.dept),
  distrik=COALESCE(EXCLUDED.distrik, ss_report.distrik),
  manfaat_fin=COALESCE(EXCLUDED.manfaat_fin, ss_report.manfaat_fin),
  tgl_menilai=COALESCE(EXCLUDED.tgl_menilai, ss_report.tgl_menilai),
  dinilai_oleh=COALESCE(EXCLUDED.dinilai_oleh, ss_report.dinilai_oleh),
  grade=COALESCE(EXCLUDED.grade, ss_report.grade),
  kualitas=COALESCE(EXCLUDED.kualitas, ss_report.kualitas),
  kategori=COALESCE(EXCLUDED.kategori, ss_report.kategori),
  kategori_norm=COALESCE(EXCLUDED.kategori_norm, ss_report.kategori_norm),
  reward=CASE WHEN EXCLUDED.reward > 0 THEN EXCLUDED.reward ELSE ss_report.reward END,
  status_karyawan=COALESCE(EXCLUDED.status_karyawan, ss_report.status_karyawan),
  outstanding=FALSE,
  status_ss=NULL,
  outstanding_at=NULL,
  import_id=EXCLUDED.import_id,
  updated_at=now()
""")

# --- upsert ReportOutstandingSS: SS masih berjalan --------------------------
# Kolom penilaian (grade/kategori/reward/tgl_menilai/...) TIDAK disentuh, supaya
# upload outstanding berikutnya tidak menghapus hasil penilaian yang sudah ada.
# Bila baris sudah punya grade (approved), status outstanding tidak dihidupkan.
_UPSERT_OUTSTANDING = text("""
INSERT INTO ss_report
  (no_ss, tgl_laporan, judul, pencetus, nrp, dept, distrik,
   divisi, management, status_ss, outstanding, outstanding_at, import_id)
VALUES
  (:no_ss, :tgl_laporan, :judul, :pencetus, :nrp, :dept, :distrik,
   :divisi, :management, :status_ss, TRUE, now(), :import_id)
ON CONFLICT (no_ss) DO UPDATE SET
  tgl_laporan=COALESCE(EXCLUDED.tgl_laporan, ss_report.tgl_laporan),
  judul=COALESCE(EXCLUDED.judul, ss_report.judul),
  pencetus=COALESCE(EXCLUDED.pencetus, ss_report.pencetus),
  nrp=COALESCE(EXCLUDED.nrp, ss_report.nrp),
  dept=COALESCE(EXCLUDED.dept, ss_report.dept),
  distrik=COALESCE(EXCLUDED.distrik, ss_report.distrik),
  divisi=COALESCE(EXCLUDED.divisi, ss_report.divisi),
  management=COALESCE(EXCLUDED.management, ss_report.management),
  status_ss=CASE WHEN ss_report.grade IS NULL THEN EXCLUDED.status_ss
                 ELSE ss_report.status_ss END,
  outstanding=CASE WHEN ss_report.grade IS NULL THEN TRUE ELSE FALSE END,
  outstanding_at=CASE WHEN ss_report.grade IS NULL THEN now()
                      ELSE ss_report.outstanding_at END,
  import_id=EXCLUDED.import_id,
  updated_at=now()
""")


async def _existing(db: AsyncSession, keys: list[str]) -> int:
    if not keys:
        return 0
    params = {f"k{i}": k for i, k in enumerate(keys)}
    ph = ",".join(f":k{i}" for i in range(len(keys)))
    return (await db.execute(
        text(f"SELECT count(*) FROM ss_report WHERE no_ss IN ({ph})"), params)).scalar() or 0


async def _count_flag(db: AsyncSession, keys: list[str], cond: str) -> int:
    """Hitung baris existing yang memenuhi kondisi tetap (mis. masih outstanding)."""
    if not keys:
        return 0
    params = {f"k{i}": k for i, k in enumerate(keys)}
    ph = ",".join(f":k{i}" for i in range(len(keys)))
    return (await db.execute(text(
        f"SELECT count(*) FROM ss_report WHERE no_ss IN ({ph}) AND {cond}"), params)).scalar() or 0


def _bind(row: dict, import_id: str) -> dict:
    """Buang penanda internal `_kind` sebelum dikirim sebagai parameter SQL."""
    return {**{k: v for k, v in row.items() if not k.startswith("_")}, "import_id": import_id}


async def _run(import_id: str, files: list[tuple[str, bytes]]):
    async with SessionLocal() as db:
        try:
            merged: dict[str, dict] = {}
            errors: list[dict] = []
            total = 0
            duplicates = 0
            for fname, content in files:
                try:
                    rows, errs = _data_rows(content, fname)
                except Exception as e:  # noqa: BLE001
                    errors.append({"file": fname, "error": str(e)})
                    continue
                total += len(rows) + len(errs)
                errors.extend(errs[:50])
                for row in rows:
                    prev = merged.get(row["no_ss"])
                    if prev is not None:
                        duplicates += 1
                        # File closed (sudah dinilai) menang atas outstanding.
                        if prev["_kind"] == "closed" and row["_kind"] == "outstanding":
                            continue
                    merged[row["no_ss"]] = row
                await db.execute(text(
                    "UPDATE imports SET total_rows=:t, processed_rows=:p WHERE id=:i"),
                    {"t": total, "p": total, "i": import_id})
                await db.commit()

            values = list(merged.values())
            inserted = updated = 0
            approved_now = 0
            done = 0
            for i in range(0, len(values), BATCH):
                batch = values[i:i + BATCH]
                closed = [b for b in batch if b["_kind"] == "closed"]
                outs = [b for b in batch if b["_kind"] == "outstanding"]

                if closed:
                    keys = [b["no_ss"] for b in closed]
                    upd = await _existing(db, keys)
                    # Baris yang tadinya outstanding kini punya grade di file closed.
                    approved_now += await _count_flag(db, keys, "outstanding = TRUE")
                    await db.execute(_UPSERT_CLOSED, [_bind(b, import_id) for b in closed])
                    inserted += len(closed) - upd
                    updated += upd

                if outs:
                    keys = [b["no_ss"] for b in outs]
                    upd = await _existing(db, keys)
                    await db.execute(_UPSERT_OUTSTANDING, [_bind(b, import_id) for b in outs])
                    inserted += len(outs) - upd
                    updated += upd

                done += len(batch)
                await db.execute(text(
                    "UPDATE imports SET processed_rows=:p, ok_rows=:o WHERE id=:i"),
                    {"p": done, "o": done, "i": import_id})
                await db.commit()

            out_rows = sum(1 for v in values if v["_kind"] == "outstanding")
            summary = {
                "inserted": inserted,
                "updated": updated,
                "duplicates": duplicates,
                "skipped": max(0, total - len(values) - len(errors)),
                "closed": len(values) - out_rows,
                "outstanding": out_rows,
                "now_approved": approved_now,
                "files": [f for f, _ in files],
                "total_rows": total,
                "errors": errors[:50],
            }
            await db.execute(text(
                "UPDATE imports SET status='COMMITTED', total_rows=:t, ok_rows=:o, "
                "fail_rows=:f, processed_rows=:p, errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"t": total, "o": len(values), "f": len(errors), "p": len(values),
                 "e": json.dumps(summary), "i": import_id})
            await db.commit()
            log.info("ss import %s: %s inserted, %s updated, %s dup, %s outstanding, "
                     "%s berubah approved, %s error(s)",
                     import_id, inserted, updated, duplicates, out_rows, approved_now,
                     len(errors))
        except Exception as e:  # noqa: BLE001
            await db.rollback()
            await db.execute(text(
                "UPDATE imports SET status='FAILED', errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"e": json.dumps({"error": str(e)}), "i": import_id})
            await db.commit()
            log.exception("ss import gagal: %s", e)


@router.post("/import", dependencies=[Depends(require_role("admin"))], status_code=202)
async def import_xlsx(
    bg: BackgroundTasks,
    files: list[UploadFile] = File(...),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Upload 1..n file xlsx ReportSS. Upsert berdasarkan NO SS."""
    if not files:
        raise HTTPException(400, "Tidak ada file")
    payload: list[tuple[str, bytes]] = []
    limit = settings.max_upload_mb * 1024 * 1024
    for f in files:
        content = await f.read()
        if len(content) > limit:
            raise HTTPException(413, f"{f.filename}: file terlalu besar")
        if not content:
            raise HTTPException(400, f"{f.filename}: file kosong")
        payload.append((f.filename or "upload.xlsx", content))
    label = ", ".join(name for name, _ in payload)
    res = await db.execute(text(
        "INSERT INTO imports(filename,sheet,status,total_rows,uploaded_by) "
        "VALUES (:fn,'SS','PROCESSING',0,:u) RETURNING id"),
        {"fn": label[:300], "u": user["username"]})
    import_id = str(res.scalar_one())
    await db.commit()
    bg.add_task(_run, import_id, payload)
    return {"import_id": import_id, "status": "PROCESSING", "files": len(payload)}


@router.get("/import/{import_id}", dependencies=[Depends(require_role("admin"))])
async def import_status(import_id: str, db: AsyncSession = Depends(get_db)):
    """Progres + ringkasan hasil import (inserted/updated/errors)."""
    row = (await db.execute(text(
        "SELECT id, filename, status, total_rows, ok_rows, fail_rows, processed_rows, "
        "uploaded_by, created_at, errors FROM imports WHERE id=:i AND sheet='SS'"),
        {"i": import_id})).mappings().first()
    if not row:
        raise HTTPException(404, "import_id tidak ditemukan")
    return dict(row)


@router.get("/filters", dependencies=[Depends(require_role("admin"))])
async def get_filters(db: AsyncSession = Depends(get_db)):
    depts = (await db.execute(text(
        "SELECT DISTINCT dept FROM ss_report WHERE dept IS NOT NULL AND dept <> '' ORDER BY dept"
    ))).scalars().all()
    kats = (await db.execute(text(
        "SELECT DISTINCT kategori_norm FROM ss_report "
        "WHERE kategori_norm IS NOT NULL AND kategori_norm <> '' ORDER BY 1"
    ))).scalars().all()
    grades = (await db.execute(text(
        "SELECT DISTINCT grade FROM ss_report WHERE grade IS NOT NULL AND grade <> '' ORDER BY 1"
    ))).scalars().all()
    statuses = (await db.execute(text(
        "SELECT DISTINCT status_karyawan FROM ss_report "
        "WHERE status_karyawan IS NOT NULL AND status_karyawan <> '' ORDER BY 1"
    ))).scalars().all()
    span = (await db.execute(text(
        "SELECT MIN(tgl_menilai) AS min_menilai, MAX(tgl_menilai) AS max_menilai, "
        "MIN(tgl_laporan) AS min_laporan, MAX(tgl_laporan) AS max_laporan, "
        "COUNT(*) AS total FROM ss_report"
    ))).mappings().first()
    status_ss = (await db.execute(text(
        "SELECT DISTINCT status_ss FROM ss_report "
        "WHERE status_ss IS NOT NULL AND status_ss <> '' ORDER BY 1"
    ))).scalars().all()
    counts = (await db.execute(text(
        "SELECT COUNT(*) FILTER (WHERE outstanding) AS outstanding, "
        "COUNT(*) FILTER (WHERE grade IS NOT NULL) AS approved FROM ss_report"
    ))).mappings().first()
    return {
        "dept": list(depts), "kategori": list(kats), "grade": list(grades),
        "status": list(statuses), "status_ss": list(status_ss),
        "outstanding": counts["outstanding"] if counts else 0,
        "approved": counts["approved"] if counts else 0,
        "min_menilai": str(span["min_menilai"]) if span and span["min_menilai"] else None,
        "max_menilai": str(span["max_menilai"]) if span and span["max_menilai"] else None,
        "min_laporan": str(span["min_laporan"]) if span and span["min_laporan"] else None,
        "max_laporan": str(span["max_laporan"]) if span and span["max_laporan"] else None,
        "total": span["total"] if span else 0,
    }


def _where(f: dict, with_date: bool = True) -> tuple[str, dict]:
    parts: list[str] = []
    p: dict = {}
    if with_date:
        col = "tgl_laporan" if f["date_basis"] == "laporan" else "tgl_menilai"
        conds: list[str] = []
        if f["start"]:
            conds.append(f"{col} >= :start")
            p["start"] = f["start"]
        if f["end"]:
            conds.append(f"{col} <= :end")
            p["end"] = f["end"]
        date_sql = " AND ".join(conds) if conds else "TRUE"
        if col == "tgl_menilai":
            # SS outstanding belum punya tanggal menilai — tetap tampilkan agar
            # bisa dipantau, apa pun rentang tanggal pada filter.
            parts.append(f"(({date_sql}) OR (tgl_menilai IS NULL AND outstanding = TRUE))")
        else:
            parts.append(f"({date_sql})")
    if f.get("tahap") == "outstanding":
        parts.append("outstanding = TRUE")
    elif f.get("tahap") == "approved":
        parts.append("grade IS NOT NULL")
    if f["dept"]:
        parts.append("dept = :dept")
        p["dept"] = f["dept"]
    if f["kategori"]:
        parts.append("kategori_norm = :kat")
        p["kat"] = f["kategori"]
    if f["grade"]:
        parts.append("grade = :grade")
        p["grade"] = f["grade"]
    if f["status"] == "__EMPTY__":
        parts.append("(status_karyawan IS NULL OR status_karyawan = '')")
    elif f["status"]:
        parts.append("status_karyawan = :status")
        p["status"] = f["status"]
    if f["search"]:
        parts.append("(no_ss ILIKE :q OR judul ILIKE :q OR pencetus ILIKE :q "
                     "OR nrp ILIKE :q OR dinilai_oleh ILIKE :q)")
        p["q"] = f"%{f['search']}%"
    return (" AND ".join(parts) if parts else "TRUE"), p


def _params(
    date_basis: str = Query("menilai", pattern="^(menilai|laporan)$"),
    start: datetime.date | None = Query(None),
    end: datetime.date | None = Query(None),
    dept: str | None = Query(None),
    kategori: str | None = Query(None),
    grade: str | None = Query(None),
    status: str | None = Query(None),
    tahap: str | None = Query(None, pattern="^(outstanding|approved)$"),
    search: str | None = Query(None),
) -> dict:
    return {"date_basis": date_basis, "start": start, "end": end, "dept": dept,
            "kategori": kategori, "grade": grade, "status": status, "tahap": tahap,
            "search": search}


def _filters(f: dict, with_date: bool = True) -> tuple[str, dict]:
    return _where(f, with_date=with_date)


@router.get("/kpi", dependencies=[Depends(require_role("admin"))])
async def get_kpi(f: dict = Depends(_params), db: AsyncSession = Depends(get_db)):
    where, p = _filters(f)
    row = (await db.execute(text(f"""
        SELECT COUNT(*) AS total,
               COALESCE(SUM(reward), 0)::float8 AS reward,
               COALESCE(SUM(manfaat_fin), 0)::float8 AS manfaat,
               COUNT(DISTINCT NULLIF(nrp, '')) AS pencetus,
               COUNT(*) FILTER (WHERE grade = 'A') AS grade_a,
               COUNT(*) FILTER (WHERE grade IN ('A', 'B')) AS grade_ab,
               COUNT(*) FILTER (WHERE grade = 'F') AS grade_f,
               COUNT(*) FILTER (WHERE manfaat_fin IS NOT NULL AND manfaat_fin <> 0) AS manfaat_rows,
               COUNT(*) FILTER (WHERE outstanding) AS outstanding,
               COUNT(*) FILTER (WHERE grade IS NULL) AS pending
        FROM ss_report WHERE {where}
    """), p)).mappings().first()
    total = row["total"] or 0
    pencetus = row["pencetus"] or 0
    return {
        "total": total,
        "reward": row["reward"] or 0,
        "manfaat": row["manfaat"] or 0,
        "manfaat_rows": row["manfaat_rows"] or 0,
        "pencetus": pencetus,
        "avg_per_pencetus": round(total / pencetus, 1) if pencetus else 0,
        "grade_a": row["grade_a"] or 0,
        "grade_ab": row["grade_ab"] or 0,
        "grade_f": row["grade_f"] or 0,
        "outstanding": row["outstanding"] or 0,
        "pending": row["pending"] or 0,
    }


@router.get("/trend", dependencies=[Depends(require_role("admin"))])
async def get_trend(
    f: dict = Depends(_params),
    granularity: str = Query("month", pattern="^(day|month|year)$"),
    db: AsyncSession = Depends(get_db),
):
    """Jumlah SS per periode dari dua sudut: tanggal laporan vs tanggal menilai.

    Filter rentang tanggal diterapkan pada masing-masing kolom tanggalnya sendiri
    supaya kedua seri bisa dibandingkan adil; filter non-tanggal (dept, kategori,
    grade, status, cari) berlaku untuk keduanya.
    """
    where, p = _filters(f, with_date=False)
    fmt = {"day": "YYYY-MM-DD", "month": "YYYY-MM", "year": "YYYY"}[granularity]
    cond_l = ["tgl_laporan IS NOT NULL"]
    cond_m = ["tgl_menilai IS NOT NULL"]
    if f["start"]:
        p["start"] = f["start"]
        cond_l.append("tgl_laporan >= :start")
        cond_m.append("tgl_menilai >= :start")
    if f["end"]:
        p["end"] = f["end"]
        cond_l.append("tgl_laporan <= :end")
        cond_m.append("tgl_menilai <= :end")
    rows = (await db.execute(text(f"""
        WITH l AS (
          SELECT to_char(date_trunc('{granularity}', tgl_laporan), '{fmt}') AS period,
                 COUNT(*) AS n
          FROM ss_report
          WHERE {where} AND {' AND '.join(cond_l)}
          GROUP BY 1
        ), m AS (
          SELECT to_char(date_trunc('{granularity}', tgl_menilai), '{fmt}') AS period,
                 COUNT(*) AS n
          FROM ss_report
          WHERE {where} AND {' AND '.join(cond_m)}
          GROUP BY 1
        )
        SELECT COALESCE(l.period, m.period) AS period,
               COALESCE(l.n, 0) AS laporan,
               COALESCE(m.n, 0) AS menilai
        FROM l FULL OUTER JOIN m ON l.period = m.period
        ORDER BY 1
    """), p)).mappings().all()
    return [dict(r) for r in rows]


_BREAK_COL = {
    "grade": "grade",
    "kategori": "kategori_norm",
    "dept": "dept",
    "status": "status_karyawan",
    "kualitas": "kualitas",
}


@router.get("/breakdown", dependencies=[Depends(require_role("admin"))])
async def get_breakdown(
    f: dict = Depends(_params),
    by: str = Query("grade"),
    db: AsyncSession = Depends(get_db),
):
    col = _BREAK_COL.get(by)
    if not col:
        raise HTTPException(400, f"by harus salah satu: {', '.join(_BREAK_COL)}")
    where, p = _filters(f)
    rows = (await db.execute(text(f"""
        SELECT COALESCE(NULLIF(TRIM({col}), ''), '(kosong)') AS label,
               COUNT(*) AS total,
               COALESCE(SUM(reward), 0)::float8 AS reward
        FROM ss_report WHERE {where}
        GROUP BY 1 ORDER BY total DESC
    """), p)).mappings().all()
    return [dict(r) for r in rows]


@router.get("/top", dependencies=[Depends(require_role("admin"))])
async def get_top(
    f: dict = Depends(_params),
    by: str = Query("pencetus", pattern="^(pencetus|penilai)$"),
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    where, p = _filters(f)
    p["lim"] = limit
    if by == "pencetus":
        rows = (await db.execute(text(f"""
            SELECT nrp AS key,
                   (ARRAY_AGG(pencetus ORDER BY tgl_menilai DESC NULLS LAST))[1] AS nama,
                   COUNT(*) AS total,
                   COALESCE(SUM(reward), 0)::float8 AS reward
            FROM ss_report
            WHERE {where} AND nrp IS NOT NULL AND nrp <> ''
            GROUP BY nrp ORDER BY total DESC, nrp LIMIT :lim
        """), p)).mappings().all()
    else:
        rows = (await db.execute(text(f"""
            SELECT UPPER(TRIM(dinilai_oleh)) AS key,
                   UPPER(TRIM(dinilai_oleh)) AS nama,
                   COUNT(*) AS total,
                   COALESCE(SUM(reward), 0)::float8 AS reward
            FROM ss_report
            WHERE {where} AND dinilai_oleh IS NOT NULL AND TRIM(dinilai_oleh) <> ''
            GROUP BY 1 ORDER BY total DESC, 1 LIMIT :lim
        """), p)).mappings().all()
    return [dict(r) for r in rows]


_SORTS = ("tgl_menilai", "tgl_laporan", "reward", "no_ss")
_SELECT = ("id, no_ss, tgl_laporan, judul, pencetus, nrp, dept, distrik, divisi, "
           "manfaat_fin, tgl_menilai, dinilai_oleh, grade, kualitas, kategori, "
           "kategori_norm, reward, status_karyawan, management, status_ss, outstanding")


@router.get("/records", dependencies=[Depends(require_role("admin"))])
async def get_records(
    f: dict = Depends(_params),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    sort: str = Query("tgl_menilai"),
    dir: str = Query("desc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    where, p = _filters(f)
    if sort not in _SORTS:
        sort = "tgl_menilai"
    p["lim"] = page_size
    p["off"] = (page - 1) * page_size
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM ss_report WHERE {where}"), p)).scalar() or 0
    rows = (await db.execute(text(
        f"SELECT {_SELECT} FROM ss_report WHERE {where} "
        f"ORDER BY {sort} {dir.upper()} NULLS LAST, no_ss LIMIT :lim OFFSET :off"),
        p)).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}


EXPORT_HEADERS = [
    "NO SS", "TANGGAL LAPORAN", "JUDUL", "PENCETUS IDE", "NRP", "DEPT", "DIVISI",
    "DISTRIK", "MANFAAT FINANCIAL", "TANGGAL MENILAI", "DINILAI OLEH", "GRADE SS",
    "KUALITAS SS", "KATEGORI SS", "KATEGORI NORMAL", "REWARD SS", "STATUS KARYAWAN",
    "STATUS SS", "OUTSTANDING",
]


@router.get("/export", dependencies=[Depends(require_role("admin"))])
async def export_csv(
    f: dict = Depends(_params),
    db: AsyncSession = Depends(get_db),
):
    where, p = _filters(f)
    p["lim"] = MAX_EXPORT
    col = "tgl_laporan" if f["date_basis"] == "laporan" else "tgl_menilai"
    rows = (await db.execute(text(
        f"SELECT {_SELECT} FROM ss_report WHERE {where} "
        f"ORDER BY {col} DESC NULLS LAST, no_ss LIMIT :lim"), p)).mappings().all()
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(EXPORT_HEADERS)
    for r in rows:
        w.writerow([
            r["no_ss"], r["tgl_laporan"], r["judul"], r["pencetus"], r["nrp"],
            r["dept"], r["divisi"], r["distrik"], r["manfaat_fin"], r["tgl_menilai"],
            r["dinilai_oleh"], r["grade"], r["kualitas"], r["kategori"],
            r["kategori_norm"], r["reward"], r["status_karyawan"],
            r["status_ss"], r["outstanding"],
        ])
    body = "\ufeff" + buf.getvalue()
    fname = f"ss_report_{datetime.date.today().isoformat()}.csv"
    return Response(
        content=body.encode("utf-8"),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'},
    )


@router.delete("/all", dependencies=[Depends(require_role("admin"))])
async def clear_all(db: AsyncSession = Depends(get_db)):
    """Kosongkan data SS (untuk re-import dari nol)."""
    res = await db.execute(text("DELETE FROM ss_report"))
    await db.commit()
    return {"deleted": res.rowcount or 0}
