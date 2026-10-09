#!/usr/bin/env python3
"""
Herramienta de generación y sincronización de íconos de HakkinLauncher
para todos los sistemas operativos soportados: macOS, Windows, Linux, Android e iOS.

Fuente de verdad: assets/hakkinlauncher.png
"""

import os
import struct
import subprocess
import tempfile
from pathlib import Path

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
SOURCE_ICON = WORKSPACE_ROOT / "assets" / "hakkinlauncher.png"

def run_cmd(cmd):
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"Error ejecutando {cmd}: {res.stderr}")
    return res.stdout

def resize_png(src_path: Path, dst_path: Path, width: int, height: int):
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["sips", "-z", str(height), str(width), str(src_path), "--out", str(dst_path)]
    run_cmd(cmd)

def build_ico(png_sizes_map: dict, output_ico_path: Path):
    """
    Construye un archivo .ico de Windows conteniendo múltiples resoluciones PNG.
    Formato estándar soportado en Windows.
    """
    count = len(png_sizes_map)
    header = struct.pack("<HHH", 0, 1, count)
    
    entries = []
    data_blobs = []
    
    current_offset = 6 + (16 * count)
    
    for size in sorted(png_sizes_map.keys(), reverse=True):
        png_bytes = png_sizes_map[size]
        w = 0 if size >= 256 else size
        h = 0 if size >= 256 else size
        entry = struct.pack(
            "<BBBBHHII",
            w,
            h,
            0,     # paleta de colores
            0,     # reservado
            1,     # planos de color
            32,    # bpp
            len(png_bytes),
            current_offset,
        )
        entries.append(entry)
        data_blobs.append(png_bytes)
        current_offset += len(png_bytes)
        
    output_ico_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_ico_path, "wb") as f:
        f.write(header)
        for e in entries:
            f.write(e)
        for b in data_blobs:
            f.write(b)

def main():
    if not SOURCE_ICON.exists():
        raise FileNotFoundError(f"No se encontró el ícono fuente en {SOURCE_ICON}")

    print(f"Generando íconos para sistemas operativos a partir de: {SOURCE_ICON.relative_to(WORKSPACE_ROOT)}")

    # 1. macOS Icons
    macos_dir = WORKSPACE_ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for filename, sz in macos_sizes.items():
        dst = macos_dir / filename
        resize_png(SOURCE_ICON, dst, sz, sz)
        print(f"  [macOS] {filename} ({sz}x{sz})")

    # 2. iOS Icons
    ios_dir = WORKSPACE_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
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
    for filename, sz in ios_sizes.items():
        dst = ios_dir / filename
        resize_png(SOURCE_ICON, dst, sz, sz)
        print(f"  [iOS] {filename} ({sz}x{sz})")

    # 3. Android Mipmaps
    android_res = WORKSPACE_ROOT / "android" / "app" / "src" / "main" / "res"
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in android_sizes.items():
        dst = android_res / folder / "ic_launcher.png"
        resize_png(SOURCE_ICON, dst, sz, sz)
        print(f"  [Android] {folder}/ic_launcher.png ({sz}x{sz})")

    # 4. Windows .ico
    ico_sizes = [256, 128, 64, 48, 32, 16]
    ico_png_map = {}
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_path = Path(tmp_dir)
        for sz in ico_sizes:
            tmp_png = tmp_path / f"ico_{sz}.png"
            resize_png(SOURCE_ICON, tmp_png, sz, sz)
            ico_png_map[sz] = tmp_png.read_bytes()
            
        win_ico_dst = WORKSPACE_ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
        build_ico(ico_png_map, win_ico_dst)
        print(f"  [Windows] app_icon.ico ({', '.join(str(s) for s in ico_sizes)}) -> {win_ico_dst.relative_to(WORKSPACE_ROOT)}")

        assets_ico_dst = WORKSPACE_ROOT / "assets" / "hakkinlauncher.ico"
        build_ico(ico_png_map, assets_ico_dst)
        print(f"  [Assets] hakkinlauncher.ico -> {assets_ico_dst.relative_to(WORKSPACE_ROOT)}")

    print("Todos los íconos del sistema operativo fueron generados con éxito.")

if __name__ == "__main__":
    main()
