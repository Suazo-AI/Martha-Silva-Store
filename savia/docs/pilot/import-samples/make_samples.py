"""Writes the two catalog import samples. Run: python savia/docs/pilot/import-samples/make_samples.py

The samples are demo data, not inventory. Codes use the 7459990 prefix so they never collide with the demo seed (75000010000xx).
The XLSX is written with zipfile so the sample needs no spreadsheet library; the column order differs from the CSV on purpose.
"""
import csv
import io
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

HERE = Path(__file__).resolve().parent


def ean13(body12: str) -> str:
    total = sum(int(d) * (3 if i % 2 else 1) for i, d in enumerate(body12))
    return body12 + str((10 - total % 10) % 10)


CSV_ROWS = [
    # code, sku, name, type, size, color, cost, price, stock
    (ean13("745999000101"), "IMP-VES-S-ROJ", "Vestido lino importado", "Vestido", "S", "Rojo", "420.00", "980.00", "3"),
    (ean13("745999000102"), "IMP-VES-M-ROJ", "Vestido lino importado", "Vestido", "M", "Rojo", "420.00", "980.00", "2"),
    (ean13("745999000103"), "IMP-PAN-30-NEG", "Pantalon recto importado", "Pantalon", "30", "Negro", "310.50", "1,150.00", "4"),
    (ean13("745999000104"), "", "Camisa manga larga importada", "Camisa", "L", "Blanco", "260", "C$ 690", "1"),
]
XLSX_HEADERS = ["Descripcion", "Precio venta", "Talla", "Color", "Existencias", "Codigo", "Costo unitario", "Categoria", "Referencia"]
XLSX_ROWS = [
    ["Chaqueta denim importada", "1450", "M", "Azul", "2", ean13("745999000201"), "690", "Chaqueta", "IMP-CHA-M-AZU"],
    ["Chaqueta denim importada", "1450", "L", "Azul", "1", ean13("745999000202"), "690", "Chaqueta", "IMP-CHA-L-AZU"],
    ["Falda plisada importada", "780.5", "S", "Verde", "3", ean13("745999000203"), "350", "Falda", "IMP-FAL-S-VER"],
]


def write_csv() -> None:
    out = io.StringIO()
    writer = csv.writer(out, delimiter=";", lineterminator="\r\n")
    writer.writerow(["Codigo de barras", "Referencia", "Descripcion", "Tipo de prenda", "Talla", "Color", "Costo", "Precio", "Existencia"])
    writer.writerows(CSV_ROWS)
    (HERE / "catalogo-ejemplo.csv").write_bytes(("﻿" + out.getvalue()).encode("utf-8"))


def col(i: int) -> str:
    return chr(ord("A") + i)


def write_xlsx() -> None:
    strings: list[str] = []

    def shared(value: str) -> int:
        if value not in strings:
            strings.append(value)
        return strings.index(value)

    numeric = {"Precio venta", "Existencias", "Codigo", "Costo unitario"}
    rows_xml = []
    for r, row in enumerate([XLSX_HEADERS, *XLSX_ROWS], start=1):
        cells = []
        for c, value in enumerate(row):
            ref = f"{col(c)}{r}"
            if r > 1 and XLSX_HEADERS[c] in numeric:
                cells.append(f'<c r="{ref}"><v>{value}</v></c>')  # Excel keeps codes and prices as numbers
            else:
                cells.append(f'<c r="{ref}" t="s"><v>{shared(value)}</v></c>')
        rows_xml.append(f'<row r="{r}">{"".join(cells)}</row>')
    main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    parts = {
        "[Content_Types].xml": '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
        "_rels/.rels": '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
        "xl/workbook.xml": f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="{main}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="Inventario" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels": '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
        "xl/styles.xml": f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="{main}"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders>'
        '<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="1"><xf xfId="0"/></cellXfs></styleSheet>',
        "xl/worksheets/sheet1.xml": f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="{main}"><sheetData>{"".join(rows_xml)}</sheetData></worksheet>',
    }
    parts["xl/sharedStrings.xml"] = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><sst xmlns="{main}" count="{len(strings)}" uniqueCount="{len(strings)}">'
                                     + "".join(f"<si><t>{escape(s)}</t></si>" for s in strings) + "</sst>")
    with zipfile.ZipFile(HERE / "inventario-ejemplo.xlsx", "w", zipfile.ZIP_DEFLATED) as zf:
        for name, xml in parts.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 11, 12, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, xml)


if __name__ == "__main__":
    write_csv()
    write_xlsx()
    print("wrote", HERE / "catalogo-ejemplo.csv", HERE / "inventario-ejemplo.xlsx")
