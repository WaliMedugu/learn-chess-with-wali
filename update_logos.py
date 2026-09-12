import os
import shutil
import struct

def convert_png_to_ico(png_path, ico_path):
    print(f"Converting {png_path} to ICO at {ico_path}...")
    with open(png_path, 'rb') as f:
        png_data = f.read()

    png_size = len(png_data)
    
    # 6-byte ICO Header
    # Reserved (2 bytes: 0), Type (2 bytes: 1 for ico), Count (2 bytes: 1 image)
    header = struct.pack('<HHH', 0, 1, 1)
    
    # 16-byte Directory Entry
    # Width (1 byte: 0 for 256), Height (1 byte: 0 for 256), Color count (1 byte: 0), Reserved (1 byte: 0)
    # Planes (2 bytes: 1), BPP (2 bytes: 32), Bytes in image (4 bytes), Offset from start (4 bytes: 22)
    entry = struct.pack('<BBBBHHII', 0, 0, 0, 0, 1, 32, png_size, 22)
    
    os.makedirs(os.path.dirname(ico_path), exist_ok=True)
    with open(ico_path, 'wb') as f:
        f.write(header)
        f.write(entry)
        f.write(png_data)
    print("ICO conversion successful.")

def copy_web_logos(logo_path):
    web_icons = [
        'web/favicon.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-192.png',
        'web/icons/Icon-maskable-512.png'
    ]
    for target in web_icons:
        print(f"Copying logo to {target}...")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copy2(logo_path, target)
    print("All web icons updated successfully.")

if __name__ == '__main__':
    logo_png = 'assets/logo.png'
    windows_ico = 'windows/runner/resources/app_icon.ico'
    
    if os.path.exists(logo_png):
        convert_png_to_ico(logo_png, windows_ico)
        copy_web_logos(logo_png)
    else:
        print(f"Error: logo not found at {logo_png}")
