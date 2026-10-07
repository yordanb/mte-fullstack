"""Laporan PDF FUI (ReportLab, deterministik): portrait untuk kop+DBR,
landscape untuk tabel oil 20 kolom. Header tabel diulang tiap halaman."""
import io
from datetime import date
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph,
                                Spacer, Table, TableStyle, PageBreak,
                                NextPageTemplate)
from reportlab.lib.colors import HexColor

GREEN = HexColor("#d6e4c9")
BRAND = HexColor("#3641f5")
RED = HexColor("#b42318")
GREY = HexColor("#555555")

CELL = ParagraphStyle("cell", fontName="Helvetica", fontSize=7, leading=8)
CELL_C = ParagraphStyle("cellc", parent=CELL, alignment=TA_CENTER)
HEAD = ParagraphStyle("head", parent=CELL, fontName="Helvetica-Bold",
                      textColor=colors.black, alignment=TA_CENTER)
TITLE = ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=14,
                       alignment=TA_CENTER, textColor=BRAND)
SUB = ParagraphStyle("sub", fontName="Helvetica-Bold", fontSize=10,
                     alignment=TA_CENTER)
SMALL = ParagraphStyle("small", fontName="Helvetica", fontSize=8,
                       alignment=TA_CENTER, textColor=GREY)
H2 = ParagraphStyle("h2", fontName="Helvetica-Bold", fontSize=10, leading=12)
SIGN = ParagraphStyle("sign", fontName="Helvetica", fontSize=8, alignment=TA_CENTER)

OIL_COLS = [("lab_no", "Lab No"), ("sample_date", "Sample"),
            ("unit_time", "HM"), ("unit_time_oils", "HM Oil"),
            ("visc", "VISC"), ("fuel", "FUEL"), ("soot", "SOOT"),
            ("oxi", "OXI"), ("nitr", "NITR"), ("water", "WTR"),
            ("tbn", "TBN"), ("si", "Si"), ("fe", "Fe"), ("cu", "Cu"),
            ("al", "Al"), ("cr", "Cr"), ("pb", "Pb"), ("na", "Na"),
            ("condition", "Cond")]
OIL_GRADES = {"visc": "grade_visc", "fuel": "grade_fuel", "soot": "grade_soot",
              "oxi": "grade_oxi", "nitr": "grade_nitr", "water": "grade_water",
              "tbn": "grade_tbn", "si": "grade_si", "fe": "grade_fe",
              "cu": "grade_cu", "al": "grade_al", "cr": "grade_cr",
              "pb": "grade_pb", "na": "grade_na"}

DBR_COLS = [("date", "DATE"), ("cn", "C/N"), ("section", "SECTION"),
            ("trouble", "Trouble"), ("code", "Code"), ("hm_start", "HM Start"),
            ("loc", "LOC"), ("start_breakdown", "Start BD"),
            ("action", "Action"), ("mechanic", "Mechanic"), ("gl", "GL")]
DBR_W = [16, 14, 16, 45, 12, 12, 14, 20, 14, 14, 13]


def _p(text, style=CELL_C):
    return Paragraph("" if text is None else str(text), style)


def _num(v):
    if v is None:
        return ""
    f = float(v)
    return str(int(f)) if f.is_integer() else str(round(f, 2))


def _footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(GREY)
    canvas.drawRightString(doc.pagesize[0] - 10 * mm, 10 * mm,
                           f"Halaman {doc.page}")
    canvas.restoreState()


