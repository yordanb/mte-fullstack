"""Proker Thermostat CAT (replace thermostat engine Caterpillar, interval 12.000 jam).

Sumber Excel: `proker thermostat engine caterpillar.xlsx`,
sheet `05. MIDLIFE COOLING SISTEM`. Satu baris per unit:

  NO | UNIT MODEL | PRODUCT | UNIT TYPE | C/N | HM NOW | DEVIASI | LIFETIME
  LAST                     : HM | DATE
  MODIF 74°C               : HM | DATE | REMAKS (DONE/NOT YET) | WR | ETA PARTS | ETA EXEC
  RADIATOR CHECK BY THERMA : HM | DATE | UPPER | LOWER | REMARK

Import disimpan flat ke `thermo_unit` (1 baris per C/N) — upsert per C/N,
unit lama yang tidak ada di file tetap tersimpan.

Kolom turunan TIDAK disimpan, dihitung ulang saat baca (terverifikasi dari
formula file: DEVIASI = HM NOW - (LAST HM + 12.000); LIFETIME = HM NOW - MODIF HM,
untuk unit yang belum dimodifikasi LIFETIME = HM NOW):
  deviasi  = hm_now - (COALESCE(last_hm,0) + interval_hm)   -- negatif = aman
  lifetime = hm_now - COALESCE(modif_hm, 0)
  due      = deviasi >= 0                                   -- thermostat jatuh tempo
"""
import datetime
import io
import json
import logging

import openpyxl
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_menu
from app.db.session import get_db, SessionLocal
from app.services.hm_sync import refresh_hm_from_sources

router = APIRouter(prefix="/v1/thermostat", tags=["thermostat"])
log = logging.getLogger("thermostat")

DEFAULT_INTERVAL = 12000           # interval replace thermostat (12.000 jam)
BATCH = 500

UNIT_FIELDS = ("no", "unit_model", "product", "unit_type", "hm_now", "interval_hm",
               "last_hm", "last_date", "modif_hm", "modif_date", "modif_status",
               "wr", "eta_parts", "eta_exec",
               "rad_hm", "rad_date", "rad_upper", "rad_lower", "rad_remark")

_DATE_FORMATS = ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y")


# --------------------------------------------------------------------------- util
def _txt(v) -> str | None:
    if v is None:
        return None
    s = str(v).replace("\xa0", " ").strip()
    return s or None


def _num(v) -> float | None:
    if v is None or v == "" or isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).replace(",", "").strip()
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def _int(v) -> int | None:
    n = _num(v)
    return int(n) if n is not None else None


def _cn(v) -> str | None:
    s = _txt(v)
    return s.upper().replace(" ", "") if s else None


def _date(v):
    """Sel tanggal → datetime.date (terima datetime, date, atau string lazim)."""
    if v is None or v == "" or isinstance(v, bool):
        return None
    if isinstance(v, datetime.datetime):
        return v.date()
    if isinstance(v, datetime.date):
        return v
    s = str(v).strip()
    if not s:
        return None
    for fmt in _DATE_FORMATS:
        try:
            return datetime.datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


# --------------------------------------------------------------------------- parser
def _find_sheet(wb):
    """Cari sheet yang punya header C/N (biasanya '05. MIDLIFE COOLING SISTEM')."""
    for sn in wb.sheetnames:
        ws = wb[sn]
        for r in range(1, min(15, ws.max_row or 1) + 1):
            for c in range(1, min(60, ws.max_column or 1) + 1):
                v = ws.cell(row=r, column=c).value
                if isinstance(v, str) and v.strip().upper() == "C/N":
                    return ws, r
    return None, None


