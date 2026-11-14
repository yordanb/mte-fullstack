"""Minute of Meeting 2 — format weekly SPEX Pumping.

Tabel flat mirip Excel: NO/ISSUED/NEED SUPPORT/BY/PIC/DUE DATE/STATUS/REMARK.
Fitur: CRUD meeting + item, carry-forward item OPEN/PROGRESS ke meeting baru,
import Excel format MOM weekly, export Excel dengan layout yang sama.
"""
import io
import re
from datetime import date, timedelta

import openpyxl
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, require_role
from app.db.session import get_db

router = APIRouter(prefix="/v1/mom2", tags=["mom2"])

STATUSES = ('open', 'progress', 'close')

# ─── Models ───────────────────────────────────────────────

class MeetingIn(BaseModel):
    period: str
    meeting_date: date
    participants: str | None = None
    carry: bool = False          # salin item open/progress dari meeting terakhir sebelum yang baru
    source_meeting_id: int | None = None  # opsional: carry dari meeting tertentu


class MeetingPatch(BaseModel):
    period: str | None = None
    week: int | None = None
    meeting_date: date | None = None
    participants: str | None = None
    status: str | None = None


class ItemIn(BaseModel):
    topic: str | None = None
    description: str
    reporter: str | None = None
    pic: str | None = None
    due_date: date | None = None
    due_flex: bool = False
    due_text: str | None = None
    status: str = 'open'
    remark: str | None = None


class ItemPatch(BaseModel):
    seq: int | None = None
    topic: str | None = None
    description: str | None = None
    reporter: str | None = None
    pic: str | None = None
    due_date: date | None = None
    due_flex: bool | None = None
    due_text: str | None = None
    status: str | None = None
    remark: str | None = None
    clear_due: bool = False   # hapus due date (set NULL)


# ─── Helpers ──────────────────────────────────────────────

_WEEK_RE = re.compile(r'^\s*W\s*(\d+)\b', re.IGNORECASE)
_MONTH_NAMES = {
    'januari': 1, 'februari': 2, 'maret': 3, 'april': 4, 'mei': 5, 'juni': 6,
    'juli': 7, 'agustus': 8, 'september': 9, 'oktober': 10, 'november': 11,
    'desember': 12,
}


def split_period(period: str) -> tuple[int | None, int | None]:
    """'W2 November 2026' → (week=2, month=11). Toleran terhadap typo tahun."""
    m = _WEEK_RE.match(period)
    week = int(m.group(1)) if m else None
    month = None
    low = period.lower()
    for name, num in _MONTH_NAMES.items():
        if name in low:
            month = num
            break
    return week, month


def parse_due(raw: str | None, ctx_month: int | None = None,
              ctx_year: int | None = None) -> tuple[date | None, bool, str | None]:
    """Pars kolom DUE DATE teks bebas → (date, flex, teks_asli).

    - None/''/'*'/'-'  → (None, False, None)
    - '21/11/2026'     → (21 Nov, False, raw)
    - '21/22/2026'     → rentang hari 21–22 pada bulan konteks → (21, True, raw)
    - '21/22/11/2026'  → rentang hari 21–22 Nov → (21 Nov, True, raw)
    """
    if raw is None:
        return None, False, None
    s = str(raw).strip()
    if not s or s in ('*', '-', '–', 'x', 'X'):
        return None, False, None
    parts = [p.strip() for p in s.split('/') if p.strip()]
    # dd/dd/mm/yyyy → rentang dua hari
    if len(parts) == 4 and all(p.isdigit() for p in parts):
        d1, d2, mo, yr = (int(p) for p in parts)
        flex = True
        if mo > 12:  # dd/mm/dd/yyyy yang aneh — tukar
            mo, yr = int(parts[2]), yr
        try:
            return date(yr, mo, d1), flex, s
        except ValueError:
            return None, True, s
    # dd/dd/yyyy — prioritas dd/mm (lokal), fallback mm/dd (US), terakhir rentang hari
    # pada bulan konteks (mis. '21/22/2026' = 21–22 Nov).
    if len(parts) == 3 and all(p.isdigit() for p in parts):
        a, b, yr = (int(p) for p in parts)
        try:                              # dd/mm/yyyy
            return date(yr, b, a), False, s
        except ValueError:
            pass
        try:                              # mm/dd/yyyy
            return date(yr, a, b), False, s
        except ValueError:
            pass
        mo = ctx_month or 1               # dua-duanya hari → rentang hari, bulan konteks
        try:
            return date(yr, mo, a), True, s
        except ValueError:
            return None, True, s
    return None, True, s  # teks tak dikenal: simpan asli, tandai fleksibel


