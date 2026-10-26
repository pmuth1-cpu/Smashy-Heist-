import os
from PIL import Image

BRAIN_DIR = r"C:\Users\muthp\.gemini\antigravity\brain\1465eb66-3f32-4383-a02e-1770100cbe56"
WORKSPACE = r"D:\My project\smashy heist"
KART_DIR = os.path.join(WORKSPACE, "assets", "kart")
os.makedirs(KART_DIR, exist_ok=True)

ITEMS = [
    ("kart_item_green_tire_1792482027603.jpg", "kart_item_green_tire.png"),
    ("kart_item_red_missile_1792482113812.jpg", "kart_item_red_missile.png"),
    ("kart_item_blue_drone_1792482136179.jpg", "kart_item_blue_drone.png"),
    ("kart_item_oil_slick_1792482158558.jpg", "kart_item_oil_slick.png"),
    ("kart_item_triple_nitro_1792482189837.jpg", "kart_item_triple_nitro.png"),
    ("kart_item_emp_lightning_1792482222808.jpg", "kart_item_emp_lightning.png"),
    ("kart_item_gold_star_1792482259197.jpg", "kart_item_gold_star.png"),
    ("kart_item_fake_box_v2_1792482356213.jpg", "kart_item_fake_box.png"),
    ("kart_hud_roulette_frame_v2_1792482425730.jpg", "kart_hud_roulette_frame.png"),
    ("kart_flag_checkered_1792482446547.jpg", "kart_flag_checkered.png")
]

for src_name, dst_name in ITEMS:
    src_path = os.path.join(BRAIN_DIR, src_name)
    dst_path = os.path.join(KART_DIR, dst_name)
    if os.path.exists(src_path):
        img = Image.open(src_path)
        img = img.resize((512, 512), Image.Resampling.LANCZOS)
        img.save(dst_path, "PNG")
        print(f"Deployed {src_name} -> {dst_path}")
    else:
        print(f"Not found: {src_path}")
