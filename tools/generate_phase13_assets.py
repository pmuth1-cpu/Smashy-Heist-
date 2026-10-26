import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(BASE_DIR, "assets")

def ensure_dirs():
    for sub in ["ui", "hud", "items", "powerups", "splash", "textures"]:
        os.makedirs(os.path.join(ASSETS_DIR, sub), exist_ok=True)

def get_font(size):
    try:
        # Standard Windows fonts
        for font_name in ["impact.ttf", "arialbd.ttf", "seguiemj.ttf", "segoeprb.ttf"]:
            font_path = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", font_name)
            if os.path.exists(font_path):
                return ImageFont.truetype(font_path, size)
    except Exception:
        pass
    return ImageFont.load_default()

def draw_thick_text(draw, pos, text, font, fill_color, outline_color=(10, 10, 14), outline_width=4):
    x, y = pos
    for dx in range(-outline_width, outline_width + 1):
        for dy in range(-outline_width, outline_width + 1):
            if dx * dx + dy * dy <= outline_width * outline_width:
                draw.text((x + dx, y + dy), text, font=font, fill=outline_color)
    draw.text((x, y), text, font=font, fill=fill_color)

def generate_ui_buttons():
    # 1. btn_smash_play.png (512x288, 16:9)
    img = Image.new("RGBA", (512, 288), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Slanted button shape
    poly = [(45, 40), (475, 40), (450, 240), (20, 240)]
    # 3D bottom shadow
    shadow_poly = [(45, 60), (475, 60), (450, 255), (20, 255)]
    draw.polygon(shadow_poly, fill=(211, 84, 0)) # Deep orange shadow
    draw.polygon(poly, fill=(241, 196, 15)) # Golden yellow
    # Top gloss
    gloss_poly = [(45, 40), (475, 40), (465, 110), (35, 110)]
    draw.polygon(gloss_poly, fill=(249, 231, 159))
    # Outline
    draw.line(poly + [poly[0]], fill=(20, 20, 25), width=8)
    font = get_font(72)
    draw_thick_text(draw, (140, 95), "SMASH!", font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=6)
    img.save(os.path.join(ASSETS_DIR, "ui", "btn_smash_play.png"))

    # 2. btn_pause_top.png (256x256, 1:1)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Rounded rectangle button
    draw.rounded_rectangle([(24, 24), (232, 232)], radius=32, fill=(41, 128, 185), outline=(15, 20, 30), width=8)
    draw.rounded_rectangle([(32, 32), (224, 110)], radius=20, fill=(90, 165, 215)) # Top gloss
    # White double vertical pause bars
    draw.rounded_rectangle([(80, 70), (108, 186)], radius=8, fill=(255, 255, 255), outline=(15, 20, 30), width=4)
    draw.rounded_rectangle([(148, 70), (176, 186)], radius=8, fill=(255, 255, 255), outline=(15, 20, 30), width=4)
    img.save(os.path.join(ASSETS_DIR, "ui", "btn_pause_top.png"))

    # 3. banner_paused_header.png (512x288, 16:9)
    img = Image.new("RGBA", (512, 288), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Slanted banner
    poly = [(30, 70), (482, 70), (460, 210), (10, 210)]
    draw.polygon(poly, fill=(24, 44, 97))
    # Red/Blue split bar
    draw.polygon([(30, 70), (256, 70), (245, 210), (10, 210)], fill=(192, 57, 43))
    draw.polygon([(256, 70), (482, 70), (460, 210), (245, 210)], fill=(41, 128, 185))
    draw.line(poly + [poly[0]], fill=(15, 20, 30), width=7)
    font = get_font(46)
    draw_thick_text(draw, (75, 115), "GAME PAUSED", font, (255, 255, 255), outline_color=(15, 20, 30), outline_width=6)
    # Siren bulbs
    draw.ellipse([(20, 115), (55, 150)], fill=(231, 76, 60), outline=(15, 20, 30), width=3)
    draw.ellipse([(455, 115), (490, 150)], fill=(52, 152, 219), outline=(15, 20, 30), width=3)
    img.save(os.path.join(ASSETS_DIR, "ui", "banner_paused_header.png"))

def generate_currency_and_tab_icons():
    # 4. icon_cash_stack.png (256x256)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Isometric cash bundle
    for i in range(3):
        y_off = 160 - i * 28
        poly = [(60, y_off), (128, y_off - 40), (196, y_off), (128, y_off + 40)]
        draw.polygon(poly, fill=(46, 204, 113), outline=(15, 25, 20), width=5)
        # Gold band
        draw.line([(110, y_off - 10), (146, y_off + 10)], fill=(241, 196, 15), width=12)
    font = get_font(52)
    draw_thick_text(draw, (115, 105), "$", font, (255, 255, 255), outline_color=(20, 40, 25), outline_width=4)
    img.save(os.path.join(ASSETS_DIR, "ui", "icon_cash_stack.png"))

    # 5. icon_trophy_cup.png (256x256)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Cup body
    draw.polygon([(65, 45), (191, 45), (160, 140), (96, 140)], fill=(241, 196, 15), outline=(20, 20, 25), width=6)
    # Handles
    draw.arc([(30, 50), (90, 120)], start=90, end=270, fill=(241, 196, 15), width=10)
    draw.arc([(166, 50), (226, 120)], start=270, end=90, fill=(241, 196, 15), width=10)
    # Stem & base
    draw.rectangle([(116, 140), (140, 185)], fill=(212, 172, 13), outline=(20, 20, 25), width=5)
    draw.polygon([(75, 185), (181, 185), (195, 220), (61, 220)], fill=(120, 66, 18), outline=(20, 20, 25), width=6)
    # Star on cup
    font = get_font(40)
    draw_thick_text(draw, (114, 65), "★", font, (255, 255, 255), outline_color=(15, 20, 25), outline_width=3)
    img.save(os.path.join(ASSETS_DIR, "ui", "icon_trophy_cup.png"))

    # 6. icon_streak_flame.png (256x256)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Outer flame
    flame_outer = [(128, 25), (185, 95), (205, 165), (165, 230), (90, 230), (50, 165), (70, 95)]
    draw.polygon(flame_outer, fill=(230, 126, 34), outline=(20, 20, 25), width=6)
    # Inner yellow flame
    flame_inner = [(128, 75), (165, 125), (175, 175), (150, 215), (105, 215), (80, 175), (92, 125)]
    draw.polygon(flame_inner, fill=(241, 196, 15), outline=(20, 20, 25), width=4)
    # Core highlight
    draw.ellipse([(112, 160), (144, 205)], fill=(255, 255, 255))
    img.save(os.path.join(ASSETS_DIR, "ui", "icon_streak_flame.png"))

    # 7. icon_wanted_star.png (256x256)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # 5-pointed star points
    cx, cy, r_out, r_in = 128, 128, 105, 45
    pts = []
    for i in range(10):
        angle = i * (math.pi / 5) - math.pi / 2
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=(241, 196, 15), outline=(20, 20, 25), width=7)
    # Bevel highlight
    pts_inner = []
    for i in range(10):
        angle = i * (math.pi / 5) - math.pi / 2
        r = (r_out if i % 2 == 0 else r_in) * 0.75
        pts_inner.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts_inner, fill=(254, 249, 231))
    img.save(os.path.join(ASSETS_DIR, "ui", "icon_wanted_star.png"))

    # Tab Icons (icon_tab_home, cars, gear, gacha, friends)
    tab_configs = [
        ("icon_tab_home.png", (46, 204, 113), "🏠"),
        ("icon_tab_cars.png", (231, 76, 60), "🏎️"),
        ("icon_tab_gear.png", (241, 196, 15), "🔧"),
        ("icon_tab_gacha.png", (155, 89, 182), "🎁"),
        ("icon_tab_friends.png", (52, 152, 219), "👥"),
    ]
    for filename, col, emoji in tab_configs:
        img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle([(25, 25), (231, 231)], radius=36, fill=col, outline=(20, 20, 25), width=7)
        draw.rounded_rectangle([(35, 35), (221, 115)], radius=24, fill=(255, 255, 255, 75))
        font = get_font(90)
        draw_thick_text(draw, (80, 75), emoji, font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=5)
        img.save(os.path.join(ASSETS_DIR, "ui", filename))

