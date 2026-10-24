"""Ewacs Performance — import CSV breakdown + KPI dashboard."""
import csv
import io
import logging
from datetime import datetime, date
from decimal import Decimal, InvalidOperation

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/ewacs", tags=["ewacs"])
log = logging.getLogger("ewacs")


def _parse_tanggal(raw: str) -> date | None:
    """Format YYYYMMDD → date, mis. '20260901' → date(2026,9,1)."""
    s = (raw or '').strip()
    if len(s) == 8 and s.isdigit():
        try:
            return date(int(s[:4]), int(s[4:6]), int(s[6:8]))
        except ValueError:
            return None
    return None


def _parse_numeric(raw: str) -> float:
    """Parse angka dengan comma thousand separator, mis. '12,705.00' → 12705.00."""
    s = (raw or '').strip().replace(',', '')
    if not s:
        return 0
    try:
        return float(s)
    except ValueError:
        return 0


def _parse_time(raw: str) -> str:
    """Format 'HH:MM' → simpan apa adanya. Kosong/invalid → NULL."""
    s = (raw or '').strip()
    if not s or s == ':':
        return None
    return s


@router.post("/import", dependencies=[Depends(require_role("inputer", "admin"))])
async def import_csv(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Import CSV breakdown. Format: header row + data rows.
    Kolom: tanggal,Crew,CN_1,EGI_1,TroubleDescription_1,Shift,Kode_1,WO_1,
    Lokasi_1,StartBD_1,MekanikDatang_1,RFU_1,Operatordatang_2,Durasi_2,
    HMStart_1,HMRFUMek_1,HMRFUOpt_1,GLPlant_1,Mekanik_1,Action_1,ID_lastupdate
    """
    content = await file.read()
    if len(content) > settings.max_upload_mb * 1024 * 1024:
        raise HTTPException(413, "File terlalu besar")
    try:
        text_content = content.decode('utf-8-sig')
    except UnicodeDecodeError:
        text_content = content.decode('latin-1')
    reader = csv.DictReader(io.StringIO(text_content))
    rows = list(reader)
    if not rows:
        raise HTTPException(400, "CSV kosong / tidak terbaca")
    # Validasi header
    required = {'tanggal', 'CN_1', 'Kode_1', 'Durasi_2'}
    missing = required - set(rows[0].keys())
    if missing:
        raise HTTPException(400, f"Kolom wajib hilang: {missing}")
    # UPSERT — data lama TIDAK dihapus semua lagi.
    # Natural key satu baris breakdown: (tanggal, cn, shift, kode, start_bd).
    #   - baris dengan key sama  → di-UPDATE (crew, durasi, HM, action, dll)
    #   - baris baru             → di-INSERT
    #   - baris "basi"           → hanya dihapus kalau berada di dalam scope file
    #     (pasangan tanggal+cn yang ikut terkirim) tapi key-nya sudah tidak ada
    #     di CSV. Ini menangani koreksi/penghapusan baris di sumber, tanpa
    #     menyentuh tanggal atau unit lain yang tidak ada di file.
    values: list[dict] = []
    index: dict[tuple, int] = {}
    duplicates = 0
    skip = 0
    for row in rows:
        d = _parse_tanggal(row.get('tanggal', ''))
        cn = (row.get('CN_1') or '').strip()
        kode = (row.get('Kode_1') or '').strip()
        if not d or not cn or not kode:
            skip += 1
            continue
        durasi = _parse_numeric(row.get('Durasi_2', ''))
        v = {
            "tanggal": d,
            "crew": (row.get('Crew') or '').strip() or None,
            "cn": cn,
            "egi": (row.get('EGI_1') or '').strip() or None,
            "trouble_desc": (row.get('TroubleDescription_1') or '').strip() or None,
            "shift": (row.get('Shift') or '').strip() or None,
            "kode": kode,
            "wo": (row.get('WO_1') or '').strip() or None,
            "lokasi": (row.get('Lokasi_1') or '').strip() or None,
            "start_bd": _parse_time(row.get('StartBD_1', '')),
            "mekanik_datang": _parse_time(row.get('MekanikDatang_1', '')),
            "rfu": _parse_time(row.get('RFU_1', '')),
            "operator_datang": _parse_time(row.get('Operatordatang_2', '')),
            "durasi": durasi,
            "hm_start": _parse_numeric(row.get('HMStart_1', '')) or None,
            "hm_rfu_mek": _parse_numeric(row.get('HMRFUMek_1', '')) or None,
            "hm_rfu_opt": _parse_numeric(row.get('HMRFUOpt_1', '')) or None,
            "gl_plant": (row.get('GLPlant_1') or '').strip() or None,
            "mekanik": (row.get('Mekanik_1') or '').strip() or None,
            "action": (row.get('Action_1') or '').strip() or None,
            "id_lastupdate": (row.get('ID_lastupdate') or '').strip() or None,
        }
        # Dedupe dalam file: key sama → baris terakhir menang (satu baris = satu key).
        key = (d, cn, v["shift"] or '', kode, v["start_bd"] or '')
        if key in index:
            duplicates += 1
            values[index[key]] = v
        else:
            index[key] = len(values)
            values.append(v)
    if not values:
        raise HTTPException(400, "Tidak ada row valid")

    cols = ("tanggal,crew,cn,egi,trouble_desc,shift,kode,wo,lokasi,"
            "start_bd,mekanik_datang,rfu,operator_datang,durasi,"
            "hm_start,hm_rfu_mek,hm_rfu_opt,gl_plant,mekanik,action,id_lastupdate")
    named = (":tanggal,:crew,:cn,:egi,:trouble_desc,:shift,:kode,:wo,:lokasi,"
             ":start_bd,:mekanik_datang,:rfu,:operator_datang,:durasi,"
             ":hm_start,:hm_rfu_mek,:hm_rfu_opt,:gl_plant,:mekanik,:action,:id_lastupdate")

    # Staging per-transaksi: tidak menyentuh tabel utama sampai semua valid.
    await db.execute(text("DROP TABLE IF EXISTS ewacs_import_stage"))
    await db.execute(text("""
        CREATE TEMP TABLE ewacs_import_stage (
          tanggal date, crew text, cn text, egi text, trouble_desc text, shift text,
          kode text, wo text, lokasi text, start_bd text, mekanik_datang text,
          rfu text, operator_datang text, durasi numeric, hm_start numeric,
          hm_rfu_mek numeric, hm_rfu_opt numeric, gl_plant text, mekanik text,
          action text, id_lastupdate text
        ) ON COMMIT DROP
    """))
    await db.execute(
        text(f"INSERT INTO ewacs_import_stage ({cols}) VALUES ({named})"), values)

    key_match = ("e.tanggal = s.tanggal AND e.cn = s.cn AND e.kode = s.kode "
                 "AND COALESCE(e.shift,'') = COALESCE(s.shift,'') "
                 "AND COALESCE(e.start_bd,'') = COALESCE(s.start_bd,'')")

    # 1) Buang baris basi di dalam scope file (tanggal+cn ada di CSV, key tidak).
    deleted = await db.execute(text(f"""
        DELETE FROM ewacs_breakdown e
        WHERE EXISTS (
                SELECT 1 FROM ewacs_import_stage s
                WHERE s.tanggal = e.tanggal AND s.cn = e.cn
              )
          AND NOT EXISTS (
                SELECT 1 FROM ewacs_import_stage s
                WHERE {key_match}
              )
    """))

    # 2) UPDATE baris yang key-nya sudah ada.
    updated = await db.execute(text(f"""
        UPDATE ewacs_breakdown e SET
          crew            = s.crew,
          egi             = s.egi,
          trouble_desc    = s.trouble_desc,
          wo              = s.wo,
          lokasi          = s.lokasi,
          mekanik_datang  = s.mekanik_datang,
          rfu             = s.rfu,
          operator_datang = s.operator_datang,
          durasi          = s.durasi,
          hm_start        = s.hm_start,
          hm_rfu_mek      = s.hm_rfu_mek,
          hm_rfu_opt      = s.hm_rfu_opt,
          gl_plant        = s.gl_plant,
          mekanik         = s.mekanik,
          action          = s.action,
          id_lastupdate   = s.id_lastupdate,
          imported_at     = now()
        FROM ewacs_import_stage s
        WHERE {key_match}
    """))

    # 3) INSERT baris yang benar-benar baru.
    inserted = await db.execute(text(f"""
        INSERT INTO ewacs_breakdown ({cols})
        SELECT {cols} FROM ewacs_import_stage s
        WHERE NOT EXISTS (
                SELECT 1 FROM ewacs_breakdown e
                WHERE {key_match}
              )
    """))

    await db.commit()
    n_updated = updated.rowcount or 0
    n_inserted = inserted.rowcount or 0
    n_deleted = deleted.rowcount or 0
    log.info("ewacs import: %d updated, %d inserted, %d deleted, %d skipped, %d dup by %s",
             n_updated, n_inserted, n_deleted, skip, duplicates, user["username"])
    return {
        "inserted": n_inserted,
        "updated": n_updated,
        "deleted": n_deleted,
        "skipped": skip,
        "duplicates": duplicates,
        "total_rows": len(rows),
    }


@router.get("/filters")
async def get_filters(
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Ambil unique values untuk dropdown filter (EGI, Crew, CN)."""
    egis = (await db.execute(text(
        "SELECT DISTINCT egi FROM ewacs_breakdown WHERE egi IS NOT NULL ORDER BY egi"
    ))).fetchall()
    crews = (await db.execute(text(
        "SELECT DISTINCT crew FROM ewacs_breakdown WHERE crew IS NOT NULL ORDER BY crew"
    ))).fetchall()
    cns = (await db.execute(text(
        "SELECT DISTINCT cn FROM ewacs_breakdown ORDER BY cn"
    ))).fetchall()
    return {
        "egi": [r[0] for r in egis],
        "crew": [r[0] for r in crews],
        "cn": [r[0] for r in cns],
    }


def _where(
    start: date | None,
    end: date | None,
    egi: str | None,
    crew: str | None,
    cn: str | None,
) -> tuple[list[str], dict]:
    parts: list[str] = []
    params: dict = {}
    if start:
        parts.append("tanggal >= :start")
        params["start"] = start
    if end:
        parts.append("tanggal <= :end")
        params["end"] = end
    if egi:
        parts.append("egi = :egi")
        params["egi"] = egi
    if crew:
        parts.append("crew = :crew")
        params["crew"] = crew
    if cn:
        parts.append("cn = :cn")
        params["cn"] = cn
    clause = " AND ".join(parts) if parts else "TRUE"
    return parts, params, clause


@router.get("/kpi")
async def get_kpi(
    start: date | None = Query(None),
    end: date | None = Query(None),
    egi: str | None = Query(None),
    crew: str | None = Query(None),
    cn: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """KPI: Physical Availability %, Total SCM/USM durasi, Ratio %."""
    _, params, clause = _where(start, end, egi, crew, cn)
    rows = (await db.execute(text(f"""
        SELECT
          COALESCE(SUM(CASE WHEN kode='SCM' THEN durasi ELSE 0 END),0) AS scm_dur,
          COALESCE(SUM(CASE WHEN kode='USM' THEN durasi ELSE 0 END),0) AS usm_dur,
          COUNT(DISTINCT cn) AS unit_count,
          COUNT(DISTINCT tanggal) AS day_count
        FROM ewacs_breakdown
        WHERE {clause}
    """), params)).mappings().first()
    if not rows:
        return {"pa": 0, "scm_dur": 0, "usm_dur": 0, "scm_pct": 0, "usm_pct": 0, "unit_count": 0, "day_count": 0}
    scm_dur = float(rows["scm_dur"] or 0)
    usm_dur = float(rows["usm_dur"] or 0)
    total_downtime = scm_dur + usm_dur
    total_avail_hours = (rows["day_count"] or 1) * (rows["unit_count"] or 1) * 24
    pa = ((total_avail_hours - total_downtime) / total_avail_hours * 100) if total_avail_hours else 0
    scm_pct = (scm_dur / total_downtime * 100) if total_downtime else 0
    usm_pct = (usm_dur / total_downtime * 100) if total_downtime else 0
    return {
        "pa": round(pa, 2),
        "scm_dur": round(scm_dur, 2),
        "usm_dur": round(usm_dur, 2),
        "scm_pct": round(scm_pct, 2),
        "usm_pct": round(usm_pct, 2),
        "unit_count": rows["unit_count"],
        "day_count": rows["day_count"],
        "total_downtime": round(total_downtime, 2),
    }


@router.get("/trend")
async def get_trend(
    start: date | None = Query(None),
    end: date | None = Query(None),
    egi: str | None = Query(None),
    crew: str | None = Query(None),
    cn: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Tren per tanggal: PA %, SCM durasi, USM durasi."""
    _, params, clause = _where(start, end, egi, crew, cn)
    rows = (await db.execute(text(f"""
        WITH daily AS (
          SELECT
            tanggal,
            COALESCE(SUM(CASE WHEN kode='SCM' THEN durasi ELSE 0 END),0) AS scm_dur,
            COALESCE(SUM(CASE WHEN kode='USM' THEN durasi ELSE 0 END),0) AS usm_dur,
            COUNT(DISTINCT cn) AS unit_count
          FROM ewacs_breakdown
          WHERE {clause}
          GROUP BY tanggal
        )
        SELECT tanggal,
               scm_dur,
               usm_dur,
               CASE WHEN unit_count > 0
                 THEN ROUND((1.0 - (scm_dur + usm_dur) / (unit_count * 24.0)) * 100, 2)
                 ELSE 0 END AS pa
        FROM daily
        ORDER BY tanggal
    """), params)).fetchall()
    return [
        {
            "tanggal": str(r[0]),
            "scm_dur": float(r[1]),
            "usm_dur": float(r[2]),
            "pa": float(r[3]),
        }
        for r in rows
    ]


@router.get("/detail")
async def get_detail(
    start: date | None = Query(None),
    end: date | None = Query(None),
    egi: str | None = Query(None),
    crew: str | None = Query(None),
    cn: str | None = Query(None),
    kode: str | None = Query(None),
    limit: int = Query(100, le=500),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Tabel detail breakdown dengan filter."""
    parts, params, clause = _where(start, end, egi, crew, cn)
    if kode:
        parts.append("kode = :kode")
        params["kode"] = kode
        clause = " AND ".join(parts) if parts else "TRUE"
    params["limit"] = limit
    params["offset"] = offset
    rows = (await db.execute(text(f"""
        SELECT id, tanggal, crew, cn, egi, trouble_desc, shift, kode, wo, lokasi,
               start_bd, mekanik_datang, rfu, operator_datang, durasi,
               hm_start, hm_rfu_mek, hm_rfu_opt, gl_plant, mekanik, action, id_lastupdate
        FROM ewacs_breakdown
        WHERE {clause}
        ORDER BY tanggal DESC, cn
        LIMIT :limit OFFSET :offset
    """), params)).mappings().all()
    return [dict(r) for r in rows]


@router.delete("/all", dependencies=[Depends(require_role("admin"))])
async def clear_all(
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Hapus semua data ewacs (re-import)."""
    result = await db.execute(text("DELETE FROM ewacs_breakdown"))
    await db.commit()
    return {"deleted": result.rowcount}