"""Yazu Lighting Daily Check — sync checklist harian unit dari Google Sheets (sheet kedua).

Konsep sama dengan yazu.py (sheet P2H): fetch CSV publik → parse → upsert ke
tabel `yazu_dc_lighting` di database (UNIQUE per waktu+id_unit), catat riwayat ke
`yazu_dc_lighting_sync_log`. Bedanya hanya sumber sheet dan mapping kolom.

Header sheet (gid=0):
  0 Waktu, 1 ID Unit, 2 Nama, 3 NRP, 4 Lokasi, 5 HM, 6 Layak Operasi, 7 Akurasi,
  8 Link Lokasi, 9 Coment,
  10 LEVEL OLI, 11 LEVEL COOLANT, 12 LEVEL FUEL,
  13 KEBOCORAN OLI, 14 KEBOCORAN COOLANT, 15 KEBOCORAN FUEL,
  16 KABEL TERKELUPAS, 17 ATTACHMENT, 18 APAR, 19 (spacer),
  20 STATUS CLOSE, 21 PIC CLOSE, 22 NRP CLOSE, 23 TGL CLOSE, 24 ACTION COMMENT
"""
import csv
import io
import logging
import re
from datetime import datetime, date
from zoneinfo import ZoneInfo

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_menu
from app.db.session import get_db

router = APIRouter(prefix="/v1/yazu-dc-lighting", tags=["yazu-dc-lighting"])
log = logging.getLogger("yazu-dc-lighting")

# Format kolom "Waktu": "04/05/2026 18:27:50" — jam lokal site (WITA/GMT+8),
# bukan UTC (lihat V38; parse sebagai tz-aware Asia/Makassar).
WAKTU_FMT = "%d/%m/%Y %H:%M:%S"
TZ = ZoneInfo("Asia/Makassar")

# Mapping header sheet → kolom DB. Index berdasarkan urutan kolom CSV.
COLS = [
    ("waktu", 0), ("id_unit", 1), ("nama", 2), ("nrp", 3), ("lokasi", 4),
    ("hm", 5), ("layak_operasi", 6), ("akurasi", 7), ("link_lokasi", 8),
    ("coment", 9),
    ("level_oli", 10), ("level_coolant", 11), ("level_fuel", 12),
    ("kebocoran_oli", 13), ("kebocoran_coolant", 14), ("kebocoran_fuel", 15),
    ("kabel_terkelupas", 16), ("attachment", 17), ("apar", 18),
    ("status_close", 20), ("pic_close", 21), ("nrp_close", 22),
    ("tgl_close", 23), ("action_comment", 24),
]
INT_COLS = {"hm", "akurasi"}


def _month_range(y: int, m: int) -> tuple[datetime, datetime]:
    """Return (start, end) tz-aware datetime for year-month range."""
    start = datetime(y, m, 1, 0, 0, 0, tzinfo=TZ)
    if m == 12:
        end = datetime(y + 1, 1, 1, 0, 0, 0, tzinfo=TZ)
    else:
        end = datetime(y, m + 1, 1, 0, 0, 0, tzinfo=TZ)
    return start, end


def _to_str(v: str | None) -> str | None:
    if v is None:
        return None
    v = v.strip()
    return v or None


def _to_int(v: str | None) -> int | None:
    """Int dari sel sheet; kolom HM kadang memakai pemisah ribuan ('5.521' → 5521)."""
    if not v or not v.strip():
        return None
    digits = re.sub(r"[^\d]", "", v)
    if not digits:
        return None
    try:
        return int(digits)
    except ValueError:
        return None


def _parse_waktu(v: str) -> datetime | None:
    """Parse '04/05/2026 18:27:50' → datetime **tz-aware WITA** (lihat yazu.py)."""
    if not v or not v.strip():
        return None
    try:
        return datetime.strptime(v.strip(), WAKTU_FMT).replace(tzinfo=TZ)
    except ValueError:
        return None


async def fetch_csv() -> str:
    """Fetch CSV text dari Google Sheets publik (sheet Daily Check)."""
    async with httpx.AsyncClient(timeout=60) as c:
        r = await c.get(settings.yazu_dc_csv_url, headers={"User-Agent": "MTE-YazuSync/1.0"})
        r.raise_for_status()
        return r.text


def parse_rows(csv_text: str) -> list[dict]:
    """Parse CSV text → list of dict siap insert. Skip header + baris kosong."""
    reader = csv.reader(io.StringIO(csv_text))
    header = next(reader, None)
    if not header:
        return []
    rows: list[dict] = []
    for raw in reader:
        if not raw or not any(c.strip() for c in raw):
            continue
        if len(raw) < 10:
            continue  # baris tidak lengkap
        w = _parse_waktu(raw[0] if len(raw) > 0 else "")
        if not w:
            continue
        uid = _to_str(raw[1] if len(raw) > 1 else "")
        if not uid:
            continue
        d: dict = {"waktu": w, "id_unit": uid}
        for key, idx in COLS:
            if key in ("waktu", "id_unit"):
                continue
            val = raw[idx] if len(raw) > idx else ""
            if key in INT_COLS:
                d[key] = _to_int(val)
            else:
                d[key] = _to_str(val)
        rows.append(d)
    return rows


