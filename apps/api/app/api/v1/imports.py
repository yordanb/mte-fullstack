import io
import openpyxl
from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.db.session import get_db
from app.services.excel_map import HEADER_MAP, HEADER_ROW, DATA_START_ROW, SHEET, parse_lab_no, norm_vessel

router = APIRouter(prefix="/v1/imports", tags=["imports"])

def _read_rows(content: bytes):
    wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    if SHEET not in wb.sheetnames:
        raise HTTPException(400, f"Sheet {SHEET} tidak ditemukan, ada: {wb.sheetnames}")
    ws = wb[SHEET]
    header = list(next(ws.iter_rows(min_row=HEADER_ROW, max_row=HEADER_ROW, values_only=True)))
    # buang 2 kolom kosong depan
    idx = {h: i for i, h in enumerate(header) if h}
    unknown = [h for h in idx if h not in HEADER_MAP]
    if unknown:
        raise HTTPException(400, f"Header tak dikenal: {unknown}")
    rows = []
    errors = []
    for rno, r in enumerate(ws.iter_rows(min_row=DATA_START_ROW, values_only=True), start=DATA_START_ROW):
        if all(v is None for v in r):
            continue
        try:
            lab_no = parse_lab_no(r[idx["Lab No"]])
            rows.append({
                "lab_no": lab_no,
                "vesselid": norm_vessel(r[idx["Vesselid"]]),
                "unit_id": (str(r[idx["Unit Id"]]).strip() if r[idx["Unit Id"]] else None),
                "model": r[idx["Model"]],
                "sample_date": r[idx["Sample Date"]],
                "condition": (str(r[idx["Condition"]]).strip().upper() if r[idx["Condition"]] else None),
                "_raw_row": rno,
            })
        except Exception as e:
            errors.append({"row": rno, "error": str(e)})
    return rows, errors

@router.post("")
async def upload_excel(
    file: UploadFile = File(...),
    dry_run: bool = Query(True),
    db: AsyncSession = Depends(get_db),
):
    content = await file.read()
    if len(content) > settings.max_upload_mb * 1024 * 1024:
        raise HTTPException(413, "File terlalu besar")
    rows, errors = _read_rows(content)
    if dry_run:
        return {"total": len(rows) + len(errors), "ok": len(rows), "fail": len(errors),
                "errors": errors[:50], "preview": rows[:5]}
    # commit: upsert kolom inti (full 116 kolom via V1 sql COPY disarankan untuk prod)
    res = await db.execute(text(
        "INSERT INTO imports(filename,status,total_rows,ok_rows,fail_rows) "
        "VALUES (:fn,'COMMITTED',:t,:o,:f) RETURNING id"),
        {"fn": file.filename, "t": len(rows) + len(errors), "o": len(rows), "f": len(errors)})
    import_id = res.scalar_one()
    for r in rows:
        await db.execute(text("""
            INSERT INTO oil_lab_result(lab_no, vesselid, unit_id, model, sample_date, "condition", import_id)
            VALUES (:lab_no,:vesselid,:unit_id,:model,:sample_date,:condition,:import_id)
            ON CONFLICT (lab_no) DO UPDATE SET
              vesselid=EXCLUDED.vesselid, unit_id=EXCLUDED.unit_id,
              sample_date=EXCLUDED.sample_date, "condition"=EXCLUDED.condition,
              import_id=EXCLUDED.import_id
        """), {**r, "import_id": import_id})
    await db.commit()
    await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_latest_status"))
    await db.commit()
    return {"import_id": str(import_id), "ok": len(rows), "fail": len(errors), "errors": errors[:50]}