def parse_meeting_date(raw) -> date | None:
    """'Sabtu, 14 November 2026' atau datetime → date."""
    if raw is None:
        return None
    if hasattr(raw, 'date'):
        return raw.date()  # type: ignore[attr-defined]
    if hasattr(raw, 'year') and not isinstance(raw, str):
        return raw  # type: ignore[return-value]
    s = str(raw).strip()
    m = re.search(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})', s)
    if m:
        month = _MONTH_NAMES.get(m.group(2).lower())
        if month:
            try:
                return date(int(m.group(3)), month, int(m.group(1)))
            except ValueError:
                return None
    m = re.match(r'^(\d{4})-(\d{2})-(\d{2})', s)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            return None
    return None


def next_period(period: str, meeting_date: date) -> tuple[str, date]:
    """'W2 November 2026' → 'W3 November 2026' (+7 hari); W5/W6 → W1 bulan berikutnya."""
    nxt = meeting_date + timedelta(days=7)
    m = _WEEK_RE.match(period)
    week = int(m.group(1)) if m else 0
    if 1 <= week < 5:
        base_month = next((num for name, num in _MONTH_NAMES.items()
                           if name in period.lower()), None)
        if base_month:
            month_name = next(n for n, num in _MONTH_NAMES.items()
                              if num == base_month).capitalize()
            return f'W{week + 1} {month_name} {meeting_date.year}', nxt
    month_name = next(n for n, num in _MONTH_NAMES.items() if num == nxt.month).capitalize()
    return f'W1 {month_name} {nxt.year}', nxt


def _month_name(num: int) -> str:
    return next(n for n, num_ in _MONTH_NAMES.items() if num_ == num).capitalize()


async def _carry_items(db: AsyncSession, new_mid: int, src_mid: int):
    """Salin item open/progress dari meeting sumber ke meeting baru."""
    src = (await db.execute(text(
        "SELECT * FROM mom2_items WHERE meeting_id=:m AND status <> 'close' ORDER BY seq, id"),
        {"m": src_mid})).mappings().all()
    for it in src:
        max_seq = (await db.execute(text(
            "SELECT COALESCE(MAX(seq), 0) + 1 FROM mom2_items WHERE meeting_id=:m"),
            {"m": new_mid})).scalar()
        await db.execute(text("""
            INSERT INTO mom2_items(meeting_id, seq, topic, description, reporter, pic,
                                   due_date, due_flex, due_text, status, remark, carried_from_id)
            VALUES (:m, :seq, :topic, :desc, :rep, :pic, :due, :flex, :dtext, 'open', :remark, :cfrom)
        """), {"m": new_mid, "seq": max_seq, "topic": it["topic"], "desc": it["description"],
               "rep": it["reporter"], "pic": it["pic"], "due": it["due_date"],
               "flex": it["due_flex"], "dtext": it["due_text"], "remark": it["remark"],
               "cfrom": it["id"]})


# ─── Meetings ─────────────────────────────────────────────

