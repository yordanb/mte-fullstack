"""Bangun infra/db/V7__equipment_seed.sql dari 4 dump di data-equipment/.

Pembersihan: trim/newline-collapse, junk ('-','?','N/A','NaT') -> NULL,
cn upper, arrived y/m/d float-string -> DATE (invalid -> NULL),
GS256 versi lighting dibuang (pakai versi pumping, sesuai keputusan user).

Idempoten: INSERT ... ON CONFLICT (cn) DO UPDATE.
Jalankan: python scripts/build_equipment_seed.py
"""
import datetime
import json
import pathlib
import re
import sqlite3

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'data-equipment'
OUT = ROOT / 'infra' / 'db' / 'V7__equipment_seed.sql'

FILES = {
    'BIGWHEEL': 'tb_bigwheel_202610051406.sql',
    'LIGHTING': 'tb_lighting_eqp_202610051406.sql',
    'MOBILE': 'tb_spex_mobile_202610051406.sql',
    'PUMPING': 'tb_spex_pumping_202610051406.sql',
}
JUNK = {'', '-', '?', 'N/A', 'NAT', 'NULL', 'NONE'}

COLS = ['cn', 'category', 'unit_model', 'unit_type', 'unit_product',
        'cn_serial_no', 'cn_year', 'cn_lokasi', 'status', 'operasional',
        'pump_group', 'engine_model', 'engine_merk', 'engine_serial_no',
        'arrived_date', 'arrived_year', 'arrived_month', 'arrived_hm',
        'lokasi', 'remark', 'offhire', 'aktif', 'specs']


def txt(v):
    if v is None:
        return None
    s = re.sub(r'\s+', ' ', str(v)).strip()
    if s == '' or s.upper() in JUNK:
        return None
    return s


def num(v):
    if v is None:
        return None
    try:
        f = float(str(v).strip())
    except (ValueError, TypeError):
        return None
    return f


def int_or_none(v):
    f = num(v)
    if f is None or not f.is_integer():
        return None
    return int(f)


def arr_parts(y, m):
    yi, mi = int_or_none(y), int_or_none(m)
    if yi is not None and not (1990 <= yi <= 2100):
        yi = None
    if mi is not None and not (1 <= mi <= 12):
        mi = None
    return yi, mi


def arr_date(y, m, d):
    yi, mi = arr_parts(y, m)
    if yi is None or mi is None:
        return None
    di = int_or_none(d)
    if di is None:
        return None
    try:
        return datetime.date(yi, mi, di).isoformat()
    except ValueError:
        return None


def load(tbl_file):
    con = sqlite3.connect(':memory:')
    con.row_factory = sqlite3.Row
    sql = (SRC / tbl_file).read_text(encoding='utf-8', errors='replace')
    sql = sql.replace('public.', '')
    sql = re.sub(r'\btrue\b', '1', sql)
    m = re.search(r'INSERT INTO (\S+) \(([^)]+)\)', sql)
    tbl, cols = m.group(1), [c.strip().strip('"') for c in m.group(2).split(',')]
    con.execute('CREATE TABLE [%s] (%s)' % (tbl, ', '.join('"%s" TEXT' % c for c in cols)))
    con.executescript(sql)
    return [dict(r) for r in con.execute('SELECT * FROM [%s]' % tbl)]


def spec(row, keys):
    out = {}
    for k in keys:
        v = txt(row.get(k))
        if v is not None:
            out[k] = v
    no = int_or_none(row.get('no'))
    if no is not None:
        out['legacy_no'] = no
    return out


