import os
import sys
from PIL import Image

BRAIN_DIR = r"C:\Users\muthp\.gemini\antigravity\brain\514cde7d-581a-4e9b-8bac-8cf37fcff2fc"
WORKSPACE = r"D:\My project\smashy heist"

ASSET_MAP = [
    {
        "src": "loading_bg_landscape_png_1792176160062.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "splash", "loading_bg_landscape.png"),
        "chroma": False,
        "resize": (1920, 1080)
    },
    {
        "src": "splash_cyber_interceptor_png_1792176281389.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "splash", "splash_cyber_interceptor.png"),
        "chroma": False,
        "resize": None
    },
    {
        "src": "btn_smash_play_png_1792176177197.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "ui", "btn_smash_play.png"),
        "chroma": True,
        "resize": None
    },
    {
        "src": "powerup_nitro_png_1792176198599.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "powerups", "powerup_nitro.png"),
        "chroma": True,
        "resize": (512, 512)
    },
    {
        "src": "powerup_emp_png_1792176218599.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "powerups", "powerup_emp.png"),
        "chroma": True,
        "resize": (512, 512)
    },
    {
        "src": "powerup_oil_png_1792176239383.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "powerups", "powerup_oil.png"),
        "chroma": True,
        "resize": (512, 512)
    },
    {
        "src": "powerup_shield_png_1792176262051.jpg",
        "dst": os.path.join(WORKSPACE, "assets", "powerups", "powerup_shield.png"),
        "chroma": True,
        "resize": (512, 512)
    }
]

def strip_chroma(img: Image.Image, tolerance: int = 55) -> Image.Image:
    img = img.convert("RGBA")
    data = img.load()
    w, h = img.size
    
    # Sample corner pixels to detect background color
    corners = [data[0, 0], data[w - 1, 0], data[0, h - 1], data[w - 1, h - 1]]
    bg_r = sum(c[0] for c in corners) // 4
    bg_g = sum(c[1] for c in corners) // 4
    bg_b = sum(c[2] for c in corners) // 4
    
    # Check if corner is magenta, white, or distinct solid
    for y in range(h):
        for x in range(w):
            r, g, b, a = data[x, y]
            dist = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
            if dist < tolerance:
                data[x, y] = (r, g, b, 0)
            elif dist < tolerance * 1.5:
                # Soft feathering
                fade = (dist - tolerance) / (tolerance * 0.5)
                alpha = int(clamp(fade * 255, 0, 255))
                data[x, y] = (r, g, b, alpha)
    return img

def clamp(val, min_v, max_v):
    return max(min_v, min(max_v, val))

def main():
    print("=== DEPLOYING NANO BANANA GENERATED ASSETS ===")
    for item in ASSET_MAP:
        src_path = os.path.join(BRAIN_DIR, item["src"])
        dst_path = item["dst"]
        
        if not os.path.exists(src_path):
            print(f"[MISSING] {src_path}")
            continue
        
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        img = Image.open(src_path)
        
        if item.get("resize"):
            img = img.resize(item["resize"], Image.Resampling.LANCZOS)
            
        if item["chroma"]:
            img = strip_chroma(img)
            img.save(dst_path, "PNG")
            print(f"[DEPLOYED & CHROMA-STRIPPED] -> {dst_path} ({img.size[0]}x{img.size[1]})")
        else:
            img.save(dst_path, "PNG")
            print(f"[DEPLOYED] -> {dst_path} ({img.size[0]}x{img.size[1]})")

    print("=== ALL ASSETS DEPLOYED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
