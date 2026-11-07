"""Yazu Pumping P2H — sync checklist inspeksi unit pompa dari Google Sheets.

Tiga kategori (tab berbeda di satu spreadsheet): primer / mhp / booster.
Konsep sama dengan yazu.py (P2H unit): fetch CSV publik → parse → upsert ke
tabel `yazu_pumping` (UNIQUE per kategori+waktu+id_unit), catat riwayat ke
`yazu_pumping_sync_log`.

Mapping kolom dilakukan **berdasarkan nama header** (bukan index) karena
urutan/kelengkapan kolom antar tab sedikit berbeda:

  Waktu, ID Unit, HM, Nama, NRP, Role, Lokasi, Link Lokasi, Akurasi,
  Fungsi Loto, Fungsi Emergency Stop, Fungsi Control Panel, Backlog,
  Level Oil Engine, Level Water Coolant, Level Grease Autolube,
  Kondisi Gland Packing, Fire Suppression, Apar, Komentar, Layak Operasi
  + khas per tab:
    primer  : Fungsi Attachment, Level Oli Vacuum
    mhp     : Level Oli Transmisi, Fungsi Attachment, Fungsi AC
    booster : Fungsi Panel Motor 355KW
"""
import csv
import io
import logging
from datetime import datetime, date
from zoneinfo import ZoneInfo

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user, require_menu
from app.db.session import get_db

router = APIRouter(prefix="/v1/yazu-pumping", tags=["yazu-pumping"])
log = logging.getLogger("yazu-pumping")

WAKTU_FMT = "%d/%m/%Y %H:%M:%S"
TZ = ZoneInfo("Asia/Makassar")

KATEGORI = ("primer", "mhp", "booster")

# Header sheet (dinormalkan: huruf kecil, spasi→_) → kolom DB.
HEADER_MAP: dict[str, str] = {
    "waktu": "waktu",
    "id_unit": "id_unit",
    "hm": "hm",
    "nama": "nama",
    "nrp": "nrp",
    "role": "role",
    "lokasi": "lokasi",
    "link_lokasi": "link_lokasi",
    "akurasi": "akurasi",
    "fungsi_loto": "fungsi_loto",
    "fungsi_emergency_stop": "fungsi_emergency_stop",
    "fungsi_control_panel": "fungsi_control_panel",
    "backlog": "backlog",
    "level_oil_engine": "level_oil_engine",
    "level_water_coolant": "level_water_coolant",
    "level_grease_autolube": "level_grease_autolube",
    "kondisi_gland_packing": "kondisi_gland_packing",
    "fire_suppression": "fire_suppression",
    "apar": "apar",
    "komentar": "komentar",
    "layak_operasi": "layak_operasi",
    # khas per kategori
    "fungsi_attachment": "fungsi_attachment",
    "level_oli_vacuum": "level_oli_vacuum",
    "level_oli_transmisi": "level_oli_transmisi",
    "fungsi_ac": "fungsi_ac",
    "fungsi_panel_motor_355kw": "fungsi_panel_motor_355kw",
}

INT_COLS = {"hm", "akurasi"}

# Semua kolom data (kecuali kategori & waktu & id_unit) — dipakai untuk
# membangun INSERT/UPSERT dinamis.
DATA_COLS = [
    "waktu", "id_unit", "hm", "nama", "nrp", "role", "lokasi", "link_lokasi",
    "akurasi", "fungsi_loto", "fungsi_emergency_stop", "fungsi_control_panel",
    "backlog", "level_oil_engine", "level_water_coolant",
    "level_grease_autolube", "kondisi_gland_packing", "fire_suppression",
    "apar", "komentar", "layak_operasi", "fungsi_attachment",
    "level_oli_vacuum", "level_oli_transmisi", "fungsi_ac",
    "fungsi_panel_motor_355kw",
]


def _month_range(y: int, m: int) -> tuple[datetime, datetime]:
    start = datetime(y, m, 1, 0, 0, 0, tzinfo=TZ)
    if m == 12:
        end = datetime(y + 1, 1, 1, 0, 0, 0, tzinfo=TZ)
    else:
        end = datetime(y, m + 1, 1, 0, 0, 0, tzinfo=TZ)
    return start, end


def _to_int(v: str | None) -> int | None:
    if not v or not v.strip():
        return None
    try:
        return int(float(v.strip()))
    except ValueError:
        return None


def _to_str(v: str | None) -> str | None:
    if v is None:
        return None
    v = v.strip()
    return v or None


def _parse_waktu(v: str) -> datetime | None:
    """Parse '26/05/2026 22:25:18' → datetime tz-aware WITA (jam lokal site)."""
    if not v or not v.strip():
        return None
    try:
        return datetime.strptime(v.strip(), WAKTU_FMT).replace(tzinfo=TZ)
    except ValueError:
        return None


