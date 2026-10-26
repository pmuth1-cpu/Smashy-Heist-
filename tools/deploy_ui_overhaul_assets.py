import os
import sys
from PIL import Image

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(WORKSPACE_DIR, "assets")
BRAIN_DIR = r"C:\Users\muthp\.gemini\antigravity\brain\2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e"

def ensure_dirs():
    for sub in ["ui", "hud", "modes", "splash", "kart", "items", "ribbons"]:
        os.makedirs(os.path.join(ASSETS_DIR, sub), exist_ok=True)

def strip_magenta_clean(img: Image.Image, tolerance=55, defringe=True) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    data = img.load()

    # Target magenta is ~ (250, 10, 245)
    for y in range(h):
        for x in range(w):
            r, g, b, a = data[x, y]
            # Magenta detection: high R, high B, low G
            dist = abs(r - 250) + abs(g - 15) + abs(b - 245)
            if dist < tolerance:
                data[x, y] = (0, 0, 0, 0)
            elif dist < tolerance * 1.55:
                # Soft feather
                fade = (dist - tolerance) / (tolerance * 0.55)
                alpha = int(max(0, min(255, fade * 255)))
                if defringe:
                    # Desaturate any remaining magenta tint
                    gray = int(r * 0.3 + g * 0.59 + b * 0.11)
                    data[x, y] = (gray, gray, gray, alpha)
                else:
                    data[x, y] = (r, g, b, alpha)

    bbox = img.getbbox()
    if bbox:
        pad = 8
        crop_box = (
            max(0, bbox[0] - pad),
            max(0, bbox[1] - pad),
            min(w, bbox[2] + pad),
            min(h, bbox[3] + pad)
        )
        img = img.crop(crop_box)
    return img

DEPLOY_LIST = [
    # Modern Cute 3D Candy Buttons
    {
        "pattern": "btn_candy_3d_green_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_candy_green.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_candy_3d_yellow_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_candy_yellow.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_candy_3d_red_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_candy_red.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_candy_3d_blue_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_candy_blue.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    # Circular 3D Bubble Buttons
    {
        "pattern": "btn_round_close_x_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_round_close_x.png"),
        "chroma": True,
        "resize": (128, 128)
    },
    {
        "pattern": "btn_round_pause_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_round_pause.png"),
        "chroma": True,
        "resize": (128, 128)
    },
    # Arched 3D Cartoon Ribbon Banners
    {
        "pattern": "ribbon_header_paused_",
        "dst": os.path.join(ASSETS_DIR, "ribbons", "ribbon_header_paused.png"),
        "chroma": True,
        "resize": (640, 180)
    },
    {
        "pattern": "ribbon_header_rewards_",
        "dst": os.path.join(ASSETS_DIR, "ribbons", "ribbon_header_rewards.png"),
        "chroma": True,
        "resize": (640, 180)
    },
    {
        "pattern": "ribbon_header_quests_",
        "dst": os.path.join(ASSETS_DIR, "ribbons", "ribbon_header_quests.png"),
        "chroma": True,
        "resize": (640, 180)
    },
    # Cute Cartoon Chests & Rewards
    {
        "pattern": "icon_cartoon_chest_day7_",
        "dst": os.path.join(ASSETS_DIR, "items", "icon_cartoon_chest_day7.png"),
        "chroma": True,
        "resize": (384, 384)
    },
    {
        "pattern": "icon_cartoon_heist_safe_",
        "dst": os.path.join(ASSETS_DIR, "items", "icon_cartoon_heist_safe.png"),
        "chroma": True,
        "resize": (256, 256)
    },
    # Cute Cartoon Star Badges
    {
        "pattern": "hud_cartoon_star_gold_",
        "dst": os.path.join(ASSETS_DIR, "hud", "hud_cartoon_star_gold.png"),
        "chroma": True,
        "resize": (256, 256)
    },
    # Legacy fallback mappings
    {
        "pattern": "btn_primary_green_rect_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_primary_green.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_danger_red_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_danger_red.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_action_blue_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_action_blue.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "btn_gold_cta_",
        "dst": os.path.join(ASSETS_DIR, "ui", "btn_gold_cta.png"),
        "chroma": True,
        "resize": (512, 180)
    },
    {
        "pattern": "banner_pause_header_",
        "dst": os.path.join(ASSETS_DIR, "ui", "banner_paused_header.png"),
        "chroma": True,
        "resize": (640, 180)
    },
    {
        "pattern": "stamp_busted_comic_",
        "dst": os.path.join(ASSETS_DIR, "hud", "stamp_busted.png"),
        "chroma": True,
        "resize": (512, 256)
    },
    {
        "pattern": "hud_wanted_star_gold_",
        "dst": os.path.join(ASSETS_DIR, "hud", "hud_wanted_star_gold.png"),
        "chroma": True,
        "resize": (256, 256)
    },
    {
        "pattern": "hud_wanted_star_empty_",
        "dst": os.path.join(ASSETS_DIR, "hud", "hud_wanted_star_empty.png"),
        "chroma": True,
        "resize": (256, 256)
    },
]

def find_file_by_pattern(pattern):
    if not os.path.exists(BRAIN_DIR):
        return None
    for f in os.listdir(BRAIN_DIR):
        if pattern in f and (f.endswith(".jpg") or f.endswith(".png")):
            return os.path.join(BRAIN_DIR, f)
    return None

def run_deployment():
    ensure_dirs()
    print("=== DEPLOYING NANOBANANA CARTOON 3D ASSETS ===")
    for item in DEPLOY_LIST:
        src = find_file_by_pattern(item["pattern"])
        if not src:
            continue
        
        dst = item["dst"]
        img = Image.open(src)
        if item.get("chroma"):
            img = strip_magenta_clean(img)
        if item.get("resize"):
            img = img.resize(item["resize"], Image.Resampling.LANCZOS)
        
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        img.save(dst, "PNG")
        print(f"[DEPLOYED] {os.path.basename(src)} -> {dst} ({img.size[0]}x{img.size[1]})")

if __name__ == "__main__":
    run_deployment()
