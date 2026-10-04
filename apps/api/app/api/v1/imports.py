import io
import openpyxl
from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from app.services.excel_map import HEADER_MAP, HEADER_ROW, DATA_START_ROW, SHEET, coerce

router = APIRouter(prefix="/v1/imports", tags=["imports"])

ALL_COLS = list(HEADER_MAP.values())  # 116 kolom, urutan sesuai HEADER_MAP

def _read_full(content: bytes):
    wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    if SHEET not in wb.sheetnames:
        raise HTTPException(400, f"Sheet {SHEET} tidak ditemukan, ada: {wb.sheetnames}")
    ws = wb[SHEET]
    header = list(next(ws.iter_rows(min_row=HEADER_ROW, max_row=HEADER_ROW, values_only=True)))
    idx = {h: i for i, h in enumerate(header) if h}
    unknown = [h for h in idx if h not in HEADER_MAP]
    if unknown:
        raise HTTPException(400, f"Header tak dikenal: {unknown}")
    missing = [h for h in HEADER_MAP if h not in idx]
    if missing:
        raise HTTPException(400, f"Header hilang: {missing}")
    rows, errors = [], []
    for rno, r in enumerate(ws.iter_rows(min_row=DATA_START_ROW, values_only=True), start=DATA_START_ROW):
        if all(v is None for v in r):
            continue
        try:
            clean = {col: coerce(col, r[idx[h]]) for h, col in HEADER_MAP.items()}
            if clean["lab_no"] is None:
                raise ValueError("Lab No kosong")
            rows.append(clean)
        except Exception as e:
            errors.append({"row": rno, "error": str(e)})
    return rows, errors

UPSERT_SQL = None

def _upsert_sql() -> str:
    global UPSERT_SQL
    if UPSERT_SQL:
        return UPSERT_SQL
    cols = ALL_COLS + ["import_id"]
    col_list = ", ".join([f'"{c}"' if c == "condition" else c for c in cols])
    val_list = ", ".join(f":{c}" for c in cols)
    sets = ", ".join(
        f'"{c}"=EXCLUDED."{c}"' if c == "condition" else f"{c}=EXCLUDED.{c}"
        for c in cols if c not in ("lab_no",))
    UPSERT_SQL = (f"INSERT INTO oil_lab_result({col_list}) VALUES ({val_list}) "
                  f"ON CONFLICT (lab_no) DO UPDATE SET {sets}")
    return UPSERT_SQL

@router.post("", dependencies=[Depends(require_role("operator", "admin"))])
async def upload_excel(
    file: UploadFile = File(...),
    dry_run: bool = Query(True),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    content = await file.read()
    if len(content) > settings.max_upload_mb * 1024 * 1024:
        raise HTTPException(413, "File terlalu besar")
    rows, errors = _read_full(content)
    if dry_run:
        return {"total": len(rows) + len(errors), "ok": len(rows), "fail": len(errors),
                "errors": errors[:50],
                "preview": [{k: rows[0][k] for k in ("lab_no", "vesselid", "unit_id", "sample_date", "condition")} ] if rows else []}
    res = await db.execute(text(
        "INSERT INTO imports(filename,status,total_rows,ok_rows,fail_rows,uploaded_by) "
        "VALUES (:fn,'COMMITTED',:t,:o,:f,:u) RETURNING id"),
        {"fn": file.filename, "t": len(rows) + len(errors),
         "o": len(rows), "f": len(errors), "u": user["username"]})
    import_id = res.scalar_one()
    sql = _upsert_sql()
    for r in rows:
        await db.execute(text(sql), {**r, "import_id": import_id})
    await db.commit()
    try:
        await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_latest_status"))
    except Exception:
        await db.rollback()
        await db.execute(text("REFRESH MATERIALIZED VIEW mv_latest_status"))
    await db.commit()
    return {"import_id": str(import_id), "ok": len(rows), "fail": len(errors), "errors": errors[:50]}
