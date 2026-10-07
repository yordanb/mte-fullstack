import io
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from app.services.fui_pdf import build_fui_pdf

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
