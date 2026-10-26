import os
from PIL import Image, ImageFilter
import numpy as np

def make_blank_button(img_path):
    im = Image.open(img_path).convert("RGBA")
    w, h = im.size
    arr = np.array(im)
    
    # Left cap: 0 to int(w * 0.28)
    # Right cap: int(w * 0.72) to w
    x1 = int(w * 0.28)
    x2 = int(w * 0.72)
    
    # Sample a clean 4-pixel wide vertical strip just before x1
    sample_strip = arr[:, x1-6:x1-2, :]
    column_avg = np.mean(sample_strip, axis=1, keepdims=True) # shape (h, 1, 4)
    
    # Replicate horizontally across x1..x2
    fill_width = x2 - x1
    fill_block = np.repeat(column_avg, fill_width, axis=1)
    
    # Place fill block
    clean_arr = arr.copy()
    clean_arr[:, x1:x2, :] = fill_block
    
    out = Image.fromarray(clean_arr.astype(np.uint8))
    # Soft horizontal blur only in the center seam transitions to blend perfectly
    # Create mask for seams
    mask = Image.new("L", (w, h), 0)
    from PIL import ImageDraw
    draw = ImageDraw.Draw(mask)
    draw.rectangle([x1-4, 0, x1+6, h], fill=255)
    draw.rectangle([x2-6, 0, x2+4, h], fill=255)
    
    blurred = out.filter(ImageFilter.GaussianBlur(radius=1.5))
    out.paste(blurred, mask=mask)
    return out

res = make_blank_button("d:/My project/smashy heist/tools/test_crops/btn_green.png")
res.save("d:/My project/smashy heist/tools/test_crops/btn_green_blank.png")
print("Saved btn_green_blank.png")
