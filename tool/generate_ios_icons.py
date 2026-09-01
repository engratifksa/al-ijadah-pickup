import os
from PIL import Image

base_dir = r'd:\AntigravityProjects\MyDoc'
master_icon_path = os.path.join(base_dir, 'assets', 'images', 'app_icon_1024.png')
ios_appicon_dir = os.path.join(base_dir, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')

if not os.path.exists(master_icon_path):
    print(f"Error: {master_icon_path} does not exist")
    exit(1)

master_icon = Image.open(master_icon_path).convert('RGB')

# iOS sizes mapped from Contents.json
ios_icons = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

for filename, size in ios_icons.items():
    dest_path = os.path.join(ios_appicon_dir, filename)
    resized = master_icon.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(dest_path, 'PNG')
    print(f"Generated {filename} ({size}x{size})")

print("All iOS App Icons generated successfully!")
