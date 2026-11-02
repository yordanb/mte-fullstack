"""Manpower Inovasi — master data dari manpower_profile dengan metrik bulanan dari manpower_month.
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

DEPT_ALLOW: set[str] = {"SPL2"}

SECTIONS = [
    "Big Wheel - PCH", "SPEX Mobile - Lighting",
    "SPEX Pumping - Fabrication", "LCE", "MTE", "Tyre", "Dept Head",
    "General Crew",
]
CREWS = [
    "Big Wheel", "PCH", "Mobile", "Lighting", "Pumping", "Tyre",
    "MTE", "LCE", "General Crew",
]
STATUSES = ["Staff", "Mekanik", "Repairman", "General Crew"]
GENERAL_CREW = "General Crew"
EMPTY = "__EMPTY__"

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
    "GENERAL CREW - PLANT 2": ("SPEX Pumping - Fabrication", "Pumping", "General Crew"),
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
    elif "GENERAL CREW" in j:
        section, crew, status = "SPEX Pumping - Fabrication", "Pumping", GENERAL_CREW
    elif "TYRE" in j:
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
    base = name.rsplit("/", 1)[-1].rsplit("\\", 1)[-1]
    found = list(_MONTH_RE.finditer(base))
    if found:
        m = found[-1]
        month = MONTHS.get(m.group(1).lower())
        year = int(m.group(2))
        if len(m.group(2)) == 2:
            year += 2000
        if month:
            return _month_start(year, month)
    found_iso = list(_ISO_RE.finditer(base))
    if found_iso:
        m = found_iso[-1]
        return _month_start(int(m.group(1)), int(m.group(2)))
    return None


def parse_period(s: str) -> dt.date:
    raw = s.strip()
    m = re.match(r"^(\d{4})-(\d{1,2})$", raw)
    if m:
        return _month_start(int(m.group(1)), int(m.group(2)))
    raise HTTPException(400, f"Format periode invalid (harus YYYY-MM): {raw}")


def _where(periode: dt.date, dept: str | None, divisi: str | None, search: str | None) -> tuple[str, dict]:
    conds = ["p.status IS NOT NULL"]
    p: dict = {"periode": periode}
    if dept:
        conds.append("m.dept = :dept")
        p["dept"] = dept
    if divisi:
        conds.append("m.divisi = :divisi")
        p["divisi"] = divisi
    if search:
        conds.append("(p.name ILIKE :q OR p.nrp ILIKE :q OR m.jabatan ILIKE :q)")
        p["q"] = f"%{search}%"
    return " AND ".join(conds), p


def _perf_where(periode: dt.date, dept: str | None, divisi: str | None) -> tuple[str, dict]:
    conds = ["p.status IS NOT NULL"]
    p: dict = {"periode": periode}
    if dept:
        conds.append("m.dept = :dept")
        p["dept"] = dept
    if divisi:
        conds.append("m.divisi = :divisi")
        p["divisi"] = divisi
    return " AND ".join(conds), p


_PERF = "p.status IS DISTINCT FROM :gc"


@router.get("/periods", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_periods(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text(f"""
        SELECT to_char(m.periode, 'YYYY-MM') AS periode,
               (SELECT COUNT(*) FROM manpower_profile WHERE status IS NOT NULL) AS manpower,
               COUNT(p.nrp) FILTER (WHERE p.status = :gc) AS general_crew,
               COUNT(p.nrp) FILTER (WHERE {_PERF}) AS assessed,
               COUNT(p.nrp) FILTER (WHERE m.innovator_ss > 0 AND {_PERF}) AS innovator_ss,
               COALESCE(SUM(m.ss_closed) FILTER (WHERE {_PERF}), 0) AS ss_closed,
               MAX(m.updated_at) AS updated_at
        FROM manpower_profile p
        LEFT JOIN manpower_month m ON m.nrp = p.nrp
        WHERE p.status IS NOT NULL AND m.periode IS NOT NULL
        GROUP BY m.periode ORDER BY m.periode DESC
    """), {"gc": GENERAL_CREW})).mappings().all()
    out = []
    for r in rows:
        if not r["periode"]:
            continue
        mp = r["manpower"] or 0
        assessed = r["assessed"] or 0
        out.append({
            "periode": r["periode"],
            "manpower": mp,
            "general_crew": r["general_crew"] or 0,
            "assessed": assessed,
            "innovator_ss": r["innovator_ss"] or 0,
            "ss_closed": int(r["ss_closed"] or 0),
            "coverage_pct": (round((r["innovator_ss"] or 0) / assessed * 100, 1)
                             if assessed else 0),
            "updated_at": str(r["updated_at"]) if r["updated_at"] else None,
        })
    return out


@router.get("/trend", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_trend(
    dept: str | None = Query(None),
    divisi: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    conds, p = ["p.status IS NOT NULL", "m.periode IS NOT NULL"], {"gc": GENERAL_CREW}
    if dept:
        conds.append("m.dept = :dept")
        p["dept"] = dept
    if divisi:
        conds.append("m.divisi = :divisi")
        p["divisi"] = divisi
    where = ("WHERE " + " AND ".join(conds)) if conds else ""
    rows = (await db.execute(text(f"""
        SELECT to_char(m.periode, 'YYYY-MM') AS periode,
               (SELECT COUNT(*) FROM manpower_profile WHERE status IS NOT NULL) AS manpower,
               COUNT(p.nrp) FILTER (WHERE p.status = :gc) AS general_crew,
               COUNT(p.nrp) FILTER (WHERE {_PERF}) AS assessed,
               COUNT(p.nrp) FILTER (WHERE m.innovator_ss > 0 AND {_PERF}) AS innovator_ss,
               COALESCE(SUM(m.ss_closed) FILTER (WHERE {_PERF}), 0) AS ss_closed
        FROM manpower_profile p
        LEFT JOIN manpower_month m ON m.nrp = p.nrp
        {where}
        GROUP BY m.periode ORDER BY m.periode
    """), p)).mappings().all()
    out = []
    for r in rows:
        if not r["periode"]:
            continue
        assessed = r["assessed"] or 0
        out.append({
            "periode": r["periode"],
            "manpower": r["manpower"] or 0,
            "general_crew": r["general_crew"] or 0,
            "assessed": assessed,
            "innovator_ss": r["innovator_ss"] or 0,
            "ss_closed": int(r["ss_closed"] or 0),
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
    where, p = _perf_where(per, dept, divisi)
    row = (await db.execute(text(f"""
        SELECT COUNT(p.nrp) AS manpower,
               COUNT(p.nrp) FILTER (WHERE p.status = :gc) AS general_crew,
               COUNT(p.nrp) FILTER (WHERE {_PERF}) AS assessed,
               COUNT(p.nrp) FILTER (WHERE m.innovator_ss > 0 AND {_PERF}) AS innovator_ss,
               COUNT(p.nrp) FILTER (WHERE m.innovator_qcc > 0 AND {_PERF}) AS innovator_qcc,
               COUNT(p.nrp) FILTER (WHERE m.innovator_all > 0 AND {_PERF}) AS innovator_all,
               COALESCE(SUM(m.ss_closed) FILTER (WHERE {_PERF}), 0) AS ss_closed,
               COALESCE(SUM(m.dt_closed) FILTER (WHERE {_PERF}), 0) AS dt_closed,
               COALESCE(SUM(m.qcp_closed) FILTER (WHERE {_PERF}), 0) AS qcp_closed,
               COALESCE(SUM(m.qcc_closed) FILTER (WHERE {_PERF}), 0) AS qcc_closed,
               MAX(m.updated_at) AS updated_at
        FROM manpower_profile p
        LEFT JOIN manpower_month m ON m.nrp = p.nrp AND m.periode = :periode
        WHERE {where}
    """), {**p, "gc": GENERAL_CREW, "periode": per})).mappings().first()
    mp = row["manpower"] or 0
    gc = row["general_crew"] or 0
    assessed = row["assessed"] or 0
    innov = row["innovator_ss"] or 0
    ssd = int(row["ss_closed"] or 0)

    dw, dp = _perf_where(per, None, divisi)
    breaks = (await db.execute(text(f"""
        SELECT COALESCE(NULLIF(TRIM(m.dept), ''), '(kosong)') AS dept,
               COUNT(*) AS manpower,
               COUNT(*) FILTER (WHERE p.status = :gc) AS general_crew,
               COUNT(*) FILTER (WHERE {_PERF}) AS assessed,
               COUNT(*) FILTER (WHERE m.innovator_ss > 0 AND {_PERF}) AS innovator_ss,
               COALESCE(SUM(m.ss_closed) FILTER (WHERE {_PERF}), 0) AS ss_closed
        FROM manpower_profile p
        LEFT JOIN manpower_month m ON m.nrp = p.nrp AND m.periode = :per
        WHERE {dw}
        GROUP BY 1 ORDER BY manpower DESC, 1
    """), {**dp, "gc": GENERAL_CREW})).mappings().all()
    dept_rows = []
    for b in breaks:
        a = b["assessed"] or 0
        dept_rows.append({
            "dept": b["dept"],
            "manpower": b["manpower"] or 0,
            "general_crew": b["general_crew"] or 0,
            "assessed": a,
            "innovator_ss": b["innovator_ss"] or 0,
            "coverage_pct": round((b["innovator_ss"] or 0) / a * 100, 1) if a else 0,
            "ss_closed": int(b["ss_closed"] or 0),
            "ss_per_manpower": round(int(b["ss_closed"] or 0) / a, 2) if a else 0,
        })

    return {
        "periode": per.strftime("%Y-%m"),
        "manpower": mp,
        "general_crew": gc,
        "assessed": assessed,
        "innovator_ss": innov,
        "innovator_qcc": row["innovator_qcc"] or 0,
        "innovator_all": row["innovator_all"] or 0,
        "coverage_pct": round(innov / assessed * 100, 1) if assessed else 0,
        "ss_closed": ssd,
        "ss_per_manpower": round(ssd / assessed, 2) if assessed else 0,
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
        where += " AND (m.innovator_ss > 0)" if innovator else " AND (m.innovator_ss = 0 OR m.innovator_ss IS NULL)"
    if sort not in _SORTS:
        sort = "nama"
    p["lim"] = page_size
    p["off"] = (page - 1) * page_size
    
    # Pilih kolom dari profile sebagai master, dan month sebagai metrik bulanan
    select_cols = """
        p.nrp AS nrp,
        COALESCE(p.name, m.nama) AS nama,
        m.jabatan AS jabatan,
        m.dept AS dept,
        m.divisi AS divisi,
        COALESCE(m.ss_closed, 0) AS ss_closed,
        COALESCE(m.innovator_ss, 0) AS innovator_ss,
        COALESCE(m.dt_closed, 0) AS dt_closed,
        COALESCE(m.qcp_closed, 0) AS qcp_closed,
        COALESCE(m.qcc_closed, 0) AS qcc_closed
    """
    
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM manpower_profile p LEFT JOIN manpower_month m ON m.nrp = p.nrp AND m.periode = :periode WHERE {where}"), p)).scalar() or 0
    rows = (await db.execute(text(
        f"SELECT {select_cols} FROM manpower_profile p LEFT JOIN manpower_month m ON m.nrp = p.nrp AND m.periode = :periode WHERE {where} "
        f"ORDER BY {sort} {dir.upper()} NULLS LAST, p.nrp LIMIT :lim OFFSET :off"),
        p)).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}


_MANAGE_SORTS = ("nrp", "nama", "jabatan", "dept", "section", "crew", "status",
                 "updated_at")


@router.get("/manage", dependencies=[Depends(require_menu("manpower", "view"))])
async def get_manage(
    section: str | None = Query(None),
    crew: str | None = Query(None),
    status: str | None = Query(None),
    search: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(25, ge=1, le=200),
    sort: str = Query("nrp"),
    dir: str = Query("asc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    conds = ["status IS NOT NULL"]
    p: dict = {}
    if section:
        if section == EMPTY:
            conds.append("section IS NULL")
        else:
            conds.append("section = :section")
            p["section"] = section
    if crew:
        if crew == EMPTY:
            conds.append("crew IS NULL")
        else:
            conds.append("crew = :crew")
            p["crew"] = crew
    if status:
        if status == EMPTY:
            conds.append("status IS NULL")
        else:
            conds.append("status = :status")
            p["status"] = status
    if search:
        conds.append("(nrp ILIKE :q OR name ILIKE :q)")
        p["q"] = f"%{search}%"
    where = "WHERE " + " AND ".join(conds) if conds else ""
    if sort not in _MANAGE_SORTS:
        sort = "nrp"
    p["lim"] = page_size
    p["off"] = (page - 1) * page_size
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM manpower_profile {where}"), p)).scalar() or 0
    rows = (await db.execute(text(f"""
        SELECT nrp, name AS nama, section, crew, status, auto, updated_by, updated_at,
               (SELECT mm.jabatan FROM manpower_month mm WHERE mm.nrp = manpower_profile.nrp ORDER BY mm.periode DESC LIMIT 1) AS jabatan,
               (SELECT mm.dept FROM manpower_month mm WHERE mm.nrp = manpower_profile.nrp ORDER BY mm.periode DESC LIMIT 1) AS dept
        FROM manpower_profile
        {where}
        ORDER BY {sort} {dir.upper()} NULLS LAST, nrp
        LIMIT :lim OFFSET :off
    """), p)).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}


@router.post("/manage/{nrp}", dependencies=[Depends(require_menu("manpower", "edit"))])
async def update_manage(
    nrp: str,
    body: dict,
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    row = (await db.execute(text(
        "SELECT nrp FROM manpower_profile WHERE nrp = :nrp"), {"nrp": nrp})).first()
    if not row:
        raise HTTPException(404, "Manpower tidak ditemukan")

    sec = _pick(body.get("section"), SECTIONS, "Section")
    cr = _pick(body.get("crew"), CREWS, "Crew")
    st = _pick(body.get("status"), STATUSES, "Status")
    name = _txt(body.get("nama"))

    await db.execute(text("""
        UPDATE manpower_profile
        SET section = :sec, crew = :cr, status = :st, name = COALESCE(:name, name),
            auto = FALSE, updated_by = :by, updated_at = NOW()
        WHERE nrp = :nrp
    """), {
        "sec": sec, "cr": cr, "st": st, "name": name, "by": user.get("username", "api"), "nrp": nrp,
    })
    await db.execute(text("COMMIT"))
    return {"ok": True}


@router.post("/auto-classify", dependencies=[Depends(require_menu("manpower", "edit"))])
async def auto_classify(
    db: AsyncSession = Depends(get_db),
    user: dict = Depends(get_current_user),
):
    rows = (await db.execute(text("""
        SELECT m.nrp, m.jabatan
        FROM manpower_month m
        JOIN manpower_profile p ON p.nrp = m.nrp
        WHERE p.auto = TRUE OR (p.section IS NULL AND p.crew IS NULL AND p.status IS NULL)
        ORDER BY m.periode DESC
    """))).mappings().all()
    seen = set()
    count = 0
    for r in rows:
        nrp = r["nrp"]
        if nrp in seen:
            continue
        seen.add(nrp)
        sec, cr, st = classify(r["jabatan"])
        if sec or cr or st:
            await db.execute(text("""
                UPDATE manpower_profile
                SET section = COALESCE(section, :sec),
                    crew = COALESCE(crew, :cr),
                    status = COALESCE(status, :st),
                    updated_by = :by, updated_at = NOW()
                WHERE nrp = :nrp AND auto = TRUE
            """), {"sec": sec, "cr": cr, "st": st, "by": user.get("username", "api"), "nrp": nrp})
            count += 1
    await db.execute(text("COMMIT"), {"by": user.get("username", "api")})
    return {"ok": True, "updated_count": count}
