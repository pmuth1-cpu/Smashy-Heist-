import os
import math
from PIL import Image, ImageDraw, ImageFont

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(WORKSPACE_DIR, "assets")

def ensure_dirs():
    for sub in ["ui", "hud", "modes", "splash", "kart", "items", "ribbons"]:
        os.makedirs(os.path.join(ASSETS_DIR, sub), exist_ok=True)

def get_font(size):
    for font_name in ["impact.ttf", "arialbd.ttf", "segoeprb.ttf"]:
        font_path = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", font_name)
        if os.path.exists(font_path):
            try:
                return ImageFont.truetype(font_path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_thick_text(draw, pos, text, font, fill_color, outline_color=(15, 20, 30), outline_width=6):
    x, y = pos
    for dx in range(-outline_width, outline_width + 1):
        for dy in range(-outline_width, outline_width + 1):
            if dx * dx + dy * dy <= outline_width * outline_width:
                draw.text((x + dx, y + dy), text, font=font, fill=outline_color)
    draw.text((x, y), text, font=font, fill=fill_color)

def make_candy_pill_button(top_color, base_color, outline_color=(15, 20, 30), width=256, height=100, extrusion=12, corner_r=30):
    scale = 2
    sw, sh = width * scale, height * scale
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    pad = 6 * scale
    ext = extrusion * scale
    r = corner_r * scale
    
    # 1. Dark comic outline for extruded base
    draw.rounded_rectangle([pad, pad + ext, sw - pad, sh - pad], radius=r, fill=outline_color)
    # 2. Base extruded body
    draw.rounded_rectangle([pad + 4*scale, pad + ext + 4*scale, sw - pad - 4*scale, sh - pad - 4*scale], radius=r - 2*scale, fill=base_color)
    
    # 3. Top button outline
    draw.rounded_rectangle([pad, pad, sw - pad, sh - pad - ext], radius=r, fill=outline_color)
    # 4. Top button candy body
    draw.rounded_rectangle([pad + 4*scale, pad + 4*scale, sw - pad - 4*scale, sh - pad - ext - 4*scale], radius=r - 2*scale, fill=top_color)
    
    # 5. Inner bottom bevel shadow on top body
    top_bot_y = sh - pad - ext - 4*scale
    draw.rounded_rectangle([pad + 6*scale, top_bot_y - 12*scale, sw - pad - 6*scale, top_bot_y], radius=r - 4*scale, fill=(0, 0, 0, 45))
    
    # 6. Glossy highlight reflection (crisp top specular arc)
    hl_pad = pad + 6 * scale
    hl_h = int((sh - pad - ext) * 0.28)
    draw.rounded_rectangle([hl_pad, hl_pad, sw - hl_pad, hl_h], radius=r - 4*scale, fill=(255, 255, 255, 75))
    draw.rounded_rectangle([hl_pad + 8*scale, hl_pad + 2*scale, sw - hl_pad - 8*scale, hl_h - 4*scale], radius=r - 8*scale, fill=(255, 255, 255, 140))
    
    return img.resize((width, height), Image.Resampling.LANCZOS)

def make_round_bubble_button(top_color, base_color, symbol="X", outline_color=(15, 20, 30), size=128):
    scale = 3
    ss = size * scale
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = ss // 2, ss // 2
    radius = (ss // 2) - 16 * scale
    ext = 10 * scale
    
    # 1. Base extruded shadow circle
    draw.ellipse([cx - radius, cy - radius + ext, cx + radius, cy + radius + ext], fill=outline_color)
    draw.ellipse([cx - radius + 4*scale, cy - radius + ext + 4*scale, cx + radius - 4*scale, cy + radius + ext - 4*scale], fill=base_color)
    
    # 2. Top button circle
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=outline_color)
    draw.ellipse([cx - radius + 5*scale, cy - radius + 5*scale, cx + radius - 5*scale, cy + radius - 5*scale], fill=top_color)
    
    # 3. Glossy bubble specular crescent
    hl_r = radius - 8 * scale
    draw.ellipse([cx - hl_r, cy - hl_r, cx + hl_r, cy + int(hl_r * 0.2)], fill=(255, 255, 255, 150))
    draw.ellipse([cx - hl_r + 6*scale, cy - hl_r + 3*scale, cx + hl_r - 6*scale, cy - int(hl_r * 0.1)], fill=(255, 255, 255, 220))
    
    # 4. Draw Symbol (X or PAUSE)
    if symbol == "X":
        thick = 12 * scale
        arm = int(radius * 0.45)
        cy_sym = cy - int(ext * 0.3)
        draw.line([cx - arm, cy_sym - arm, cx + arm, cy_sym + arm], fill=outline_color, width=thick + 6*scale)
        draw.line([cx - arm, cy_sym + arm, cx + arm, cy_sym - arm], fill=outline_color, width=thick + 6*scale)
        draw.line([cx - arm, cy_sym - arm, cx + arm, cy_sym + arm], fill=(255, 255, 255), width=thick)
        draw.line([cx - arm, cy_sym + arm, cx + arm, cy_sym - arm], fill=(255, 255, 255), width=thick)
    elif symbol == "PAUSE":
        thick = 10 * scale
        bar_h = int(radius * 0.48)
        bar_sep = 12 * scale
        cy_sym = cy - int(ext * 0.3)
        draw.rounded_rectangle([cx - bar_sep - thick, cy_sym - bar_h, cx - bar_sep, cy_sym + bar_h], radius=4*scale, fill=outline_color)
        draw.rounded_rectangle([cx - bar_sep - thick + 2*scale, cy_sym - bar_h + 2*scale, cx - bar_sep - 2*scale, cy_sym + bar_h - 2*scale], radius=3*scale, fill=(255, 255, 255))
        draw.rounded_rectangle([cx + bar_sep, cy_sym - bar_h, cx + bar_sep + thick, cy_sym + bar_h], radius=4*scale, fill=outline_color)
        draw.rounded_rectangle([cx + bar_sep + 2*scale, cy_sym - bar_h + 2*scale, cx + bar_sep + thick - 2*scale, cy_sym + bar_h - 2*scale], radius=3*scale, fill=(255, 255, 255))
        
    return img.resize((size, size), Image.Resampling.LANCZOS)

def make_ribbon_banner(title_text, ribbon_color, trim_color=(241, 196, 15), outline_color=(15, 20, 30), width=640, height=160):
    scale = 2
    sw, sh = width * scale, height * scale
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = sw // 2
    pad_x = 30 * scale
    pad_y = 20 * scale
    rib_h = 80 * scale
    tail_w = 70 * scale
    fold_w = 35 * scale
    fold_y = 22 * scale
    
    # 1. Left and right draped tails (behind center ribbon)
    l_tail = [
        (pad_x, pad_y + fold_y),
        (pad_x + tail_w, pad_y + fold_y),
        (pad_x + tail_w, pad_y + fold_y + rib_h),
        (pad_x, pad_y + fold_y + rib_h),
        (pad_x + 25*scale, pad_y + fold_y + rib_h // 2)
    ]
    dark_tail = (int(ribbon_color[0] * 0.70), int(ribbon_color[1] * 0.70), int(ribbon_color[2] * 0.70))
    draw.polygon(l_tail, fill=dark_tail, outline=outline_color, width=5*scale)
    
    r_tail = [
        (sw - pad_x, pad_y + fold_y),
        (sw - pad_x - tail_w, pad_y + fold_y),
        (sw - pad_x - tail_w, pad_y + fold_y + rib_h),
        (sw - pad_x, pad_y + fold_y + rib_h),
        (sw - pad_x - 25*scale, pad_y + fold_y + rib_h // 2)
    ]
    draw.polygon(r_tail, fill=dark_tail, outline=outline_color, width=5*scale)
    
    # 2. Main arched center ribbon body
    mid_left = pad_x + tail_w - fold_w
    mid_right = sw - pad_x - tail_w + fold_w
    top_y = pad_y
    bot_y = pad_y + rib_h
    
    # Base ribbon with gold trim
    draw.rounded_rectangle([mid_left, top_y, mid_right, bot_y], radius=18*scale, fill=outline_color)
    draw.rounded_rectangle([mid_left + 4*scale, top_y + 4*scale, mid_right - 4*scale, bot_y - 4*scale], radius=15*scale, fill=trim_color)
    draw.rounded_rectangle([mid_left + 8*scale, top_y + 8*scale, mid_right - 8*scale, bot_y - 8*scale], radius=12*scale, fill=ribbon_color)
    
    # 3. Glossy highlight across top edge
    draw.rounded_rectangle([mid_left + 10*scale, top_y + 6*scale, mid_right - 10*scale, top_y + 26*scale], radius=8*scale, fill=(255, 255, 255, 110))
    
    # 4. Text with 3D drop shadow
    font = get_font(40 * scale)
    bbox = draw.textbbox((0, 0), title_text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw // 2
    ty = top_y + (rib_h - th) // 2 - 4*scale
    
    for d in range(4 * scale, 0, -1):
        draw_thick_text(draw, (tx, ty + d), title_text, font, dark_tail, outline_color=(15, 20, 30), outline_width=6*scale)
    draw_thick_text(draw, (tx, ty), title_text, font, (255, 255, 255), outline_color=(15, 20, 30), outline_width=6*scale)
    
    # Side Star Accents
    for sx in [mid_left + 24*scale, mid_right - 24*scale]:
        sy = top_y + rib_h // 2
        draw.ellipse([sx - 10*scale, sy - 10*scale, sx + 10*scale, sy + 10*scale], fill=(241, 196, 15), outline=outline_color, width=3*scale)
        draw.ellipse([sx - 4*scale, sy - 4*scale, sx + 4*scale, sy + 4*scale], fill=(255, 255, 255))
    
    return img.resize((width, height), Image.Resampling.LANCZOS)

def make_cartoon_star(is_gold=True, size=256):
    scale = 3
    ss = size * scale
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = ss // 2, ss // 2
    r_outer = int(ss * 0.42)
    r_inner = int(ss * 0.20)
    
    points = []
    for i in range(10):
        ang = -math.pi * 0.5 + i * (math.pi / 5.0)
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    
    outline_color = (15, 20, 30)
    
    if is_gold:
        base_ext = 8 * scale
        base_points = [(p[0], p[1] + base_ext) for p in points]
        draw.polygon(base_points, fill=outline_color)
        draw.polygon([(p[0], p[1] + base_ext) for p in points], fill=(211, 84, 0))
        draw.polygon(points, fill=outline_color)
        draw.polygon(points, fill=(241, 196, 15))
        inner_points = []
        for i in range(10):
            ang = -math.pi * 0.5 + i * (math.pi / 5.0)
            r = (r_outer - 6*scale) if i % 2 == 0 else (r_inner - 3*scale)
            inner_points.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
        draw.polygon(inner_points, fill=(243, 156, 18))
        draw.ellipse([cx - int(r_outer * 0.35), cy - int(r_outer * 0.45), cx - int(r_outer * 0.15), cy - int(r_outer * 0.25)], fill=(255, 255, 255, 230))
    else:
        draw.polygon(points, fill=outline_color)
        draw.polygon(points, fill=(35, 45, 65))
        inner_points = []
        for i in range(10):
            ang = -math.pi * 0.5 + i * (math.pi / 5.0)
            r = (r_outer - 8*scale) if i % 2 == 0 else (r_inner - 4*scale)
            inner_points.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
        draw.polygon(inner_points, fill=(20, 28, 42))
        
    return img.resize((size, size), Image.Resampling.LANCZOS)

def make_cartoon_chest_day7(size=384):
    scale = 2
    ss = size * scale
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = ss // 2, ss // 2 + 10*scale
    outline_color = (20, 25, 35)
    
    # 1. Golden Aura Glow behind chest
    glow_r = int(ss * 0.44)
    draw.ellipse([cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r], fill=(241, 196, 15, 60))
    draw.ellipse([cx - int(glow_r*0.75), cy - int(glow_r*0.75), cx + int(glow_r*0.75), cy + int(glow_r*0.75)], fill=(255, 230, 80, 80))
    
    # 2. Chest Lower Body
    bw, bh = 240 * scale, 130 * scale
    bx1, by1 = cx - bw // 2, cy - 10 * scale
    bx2, by2 = cx + bw // 2, cy - 10 * scale + bh
    draw.rounded_rectangle([bx1, by1 + 10*scale, bx2, by2 + 10*scale], radius=24*scale, fill=outline_color)
    draw.rounded_rectangle([bx1, by1, bx2, by2], radius=24*scale, fill=outline_color)
    draw.rounded_rectangle([bx1 + 6*scale, by1 + 6*scale, bx2 - 6*scale, by2 - 6*scale], radius=20*scale, fill=(142, 68, 173))
    
    # Gold Straps
    strap_w = 28 * scale
    draw.rounded_rectangle([bx1 + 30*scale, by1 + 6*scale, bx1 + 30*scale + strap_w, by2 - 6*scale], radius=6*scale, fill=(241, 196, 15))
    draw.rounded_rectangle([bx2 - 30*scale - strap_w, by1 + 6*scale, bx2 - 30*scale, by2 - 6*scale], radius=6*scale, fill=(241, 196, 15))
    
    # 3. Chest Lid (Arched Dome)
    lid_w, lid_h = 260 * scale, 95 * scale
    lx1, ly1 = cx - lid_w // 2, by1 - lid_h + 12*scale
    lx2, ly2 = cx + lid_w // 2, by1 + 12*scale
    draw.rounded_rectangle([lx1, ly1, lx2, ly2], radius=32*scale, fill=outline_color)
    draw.rounded_rectangle([lx1 + 6*scale, ly1 + 6*scale, lx2 - 6*scale, ly2 - 6*scale], radius=28*scale, fill=(155, 89, 182))
    draw.rounded_rectangle([lx1 + 16*scale, ly1 + 10*scale, lx2 - 16*scale, ly1 + 35*scale], radius=16*scale, fill=(255, 255, 255, 110))
    draw.rounded_rectangle([lx1 + 40*scale, ly1 + 6*scale, lx1 + 40*scale + strap_w, ly2 - 6*scale], radius=6*scale, fill=(241, 196, 15))
    draw.rounded_rectangle([lx2 - 40*scale - strap_w, ly1 + 6*scale, lx2 - 40*scale, ly2 - 6*scale], radius=6*scale, fill=(241, 196, 15))
    
    # 4. Smiling Golden Lock
    lock_r = 34 * scale
    draw.ellipse([cx - lock_r, cy - 15*scale - lock_r, cx + lock_r, cy - 15*scale + lock_r], fill=outline_color)
    draw.ellipse([cx - lock_r + 4*scale, cy - 15*scale - lock_r + 4*scale, cx + lock_r - 4*scale, cy - 15*scale + lock_r - 4*scale], fill=(241, 196, 15))
    draw.ellipse([cx - 7*scale, cy - 22*scale, cx + 7*scale, cy - 8*scale], fill=outline_color)
    draw.polygon([(cx - 5*scale, cy - 12*scale), (cx + 5*scale, cy - 12*scale), (cx + 7*scale, cy - 2*scale), (cx - 7*scale, cy - 2*scale)], fill=outline_color)
    
    # 5. Colorful gems
    gem_colors = [(255, 71, 87), (46, 204, 113), (9, 132, 227), (241, 196, 15)]
    for i, gc in enumerate(gem_colors):
        gx = cx - 75*scale + i * 50*scale
        gy = by2 - 4*scale
        draw.ellipse([gx - 10*scale, gy - 10*scale, gx + 10*scale, gy + 10*scale], fill=outline_color)
        draw.ellipse([gx - 8*scale, gy - 8*scale, gx + 8*scale, gy + 8*scale], fill=gc)
        draw.ellipse([gx - 4*scale, gy - 6*scale, gx, gy - 2*scale], fill=(255, 255, 255, 220))
        
    return img.resize((size, size), Image.Resampling.LANCZOS)

def make_cartoon_safe(size=256):
    scale = 3
    ss = size * scale
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = ss // 2, ss // 2
    outline_color = (20, 25, 35)
    
    pad = 16 * scale
    ext = 12 * scale
    draw.rounded_rectangle([pad, pad + ext, ss - pad, ss - pad + ext], radius=28*scale, fill=outline_color)
    draw.rounded_rectangle([pad, pad, ss - pad, ss - pad], radius=28*scale, fill=outline_color)
    draw.rounded_rectangle([pad + 6*scale, pad + 6*scale, ss - pad - 6*scale, ss - pad - 6*scale], radius=24*scale, fill=(52, 73, 94))
    
    dpad = pad + 20 * scale
    draw.rounded_rectangle([dpad, dpad, ss - dpad, ss - dpad], radius=18*scale, fill=(44, 62, 80), outline=outline_color, width=4*scale)
    
    wr = 36 * scale
    draw.ellipse([cx - wr, cy - wr, cx + wr, cy + wr], fill=outline_color)
    draw.ellipse([cx - wr + 4*scale, cy - wr + 4*scale, cx + wr - 4*scale, cy + wr - 4*scale], fill=(241, 196, 15))
    for a in [0, 45, 90, 135]:
        rad = math.radians(a)
        x1 = cx + int((wr - 6*scale) * math.cos(rad))
        y1 = cy + int((wr - 6*scale) * math.sin(rad))
        x2 = cx - int((wr - 6*scale) * math.cos(rad))
        y2 = cy - int((wr - 6*scale) * math.sin(rad))
        draw.line([x1, y1, x2, y2], fill=outline_color, width=5*scale)
    draw.ellipse([cx - 12*scale, cy - 12*scale, cx + 12*scale, cy + 12*scale], fill=(230, 126, 34), outline=outline_color, width=3*scale)
    
    bolts = [
        (dpad + 10*scale, dpad + 10*scale),
        (ss - dpad - 10*scale, dpad + 10*scale),
        (dpad + 10*scale, ss - dpad - 10*scale),
        (ss - dpad - 10*scale, ss - dpad - 10*scale),
    ]
    for bx, by in bolts:
        draw.ellipse([bx - 6*scale, by - 6*scale, bx + 6*scale, by + 6*scale], fill=(241, 196, 15), outline=outline_color, width=2*scale)
        
    return img.resize((size, size), Image.Resampling.LANCZOS)

def make_cartoon_mode_card(title, badge_text, bg_gradient_colors, icon_type="car", width=960, height=540):
    scale = 2
    sw, sh = width * scale, height * scale
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 1. Gradient Background
    c_top, c_bot = bg_gradient_colors
    for y in range(sh):
        t = y / float(sh)
        r = int(c_top[0] * (1 - t) + c_bot[0] * t)
        g = int(c_top[1] * (1 - t) + c_bot[1] * t)
        b = int(c_top[2] * (1 - t) + c_bot[2] * t)
        draw.line([(0, y), (sw, y)], fill=(r, g, b, 255))
        
    # 2. Comic Sunburst Beams from center-bottom
    cx, cy = sw // 2, sh - 100 * scale
    beam_color = (255, 255, 255, 30)
    for a in range(0, 360, 24):
        rad1 = math.radians(a)
        rad2 = math.radians(a + 12)
        dist = sw
        p1 = (cx, cy)
        p2 = (cx + int(dist * math.cos(rad1)), cy + int(dist * math.sin(rad1)))
        p3 = (cx + int(dist * math.cos(rad2)), cy + int(dist * math.sin(rad2)))
        draw.polygon([p1, p2, p3], fill=beam_color)
        
    # 3. Ground / Road Curve at bottom
    ground_color = (25, 35, 55, 255)
    road_poly = [
        (0, sh - 140 * scale),
        (sw // 3, sh - 165 * scale),
        (2 * sw // 3, sh - 150 * scale),
        (sw, sh - 180 * scale),
        (sw, sh),
        (0, sh)
    ]
    draw.polygon(road_poly, fill=ground_color)
    draw.line([(0, sh - 140 * scale), (sw // 3, sh - 165 * scale), (2 * sw // 3, sh - 150 * scale), (sw, sh - 180 * scale)], fill=(241, 196, 15, 255), width=8*scale)
    
    # 4. Cute Comic Illustration
    if icon_type == "car":
        car_cx, car_cy = sw // 2, sh - 190 * scale
        draw.ellipse([car_cx - 160*scale, car_cy + 40*scale, car_cx + 160*scale, car_cy + 80*scale], fill=(10, 15, 25, 180))
        draw.ellipse([car_cx - 130*scale, car_cy + 15*scale, car_cx - 70*scale, car_cy + 75*scale], fill=(20, 25, 35))
        draw.ellipse([car_cx - 115*scale, car_cy + 30*scale, car_cx - 85*scale, car_cy + 60*scale], fill=(200, 210, 225))
        draw.ellipse([car_cx + 70*scale, car_cy + 15*scale, car_cx + 130*scale, car_cy + 75*scale], fill=(20, 25, 35))
        draw.ellipse([car_cx + 85*scale, car_cy + 30*scale, car_cx + 115*scale, car_cy + 60*scale], fill=(200, 210, 225))
        draw.rounded_rectangle([car_cx - 150*scale, car_cy - 10*scale, car_cx + 150*scale, car_cy + 45*scale], radius=20*scale, fill=(241, 196, 15), outline=(20, 25, 35), width=6*scale)
        draw.rounded_rectangle([car_cx - 90*scale, car_cy - 65*scale, car_cx + 80*scale, car_cy - 5*scale], radius=18*scale, fill=(100, 210, 255), outline=(20, 25, 35), width=6*scale)
        draw.ellipse([car_cx - 15*scale, car_cy - 85*scale, car_cx + 15*scale, car_cy - 65*scale], fill=(255, 71, 87), outline=(20, 25, 35), width=4*scale)
    elif icon_type == "boss":
        car_cx, car_cy = sw // 2, sh - 210 * scale
        draw.ellipse([car_cx - 100*scale, car_cy - 120*scale, car_cx + 100*scale, car_cy + 40*scale], fill=(30, 20, 45), outline=(15, 10, 25), width=8*scale)
        draw.ellipse([car_cx - 45*scale, car_cy - 60*scale, car_cx + 45*scale, car_cy], fill=(255, 71, 87), outline=(255, 230, 100), width=6*scale)
        draw.ellipse([car_cx - 15*scale, car_cy - 40*scale, car_cx + 15*scale, car_cy - 15*scale], fill=(255, 255, 255))
        for lx, ly in [(-180, -80), (-240, 20), (180, -80), (240, 20)]:
            draw.line([(car_cx + int(lx*0.4*scale), car_cy - 40*scale), (car_cx + lx*scale, car_cy + ly*scale)], fill=(40, 30, 55), width=16*scale)
    elif icon_type == "loot":
        car_cx, car_cy = sw // 2, sh - 180 * scale
        draw.ellipse([car_cx - 110*scale, car_cy - 80*scale, car_cx + 110*scale, car_cy + 90*scale], fill=(46, 204, 113), outline=(20, 35, 25), width=7*scale)
        draw.rounded_rectangle([car_cx - 50*scale, car_cy - 120*scale, car_cx + 50*scale, car_cy - 75*scale], radius=10*scale, fill=(39, 174, 96), outline=(20, 35, 25), width=6*scale)
        draw.rounded_rectangle([car_cx - 35*scale, car_cy - 85*scale, car_cx + 35*scale, car_cy - 70*scale], radius=5*scale, fill=(241, 196, 15))
        font_sym = get_font(72 * scale)
        draw_thick_text(draw, (car_cx - 28*scale, car_cy - 45*scale), "$", font_sym, (255, 255, 255), (15, 30, 20), outline_width=6*scale)
    elif icon_type == "kart":
        car_cx, car_cy = sw // 2, sh - 180 * scale
        draw.rounded_rectangle([car_cx - 50*scale, car_cy - 140*scale, car_cx + 50*scale, car_cy - 40*scale], radius=15*scale, fill=(241, 196, 15), outline=(20, 25, 35), width=6*scale)
        draw.ellipse([car_cx - 85*scale, car_cy - 120*scale, car_cx - 45*scale, car_cy - 70*scale], outline=(241, 196, 15), width=8*scale)
        draw.ellipse([car_cx + 45*scale, car_cy - 120*scale, car_cx + 85*scale, car_cy - 70*scale], outline=(241, 196, 15), width=8*scale)
        draw.rounded_rectangle([car_cx - 120*scale, car_cy - 30*scale, car_cx + 120*scale, car_cy + 35*scale], radius=18*scale, fill=(255, 71, 87), outline=(20, 25, 35), width=6*scale)
        draw.ellipse([car_cx - 110*scale, car_cy + 10*scale, car_cx - 60*scale, car_cy + 65*scale], fill=(20, 25, 35))
        draw.ellipse([car_cx + 60*scale, car_cy + 10*scale, car_cx + 110*scale, car_cy + 65*scale], fill=(20, 25, 35))
        font_n1 = get_font(32 * scale)
        draw_thick_text(draw, (car_cx - 10*scale, car_cy - 115*scale), "1", font_n1, (255, 255, 255), (20, 25, 35), outline_width=4*scale)

    # 5. Sparkle Stars
    star_positions = [
        (80*scale, 90*scale), (150*scale, 180*scale), (sw - 120*scale, 110*scale), (sw - 180*scale, 220*scale)
    ]
    for sx, sy in star_positions:
        draw.polygon([
            (sx, sy - 18*scale), (sx + 5*scale, sy - 5*scale),
            (sx + 18*scale, sy), (sx + 5*scale, sy + 5*scale),
            (sx, sy + 18*scale), (sx - 5*scale, sy + 5*scale),
            (sx - 18*scale, sy), (sx - 5*scale, sy - 5*scale)
        ], fill=(255, 240, 140))
        
    # 6. Title Typography
    font_title = get_font(52 * scale)
    bbox = font_title.getbbox(title)
    tw = bbox[2] - bbox[0]
    tx = (sw - tw) // 2
    ty = 48 * scale
    
    title_ext = 8 * scale
    for ed in range(title_ext, 0, -1):
        draw_thick_text(draw, (tx, ty + ed), title, font_title, (180, 80, 10), (15, 20, 30), outline_width=6*scale)
    draw_thick_text(draw, (tx, ty), title, font_title, (255, 220, 40), (15, 20, 30), outline_width=6*scale)
    
    # 7. Subtitle / Badge Pill
    font_sub = get_font(22 * scale)
    s_bbox = font_sub.getbbox(badge_text)
    s_w = s_bbox[2] - s_bbox[0]
    pill_w = s_w + 48 * scale
    pill_h = 42 * scale
    pill_x = (sw - pill_w) // 2
    pill_y = ty + 70 * scale
    draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=15*scale, fill=(15, 25, 45, 230), outline=(241, 196, 15), width=3*scale)
    draw.text(((sw - s_w) // 2, pill_y + 8*scale), badge_text, font=font_sub, fill=(255, 235, 120))
    
    # 8. Thick Outer Comic Frame
    border_w = 8 * scale
    draw.rectangle([0, 0, sw, border_w], fill=(15, 20, 30))
    draw.rectangle([0, sh - border_w, sw, sh], fill=(15, 20, 30))
    draw.rectangle([0, 0, border_w, sh], fill=(15, 20, 30))
    draw.rectangle([sw - border_w, 0, sw, sh], fill=(15, 20, 30))
    
    return img.resize((width, height), Image.Resampling.LANCZOS)

def build_all_cartoon_assets():
    ensure_dirs()
    print("=== GENERATING COMPLETE 3D CARTOON UI ASSET KIT ===")
    
    # 1. 3D Candy Buttons (256x100 for perfect 9-slice)
    buttons = [
        ("btn_candy_green.png", (46, 204, 113), (27, 122, 67)), # Lime
        ("btn_candy_yellow.png", (241, 196, 15), (211, 84, 0)), # Banana Gold
        ("btn_candy_red.png", (255, 71, 87), (179, 57, 57)),   # Strawberry
        ("btn_candy_blue.png", (9, 132, 227), (6, 82, 221)),    # Sky Blue
        ("btn_candy_purple.png", (142, 68, 173), (91, 44, 111)) # Grape
    ]
    for fname, top_col, base_col in buttons:
        p = os.path.join(ASSETS_DIR, "ui", fname)
        img = make_candy_pill_button(top_col, base_col, width=256, height=100, extrusion=12, corner_r=30)
        img.save(p, "PNG")
        print(f"  [CREATED] {p}")
        
    # 2. Bubble Buttons (X and Pause)
    p_x = os.path.join(ASSETS_DIR, "ui", "btn_round_close_x.png")
    img_x = make_round_bubble_button((255, 71, 87), (179, 57, 57), symbol="X", size=128)
    img_x.save(p_x, "PNG")
    print(f"  [CREATED] {p_x}")
    
    p_pause = os.path.join(ASSETS_DIR, "ui", "btn_round_pause.png")
    img_pause = make_round_bubble_button((9, 132, 227), (6, 82, 221), symbol="PAUSE", size=128)
    img_pause.save(p_pause, "PNG")
    print(f"  [CREATED] {p_pause}")
    
    # 3. Arched Ribbon Headers
    ribbons = [
        ("ribbon_header_paused.png", "PAUSED!", (231, 76, 60), (241, 196, 15)),
        ("ribbon_header_rewards.png", "DAILY REWARDS!", (241, 196, 15), (9, 132, 227)),
        ("ribbon_header_quests.png", "DAILY MISSIONS!", (9, 132, 227), (241, 196, 15))
    ]
    for rname, rtext, rcol, trimcol in ribbons:
        rp = os.path.join(ASSETS_DIR, "ribbons", rname)
        rimg = make_ribbon_banner(rtext, rcol, trimcol)
        rimg.save(rp, "PNG")
        print(f"  [CREATED] {rp}")
        
    # 4. Rewards & Chests
    p_chest = os.path.join(ASSETS_DIR, "items", "icon_cartoon_chest_day7.png")
    img_chest = make_cartoon_chest_day7(384)
    img_chest.save(p_chest, "PNG")
    print(f"  [CREATED] {p_chest}")
    
    p_safe = os.path.join(ASSETS_DIR, "items", "icon_cartoon_heist_safe.png")
    img_safe = make_cartoon_safe(256)
    img_safe.save(p_safe, "PNG")
    print(f"  [CREATED] {p_safe}")
    
    # 5. Cartoon Stars
    p_star_gold = os.path.join(ASSETS_DIR, "hud", "hud_cartoon_star_gold.png")
    img_s_gold = make_cartoon_star(is_gold=True, size=256)
    img_s_gold.save(p_star_gold, "PNG")
    print(f"  [CREATED] {p_star_gold}")
    
    p_star_empty = os.path.join(ASSETS_DIR, "hud", "hud_cartoon_star_empty.png")
    img_s_empty = make_cartoon_star(is_gold=False, size=256)
    img_s_empty.save(p_star_empty, "PNG")
    print(f"  [CREATED] {p_star_empty}")
    
    # 6. Cute Cartoon 16:9 Game Mode Cards
    modes = [
        ("mode_daily_getaway.png", "DAILY GETAWAY", "★ 5-STAR HEIST SURVIVAL ★", ((243, 156, 18), (230, 126, 34)), "car"),
        ("mode_boss_escape.png", "BOSS ESCAPE", "⚡ STEAMPUNK SPIDER MECH ⚡", ((142, 68, 173), (44, 62, 80)), "boss"),
        ("mode_hot_loot.png", "HOT LOOT TAG", "💰 HOLD THE MONEY BAG! 💰", ((46, 204, 113), (22, 160, 133)), "loot"),
        ("mode_kart_gp.png", "SMASHY KART GP", "🏆 3-LAP GRAND PRIX RACER 🏆", ((52, 152, 219), (41, 128, 185)), "kart"),
    ]
    for mname, mtitle, mbadge, mgradient, micon in modes:
        mp = os.path.join(ASSETS_DIR, "modes", mname)
        mimg = make_cartoon_mode_card(mtitle, mbadge, mgradient, micon)
        mimg.save(mp, "PNG")
        print(f"  [CREATED] {mp}")
        
    print("=== COMPLETE CARTOON 3D ASSET SUITE GENERATED! ===")

if __name__ == "__main__":
    build_all_cartoon_assets()
