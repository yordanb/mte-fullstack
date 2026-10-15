from fastapi import APIRouter, Depends, Query, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_role
from app.db.session import get_db
from datetime import date

router = APIRouter(prefix="/v1/staging", tags=["staging"])

ROLE_LABELS = {0: "Primer", 1: "Booster 1", 2: "Booster 2", 3: "Booster 3",
               4: "Booster 4", 5: "Booster 5", 6: "Booster 6"}


def _role_label(n: int) -> str:
    return ROLE_LABELS.get(n, f"Booster {n}")


def _cur_period() -> str:
    return date.today().strftime("%Y-%m")


# ─── Models ───────────────────────────────────────────────

class GroupIn(BaseModel):
    group_no: int
    sump_name: str | None = None
    system_type: str
    is_active: bool = True


class GroupPatch(BaseModel):
    group_no: int | None = None
    sump_name: str | None = None
    system_type: str | None = None
    is_active: bool | None = None


class PumpIn(BaseModel):
    pump_cn: str
    role_order: int = 0


class PumpPatch(BaseModel):
    pump_cn: str | None = None
    role_order: int | None = None


class ReorderItem(BaseModel):
    id: int
    role_order: int


class ReorderReq(BaseModel):
    group_id: int
    period: str
    items: list[ReorderItem]


class CopyReq(BaseModel):
    from_period: str
    to_period: str


class MoveReq(BaseModel):
    pump_id: int
    to_group_id: int
    to_role_order: int


# ─── Group CRUD ───────────────────────────────────────────