@router.get("/meetings")
async def list_meetings(status: str | None = Query(None),
                        db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    conds, p = [], {}
    if status:
        conds.append("m.status = :st"); p["st"] = status
    where = f"WHERE {' AND '.join(conds)}" if conds else ""
    rows = (await db.execute(text(f"""
        SELECT m.*,
               COUNT(i.id) AS total_items,
               COUNT(i.id) FILTER (WHERE i.status <> 'close') AS open_items
        FROM mom2_meetings m
        LEFT JOIN mom2_items i ON i.meeting_id = m.id
        {where}
        GROUP BY m.id
        ORDER BY m.meeting_date DESC
    """), p)).mappings().all()
    return {"data": [dict(r) for r in rows]}


@router.get("/next")
async def next_meeting(db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    """Saran periode + tanggal untuk meeting berikutnya (dari meeting terakhir)."""
    last = (await db.execute(text(
        "SELECT id, period, meeting_date FROM mom2_meetings ORDER BY meeting_date DESC LIMIT 1")
    )).mappings().first()
    if not last:
        t = date.today()
        return {"data": {"period": f"W1 {_month_name(t.month)} {t.year}",
                         "week": 1, "meeting_date": t.isoformat(), "source_meeting_id": None}}
    period, nxt = next_period(last["period"], last["meeting_date"])
    m = _WEEK_RE.match(period)
    week = int(m.group(1)) if m else None
    return {"data": {"period": period, "week": week, "meeting_date": nxt.isoformat(),
                     "source_meeting_id": last["id"], "source_period": last["period"],
                     "participants": None}}


@router.post("/meetings", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def create_meeting(body: MeetingIn, db: AsyncSession = Depends(get_db),
                         user=Depends(get_current_user)):
    week, _ = split_period(body.period)
    src_id = body.source_meeting_id
    if body.carry and not src_id:
        last = (await db.execute(text(
            "SELECT id FROM mom2_meetings WHERE meeting_date < :d ORDER BY meeting_date DESC LIMIT 1"),
            {"d": body.meeting_date})).mappings().first()
        src_id = last["id"] if last else None
    res = await db.execute(text("""
        INSERT INTO mom2_meetings(period, week, meeting_date, participants, status, created_by)
        VALUES (:p, :w, :d, :part, 'open', :u) RETURNING id
    """), {"p": body.period.strip(), "w": week, "d": body.meeting_date,
           "part": body.participants, "u": user["username"]})
    new_mid = res.scalar_one()
    if body.carry and src_id:
        await _carry_items(db, new_mid, src_id)
    await db.commit()
    return {"id": new_mid}


@router.get("/meetings/{mid}")
async def get_meeting(mid: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    m = (await db.execute(text("SELECT * FROM mom2_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not m:
        raise HTTPException(404, "Meeting tidak ditemukan")
    items = (await db.execute(text(
        "SELECT * FROM mom2_items WHERE meeting_id=:m ORDER BY seq, id"), {"m": mid})).mappings().all()
    out = dict(m)
    out["items"] = [dict(i) for i in items]
    return out


@router.patch("/meetings/{mid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_meeting(mid: int, body: MeetingPatch, db: AsyncSession = Depends(get_db),
                        user=Depends(get_current_user)):
    allowed = ("period", "week", "participants", "status")
    sets, p = [], {"id": mid}
    for k in allowed:
        v = getattr(body, k)
        if v is not None:
            if k == "status" and v not in ('open', 'closed'):
                raise HTTPException(400, "Status harus 'open' atau 'closed'")
            sets.append(f"{k}=:{k}"); p[k] = v
    if body.meeting_date is not None:
        sets.append("meeting_date=:d"); p["d"] = body.meeting_date
    if body.period is not None:
        week, _ = split_period(body.period)
        sets.append("week=:w"); p["w"] = week
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE mom2_meetings SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Meeting tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/meetings/{mid}", dependencies=[Depends(require_role("admin"))])
async def delete_meeting(mid: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM mom2_meetings WHERE id=:id"), {"id": mid})
    if res.rowcount == 0:
        raise HTTPException(404, "Meeting tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.post("/meetings/{mid}/carry", dependencies=[Depends(require_role("inputer", "admin"))])
async def carry_into(mid: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    """Carry item open/progress dari meeting sebelumnya ke meeting {mid}."""
    cur = (await db.execute(text(
        "SELECT meeting_date FROM mom2_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not cur:
        raise HTTPException(404, "Meeting tidak ditemukan")
    prev = (await db.execute(text("""
        SELECT id FROM mom2_meetings
        WHERE meeting_date < :d AND id <> :id
        ORDER BY meeting_date DESC LIMIT 1
    """), {"d": cur["meeting_date"], "id": mid})).mappings().first()
    if not prev:
        raise HTTPException(400, "Tidak ada meeting sebelumnya untuk di-carry")
    n = (await db.execute(text(
        "SELECT COUNT(*) FROM mom2_items WHERE meeting_id=:m AND status <> 'close'"),
        {"m": prev["id"]})).scalar()
    if n == 0:
        raise HTTPException(400, "Meeting sebelumnya tidak punya item OPEN/PROGRESS")
    await _carry_items(db, mid, prev["id"])
    await db.commit()
    return {"ok": True, "carried": n}


# ─── Items ────────────────────────────────────────────────

@router.post("/meetings/{mid}/items", dependencies=[Depends(require_role("inputer", "admin"))], status_code=201)
async def add_item(mid: int, body: ItemIn, db: AsyncSession = Depends(get_db),
                   user=Depends(get_current_user)):
    if body.status not in STATUSES:
        raise HTTPException(400, f"Status harus salah satu {STATUSES}")
    seq = (await db.execute(text(
        "SELECT COALESCE(MAX(seq), 0) + 1 FROM mom2_items WHERE meeting_id=:m"), {"m": mid})).scalar()
    res = await db.execute(text("""
        INSERT INTO mom2_items(meeting_id, seq, topic, description, reporter, pic,
                               due_date, due_flex, due_text, status, remark)
        VALUES (:m, :seq, :topic, :desc, :rep, :pic, :due, :flex, :dtext, :st, :remark)
        RETURNING id
    """), {"m": mid, "seq": seq, "topic": body.topic, "desc": body.description.strip(),
           "rep": body.reporter, "pic": body.pic, "due": body.due_date,
           "flex": body.due_flex, "dtext": body.due_text, "st": body.status,
           "remark": body.remark})
    await db.commit()
    return {"id": res.scalar_one()}


@router.patch("/items/{iid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def patch_item(iid: int, body: ItemPatch, db: AsyncSession = Depends(get_db),
                     user=Depends(get_current_user)):
    allowed = ("seq", "topic", "description", "reporter", "pic", "due_text", "status", "remark")
    sets, p = [], {"id": iid}
    for k in allowed:
        v = getattr(body, k)
        if v is not None and not (k == "description" and not str(v).strip()):
            if k == "status" and v not in STATUSES:
                raise HTTPException(400, f"Status harus salah satu {STATUSES}")
            sets.append(f"{k}=:{k}"); p[k] = v
    if body.clear_due:
        sets.append("due_date=NULL"); sets.append("due_flex=FALSE"); sets.append("due_text=NULL")
    if body.due_date is not None:
        sets.append("due_date=:due"); p["due"] = body.due_date
        sets.append("due_flex=FALSE"); sets.append("due_text=NULL")
    if body.due_flex is not None:
        sets.append("due_flex=:flex"); p["flex"] = body.due_flex
    if not sets:
        raise HTTPException(400, "Tidak ada field yang diubah")
    res = await db.execute(text(f"UPDATE mom2_items SET {', '.join(sets)} WHERE id=:id"), p)
    if res.rowcount == 0:
        raise HTTPException(404, "Item tidak ditemukan")
    await db.commit()
    return {"ok": True}


@router.delete("/items/{iid}", dependencies=[Depends(require_role("inputer", "admin"))])
async def delete_item(iid: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    res = await db.execute(text("DELETE FROM mom2_items WHERE id=:id"), {"id": iid})
    if res.rowcount == 0:
        raise HTTPException(404, "Item tidak ditemukan")
    await db.commit()
    return {"ok": True}


# ─── Import Excel (format MOM SPEX PUMP weekly) ───────────

_HDR = ('NO', 'ISSUED', 'NEED SUPPORT', 'BY', 'PIC', 'DUE DATE', 'STATUS', 'REMARK')


def _find_header(ws):
    """Cari baris header: 8 sel pertama mengandung NO/ISSUED/NEED SUPPORT."""
    for r in range(1, min(ws.max_row, 30) + 1):
        vals = [str(ws.cell(row=r, column=c).value or '').strip().upper() for c in range(1, 12)]
        if 'NO' in vals and 'ISSUED' in vals and any('NEED' in v for v in vals):
            cols = {}
            for c in range(1, ws.max_column + 1):
                v = str(ws.cell(row=r, column=c).value or '').strip().upper()
                if v in _HDR and v not in cols:
                    cols[v] = c
            return r, cols
    return None, None


@router.post("/import", dependencies=[Depends(require_role("inputer", "admin"))])
async def import_xlsx(file: UploadFile = File(...), db: AsyncSession = Depends(get_db),
                      user=Depends(get_current_user)):
    """Import satu file MOM weekly. Bila meeting periode yang sama sudah ada → error
    (pakai PATCH/append manual); bila belum → buat meeting + items."""
    content = await file.read()
    try:
        wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
    except Exception as e:
        raise HTTPException(400, f"File Excel tidak bisa dibaca: {e}")
    ws = wb.active
    hdr_row, cols = _find_header(ws)
    if not cols or 'NEED SUPPORT' not in cols:
        raise HTTPException(400, "Header tabel (NO/ISSUED/NEED SUPPORT/...) tidak ditemukan di sheet pertama")

    # Blok judul di atas header
    title = period_raw = date_raw = participants_raw = None
    for r in range(1, hdr_row):
        for c in range(1, cols.get('NO', 2) + 1):
            v = ws.cell(row=r, column=c).value
            if v is None:
                continue
            s = str(v).strip()
            if s and title is None:
                title = s
            elif s and period_raw is None:
                period_raw = s
            elif s and date_raw is None and re.search(r'\d', s):
                date_raw = s
            elif s and participants_raw is None and s.upper().startswith('PIC'):
                participants_raw = re.sub(r'^PIC\s*:?\s*', '', s, flags=re.IGNORECASE)
    # Fallback berdasar posisi khas format (B2 judul, B3 periode, B4 tanggal, B5 PIC)
    if not title:
        title = str(ws.cell(row=2, column=2).value or 'MOM Weekly')
    if not period_raw:
        period_raw = str(ws.cell(row=3, column=2).value or '')
    meeting_date = parse_meeting_date(date_raw or ws.cell(row=4, column=2).value) or date.today()
    if not participants_raw:
        participants_raw = re.sub(r'^PIC\s*:?\s*', '', str(ws.cell(row=5, column=2).value or ''),
                                  flags=re.IGNORECASE) or None

    period = re.sub(r'\b(19|20)\d{2}\b', str(meeting_date.year), period_raw).strip()
    if not period:
        period = f"W1 {_month_name(meeting_date.month)} {meeting_date.year}"
    week, _ = split_period(period)

    dup = (await db.execute(text("SELECT id FROM mom2_meetings WHERE period=:p"), {"p": period})).scalar()
    if dup:
        raise HTTPException(409, f"Meeting periode '{period}' sudah ada (id {dup}). "
                                 f"Hapus dulu bila ingin mengimpor ulang.")

    res = await db.execute(text("""
        INSERT INTO mom2_meetings(period, week, meeting_date, participants, status, created_by)
        VALUES (:p, :w, :d, :part, 'open', :u) RETURNING id
    """), {"p": period, "w": week, "d": meeting_date, "part": participants_raw,
           "u": user["username"]})
    mid = res.scalar_one()

    warnings: list[str] = []
    seq = 0
    rows = 0
    for r in range(hdr_row + 1, ws.max_row + 1):
        desc = ws.cell(row=r, column=cols['NEED SUPPORT']).value
        status_raw = str(ws.cell(row=r, column=cols.get('STATUS', 1)).value or '').strip().upper()
        if desc is None and not status_raw:
            continue  # baris kosong
        desc = str(desc or '').strip()
        if not desc:
            continue
        rows += 1
        seq += 1
        topic = ws.cell(row=r, column=cols['ISSUED']).value if 'ISSUED' in cols else None
        topic = str(topic).strip() if topic is not None else None
        reporter = ws.cell(row=r, column=cols['BY']).value if 'BY' in cols else None
        reporter = str(reporter).strip() if reporter is not None else None
        pic = ws.cell(row=r, column=cols['PIC']).value if 'PIC' in cols else None
        pic = str(pic).strip() if pic is not None else None
        due_raw = ws.cell(row=r, column=cols['DUE DATE']).value if 'DUE DATE' in cols else None
        due, flex, due_text = parse_due(str(due_raw) if due_raw is not None else None,
                                        ctx_month=meeting_date.month, ctx_year=meeting_date.year)
        if due_text and flex:
            warnings.append(f"Baris {seq}: due date '{due_text}' ambigu/fleksibel — ditandai FLEX.")
        status = {'OPEN': 'open', 'PROGRESS': 'progress', 'CLOSE': 'close',
                  'CLOSED': 'close', 'DONE': 'close'}.get(status_raw, 'open')
        if status_raw and status_raw not in ('OPEN', 'PROGRESS', 'CLOSE', 'CLOSED', 'DONE'):
            warnings.append(f"Baris {seq}: status '{status_raw}' tidak dikenal, diset OPEN.")
        remark = ws.cell(row=r, column=cols['REMARK']).value if 'REMARK' in cols else None
        remark = str(remark).strip() if remark is not None else None
        await db.execute(text("""
            INSERT INTO mom2_items(meeting_id, seq, topic, description, reporter, pic,
                                   due_date, due_flex, due_text, status, remark)
            VALUES (:m, :seq, :topic, :desc, :rep, :pic, :due, :flex, :dtext, :st, :remark)
        """), {"m": mid, "seq": seq, "topic": topic, "desc": desc, "rep": reporter,
               "pic": pic, "due": due, "flex": flex, "dtext": due_text, "st": status,
               "remark": remark})
    if rows == 0:
        await db.rollback()
        raise HTTPException(400, "Tidak ada baris item yang bisa dibaca dari file ini")
    await db.commit()
    return {"meeting_id": mid, "period": period, "imported": rows, "warnings": warnings}


# ─── Export Excel (layout sama seperti format asli) ───────

@router.get("/meetings/{mid}/export")
async def export_xlsx(mid: int, db: AsyncSession = Depends(get_db), user=Depends(get_current_user)):
    m = (await db.execute(text("SELECT * FROM mom2_meetings WHERE id=:id"), {"id": mid})).mappings().first()
    if not m:
        raise HTTPException(404, "Meeting tidak ditemukan")
    items = (await db.execute(text(
        "SELECT * FROM mom2_items WHERE meeting_id=:m ORDER BY seq, id"), {"m": mid})).mappings().all()

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = re.sub(r'[\\/*?:\[\]]', '_', str(m["period"])[:31]) or 'MOM'

    _ID_MONTHS = ('', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
                  'Agustus', 'September', 'Oktober', 'November', 'Desember')
    _ID_DAYS = ('Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu')
    d = m["meeting_date"]
    date_id = f"{_ID_DAYS[d.weekday()]}, {d.day} {_ID_MONTHS[d.month]} {d.year}"

    ws['B2'] = 'MOM MEETING WEEKLY SPEX PUMPING'
    ws['B2'].font = openpyxl.styles.Font(bold=True, size=12)
    ws['B3'] = m["period"]
    ws['B4'] = date_id
    ws['B5'] = f"PIC : {m['participants']}" if m["participants"] else 'PIC :'
    for addr in ('B3', 'B4', 'B5'):
        ws[addr].font = openpyxl.styles.Font(size=10)

    headers = ('NO', 'ISSUED', 'NEED SUPPORT', 'BY', 'PIC', 'DUE DATE', 'STATUS', 'REMARK')
    hr = 7
    for i, h in enumerate(headers, start=2):
        c = ws.cell(row=hr, column=i, value=h)
        c.font = openpyxl.styles.Font(bold=True, size=10)
        c.border = openpyxl.styles.Border(
            left=openpyxl.styles.Side(style='thin'), right=openpyxl.styles.Side(style='thin'),
            top=openpyxl.styles.Side(style='thin'), bottom=openpyxl.styles.Side(style='thin'))
        c.alignment = openpyxl.styles.Alignment(horizontal='center', vertical='center')

    thin = openpyxl.styles.Side(style='thin')
    border = openpyxl.styles.Border(left=thin, right=thin, top=thin, bottom=thin)
    wrap = openpyxl.styles.Alignment(wrap_text=True, vertical='top')
    for idx, it in enumerate(items, start=1):
        r = hr + idx
        due_disp = it["due_text"] if it["due_flex"] and it["due_text"] else (
            it["due_date"].strftime('%d/%m/%Y') if it["due_date"] else '*')
        vals = (idx, it["topic"], it["description"], it["reporter"], it["pic"],
                due_disp, (it["status"] or 'open').upper(), it["remark"])
        for i, v in enumerate(vals, start=2):
            c = ws.cell(row=r, column=i, value=v)
            c.font = openpyxl.styles.Font(size=10)
            c.border = border
            c.alignment = wrap if i in (4, 9) else openpyxl.styles.Alignment(vertical='top', wrap_text=True)
        ws.row_dimensions[r].height = 28.8

    for col, w in zip('BCDEFGHI', (4.7, 21.4, 32.7, 18.6, 8.9, 14.2, 10.0, 25.7)):
        ws.column_dimensions[col].width = w
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    fname = f"MOM SPEX PUMP {m['period']}.xlsx".replace('/', '-')
    return StreamingResponse(buf, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                             headers={'Content-Disposition': f'attachment; filename="{fname}"'})
