import os
from PIL import Image, ImageFilter
import numpy as np
from collections import deque

WORKSPACE = "d:/My project/smashy heist"
BRAIN_DIR = "C:/Users/muthp/.gemini/antigravity/brain/2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e"

def ensure_dirs():
    for d in ["assets/ui", "assets/ribbons", "assets/items", "assets/hud"]:
        os.makedirs(os.path.join(WORKSPACE, d), exist_ok=True)

def remove_white_bg(img, thresh=242):
    # Converts white/near-white to transparent alpha with soft edge antialiasing
    im = img.convert("RGBA")
    w, h = im.size
    arr = np.array(im)
    
    # Is background if RGB are all high
    is_bg = (arr[:, :, 0] > thresh) & (arr[:, :, 1] > thresh) & (arr[:, :, 2] > thresh)
    
    # Floodfill from boundaries
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
                    
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, mode="L").filter(ImageFilter.GaussianBlur(radius=0.6))
    im.putalpha(alpha_img)
    
    # Auto-crop transparent borders
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    return im

def deploy_candy_buttons():
    print("--- 1. Extracting Blank 3D Candy Buttons ---")
    btn_sheet_path = os.path.join(BRAIN_DIR, "btn_blank_candy_buttons_1792601739828.jpg")
    sheet = Image.open(btn_sheet_path)
    
    # Coordinates from our NumPy measurement:
    # x: 350 to 850
    # y ranges:
    # 1. Lime Green: [30, 190]
    # 2. Sunny Gold: [200, 360]
    # 3. Strawberry Red: [370, 530]
    # 4. Sky Blue: [538, 698]
    # 5. Grape Purple: [705, 865]
    
    button_defs = [
        ("btn_candy_green.png", (350, 30, 850, 190)),
        ("btn_candy_yellow.png", (350, 200, 850, 360)),
        ("btn_candy_red.png", (350, 370, 850, 530)),
        ("btn_candy_blue.png", (350, 538, 850, 698)),
        ("btn_candy_purple.png", (350, 705, 850, 865)),
    ]
    
    for fname, crop_box in button_defs:
        btn_crop = sheet.crop(crop_box)
        btn_alpha = remove_white_bg(btn_crop, thresh=244)
        
        # Resize to standard high-res button (e.g. 384x120) for optimal 9-slice
        final_btn = btn_alpha.resize((384, 120), Image.Resampling.LANCZOS)
        out_p = os.path.join(WORKSPACE, "assets/ui", fname)
        final_btn.save(out_p, "PNG")
        print(f"  [SAVED] {out_p} ({final_btn.size})")

def deploy_bubble_buttons_and_ribbons():
    print("--- 2. Extracting Bubble Buttons & Ribbons ---")
    kit_path = os.path.join(BRAIN_DIR, "ui_kit_3d_candy_buttons_1792601007314.jpg")
    kit = Image.open(kit_path)
    
    # 1. Bubble Close X: x 500..680, y 530..730
    x_crop = kit.crop((500, 530, 680, 730))
    x_alpha = remove_white_bg(x_crop, thresh=230)
    x_final = x_alpha.resize((128, 128), Image.Resampling.LANCZOS)
    x_out = os.path.join(WORKSPACE, "assets/ui/btn_round_close_x.png")
    x_final.save(x_out, "PNG")
    print(f"  [SAVED] {x_out} ({x_final.size})")
    
    # 2. Bubble Pause: x 700..880, y 530..730
    p_crop = kit.crop((700, 530, 880, 730))
    p_alpha = remove_white_bg(p_crop, thresh=230)
    p_final = p_alpha.resize((128, 128), Image.Resampling.LANCZOS)
    p_out = os.path.join(WORKSPACE, "assets/ui/btn_round_pause.png")
    p_final.save(p_out, "PNG")
    print(f"  [SAVED] {p_out} ({p_final.size})")
    
    # 3. Ribbon Paused: x 60..560, y 60..310
    rib_p_crop = kit.crop((60, 60, 560, 310))
    rib_p_alpha = remove_white_bg(rib_p_crop, thresh=230)
    rib_p_final = rib_p_alpha.resize((560, 180), Image.Resampling.LANCZOS)
    rib_p_out = os.path.join(WORKSPACE, "assets/ribbons/ribbon_header_paused.png")
    rib_p_final.save(rib_p_out, "PNG")
    print(f"  [SAVED] {rib_p_out} ({rib_p_final.size})")
    
    # 4. Ribbon Victory: x 550..1020, y 60..310
    rib_v_crop = kit.crop((550, 60, 1020, 310))
    rib_v_alpha = remove_white_bg(rib_v_crop, thresh=230)
    rib_v_final = rib_v_alpha.resize((560, 180), Image.Resampling.LANCZOS)
    rib_v_out = os.path.join(WORKSPACE, "assets/ribbons/ribbon_header_victory.png")
    rib_v_final.save(rib_v_out, "PNG")
    print(f"  [SAVED] {rib_v_out} ({rib_v_final.size})")
    
    # 5. Safe Smiling: x 1030..1330, y 70..340
    safe_crop = kit.crop((1030, 70, 1330, 340))
    safe_alpha = remove_white_bg(safe_crop, thresh=230)
    safe_final = safe_alpha.resize((256, 256), Image.Resampling.LANCZOS)
    safe_out = os.path.join(WORKSPACE, "assets/items/icon_cartoon_heist_safe.png")
    safe_final.save(safe_out, "PNG")
    print(f"  [SAVED] {safe_out} ({safe_final.size})")

