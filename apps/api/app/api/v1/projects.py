import datetime
import uuid
from pathlib import Path
from fastapi import APIRouter, Depends, Request, UploadFile, File, Form, Query, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/projects", tags=["projects"])

STATUSES = ("BELUM_MULAI", "ON_TRACK", "AT_RISK", "TERLAMBAT", "SELESAI")


def _pdir() -> Path:
    p = Path(settings.upload_dir) / "project_updates"
    p.mkdir(parents=True, exist_ok=True)
    return p


def _derive_stage(latest: dict | None, plan_end) -> str:
    if not latest:
        return "BELUM_MULAI"
    if latest.get("status") == "SELESAI":
        return "SELESAI"
    if plan_end and datetime.date.today() > plan_end:
        return "TERLAMBAT"
    return latest.get("status") or "ON_TRACK"


def _derive_project(stages: list) -> tuple[int, str]:
    if not stages:
        return 0, "BELUM_MULAI"
    ws = [(s.get("weight") or 0) for s in stages]
    if sum(ws) > 0:
        prog = round(sum(s.get("progress", 0) * w for s, w in zip(stages, ws)) / sum(ws))
    else:
        prog = round(sum(s.get("progress", 0) for s in stages) / len(stages))
    ds = [s["derived"] for s in stages]
    if all(d == "SELESAI" for d in ds):
        st = "SELESAI"
    elif any(d == "TERLAMBAT" for d in ds):
        st = "TERLAMBAT"
    elif any(d == "AT_RISK" for d in ds):
        st = "AT_RISK"
    elif any(d in ("ON_TRACK", "SELESAI") for d in ds):
        st = "ON_TRACK"
    else:
        st = "BELUM_MULAI"
    return prog, st


async def _stages(db: AsyncSession, pid: str) -> list:
    rows = (await db.execute(text(
        "SELECT * FROM project_stages WHERE project_id=:p ORDER BY sort, created_at"),
        {"p": pid})).mappings().all()
    out = []
    for s in rows:
        s = dict(s)
        if isinstance(s.get("plan_end"), str):
            s["plan_end"] = datetime.date.fromisoformat(s["plan_end"][:10])
        ups = (await db.execute(text(
            "SELECT u.*, (SELECT count(*) FROM project_photos x WHERE x.update_id=u.id) AS photos "
            "FROM project_updates u WHERE u.stage_id=:s "
            "ORDER BY u.date DESC, u.created_at DESC"), {"s": s["id"]})).mappings().all()
        ups = [dict(u) for u in ups]
        for u in ups:
            ph = (await db.execute(text(
                "SELECT id::text AS id, orig_name FROM project_photos "
                "WHERE update_id=:a ORDER BY created_at"), {"a": str(u["id"])})
            ).mappings().all()
            u["id"] = str(u["id"])
            u["photo_list"] = [dict(p) for p in ph]
        latest = ups[0] if ups else None
        s["updates"] = ups
        s["latest"] = latest
        s["progress"] = (latest or {}).get("progress", 0) or 0
        s["derived"] = _derive_stage(latest, s.get("plan_end"))
        out.append(s)
    return out


def _ser_stage(s: dict) -> dict:
    s = dict(s)
    for k in ("plan_start", "plan_end"):
        if s.get(k) and not isinstance(s[k], str):
            s[k] = str(s[k])
    if s.get("latest"):
        s["latest"] = dict(s["latest"])
        for k in ("date", "created_at"):
            if s["latest"].get(k) and not isinstance(s["latest"][k], str):
                s["latest"][k] = str(s["latest"][k])
    for u in s.get("updates", []):
        for k in ("date", "created_at"):
            if u.get(k) and not isinstance(u[k], str):
                u[k] = str(u[k])
    return s


