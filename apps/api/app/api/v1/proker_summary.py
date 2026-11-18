"""Summary Program Kerja — matriks CN x modul proker (grup Technical Expert).

Satu baris per unit (Code Number), satu kolom per modul proker; tiap sel
menampilkan HM + tanggal eksekusi terakhir yang benar-benar terlaksana
(bukan PLAN). Sumber baris = union CN dari semua tabel unit proker.
Fitur: daftar matriks + export Excel (layout sama).
"""
import io
from datetime import datetime

import openpyxl
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_menu
from app.db.session import get_db

router = APIRouter(prefix="/v1/proker-summary", tags=["proker-summary"])

# 13 kolom modul: key menu → label kolom (urutan = urutan kolom tabel).
MODULES = (
    ("proker", "GMC Pompa Primer"),
    ("prokerbooster", "Midlife Eng Booster"),
    ("prokerinjector", "Midlife Injector"),
    ("prokerthermo", "Thermostat CAT"),
    ("prokerpanel", "GMC Panel Booster"),
    ("prokerexhaust", "Exhaust Primer"),
    ("prokerexhaustmits", "Exhaust Mitsura"),
    ("prokerfandrebb", "Rebearing Fan Drive"),
    ("prokerfandpompa", "Fan Drive Pompa"),
    ("prokergmc", "GMC Motor"),
    ("prokerfsbooster", "Fire Sup Booster"),
    ("prokerfsprimer", "Fire Sup Primer"),
    ("prokerponton", "Ponton"),
)

# SELECT eksekusi terlaksana per modul (4 kolom: cn, module, hm, service_date).
# Aturan terlaksana: hm tercatat DAN status bukan PLAN (fire suppression
# berstatus NOT YET punya hm NULL sehingga otomatis tersaring).
_EXEC_FRAGMENTS = (
    # Alias "module" pada fragment pertama menentukan nama kolom UNION.
    "SELECT cn, 'proker' AS module, hm, service_date FROM proker_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerbooster', hm, service_date FROM booster_event "
    "WHERE hm IS NOT NULL",
    # Injector tidak menyimpan tanggal — urutan "terakhir" hanya berdasar HM.
    "SELECT cn, 'prokerinjector', hm, NULL::date FROM injector_replacement "
    "WHERE hm IS NOT NULL AND status = 'DONE'",
    # Thermostat: data LAST ada di tabel unit (tanpa tabel eksekusi).
    "SELECT cn, 'prokerthermo', last_hm, last_date FROM thermo_unit "
    "WHERE last_hm IS NOT NULL",
    "SELECT cn, 'prokerpanel', hm, service_date FROM proker_panel_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerexhaust', hm, service_date FROM proker_exhaust_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerexhaustmits', hm, service_date "
    "FROM proker_exhaust_mitsura_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerfandrebb', hm, service_date FROM proker_fandrebb_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerfandpompa', hm, service_date FROM proker_fanpompa_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokergmc', hm, service_date FROM proker_gmc_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerfsbooster', hm, service_date FROM proker_fsbooster_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerfsprimer', hm, service_date FROM proker_fsprimer_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
    "SELECT cn, 'prokerponton', hm, service_date FROM proker_ponton_execution "
    "WHERE hm IS NOT NULL AND status <> 'PLAN'",
)

# 13 tabel unit proker — sumber daftar CN + identitas (model, product).
_UNIT_TABLES = (
    "proker_unit", "booster_unit", "injector_unit", "thermo_unit",
    "proker_panel_unit", "proker_exhaust_unit", "proker_exhaust_mitsura_unit",
    "proker_fandrebb_unit", "proker_fanpompa_unit", "proker_gmc_unit",
    "proker_fsbooster_unit", "proker_fsprimer_unit", "proker_ponton_unit",
)


def _units_union_sql() -> str:
    return "\n    UNION ALL ".join(
        f"SELECT cn, unit_model, product FROM {t}" for t in _UNIT_TABLES)


async def _summary_rows(db: AsyncSession, search: str) -> tuple[list[dict], list[dict]]:
    """Kembalikan (modules, units) — dipakai endpoint daftar & export Excel.

    Unit hanya yang aktif di equipment (aturan sama dengan halaman proker).
    """
    where = ""
    params: dict = {}
    if search.strip():
        where = ("AND (u.cn ILIKE :q OR COALESCE(u.unit_model,'') ILIKE :q "
                 "OR COALESCE(u.product,'') ILIKE :q)")
        params["q"] = f"%{search.strip()}%"

    exec_union = "\n    UNION ALL ".join(_EXEC_FRAGMENTS)

    sql = text(f"""
WITH units AS (
    SELECT cn, MAX(unit_model) AS unit_model, MAX(product) AS product
    FROM (
    {_units_union_sql()}
    ) src
    GROUP BY cn
),
last_exec AS (
    SELECT cn, module, hm, service_date FROM (
    {exec_union}
    ) e
),
ranked AS (
    SELECT cn, module, hm, service_date,
           ROW_NUMBER() OVER (PARTITION BY cn, module
                              ORDER BY service_date DESC NULLS LAST,
                                       hm DESC NULLS LAST) AS rn
    FROM last_exec
)
SELECT u.cn, u.unit_model, u.product, r.module, r.hm, r.service_date
FROM units u
LEFT JOIN ranked r ON r.cn = u.cn AND r.rn = 1
WHERE EXISTS (SELECT 1 FROM equipment eq
              WHERE eq.cn = u.cn AND eq.aktif)
{where}
ORDER BY u.cn
""")

    modules = [{"key": k, "label": label} for k, label in MODULES]
    units_out: list[dict] = []
    cells_by_cn: dict[str, dict] = {}
    for row in (await db.execute(sql, params)).mappings().all():
        cn = row["cn"]
        unit = cells_by_cn.get(cn)
        if unit is None:
            unit = {
                "cn": cn,
                "model": row["unit_model"],
                "product": row["product"],
                "cells": {},
            }
            cells_by_cn[cn] = unit
            units_out.append(unit)
        if row["module"]:
            unit["cells"][row["module"]] = {
                "hm": float(row["hm"]) if row["hm"] is not None else None,
                "date": row["service_date"].isoformat() if row["service_date"] else None,
            }

    modules = [{"key": k, "label": label} for k, label in MODULES]
    return modules, units_out


