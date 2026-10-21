import urllib.request
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

photos = [
    "https://www.pedulianak.org/wp-content/uploads/2025/08/6-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/07/Ayra-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6859-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6838-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/07/DSCF6843-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8123-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF7024-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2026/08/DSCF8114-200x300.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2022/10/Hamdi.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2024/08/DSCF0645-1-563x375.jpg",
    "https://www.pedulianak.org/wp-content/uploads/2024/08/DSCF4843-1-570x365.jpg"
]

print("Validasi URL foto dari pedulianak.org:")
valid_photos = []
for p in photos:
    try:
        req = urllib.request.Request(p, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=8) as r:
            print(f"[OK] {r.status} - {p}")
            valid_photos.append(p)
    except Exception as e:
        print(f"[ERR] {e} - {p}")

print(f"\nTotal foto valid & aktif: {len(valid_photos)}")