@router.get("")
async def list_projects(search: str | None = None,
                        status: str | None = None,
                        page: int = Query(1, ge=1),
                        page_size: int = Query(20, ge=1, le=100),
                        db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    conds, p = [], {}
    if search:
        conds.append("(name ILIKE :s OR pic ILIKE :s OR cn ILIKE :s)")
        p["s"] = f"%{search}%"
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(
        f"SELECT * FROM projects {where} ORDER BY created_at DESC LIMIT 500"), p)
    ).mappings().all()
    out = []
    for r in rows:
        r = dict(r)
        stages = await _stages(db, str(r["id"]))
        prog, st = _derive_project([{"progress": s["progress"], "derived": s["derived"],
                                     "weight": s.get("weight") or 0} for s in stages])
        r["progress"], r["derived"] = prog, st
        r["nstage"] = len(stages)
        r["id"] = str(r["id"])
        for k in ("target_date", "created_at"):
            if r.get(k) and not isinstance(r[k], str):
                r[k] = str(r[k])
        if status and st != status.upper():
            continue
        out.append(r)
    total = len(out)
    return {"total": total, "page": page, "page_size": page_size,
            "data": out[(page - 1) * page_size:page * page_size]}


class ProjectIn(BaseModel):
    name: str
    description: str | None = None
    pic: str | None = None
    cn: str | None = None
    crew: str | None = None
    target_date: datetime.date | None = None


