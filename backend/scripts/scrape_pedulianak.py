import urllib.request
import http.cookiejar
import ssl
import re

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

urls = [
    'https://www.pedulianak.org/id/',
    'https://www.pedulianak.org/sponsor-a-child/',
]

for url in urls:
    try:
        print(f"\n--- Mengakses: {url} ---")
        with opener.open(url, timeout=15) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
            print(f"Status: {resp.status}, Final URL: {resp.url}, Length: {len(html)}")
            

            sponsor_links = set(re.findall(r'href=[\"\'](https://www\.pedulianak\.org/[^\"]*sponsor[^\"]*)[\"\']', html, re.IGNORECASE))
            print("Sponsor links:")
            for sl in sponsor_links:
                print("  ", sl)
                

            uploads = set(re.findall(r'https://www\.pedulianak\.org/wp-content/uploads/[^\s\"\'<>]+\.(?:jpg|jpeg|png|webp)', html))
            print(f"Uploads: {len(uploads)}")
            for u in sorted(uploads)[:20]:
                print("  ", u)
    except Exception as e:
        print(f"Error {url}: {e}")
