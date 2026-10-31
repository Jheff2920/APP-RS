"""Generate fixed-size PDF samples using only the Python standard library.

Run from the repository root: python tool/create_label_test_pdfs.py
"""
from pathlib import Path


def make_pdf(width_mm, height_mm, count):
    width, height = width_mm * 72 / 25.4, height_mm * 72 / 25.4
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>", b"", b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
    pages = []
    for number in range(1, count + 1):
        page_id = len(objects) + 1
        stream_id = page_id + 1
        pages.append(f"{page_id} 0 R")
        objects.append((f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width:.4f} {height:.4f}] "
                        f"/Resources << /Font << /F1 3 0 R >> >> /Contents {stream_id} 0 R >>").encode())
        # The border is 2 mm from the edge. A second line measures exactly 10 mm.
        inset = 2 * 72 / 25.4
        drawing = (f"0 G 0.5 w {inset:.4f} {inset:.4f} {width - 2 * inset:.4f} {height - 2 * inset:.4f} re S\n"
                   f"BT /F1 7 Tf {inset + 3:.4f} {height - inset - 10:.4f} Td (RED SOLUCIONES) Tj ET\n"
                   f"BT /F1 6 Tf {inset + 3:.4f} {height - inset - 20:.4f} Td ({width_mm} x {height_mm} mm - {number}/{count}) Tj ET\n"
                   f"{inset + 3:.4f} {inset + 6:.4f} m {inset + 3 + 10 * 72 / 25.4:.4f} {inset + 6:.4f} l S\n").encode()
        objects.append(b"<< /Length " + str(len(drawing)).encode() + b" >>\nstream\n" + drawing + b"endstream")
    objects[1] = f"<< /Type /Pages /Kids [{' '.join(pages)}] /Count {count} >>".encode()
    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for i, data in enumerate(objects, 1):
        offsets.append(len(pdf))
        pdf.extend(f"{i} 0 obj\n".encode() + data + b"\nendobj\n")
    start = len(pdf)
    pdf.extend(f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode())
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode())
    pdf.extend(f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n".encode())
    return pdf


if __name__ == "__main__":
    output = Path(__file__).resolve().parents[1] / "inst-apk" / "impresoras-logicas"
    output.mkdir(parents=True, exist_ok=True)
    for width, height in [(50, 25), (30, 20)]:
        target = output / f"etiquetas-{width}x{height}-3-paginas.pdf"
        target.write_bytes(make_pdf(width, height, 3))
        print(target)