def _norm_header(h: str) -> str:
    """'Level Oil Engine' → 'level_oil_engine' (uppercase, spasi→_)."""
    return h.strip().lower().replace(" ", "_")


def parse_rows(csv_text: str, kategori: str) -> list[dict]:
    """Parse CSV → list dict siap insert untuk satu kategori.

    Mengandalkan nama header agar tahan perbedaan urutan/kolom antar tab.
    """
    reader = csv.reader(io.StringIO(csv_text))
    header = next(reader, None)
    if not header:
        return []
    # index CSV → kolom DB
    col_of: dict[int, str] = {}
    for i, h in enumerate(header):
        key = HEADER_MAP.get(_norm_header(h))
        if key:
            col_of[i] = key

    rows: list[dict] = []
    for raw in reader:
        if not raw or not any(c.strip() for c in raw):
            continue
        d: dict = {"kategori": kategori}
        for i, key in col_of.items():
            val = raw[i] if len(raw) > i else ""
            d[key] = _to_int(val) if key in INT_COLS else _to_str(val)
        w = d.get("waktu")
        # `waktu` masih string di sini — parse.
        w = _parse_waktu(d.get("waktu") or "")
        if not w:
            continue
        uid = d.get("id_unit")
        if not uid:
            continue
        d["waktu"] = w
        rows.append(d)
    return rows


async def fetch_csv(kategori: str) -> str:
    async with httpx.AsyncClient(timeout=60) as c:
        r = await c.get(
            settings.yazu_pumping_csv_url(kategori),
            headers={"User-Agent": "MTE-YazuSync/1.0"},
        )
        r.raise_for_status()
        return r.text


async def do_sync(db: AsyncSession) -> dict:
    """Fetch + parse + upsert ketiga kategori. Return summary dict."""
    started = datetime.now(ZoneInfo("UTC"))
    params = ",".join(f":{c}" for c in DATA_COLS)
    col_list = "kategori," + ",".join(DATA_COLS)
    param_list = ":kategori," + params
    update_list = ",".join(
        f"{c}=EXCLUDED.{c}" for c in DATA_COLS if c not in ("waktu", "id_unit")
    )
    sql = f"""
        INSERT INTO yazu_pumping ({col_list})
        VALUES ({param_list})
        ON CONFLICT (kategori, waktu, id_unit)
        DO UPDATE SET {update_list}, synced_at = NOW()
    """

    total = 0
    upserted = 0
    errors: list[str] = []
    try:
        for kategori in KATEGORI:
            csv_text = await fetch_csv(kategori)
            rows = parse_rows(csv_text, kategori)
            total += len(rows)
            batch = 200
            for i in range(0, len(rows), batch):
                chunk = rows[i:i + batch]
                await db.execute(text(sql), chunk)
                upserted += len(chunk)
        await db.execute(text("""
            INSERT INTO yazu_pumping_sync_log
              (started_at, finished_at, status, rows_total, rows_upserted, error_msg)
            VALUES (:s, NOW(), 'success', :t, :u, NULL)
        """), {"s": started, "t": total, "u": upserted})
        await db.commit()
    except Exception as e:  # catat kegagalan agar terlihat di /stats
        log.exception("yazu-pumping sync error")
        errors.append(str(e))
        await db.rollback()
        await db.execute(text("""
            INSERT INTO yazu_pumping_sync_log
              (started_at, finished_at, status, rows_total, rows_upserted, error_msg)
            VALUES (:s, NOW(), 'error', :t, :u, :e)
        """), {"s": started, "t": total, "u": upserted, "e": "; ".join(errors)[:2000]})
        await db.commit()
        return {"status": "error", "error_msg": "; ".join(errors),
                "rows_total": total, "rows_upserted": upserted}

    return {"status": "success", "rows_total": total, "rows_upserted": upserted}


# ─── Endpoints ────────────────────────────────────────────

@router.post("/sync", dependencies=[Depends(require_menu("yazupumping", "add"))])
async def sync_now(db: AsyncSession = Depends(get_db)):
    """Trigger manual sync ketiga kategori dari Google Sheets."""
    try:
        return await do_sync(db)
    except httpx.HTTPError as e:
        raise HTTPException(502, f"fetch gagal: {e}")