def _parse(content: bytes, fname: str) -> tuple[list[dict], list[dict]]:
    """Baca satu workbook → (units, errors)."""
    wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
    try:
        ws, header_row = _find_sheet(wb)
        if ws is None:
            raise ValueError("kolom C/N tidak ditemukan — bukan format Proker Thermostat CAT")

        max_col = ws.max_column or 0
        max_row = ws.max_row or 0

        def cell(r: int, c: int):
            try:
                return ws.cell(row=r, column=c).value
            except (ValueError, IndexError):
                return None

        # label grup pada baris header (termasuk sel merge) + sub-label di bawahnya
        groups: dict[int, str] = {}
        for rng in ws.merged_cells.ranges:
            if rng.min_row <= header_row <= rng.max_row:
                val = _txt(cell(header_row, rng.min_col)) or ""
                for c in range(rng.min_col, rng.max_col + 1):
                    groups[c] = val
        for c in range(1, max_col + 1):
            groups.setdefault(c, _txt(cell(header_row, c)) or "")

        # pemetaan (kolom → field) berdasarkan pasangan grup + sub-header
        cols: dict[str, int] = {}
        for c in range(1, max_col + 1):
            g = groups.get(c, "").strip().upper()
            sub = (_txt(cell(header_row + 1, c)) or "").strip().upper()
            if g == "C/N":
                cols.setdefault("cn", c)
            elif g == "NO":
                cols.setdefault("no", c)
            elif g == "UNIT MODEL":
                cols.setdefault("unit_model", c)
            elif g == "PRODUCT":
                cols.setdefault("product", c)
            elif g == "UNIT TYPE":
                cols.setdefault("unit_type", c)
            elif g == "HM NOW":
                cols.setdefault("hm_now", c)
            elif g == "LAST":
                if sub == "HM":
                    cols.setdefault("last_hm", c)
                elif sub == "DATE":
                    cols.setdefault("last_date", c)
            elif g.startswith("MODIF"):
                if sub == "HM":
                    cols.setdefault("modif_hm", c)
                elif sub == "DATE":
                    cols.setdefault("modif_date", c)
                elif sub.startswith("REMA"):        # REMAKS / REMARKS
                    cols.setdefault("modif_status", c)
                elif sub == "WR":
                    cols.setdefault("wr", c)
                elif sub == "ETA PARTS":
                    cols.setdefault("eta_parts", c)
                elif sub == "ETA EXEC":
                    cols.setdefault("eta_exec", c)
            elif g.startswith("RADIATOR"):
                if sub == "HM":
                    cols.setdefault("rad_hm", c)
                elif sub == "DATE":
                    cols.setdefault("rad_date", c)
                elif sub == "UPPER":
                    cols.setdefault("rad_upper", c)
                elif sub == "LOWER":
                    cols.setdefault("rad_lower", c)
                elif sub.startswith("REMARK"):
                    cols.setdefault("rad_remark", c)

        if "cn" not in cols:
            raise ValueError("kolom C/N tidak ditemukan — bukan format Proker Thermostat CAT")
        if "hm_now" not in cols:
            raise ValueError("kolom HM NOW tidak ditemukan — format tidak dikenali")

        def val(r: int, key: str):
            c = cols.get(key)
            return cell(r, c) if c else None

        units: list[dict] = []
        errors: list[dict] = []
        seen: set[str] = set()
        for r in range(header_row + 2, max_row + 1):
            cn = _cn(val(r, "cn"))
            if not cn:
                continue
            if cn in seen:
                errors.append({"file": fname, "row": r, "cn": cn,
                               "error": "C/N duplikat — baris terakhir dipakai"})
            seen.add(cn)

            for key, label in (("last_date", "LAST DATE"), ("modif_date", "MODIF DATE"),
                               ("eta_parts", "ETA PARTS"), ("eta_exec", "ETA EXEC"),
                               ("rad_date", "RADIATOR DATE")):
                raw = val(r, key)
                if raw is not None and _date(raw) is None:
                    errors.append({"file": fname, "row": r, "cn": cn,
                                   "error": f"{label} tidak terbaca: {raw!r}"})

            status = (_txt(val(r, "modif_status")) or "").upper() or None
            units.append({
                "cn": cn,
                "no": _int(val(r, "no")),
                "unit_model": _txt(val(r, "unit_model")),
                "product": _txt(val(r, "product")),
                "unit_type": _txt(val(r, "unit_type")),
                "hm_now": _num(val(r, "hm_now")),
                "interval_hm": float(DEFAULT_INTERVAL),
                "last_hm": _num(val(r, "last_hm")),
                "last_date": _date(val(r, "last_date")),
                "modif_hm": _num(val(r, "modif_hm")),
                "modif_date": _date(val(r, "modif_date")),
                "modif_status": status,
                "wr": _txt(val(r, "wr")),
                "eta_parts": _date(val(r, "eta_parts")),
                "eta_exec": _date(val(r, "eta_exec")),
                "rad_hm": _num(val(r, "rad_hm")),
                "rad_date": _date(val(r, "rad_date")),
                "rad_upper": _num(val(r, "rad_upper")),
                "rad_lower": _num(val(r, "rad_lower")),
                "rad_remark": _txt(val(r, "rad_remark")),
            })
        return units, errors
    finally:
        wb.close()


