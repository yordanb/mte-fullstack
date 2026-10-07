import io
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from app.services.fui_pdf import build_fui_pdf
from app.services.pama_pdf import build_pama_pdf

router = APIRouter(prefix="/v1/fui", tags=["fui"])


@router.get("/report.pdf", dependencies=[Depends(require_role("viewer", "inputer", "admin"))])
async def report(cn: str = Query(..., min_length=2),
                 db: AsyncSession = Depends(get_db),
                 user=Depends(get_current_user)):
    v = cn.strip().upper()
    eq = (await db.execute(text("SELECT * FROM equipment WHERE cn=:c"),
                           {"c": v})).mappings().first()
    dbr = (await db.execute(text(
        "SELECT * FROM dbr_records WHERE cn=:c AND code='USM' "
        "AND (action IS NULL OR UPPER(action) != 'CONTINUE') "
        "ORDER BY date DESC LIMIT 10"), {"c": v})).mappings().all()
    units = (await db.execute(text(
        "SELECT DISTINCT unit_id FROM oil_lab_result "
        "WHERE vesselid=:v AND unit_id IS NOT NULL AND TRIM(unit_id) <> '' "
        "ORDER BY unit_id"), {"v": v})).scalars().all()
    oil = []
    for u in units:
        rows = (await db.execute(text(
            "SELECT lab_no, vesselid, unit_id, sample_date, oil_weight, "
            "unit_time, unit_time_oils, visc, fuel, soot, oxi, nitr, water, tbn, "
            "si, fe, cu, al, cr, pb, na, "
            "grade_visc, grade_fuel, grade_soot, grade_oxi, grade_nitr, "
            "grade_water, grade_tbn, grade_si, grade_fe, grade_cu, "
            "grade_al, grade_cr, grade_pb, grade_na, "
            "\"condition\" FROM oil_lab_result "
            "WHERE vesselid=:v AND unit_id=:u "
            "ORDER BY sample_date DESC, lab_no DESC LIMIT 10"),
            {"v": v, "u": u})).mappings().all()
        if rows:
            oil.append((u, [dict(r) for r in rows]))
    pdf = build_fui_pdf(dict(eq) if eq else None,
                         [dict(r) for r in dbr], oil, v)
    return StreamingResponse(io.BytesIO(pdf), media_type="application/pdf",
                             headers={"Content-Disposition":
                                      f'attachment; filename="FUI-{v}.pdf"'})


OIL_WIDE = ("lab_no, vesselid, unit_id, district, sample_date, date_taken, oil_weight, "
            "unit_time, unit_time_oils, visc, fuel, soot, oxi, nitr, water, tbn, "
            "si, fe, cu, al, cr, pb, na, english_description, "
            "grade_visc, grade_fuel, grade_soot, grade_oxi, grade_nitr, "
            "grade_water, grade_tbn, grade_si, grade_fe, grade_cu, "
            "grade_al, grade_cr, grade_pb, grade_na, "
            "n_visc, n_fuel, n_soot, n_oxi, n_nitr, n_water, n_tbn, "
            "n_si, n_fe, n_cu, n_al, n_cr, n_pb, n_na, "
            "n_visc_max, n_fuel_max, n_soot_max, n_oxi_max, n_nitr_max, "
            "n_water_max, n_tbn_max, n_si_max, n_fe_max, n_cu_max, "
            "n_al_max, n_cr_max, n_pb_max, n_na_max, \"condition\"")


