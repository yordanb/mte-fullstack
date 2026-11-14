"""Refresh HM NOW halaman Proker dari sumber pencatatan HM (tombol "Refresh HM").

Mengambil pembacaan HM terbaru per C/N dari dua sumber:
  * Hourmeter        — tabel hourmeter_opening/hourmeter_daily (upload bulanan);
                       nilai = HM hari terakhir pada periode terbaru per C/N
                       (fallback: opening periode terbaru bila tak ada nilai harian).
  * Yazu Lighting Daily Check — tabel yazu_dc_lighting (sync harian 06:00/18:00); nilai = HM pada
                       baris dengan waktu paling baru per ID unit.

Aturan:
  - C/N dicocokkan setelah normalisasi (huruf besar, spasi dibuang);
  - bila sebuah C/N ada di kedua sumber, Yazu DC dipakai (pencatatan harian);
  - nilai kosong / nol diabaikan agar tidak menimpa HM valid;
  - unit yang tidak ada di kedua sumber dibiarkan apa adanya dan dilaporkan
    sebagai `not_found`.
"""
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

# Whitelist tabel proker yang boleh di-refresh (nama tabel tidak pernah dari user).
TABLES = ("proker_unit", "proker_panel_unit", "proker_exhaust_unit",
          "proker_exhaust_mitsura_unit",
          "booster_unit", "injector_unit", "thermo_unit")


def _norm(cn: str | None) -> str:
    return (cn or "").upper().replace(" ", "")


async def _yazu_map(db: AsyncSession) -> dict[str, int]:
    """C/N ter-normalisasi → HM pada baris yazu_dc_lighting paling baru."""
    rows = (await db.execute(text("""
        SELECT DISTINCT ON (id_unit) id_unit, hm
        FROM yazu_dc_lighting
        WHERE hm IS NOT NULL AND hm > 0
        ORDER BY id_unit, waktu DESC
    """))).mappings().all()
    return {_norm(r["id_unit"]): r["hm"] for r in rows}


async def _hourmeter_map(db: AsyncSession) -> dict[str, int]:
    """C/N ter-normalisasi → HM hari terakhir periode terbaru (fallback opening)."""
    out: dict[str, int] = {}

    # Fallback: opening pada periode terbaru per C/N.
    rows = (await db.execute(text("""
        SELECT DISTINCT ON (cn) cn, opening
        FROM hourmeter_opening
        WHERE opening IS NOT NULL AND opening > 0
        ORDER BY cn, period DESC
    """))).mappings().all()
    for r in rows:
        out[_norm(r["cn"])] = r["opening"]

    # Nilai harian (menang atas opening): day terbesar pada periode terbaru per C/N.
    rows = (await db.execute(text("""
        WITH latest AS (
            SELECT cn, MAX(period) AS period FROM (
                SELECT cn, period FROM hourmeter_opening
                UNION ALL
                SELECT cn, period FROM hourmeter_daily
            ) x GROUP BY cn
        )
        SELECT DISTINCT ON (d.cn) d.cn, d.hm
        FROM hourmeter_daily d
        JOIN latest l ON l.cn = d.cn AND l.period = d.period
        WHERE d.hm IS NOT NULL AND d.hm > 0
        ORDER BY d.cn, d.day DESC
    """))).mappings().all()
    for r in rows:
        out[_norm(r["cn"])] = r["hm"]

    return out


async def refresh_hm_from_sources(db: AsyncSession, table: str,
                                  cns: list[str] | None = None) -> dict:
    """Update kolom `hm_now` tabel proker dari sumber HM terbaru.

    `cns` opsional membatasi unit yang diproses (mis. hanya unit CAT di Proker
    GMC). Return ringkasan: jumlah unit diperbarui, unit tanpa data di sumber,
    dan detail per unit (termasuk nilai sebelum & asal sumbernya).
    """
    if table not in TABLES:
        raise ValueError(f"tabel tidak dikenal: {table}")

    if cns is None:
        rows = (await db.execute(text(f"SELECT cn, hm_now FROM {table}"))).mappings()
    else:
        rows = (await db.execute(
            text(f"SELECT cn, hm_now FROM {table} WHERE cn = ANY(:cns)"),
            {"cns": list(cns)})).mappings()
    current = {r["cn"]: r["hm_now"] for r in rows}
    if not current:
        return {"updated": 0, "not_found": 0, "details": []}

    yazu = await _yazu_map(db)
    hourmeter = await _hourmeter_map(db)

    details: list[dict] = []
    updated, unchanged = 0, 0
    for cn, before in current.items():
        key = _norm(cn)
        if key in yazu:
            new_hm, source = yazu[key], "yazu_dc_lighting"
        elif key in hourmeter:
            new_hm, source = hourmeter[key], "hourmeter"
        else:
            details.append({"cn": cn, "before": before, "hm_now": None,
                            "source": "not_found", "changed": False})
            continue
        same = before is not None and float(before) == float(new_hm)
        if same:
            unchanged += 1
        else:
            await db.execute(text(f"UPDATE {table} SET hm_now = :hm WHERE cn = :cn"),
                             {"hm": new_hm, "cn": cn})
            updated += 1
        details.append({"cn": cn, "before": before, "hm_now": new_hm,
                        "source": source, "changed": not same})

    await db.commit()
    not_found = sum(1 for d in details if d["source"] == "not_found")
    return {"updated": updated, "unchanged": unchanged, "not_found": not_found,
            "details": details}
