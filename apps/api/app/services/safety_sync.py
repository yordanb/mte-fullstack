"""Sinkronisasi inspeksi safety 6 PAS dari CSV publik Google Sheets.
Sumber: Google Form (26 kolom). Timestamp DD/MM/YYYY, zona site WITA (+8)."""
import csv
import datetime
import io
import re
import urllib.request

SHEET_CSV_URL = ("https://docs.google.com/spreadsheets/d/"
                 "1Q8WiamEZAOIdzqI8fidEldOK3gynPEH7Pu5rK0Zv5iI/export?format=csv")
SITE_TZ = datetime.timezone(datetime.timedelta(hours=8))
CHUNK = 500

COLS = ["submitted_at", "pengawas_nama", "pengawas_nrp", "mekanik_nama",
        "mekanik_nrp", "grade", "section", "doc6pas_url", "bisa6pas",
        "p1_doa", "p2_apd", "p2_stretch", "p3_housekeeping", "p3_doc",
        "p3_desc", "p4_alat", "p4_doc", "p4_desc", "p5_prosedur", "vlog_url",
        "vlog_desc", "p6_tindakan", "p6_desc", "followup", "area_bomak",
        "job_desc"]


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
    # "08/01/2026 15:50:54" DD/MM/YYYY, waktu site WITA
    dt = datetime.datetime.strptime(v.strip(), "%d/%m/%Y %H:%M:%S")
    return dt.replace(tzinfo=SITE_TZ)


def fetch_rows():
    req = urllib.request.Request(SHEET_CSV_URL, headers={"User-Agent": "mte-sync/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        text = r.read().decode("utf-8-sig", errors="replace")
    return list(csv.reader(io.StringIO(text)))


def clean_row(r):
    """Kembalikan dict siap INSERT atau raise ValueError."""
    if len(r) < 26:
        raise ValueError(f"kolom kurang ({len(r)})")
    ts = _parse_ts(r[0])
    out = {
        "submitted_at": ts,
        "pengawas_nama": _txt(r[1]), "pengawas_nrp": _txt(r[2]) or "",
        "mekanik_nama": _txt(r[3]), "mekanik_nrp": _txt(r[4]) or "",
        "grade": _txt(r[5]), "section": _txt(r[6]),
        "doc6pas_url": _txt(r[7]), "bisa6pas": _txt(r[8]),
        "p1_doa": _txt(r[9]), "p2_apd": _txt(r[10]), "p2_stretch": _txt(r[11]),
        "p3_housekeeping": _txt(r[12]), "p3_doc": _txt(r[13]), "p3_desc": _txt(r[14]),
        "p4_alat": _txt(r[15]), "p4_doc": _txt(r[16]), "p4_desc": _txt(r[17]),
        "p5_prosedur": _txt(r[18]), "vlog_url": _txt(r[19]),
        "vlog_desc": _txt(r[20]), "p6_tindakan": _txt(r[21]), "p6_desc": _txt(r[22]),
        "followup": _txt(r[23]), "area_bomak": _txt(r[24]), "job_desc": _txt(r[25]),
    }
    out["doc6pas_file"] = _file_id(out["doc6pas_url"])
    out["vlog_file"] = _file_id(out["vlog_url"])
    if not out["mekanik_nama"] and not out["pengawas_nama"]:
        raise ValueError("baris tanpa nama")
    return out


UPSERT_COLS = ["submitted_at", "pengawas_nama", "pengawas_nrp", "mekanik_nama",
               "mekanik_nrp", "grade", "section", "doc6pas_url", "doc6pas_file",
               "bisa6pas", "p1_doa", "p2_apd", "p2_stretch", "p3_housekeeping",
               "p3_doc", "p3_desc", "p4_alat", "p4_doc", "p4_desc",
               "p5_prosedur", "vlog_url", "vlog_file", "vlog_desc",
               "p6_tindakan", "p6_desc", "followup", "area_bomak", "job_desc"]


async def sync_db(db, by=""):
    """Tarik CSV, bersihkan, upsert per chunk. Return dict statistik."""
    from sqlalchemy import text
    raw = fetch_rows()
    data = raw[1:] if raw and raw[0] and raw[0][0].strip().lower() == "timestamp" else raw
    ok, fail, errors = 0, 0, []
    log = (await db.execute(text(
        "INSERT INTO safety_sync_log(synced_by) VALUES (:u) RETURNING id"),
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
                     if c not in ("submitted_at", "mekanik_nrp", "pengawas_nrp"))
    await db.execute(text(
        f"INSERT INTO safety_pas({', '.join(cols)}) VALUES {', '.join(vals)} "
        f"ON CONFLICT (submitted_at, mekanik_nrp, pengawas_nrp) DO UPDATE SET "
        f"{sets}, synced_at=now()"), params)
    await db.commit()
    return len(batch)
