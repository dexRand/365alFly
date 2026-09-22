#!/usr/bin/env python3
"""Generate the fidelity test decks for docs/TEST_MATRIX.md.

Stdlib-only OOXML writer. Produces one .pptx per matrix row where the
element can be expressed in raw DrawingML. Elements not expressible
(SmartArt, charts, media) are documented in test_files/README.md and
must be created with real PowerPoint on the native reference machine.

Usage: python3 scripts/gen-test-decks.py [OUTDIR]  (default: winapps-baseline/test_files)
"""
import io
import os
import struct
import sys
import zlib
import zipfile

EMU = 914400  # 1 inch


def emu(cm: float) -> int:
    return int(cm / 2.54 * EMU)


# ---------------------------------------------------------------- png (stdlib)
def make_png(width: int, height: int, rgb: tuple) -> bytes:
    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        c += struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
        return c

    raw = b""
    row = b"\x00" + bytes(rgb) * width
    for _ in range(height):
        raw += row
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


# ---------------------------------------------------------- ooxml building
def content_types(n: int) -> str:
    overrides = (
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
        '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>'
        '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
        '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
        '<Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>'
    )
    for i in range(1, n + 1):
        overrides += f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
    return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            f'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            f'<Default Extension="xml" ContentType="application/xml"/>'
            f'<Default Extension="png" ContentType="image/png"/>'
            f'{overrides}</Types>')

ROOT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>"""

THEME = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="pptx-open-th">
<a:themeElements>
<a:clrScheme name="pptx-open">{FMTSCHEME}</a:clrScheme>
<a:fontScheme name="pptx-open">
<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="pptx-open">
<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
<a:lnStyleLst><a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln><a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln><a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln></a:lnStyleLst>
<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
</a:theme>"""

FMTSCHEME = ('<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
             '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
             '<a:dk2><a:srgbClr val="1F497D"/></a:dk2>'
             '<a:lt2><a:srgbClr val="EEECE1"/></a:lt2>'
             '<a:accent1><a:srgbClr val="4F81BD"/></a:accent1>'
             '<a:accent2><a:srgbClr val="C0504D"/></a:accent2>'
             '<a:accent3><a:srgbClr val="9BBB59"/></a:accent3>'
             '<a:accent4><a:srgbClr val="8064A2"/></a:accent4>'
             '<a:accent5><a:srgbClr val="4BACC6"/></a:accent5>'
             '<a:accent6><a:srgbClr val="F79646"/></a:accent6>'
             '<a:hlink><a:srgbClr val="0000FF"/></a:hlink>'
             '<a:folHlink><a:srgbClr val="800080"/></a:folHlink>')

SLIDE_MASTER = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:bg><p:bgPr><a:solidFill><a:schemeClr val="bg1"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree></p:cSld>
<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
<p:txStyles>
<p:titleStyle><a:lvl1pPr><a:defRPr sz="4400" kern="1200"/></a:lvl1pPr><a:lvl2pPr/><a:lvl3pPr/><a:lvl4pPr/><a:lvl5pPr/><a:lvl6pPr/><a:lvl7pPr/><a:lvl8pPr/><a:lvl9pPr/></p:titleStyle>
<p:bodyStyle><a:lvl1pPr/><a:lvl2pPr/><a:lvl3pPr/><a:lvl4pPr/><a:lvl5pPr/><a:lvl6pPr/><a:lvl7pPr/><a:lvl8pPr/><a:lvl9pPr/></p:bodyStyle>
<p:otherStyle><a:lvl1pPr/><a:lvl2pPr/><a:lvl3pPr/><a:lvl4pPr/><a:lvl5pPr/><a:lvl6pPr/><a:lvl7pPr/><a:lvl8pPr/><a:lvl9pPr/></p:otherStyle>
</p:txStyles>
</p:sldMaster>"""

SLIDE_MASTER_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>"""

SLIDE_LAYOUT = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
<p:cSld name="Blank"><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
</p:spTree></p:cSld>
<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>"""

SLIDE_LAYOUT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>"""

