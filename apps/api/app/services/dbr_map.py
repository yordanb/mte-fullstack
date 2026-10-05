"""Mapping DBR_format.xlsx (Sheet1, header row 1) -> dbr_records. Serba mentah (TEXT)."""
import datetime

SHEET = "Sheet1"
HEADER_ROW = 1
DATA_START_ROW = 2

HEADER_MAP = {
    "DATE": "date", "C/N": "cn", "SECTION": "section",
    "Trouble Description": "trouble", "Code": "code",
    "HM Start": "hm_start", "LOC": "loc",
    "Start Break Down": "start_breakdown", "Start Time": "start_time",
    "Finish Time": "finish_time", "Total": "total", "WO": "wo",
    "NOTIFICATION": "notification", "ACTION": "action",
    "MECHANIC": "mechanic", "GL": "gl",
}


def _s(v):
    if v is None:
        return None
    if isinstance(v, bool):
        return str(v)
    s = str(v).strip()
    return s if s != "" else None


def coerce(col: str, v):
    if col == "date":
        if isinstance(v, datetime.datetime):
            return v.date()
        if isinstance(v, datetime.date):
            return v
        raise ValueError(f"DATE tidak valid: {v!r}")
    if col == "cn":
        s = _s(v)
        if not s:
            raise ValueError("C/N kosong")
        return s.upper()
    if col == "code":
        s = _s(v)
        if s is None:
            return None
        # kode angka 32006.0 (float excel) -> '32006'
        try:
            f = float(s)
            if f.is_integer():
                return str(int(f))
        except ValueError:
            pass
        return s.upper()
    return _s(v)