# --------------------------------------------------------------------------- import
_UNIT_UPSERT = text("""
INSERT INTO thermo_unit
  (cn, no, unit_model, product, unit_type, hm_now, interval_hm,
   last_hm, last_date, modif_hm, modif_date, modif_status,
   wr, eta_parts, eta_exec, rad_hm, rad_date, rad_upper, rad_lower, rad_remark,
   import_id)
VALUES
  (:cn, :no, :unit_model, :product, :unit_type, :hm_now, :interval_hm,
   :last_hm, :last_date, :modif_hm, :modif_date, :modif_status,
   :wr, :eta_parts, :eta_exec, :rad_hm, :rad_date, :rad_upper, :rad_lower, :rad_remark,
   :import_id)
ON CONFLICT (cn) DO UPDATE SET
  no           = COALESCE(EXCLUDED.no, thermo_unit.no),
  unit_model   = COALESCE(EXCLUDED.unit_model, thermo_unit.unit_model),
  product      = COALESCE(EXCLUDED.product, thermo_unit.product),
  unit_type    = COALESCE(EXCLUDED.unit_type, thermo_unit.unit_type),
  hm_now       = COALESCE(EXCLUDED.hm_now, thermo_unit.hm_now),
  interval_hm  = thermo_unit.interval_hm,
  last_hm      = COALESCE(EXCLUDED.last_hm, thermo_unit.last_hm),
  last_date    = COALESCE(EXCLUDED.last_date, thermo_unit.last_date),
  modif_hm     = COALESCE(EXCLUDED.modif_hm, thermo_unit.modif_hm),
  modif_date   = COALESCE(EXCLUDED.modif_date, thermo_unit.modif_date),
  modif_status = COALESCE(EXCLUDED.modif_status, thermo_unit.modif_status),
  wr           = COALESCE(EXCLUDED.wr, thermo_unit.wr),
  eta_parts    = COALESCE(EXCLUDED.eta_parts, thermo_unit.eta_parts),
  eta_exec     = COALESCE(EXCLUDED.eta_exec, thermo_unit.eta_exec),
  rad_hm       = COALESCE(EXCLUDED.rad_hm, thermo_unit.rad_hm),
  rad_date     = COALESCE(EXCLUDED.rad_date, thermo_unit.rad_date),
  rad_upper    = COALESCE(EXCLUDED.rad_upper, thermo_unit.rad_upper),
  rad_lower    = COALESCE(EXCLUDED.rad_lower, thermo_unit.rad_lower),
  rad_remark   = COALESCE(EXCLUDED.rad_remark, thermo_unit.rad_remark),
  import_id    = EXCLUDED.import_id,
  updated_at   = now()
""")


async def _run(import_id: str, files: list[tuple[str, bytes]]):
    async with SessionLocal() as db:
        try:
            merged: dict[str, dict] = {}
            errors: list[dict] = []
            for fname, content in files:
                try:
                    units, errs = _parse(content, fname)
                except Exception as e:  # noqa: BLE001
                    errors.append({"file": fname, "error": str(e)})
                    continue
                errors.extend(errs[:50])
                merged.update({u["cn"]: u for u in units})

            if not merged:
                raise ValueError("tidak ada baris unit yang terbaca (C/N kosong semua)")

            rows = list(merged.values())
            for i in range(0, len(rows), BATCH):
                await db.execute(_UNIT_UPSERT, [
                    {**u, "import_id": import_id} for u in rows[i:i + BATCH]])
                await db.execute(text(
                    "UPDATE imports SET processed_rows=:p, ok_rows=:o, total_rows=:t WHERE id=:i"),
                    {"p": min(i + BATCH, len(rows)), "o": min(i + BATCH, len(rows)),
                     "t": len(rows), "i": import_id})
                await db.commit()

            done = sum(1 for u in rows if (u["modif_status"] or "").upper() == "DONE")
            due = sum(1 for u in rows
                      if u["hm_now"] is not None
                      and float(u["hm_now"]) - ((u["last_hm"] or 0) + float(u["interval_hm"])) >= 0)
            summary = {
                "units": len(rows), "done": done, "not_yet": len(rows) - done,
                "due": due, "inserted": len(rows), "updated": 0,
                "files": [f for f, _ in files], "errors": errors[:50],
            }
            await db.execute(text(
                "UPDATE imports SET status='COMMITTED', total_rows=:t, ok_rows=:o, "
                "fail_rows=:f, processed_rows=:p, errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"t": len(rows), "o": len(rows), "f": len(errors), "p": len(rows),
                 "e": json.dumps(summary, default=str), "i": import_id})
            await db.commit()
            log.info("thermostat import %s: %s unit (%s done, %s due)",
                     import_id, len(rows), done, due)
        except Exception as e:  # noqa: BLE001
            await db.rollback()
            await db.execute(text(
                "UPDATE imports SET status='FAILED', errors=CAST(:e AS jsonb) WHERE id=:i"),
                {"e": json.dumps({"error": str(e)}, default=str), "i": import_id})
            await db.commit()
            log.exception("thermostat import gagal: %s", e)