async def do_sync(db: AsyncSession) -> dict:
    """Fetch + parse + upsert. Return summary dict."""
    started = datetime.now(ZoneInfo("UTC"))
    csv_text = await fetch_csv()
    rows = parse_rows(csv_text)
    if not rows:
        return {"status": "error", "error_msg": "no rows parsed", "rows_total": 0, "rows_upserted": 0}

    cols = [k for k, _ in COLS]
    col_list = ",".join(cols)
    param_list = ",".join(f":{c}" for c in cols)
    update_list = ",".join(f"{c}=EXCLUDED.{c}" for c in cols if c not in ("waktu", "id_unit"))

    sql = f"""
        INSERT INTO yazu_dc_lighting ({col_list})
        VALUES ({param_list})
        ON CONFLICT (waktu, id_unit) DO UPDATE SET {update_list}, synced_at = NOW()
    """
    upserted = 0
    batch = 200
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        await db.execute(text(sql), chunk)
        upserted += len(chunk)
    await db.execute(text("""
        INSERT INTO yazu_dc_lighting_sync_log(started_at, finished_at, status, rows_total, rows_upserted)
        VALUES (:s, NOW(), 'success', :t, :u)
    """), {"s": started, "t": len(rows), "u": upserted})
    await db.commit()
    return {"status": "success", "rows_total": len(rows), "rows_upserted": upserted}


# ─── Endpoints ────────────────────────────────────────────

@router.post("/sync", dependencies=[Depends(require_menu("yazudc_lighting", "add"))])
async def sync_now(db: AsyncSession = Depends(get_db)):
    """Trigger manual sync dari Google Sheets (Daily Check) → tabel yazu_dc_lighting."""
    try:
        return await do_sync(db)
    except httpx.HTTPError as e:
        raise HTTPException(502, f"fetch gagal: {e}")
    except Exception as e:
        log.exception("yazu-dc sync error")
        raise HTTPException(500, f"sync error: {e}")


@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db)):
    """Status sync terakhir + total baris."""
    last = (await db.execute(text("""
        SELECT started_at, finished_at, status, rows_total, rows_upserted, error_msg
        FROM yazu_dc_lighting_sync_log ORDER BY id DESC LIMIT 1
    """))).fetchone()
    total = (await db.execute(text("SELECT COUNT(*) FROM yazu_dc_lighting"))).scalar()
    last_data = (await db.execute(text("SELECT MAX(waktu) FROM yazu_dc_lighting"))).scalar()
    units = (await db.execute(text("SELECT COUNT(DISTINCT id_unit) FROM yazu_dc_lighting"))).scalar()
    return {
        "total_rows": total,
        "total_units": units,
        "last_data_waktu": last_data,
        "last_sync": dict(last._mapping) if last else None,
    }


@router.get("/units")
async def list_units(db: AsyncSession = Depends(get_db)):
    """List semua ID Unit unik (untuk filter/referensi)."""
    rows = (await db.execute(text(
        "SELECT DISTINCT id_unit FROM yazu_dc_lighting ORDER BY id_unit"
    ))).fetchall()
    return [r[0] for r in rows]


@router.get("/pivot")
async def pivot(
    year: int = Query(None, description="Tahun, default tahun berjalan"),
    month: int = Query(None, ge=1, le=12, description="Bulan 1-12, default bulan berjalan"),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Pivot: baris = ID Unit, kolom = tanggal 1..akhir bulan, sel = HM terakhir hari itu."""
    today = datetime.now(TZ).date()
    y = year or today.year
    m = month or today.month
    if m == 12:
        next_first = date(y + 1, 1, 1)
    else:
        next_first = date(y, m + 1, 1)
    days_in_month = (next_first - date(y, m, 1)).days

    start_iso, end_iso = _month_range(y, m)

    try:
        rows2 = (await db.execute(text("""
            WITH latest AS (
              SELECT id_unit,
                     (waktu AT TIME ZONE 'Asia/Makassar')::date AS d,
                     hm,
                     waktu,
                     ROW_NUMBER() OVER (PARTITION BY id_unit, (waktu AT TIME ZONE 'Asia/Makassar')::date
                                        ORDER BY waktu DESC) AS rn
              FROM yazu_dc_lighting
              WHERE waktu >= :s AND waktu < :e
            )
            SELECT id_unit, EXTRACT(DAY FROM d)::int AS day, hm
            FROM latest WHERE rn = 1
        """), {"s": start_iso, "e": end_iso})).fetchall()
    except Exception as e:
        log.exception("yazu-dc pivot query error")
        raise HTTPException(500, f"pivot error: {e}")

    cells: dict[str, dict[int, int]] = {}
    units_order: list[str] = []
    for r in rows2:
        uid = r[0]
        if uid not in cells:
            cells[uid] = {}
            units_order.append(uid)
        cells[uid][r[1]] = r[2]

    return {
        "year": y,
        "month": m,
        "days_in_month": days_in_month,
        "units": units_order,
        "cells": cells,
    }


@router.get("/raw")
async def list_raw(
    year: int = Query(None),
    month: int = Query(None, ge=1, le=12),
    id_unit: str = Query(None),
    limit: int = Query(500, le=5000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """List raw rows dengan filter (untuk drill-down dari pivot)."""
    where = ["1=1"]
    params: dict = {"limit": limit, "offset": offset}
    if year and month:
        start_iso, end_iso = _month_range(year, month)
        params["s"], params["e"] = start_iso, end_iso
        where.append("waktu >= :s")
        where.append("waktu <  :e")
    if id_unit:
        params["uid"] = id_unit
        where.append("id_unit = :uid")
    sql = f"""
        SELECT id, waktu, id_unit, nama, nrp, lokasi, hm, layak_operasi,
               akurasi, link_lokasi, coment, apar,
               status_close, pic_close, nrp_close, tgl_close, action_comment
        FROM yazu_dc_lighting
        WHERE {' AND '.join(where)}
        ORDER BY waktu DESC
        LIMIT :limit OFFSET :offset
    """
    rows = (await db.execute(text(sql), params)).fetchall()
    return [dict(r._mapping) for r in rows]
