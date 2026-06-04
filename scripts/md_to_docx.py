#!/usr/bin/env python3
"""Convert the Swan Match Step 22/23/24 markdown docs into editable Word (.docx) files."""
import os
import re
from docx import Document
from docx.shared import Pt, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT

ROOT = "/Users/apple/Downloads/Swan_Match_app-main"
OUT_DIR = os.path.join(ROOT, "docs", "word")
os.makedirs(OUT_DIR, exist_ok=True)

FILES = [
    "docs/legal/Contractor_IP_Assignment_and_NDA.md",
    "docs/brand/Trademark_Protection_Checklist.md",
    "docs/brand/Brand_Asset_Ownership_Register.md",
    "docs/sops/Refund_SOP.md",
    "docs/sops/Deployment_Runbook.md",
    "docs/sops/Incident_Response_Runbook.md",
    "docs/sops/Escalation_Tree.md",
    "docs/sops/Backup_Restore_Drill.md",
    "docs/strategy/Exit_Strategy.md",
]

GOLD = RGBColor(0xB8, 0x86, 0x0B)
GREY = RGBColor(0x55, 0x55, 0x55)

INLINE_RE = re.compile(r"(\*\*.+?\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))")


def add_inline(paragraph, text):
    """Render **bold**, `code`, and [link](url) into runs."""
    for part in INLINE_RE.split(text):
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            r = paragraph.add_run(part[2:-2]); r.bold = True
        elif part.startswith("`") and part.endswith("`"):
            r = paragraph.add_run(part[1:-1]); r.font.name = "Courier New"; r.font.size = Pt(9.5)
        elif part.startswith("[") and "](" in part:
            label = part[1:part.index("]")]
            r = paragraph.add_run(label); r.font.color.rgb = RGBColor(0x1F, 0x5F, 0xB4)
        else:
            paragraph.add_run(part)


def is_table_sep(line):
    return bool(re.match(r"^\s*\|?[\s:\-|]+\|?\s*$", line)) and "-" in line


def flush_table(doc, rows):
    if not rows:
        return
    header = rows[0]
    ncols = len(header)
    table = doc.add_table(rows=0, cols=ncols)
    table.style = "Light Grid Accent 1"
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    for ri, cells in enumerate(rows):
        cells = (cells + [""] * ncols)[:ncols]
        row = table.add_row().cells
        for ci, cell in enumerate(cells):
            p = row[ci].paragraphs[0]
            add_inline(p, cell.strip())
            for run in p.runs:
                run.font.size = Pt(9)
                if ri == 0:
                    run.bold = True
    doc.add_paragraph()


def convert(md_path, out_path):
    with open(md_path, encoding="utf-8") as f:
        lines = f.read().split("\n")

    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(10.5)

    i = 0
    in_code = False
    code_buf = []
    table_buf = []

    def flush_code():
        nonlocal code_buf
        if code_buf:
            p = doc.add_paragraph()
            r = p.add_run("\n".join(code_buf))
            r.font.name = "Courier New"; r.font.size = Pt(9)
            p.paragraph_format.left_indent = Inches(0.2)
            code_buf = []

    while i < len(lines):
        line = lines[i]

        # code fences
        if line.strip().startswith("```"):
            if in_code:
                flush_code(); in_code = False
            else:
                in_code = True
            i += 1
            continue
        if in_code:
            code_buf.append(line); i += 1; continue

        # tables
        if line.strip().startswith("|") and i + 1 < len(lines) and is_table_sep(lines[i + 1]):
            table_buf = [[c for c in line.strip().strip("|").split("|")]]
            i += 2  # skip header + separator
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_buf.append([c for c in lines[i].strip().strip("|").split("|")])
                i += 1
            flush_table(doc, table_buf)
            table_buf = []
            continue

        stripped = line.strip()

        # blank
        if not stripped:
            i += 1; continue

        # horizontal rule
        if re.match(r"^---+$", stripped):
            doc.add_paragraph().add_run("_" * 60).font.color.rgb = RGBColor(0xCC, 0xCC, 0xCC)
            i += 1; continue

        # headings
        m = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if m:
            level = len(m.group(1))
            h = doc.add_heading(level=min(level, 4))
            add_inline(h, m.group(2))
            for run in h.runs:
                if level == 1:
                    run.font.color.rgb = RGBColor(0x1a, 0x1a, 0x2e)
                else:
                    run.font.color.rgb = GOLD if level == 2 else RGBColor(0x33, 0x33, 0x33)
            i += 1; continue

        # blockquote
        if stripped.startswith(">"):
            quote = stripped.lstrip(">").strip()
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.25)
            add_inline(p, quote)
            for run in p.runs:
                run.italic = True; run.font.color.rgb = GREY; run.font.size = Pt(9.5)
            i += 1; continue

        # checkbox list
        mcb = re.match(r"^(\s*)- \[( |x|X)\]\s+(.*)$", line)
        if mcb:
            indent = len(mcb.group(1)) // 2
            p = doc.add_paragraph(style="List Bullet")
            p.paragraph_format.left_indent = Inches(0.3 + 0.25 * indent)
            box = "[x] " if mcb.group(2).lower() == "x" else "[ ] "
            p.add_run(box)
            add_inline(p, mcb.group(3))
            i += 1; continue

        # bullet list
        mb = re.match(r"^(\s*)[-*]\s+(.*)$", line)
        if mb:
            indent = len(mb.group(1)) // 2
            p = doc.add_paragraph(style="List Bullet")
            p.paragraph_format.left_indent = Inches(0.3 + 0.25 * indent)
            add_inline(p, mb.group(2))
            i += 1; continue

        # numbered list
        mn = re.match(r"^(\s*)\d+\.\s+(.*)$", line)
        if mn:
            p = doc.add_paragraph(style="List Number")
            add_inline(p, mn.group(2))
            i += 1; continue

        # normal paragraph
        p = doc.add_paragraph()
        add_inline(p, stripped)
        i += 1

    flush_code()
    doc.save(out_path)
    return out_path


def main():
    made = []
    for rel in FILES:
        md = os.path.join(ROOT, rel)
        name = os.path.splitext(os.path.basename(rel))[0] + ".docx"
        out = os.path.join(OUT_DIR, name)
        convert(md, out)
        made.append(out)
    print(f"Created {len(made)} Word files in {OUT_DIR}:")
    for m in made:
        print("  -", os.path.basename(m))


if __name__ == "__main__":
    main()