@router.get("/pama.pdf", dependencies=[Depends(require_role("viewer", "inputer", "admin"))])
async def pama(cn: str = Query(..., min_length=2),
               db: AsyncSession = Depends(get_db),
               user=Depends(get_current_user)):
    """Laporan gaya vendor PAMA per component + tabel kerusakan dari DBR."""
    v = cn.strip().upper()
    units = (await db.execute(text(
        "SELECT DISTINCT unit_id FROM oil_lab_result "
        "WHERE vesselid=:v AND unit_id IS NOT NULL AND TRIM(unit_id) <> '' "
        "ORDER BY unit_id"), {"v": v})).scalars().all()
    oil = []
    for u in units:
        rows = (await db.execute(text(
            f"SELECT {OIL_WIDE} FROM oil_lab_result "
            "WHERE vesselid=:v AND unit_id=:u "
            "ORDER BY sample_date DESC, lab_no DESC LIMIT 10"),
            {"v": v, "u": u})).mappings().all()
        clean = []
        for r in rows:
            d = dict(r)
            try:
                if d.get("date_taken") and d.get("sample_date"):
                    d["lead_time"] = (d["date_taken"] - d["sample_date"]).days
            except Exception:
                pass
            clean.append(d)
        if clean:
            oil.append((u, clean))
    dbr = (await db.execute(text(
        "SELECT * FROM dbr_records WHERE cn=:c AND code='USM' "
        "AND (action IS NULL OR UPPER(action) != 'CONTINUE') "
        "ORDER BY date DESC LIMIT 1"), {"c": v})).mappings().first()
    pdf = build_pama_pdf(None, oil, dict(dbr) if dbr else None, v)
    return StreamingResponse(io.BytesIO(pdf), media_type="application/pdf",
                             headers={"Content-Disposition":
                                      f'attachment; filename="PAMA-{v}.pdf"'})


SUG_COLS = ("r.lab_no, r.vesselid, r.unit_id, r.model, r.sample_date, r.date_taken, "
            "ROUND(EXTRACT(EPOCH FROM (r.date_taken - r.sample_date)) / 86400, 1) AS lead_time, "
            "r.oil_weight, r.unit_time, r.unit_time_oils, "
            "r.visc, r.fuel, r.soot, r.oxi, r.nitr, r.water, r.tbn, "
            "r.si, r.fe, r.cu, r.al, r.cr, r.pb, r.na, "
            "r.grade_visc, r.grade_fuel, r.grade_soot, r.grade_oxi, r.grade_nitr, "
            "r.grade_water, r.grade_tbn, r.grade_si, r.grade_fe, r.grade_cu, "
            "r.grade_al, r.grade_cr, r.grade_pb, r.grade_na, "
            "r.\"condition\", r.english_description, "
            "e.unit_type, e.unit_product")


@router.get("/suggestions", dependencies=[Depends(require_role("viewer", "inputer", "admin"))])
async def suggestions(category: str = Query(..., min_length=3),
                      db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    """Unit aktif 1 kategori yang sample terakhirnya non-NORMAL + 3 oil terakhirnya."""
    if category.upper() not in ("BIGWHEEL", "LIGHTING", "MOBILE", "PUMPING"):
        raise HTTPException(400, "category harus BIGWHEEL/LIGHTING/MOBILE/PUMPING")
    rows = (await db.execute(text(
        f"SELECT {SUG_COLS} FROM ("
        "SELECT o.*, ROW_NUMBER() OVER (PARTITION BY o.vesselid, o.unit_id "
        "ORDER BY o.sample_date DESC, o.lab_no DESC) AS rn "
        "FROM oil_lab_result o "
        "JOIN equipment e ON e.cn = o.vesselid "
        "WHERE e.category=:cat AND e.aktif) r "
        "JOIN equipment e ON e.cn = r.vesselid "
        "JOIN (SELECT vesselid, unit_id FROM ("
        "SELECT o.vesselid, o.unit_id, ROW_NUMBER() OVER (PARTITION BY o.vesselid, o.unit_id "
        "ORDER BY o.sample_date DESC, o.lab_no DESC) AS rn, o.\"condition\" "
        "FROM oil_lab_result o "
        "JOIN equipment e ON e.cn = o.vesselid "
        "WHERE e.category=:cat AND e.aktif) t "
        "WHERE rn = 1 AND \"condition\" IS DISTINCT FROM 'NORMAL') l "
        "USING (vesselid, unit_id) "
        "WHERE r.rn <= 3 "
        "ORDER BY r.vesselid, r.unit_id, r.sample_date DESC LIMIT 600"),
        {"cat": category.upper()})).mappings().all()
    return {"category": category.upper(), "data": [dict(r) for r in rows]}