@router.post("/import", dependencies=[Depends(require_menu("prokerthermo", "add"))], status_code=202)
async def import_xlsx(
    bg: BackgroundTasks,
    files: list[UploadFile] = File(...),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Upload 1..n file thermostat (.xlsx). Upsert unit per C/N."""
    if not files:
        raise HTTPException(400, "Tidak ada file")
    payload: list[tuple[str, bytes]] = []
    limit = settings.max_upload_mb * 1024 * 1024
    for f in files:
        content = await f.read()
        if len(content) > limit:
            raise HTTPException(413, f"{f.filename}: file terlalu besar")
        if not content:
            raise HTTPException(400, f"{f.filename}: file kosong")
        payload.append((f.filename or "upload.xlsx", content))
    label = ", ".join(name for name, _ in payload)
    res = await db.execute(text(
        "INSERT INTO imports(filename,sheet,status,total_rows,uploaded_by) "
        "VALUES (:fn,'THERMOSTAT','PROCESSING',0,:u) RETURNING id"),
        {"fn": label[:300], "u": user["username"]})
    import_id = str(res.scalar_one())
    await db.commit()
    bg.add_task(_run, import_id, payload)
    return {"import_id": import_id, "status": "PROCESSING", "files": len(payload)}


@router.get("/import/{import_id}", dependencies=[Depends(require_menu("prokerthermo", "view"))])
async def import_status(import_id: str, db: AsyncSession = Depends(get_db)):
    row = (await db.execute(text(
        "SELECT id, filename, status, total_rows, ok_rows, fail_rows, processed_rows, "
        "uploaded_by, created_at, errors FROM imports WHERE id=:i AND sheet='THERMOSTAT'"),
        {"i": import_id})).mappings().first()
    if not row:
        raise HTTPException(404, "import_id tidak ditemukan")
    return dict(row)


# --------------------------------------------------------------------------- agregat
# Kolom turunan (tidak disimpan): deviasi = hm_now - (last_hm + interval);
# lifetime = hm_now - modif_hm; unit yang belum pernah diganti/modif dihitung
# dari 0 (sesuai formula pada file sumber).
_UNIT_SELECT = """
  SELECT cn, no, unit_model, product, unit_type, hm_now, interval_hm,
         last_hm, last_date, modif_hm, modif_date, modif_status,
         wr, eta_parts, eta_exec, rad_hm, rad_date, rad_upper, rad_lower, rad_remark,
         CASE WHEN hm_now IS NULL THEN NULL
              ELSE hm_now - (COALESCE(last_hm, 0) + interval_hm) END AS deviasi,
         CASE WHEN hm_now IS NULL THEN NULL
              ELSE hm_now - COALESCE(modif_hm, 0) END AS lifetime,
         (hm_now IS NOT NULL
          AND hm_now - (COALESCE(last_hm, 0) + interval_hm) >= 0) AS due
  FROM thermo_unit
"""

_SORT = {
    "cn": "cn", "no": "no", "unit_model": "unit_model", "product": "product",
    "unit_type": "unit_type", "hm_now": "hm_now", "deviasi": "deviasi",
    "lifetime": "lifetime", "modif_status": "modif_status",
    "last_hm": "last_hm", "eta_exec": "eta_exec",
}


@router.get("/filters", dependencies=[Depends(require_menu("prokerthermo", "view"))])
async def get_filters(db: AsyncSession = Depends(get_db)):
    async def distinct(col: str) -> list[str]:
        return list((await db.execute(text(
            f"SELECT DISTINCT {col} FROM thermo_unit "
            f"WHERE {col} IS NOT NULL AND {col} <> '' ORDER BY 1"))).scalars().all())

    return {
        "product": await distinct("product"),
        "model": await distinct("unit_model"),
        "type": await distinct("unit_type"),
        "interval": DEFAULT_INTERVAL,
    }


@router.get("/stats", dependencies=[Depends(require_menu("prokerthermo", "view"))])
async def get_stats(db: AsyncSession = Depends(get_db)):
    agg = (await db.execute(text("""
        SELECT COUNT(*) AS units,
               COUNT(*) FILTER (WHERE modif_status = 'DONE') AS done,
               COUNT(*) FILTER (WHERE modif_status IS NOT NULL AND modif_status <> 'DONE') AS not_yet,
               COUNT(*) FILTER (WHERE hm_now IS NOT NULL
                                AND hm_now - (COALESCE(last_hm, 0) + interval_hm) >= 0) AS due,
               MAX(last_date) AS last_date
        FROM thermo_unit
    """))).mappings().first()
    return {
        "units": agg["units"], "done": agg["done"], "not_yet": agg["not_yet"],
        "due": agg["due"], "interval": DEFAULT_INTERVAL,
        "last_date": agg["last_date"],
    }


@router.get("/units", dependencies=[Depends(require_menu("prokerthermo", "view"))])
async def list_units(
    search: str | None = None,
    product: str | None = None,
    model: str | None = None,
    status: str | None = None,
    due: bool | None = None,
    executed: str | None = Query(None, pattern="^(yes|no)$"),
    sort: str = Query("no"),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    conds, p = [], {"lim": page_size, "off": (page - 1) * page_size}
    if search:
        conds.append("(cn ILIKE :s OR unit_model ILIKE :s OR product ILIKE :s "
                     "OR unit_type ILIKE :s OR wr ILIKE :s)")
        p["s"] = f"%{search.strip()}%"
    if product:
        conds.append("product = :prod")
        p["prod"] = product
    if model:
        conds.append("unit_model = :model")
        p["model"] = model
    if status:
        conds.append("COALESCE(modif_status, 'NOT YET') = :st")
        p["st"] = status.upper()
    if due is not None:
        conds.append("(:due = FALSE OR (hm_now IS NOT NULL "
                     "AND hm_now - (COALESCE(last_hm, 0) + interval_hm) >= 0))")
        p["due"] = due
    # Cakupan eksekusi dihitung SEBELUM filter executed, supaya angka chip
    # tetap menggambarkan seluruh unit pada filter product/model/search aktif.
    # "Sudah" = modif 74°C berstatus DONE (satu baris per unit di thermo_unit).
    done_expr = "COALESCE(modif_status, 'NOT YET') = 'DONE'"
    not_done_expr = "COALESCE(modif_status, 'NOT YET') <> 'DONE'"
    scope = {k: v for k, v in p.items() if k not in ("lim", "off")}
    cov = (await db.execute(text(f"""
        SELECT COUNT(*) FILTER (WHERE {done_expr}) AS executed,
               COUNT(*) FILTER (WHERE {not_done_expr}) AS not_executed
        FROM thermo_unit {where}
    """), scope)).mappings().first()
    if executed == "yes":
        conds.append(done_expr)
    elif executed == "no":
        conds.append(not_done_expr)
    if executed:
        where = f"WHERE {' AND '.join(conds)}"
    col = _SORT.get(sort, "no")
    total = (await db.execute(text(
        f"SELECT COUNT(*) FROM thermo_unit {where}"), p)).scalar() or 0
    rows = (await db.execute(text(f"""
        {_UNIT_SELECT}
        {where}
        ORDER BY {col} {order.upper()} NULLS LAST, cn
        LIMIT :lim OFFSET :off
    """), p)).mappings().all()
    return {"total": total, "page": page, "page_size": page_size,
            "executed_units": cov["executed"] if cov else 0,
            "not_executed_units": cov["not_executed"] if cov else 0,
            "data": [dict(r) for r in rows]}


# --------------------------------------------------------------------------- tulis
@router.post("/units", dependencies=[Depends(require_menu("prokerthermo", "add"))], status_code=201)
async def create_unit(body: dict, db: AsyncSession = Depends(get_db)):
    cn = _cn(body.get("cn"))
    if not cn:
        raise HTTPException(400, "cn wajib diisi")
    if (await db.execute(text("SELECT 1 FROM thermo_unit WHERE cn=:c"), {"c": cn})).scalar():
        raise HTTPException(409, f"{cn} sudah ada")
    interval = _num(body.get("interval_hm"))
    if interval is None or interval <= 0:
        interval = float(DEFAULT_INTERVAL)
    row = (await db.execute(text("""
        INSERT INTO thermo_unit
          (cn, no, unit_model, product, unit_type, hm_now, interval_hm,
           last_hm, last_date, modif_hm, modif_date, modif_status,
           wr, eta_parts, eta_exec, rad_hm, rad_date, rad_upper, rad_lower, rad_remark)
        VALUES (:cn, :no, :unit_model, :product, :unit_type, :hm_now, :interval_hm,
                :last_hm, :last_date, :modif_hm, :modif_date, :modif_status,
                :wr, :eta_parts, :eta_exec, :rad_hm, :rad_date, :rad_upper, :rad_lower, :rad_remark)
        RETURNING *
    """), {
        "cn": cn, "no": _int(body.get("no")),
        "unit_model": _txt(body.get("unit_model")), "product": _txt(body.get("product")),
        "unit_type": _txt(body.get("unit_type")), "hm_now": _num(body.get("hm_now")),
        "interval_hm": interval,
        "last_hm": _num(body.get("last_hm")), "last_date": _date(body.get("last_date")),
        "modif_hm": _num(body.get("modif_hm")), "modif_date": _date(body.get("modif_date")),
        "modif_status": (_txt(body.get("modif_status")) or "").upper() or None,
        "wr": _txt(body.get("wr")),
        "eta_parts": _date(body.get("eta_parts")), "eta_exec": _date(body.get("eta_exec")),
        "rad_hm": _num(body.get("rad_hm")), "rad_date": _date(body.get("rad_date")),
        "rad_upper": _num(body.get("rad_upper")), "rad_lower": _num(body.get("rad_lower")),
        "rad_remark": _txt(body.get("rad_remark")),
    })).mappings().first()
    await db.commit()
    return dict(row)


@router.patch("/units/{cn}", dependencies=[Depends(require_menu("prokerthermo", "edit"))])
async def update_unit(cn: str, body: dict, db: AsyncSession = Depends(get_db)):
    key = _cn(cn) or ""
    cur = (await db.execute(text("SELECT * FROM thermo_unit WHERE cn=:c"),
                            {"c": key})).mappings().first()
    if not cur:
        raise HTTPException(404, f"{key} tidak ditemukan")

    sets, params = [], {"c": key}
    for f in UNIT_FIELDS:
        if f not in body:
            continue
        if f in ("no",):
            params[f] = _int(body[f])
        elif f in ("hm_now", "last_hm", "modif_hm", "rad_hm", "rad_upper", "rad_lower"):
            params[f] = _num(body[f])
        elif f == "interval_hm":
            v = _num(body[f])
            params[f] = v if v and v > 0 else float(DEFAULT_INTERVAL)
        elif f in ("last_date", "modif_date", "eta_parts", "eta_exec", "rad_date"):
            d = _date(body[f])
            if body[f] not in (None, "") and d is None:
                raise HTTPException(400, f"{f}: format tanggal tidak dikenali")
            params[f] = d
        elif f == "modif_status":
            params[f] = (_txt(body[f]) or "").upper() or None
        else:
            params[f] = _txt(body[f])
        sets.append(f"{f}=:{f}")
    if not sets:
        raise HTTPException(400, "tidak ada field yang diubah")
    await db.execute(text(
        f"UPDATE thermo_unit SET {', '.join(sets)}, updated_at = now() WHERE cn=:c"), params)
    await db.commit()
    row = (await db.execute(text(f"{_UNIT_SELECT} WHERE cn=:c"),
                            {"c": key})).mappings().first()
    return dict(row)


@router.post("/refresh-hm", dependencies=[Depends(require_menu("prokerthermo", "add"))])
async def refresh_hm(db: AsyncSession = Depends(get_db)):
    """Refresh HM NOW thermostat dari halaman Hourmeter & Yazu Lighting Daily Check.

    HM terbaru per C/N diambil dari `services/hm_sync`; Yazu DC (harian)
    diprioritaskan, Hourmeter (bulanan) menjadi cadangan. Unit yang tidak ada
    di kedua sumber dibiarkan dan dilaporkan `not_found`.
    """
    return await refresh_hm_from_sources(db, "thermo_unit")


@router.delete("/units/{cn}", dependencies=[Depends(require_menu("prokerthermo", "delete"))])
async def delete_unit(cn: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(text("DELETE FROM thermo_unit WHERE cn=:c"),
                           {"c": _cn(cn) or ""})
    if res.rowcount == 0:
        raise HTTPException(404, "unit tidak ditemukan")
    await db.commit()
    return {"deleted": res.rowcount}
