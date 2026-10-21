import urllib.request
import http.cookiejar
import ssl
import re
import json

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(cj),
    urllib.request.HTTPSHandler(context=ctx)
)

headers = [
    ('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'),
    ('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'),
    ('Accept-Language', 'id,en-US;q=0.9,en;q=0.8'),
    ('Cookie', 'pll_language=id')
]
opener.addheaders = headers

url = 'https://www.pedulianak.org/id/sponsor-full-screen/'
print(f"--- Mengakses: {url} ---")
with opener.open(url, timeout=20) as resp:
    html = resp.read().decode('utf-8', errors='ignore')
    print(f"Status: {resp.status}, Length: {len(html)}")
    
    # Simpan ke file untuk dianalisis
    with open('d:/LENOVO/Downloads/AsuhKita Mobile/AsuhKita/pedulianak_sponsor.html', 'w', encoding='utf-8') as f:
        f.write(html)
    print("Disimpan ke pedulianak_sponsor.html")
    
    # Cari endpoint ajax / api
    ajax_urls = re.findall(r'[\"\']([^\"\']*(?:ajax|api|sponsor|child|children)[^\"\']*)[\"\']', html, re.I)
    print("Kemungkinan API endpoints:")
    for a in set(ajax_urls)[:20]:
        if 'http' in a or 'wp-' in a:
            print("  ", a)