PRES_PROPS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentationPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>
"""


def presentation_xml(n: int) -> str:
    ids = "".join(f'<p:sldId id="{256 + i}" r:id="rId{i+1}"/>' for i in range(n))
    return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
            f'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
            f'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
            f'<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId100"/></p:sldMasterIdLst>'
            f'<p:sldIdLst>{ids}</p:sldIdLst>'
            f'<p:sldSz cx="{emu(33.867)}" cy="{emu(19.05)}"/>'
            f'<p:notesSz cx="6858000" cy="9144000"/>'
            f'</p:presentation>')


def presentation_rels(n: int, with_images: dict) -> str:
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>')
    for i in range(n):
        rels += f'<Relationship Id="rId{i+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i+1}.xml"/>'
    return rels + "</Relationships>"


def slide_rels(images: dict) -> str:
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    for rid in images:
        rels += f'<Relationship Id="rId{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image{rid}.png"/>'
    return rels + "</Relationships>"


def nvgrp() -> str:
    return ('<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
            '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>')


def sp_rect(idx: int, x: float, y: float, w: float, h: float, fill: str,
            text: str = "", font: str = None, sz: int = 1800, alpha: int = 100000,
            line: str = None, fill_alpha: int = 100000, anchor: str = "ctr",
            wrap: str = "square", autofit: bool = False, pre: str = "",
            post: str = "", geom: str = "rect") -> str:
    xfrm = f'<a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(w)}" cy="{emu(h)}"/></a:xfrm>'
    fge = f'<a:prstGeom prst="{geom}"><a:avLst/></a:prstGeom>'
    fillxml = ""
    if fill:
        fillxml = f'<a:solidFill><a:srgbClr val="{fill}"><a:alpha val="{fill_alpha}"/></a:srgbClr></a:solidFill>'
    linexml = ""
    if line:
        linexml = f'<a:ln w="12700"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>'
    rpr = f'<a:rPr lang="en-US" sz="{sz}" dirty="0"'
    if font:
        rpr += f'><a:latin typeface="{font}"/><a:ea typeface="{font}"/></a:rPr>'
    else:
        rpr += '/>'
    body_extra = ' wrap="none"' if wrap == "none" else ""
    body_extra += f' anchor="{anchor}"'
    autofitxml = '<a:normAutofit fontScale="100000" lnSpcReduction="0"/>' if autofit else ""
    if text:
        txbody = (f'<p:txBody><a:bodyPr vertOverflow="clip"{body_extra}>{autofitxml}</a:bodyPr>'
                  f'<a:lstStyle/><a:p><a:r>{rpr}<a:t>{text}</a:t></a:r></a:p></p:txBody>')
    else:
        txbody = (f'<p:txBody><a:bodyPr{body_extra}>{autofitxml}</a:bodyPr>'
                  f'<a:lstStyle/><a:p><a:endParaRPr lang="en-US"/></a:p></p:txBody>')
    eff = f'<a:effectLst><a:alphaModFix amt="{alpha}"/></a:effectLst>' if alpha < 100000 else "<a:effectLst/>"
    return (f'<p:sp>{pre}'
            f'<p:nvSpPr><p:cNvPr id="{idx}" name="Shape{idx}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
            f'<p:spPr>{xfrm}{fge}{fillxml}{linexml}{eff}</p:spPr>'
            f'{txbody}'
            f'{post}</p:sp>')


def sp_group(idx: int, children: list) -> str:
    inner = "".join(children)
    return (f'<p:grpSp>'
            f'<p:nvGrpSpPr><p:cNvPr id="{idx}" name="Group{idx}"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
            f'<p:grpSpPr><a:xfrm><a:off x="{emu(2)}" y="{emu(2)}"/><a:ext cx="{emu(6)}" cy="{emu(4)}"/>'
            f'<a:chOff x="0" y="0"/><a:chExt cx="{emu(6)}" cy="{emu(4)}"/></a:xfrm></p:grpSpPr>'
            f'{inner}</p:grpSp>')


def slide_xml(shapes: str, transition: str = "", timing: str = "", bg: str = "") -> str:
    bgxml = ""
    if bg:
        bgxml = f'<p:bg><p:bgPr><a:solidFill><a:srgbClr val="{bg}"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
    return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
            f'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
            f'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
            f'<p:cSld>{bgxml}<p:spTree>{nvgrp()}{shapes}</p:spTree></p:cSld>'
            f'<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
            f'{transition}{timing}'
            f'</p:sld>')


def build_deck(path: str, slide_bodies: list, images: dict = None) -> None:
    images = images or {}
    n = len(slide_bodies)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types(n))
        z.writestr("_rels/.rels", ROOT_RELS)
        z.writestr("ppt/presentation.xml", presentation_xml(n))
        z.writestr("ppt/_rels/presentation.xml.rels", presentation_rels(n, images))
        z.writestr("ppt/presProps.xml", PRES_PROPS)
        z.writestr("ppt/theme/theme1.xml", THEME.replace("{FMTSCHEME}", FMTSCHEME))
        z.writestr("ppt/slideMasters/slideMaster1.xml", SLIDE_MASTER)
        z.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", SLIDE_MASTER_RELS)
        z.writestr("ppt/slideLayouts/slideLayout1.xml", SLIDE_LAYOUT)
        z.writestr("ppt/slideLayouts/_rels/slideLayout1.xml.rels", SLIDE_LAYOUT_RELS)
        for rid, blob in images.items():
            z.writestr(f"ppt/media/image{rid}.png", blob)
        for i, body in enumerate(slide_bodies, start=1):
            z.writestr(f"ppt/slides/slide{i}.xml", body)
            z.writestr(f"ppt/slides/_rels/slide{i}.xml.rels", slide_rels(images))
    print(f"  wrote {os.path.relpath(path)}")


# --------------------------------------------------------------- decks
def deck_fonts():
    rows = [
        ('font', 'Arial', 'Arial standard font'),
        ('font', 'Georgia', 'Georgia - not installed by default on Windows'),
        ('font', 'Times New Roman', 'TNR classic'),
        ('font', 'Courier New', 'Courier New mono'),
        ('font', 'Impact', 'Impact heavy'),
        ('font', 'Comic Sans MS', 'Comic Sans MS'),
    ]
    slides = []
    for i, (_, f, label) in enumerate(rows):
        y = 1 + i * 2.6
        slides.append(slide_xml(
            sp_rect(2, 1, y, 30, 1.8, None, label, font=f, sz=2200)
            + sp_rect(3, 1, y + 1.9, 30, 1.8, "F2F2F2", f"(specified: {f})", font=f, sz=1600)
        ))
    return slides, {}


def deck_textboxes():
    s1 = (sp_rect(2, 1, 1, 12, 6, None, "wrap=off long text that will overflow the box boundary and keep going",
                  sz=2000, wrap="none")
          + sp_rect(3, 15, 1, 12, 6, "DDEEFF", "wrap=square",
                    sz=2000, wrap="square"))
    s2 = (sp_rect(2, 1, 1, 12, 8, None, "autofit=on this box shrinks text to fit",
                  sz=4000, autofit=True)
          + sp_rect(3, 15, 1, 12, 2, None, "anchor=top", sz=2000, anchor="t")
          + sp_rect(4, 15, 4, 12, 2, None, "anchor=bottom", sz=2000, anchor="b"))
    return [slide_xml(s1), slide_xml(s2)], {}


def deck_transparency():
    s1 = (sp_rect(2, 1, 1, 20, 12, "C0504D", "", fill_alpha=100000)
          + sp_rect(3, 4, 3, 20, 12, "4BACC6", "", fill_alpha=50000)
          + sp_rect(4, 7, 5, 20, 12, "9BBB59", "", fill_alpha=25000))
    s2 = (sp_rect(2, 1, 1, 20, 3, "000000", "", fill_alpha=30000)
          + sp_rect(3, 1, 6, 20, 3, "000000", "", fill_alpha=60000)
          + sp_rect(4, 1, 11, 20, 3, "000000", "", fill_alpha=90000))
    return [slide_xml(s1), slide_xml(s2)], {}


def deck_shapes():
    s1 = (sp_rect(2, 1, 1, 8, 8, "C0392B", "square", geom="rect")
          + sp_rect(3, 10, 1, 8, 8, "2980B9", "rounded", geom="roundRect")
          + sp_rect(4, 19, 1, 8, 8, "27AE60", "ellipse", geom="ellipse"))
    s2 = (sp_rect(2, 1, 1, 18, 5, "8E44AD", "", geom="diamond")
          + sp_rect(3, 1, 7, 8, 8, "E67E22", "", geom="triangle")
          + sp_rect(4, 10, 7, 14, 8, "E74C3C", "", geom="rightArrow"))
    return [slide_xml(s1), slide_xml(s2)], {}


def deck_image(with_alpha: bool):
    png = make_png(64, 64, (0x2E, 0xCC, 0x71))
    F = emu(0.3)
    pic_wo = ('<p:pic><p:nvPicPr><p:cNvPr id="2" name="Pic1"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>'
              f'<p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
              f'<p:spPr><a:xfrm><a:off x="{emu(1)}" y="{emu(1)}"/><a:ext cx="{int(F*16)}" cy="{int(F*16)}"/></a:xfrm>'
              f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>')
    pic_alpha_fill = ('<p:pic><p:nvPicPr><p:cNvPr id="3" name="Pic2"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>'
                      '<p:blipFill><a:blip r:embed="rId3"><a:alphaModFix amt="40000"/></a:blip><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
                      f'<p:spPr><a:xfrm><a:off x="{emu(12)}" y="{emu(1)}"/><a:ext cx="{int(F*16)}" cy="{int(F*16)}"/></a:xfrm>'
                      f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>')
    s1 = slide_xml(pic_wo + pic_alpha_fill)
    return [s1], {2: png, 3: png}


def deck_tables():
    # 3x3 table with header fill, borders, two text cells
    grid = ''.join(f'<a:gridCol w="{emu(9)}"/>' for _ in range(3))
    def cell(text, fill=None, w_row=0):
        f = f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else "<a:noFill/>"
        return (f'<a:tc><a:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/>'
                f'<a:p><a:r><a:rPr lang="en-US" sz="1400" dirty="0"/><a:t>{text}</a:t></a:r></a:p></a:txBody>'
                f'<a:tcPr marL="91440" marR="91440" marT="45720" marB="45720">{f}'
                f'<a:lnL w="9525"><a:solidFill><a:srgbClr val="1F1F1F"/></a:solidFill></a:lnL>'
                f'<a:lnR w="9525"><a:solidFill><a:srgbClr val="1F1F1F"/></a:solidFill></a:lnR>'
                f'<a:lnT w="9525"><a:solidFill><a:srgbClr val="1F1F1F"/></a:solidFill></a:lnT>'
                f'<a:lnB w="9525"><a:solidFill><a:srgbClr val="1F1F1F"/></a:solidFill></a:lnB>'
                f'</a:tcPr></a:tc>')
    rows = ('<a:tr h="822960"><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="1500" b="1" dirty="0"/><a:t>Head A</a:t></a:r></a:p></a:txBody><a:tcPr><a:solidFill><a:srgbClr val="4F81BD"/></a:solidFill></a:tcPr></a:tc>' +
            cell("Head B", "4F81BD") + cell("Head C", "4F81BD") + '</a:tr>'
            + f'<a:tr h="600000">' + cell("data 1") + cell("data 2") + cell("data 3") + '</a:tr>'
            + f'<a:tr h="600000">' + cell("left") + cell("center") + cell("right") + '</a:tr>')
    tbl = (f'<p:graphicFrame>'
           f'<p:nvGraphicFramePr><p:cNvPr id="2" name="Table1"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
           f'<p:xfrm><a:off x="{emu(3)}" y="{emu(2)}"/><a:ext cx="{emu(27)}" cy="{emu(12)}"/></p:xfrm>'
           f'<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
           f'<a:tbl><a:tblPr firstRow="1" bandRow="0"><a:tableStyleId>{{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}}</a:tableStyleId></a:tblPr>'
           f'<a:tblGrid>{grid}</a:tblGrid>{rows}</a:tbl></a:graphicData></a:graphic></p:graphicFrame>')
    return [slide_xml(tbl)], {}


def deck_zorder():
    base = (sp_rect(2, 2, 2, 14, 10, "C0504D", "bg red (first)")
            + sp_rect(3, 6, 4, 14, 10, "4BACC6", "mid cyan")
            + sp_rect(4, 10, 6, 14, 10, "9BBB59", "front green (last)"))
    reversed_shapes = (sp_rect(2, 2, 2, 14, 10, "9BBB59", "now green drawn first")
                       + sp_rect(3, 6, 4, 14, 10, "4BACC6", "mid cyan")
                       + sp_rect(4, 10, 6, 14, 10, "C0504D", "now red on top"))
    return [slide_xml(base), slide_xml(reversed_shapes)], {}


def deck_groups():
    g1 = sp_group(2, [sp_rect(3, 0, 0, 4, 4, "E74C3C", "A"), sp_rect(4, 4, 2, 4, 4, "3498DB", "B")])
    g2 = sp_group(5, [sp_rect(6, 0, 0, 4, 4, "27AE60", "C"), sp_rect(7, 4, 2, 4, 4, "F1C40F", "D")])
    return [slide_xml(g1 + g2)], {}


TRANS_FADE = ('<p:transition spd="med"><p:fade/></p:transition>')
TRANS_PUSH = ('<p:transition spd="med"><p:push dir="l"/></p:transition>')


def deck_transitions():
    s1 = slide_xml(sp_rect(2, 5, 5, 20, 6, "9B59B6", "slide 1 - fade next", sz=2400),
                   transition=TRANS_FADE)
    s2 = slide_xml(sp_rect(2, 5, 5, 20, 6, "E67E22", "slide 2 - push left next", sz=2400),
                   transition=TRANS_PUSH)
    return [s1, s2], {}


ANIM = (
    "<p:timing><p:tnLst><p:par><p:cTn id=\"1\" dur=\"indefinite\" restart=\"never\" nodeType=\"tmRoot\">"
    "<p:childTnLst>"
    "<p:seq concurrent=\"1\" nextAc=\"seek\"><p:cTn id=\"2\" dur=\"indefinite\" nodeType=\"mainSeq\">"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"3\" fill=\"hold\"><p:stCondLst><p:cond delay=\"indefinite\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"4\" fill=\"hold\"><p:stCondLst><p:cond delay=\"0\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"5\" presetID=\"2\" presetClass=\"entr\" presetSubtype=\"0\" fill=\"hold\" nodeType=\"clickEffect\">"
    "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"6\" presetID=\"2\" presetClass=\"entr\" presetSubtype=\"0\" fill=\"hold\">"
    "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"7\" presetID=\"2\" presetClass=\"entr\" presetSubtype=\"0\" fill=\"hold\" nodeType=\"withEffect\">"
    "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:par><p:cTn id=\"8\" presetID=\"2\" presetClass=\"entr\" presetSubtype=\"0\" fill=\"hold\" nodeType=\"withEffect\">"
    "<p:stCondLst><p:cond delay=\"0\"/></p:stCondLst>"
    "<p:childTnLst>"
    "<p:animEffect transition=\"in\" filter=\"fade\"><p:cBhvr>"
    "<p:cTn id=\"9\" dur=\"500\" fill=\"hold\"><p:stCondLst><p:cond delay=\"0\"/></p:stCondLst></p:cTn>"
    "<p:tgtEl><p:spTgt spid=\"2\"/></p:tgtEl>"
    "<p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst>"
    "</p:cBhvr></p:animEffect>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst></p:cTn></p:par>"
    "</p:childTnLst>"
    "<p:prevCondLst><p:cond evt=\"onPrev\" delay=\"0\"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>"
    "<p:nextCondLst><p:cond evt=\"onNext\" delay=\"0\"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>"
    "</p:cTn></p:seq>"
    "</p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>"
)


def deck_animation():
    s1 = slide_xml(sp_rect(2, 3, 3, 24, 6, "2C3E50", "this box fades in on click", sz=2600), timing=ANIM)
    s2 = slide_xml(sp_rect(2, 3, 3, 24, 6, "16A085", "plain box (control)", sz=2600))
    return [s1, s2], {}


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "winapps-baseline/test_files"
    os.makedirs(outdir, exist_ok=True)
    decks = {
        "fonts.pptx": deck_fonts(),
        "textboxes.pptx": deck_textboxes(),
        "transparency.pptx": deck_transparency(),
        "shapes.pptx": deck_shapes(),
        "image.pptx": deck_image(with_alpha=True),
        "tables.pptx": deck_tables(),
        "zorder.pptx": deck_zorder(),
        "groups.pptx": deck_groups(),
        "transitions.pptx": deck_transitions(),
        "animation.pptx": deck_animation(),
    }
    for name, (slides, images) in decks.items():
        build_deck(os.path.join(outdir, name), slides, images)


if __name__ == "__main__":
    main()