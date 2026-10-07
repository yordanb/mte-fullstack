"""Laporan gaya vendor PAMA dari database (tanpa capture):
header band District/Code/Component + tabel oil + Warning Limit Min/Max
+ Recommendation + tabel Kerusakan (dari DBR USM terbaru).
1 component -> portrait full-width; multi -> landscape 2 kolom."""
import io
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph,
                                Spacer, Table, TableStyle, KeepTogether)
from reportlab.lib.colors import HexColor

TEAL = HexColor("#0e7c7b")
GREEN = HexColor("#d6e4c9")
BLUE_BG = HexColor("#cfe3f5")
RED = HexColor("#c00000")
DARK_GREEN = HexColor("#0a6b0a")
GREY = HexColor("#555555")

CELL = ParagraphStyle("cell", fontName="Helvetica", fontSize=7, leading=8)
CELL_C = ParagraphStyle("cellc", parent=CELL, alignment=TA_CENTER)
HEAD = ParagraphStyle("head", parent=CELL, fontName="Helvetica-Bold",
                      textColor=colors.white, alignment=TA_CENTER)
BAND = ParagraphStyle("band", parent=CELL, fontName="Helvetica-Bold",
                      textColor=colors.white)
BANDV = ParagraphStyle("bandv", parent=BAND, alignment=TA_LEFT)
TITLE = ParagraphStyle("title", fontName="Helvetica-Bold", fontSize=12,
                       alignment=TA_CENTER, textColor=HexColor("#0000cc"))
SUB = ParagraphStyle("sub", fontName="Helvetica-Bold", fontSize=9,
                     alignment=TA_CENTER)
H2 = ParagraphStyle("h2", fontName="Helvetica-Bold", fontSize=10, leading=12)
H2L = ParagraphStyle("h2l", parent=H2, alignment=TA_LEFT)
REC = ParagraphStyle("rec", fontName="Helvetica", fontSize=8, leading=10)
WHITEB = ParagraphStyle("whiteb", parent=CELL_C, fontName="Helvetica-Bold",
                        textColor=colors.white)
KLABEL = ParagraphStyle("klabel", fontName="Helvetica-Bold", fontSize=9,
                        textColor=RED, alignment=TA_CENTER)

PARAMS = ["visc", "fuel", "soot", "oxi", "nitr", "water", "tbn",
          "si", "fe", "cu", "al", "cr", "pb", "na"]
PLABEL = {"visc": "VISC", "fuel": "FUEL", "soot": "SOOT", "oxi": "OXI",
          "nitr": "NITR", "water": "WTR", "tbn": "TBN",
          "si": "Si", "fe": "Fe", "cu": "Cu", "al": "Al",
          "cr": "Cr", "pb": "Pb", "na": "Na"}
NMIN = {"visc": "n_visc", "fuel": "n_fuel", "soot": "n_soot", "oxi": "n_oxi",
        "nitr": "n_nitr", "water": "n_water", "tbn": "n_tbn",
        "si": "n_si", "fe": "n_fe", "cu": "n_cu", "al": "n_al",
        "cr": "n_cr", "pb": "n_pb", "na": "n_na"}
NMAX = {"visc": "n_visc_max", "fuel": "n_fuel_max", "soot": "n_soot_max",
        "oxi": "n_oxi_max", "nitr": "n_nitr_max", "water": "n_water_max",
        "tbn": "n_tbn_max", "si": "n_si_max", "fe": "n_fe_max",
        "cu": "n_cu_max", "al": "n_al_max", "cr": "n_cr_max",
        "pb": "n_pb_max", "na": "n_na_max"}
GRADE = {"visc": "grade_visc", "fuel": "grade_fuel", "soot": "grade_soot",
         "oxi": "grade_oxi", "nitr": "grade_nitr", "water": "grade_water",
         "tbn": "grade_tbn", "si": "grade_si", "fe": "grade_fe",
         "cu": "grade_cu", "al": "grade_al", "cr": "grade_cr",
         "pb": "grade_pb", "na": "grade_na"}


def _p(text, style=CELL_C):
    return Paragraph("" if text is None else str(text), style)


def _idn(v):
    """Angka format Indonesia (koma desimal)."""
    if v is None or v == "":
        return ""
    try:
        f = float(v)
    except (ValueError, TypeError):
        return str(v)
    s = str(int(f)) if f.is_integer() else str(round(f, 2))
    return s.replace(".", ",")


def _date(v):
    if not v:
        return ""
    p = str(v)[:10].split("-")
    return f"{p[2]}/{p[1]}/{p[0]}" if len(p) == 3 else str(v)


def _grid(t, header_rows=1):
    t.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ] + [("BACKGROUND", (0, r), (-1, r), GREEN) for r in range(header_rows)]))
    return t


def _logo_path():
    from pathlib import Path as _P
    p = _P(__file__).resolve().parent.parent / "assets" / "logopama.png"
    return str(p) if p.is_file() else None


