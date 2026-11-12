"""Hourmeter — pencatatan HM bulanan dari upload Excel (sheet HM_Manual).

Konsep: user meng-upload file Excel per bulan (format persis seperti
"hm pumping okt 26.xlsx"); system mengganti seluruh data periode tersebut.

Struktur sheet yang didukung:
  Baris judul   : sel tanggal tanggal-1 periode (mis. 2026-10-01) — boleh merged
  Baris header  : No | EGI | CN Unit | <HM opening (31 Agu)> | 1..31 (day) | Max
                  — kolom opening = datetime tepat di kiri kolom hari=1;
                  — kolom hari = datetime dengan .day berurutan 1..31
                    (tahun/bulan yang tersimpan di file boleh "kacau",
                     yang dipakai hanya angka hari-nya)
  Baris data    : EGI, CN, opening numeric, nilai HM sparse numeric per hari
"""
import io
import logging
from calendar import monthrange
from datetime import datetime, date

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, require_menu
from app.db.session import get_db

router = APIRouter(prefix="/v1/hourmeter", tags=["hourmeter"])
log = logging.getLogger("hourmeter")


def _cell_num(v) -> int | None:
    """Nilai numerik dari sel: int/float langsung; string diputuskan pemisahnya.

    Aturan pemisah (HM berformat naskah Indonesia):
    - koma & titik bersamaan → pemisah TERAKHIR adalah desimal ('1.234.567,8')
    - hanya koma → desimal bila ≤2 digit di belakang ('46,5'), selain itu ribuan ('46,383')
    - hanya titik → desimal bila ≤2 digit di belakang ('46383.5'), selain itu ribuan ('46.383')
    """
    if v is None or v == "":
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        f = float(v)
    else:
        s = str(v).strip().replace(" ", "").replace("\u00a0", "")
        if not s or s in ("-", "–", "."):
            return None
        if "," in s and "." in s:
            if s.rfind(",") > s.rfind("."):
                s = s.replace(".", "").replace(",", ".")   # 1.234.567,8
            else:
                s = s.replace(",", "")                     # 1,234.5
        elif "," in s:
            head, _, tail = s.rpartition(",")
            s = f"{head}.{tail}" if len(tail) <= 2 else s.replace(",", "")
        elif "." in s:
            head, _, tail = s.rpartition(".")
            s = s if len(tail) <= 2 else s.replace(".", "")
        try:
            f = float(s)
        except ValueError:
            return None
    return int(f)


