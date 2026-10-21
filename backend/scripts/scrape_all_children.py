import urllib.request
import urllib.parse
import ssl
import json
import re

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

url = 'https://www.pedulianak.org/wp-admin/admin-ajax.php'
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'X-Requested-With': 'XMLHttpRequest',
    'Cookie': 'pll_language=id'
}

all_children = []

for page in range(1, 4):
    print(f"Fetching page {page}...")
    data = urllib.parse.urlencode({
        'action': 'load_more_children_fullscreen',
        'page': page
    }).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
            raw = resp.read().decode('utf-8', errors='ignore')
            res_json = json.loads(raw)
            content = res_json.get('content', '')
            if not content or '<div class="col-12' not in content:
                print(f"No more content on page {page}")
                break
                
            # Parse each card:
            # Cards are inside: <div class="col-12 col-lg-6 ...> ... </div>
            cards = re.findall(r'<div class=\"item-list-list_card\">(.*?)<\/div>\s*<\/div>\s*<\/div>', content, re.DOTALL)
            print(f"Page {page} found {len(cards)} cards")
            
            for c in cards:
                # Foto
                img_m = re.search(r'<img[^>]+src=[\"\']([^\"\']+)[\"\']', c)
                photo_url = img_m.group(1).replace(r'\/', '/') if img_m else ''
                
                # Nama (hapus polyglot tags [:en]...[:id]...[:])
                name_m = re.search(r'<h[23][^>]*>(.*?)<\/h[23]>', c)
                raw_name = name_m.group(1) if name_m else ''
                name = re.sub(r'\[:.*?\]', '', raw_name).strip()
                if not name and '[:id]' in raw_name:
                    name_id_m = re.search(r'\[:id\](.*?)\[:\]', raw_name)
                    if name_id_m: name = name_id_m.group(1).strip()
                if not name:
                    name_en_m = re.search(r'\[:en\](.*?)\[:id\]', raw_name)
                    if name_en_m: name = name_en_m.group(1).strip()
                    
                # Detail link or story
                link_m = re.search(r'href=[\"\']([^\"\']+)[\"\']', c)
                detail_url = link_m.group(1).replace(r'\/', '/') if link_m else ''
                
                # Price / target
                price_m = re.search(r'<div class=\"price-amount\">(.*?)<\/div>', c)
                price = re.sub(r'<[^>]+>', '', price_m.group(1)).strip() if price_m else ''
                price = re.sub(r'\[:.*?\]', '', price).strip()
                
                # Story / Deskripsi singkat
                desc_m = re.search(r'<p[^>]*>(.*?)<\/p>', c)
                desc = re.sub(r'<[^>]+>', '', desc_m.group(1)).strip() if desc_m else ''
                desc = re.sub(r'\[:.*?\]', '', desc).strip()
                
                if name and photo_url:
                    all_children.append({
                        'name': name,
                        'photo_url': photo_url,
                        'detail_url': detail_url,
                        'price': price,
                        'desc': desc
                    })
    except Exception as e:
        print(f"Error page {page}:", e)

print(f"\n=== TOTAL ANAK TER-SCRAPE: {len(all_children)} ===")
for i, ch in enumerate(all_children):
    print(f"{i+1}. {ch['name']} | Foto: {ch['photo_url']}")
    if ch['desc']:
        print(f"   Desc: {ch['desc'][:80]}...")

with open('d:/LENOVO/Downloads/AsuhKita Mobile/AsuhKita/scraped_children.json', 'w', encoding='utf-8') as f:
    json.dump(all_children, f, indent=2, ensure_ascii=False)
print("Data tersimpan di scraped_children.json")