def _kop(canvas, W, H, left_margin, right_margin):
    canvas.saveState()
    logo = _logo_path()
    text_x = left_margin
    if logo:
        lw = 9 * mm
        try:
            from PIL import Image as _PIL
            with _PIL.open(logo) as im:
                ratio = im.size[1] / im.size[0]
        except Exception:
            ratio = 1.0
        lh = lw * ratio
        canvas.drawImage(logo, left_margin, H - 5 * mm - lh,
                         width=lw, height=lh,
                         preserveAspectRatio=True, mask="auto")
        text_x = left_margin + lw + 4 * mm
    canvas.setFont("Helvetica-Bold", 10)
    canvas.setFillColor(colors.black)
    canvas.drawString(text_x, H - 13 * mm, "PT PAMAPERSADA NUSANTARA")
    canvas.setFont("Helvetica", 6)
    canvas.drawString(text_x, H - 17 * mm, "Mining And Earth Moving Contractor")
    canvas.setStrokeColor(colors.black)
    canvas.setLineWidth(0.5)
    canvas.line(left_margin, H - 21 * mm, W - right_margin, H - 21 * mm)
    canvas.restoreState()


def _footer(canvas, W, page):
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(GREY)
    canvas.drawCentredString(W / 2, 10 * mm, f"Halaman {page}")
    canvas.restoreState()


def _make_headfoot(W, H, left_margin, right_margin):
    def headfoot(canvas, doc):
        _kop(canvas, W, H, left_margin, right_margin)
        _footer(canvas, W, doc.page)
    return headfoot