def parse_hourmeter_xlsx(data: bytes) -> dict:
    """Parse sheet pertama yang berisi 'CN Unit'. Return dict terstruktur.

    Raise ValueError dengan pesan berbahasa Indonesia bila format tak dikenal.
    """
    from openpyxl import load_workbook

    wb = load_workbook(io.BytesIO(data), data_only=True, read_only=True)
    header_row_idx, ws_hdr = None, None
    for ws in wb.worksheets:
        rows = [list(r) for r in ws.iter_rows(values_only=True)]
        for i, row in enumerate(rows[:10]):
            if row and any(
                isinstance(v, str) and v.strip().upper() == "CN UNIT" for v in row
            ):
                header_row_idx, ws_hdr = i, rows
                break
        if header_row_idx is not None:
            break
    if header_row_idx is None:
        raise ValueError("Sheet dengan kolom 'CN Unit' tidak ditemukan di file Excel")
    hdr = ws_hdr[header_row_idx]

    # ── Periode: tanggal tanggal-1 bulan pada baris-baris di atas header ──
    period_date: datetime | None = None
    for i in range(header_row_idx):
        for v in ws_hdr[i]:
            if isinstance(v, datetime):
                period_date = v
                break
        if period_date is not None:
            break
    period = f"{period_date.year}-{period_date.month:02d}" if period_date else None

    # ── Kolom hari: datetime dengan .day==1, lalu berurutan naik ──
    day_cols: list[tuple[int, int]] = []          # (index kolom, day)
    opening_col: int | None = None
    start = None
    for j, v in enumerate(hdr):
        if isinstance(v, datetime) and 1 <= v.day <= 31:
            if v.day == 1:
                start = j
                break
    if start is None:
        raise ValueError(
            "Kolom hari tidak dikenali (butuh deret tanggal tampil '01'..'31' di baris header)"
        )
    day = 1
    j = start
    while j < len(hdr):
        v = hdr[j]
        if isinstance(v, datetime) and v.day == day:
            day_cols.append((j, day))
            day += 1
            j += 1
        else:
            break
    if day_cols:
        k = start - 1
        if k >= 0 and isinstance(hdr[k], datetime):
            opening_col = k

    # ── Kolom identitas ──
    cn_col = egi_col = None
    for j, v in enumerate(hdr):
        if isinstance(v, str):
            u = v.strip().upper()
            if u == "CN UNIT":
                cn_col = j
            elif u == "EGI":
                egi_col = j
    if cn_col is None:
        raise ValueError("Kolom 'CN Unit' tidak ditemukan di baris header")

    # ── Baris data ──
    units: list[dict] = []
    seen: set[str] = set()
    for row in ws_hdr[header_row_idx + 1:]:
        if cn_col >= len(row):
            continue
        cn = row[cn_col]
        if cn is None or str(cn).strip() == "":
            continue
        cn = str(cn).strip().upper().replace(" ", "")
        if cn in seen:
            continue
        seen.add(cn)
        egi = row[egi_col] if egi_col is not None and len(row) > egi_col else None
        egi = str(egi).strip() if egi is not None else None
        opening = _cell_num(row[opening_col]) if opening_col is not None else None
        vals: dict[int, int] = {}
        for j, d in day_cols:
            v = _cell_num(row[j]) if len(row) > j else None
            if v is not None:
                vals[d] = v
        units.append({"cn": cn, "egi": egi, "opening": opening, "vals": vals})

    if not units:
        raise ValueError("Tidak ada baris unit terbaca di file")
    return {"period": period, "units": units, "days": [d for _, d in day_cols]}


# ─── Endpoints ────────────────────────────────────────────