def build():
    rows = []
    for r in load(FILES['BIGWHEEL']):
        rows.append(dict(
            cn=txt(r['cn']).upper(), category='BIGWHEEL',
            unit_model=None, unit_type=txt(r['unit_type']), unit_product=txt(r['unit_product']),
            cn_serial_no=txt(r['cn_serial_no']), cn_year=int_or_none(r['cn_year']),
            cn_lokasi=None, status=txt(r['status']), operasional=None, pump_group=None,
            engine_model=txt(r['engine_model']), engine_merk=txt(r['engine_merk']),
            engine_serial_no=txt(r['engine_serial_no']),
            arrived_date=arr_date(r['arrived_year'], r['arrived_month'], r['arrived_date']),
            arrived_year=arr_parts(r['arrived_year'], r['arrived_month'])[0],
            arrived_month=arr_parts(r['arrived_year'], r['arrived_month'])[1],
            arrived_hm=num(r['arrived_hm']), lokasi=None,
            remark=txt(r['remark']), offhire=txt(r['offhire']),
            aktif=(str(r['aktif']).strip() == '1'),
            specs=spec(r, ['tansmission_model', 'transmission_serial_no',
                           'differential_model', 'differential_serial_no',
                           'final_drive_model', 'final_drive_front_serial_no',
                           'final_drive_rear_serial_no'])))
    for r in load(FILES['LIGHTING']):
        if txt(r['cn']).upper() == 'GS256':
            continue  # dimenangkan versi pumping
        rows.append(dict(
            cn=txt(r['cn']).upper(), category='LIGHTING',
            unit_model=txt(r['unit_model']), unit_type=txt(r['unit_type']),
            unit_product=txt(r['unit_product']), cn_serial_no=txt(r['cn_serial_no']),
            cn_year=None, cn_lokasi=txt(r['cn_lokasi']), status=None, operasional=None,
            pump_group=None, engine_model=txt(r['engine_model']),
            engine_merk=txt(r['engine_merk']), engine_serial_no=txt(r['engine_serial_no']),
            arrived_date=arr_date(r['arrived_year'], r['arrived_month'], r['arrived_date']),
            arrived_year=arr_parts(r['arrived_year'], r['arrived_month'])[0],
            arrived_month=arr_parts(r['arrived_year'], r['arrived_month'])[1],
            arrived_hm=None, lokasi=txt(r['cn_lokasi']),
            remark=txt(r['remark']), offhire=txt(r['offhire']),
            aktif=(str(r['aktif']).strip() == '1'),
            specs=spec(r, ['geno_model', 'geno_serial_no'])))
    for r in load(FILES['MOBILE']):
        rows.append(dict(
            cn=txt(r['cn']).upper(), category='MOBILE',
            unit_model=txt(r['unit_model']), unit_type=txt(r['unit_type']),
            unit_product=txt(r['unit_product']), cn_serial_no=txt(r['cn_serial_no']),
            cn_year=None, cn_lokasi=None, status=None, operasional=None, pump_group=None,
            engine_model=txt(r['engine_model']), engine_merk=txt(r['engine_merk']),
            engine_serial_no=txt(r['engine_serial_no']),
            arrived_date=arr_date(r['arrived_year'], r['arrived_month'], r['arrived_date']),
            arrived_year=arr_parts(r['arrived_year'], r['arrived_month'])[0],
            arrived_month=arr_parts(r['arrived_year'], r['arrived_month'])[1],
            arrived_hm=None, lokasi=txt(r['user']),
            remark=txt(r['remarks']), offhire=txt(r['offhire']),
            aktif=(str(r['aktif']).strip() == '1'),
            specs=spec(r, ['attachment_serial_no', 'transmission_model',
                           'transmission_serial_no', 'transfer_model', 'transfer_serial_no',
                           'axle_front', 'axle_middle', 'axle_rear',
                           'attachment_type', 'attachment_serial_no_1',
                           'attachment_capacity'])))
    for r in load(FILES['PUMPING']):
        rows.append(dict(
            cn=txt(r['cn']).upper(), category='PUMPING',
            unit_model=None, unit_type=txt(r['unit_type']), unit_product=txt(r['unit_product']),
            cn_serial_no=txt(r['cn_serial_no']), cn_year=None, cn_lokasi=None, status=None,
            operasional=txt(r['operasional']), pump_group=txt(r['swp_or_big_pump']),
            engine_model=txt(r['engine_genset_model']), engine_merk=txt(r['engine_genset_merk']),
            engine_serial_no=txt(r['engine_genset_serial_no']),
            arrived_date=arr_date(r['arrived_year'], r['arrived_month'], r['arrived_date']),
            arrived_year=arr_parts(r['arrived_year'], r['arrived_month'])[0],
            arrived_month=arr_parts(r['arrived_year'], r['arrived_month'])[1],
            arrived_hm=None, lokasi=None,
            remark=txt(r['remark']), offhire=txt(r['offhire']),
            aktif=(str(r['aktif']).strip() == '1'),
            specs=spec(r, ['genset_type', 'genset_cn', 'genset_serial_no',
                           'genset_arrived_year', 'geno_cn', 'geno_model', 'geno_serial_no',
                           'inverter_model', 'inverter_serial_no', 'motor_model',
                           'motor_serial_no', 'pompa_model', 'pompa_serial_no',
                           'bareshaft_serial_no', 'tm_motor_serial_no', 'tm_model',
                           'tm_serial_no', 'motor_inverter_model',
                           'motor_inverter_serial_no'])))
    # validasi: cn unik
    seen, dups = set(), set()
    for e in rows:
        if e['cn'] in seen:
            dups.add(e['cn'])
        seen.add(e['cn'])
    assert not dups, 'cn ganda: %s' % dups
    return rows


def lit(v):
    if v is None:
        return 'NULL'
    if isinstance(v, bool):
        return 'TRUE' if v else 'FALSE'
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, dict):
        v = json.dumps(v, ensure_ascii=False)
    return "'%s'" % str(v).replace("'", "''")


def emit(rows):
    sets = ', '.join('%s=EXCLUDED.%s' % (c, c) for c in COLS if c != 'cn')
    parts = ['-- V7 seed equipment (%d unit). Dihasilkan scripts/build_equipment_seed.py. '
             'Idempoten (rerun aman).' % len(rows)]
    for i in range(0, len(rows), 100):
        chunk = rows[i:i + 100]
        vals = ',\n'.join('(%s)' % ', '.join(lit(e[c]) for c in COLS) for e in chunk)
        parts.append(
            'INSERT INTO equipment(%s) VALUES\n%s\nON CONFLICT (cn) DO UPDATE SET %s;'
            % (', '.join(COLS), vals, sets))
    OUT.write_text('\n'.join(parts) + '\n', encoding='utf-8')


if __name__ == '__main__':
    data = build()
    emit(data)
    from collections import Counter
    print('total:', len(data), '| per kategori:', dict(Counter(e['category'] for e in data)))
    print('GS256:', [e for e in data if e['cn'] == 'GS256'][0]['category'])
    print('arrived_date NULL:', sum(1 for e in data if not e['arrived_date']))
    print('contoh WP676:', [e for e in data if e['cn'] == 'WP676'])
    print('contoh TL861:', [e for e in data if e['cn'] == 'TL861'])
    print('->', OUT)
