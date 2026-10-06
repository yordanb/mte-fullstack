import datetime
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, Request, UploadFile, File, Form, Query, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/activities", tags=["activities"])


def _dir() -> Path:
    p = Path(settings.upload_dir) / "activities"
    p.mkdir(parents=True, exist_ok=True)
    return p


@router.get("/month")
async def month_counts(year: int = Query(..., ge=2000, le=2100),
                       month: int = Query(..., ge=1, le=12),
                       crew: str | None = None,
                       category: str | None = None,
                       db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    """Jumlah aktivitas per tanggal dalam sebulan (untuk dot kalender)."""
    conds, p = ["date_trunc('month', date) = make_date(:y, :m, 1)"], {"y": year, "m": month}
    if crew:
        conds.append("crew ILIKE :cw"); p["cw"] = f"%{crew}%"
    if category:
        conds.append("category ILIKE :ct"); p["ct"] = f"%{category}%"
    rows = (await db.execute(text(
        f"SELECT date::text AS d, count(*) AS n FROM activities "
        f"WHERE {' AND '.join(conds)} GROUP BY 1"), p)).mappings().all()
    return {"counts": {r["d"]: r["n"] for r in rows}}


@router.get("/recap")
async def recap(year: int = Query(..., ge=2000, le=2100),
                month: int = Query(..., ge=1, le=12),
                crew: str | None = None,
                category: str | None = None,
                db: AsyncSession = Depends(get_db),
                user=Depends(get_current_user)):
    """Rekap semua aktivitas sebulan + filter crew/kategori."""
    conds, p = ["date_trunc('month', date) = make_date(:y, :m, 1)"], {"y": year, "m": month}
    if crew:
        conds.append("crew ILIKE :cw"); p["cw"] = f"%{crew}%"
    if category:
        conds.append("category ILIKE :ct"); p["ct"] = f"%{category}%"
    rows = (await db.execute(text(
        f"SELECT a.*, (SELECT count(*) FROM activity_photos x WHERE x.activity_id=a.id) AS photos_count "
        f"FROM activities a WHERE {' AND '.join(conds)} "
        f"ORDER BY a.date DESC, a.created_at LIMIT 500"), p)).mappings().all()
    return {"data": [dict(r) for r in rows]}


@router.get("")
async def by_date(date: datetime.date,
                  db: AsyncSession = Depends(get_db),
                  user=Depends(get_current_user)):
    """Daftar aktivitas 1 tanggal + jumlah foto + cover."""
    rows = (await db.execute(text(
        "SELECT a.*, (SELECT count(*) FROM activity_photos p WHERE p.activity_id=a.id) AS photos, "
        "(SELECT p.id::text FROM activity_photos p WHERE p.activity_id=a.id "
        " ORDER BY p.created_at LIMIT 1) AS cover_id "
        "FROM activities a WHERE a.date=:d ORDER BY a.created_at"), {"d": date})
    ).mappings().all()
    return {"date": str(date), "data": [dict(r) for r in rows]}


@router.get("/{aid}")
async def detail(aid: str, db: AsyncSession = Depends(get_db),
                 user=Depends(get_current_user)):
    row = (await db.execute(text("SELECT * FROM activities WHERE id=:i"), {"i": aid})
           ).mappings().first()
    if not row:
        raise HTTPException(404, "aktivitas tidak ditemukan")
    photos = (await db.execute(text(
        "SELECT id, orig_name, content_type, size, created_at FROM activity_photos "
        "WHERE activity_id=:i ORDER BY created_at"), {"i": aid})).mappings().all()
    out = dict(row)
    out["photos"] = [{**dict(p), "id": str(p["id"])} for p in photos]
    return out


@router.post("", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create(date: datetime.date = Form(...),
                 title: str = Form(...),
                 description: str | None = Form(None),
                 category: str | None = Form(None),
                 crew: str | None = Form(None),
                 cn: str | None = Form(None),
                 files: list[UploadFile] = File(default=[]),
                 db: AsyncSession = Depends(get_db),
                 user=Depends(get_current_user)):
    title = title.strip()
    if not title:
        raise HTTPException(400, "judul wajib diisi")
    crew = (crew or "").strip() or None
    if not crew:
        raise HTTPException(400, "crew wajib diisi")
    cn = (cn or "").strip().upper() or None
    if cn:
        ok = (await db.execute(text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": cn})).scalar()
        if not ok:
            raise HTTPException(400, f"CN {cn} tidak ada di master equipment")
    res = await db.execute(text(
        "INSERT INTO activities(date,title,description,category,crew,cn,created_by) "
        "VALUES (:d,:t,:desc,:cat,:cw,:cn,:u) RETURNING id"),
        {"d": date, "t": title, "desc": description, "cat": (category or "").strip() or None,
         "cw": crew, "cn": cn, "u": user["username"]})
    aid = str(res.scalar_one())
    adir = _dir() / aid
    adir.mkdir(parents=True, exist_ok=True)
    for f in files:
        if not f.filename:
            continue
        ext = Path(f.filename).suffix[:10]
        stored = f"{uuid.uuid4().hex}{ext}"
        dest = adir / stored
        size = 0
        with dest.open("wb") as out:
            while True:
                chunk = await f.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                out.write(chunk)
        await db.execute(text(
            "INSERT INTO activity_photos(activity_id,filename,orig_name,content_type,size) "
            "VALUES (:a,:fn,:on,:ct,:s)"),
            {"a": aid, "fn": stored, "on": f.filename[:200],
             "ct": f.content_type, "s": size})
    await db.commit()
    return {"id": aid}


@router.patch("/{aid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def update(aid: str, body: dict, db: AsyncSession = Depends(get_db),
                 user=Depends(get_current_user)):
    allowed = ("date", "title", "description", "category", "crew", "cn")
    sets, params = [], {"i": aid}
    for k in allowed:
        if k in body:
            if k == "title" and not (body[k] or "").strip():
                raise HTTPException(400, "judul wajib diisi")
            if k == "cn":
                v = (body[k] or "").strip().upper() or None
                if v and not (await db.execute(
                        text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": v})).scalar():
                    raise HTTPException(400, f"CN {v} tidak ada di master equipment")
                params[k] = v
            elif k == "date":
                # JSON selalu string: parse eksplisit (asyncpg tak terima str untuk kolom DATE).
                try:
                    params[k] = datetime.date.fromisoformat(str(body[k])[:10])
                except (ValueError, TypeError):
                    raise HTTPException(400, "format tanggal salah (YYYY-MM-DD)")
            else:
                params[k] = body[k]
            sets.append(f"{k}=:{k}")
    if not sets:
        raise HTTPException(400, "tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE activities SET {', '.join(sets)} WHERE id=:i"), params)
    if res.rowcount == 0:
        raise HTTPException(404, "aktivitas tidak ditemukan")
    await db.commit()
    return {"id": aid}


@router.delete("/{aid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def remove(aid: str, db: AsyncSession = Depends(get_db),
                 user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM activities WHERE id=:i"), {"i": aid})
    if res.rowcount == 0:
        raise HTTPException(404, "aktivitas tidak ditemukan")
    await db.commit()
    import shutil
    shutil.rmtree(_dir() / aid, ignore_errors=True)
    return {"ok": True}


@router.delete("/{aid}/photos/{pid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def remove_photo(aid: str, pid: str, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    row = (await db.execute(text(
        "SELECT filename FROM activity_photos WHERE id=:p AND activity_id=:a"),
        {"p": pid, "a": aid})).mappings().first()
    if not row:
        raise HTTPException(404, "foto tidak ditemukan")
    await db.execute(text("DELETE FROM activity_photos WHERE id=:p"), {"p": pid})
    await db.commit()
    try:
        (_dir() / aid / row["filename"]).unlink(missing_ok=True)
    except OSError:
        pass
    return {"ok": True}


@router.get("/{aid}/photos/{pid}")
async def photo(aid: str, pid: str, token: str | None = None,
                request: Request = None,  # diisi FastAPI
                db: AsyncSession = Depends(get_db)):
    # <img> tak bisa kirim header Authorization: terima ?token= juga.
    from app.core.security import decode_token
    tok = token
    if not tok and request is not None:
        auth = request.headers.get("authorization", "")
        if auth.lower().startswith("bearer "):
            tok = auth[7:]
    if not tok:
        raise HTTPException(401, "Butuh login")
    try:
        payload = decode_token(tok)
    except Exception:
        raise HTTPException(401, "Token tidak valid")
    ok = (await db.execute(text("SELECT 1 FROM users WHERE id::text=:s"),
                           {"s": payload.get("sub")})).scalar()
    if not ok:
        raise HTTPException(401, "User tidak ada")
    row = (await db.execute(text(
        "SELECT filename, content_type, orig_name FROM activity_photos "
        "WHERE id=:p AND activity_id=:a"), {"p": pid, "a": aid})).mappings().first()
    if not row:
        raise HTTPException(404, "foto tidak ditemukan")
    path = _dir() / aid / row["filename"]
    if not path.is_file():
        raise HTTPException(404, "file hilang di server")
    return FileResponse(path, media_type=row["content_type"] or "image/jpeg",
                        filename=row["orig_name"] or row["filename"])