def build_fui_pdf(eq: dict | None, dbr: list, oil: list, cn: str) -> bytes:
    """eq: 1 baris equipment. dbr: list dict. oil: [(unit, [rows])]."""
    buf = io.BytesIO()
    pw, ph = A4  # portrait
    lw, lh = ph, pw  # landscape
    doc = BaseDocTemplate(buf, leftMargin=10 * mm, rightMargin=10 * mm,
                          topMargin=12 * mm, bottomMargin=14 * mm,
                          title=f"FUI-{cn}", author="MTE Data Center")
    pf = Frame(doc.leftMargin, doc.bottomMargin, pw - 20 * mm, ph - 26 * mm, id="p")
    lf = Frame(doc.leftMargin, doc.bottomMargin, lw - 20 * mm, lh - 26 * mm, id="l")
    doc.addPageTemplates([
        PageTemplate(id="portrait", frames=[pf], pagesize=(pw, ph), onPage=_footer),
        PageTemplate(id="landscape", frames=[lf], pagesize=(lw, lh), onPage=_footer),
    ])
    story, today = [], date.today().strftime("%d/%m/%Y")
    story += [Paragraph("MTE DATA CENTER", TITLE),
              Paragraph(f"FOLLOW UP INSTRUCTION (FUI) — {cn}", SUB),
              Paragraph(f"Tanggal cetak: {today}", SMALL), Spacer(1, 4 * mm)]
    if eq:
        engine = " - ".join([x for x in (eq.get("engine_merk"), eq.get("engine_model")) if x])
        info = [["Code Unit", "Unit Type", "Product"],
                [eq.get("cn", ""), eq.get("unit_type") or "-", eq.get("unit_product") or "-"],
                ["Engine", "CN Serial No", "Engine Serial No"],
                [engine or "-", eq.get("cn_serial_no") or "-", eq.get("engine_serial_no") or "-"]]
        t = Table([[ _p(c, HEAD) if i % 2 == 0 else _p(c) for c in row]
                   for i, row in enumerate(info)],
                  colWidths=[(pw - 20 * mm) / 3] * 3)
        t.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#555555")),
            ("BACKGROUND", (0, 0), (-1, 0), GREEN),
            ("BACKGROUND", (0, 2), (-1, 2), GREEN),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]))
        story += [t, Spacer(1, 4 * mm)]
    story += [Paragraph("DBR Breakdown — 10 terbaru (Code USM, tanpa CONTINUE)", H2)]
    dhead = [_p(c[1], HEAD) for c in DBR_COLS]
    drows = []
    for r in dbr:
        row = []
        for k, _ in DBR_COLS:
            v = r.get(k)
            if k == "date" and v:
                v = str(v)[:10].split("-")
                v = f"{v[2]}/{v[1]}/{v[0]}" if len(v) == 3 else str(r.get(k))
            row.append(_p(v, CELL if k in ("trouble", "action") else CELL_C))
        drows.append(row)
    if not drows:
        drows = [[_p(f"Tidak ada data DBR USM untuk {cn}")]]
    dt = Table([dhead] + drows, colWidths=[w * mm for w in DBR_W], repeatRows=1)
    dt.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#555555")),
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    story += [dt]
    # --- oil landscape, 1 halaman per component ---
    if oil:
        story += [NextPageTemplate("landscape"), PageBreak()]
    for ui, (unit, rows) in enumerate(oil):
        story += [Paragraph(f"Report Analisa Oli — Component {unit} (10 terakhir)", H2)]
        ohead = [_p(c[1], HEAD) for c in OIL_COLS]
        orows = []
        for r in rows:
            row = []
            for k, _ in OIL_COLS:
                v = r.get(k)
                if k == "sample_date" and v:
                    v = str(v)[:10].split("-")
                    v = f"{v[2]}/{v[1]}/{v[0]}" if len(v) == 3 else str(r.get(k))
                elif k not in ("lab_no", "condition"):
                    v = _num(v)
                g = r.get(OIL_GRADES[k]) if k in OIL_GRADES else None
                bad = g is not None and g != "" and g != "N"
                cell = "" if v is None else str(v)
                if bad:
                    cell = f'<font color="{RED.hexval()}" size="8"><b>{cell}</b></font>'
                    row.append(Paragraph(cell, CELL_C))
                else:
                    row.append(_p(cell))
            orows.append(row)
        if not orows:
            orows = [[_p(f"Tidak ada data oil untuk {unit}")]]
        avail = lw - 20 * mm
        w_lab, w_cond = 22 * mm, 16 * mm
        w_mid = (avail - w_lab - w_cond) / (len(OIL_COLS) - 2)
        ot = Table([ohead] + orows,
                   colWidths=[w_lab] + [w_mid] * (len(OIL_COLS) - 2) + [w_cond],
                   repeatRows=1)
        ot.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#555555")),
            ("BACKGROUND", (0, 0), (-1, 0), GREEN),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]))
        story += [ot]
        if ui < len(oil) - 1:
            story += [PageBreak()]
        if ui == len(oil) - 1:
            story += [Spacer(1, 12 * mm)]
            sig = [[Paragraph(t, SIGN) for t in ("Dibuat Oleh", "Diperiksa", "Disetujui")],
                   [Paragraph("<br/><br/><br/>", SIGN)] * 3,
                   [Paragraph("( Nama / Tanda tangan / Tanggal )", SIGN)] * 3]
            st = Table(sig, colWidths=[avail / 3] * 3)
            st.setStyle(TableStyle([("LINEBELOW", (0, 1), (-1, 1), 0.5, colors.black)]))
            story += [st]
    if not oil:
        story += [Spacer(1, 12 * mm)]
        sig = [[Paragraph(t, SIGN) for t in ("Dibuat Oleh", "Diperiksa", "Disetujui")],
               [Paragraph("<br/><br/><br/>", SIGN)] * 3,
               [Paragraph("( Nama / Tanda tangan / Tanggal )", SIGN)] * 3]
        st = Table(sig, colWidths=[(pw - 20 * mm) / 3] * 3)
        st.setStyle(TableStyle([("LINEBELOW", (0, 1), (-1, 1), 0.5, colors.black)]))
        story += [st]
    doc.build(story)
    return buf.getvalue()
