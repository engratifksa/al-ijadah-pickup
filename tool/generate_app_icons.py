import os
from PIL import Image, ImageDraw

src_img_path = r'C:\Users\Atif\.gemini\antigravity-ide\brain\dd46f7d2-98be-448d-ae42-37578321b84a\al_ijadah_logo_clean_1788172285305.jpg'
base_dir = r'd:\AntigravityProjects\MyDoc'
assets_dir = os.path.join(base_dir, 'assets', 'images')
os.makedirs(assets_dir, exist_ok=True)

im = Image.open(src_img_path).convert('RGBA')
w, h = im.size

# 1. Generate transparent full logo: assets/images/al_ijadah_logo.png
# Make white pixels transparent
logo_crop = im.crop((140, 110, 884, 940))
datas = logo_crop.getdata()
new_data = []
for item in datas:
    # If pixel is near white, make transparent
    if item[0] > 240 and item[1] > 240 and item[2] > 240:
        new_data.append((255, 255, 255, 0))
    else:
        new_data.append(item)
logo_crop.putdata(new_data)
logo_path = os.path.join(assets_dir, 'al_ijadah_logo.png')
logo_crop.save(logo_path, 'PNG')
print(f'Saved {logo_path} ({logo_crop.size})')

# 2. Generate crest only: assets/images/al_ijadah_crest.png
# Crest is around (360, 120, 664, 545)
crest_crop = im.crop((360, 120, 664, 545))
crest_datas = crest_crop.getdata()
new_crest_data = []
for item in crest_datas:
    if item[0] > 240 and item[1] > 240 and item[2] > 240:
        new_crest_data.append((255, 255, 255, 0))
    else:
        new_crest_data.append(item)
crest_crop.putdata(new_crest_data)

# Create 512x512 transparent canvas and center the crest
crest_canvas = Image.new('RGBA', (512, 512), (255, 255, 255, 0))
cw, ch = crest_crop.size
crest_canvas.paste(crest_crop, ((512 - cw) // 2, (512 - ch) // 2), crest_crop)
crest_path = os.path.join(assets_dir, 'al_ijadah_crest.png')
crest_canvas.save(crest_path, 'PNG')
print(f'Saved {crest_path}')

# 3. Create high-resolution Master App Icon (1024x1024)
# Clean white background with smooth rounded card and royal blue border, crest centered
icon_1024 = Image.new('RGBA', (1024, 1024), (255, 255, 255, 255))
draw = ImageDraw.Draw(icon_1024)

# Draw subtle outer background accent
draw.rectangle([0, 0, 1024, 1024], fill=(255, 255, 255, 255))

# Scale crest to fit comfortably inside adaptive icon safe area (65% of size = ~665px)
target_h = 660
ratio = target_h / ch
target_w = int(cw * ratio)
scaled_crest = crest_crop.resize((target_w, target_h), Image.Resampling.LANCZOS)
paste_x = (1024 - target_w) // 2
paste_y = (1024 - target_h) // 2
icon_1024.paste(scaled_crest, (paste_x, paste_y), scaled_crest)

master_icon_path = os.path.join(assets_dir, 'app_icon_1024.png')
icon_1024.save(master_icon_path, 'PNG')
print(f'Saved master icon {master_icon_path}')

# 4. Generate Android mipmap icons
android_res = os.path.join(base_dir, 'android', 'app', 'src', 'main', 'res')
mipmap_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

for folder, size in mipmap_sizes.items():
    dest_dir = os.path.join(android_res, folder)
    os.makedirs(dest_dir, exist_ok=True)
    resized = icon_1024.resize((size, size), Image.Resampling.LANCZOS)
    target_path = os.path.join(dest_dir, 'ic_launcher.png')
    resized.save(target_path, 'PNG')
    print(f'Saved Android icon: {target_path} ({size}x{size})')

# 5. Generate Web icons
web_icons_dir = os.path.join(base_dir, 'web', 'icons')
os.makedirs(web_icons_dir, exist_ok=True)
for w_size in [192, 512]:
    resized = icon_1024.resize((w_size, w_size), Image.Resampling.LANCZOS)
    resized.save(os.path.join(web_icons_dir, f'Icon-{w_size}.png'), 'PNG')
    resized.save(os.path.join(web_icons_dir, f'Icon-maskable-{w_size}.png'), 'PNG')

favicon = icon_1024.resize((32, 32), Image.Resampling.LANCZOS)
favicon.save(os.path.join(base_dir, 'web', 'favicon.png'), 'PNG')
print('Web icons updated successfully!')