@router.get("/groups")
async def list_groups(period: str | None = None,
                      db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    """List semua grup + untaian pump untuk periode tertentu."""
    p = period or _cur_period()
    rows = (await db.execute(text("""
        SELECT g.id, g.group_no, g.sump_name, g.system_type, g.is_active,
               g.created_at, g.updated_at,
               COALESCE(json_agg(
                 json_build_object(
                   'id', i.id, 'pump_cn', i.pump_cn, 'role_order', i.role_order,
                   'role_label', CASE
                     WHEN i.role_order = 0 THEN 'Primer'
                     ELSE 'Booster ' || i.role_order
                   END,
                   'unit_type', e.unit_type, 'unit_model', e.unit_model
                 ) ORDER BY i.role_order
               ) FILTER (WHERE i.id IS NOT NULL), '[]') AS pumps
        FROM staging_pump_groups g
        LEFT JOIN staging_pump_items i ON i.group_id = g.id AND i.period = :p
        LEFT JOIN equipment e ON e.cn = i.pump_cn
        GROUP BY g.id ORDER BY g.group_no
    """), {"p": p})).mappings().all()
    return {"period": p, "data": [dict(r) for r in rows]}


@router.get("/groups/{gid}")
async def get_group(gid: int, period: str | None = None,
                    db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    """Detail 1 grup + pump + riwayat perubahan."""
    p = period or _cur_period()
    grp = (await db.execute(text("""
        SELECT g.id, g.group_no, g.sump_name, g.system_type, g.is_active,
               g.created_at, g.updated_at,
               COALESCE(json_agg(
                 json_build_object(
                   'id', i.id, 'pump_cn', i.pump_cn, 'role_order', i.role_order,
                   'role_label', CASE
                     WHEN i.role_order = 0 THEN 'Primer'
                     ELSE 'Booster ' || i.role_order
                   END,
                   'unit_type', e.unit_type, 'unit_model', e.unit_model
                 ) ORDER BY i.role_order
               ) FILTER (WHERE i.id IS NOT NULL), '[]') AS pumps
        FROM staging_pump_groups g
        LEFT JOIN staging_pump_items i ON i.group_id = g.id AND i.period = :p
        LEFT JOIN equipment e ON e.cn = i.pump_cn
        WHERE g.id = :gid
        GROUP BY g.id
    """), {"gid": gid, "p": p})).mappings().first()
    if not grp:
        raise HTTPException(404, "Grup tidak ditemukan")
    changes = (await db.execute(text("""
        SELECT id, period, change_type, pump_cn, from_value, to_value,
               changed_by, changed_at
        FROM staging_pump_changes WHERE group_id = :gid
        ORDER BY changed_at DESC LIMIT 50
    """), {"gid": gid})).mappings().all()
    return {**dict(grp), "changes": [dict(c) for c in changes]}


@router.post("/groups", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create_group(body: GroupIn, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    g = (await db.execute(text("""
        INSERT INTO staging_pump_groups(group_no, sump_name, system_type, is_active)
        VALUES (:no, :sump, :sistem, :aktif) RETURNING id
    """), {"no": body.group_no, "sump": body.sump_name, "sistem": body.system_type,
           "aktif": body.is_active})).scalar()
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, from_value, to_value, changed_by)
        VALUES (:gid, :p, 'GROUP_EDIT', NULL, :info, :u)
    """), {"gid": g, "p": _cur_period(),
           "info": f"Grup dibuat: No {body.group_no}, {body.system_type}",
           "u": user["username"]})
    await db.commit()
    return {"id": g}


@router.patch("/groups/{gid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_group(gid: int, body: GroupPatch,
                      db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    cur = (await db.execute(text("SELECT * FROM staging_pump_groups WHERE id=:gid"),
                            {"gid": gid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Grup tidak ditemukan")
    sets, p = [], {"gid": gid}
    changes_log = []
    for fld in ("group_no", "sump_name", "system_type", "is_active"):
        v = getattr(body, fld)
        if v is not None and str(v) != str(cur[fld]):
            sets.append(f"{fld} = :{fld}")
            p[fld] = v
            changes_log.append(f"{fld}: {cur[fld]} → {v}")
    if not sets:
        return {"ok": False, "detail": "Tidak ada perubahan"}
    sets.append("updated_at = now()")
    await db.execute(text(f"UPDATE staging_pump_groups SET {', '.join(sets)} WHERE id=:gid"), p)
    if changes_log:
        await db.execute(text("""
            INSERT INTO staging_pump_changes(group_id, period, change_type, from_value, to_value, changed_by)
            VALUES (:gid, :p, 'GROUP_EDIT', :fv, :tv, :u)
        """), {"gid": gid, "p": _cur_period(),
               "fv": "; ".join(changes_log), "tv": "Grup diubah",
               "u": user["username"]})
    await db.commit()
    return {"ok": True}


@router.delete("/groups/{gid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_group(gid: int, db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    cur = (await db.execute(text("SELECT group_no, system_type FROM staging_pump_groups WHERE id=:gid"),
                            {"gid": gid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Grup tidak ditemukan")
    await db.execute(text("DELETE FROM staging_pump_groups WHERE id=:gid"), {"gid": gid})
    await db.commit()
    return {"ok": True}


# ─── Pump items ───────────────────────────────────────────

@router.post("/groups/{gid}/pumps", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_pump(gid: int, body: PumpIn, period: str | None = None,
                   db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    p = period or _cur_period()
    grp = (await db.execute(text("SELECT id FROM staging_pump_groups WHERE id=:gid"),
                            {"gid": gid})).scalar()
    if not grp:
        raise HTTPException(404, "Grup tidak ditemukan")
    cn = body.pump_cn.strip().upper().replace(" ", "")
    eq = (await db.execute(text("SELECT cn FROM equipment WHERE cn=:cn AND category='PUMPING'"),
                           {"cn": cn})).scalar()
    if not eq:
        raise HTTPException(400, f"Pump {cn} tidak ditemukan di master equipment (kategori PUMPING)")
    existing = (await db.execute(text(
        "SELECT id FROM staging_pump_items WHERE group_id=:gid AND period=:p AND pump_cn=:cn"),
        {"gid": gid, "p": p, "cn": cn})).scalar()
    if existing:
        raise HTTPException(409, f"Pump {cn} sudah ada di grup ini untuk periode {p}")
    role = body.role_order
    clash = (await db.execute(text(
        "SELECT id FROM staging_pump_items WHERE group_id=:gid AND period=:p AND role_order=:r"),
        {"gid": gid, "p": p, "r": role})).scalar()
    if clash:
        await db.execute(text(
            "UPDATE staging_pump_items SET role_order = role_order + 1 "
            "WHERE group_id=:gid AND period=:p AND role_order >= :r"),
            {"gid": gid, "p": p, "r": role})
    new_id = (await db.execute(text("""
        INSERT INTO staging_pump_items(group_id, period, pump_cn, role_order)
        VALUES (:gid, :p, :cn, :r) RETURNING id
    """), {"gid": gid, "p": p, "cn": cn, "r": role})).scalar()
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, pump_cn, from_value, to_value, changed_by)
        VALUES (:gid, :p, 'ADD_PUMP', :cn, NULL, :role, :u)
    """), {"gid": gid, "p": p, "cn": cn, "role": _role_label(role), "u": user["username"]})
    await db.commit()
    return {"id": new_id}


@router.patch("/pumps/{pid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_pump(pid: int, body: PumpPatch,
                     db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    cur = (await db.execute(text("SELECT * FROM staging_pump_items WHERE id=:pid"),
                            {"pid": pid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Pump item tidak ditemukan")
    sets, p = [], {"pid": pid}
    log_from, log_to = [], []
    if body.pump_cn is not None and body.pump_cn.strip().upper().replace(" ", "") != cur["pump_cn"]:
        cn = body.pump_cn.strip().upper().replace(" ", "")
        eq = (await db.execute(text("SELECT cn FROM equipment WHERE cn=:cn AND category='PUMPING'"),
                               {"cn": cn})).scalar()
        if not eq:
            raise HTTPException(400, f"Pump {cn} tidak ditemukan di master equipment")
        sets.append("pump_cn = :cn"); p["cn"] = cn
        log_from.append(f"pump={cur['pump_cn']}"); log_to.append(f"pump={cn}")
    if body.role_order is not None and body.role_order != cur["role_order"]:
        sets.append("role_order = :r"); p["r"] = body.role_order
        log_from.append(_role_label(cur["role_order"]))
        log_to.append(_role_label(body.role_order))
    if not sets:
        return {"ok": False, "detail": "Tidak ada perubahan"}
    await db.execute(text(f"UPDATE staging_pump_items SET {', '.join(sets)} WHERE id=:pid"), p)
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, pump_cn, from_value, to_value, changed_by)
        VALUES (:gid, :p, 'REORDER', :cn, :fv, :tv, :u)
    """), {"gid": cur["group_id"], "p": cur["period"], "cn": cur["pump_cn"],
           "fv": " → ".join(log_from) if log_from else None,
           "tv": " → ".join(log_to) if log_to else None,
           "u": user["username"]})
    await db.commit()
    return {"ok": True}


@router.delete("/pumps/{pid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_pump(pid: int, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    cur = (await db.execute(text("SELECT * FROM staging_pump_items WHERE id=:pid"),
                            {"pid": pid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Pump item tidak ditemukan")
    await db.execute(text("DELETE FROM staging_pump_items WHERE id=:pid"), {"pid": pid})
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, pump_cn, from_value, to_value, changed_by)
        VALUES (:gid, :p, 'REMOVE_PUMP', :cn, :role, NULL, :u)
    """), {"gid": cur["group_id"], "p": cur["period"], "cn": cur["pump_cn"],
           "role": _role_label(cur["role_order"]), "u": user["username"]})
    await db.commit()
    return {"ok": True}


@router.post("/reorder", dependencies=[Depends(require_role("inputer", "admin"))])
async def reorder_pumps(body: ReorderReq,
                        db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    """Bulk update role_order via drag-and-drop."""
    old = {r["id"]: dict(r) for r in (await db.execute(text(
        "SELECT id, pump_cn, role_order FROM staging_pump_items WHERE group_id=:gid AND period=:p"),
        {"gid": body.group_id, "p": body.period})).mappings().all()}
    for item in body.items:
        prev = old.get(item.id)
        if prev and prev["role_order"] != item.role_order:
            await db.execute(text(
                "UPDATE staging_pump_items SET role_order=:r WHERE id=:pid"),
                {"r": item.role_order, "pid": item.id})
            await db.execute(text("""
                INSERT INTO staging_pump_changes(group_id, period, change_type, pump_cn, from_value, to_value, changed_by)
                VALUES (:gid, :p, 'REORDER', :cn, :fv, :tv, :u)
            """), {"gid": body.group_id, "p": body.period, "cn": prev["pump_cn"],
                   "fv": _role_label(prev["role_order"]), "tv": _role_label(item.role_order),
                   "u": user["username"]})
    await db.commit()
    return {"ok": True}


@router.post("/move", dependencies=[Depends(require_role("inputer", "admin"))])
async def move_pump(body: MoveReq, db: AsyncSession = Depends(get_db),
                    user=Depends(get_current_user)):
    """Pindahkan pump ke grup lain dengan role_order tertentu."""
    cur = (await db.execute(text("SELECT * FROM staging_pump_items WHERE id=:pid"),
                            {"pid": body.pump_id})).mappings().first()
    if not cur:
        raise HTTPException(404, "Pump item tidak ditemukan")
    old_gid = cur["group_id"]
    old_role = cur["role_order"]
    p = cur["period"]
    if old_gid == body.to_group_id and old_role == body.to_role_order:
        return {"ok": False, "detail": "Tidak ada perubahan"}
    # Cek duplikat CN di grup tujuan
    dup = (await db.execute(text(
        "SELECT 1 FROM staging_pump_items WHERE group_id=:gid AND period=:p AND pump_cn=:cn AND id<>:pid"),
        {"gid": body.to_group_id, "p": p, "cn": cur["pump_cn"], "pid": body.pump_id})).scalar()
    if dup:
        raise HTTPException(409, f"Pump {cur['pump_cn']} sudah ada di grup tujuan")
    # Tutup gap di grup sumber
    await db.execute(text(
        "UPDATE staging_pump_items SET role_order = role_order - 1 "
        "WHERE group_id=:gid AND period=:p AND role_order > :r"),
        {"gid": old_gid, "p": p, "r": old_role})
    # Geser di grup tujuan
    await db.execute(text(
        "UPDATE staging_pump_items SET role_order = role_order + 1 "
        "WHERE group_id=:gid AND period=:p AND role_order >= :r"),
        {"gid": body.to_group_id, "p": p, "r": body.to_role_order})
    # Pindahkan pump
    await db.execute(text(
        "UPDATE staging_pump_items SET group_id=:gid, role_order=:r WHERE id=:pid"),
        {"gid": body.to_group_id, "r": body.to_role_order, "pid": body.pump_id})
    # Log
    old_grp = (await db.execute(text("SELECT group_no, system_type FROM staging_pump_groups WHERE id=:gid"),
                                {"gid": old_gid})).mappings().first()
    new_grp = (await db.execute(text("SELECT group_no, system_type FROM staging_pump_groups WHERE id=:gid"),
                                {"gid": body.to_group_id})).mappings().first()
    from_desc = f"Grup {old_grp['group_no']} ({old_grp['system_type']}) / {_role_label(old_role)}"
    to_desc = f"Grup {new_grp['group_no']} ({new_grp['system_type']}) / {_role_label(body.to_role_order)}"
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, pump_cn, from_value, to_value, changed_by)
        VALUES (:gid, :p, 'MOVE', :cn, :fv, :tv, :u)
    """), {"gid": body.to_group_id, "p": p, "cn": cur["pump_cn"],
           "fv": from_desc, "tv": to_desc, "u": user["username"]})
    await db.commit()
    return {"ok": True}
async def copy_config(body: CopyReq, db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    """Copy konfigurasi dari satu periode ke periode lain."""
    existing = (await db.execute(text(
        "SELECT 1 FROM staging_pump_items WHERE period=:to LIMIT 1"),
        {"to": body.to_period})).scalar()
    if existing:
        raise HTTPException(409, f"Periode {body.to_period} sudah memiliki konfigurasi")
    rows = (await db.execute(text("""
        SELECT group_id, pump_cn, role_order FROM staging_pump_items WHERE period=:from
    """), {"from": body.from_period})).mappings().all()
    if not rows:
        raise HTTPException(400, f"Periode {body.from_period} tidak memiliki konfigurasi untuk disalin")
    for r in rows:
        await db.execute(text("""
            INSERT INTO staging_pump_items(group_id, period, pump_cn, role_order)
            VALUES (:gid, :to, :cn, :r)
        """), {"gid": r["group_id"], "to": body.to_period,
               "cn": r["pump_cn"], "r": r["role_order"]})
    await db.execute(text("""
        INSERT INTO staging_pump_changes(group_id, period, change_type, from_value, to_value, changed_by)
        SELECT id, :to, 'GROUP_EDIT', :from, 'Copy konfigurasi', :u
        FROM staging_pump_groups WHERE is_active = TRUE
    """), {"to": body.to_period, "from": body.from_period, "u": user["username"]})
    await db.commit()
    return {"ok": True, "copied": len(rows)}


# ─── Change history ───────────────────────────────────────

@router.get("/changes")
async def list_changes(period: str | None = None,
                       group_id: int | None = None,
                       db: AsyncSession = Depends(get_db),
                       user=Depends(get_current_user)):
    conds, p = [], {}
    if period:
        conds.append("c.period = :p"); p["p"] = period
    if group_id:
        conds.append("c.group_id = :gid"); p["gid"] = group_id
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(f"""
        SELECT c.id, c.group_id, c.period, c.change_type, c.pump_cn,
               c.from_value, c.to_value, c.changed_by, c.changed_at,
               g.group_no, g.sump_name, g.system_type
        FROM staging_pump_changes c
        JOIN staging_pump_groups g ON g.id = c.group_id
        {where} ORDER BY c.changed_at DESC LIMIT 200
    """), p)).mappings().all()
    return {"data": [dict(r) for r in rows]}


# ─── Equipment search (PUMPING only) ──────────────────────

@router.get("/equipment")
async def search_pump_equipment(q: str = Query("", min_length=0),
                                db: AsyncSession = Depends(get_db),
                                user=Depends(get_current_user)):
    """Search equipment kategori PUMPING untuk dropdown pilih pump."""
    pattern = f"%{q.strip().upper().replace(' ', '')}%"
    rows = (await db.execute(text("""
        SELECT cn, unit_type, unit_model, unit_product, aktif
        FROM equipment WHERE category='PUMPING'
        AND (UPPER(REPLACE(cn, ' ', '')) ILIKE :q OR UPPER(COALESCE(unit_type,'')) ILIKE :q)
        ORDER BY cn LIMIT 20
    """), {"q": pattern})).mappings().all()
    return {"data": [dict(r) for r in rows]}
