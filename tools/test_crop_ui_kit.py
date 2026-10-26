import os
from PIL import Image, ImageChops, ImageFilter, ImageDraw
import numpy as np

KIT_PATH = "C:/Users/muthp/.gemini/antigravity/brain/2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e/ui_kit_3d_candy_buttons_1792601007314.jpg"
REWARDS_PATH = "C:/Users/muthp/.gemini/antigravity/brain/2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e/mockup_rewards_vault_1792600947099.jpg"
OUT_DIR = "d:/My project/smashy heist/tools/test_crops"
os.makedirs(OUT_DIR, exist_ok=True)

im = Image.open(KIT_PATH).convert("RGBA")
W, H = im.size

# Function to remove solid / near-white background around an isolated object
def extract_transparent_object(crop_box, bg_threshold=225):
    sub = im.crop(crop_box)
    w, h = sub.size
    
    # Create mask: floodfill from outer edges where color is near white/grey
    # Sample corner color
    arr = np.array(sub)
    # Check brightness or diff from corner
    corner_colors = [arr[0, 0, :3], arr[0, w-1, :3], arr[h-1, 0, :3], arr[h-1, w-1, :3]]
    avg_bg = np.mean(corner_colors, axis=0)
    
    # Distance from background color
    diff = np.sqrt(np.sum((arr[:, :, :3].astype(float) - avg_bg)**2, axis=2))
    
    # Alpha mask: 0 where diff < 28 and brightness > 190
    brightness = np.mean(arr[:, :, :3], axis=2)
    is_bg = (diff < 35) & (brightness > 185)
    
    # Use flood fill from (0,0) to only remove connected background
    from collections import deque
    mask = np.zeros((h, w), dtype=bool)
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    
    for x in range(w):
        if is_bg[0, x]: q.append((0, x)); visited[0, x] = True
        if is_bg[h-1, x]: q.append((h-1, x)); visited[h-1, x] = True
    for y in range(h):
        if is_bg[y, 0]: q.append((y, 0)); visited[y, 0] = True
        if is_bg[y, w-1]: q.append((y, w-1)); visited[y, w-1] = True
        
    while q:
        cy, cx = q.popleft()
        mask[cy, cx] = True
        for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w:
                if not visited[ny, nx] and is_bg[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
                    
    # Antialias alpha
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, mode="L")
    # Soften edges slightly
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=0.7))
    sub.putalpha(alpha_img)
    return sub

# Test slices
crops = {
    "ribbon_paused": (60, 60, 560, 310),
    "ribbon_victory": (550, 60, 1020, 310),
    "safe_smiling": (1030, 70, 1330, 340),
    "btn_green": (70, 360, 320, 520),
    "btn_yellow": (320, 360, 570, 520),
    "btn_red": (565, 360, 810, 520),
    "btn_blue": (810, 360, 1060, 520),
    "btn_purple": (1060, 360, 1315, 520),
    "bubble_close_x": (500, 530, 680, 740),
    "bubble_pause": (700, 530, 880, 740)
}

for name, box in crops.items():
    res = extract_transparent_object(box)
    p = os.path.join(OUT_DIR, f"{name}.png")
    res.save(p)
    print(f"Saved {name}: {res.size}")