@router.post("", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create_project(body: ProjectIn, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    if not (body.name or "").strip():
        raise HTTPException(400, "nama project wajib diisi")
    cn = (body.cn or "").strip().upper() or None
    if cn and not (await db.execute(
            text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": cn})).scalar():
        raise HTTPException(400, f"CN {cn} tidak ada di master equipment")
    res = await db.execute(text(
        "INSERT INTO projects(name,description,pic,cn,crew,target_date,created_by) "
        "VALUES (:n,:d,:p,:c,:cw,:t,:u) RETURNING id"),
        {"n": body.name.strip(), "d": body.description,
         "p": (body.pic or "").strip() or None, "cn": cn,
         "cw": (body.crew or "").strip() or None,
         "t": body.target_date, "u": user["username"]})
    await db.commit()
    return {"id": str(res.scalar_one())}


@router.get("/{pid}")
async def detail_project(pid: str, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    r = (await db.execute(text("SELECT * FROM projects WHERE id=:i"),
                          {"i": pid})).mappings().first()
    if not r:
        raise HTTPException(404, "project tidak ditemukan")
    r = dict(r)
    r["id"] = str(r["id"])
    for k in ("target_date", "created_at"):
        if r.get(k) and not isinstance(r[k], str):
            r[k] = str(r[k])
    stages = [_ser_stage(s) for s in await _stages(db, pid)]
    prog, st = _derive_project([{"progress": s["progress"], "derived": s["derived"],
                                 "weight": s.get("weight") or 0} for s in stages])
    r["stages"], r["progress"], r["derived"] = stages, prog, st
    return r


class ProjectPatch(BaseModel):
    name: str | None = None
    description: str | None = None
    pic: str | None = None
    cn: str | None = None
    crew: str | None = None
    target_date: datetime.date | None = None


@router.patch("/{pid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def update_project(pid: str, body: ProjectPatch, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    sets, params = [], {"i": pid}
    d = body.model_dump(exclude_unset=True)
    if "name" in d and not (d["name"] or "").strip():
        raise HTTPException(400, "nama project wajib diisi")
    if "cn" in d:
        v = (d["cn"] or "").strip().upper() or None
        if v and not (await db.execute(
                text("SELECT 1 FROM equipment WHERE cn=:c"), {"c": v})).scalar():
            raise HTTPException(400, f"CN {v} tidak ada di master equipment")
        d["cn"] = v
    for k, v in d.items():
        sets.append(f"{k}=:{k}")
        params[k] = v.strip() if isinstance(v, str) else v
    if not sets:
        raise HTTPException(400, "tidak ada yang diubah")
    res = await db.execute(text(f"UPDATE projects SET {', '.join(sets)} WHERE id=:i"), params)
    if res.rowcount == 0:
        raise HTTPException(404, "project tidak ditemukan")
    await db.commit()
    return {"id": pid}


@router.delete("/{pid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_project(pid: str, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    ups = (await db.execute(text(
        "SELECT u.id FROM project_updates u JOIN project_stages s ON s.id=u.stage_id "
        "WHERE s.project_id=:p"), {"p": pid})).scalars().all()
    res = await db.execute(text("DELETE FROM projects WHERE id=:i"), {"i": pid})
    if res.rowcount == 0:
        raise HTTPException(404, "project tidak ditemukan")
    await db.commit()
    import shutil
    for uid in ups:
        shutil.rmtree(_pdir() / str(uid), ignore_errors=True)
    return {"ok": True}


class StageIn(BaseModel):
    name: str
    plan_start: datetime.date | None = None
    plan_end: datetime.date | None = None
    weight: float = 0
    sort: int = 0


@router.post("/{pid}/stages", dependencies=[Depends(require_role("inputer", "admin"))],
            status_code=201)
async def add_stage(pid: str, body: StageIn, db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    if not (await db.execute(text("SELECT 1 FROM projects WHERE id=:i"),
                             {"i": pid})).scalar():
        raise HTTPException(404, "project tidak ditemukan")
    if not (body.name or "").strip():
        raise HTTPException(400, "nama tahap wajib diisi")
    if body.plan_start and body.plan_end and body.plan_end < body.plan_start:
        raise HTTPException(400, "rencana selesai sebelum mulai")
    res = await db.execute(text(
        "INSERT INTO project_stages(project_id,name,plan_start,plan_end,weight,sort) "
        "VALUES (:p,:n,:s,:e,:w,:o) RETURNING id"),
        {"p": pid, "n": body.name.strip(), "s": body.plan_start,
         "e": body.plan_end, "w": body.weight or 0, "o": body.sort or 0})
    await db.commit()
    return {"id": str(res.scalar_one())}


class StagePatch(BaseModel):
    name: str | None = None
    plan_start: datetime.date | None = None
    plan_end: datetime.date | None = None
    weight: float | None = None
    sort: int | None = None


@router.patch("/stages/{sid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def update_stage(sid: str, body: StagePatch, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    cur = (await db.execute(text("SELECT plan_start, plan_end FROM project_stages WHERE id=:i"),
                            {"i": sid})).mappings().first()
    if not cur:
        raise HTTPException(404, "tahap tidak ditemukan")
    d = body.model_dump(exclude_unset=True)
    ps, pe = d.get("plan_start", cur["plan_start"]), d.get("plan_end", cur["plan_end"])
    if isinstance(ps, str):
        ps = datetime.date.fromisoformat(ps[:10])
    if isinstance(pe, str):
        pe = datetime.date.fromisoformat(pe[:10])
    if ps and pe and pe < ps:
        raise HTTPException(400, "rencana selesai sebelum mulai")
    sets, params = [], {"i": sid}
    for k, v in d.items():
        sets.append(f"{k}=:{k}")
        params[k] = v.strip() if isinstance(v, str) else v
    if not sets:
        raise HTTPException(400, "tidak ada yang diubah")
    await db.execute(text(f"UPDATE project_stages SET {', '.join(sets)} WHERE id=:i"), params)
    await db.commit()
    return {"id": sid}


@router.delete("/stages/{sid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_stage(sid: str, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    ups = (await db.execute(text("SELECT id FROM project_updates WHERE stage_id=:s"),
                            {"s": sid})).scalars().all()
    res = await db.execute(text("DELETE FROM project_stages WHERE id=:i"), {"i": sid})
    if res.rowcount == 0:
        raise HTTPException(404, "tahap tidak ditemukan")
    await db.commit()
    import shutil
    for uid in ups:
        shutil.rmtree(_pdir() / str(uid), ignore_errors=True)
    return {"ok": True}


@router.post("/stages/{sid}/updates",
            dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_update(sid: str,
                     date: datetime.date = Form(...),
                     progress: int = Form(0),
                     status: str = Form("ON_TRACK"),
                     note: str | None = Form(None),
                     files: list[UploadFile] = File(default=[]),
                     db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    if not (await db.execute(text("SELECT 1 FROM project_stages WHERE id=:i"),
                             {"i": sid})).scalar():
        raise HTTPException(404, "tahap tidak ditemukan")
    if status not in STATUSES:
        raise HTTPException(400, f"status harus salah satu {STATUSES}")
    if not 0 <= progress <= 100:
        raise HTTPException(400, "progress 0-100")
    res = await db.execute(text(
        "INSERT INTO project_updates(stage_id,date,progress,status,note,created_by) "
        "VALUES (:s,:d,:p,:st,:n,:u) RETURNING id"),
        {"s": sid, "d": date, "p": progress, "st": status,
         "n": (note or "").strip() or None, "u": user["username"]})
    uid = str(res.scalar_one())
    adir = _pdir() / uid
    adir.mkdir(parents=True, exist_ok=True)
    for f in files:
        if not f.filename:
            continue
        ext = Path(f.filename).suffix[:10]
        stored = f"{uuid.uuid4().hex}{ext}"
        size = 0
        with (adir / stored).open("wb") as out:
            while True:
                chunk = await f.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                out.write(chunk)
        await db.execute(text(
            "INSERT INTO project_photos(update_id,filename,orig_name,content_type,size) "
            "VALUES (:a,:fn,:on,:ct,:s)"),
            {"a": uid, "fn": stored, "on": f.filename[:200],
             "ct": f.content_type, "s": size})
    await db.commit()
    return {"id": uid}


class UpdatePatch(BaseModel):
    date: datetime.date | None = None
    progress: int | None = None
    status: str | None = None
    note: str | None = None


@router.patch("/updates/{uid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def update_update(uid: str, body: UpdatePatch, db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    d = body.model_dump(exclude_unset=True)
    if "status" in d and d["status"] not in STATUSES:
        raise HTTPException(400, f"status harus salah satu {STATUSES}")
    if "progress" in d and not 0 <= d["progress"] <= 100:
        raise HTTPException(400, "progress 0-100")
    sets, params = [], {"i": uid}
    for k, v in d.items():
        sets.append(f"{k}=:{k}")
        params[k] = v
    if not sets:
        raise HTTPException(400, "tidak ada yang diubah")
    res = await db.execute(text(f"UPDATE project_updates SET {', '.join(sets)} WHERE id=:i"),
                           params)
    if res.rowcount == 0:
        raise HTTPException(404, "update tidak ditemukan")
    await db.commit()
    return {"id": uid}


@router.delete("/updates/{uid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_update(uid: str, db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM project_updates WHERE id=:i"), {"i": uid})
    if res.rowcount == 0:
        raise HTTPException(404, "update tidak ditemukan")
    await db.commit()
    import shutil
    shutil.rmtree(_pdir() / uid, ignore_errors=True)
    return {"ok": True}


@router.delete("/updates/{uid}/photos/{pid}",
              dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_photo(uid: str, pid: str, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    row = (await db.execute(text(
        "SELECT filename FROM project_photos WHERE id=:p AND update_id=:a"),
        {"p": pid, "a": uid})).mappings().first()
    if not row:
        raise HTTPException(404, "foto tidak ditemukan")
    await db.execute(text("DELETE FROM project_photos WHERE id=:p"), {"p": pid})
    await db.commit()
    try:
        (_pdir() / uid / row["filename"]).unlink(missing_ok=True)
    except OSError:
        pass
    return {"ok": True}


@router.get("/updates/{uid}/photos/{pid}")
async def photo(uid: str, pid: str, token: str | None = None,
                request: Request = None,
                db: AsyncSession = Depends(get_db)):
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
        "SELECT filename, content_type, orig_name FROM project_photos "
        "WHERE id=:p AND update_id=:a"), {"p": pid, "a": uid})).mappings().first()
    if not row:
        raise HTTPException(404, "foto tidak ditemukan")
    path = _pdir() / uid / row["filename"]
    if not path.is_file():
        raise HTTPException(404, "file hilang di server")
    return FileResponse(path, media_type=row["content_type"] or "image/jpeg",
                        filename=row["orig_name"] or row["filename"])