@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db)):
    """Status sync terakhir + total baris per kategori."""
    last = (await db.execute(text("""
        SELECT started_at, finished_at, status, rows_total, rows_upserted, error_msg
        FROM yazu_pumping_sync_log ORDER BY id DESC LIMIT 1
    """))).fetchone()
    total = (await db.execute(text("SELECT COUNT(*) FROM yazu_pumping"))).scalar()
    last_data = (await db.execute(text("SELECT MAX(waktu) FROM yazu_pumping"))).scalar()
    units = (await db.execute(
        text("SELECT COUNT(DISTINCT id_unit) FROM yazu_pumping"))).scalar()
    per_kat = (await db.execute(text("""
        SELECT kategori, COUNT(*) AS n, COUNT(DISTINCT id_unit) AS units
        FROM yazu_pumping GROUP BY kategori
    """))).mappings().all()
    return {
        "total_rows": total,
        "total_units": units,
        "last_data_waktu": last_data,
        "last_sync": dict(last._mapping) if last else None,
        "per_kategori": {r["kategori"]: {"rows": r["n"], "units": r["units"]}
                         for r in per_kat},
    }


@router.get("/units")
async def list_units(
    kategori: str = Query(None, description="primer|mhp|booster (opsional)"),
    db: AsyncSession = Depends(get_db),
):
    """List ID Unit unik (opsional per kategori)."""
    if kategori:
        rows = (await db.execute(text(
            "SELECT DISTINCT id_unit FROM yazu_pumping WHERE kategori = :k "
            "ORDER BY id_unit"
        ), {"k": kategori})).fetchall()
    else:
        rows = (await db.execute(text(
            "SELECT DISTINCT id_unit FROM yazu_pumping ORDER BY id_unit"
        ))).fetchall()
    return [r[0] for r in rows]


@router.get("/pivot")
async def pivot(
    kategori: str = Query(..., description="primer|mhp|booster"),
    year: int = Query(None, description="Tahun, default tahun berjalan"),
    month: int = Query(None, ge=1, le=12, description="Bulan 1-12"),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """Pivot: baris = ID Unit, kolom = tanggal, sel = HM terakhir hari itu."""
    if kategori not in KATEGORI:
        raise HTTPException(400, f"kategori tidak valid: {kategori}")
    today = datetime.now(TZ).date()
    y = year or today.year
    m = month or today.month
    next_first = date(y + 1, 1, 1) if m == 12 else date(y, m + 1, 1)
    days_in_month = (next_first - date(y, m, 1)).days
    start_iso, end_iso = _month_range(y, m)

    try:
        rows2 = (await db.execute(text("""
            WITH latest AS (
              SELECT id_unit,
                     (waktu AT TIME ZONE 'Asia/Makassar')::date AS d,
                     hm, waktu,
                     ROW_NUMBER() OVER (
                       PARTITION BY id_unit, (waktu AT TIME ZONE 'Asia/Makassar')::date
                       ORDER BY waktu DESC) AS rn
              FROM yazu_pumping
              WHERE kategori = :k AND waktu >= :s AND waktu < :e
            )
            SELECT id_unit, EXTRACT(DAY FROM d)::int AS day, hm
            FROM latest WHERE rn = 1
        """), {"k": kategori, "s": start_iso, "e": end_iso})).fetchall()
    except Exception as e:
        log.exception("yazu-pumping pivot query error")
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
        "kategori": kategori,
        "year": y,
        "month": m,
        "days_in_month": days_in_month,
        "units": units_order,
        "cells": cells,
    }


@router.get("/raw")
async def list_raw(
    kategori: str = Query(None),
    year: int = Query(None),
    month: int = Query(None, ge=1, le=12),
    id_unit: str = Query(None),
    limit: int = Query(500, le=5000),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _user=Depends(get_current_user),
):
    """List raw rows dengan filter (drill-down dari pivot)."""
    where = ["1=1"]
    params: dict = {"limit": limit, "offset": offset}
    if kategori:
        params["k"] = kategori
        where.append("kategori = :k")
    if year and month:
        start_iso, end_iso = _month_range(year, month)
        params["s"], params["e"] = start_iso, end_iso
        where.append("waktu >= :s")
        where.append("waktu <  :e")
    if id_unit:
        params["uid"] = id_unit
        where.append("id_unit = :uid")
    sql = f"""
        SELECT id, kategori, waktu, id_unit, hm, nama, nrp, role, lokasi,
               link_lokasi, akurasi, fungsi_loto, fungsi_emergency_stop,
               fungsi_control_panel, backlog, level_oil_engine,
               level_water_coolant, level_grease_autolube,
               kondisi_gland_packing, fire_suppression, apar, komentar,
               layak_operasi, fungsi_attachment, level_oli_vacuum,
               level_oli_transmisi, fungsi_ac, fungsi_panel_motor_355kw
        FROM yazu_pumping
        WHERE {' AND '.join(where)}
        ORDER BY waktu DESC
        LIMIT :limit OFFSET :offset
    """
    rows = (await db.execute(text(sql), params)).fetchall()
    return [dict(r._mapping) for r in rows]