@router.post("/upload", dependencies=[Depends(require_menu("hourmeter", "add"))])
async def upload_hourmeter(
    file: UploadFile = File(...),
    year: int | None = Form(None),
    month: int | None = Form(None),
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Upload file Excel HM → ganti seluruh data periode tersebut.

    Periode dibaca dari file (baris judul); bila user memilih bulan/tahun di UI,
    dipakai sebagai validasi silang — mismatch ditolak agar tak salah periode.
    """
    raw = await file.read()
    try:
        parsed = parse_hourmeter_xlsx(raw)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        log.exception("parsing hourmeter xlsx gagal")
        raise HTTPException(400, f"File Excel tidak dapat dibaca: {e}")

    file_period = parsed["period"]
    if year and month:
        sel = f"{year}-{month:02d}"
        if file_period and file_period != sel:
            raise HTTPException(
                400,
                f"Periode file ({file_period}) tidak sama dengan pilihan ({sel}). "
                "Periksa pilihan bulan/tahun atau file yang diupload.",
            )
        period = sel
    else:
        if not file_period:
            raise HTTPException(
                400,
                "Periode tidak terbaca dari file — pilih Bulan & Tahun di UI, "
                "atau pastikan baris judul berisi tanggal periode.",
            )
        period = file_period

    units = parsed["units"]
    if not units:
        raise HTTPException(400, "Tidak ada baris CN Unit terbaca dari file")

    try:
        # Ganti seluruh periode (unit yang tidak ada di file baru ikut hilang)
        await db.execute(text("DELETE FROM hourmeter_daily WHERE period = :p"), {"p": period})
        await db.execute(text("DELETE FROM hourmeter_opening WHERE period = :p"), {"p": period})
        op = [{"p": period, "cn": u["cn"], "egi": u["egi"], "opening": u["opening"]} for u in units]
        await db.execute(text("""
            INSERT INTO hourmeter_opening(period, cn, egi, opening)
            VALUES (:p, :cn, :egi, :opening)
        """), op)
        vp = [
            {"p": period, "cn": u["cn"], "d": d, "v": v}
            for u in units for d, v in u["vals"].items()
        ]
        if vp:
            await db.execute(text("""
                INSERT INTO hourmeter_daily(period, cn, day, hm, updated_at)
                VALUES (:p, :cn, :d, :v, NOW())
            """), vp)
        nval = len(vp)
        await db.execute(text("""
            INSERT INTO hourmeter_upload_log(period, filename, rows_units, rows_values, status, uploaded_by)
            VALUES (:p, :f, :u, :v, 'success', :who)
        """), {"p": period, "f": file.filename, "u": len(units), "v": nval, "who": user["username"]})
        await db.commit()
    except Exception as e:
        await db.rollback()
        log.exception("gagal simpan hourmeter")
        raise HTTPException(500, f"gagal simpan: {e}")
    return {"ok": True, "period": period, "units": len(units), "values": nval}


@router.get("/stats")
async def stats(db: AsyncSession = Depends(get_db), _user=Depends(get_current_user)):
    """Daftar periode yang sudah di-upload + ringkasannya."""
    periods = (await db.execute(text("""
        SELECT o.period,
               COUNT(*)                          AS units,
               COALESCE(SUM(d.n), 0)             AS values_cnt,
               MAX(o.uploaded_at)                AS uploaded_at,
               MAX(o.uploaded_by)                AS uploaded_by
        FROM hourmeter_opening o
        LEFT JOIN LATERAL (
          SELECT COUNT(*) AS n FROM hourmeter_daily
          WHERE period = o.period AND cn = o.cn
        ) d ON TRUE
        GROUP BY o.period ORDER BY o.period DESC
    """))).mappings().all()
    logs = (await db.execute(text("""
        SELECT period, filename, rows_units, rows_values, status, error_msg, uploaded_by, uploaded_at
        FROM hourmeter_upload_log ORDER BY id DESC LIMIT 10
    """))).mappings().all()
    return {"periods": [dict(r) for r in periods], "logs": [dict(r) for r in logs]}


@router.get("/pivot")
async def pivot(
    year: int = Query(None), month: int = Query(None, ge=1, le=12),
    db: AsyncSession = Depends(get_db), _user=Depends(get_current_user),
):
    """Grid HM: baris = CN unit, kolom = hari, + opening & akhir & selisih."""
    today = date.today()
    year = year or today.year
    month = month or today.month
    days_in_month = monthrange(year, month)[1]
    period = f"{year}-{month:02d}"

    op_rows = (await db.execute(text("""
        SELECT cn, egi, opening FROM hourmeter_opening
        WHERE period = :p ORDER BY cn
    """), {"p": period})).mappings().all()
    val_rows = (await db.execute(text("""
        SELECT cn, day, hm FROM hourmeter_daily
        WHERE period = :p ORDER BY cn, day
    """), {"p": period})).fetchall()

    cells: dict[str, dict[int, int]] = {}
    for r in val_rows:
        cells.setdefault(r[0], {})[r[1]] = r[2]

    units = []
    for r in op_rows:
        cn = r["cn"]
        vals = cells.get(cn, {})
        opening = r["opening"]
        last_day = max(vals) if vals else None
        final = vals[last_day] if last_day is not None else opening
        delta = (final - opening) if (final is not None and opening is not None) else None
        units.append({
            "cn": cn, "egi": r["egi"], "opening": opening,
            "vals": {str(d): v for d, v in vals.items()},
            "last_day": last_day, "final": final, "delta": delta,
        })
    return {"period": period, "days_in_month": days_in_month, "units": units}


# ─── Ringkasan per unit (tab HM Dragflow) ─────────────────────────────────

@router.get("/summary")
async def summary(
    db: AsyncSession = Depends(get_db), _user=Depends(get_current_user),
):
    """HM per unit untuk daftar unit dragflow — SELALU dari database penuh.

    Endpoint ini sengaja TIDAK memakai filter bulan/tahun: HM Last RFU,
    Date RFU, dan HM Tercatat adalah kondisi TERAKHIR unit (tanggal terbesar
    di seluruh periode), karena angka itulah yang dipakai untuk mengukur
    lifetime. Mengganti bulan/tahun di UI tidak boleh mengubah nilainya.

    - `hm_last`/`hm_at`/`hm_date` = pembacaan RFU terakhir (tanggal terbesar).
      Fallback ke `opening` terakhir (Open bulan terbesar) hanya bila unit
      belum pernah punya pembacaan harian; Date RFU dibiarkan kosong.
    - `dc_hm`/`dc_date` = HM Daily Check (DC) terbaru dari aktivitas
      kategori "Daily Check Dragflow" (halaman Activity → tab DC Dragflow),
      dicocokkan lewat kode WP (`activities.cn`). Dipakai sebagai
      "HM (Daily Check)" pada rumus Lifetime.
    - `lifetime`   = HM Daily Check terbaru − pembacaan HM RFU terakhir.
    """
    # Daftar CN = semua unit yang pernah muncul (opening, pembacaan harian,
    # ATAU aktivitas DC Dragflow), sehingga unit tidak hilang hanya karena
    # periode berbeda atau karena HM-nya baru dicatat lewat Daily Check.
    rows = (await db.execute(text("""
        WITH dc_rank AS (
          -- HM DC: aktivitas kategori "Daily Check Dragflow" (halaman Activity
          -- → tab DC Dragflow), dicocokkan lewat kode WP pada `activities.cn`.
          -- Pencocokan kategori WAJIB sama dengan tab DC Dragflow di Activity
          -- (ILIKE '%Daily Check Dragflow%'), sebab teksnya bisa berbeda
          -- spasi/huruf besar-kecil/ada kata tambahan. Satu tanggal bisa punya
          -- dua shift; dipakai pembacaan terakhir (shift terbesar).
          SELECT cn, hm, date,
                 ROW_NUMBER() OVER (PARTITION BY cn
                     ORDER BY date DESC, shift DESC NULLS LAST,
                              created_at DESC) AS rn
          FROM activities
          WHERE hm IS NOT NULL
            AND cn IS NOT NULL
            AND category ILIKE '%Daily Check Dragflow%'
        ),
        dc AS (
          SELECT cn, hm, date FROM dc_rank WHERE rn = 1
        ),
        cns AS (
          SELECT cn FROM hourmeter_opening
          UNION
          SELECT cn FROM hourmeter_daily
          UNION
          SELECT cn FROM dc
        ),
        op_last AS (
          SELECT cn, opening,
                 ROW_NUMBER() OVER (PARTITION BY cn
                     ORDER BY period DESC) AS rn
          FROM hourmeter_opening
          WHERE opening IS NOT NULL
        ),
        base AS (
          SELECT c.cn,
                 (SELECT egi FROM hourmeter_opening e
                   WHERE e.cn = c.cn AND e.egi IS NOT NULL
                   ORDER BY e.period DESC LIMIT 1) AS egi,
                 (SELECT opening FROM op_last x
                   WHERE x.cn = c.cn AND x.rn = 1) AS opening
          FROM cns c
        ),
        rank AS (
          SELECT cn, period, day, hm, updated_at,
                 ROW_NUMBER() OVER (PARTITION BY cn
                     ORDER BY period DESC, day DESC) AS rn
          FROM hourmeter_daily
        ),
        last_read AS (
          SELECT r.cn, r.hm, r.updated_at, r.period, r.day
          FROM rank r WHERE r.rn = 1
        )
        SELECT b.cn, b.egi, b.opening,
               l.hm         AS last_hm,
               l.updated_at AS last_at,
               l.period     AS last_period,
               l.day        AS last_day,
               d.hm              AS dc_hm,
               CAST(d.date AS TEXT) AS dc_date
        FROM base b
        LEFT JOIN last_read l ON l.cn = b.cn
        LEFT JOIN dc        d ON d.cn = b.cn
        ORDER BY b.cn
    """))).mappings().all()

    units = []
    for r in rows:
        last_hm = r["last_hm"] if r["last_hm"] is not None else r["opening"]
        last_period = r["last_period"]
        last_day = r["last_day"]
        # HM Daily Check terbaru (bisa datang sebagai date atau datetime).
        dc_hm = r["dc_hm"]
        raw_dc = r["dc_date"]
        dc_date = (str(raw_dc)[:10] if raw_dc is not None
                   else None)
        units.append({
            "cn": r["cn"],
            "egi": r["egi"],
            # Pembacaan terakhir lintas periode (fallback opening terakhir).
            "hm_last": last_hm,
            "hm_at": r["last_at"].isoformat() if r["last_at"] else None,
            # Tanggal pembacaan terakhir (YYYY-MM-DD) — null bila hanya opening.
            "hm_date": (f"{last_period}-{int(last_day):02d}"
                        if (last_period and last_day is not None) else None),
            # HM DC & tanggal terbaru dari Activity → tab DC Dragflow, serta
            # Lifetime = HM DC − pembacaan HM RFU terakhir.
            "dc_hm": dc_hm,
            "dc_date": dc_date,
            "lifetime": (dc_hm - last_hm
                         if (dc_hm is not None and last_hm is not None) else None),
        })

    return {"units": units}


# ─── Input cepat HM (tempel teks "CN hm.NNNNN") ───────────────────────────

@router.post("/quick-input", dependencies=[Depends(require_menu("hourmeter", "add"))])
async def quick_input(
    body: dict,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Simpan pembacaan HM harian hasil tempel teks cepat.

    Body: {"date": "YYYY-MM-DD", "rows": [{"cn": "WP491", "hm": 22531}, ...]}
    - Tiap baris di-upsert ke `hourmeter_daily` (periode YYYY-MM, hari = tanggal);
    - bila CN belum punya baris `opening` di periode itu, dibuat dengan
      opening = HM yang diinput (Selisih bulan mulai dari 0);
    - CN yang tidak ada di master `equipment` tetap disimpan tetapi ditandai
      peringatan (`warning`) agar bisa dicek.
    """
    rows = body.get("rows")
    if not isinstance(rows, list) or not rows:
        raise HTTPException(400, "Tidak ada baris HM yang dikirim")

    raw_date = body.get("date")
    try:
        d = datetime.strptime(str(raw_date)[:10], "%Y-%m-%d").date() if raw_date else date.today()
    except ValueError:
        raise HTTPException(400, "Tanggal tidak valid (format YYYY-MM-DD)")
    period = f"{d.year}-{d.month:02d}"
    day = d.day

    results: list[dict] = []
    saved = 0
    for r in rows:
        cn = str((r or {}).get("cn") or "").strip().upper().replace(" ", "")
        hm = _cell_num((r or {}).get("hm"))
        if not cn or hm is None:
            results.append({"cn": cn, "hm": hm, "status": "invalid",
                            "warning": "CN atau HM tidak terbaca"})
            continue
        known = (await db.execute(
            text("SELECT 1 FROM equipment WHERE cn = :c"), {"c": cn})).scalar()
        # Pastikan baris opening ada; nilai awal = HM yang diinput.
        await db.execute(text("""
            INSERT INTO hourmeter_opening(period, cn, egi, opening, uploaded_by)
            VALUES (:p, :cn, NULL, :op, :who)
            ON CONFLICT (period, cn) DO NOTHING
        """), {"p": period, "cn": cn, "op": hm, "who": user["username"]})
        await db.execute(text("""
            INSERT INTO hourmeter_daily(period, cn, day, hm, updated_at)
            VALUES (:p, :cn, :d, :v, NOW())
            ON CONFLICT (period, cn, day) DO UPDATE SET hm = EXCLUDED.hm, updated_at = NOW()
        """), {"p": period, "cn": cn, "d": day, "v": hm})
        saved += 1
        item = {"cn": cn, "hm": hm, "status": "saved", "warning": None}
        if not known:
            item["warning"] = "CN tidak ada di master equipment"
        results.append(item)

    try:
        await db.execute(text("""
            INSERT INTO hourmeter_upload_log(period, filename, rows_units, rows_values, status, uploaded_by)
            VALUES (:p, :f, :u, :v, 'success', :who)
        """), {"p": period, "f": f"input-cepat {d.isoformat()}", "u": saved,
               "v": saved, "who": user["username"]})
        await db.commit()
    except Exception as e:  # noqa: BLE001
        await db.rollback()
        log.exception("gagal simpan input cepat hourmeter")
        raise HTTPException(500, f"gagal simpan: {e}")

    warned = sum(1 for x in results if x.get("warning"))
    return {
        "ok": True, "period": period, "date": d.isoformat(), "day": day,
        "saved": saved, "warned": warned, "results": results,
    }


@router.post("/delete-reading", dependencies=[Depends(require_menu("hourmeter", "delete"))])
async def delete_reading(
    body: dict,
    db: AsyncSession = Depends(get_db),
    user=Depends(get_current_user),
):
    """Hapus SATU pembacaan HM hasil input cepat (koreksi salah input).

    Body: {"cn": "WP792", "date": "YYYY-MM-DD"}
    Menghapus baris `hourmeter_daily` pada periode+tanggal tersebut, sehingga
    nilai HM RFU (beserta Date RFU) hilang dari grid. Baris `opening` periode
    itu DIBIARKAN supaya unit tetap tampil di grid; bila HM balik ke nilai
    yang salah, isi ulang lewat tombol "Isi RFU".
    """
    cn = str((body or {}).get("cn") or "").strip().upper().replace(" ", "")
    if not cn:
        raise HTTPException(400, "CN tidak boleh kosong")

    raw_date = (body or {}).get("date")
    try:
        d = datetime.strptime(str(raw_date)[:10], "%Y-%m-%d").date()
    except (ValueError, TypeError):
        raise HTTPException(400, "Tanggal tidak valid (format YYYY-MM-DD)")
    period = f"{d.year}-{d.month:02d}"

    res = await db.execute(text("""
        DELETE FROM hourmeter_daily
        WHERE period = :p AND cn = :cn AND day = :day
    """), {"p": period, "cn": cn, "day": d.day})
    deleted = res.rowcount or 0

    try:
        await db.execute(text("""
            INSERT INTO hourmeter_upload_log(period, filename, rows_units, rows_values, status, uploaded_by)
            VALUES (:p, :f, :n, :n, 'success', :who)
        """), {"p": period, "f": f"hapus-rfu {cn} {d.isoformat()}",
               "n": -deleted, "who": user["username"]})
        await db.commit()
    except Exception:  # noqa: BLE001
        await db.rollback()
        log.exception("gagal hapus pembacaan hourmeter")
        raise HTTPException(500, "gagal menghapus pembacaan")

    return {"ok": True, "cn": cn, "period": period, "date": d.isoformat(),
            "deleted": deleted}


@router.get("/history")
async def history(
    cn: str = Query(..., min_length=1),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db), _user=Depends(get_current_user),
):
    """Riwayat pembacaan HM RFU satu unit (untuk menu "+ HM RFU").

    Mengembalikan pembacaan `hourmeter_daily` unit tersebut dari SELURUH
    periode, terbaru lebih dulu. Satu tanggal = satu pembacaan (menambah
    pembacaan baru di tanggal lain berarti menambah baris baru, bukan
    menimpa yang lama), jadi daftar ini adalah riwayat aslinya.
    """
    cn = str(cn).strip().upper().replace(" ", "")
    rows = (await db.execute(text("""
        SELECT cn, period, day,
               hm,
               updated_at,
               MAKE_DATE(
                 CAST(SUBSTR(period, 1, 4) AS INTEGER),
                 CAST(SUBSTR(period, 6, 2) AS INTEGER),
                 day
               ) AS reading_date
        FROM hourmeter_daily
        WHERE cn = :cn AND day IS NOT NULL
        ORDER BY period DESC, day DESC
        LIMIT :lim
    """), {"cn": cn, "lim": limit})).mappings().all()

    out = []
    for r in rows:
        out.append({
            "cn": r["cn"],
            "date": str(r["reading_date"])[:10] if r["reading_date"] else None,
            "period": r["period"],
            "day": int(r["day"]),
            "hm": r["hm"],
            "hm_at": (r["updated_at"].isoformat()
                      if hasattr(r["updated_at"], "isoformat")
                      else (str(r["updated_at"]) if r["updated_at"] else None)),
        })
    return {"cn": cn, "readings": out, "count": len(out)}