def deploy_rewards_vault_and_hud_assets():
    print("--- 3. Extracting Rewards Vault & HUD Assets ---")
    # Rewards Ribbon from mockup
    rew_mockup_path = os.path.join(BRAIN_DIR, "mockup_rewards_vault_1792600947099.jpg")
    rew_im = Image.open(rew_mockup_path)
    
    # Crop Day 7 safe and treasure chest: x 980..1260, y 360..580
    d7_crop = rew_im.crop((980, 350, 1260, 580))
    # Remove dark background
    d7_arr = np.array(d7_crop.convert("RGBA"))
    # Dark purple background in card has low green and red
    is_d7_bg = (d7_arr[:, :, 0] < 80) & (d7_arr[:, :, 1] < 50) & (d7_arr[:, :, 2] < 120)
    d7_alpha = np.where(is_d7_bg, 0, 255).astype(np.uint8)
    d7_alpha_im = Image.fromarray(d7_alpha, mode="L").filter(ImageFilter.GaussianBlur(radius=0.7))
    d7_crop.putalpha(d7_alpha_im)
    d7_bbox = d7_crop.getbbox()
    if d7_bbox: d7_crop = d7_crop.crop(d7_bbox)
    d7_final = d7_crop.resize((256, 220), Image.Resampling.LANCZOS)
    d7_out = os.path.join(WORKSPACE, "assets/items/icon_cartoon_chest_day7.png")
    d7_final.save(d7_out, "PNG")
    print(f"  [SAVED] {d7_out} ({d7_final.size})")
    
    # Extract Gold Star from HUD Mockup: C:/Users/muthp/.gemini/antigravity/brain/2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e/mockup_gameplay_hud_1792600974729.jpg
    hud_path = os.path.join(BRAIN_DIR, "mockup_gameplay_hud_1792600974729.jpg")
    hud_im = Image.open(hud_path)
    # Wanted Star is in top-left: x 100..260, y 100..200
    star_crop = hud_im.crop((150, 110, 210, 175))
    star_arr = np.array(star_crop.convert("RGBA"))
    is_blue_bg = (star_arr[:, :, 2] > 140) & (star_arr[:, :, 0] < 120)
    star_alpha = np.where(is_blue_bg, 0, 255).astype(np.uint8)
    star_alpha_im = Image.fromarray(star_alpha, mode="L").filter(ImageFilter.GaussianBlur(radius=0.7))
    star_crop.putalpha(star_alpha_im)
    s_bbox = star_crop.getbbox()
    if s_bbox: star_crop = star_crop.crop(s_bbox)
    star_final = star_crop.resize((128, 128), Image.Resampling.LANCZOS)
    star_out = os.path.join(WORKSPACE, "assets/hud/hud_cartoon_star_gold.png")
    star_final.save(star_out, "PNG")
    print(f"  [SAVED] {star_out} ({star_final.size})")

if __name__ == "__main__":
    ensure_dirs()
    deploy_candy_buttons()
    deploy_bubble_buttons_and_ribbons()
    deploy_rewards_vault_and_hud_assets()
    print("=== STUDIO-GRADE ASSETS DEPLOYED TO WORKSPACE! ===")
