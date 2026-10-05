from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/equipment", tags=["equipment"])

WRITABLE = (
    "category", "unit_model", "unit_type", "unit_product", "cn_serial_no",
    "cn_year", "cn_lokasi", "status", "operasional", "pump_group",
    "engine_model", "engine_merk", "engine_serial_no",
    "arrived_date", "arrived_year", "arrived_month", "arrived_hm",
    "lokasi", "remark", "offhire", "aktif",
)
CATEGORIES = ("BIGWHEEL", "LIGHTING", "MOBILE", "PUMPING")


@router.get("")
async def list_equipment(
    search: str | None = None,
    category: str | None = None,
    prefix: str | None = Query(None, min_length=2, max_length=2),
    aktif: bool | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    conds, p = [], {"lim": page_size, "off": (page - 1) * page_size}
    if search:
        conds.append("(cn ILIKE :s OR unit_type ILIKE :s OR unit_product ILIKE :s OR unit_model ILIKE :s)")
        p["s"] = f"%{search.upper()}%"
    if category:
        if category.upper() not in CATEGORIES:
            raise HTTPException(400, f"category harus salah satu {CATEGORIES}")
        conds.append("category = :cat")
        p["cat"] = category.upper()
    if prefix:
        conds.append("cn_prefix = UPPER(:pfx)")
        p["pfx"] = prefix
    if aktif is not None:
        conds.append("aktif = :akt")
        p["akt"] = aktif
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    total = (await db.execute(text(f"SELECT count(*) FROM equipment {where}"), p)).scalar()
    rows = (await db.execute(text(
        f"SELECT * FROM equipment {where} ORDER BY cn LIMIT :lim OFFSET :off"), p)
    ).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "data": [dict(r) for r in rows]}


@router.get("/{cn}")
async def detail_equipment(cn: str, db: AsyncSession = Depends(get_db),
                           user=Depends(get_current_user)):
    row = (await db.execute(text("SELECT * FROM equipment WHERE cn=UPPER(:c)"),
                            {"c": cn})).mappings().first()
    if not row:
        raise HTTPException(404, "cn tidak ditemukan")
    return dict(row)


@router.post("", dependencies=[Depends(require_role("operator", "admin"))], status_code=201)
async def create_equipment(body: dict, db: AsyncSession = Depends(get_db),
                           user=Depends(get_current_user)):
    cn = (body.get("cn") or "").strip().upper()
    if not cn:
        raise HTTPException(400, "cn wajib diisi")
    cat = (body.get("category") or "").strip().upper()
    if cat not in CATEGORIES:
        raise HTTPException(400, f"category harus salah satu {CATEGORIES}")
    exists = (await db.execute(text("SELECT 1 FROM equipment WHERE cn=:c"),
                               {"c": cn})).scalar()
    if exists:
        raise HTTPException(409, f"{cn} sudah ada, gunakan ubah")
    import json as _json
    cols, params = ["cn", "category"], {"cn": cn, "cat": cat}
    for f in WRITABLE[1:]:
        if f in body and body[f] is not None:
            cols.append(f)
            params[f] = body[f]
    if "specs" in body and isinstance(body["specs"], dict):
        cols.append("specs")
        params["specs"] = _json.dumps(body["specs"])
    await db.execute(
        text(f"INSERT INTO equipment({', '.join(cols)}) "
             f"VALUES ({', '.join(':' + c if c != 'category' else ':cat' for c in cols)})"),
        params)
    await db.commit()
    row = (await db.execute(text("SELECT * FROM equipment WHERE cn=:c"),
                            {"c": cn})).mappings().first()
    return dict(row)


@router.patch("/{cn}", dependencies=[Depends(require_role("operator", "admin"))])
async def update_equipment(cn: str, body: dict, db: AsyncSession = Depends(get_db),
                           user=Depends(get_current_user)):
    import json as _json
    sets, params = [], {"c": cn.upper()}
    for f in WRITABLE:
        if f in body:
            if f == "category" and body[f] is not None \
                    and str(body[f]).upper() not in CATEGORIES:
                raise HTTPException(400, f"category harus salah satu {CATEGORIES}")
            sets.append(f"{f}=:{f}")
            v = body[f]
            params[f] = str(v).upper() if f == "category" and v is not None else v
    if "specs" in body:
        if body["specs"] is not None and not isinstance(body["specs"], dict):
            raise HTTPException(400, "specs harus objek")
        sets.append("specs=:specs")
        params["specs"] = _json.dumps(body["specs"]) if body["specs"] is not None else None
    if not sets:
        raise HTTPException(400, "tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE equipment SET {', '.join(sets)} WHERE cn=:c"), params)
    if res.rowcount == 0:
        raise HTTPException(404, "cn tidak ditemukan")
    await db.commit()
    row = (await db.execute(text("SELECT * FROM equipment WHERE cn=:c"),
                            {"c": cn.upper()})).mappings().first()
    return dict(row)
