import os
import math
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KART_DIR = os.path.join(BASE_DIR, "assets", "kart")
os.makedirs(KART_DIR, exist_ok=True)

SIZE = 512
BG_COLOR = (255, 255, 255, 255)

def get_font(size):
    for font_name in ["impact.ttf", "arialbd.ttf", "segoeprb.ttf"]:
        font_path = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", font_name)
        if os.path.exists(font_path):
            try:
                return ImageFont.truetype(font_path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_thick_circle(draw, center, radius, fill, outline=(20, 20, 25), outline_width=10):
    x, y = center
    draw.ellipse([(x - radius - outline_width, y - radius - outline_width),
                  (x + radius + outline_width, y + radius + outline_width)], fill=outline)
    draw.ellipse([(x - radius, y - radius), (x + radius, y + radius)], fill=fill)

def draw_thick_polygon(draw, points, fill, outline=(20, 20, 25), outline_width=10):
    draw.polygon(points, fill=fill, outline=outline, width=outline_width)

def draw_thick_text(draw, pos, text, font, fill_color, outline_color=(20, 20, 25), outline_width=8):
    x, y = pos
    for dx in range(-outline_width, outline_width + 1):
        for dy in range(-outline_width, outline_width + 1):
            if dx * dx + dy * dy <= outline_width * outline_width:
                draw.text((x + dx, y + dy), text, font=font, fill=outline_color)
    draw.text((x, y), text, font=font, fill=fill_color)

# 1. kart_item_green_tire.png
def make_green_tire():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Kinetic green ricochet arrows around tire
    arrow_angles = [30, 150, 270]
    for ang in arrow_angles:
        rad = math.radians(ang)
        ax = cx + 180 * math.cos(rad)
        ay = cy + 180 * math.sin(rad)
        # Arrow triangle
        t_ang = rad + math.pi * 0.5
        p1 = (ax + 35 * math.cos(t_ang), ay + 35 * math.sin(t_ang))
        p2 = (ax - 20 * math.cos(t_ang) + 20 * math.cos(rad), ay - 20 * math.sin(t_ang) + 20 * math.sin(rad))
        p3 = (ax - 20 * math.cos(t_ang) - 20 * math.cos(rad), ay - 20 * math.sin(t_ang) - 20 * math.sin(rad))
        draw_thick_polygon(draw, [p1, p2, p3], fill=(46, 204, 113), outline=(15, 20, 25), outline_width=8)

    # Outer tire tread
    draw_thick_circle(draw, (cx, cy), 150, fill=(39, 174, 96), outline=(15, 20, 25), outline_width=14)
    # Tire treads blocks
    for i in range(12):
        t_ang = i * (math.pi * 2 / 12)
        tx = cx + 135 * math.cos(t_ang)
        ty = cy + 135 * math.sin(t_ang)
        draw.ellipse([(tx - 18, ty - 18), (tx + 18, ty + 18)], fill=(30, 130, 76), outline=(15, 20, 25), width=6)
    
    # Inner tire rim
    draw_thick_circle(draw, (cx, cy), 95, fill=(46, 204, 113), outline=(15, 20, 25), outline_width=10)
    # Metallic hub
    draw_thick_circle(draw, (cx, cy), 55, fill=(236, 240, 241), outline=(15, 20, 25), outline_width=8)
    draw_thick_circle(draw, (cx, cy), 22, fill=(189, 195, 199), outline=(15, 20, 25), outline_width=6)
    
    # Gloss highlight
    draw.arc([(cx - 130, cy - 130), (cx + 130, cy + 130)], start=190, end=290, fill=(168, 255, 180), width=18)
    img.save(os.path.join(KART_DIR, "kart_item_green_tire.png"))

# 2. kart_item_red_missile.png
def make_red_missile():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Homing Target Crosshair (Yellow/White)
    draw.ellipse([(cx - 200, cy - 200), (cx + 200, cy + 200)], outline=(241, 196, 15), width=8)
    draw.line([(cx - 220, cy), (cx - 150, cy)], fill=(241, 196, 15), width=8)
    draw.line([(cx + 150, cy), (cx + 220, cy)], fill=(241, 196, 15), width=8)
    draw.line([(cx, cy - 220), (cx, cy - 150)], fill=(241, 196, 15), width=8)
    draw.line([(cx, cy + 150), (cx, cy + 220)], fill=(241, 196, 15), width=8)
    
    # Rocket exhaust flames
    draw_thick_polygon(draw, [(210, 360), (256, 460), (302, 360)], fill=(243, 156, 18), outline=(15, 20, 25), outline_width=8)
    draw.polygon([(230, 360), (256, 430), (282, 360)], fill=(241, 196, 15))
    
    # Shark-fin stabilizers
    draw_thick_polygon(draw, [(180, 340), (130, 380), (180, 280)], fill=(150, 20, 30), outline=(15, 20, 25), outline_width=10)
    draw_thick_polygon(draw, [(332, 340), (382, 380), (332, 280)], fill=(150, 20, 30), outline=(15, 20, 25), outline_width=10)
    
    # Missile body
    body_pts = [(180, 360), (180, 220), (256, 100), (332, 220), (332, 360)]
    draw_thick_polygon(draw, body_pts, fill=(231, 76, 60), outline=(15, 20, 25), outline_width=12)
    
    # Police Siren nosecone
    draw_thick_polygon(draw, [(220, 155), (256, 95), (292, 155)], fill=(52, 152, 219), outline=(15, 20, 25), outline_width=8)
    # Siren light gloss
    draw.ellipse([(245, 110), (267, 132)], fill=(255, 255, 255))
    
    # Checker band across body
    draw.rectangle([(180, 250), (332, 280)], fill=(255, 255, 255), outline=(15, 20, 25), width=6)
    for bx in [180, 218, 256, 294]:
        draw.rectangle([(bx, 250), (bx + 19, 265)], fill=(15, 20, 25))
        draw.rectangle([(bx + 19, 265), (bx + 38, 280)], fill=(15, 20, 25))
        
    # Gloss arc
    draw.line([(200, 230), (240, 170)], fill=(255, 180, 180), width=12)
    img.save(os.path.join(KART_DIR, "kart_item_red_missile.png"))

# 3. kart_item_blue_drone.png
def make_blue_drone():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 240
    
    # Spiked rotors
    for dx, dy in [(-130, -70), (130, -70), (-130, 80), (130, 80)]:
        px, py = cx + dx, cy + dy
        # Rotor struts
        draw.line([(cx, cy), (px, py)], fill=(44, 62, 80), width=14)
        draw.line([(cx, cy), (px, py)], fill=(15, 20, 25), width=6)
        # Ring
        draw.ellipse([(px - 45, py - 45), (px + 45, py + 45)], outline=(0, 210, 211), width=10)
        # Blade
        draw.line([(px - 35, py), (px + 35, py)], fill=(236, 240, 241), width=8)
    
    # Central Assault Drone Body
    draw_thick_circle(draw, (cx, cy), 80, fill=(41, 128, 185), outline=(15, 20, 25), outline_width=12)
    draw_thick_circle(draw, (cx, cy), 50, fill=(52, 152, 219), outline=(15, 20, 25), outline_width=8)
    # Electric plasma eye
    draw.ellipse([(cx - 24, cy - 24), (cx + 24, cy + 24)], fill=(0, 255, 255))
    draw.ellipse([(cx - 10, cy - 10), (cx + 10, cy + 10)], fill=(255, 255, 255))
    
    # Golden #1 Crown Target Reticle Underneath
    crown_y = 390
    crown_pts = [(cx - 70, crown_y + 35), (cx - 70, crown_y), (cx - 35, crown_y + 15), 
                 (cx, crown_y - 20), (cx + 35, crown_y + 15), (cx + 70, crown_y), (cx + 70, crown_y + 35)]
    draw_thick_polygon(draw, crown_pts, fill=(241, 196, 15), outline=(15, 20, 25), outline_width=8)
    font = get_font(38)
    draw_thick_text(draw, (cx - 12, crown_y + 2), "#1", font, (255, 255, 255), outline_width=5)
    
    img.save(os.path.join(KART_DIR, "kart_item_blue_drone.png"))

# 4. kart_item_oil_slick.png
def make_oil_slick():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Glossy purple-black oil puddle
    puddle_pts = [
        (cx - 180, cy + 90), (cx - 140, cy + 160), (cx - 20, cy + 180),
        (cx + 110, cy + 170), (cx + 190, cy + 120), (cx + 170, cy + 50),
        (cx + 80, cy + 40), (cx - 60, cy + 50)
    ]
    draw_thick_polygon(draw, puddle_pts, fill=(34, 18, 54), outline=(15, 20, 25), outline_width=12)
    # Rainbow sheen on puddle
    draw.arc([(cx - 130, cy + 70), (cx + 130, cy + 150)], start=30, end=170, fill=(155, 89, 182), width=16)
    draw.arc([(cx - 110, cy + 85), (cx + 110, cy + 145)], start=40, end=160, fill=(0, 210, 211), width=8)
    
    # Tipping Yellow Banana Hazard Cone
    cone_pts = [(cx - 70, cy + 70), (cx - 10, cy - 140), (cx + 50, cy - 120), (cx + 60, cy + 80)]
    draw_thick_polygon(draw, cone_pts, fill=(241, 196, 15), outline=(15, 20, 25), outline_width=12)
    # Cone white reflective stripes
    draw.line([(cx - 40, cy + 10), (cx + 55, cy + 20)], fill=(255, 255, 255), width=20)
    draw.line([(cx - 25, cy - 50), (cx + 50, cy - 40)], fill=(255, 255, 255), width=18)
    # Banana peel curve on cone
    draw.arc([(cx - 80, cy - 80), (cx, cy)], start=180, end=340, fill=(243, 156, 18), width=14)
    # Slip action lines
    draw.line([(cx + 100, cy - 40), (cx + 170, cy - 70)], fill=(241, 196, 15), width=8)
    draw.line([(cx + 120, cy - 10), (cx + 190, cy - 30)], fill=(241, 196, 15), width=8)
    img.save(os.path.join(KART_DIR, "kart_item_oil_slick.png"))

# 5. kart_item_triple_nitro.png
def make_triple_nitro():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 260
    
    canister_positions = [
        (cx - 95, cy + 20, -15, (52, 152, 219)),
        (cx + 95, cy + 20, 15, (231, 76, 60)),
        (cx, cy - 40, 0, (41, 128, 185))
    ]
    
    for px, py, rot, col in canister_positions:
        # Exhaust turbo flames at nozzle
        draw_thick_polygon(draw, [(px - 22, py - 110), (px, py - 170), (px + 22, py - 110)], fill=(241, 196, 15), outline=(15, 20, 25), outline_width=6)
        draw.polygon([(px - 12, py - 110), (px, py - 150), (px + 12, py - 110)], fill=(230, 126, 34))
        # Valve nozzle
        draw.rectangle([(px - 16, py - 110), (px + 16, py - 85)], fill=(189, 195, 199), outline=(15, 20, 25), width=6)
        # Bottle
        draw.rounded_rectangle([(px - 38, py - 85), (px + 38, py + 95)], radius=18, fill=col, outline=(15, 20, 25), width=10)
        # NOS Label badge
        draw.rectangle([(px - 30, py - 30), (px + 30, py + 25)], fill=(236, 240, 241), outline=(15, 20, 25), width=4)
        font = get_font(26)
        draw_thick_text(draw, (px - 24, py - 15), "NOS", font, (15, 20, 25), outline_color=(255, 255, 255), outline_width=2)
        # Gloss streak
        draw.line([(px - 24, py - 70), (px - 24, py + 75)], fill=(255, 255, 255, 160), width=6)
        
    img.save(os.path.join(KART_DIR, "kart_item_triple_nitro.png"))

# 6. kart_item_emp_lightning.png
def make_emp_lightning():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Shrink-ray cyan energy rings
    draw.ellipse([(cx - 200, cy - 200), (cx + 200, cy + 200)], outline=(0, 210, 211), width=12)
    draw.ellipse([(cx - 150, cy - 150), (cx + 150, cy + 150)], outline=(129, 236, 236), width=8)
    draw.ellipse([(cx - 100, cy - 100), (cx + 100, cy + 100)], outline=(0, 210, 211), width=6)
    
    # Jagged lightning bolt
    bolt_pts = [
        (cx + 40, cy - 190),
        (cx - 70, cy - 10),
        (cx + 10, cy - 10),
        (cx - 50, cy + 190),
        (cx + 80, cy + 10),
        (cx, cy + 10)
    ]
    draw_thick_polygon(draw, bolt_pts, fill=(241, 196, 15), outline=(15, 20, 25), outline_width=14)
    # Inner bright lightning core
    inner_bolt = [
        (cx + 35, cy - 170),
        (cx - 50, cy - 5),
        (cx + 5, cy - 5),
        (cx - 35, cy + 170),
        (cx + 60, cy + 5),
        (cx - 5, cy + 5)
    ]
    draw.polygon(inner_bolt, fill=(255, 255, 255))
    
    # Spark crackles
    for ang in [45, 135, 225, 315]:
        rad = math.radians(ang)
        sx = cx + 160 * math.cos(rad)
        sy = cy + 160 * math.sin(rad)
        draw.line([(sx - 15, sy), (sx + 15, sy)], fill=(0, 255, 255), width=8)
        draw.line([(sx, sy - 15), (sx, sy + 15)], fill=(0, 255, 255), width=8)

    img.save(os.path.join(KART_DIR, "kart_item_emp_lightning.png"))

# 7. kart_item_gold_star.png
def make_gold_star():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Rainbow prism aura rings
    colors = [(231, 76, 60), (243, 156, 18), (241, 196, 15), (46, 204, 113), (52, 152, 219), (155, 89, 182)]
    for i, col in enumerate(colors):
        r = 215 - i * 6
        draw.arc([(cx - r, cy - r), (cx + r, cy + r)], start=0, end=360, fill=col, width=5)
    
    # 5-pointed Golden Star points
    outer_r = 175
    inner_r = 80
    star_pts = []
    for i in range(10):
        r = outer_r if i % 2 == 0 else inner_r
        ang = i * (math.pi / 5) - math.pi * 0.5
        star_pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    draw_thick_polygon(draw, star_pts, fill=(241, 196, 15), outline=(15, 20, 25), outline_width=14)
    
    # Inner star gradient / bevel
    inner_star = []
    for i in range(10):
        r = (outer_r - 25) if i % 2 == 0 else (inner_r - 12)
        ang = i * (math.pi / 5) - math.pi * 0.5
        inner_star.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    draw.polygon(inner_star, fill=(249, 231, 159))
    
    # Cute Mario Kart style cartoon eyes
    draw.ellipse([(cx - 38, cy - 20), (cx - 18, cy + 30)], fill=(15, 20, 25))
    draw.ellipse([(cx + 18, cy - 20), (cx + 38, cy + 30)], fill=(15, 20, 25))
    draw.ellipse([(cx - 34, cy - 14), (cx - 24, cy + 4)], fill=(255, 255, 255))
    draw.ellipse([(cx + 22, cy - 14), (cx + 32, cy + 4)], fill=(255, 255, 255))
    
    # Star sparkles
    for sx, sy in [(90, 110), (410, 120), (420, 390), (95, 380)]:
        draw.polygon([(sx, sy - 20), (sx + 8, sy), (sx, sy + 20), (sx - 8, sy)], fill=(255, 255, 255), outline=(15, 20, 25), width=3)
        draw.polygon([(sx - 20, sy), (sx, sy + 8), (sx + 20, sy), (sx, sy - 8)], fill=(255, 255, 255), outline=(15, 20, 25), width=3)

    img.save(os.path.join(KART_DIR, "kart_item_gold_star.png"))

# 8. kart_item_fake_box.png
def make_fake_box():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 270
    
    # Ticking dynamite fuse at top
    draw.line([(cx, cy - 140), (cx + 30, cy - 190), (cx + 60, cy - 180)], fill=(140, 100, 50), width=10)
    # Spark on fuse
    draw.ellipse([(cx + 55, cy - 195), (cx + 80, cy - 170)], fill=(241, 196, 15))
    draw.ellipse([(cx + 62, cy - 188), (cx + 73, cy - 177)], fill=(231, 76, 60))
    
    # Red-tinted crystal question block
    draw.rounded_rectangle([(cx - 140, cy - 140), (cx + 140, cy + 140)], radius=28, fill=(192, 57, 43), outline=(15, 20, 25), width=14)
    draw.rounded_rectangle([(cx - 120, cy - 120), (cx + 120, cy + 120)], radius=20, fill=(231, 76, 60), outline=(15, 20, 25), width=8)
    
    # Crystal corner bevels
    draw.line([(cx - 120, cy - 120), (cx - 80, cy - 80)], fill=(255, 150, 150), width=8)
    draw.line([(cx + 120, cy - 120), (cx + 80, cy - 80)], fill=(255, 150, 150), width=8)
    
    # Upside-down question mark (¿)
    font = get_font(160)
    draw_thick_text(draw, (cx - 36, cy - 105), "¿", font, (255, 255, 255), outline_color=(15, 20, 25), outline_width=8)
    
    img.save(os.path.join(KART_DIR, "kart_item_fake_box.png"))

# 9. kart_hud_roulette_frame.png
def make_roulette_frame():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Rainbow Neon Corners
    draw.rounded_rectangle([(25, 25), (487, 487)], radius=56, fill=(44, 62, 80), outline=(15, 20, 25), width=16)
    
    # Chrome Bevel Border
    draw.rounded_rectangle([(45, 45), (467, 467)], radius=44, fill=(189, 195, 199), outline=(15, 20, 25), width=10)
    draw.rounded_rectangle([(65, 65), (447, 447)], radius=36, fill=(236, 240, 241), outline=(15, 20, 25), width=6)
    
    # Rainbow corner accents
    corner_colors = [(231, 76, 60), (241, 196, 15), (46, 204, 113), (52, 152, 219)]
    draw.line([(45, 110), (45, 45), (110, 45)], fill=corner_colors[0], width=16)
    draw.line([(467, 110), (467, 45), (402, 45)], fill=corner_colors[1], width=16)
    draw.line([(467, 402), (467, 467), (402, 467)], fill=corner_colors[2], width=16)
    draw.line([(45, 402), (45, 467), (110, 467)], fill=corner_colors[3], width=16)
    
    # Dark Inner Item Window
    draw.rounded_rectangle([(85, 85), (427, 427)], radius=28, fill=(24, 44, 97), outline=(15, 20, 25), width=10)
    
    # Subtle inner grid pattern
    for g in range(125, 400, 40):
        draw.line([(g, 90), (g, 420)], fill=(34, 54, 110), width=3)
        draw.line([(90, g), (420, g)], fill=(34, 54, 110), width=3)
        
    img.save(os.path.join(KART_DIR, "kart_hud_roulette_frame.png"))

# 10. kart_flag_checkered.png
def make_flag_checkered():
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)
    cx, cy = 256, 256
    
    # Crossed flagpole poles (Gold/Brown)
    draw.line([(70, 440), (440, 80)], fill=(211, 84, 0), width=20)
    draw.line([(70, 440), (440, 80)], fill=(15, 20, 25), width=6)
    draw.line([(442, 440), (72, 80)], fill=(211, 84, 0), width=20)
    draw.line([(442, 440), (72, 80)], fill=(15, 20, 25), width=6)
    
    # Left Checkered Flag
    flag1_pts = [(72, 80), (220, 110), (200, 240), (130, 210)]
    draw_thick_polygon(draw, flag1_pts, fill=(255, 255, 255), outline=(15, 20, 25), outline_width=8)
    # Checkered pattern
    draw.polygon([(72, 80), (146, 95), (136, 160), (95, 145)], fill=(15, 20, 25))
    draw.polygon([(146, 160), (200, 240), (130, 210), (115, 175)], fill=(15, 20, 25))
    
    # Right Checkered Flag
    flag2_pts = [(440, 80), (292, 110), (312, 240), (382, 210)]
    draw_thick_polygon(draw, flag2_pts, fill=(255, 255, 255), outline=(15, 20, 25), outline_width=8)
    draw.polygon([(440, 80), (366, 95), (376, 160), (417, 145)], fill=(15, 20, 25))
    draw.polygon([(366, 160), (312, 240), (382, 210), (397, 175)], fill=(15, 20, 25))
    
    # Golden Trophy in Center
    # Trophy cup
    draw.rectangle([(cx - 30, cy + 80), (cx + 30, cy + 120)], fill=(241, 196, 15), outline=(15, 20, 25), width=6)
    draw.rectangle([(cx - 45, cy + 120), (cx + 45, cy + 145)], fill=(211, 84, 0), outline=(15, 20, 25), width=6)
    # Cup body
    cup_pts = [(cx - 65, cy - 40), (cx + 65, cy - 40), (cx + 40, cy + 70), (cx - 40, cy + 70)]
    draw_thick_polygon(draw, cup_pts, fill=(241, 196, 15), outline=(15, 20, 25), outline_width=8)
    # Trophy handles
    draw.arc([(cx - 95, cy - 30), (cx - 45, cy + 40)], start=90, end=270, fill=(241, 196, 15), width=12)
    draw.arc([(cx + 45, cy - 30), (cx + 95, cy + 40)], start=-90, end=90, fill=(241, 196, 15), width=12)
    # Star on trophy
    draw.polygon([(cx, cy - 15), (cx + 6, cy + 2), (cx + 22, cy + 2), (cx + 10, cy + 12), (cx + 14, cy + 28), (cx, cy + 18), (cx - 14, cy + 28), (cx - 10, cy + 12), (cx - 22, cy + 2), (cx - 6, cy + 2)], fill=(255, 255, 255))
    
    img.save(os.path.join(KART_DIR, "kart_flag_checkered.png"))

def main():
    print("Generating Phase 15 Nano Banana Kart Icons & Badges...")
    make_green_tire()
    make_red_missile()
    make_blue_drone()
    make_oil_slick()
    make_triple_nitro()
    make_emp_lightning()
    make_gold_star()
    make_fake_box()
    make_roulette_frame()
    make_flag_checkered()
    print("All 10 Kart Assets Generated in %s" % KART_DIR)

if __name__ == "__main__":
    main()
