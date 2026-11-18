"""Summary Program Kerja — matriks CN x modul proker (grup Technical Expert).

Satu baris per unit (Code Number), satu kolom per modul proker; tiap sel
menampilkan HM + tanggal eksekusi terakhir yang benar-benar terlaksana
(bukan PLAN). Sumber baris = union CN dari semua tabel unit proker.
"""
from fastapi import APIRouter, Depends, Query
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


@router.get("", dependencies=[Depends(require_menu("prokersummary", "view"))])
async def get_summary(
    search: str = Query("", max_length=100),
    db: AsyncSession = Depends(get_db),
):
    """Matriks ringkasan: daftar unit + eksekusi terlaksana terakhir per modul.

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

    return {"modules": modules, "units": units_out,
            "total": len(units_out)}