@router.get("", dependencies=[Depends(require_menu("prokersummary", "view"))])
async def get_summary(
    search: str = Query("", max_length=100),
    db: AsyncSession = Depends(get_db),
):
    """Matriks ringkasan: daftar unit + eksekusi terlaksana terakhir per modul."""
    modules, units_out = await _summary_rows(db, search)
    return {"modules": modules, "units": units_out,
            "total": len(units_out)}


# ─── Export Excel (layout matriks sama dengan halaman) ─────────────────────

@router.get("/export", dependencies=[Depends(require_menu("prokersummary", "view"))])
async def export_xlsx(
    search: str = Query("", max_length=100),
    db: AsyncSession = Depends(get_db),
):
    """Export matriks summary ke .xlsx — 2 kolom per modul (HM, Tanggal)."""
    modules, units = await _summary_rows(db, search)

    thin = openpyxl.styles.Side(style='thin')
    border = openpyxl.styles.Border(left=thin, right=thin, top=thin, bottom=thin)
    bold10 = openpyxl.styles.Font(bold=True, size=10)
    normal10 = openpyxl.styles.Font(size=10)
    center = openpyxl.styles.Alignment(horizontal='center', vertical='center')

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = 'Summary Proker'

    ws['A1'] = 'SUMMARY PROGRAM KERJA'
    ws['A1'].font = openpyxl.styles.Font(bold=True, size=12)
    ws['A2'] = f"Diunduh: {datetime.now().strftime('%d/%m/%Y %H:%M')}"
    ws['A2'].font = openpyxl.styles.Font(size=9, italic=True)

    # Header 2 baris: baris 1 = nama modul (merge 2 kolom), baris 2 = HM|Tanggal.
    hr, hr2 = 4, 5
    fixed = ('No', 'Code Number', 'Model', 'Product')
    for i, h in enumerate(fixed, start=1):
        ws.merge_cells(start_row=hr, start_column=i, end_row=hr2, end_column=i)
        c = ws.cell(row=hr, column=i, value=h)
        c.font = bold10
        c.border = border
        c.alignment = center
    col = len(fixed) + 1
    for _, label in modules:
        ws.merge_cells(start_row=hr, start_column=col, end_row=hr,
                       end_column=col + 1)
        c = ws.cell(row=hr, column=col, value=label)
        c.font = bold10
        c.border = border
        c.alignment = openpyxl.styles.Alignment(
            horizontal='center', vertical='center', wrap_text=True)
        for j, sub in enumerate(('HM', 'Tanggal')):
            c2 = ws.cell(row=hr2, column=col + j, value=sub)
            c2.font = bold10
            c2.border = border
            c2.alignment = center
        col += 2

    # Data — HM angka (bisa dihitung), tanggal teks dd/mm/yyyy ala web.
    for idx, u in enumerate(units, start=1):
        r = hr2 + idx
        vals = (idx, u['cn'], u['model'], u['product'])
        for i, v in enumerate(vals, start=1):
            c = ws.cell(row=r, column=i, value=v)
            c.font = normal10
            c.border = border
        col = len(fixed) + 1
        for key, _ in modules:
            cell = u['cells'].get(key)
            has_hm = cell is not None and cell['hm'] is not None
            hm = ws.cell(row=r, column=col, value=cell['hm'] if has_hm else None)
            hm.font = normal10
            hm.border = border
            hm.number_format = '#,##0.##'
            d = cell['date'] if cell else None
            has_date = bool(d)
            date = ws.cell(
                row=r, column=col + 1,
                value=(f'{d[8:10]}/{d[5:7]}/{d[:4]}' if has_date else None))
            date.font = normal10
            date.border = border
            col += 2

    ws.row_dimensions[hr].height = 30  # nama modul bisa 2 baris saat wrap
    for r_ in range(hr2, hr2 + len(units) + 1):
        ws.row_dimensions[r_].height = 15
    ws.column_dimensions['A'].width = 5
    ws.column_dimensions['B'].width = 14
    ws.column_dimensions['C'].width = 20
    ws.column_dimensions['D'].width = 16
    col = len(fixed) + 1
    for _ in modules:
        ws.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 9
        ws.column_dimensions[openpyxl.utils.get_column_letter(col + 1)].width = 12
        col += 2
    ws.freeze_panes = f'E{hr2 + 1}'

    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    fname = 'Summary Program Kerja.xlsx'
    return StreamingResponse(
        buf, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={'Content-Disposition': f'attachment; filename="{fname}"'})