def _component_block(unit, rows, width, cn_fallback, district_fallback):
    """Satu blok component lengkap. width = lebar tersedia (mm number)."""
    first = rows[0] if rows else {}
    district = first.get("district") or district_fallback or "-"
    band = Table([
        [_p("District", BAND), _p(district, BANDV),
         _p("Code Number", BAND), _p(first.get("vesselid") or cn_fallback, BANDV),
         _p("Component", BAND), _p(unit, BANDV)],
    ], colWidths=[w * mm for w in
                   [width * 0.12, width * 0.16, width * 0.15,
                    width * 0.14, width * 0.15, width * 0.28]])
    band.setStyle(TableStyle([
        ("GRID", (0, 0), (-1, -1), 0.5, colors.black),
        ("BACKGROUND", (0, 0), (-1, -1), TEAL),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    n = len(PARAMS)
    head1 = (["Lab No.", "Sampl Date", "Oil Type", "HM"]
             + [PLABEL[p] for p in PARAMS] + ["Condition"])
    head2 = (["Lead Time", "Analisys", "SAE", "HM Oil"] + [""] * n + [""])
    # proporsi kolom: lab 12%, sample 9%, oil 10%, hm 7%, hmoil 7%, param rata, cond 9%
    rest = width - width * (0.12 + 0.09 + 0.10 + 0.07 + 0.07 + 0.09)
    pw_ = rest / n
    widths = ([width * 0.12, width * 0.09, width * 0.10, width * 0.07,
               width * 0.07] + [pw_] * n + [width * 0.09])
    body = [[_p(h, HEAD) for h in head1],
            [_p(h, HEAD) for h in head2]]
    for r in rows:
        vals = [r.get("lab_no"), _date(r.get("sample_date")),
                r.get("oil_weight") or "-", _idn(r.get("unit_time"))]
        for p in PARAMS:
            g = r.get(GRADE[p])
            bad = g is not None and g != "" and g != "N"
            v = _idn(r.get(p))
            vals.append(Paragraph(
                f'<font color="{RED.hexval()}"><b>{v}</b></font>' if bad else v,
                CELL_C))
        cond = (r.get("condition") or "").upper()
        ccolor = DARK_GREEN.hexval() if cond == "NORMAL" else RED.hexval()
        vals.append(Paragraph(f'<font color="{ccolor}"><b>{cond}</b></font>', CELL_C))
        body.append([_p(v) for v in vals[:4]] + vals[4:-1] + [vals[-1]])
        lt = [_idn(r.get("lead_time")), _date(r.get("date_taken")),
              "-", _idn(r.get("unit_time_oils"))] + [""] * (n + 1)
        body.append([_p(v) for v in lt])
    lim = first
    wmin = ([Paragraph('<font color="white"><b>Warning Limit Minimum</b></font>', WHITEB)]
            + [_p("")] * 3
            + [Paragraph(f'<font color="white"><b>{_idn(lim.get(NMIN[p]))}</b></font>', CELL_C)
               for p in PARAMS] + [_p("")])
    wmax = ([Paragraph(f'<font color="{RED.hexval()}"><b>Warning Limit Maximum</b></font>', HEAD)]
            + [_p("")] * 3
            + [Paragraph(f'<font color="{RED.hexval()}"><b>{_idn(lim.get(NMAX[p]))}</b></font>', CELL_C)
               for p in PARAMS] + [_p("")])
    body += [wmin, wmax]
    # selaraskan kolom
    cols = len(head1)
    table_data = []
    for row in body:
        row = (row + [_p("")] * cols)[:cols]
        table_data.append(row)
    # SPAN untuk sel limit
    spans = [("SPAN", (0, -2), (3, -2)), ("SPAN", (0, -1), (3, -1))]
    t = Table(table_data, colWidths=[w * mm for w in widths], repeatRows=2)
    style = [("GRID", (0, 0), (-1, -1), 0.5, colors.black),
             ("BACKGROUND", (0, 0), (-1, 1), GREEN),
             ("BACKGROUND", (0, -2), (-1, -1), BLUE_BG),
             ("VALIGN", (0, 0), (-1, -1), "MIDDLE")] + spans
    t.setStyle(TableStyle(style))
    rec_text = next((r.get("english_description") for r in rows
                     if (r.get("english_description") or "").strip()), "-")
    rec = Table([[Paragraph("<b>Recommendation :</b><br/>" + str(rec_text), REC)]],
                colWidths=[width * mm])
    rec.setStyle(TableStyle([("BOX", (0, 0), (-1, -1), 0.5, colors.black),
                             ("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return [Paragraph(unit, H2L), Spacer(1, 1 * mm),
            band, Spacer(1, 2 * mm), t, Spacer(1, 2 * mm), rec]


def build_pama_pdf(eq, units_oil, latest_dbr, cn, district_default=None):
    """units_oil: [(unit, [rows])]. latest_dbr: dict|None (USM terbaru)."""
    buf = io.BytesIO()
    pw, ph = A4
    multi = len(units_oil) > 1
    if multi:  # landscape 2 kolom
        W, H = ph, pw
    else:      # portrait penuh
        W, H = pw, ph
    doc = BaseDocTemplate(buf, leftMargin=5 * mm, rightMargin=5 * mm,
                          topMargin=24 * mm, bottomMargin=5 * mm,
                          title=f"PAMA-{cn}", author="MTE Data Center")
    fw = W - 10 * mm
    headfoot = _make_headfoot(W, H, doc.leftMargin, doc.rightMargin)

    if multi:
        # koran 2 kolom: blok mengalir kolom1 -> kolom2 otomatis
        from reportlab.platypus import NextPageTemplate
        colw = (fw - 4 * mm) / 2
        fh = H - 29 * mm
        frames = [Frame(doc.leftMargin, doc.bottomMargin, colw, fh, id="c1"),
                  Frame(doc.leftMargin + colw + 4 * mm, doc.bottomMargin,
                        colw, fh, id="c2")]
        doc.addPageTemplates([
            PageTemplate(id="col2", frames=frames, pagesize=(W, H), onPage=headfoot),
            PageTemplate(id="full", frames=[Frame(
                doc.leftMargin, doc.bottomMargin, fw, fh, id="f")],
                pagesize=(W, H), onPage=headfoot),
        ])
    else:
        doc.addPageTemplates([PageTemplate(
            id="main", frames=[Frame(doc.leftMargin, doc.bottomMargin,
                                     fw, H - 29 * mm)],
            pagesize=(W, H), onPage=headfoot)])
    story = []
    if multi:
        for unit, rows in units_oil:
            story.append(KeepTogether(
                _component_block(unit, rows, colw / mm, cn, district_default)))
            story.append(Spacer(1, 3 * mm))
    else:
        for unit, rows in units_oil:
            story += [KeepTogether(
                _component_block(unit, rows, fw / mm, cn, district_default))]
    # --- halaman kerusakan ---
    d = latest_dbr or {}
    k = [[Paragraph('<font color="red"><b>Kerusakan Yang Terjadi</b></font>', KLABEL),
          _p(d.get("trouble") or "-")],
         [Paragraph('<font color="red"><b>Penyebab kerusakan</b></font>', KLABEL),
          _p(d.get("code") or "-")],
         [Paragraph('<font color="red"><b>Tindakan Yang Di Lakukan</b></font>', KLABEL),
          _p(d.get("action") or "-")],
         [Paragraph('<font color="red"><b>Oleh</b></font>', KLABEL),
          _p(d.get("mechanic") or "-"),
          Paragraph('<font color="red"><b>Date</b></font>', KLABEL),
          _p(_date(d.get("date")))]]
    kt = Table(k, colWidths=[32 * mm, fw - 32 * mm - 30 * mm - 30 * mm, 30 * mm, 30 * mm])
    kt.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), 0.5, colors.black),
                            ("VALIGN", (0, 0), (-1, -1), "TOP")]))
    if multi:
        from reportlab.platypus import NextPageTemplate, PageBreak
        story += [NextPageTemplate("full"), PageBreak(),
                  Paragraph("Kerusakan / Tindak Lanjut", H2),
                  Spacer(1, 2 * mm), kt]
    else:
        story += [Spacer(1, 4 * mm), kt]
    doc.build(story)
    return buf.getvalue()
