"""Sinkronisasi inspeksi R1BI dari CSV publik Google Sheets.
Tanggal acuan = H13 (tgl R1BI staff), fallback tanggal submit. Zona site +8."""
import csv
import datetime
import io
import re
import urllib.request

SHEET_CSV_URL = ("https://docs.google.com/spreadsheets/d/"
                 "1D4ss9lpPTrpqyaOcWORuXKqcFaUcFv4Jv9evxCiLgoU/export?format=csv")
SITE_TZ = datetime.timezone(datetime.timedelta(hours=8))
CHUNK = 500

UPSERT_COLS = ["submitted_at", "tanggal", "nama", "nrp", "jabatan",
               "section", "grade", "staff_ribi", "aktivitas", "lokasi",
               "job_desc", "bahaya_desc", "pengendalian_desc", "tgl_ribi",
               "foto_area_url", "foto_area_file", "foto_jsa_url", "foto_jsa_file"]


def _txt(v):
    if v is None:
        return None
    s = re.sub(r"\s+", " ", str(v)).strip()
    return s or None


def _file_id(url):
    if not url:
        return None
    m = re.search(r"[?&]id=([^&]+)", url) or re.search(r"/d/([^/]+)", url)
    return m.group(1) if m else None


def _parse_ts(v):
    dt = datetime.datetime.strptime(v.strip(), "%d/%m/%Y %H:%M:%S")
    return dt.replace(tzinfo=SITE_TZ)


def _parse_date(v):
    """Ambil DD/MM/YYYY dari teks bebas (abaikan sisanya)."""
    if not v:
        return None
    m = re.search(r"(\d{1,2})/(\d{1,2})/(\d{4})", str(v))
    if not m:
        return None
    try:
        d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
        return datetime.date(y, mo, d)
    except ValueError:
        return None


def fetch_rows():
    req = urllib.request.Request(SHEET_CSV_URL, headers={"User-Agent": "mte-sync/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        text = r.read().decode("utf-8-sig", errors="replace")
    return list(csv.reader(io.StringIO(text)))


def clean_row(r):
    if len(r) < 16:
        raise ValueError(f"kolom kurang ({len(r)})")
    ts = _parse_ts(r[0])
    tgl = _parse_date(r[13]) or ts.date()
    out = {
        "submitted_at": ts,
        "tanggal": tgl,
        "nama": _txt(r[2]), "nrp": _txt(r[3]) or "",
        "jabatan": _txt(r[4]), "section": _txt(r[5]), "grade": _txt(r[6]),
        "staff_ribi": _txt(r[7]), "aktivitas": _txt(r[8]),
        "lokasi": _txt(r[9]), "job_desc": _txt(r[10]),
        "bahaya_desc": _txt(r[11]), "pengendalian_desc": _txt(r[12]),
        "tgl_ribi": _parse_date(r[13]),
        "foto_area_url": _txt(r[14]), "foto_jsa_url": _txt(r[15]),
    }
    out["foto_area_file"] = _file_id(out["foto_area_url"])
    out["foto_jsa_file"] = _file_id(out["foto_jsa_url"])
    if not out["nama"]:
        raise ValueError("baris tanpa nama")
    return out


async def sync_db(db, by=""):
    from sqlalchemy import text
    raw = fetch_rows()
    data = raw[1:] if raw and raw[0] and raw[0][0].strip().lower() == "timestamp" else raw
    ok, fail, errors = 0, 0, []
    log = (await db.execute(text(
        "INSERT INTO safety_sync_log(source, synced_by) VALUES ('r1bi', :u) RETURNING id"),
        {"u": by})).scalar_one()
    await db.commit()
    batch = []
    try:
        for i, r in enumerate(data, start=2):
            if not r or all(not (c or "").strip() for c in r):
                continue
            try:
                batch.append(clean_row(r))
            except Exception as e:
                fail += 1
                if len(errors) < 20:
                    errors.append({"row": i, "error": str(e)})
            if len(batch) >= CHUNK:
                ok += await _flush(db, batch)
                batch = []
        if batch:
            ok += await _flush(db, batch)
        await db.execute(text(
            "UPDATE safety_sync_log SET finished_at=now(), fetched=:f, "
            "ok_rows=:o, fail_rows=:e WHERE id=:i"),
            {"f": len(data), "o": ok, "e": fail, "i": log})
        await db.commit()
    except Exception:
        await db.rollback()
        raise
    return {"fetched": len(data), "ok": ok, "fail": fail, "errors": errors}


async def _flush(db, batch):
    from sqlalchemy import text
    cols = UPSERT_COLS
    vals, params = [], {}
    for i, r in enumerate(batch):
        vals.append(f"({', '.join(f':{c}_{i}' for c in cols)})")
        for c in cols:
            params[f"{c}_{i}"] = r[c]
    sets = ", ".join(f"{c}=EXCLUDED.{c}" for c in cols
                     if c not in ("submitted_at", "nrp", "nama"))
    await db.execute(text(
        f"INSERT INTO safety_r1bi({', '.join(cols)}) VALUES {', '.join(vals)} "
        f"ON CONFLICT (submitted_at, nrp, nama) DO UPDATE SET "
        f"{sets}, synced_at=now()"), params)
    await db.commit()
    return len(batch)