def generate_hud_stamps_and_gadget():
    # 1. stamp_busted.png (512x288, 16:9)
    img = Image.new("RGBA", (512, 288), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Slanted stamp box
    poly = [(35, 55), (480, 35), (460, 245), (15, 225)]
    draw.polygon(poly, fill=(24, 44, 97), outline=(15, 20, 30), width=8)
    draw.line([(45, 65), (470, 45), (452, 235), (27, 215), (45, 65)], fill=(231, 76, 60), width=4)
    font = get_font(76)
    draw_thick_text(draw, (85, 95), "BUSTED", font, (255, 255, 255), outline_color=(15, 20, 30), outline_width=7)
    # Handcuff motif
    draw.ellipse([(380, 160), (425, 205)], outline=(200, 200, 220), width=6)
    draw.ellipse([(415, 175), (460, 220)], outline=(200, 200, 220), width=6)
    img.save(os.path.join(ASSETS_DIR, "hud", "stamp_busted.png"))

    # 2. stamp_wasted.png (512x288, 16:9)
    img = Image.new("RGBA", (512, 288), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    poly = [(25, 35), (475, 55), (490, 245), (40, 225)]
    draw.polygon(poly, fill=(192, 57, 43), outline=(15, 20, 30), width=8)
    draw.line([(35, 45), (465, 65), (478, 235), (50, 215), (35, 45)], fill=(241, 196, 15), width=4)
    font = get_font(76)
    draw_thick_text(draw, (95, 95), "WASTED", font, (255, 255, 255), outline_color=(15, 20, 30), outline_width=7)
    img.save(os.path.join(ASSETS_DIR, "hud", "stamp_wasted.png"))

    # 3. btn_gadget_trigger.png (256x256, 1:1)
    img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)
    # Circular arcade button
    draw.ellipse([(20, 20), (236, 236)], fill=(142, 68, 173), outline=(20, 20, 25), width=9)
    draw.ellipse([(38, 38), (218, 218)], fill=(155, 89, 182), outline=(241, 196, 15), width=6)
    # Lightning bolt in center
    bolt = [(135, 50), (95, 125), (135, 125), (115, 205), (170, 115), (130, 115)]
    draw.polygon(bolt, fill=(241, 196, 15), outline=(20, 20, 25), width=5)
    img.save(os.path.join(ASSETS_DIR, "hud", "btn_gadget_trigger.png"))

def generate_items_and_powerups():
    items = [
        ("item_rockets_twin.png", (231, 76, 60), "🚀"),
        ("item_emp_dome.png", (0, 210, 211), "⚡"),
        ("item_magnet_dish.png", (241, 196, 15), "🧲"),
        ("item_underglow_cyan.png", (84, 160, 255), "💡"),
        ("item_trail_gold_flame.png", (230, 126, 34), "🔥"),
        ("item_trail_cyber_purple.png", (155, 89, 182), "🟣"),
        ("item_bumper_chrome.png", (189, 195, 199), "🛡️"),
        ("item_bumper_spiked.png", (127, 140, 141), "⚔️"),
        ("item_armor_titanium.png", (44, 62, 80), "🔰"),
    ]
    for filename, col, emoji in items:
        img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle([(24, 24), (232, 232)], radius=32, fill=col, outline=(20, 20, 25), width=7)
        draw.rounded_rectangle([(34, 34), (222, 110)], radius=20, fill=(255, 255, 255, 65))
        font = get_font(95)
        draw_thick_text(draw, (75, 75), emoji, font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=5)
        img.save(os.path.join(ASSETS_DIR, "items", filename))

    powerups = [
        ("powerup_nitro.png", (52, 152, 219), "NOS"),
        ("powerup_emp.png", (0, 210, 211), "EMP"),
        ("powerup_oil.png", (241, 196, 15), "OIL"),
        ("powerup_shield.png", (46, 204, 113), "SHIELD"),
    ]
    for filename, col, text in powerups:
        img = Image.new("RGBA", (256, 256), (255, 255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.ellipse([(20, 20), (236, 236)], fill=col, outline=(20, 20, 25), width=8)
        draw.ellipse([(35, 35), (221, 110)], fill=(255, 255, 255, 75))
        font = get_font(44)
        x_pos = 78 if len(text) == 3 else 55
        draw_thick_text(draw, (x_pos, 105), text, font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=5)
        img.save(os.path.join(ASSETS_DIR, "powerups", filename))

def generate_splash_and_textures():
    # 1. loading_bg_landscape.png (1280x720, 16:9)
    img = Image.new("RGB", (1280, 720), (230, 126, 34))
    draw = ImageDraw.Draw(img)
    # Sky & Sunset gradient
    for y in range(400):
        factor = y / 400.0
        r = int(142 * (1 - factor) + 243 * factor)
        g = int(68 * (1 - factor) + 156 * factor)
        b = int(173 * (1 - factor) + 18 * factor)
        draw.line([(0, y), (1280, y)], fill=(r, g, b))
    # Desert canyon mesa blocks
    draw.polygon([(0, 320), (340, 320), (390, 480), (0, 480)], fill=(186, 74, 0))
    draw.polygon([(920, 280), (1280, 280), (1280, 500), (860, 500)], fill=(186, 74, 0))
    # Bridge across canyon
    draw.rectangle([(250, 440), (1050, 475)], fill=(52, 73, 94))
    # Road surface
    draw.rectangle([(0, 475), (1280, 720)], fill=(33, 47, 61))
    # Yellow and white dashed road lane lines
    for x in range(50, 1280, 140):
        draw.line([(x, 590), (x + 80, 590)], fill=(241, 196, 15), width=8)
    # Muscle Car silhouette on bridge
    draw.rectangle([(560, 400), (740, 455)], fill=(231, 76, 60))
    draw.rectangle([(600, 370), (700, 400)], fill=(255, 255, 255))
    font = get_font(52)
    draw_thick_text(draw, (380, 630), "SMASHY HEIST: GETAWAY", font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=6)
    img.save(os.path.join(ASSETS_DIR, "splash", "loading_bg_landscape.png"))

    # 2. 8 Car Brawler Splash Cards (512x512)
    cars = [
        ("splash_default_coupe.png", (46, 204, 113), "COUPE"),
        ("splash_tuk_tuk_jet.png", (52, 152, 219), "TUK TUK"),
        ("splash_armored_bulldozer.png", (155, 89, 182), "DOZER"),
        ("splash_ice_cream_drifter.png", (255, 118, 117), "FROSTY"),
        ("splash_cyber_interceptor.png", (0, 210, 211), "CYBER"),
        ("splash_monster_pickup.png", (230, 126, 34), "MONSTER"),
        ("splash_gold_limo.png", (241, 196, 15), "LIMO"),
        ("splash_f1_street_kart.png", (243, 156, 18), "APEX F1"),
    ]
    for filename, col, title in cars:
        img = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
        draw = ImageDraw.Draw(img)
        # Comic speed rays background
        cx, cy = 256, 256
        for deg in range(0, 360, 30):
            rad1 = math.radians(deg)
            rad2 = math.radians(deg + 15)
            p1 = (cx + 360 * math.cos(rad1), cy + 360 * math.sin(rad1))
            p2 = (cx + 360 * math.cos(rad2), cy + 360 * math.sin(rad2))
            draw.polygon([(cx, cy), p1, p2], fill=col)
        # Inner shield
        draw.rounded_rectangle([(40, 40), (472, 472)], radius=45, outline=(20, 20, 25), width=10)
        # Car body block
        draw.polygon([(110, 310), (402, 310), (370, 230), (142, 230)], fill=col, outline=(20, 20, 25), width=7)
        draw.polygon([(160, 230), (352, 230), (320, 175), (192, 175)], fill=(255, 255, 255), outline=(20, 20, 25), width=6)
        # Wheels
        draw.ellipse([(120, 290), (180, 350)], fill=(30, 30, 35), outline=(241, 196, 15), width=5)
        draw.ellipse([(332, 290), (392, 350)], fill=(30, 30, 35), outline=(241, 196, 15), width=5)
        # Text label
        font = get_font(48)
        w = len(title) * 26
        draw_thick_text(draw, (256 - w // 2, 380), title, font, (255, 255, 255), outline_color=(20, 20, 25), outline_width=6)
        img.save(os.path.join(ASSETS_DIR, "splash", filename))

    # 3. Textures (512x512 tileable)
    # tex_building_facade.png
    img = Image.new("RGB", (512, 512), (30, 39, 46))
    draw = ImageDraw.Draw(img)
    for y in range(20, 500, 60):
        for x in range(20, 500, 50):
            is_lit = (x + y) % 3 == 0
            win_col = (241, 196, 15) if is_lit else (0, 168, 255)
            draw.rectangle([(x, y), (x + 35, y + 42)], fill=win_col, outline=(15, 20, 25), width=3)
    img.save(os.path.join(ASSETS_DIR, "textures", "tex_building_facade.png"))

    # tex_road_asphalt.png
    img = Image.new("RGB", (512, 512), (47, 53, 66))
    draw = ImageDraw.Draw(img)
    # Curb edges
    draw.rectangle([(0, 0), (35, 512)], fill=(164, 176, 190))
    draw.rectangle([(477, 0), (512, 512)], fill=(164, 176, 190))
    # Dashed lane markers
    for y in range(30, 512, 120):
        draw.rectangle([(246, y), (266, y + 70)], fill=(255, 255, 255))
    img.save(os.path.join(ASSETS_DIR, "textures", "tex_road_asphalt.png"))

if __name__ == "__main__":
    ensure_dirs()
    generate_ui_buttons()
    generate_currency_and_tab_icons()
    generate_hud_stamps_and_gadget()
    generate_items_and_powerups()
    generate_splash_and_textures()
    print("ALL PHASE 13 NANO BANANA ASSETS GENERATED CLEANLY!")
