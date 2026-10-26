import os
from PIL import Image, ImageFilter
import numpy as np
from collections import deque

REWARDS_MOCKUP = "C:/Users/muthp/.gemini/antigravity/brain/2c8521a3-a55a-4b77-8ce7-fe8e9923ae8e/mockup_rewards_vault_1792600947099.jpg"
im = Image.open(REWARDS_MOCKUP).convert("RGBA")

# Extract the DAILY REWARDS! ribbon (x: 290..1060, y: 70..240)
rib = im.crop((280, 70, 1070, 240))
w, h = rib.size
arr = np.array(rib)

# Find background mask: outside the red ribbon and gold stitching
# The background is the wooden board (brown/tan) and blue top border (dark blue)
# Red ribbon has high R, low G, low B (R > 160, G < 90, B < 90) or gold trim (R > 180, G > 140, B < 80)
is_ribbon = ((arr[:, :, 0] > 140) & (arr[:, :, 1] < 100) & (arr[:, :, 2] < 100)) | \
            ((arr[:, :, 0] > 180) & (arr[:, :, 1] > 130) & (arr[:, :, 2] < 90)) | \
            ((arr[:, :, 0] > 230) & (arr[:, :, 1] > 230) & (arr[:, :, 2] > 230)) # white text

# Dark comic outline of ribbon
is_outline = (arr[:, :, 0] < 60) & (arr[:, :, 1] < 40) & (arr[:, :, 2] < 40)

# Floodfill from edges to remove all non-ribbon background
mask = np.zeros((h, w), dtype=bool)
visited = np.zeros((h, w), dtype=bool)
q = deque()

for x in range(w):
    if not is_ribbon[0, x]: q.append((0, x)); visited[0, x] = True
    if not is_ribbon[h-1, x]: q.append((h-1, x)); visited[h-1, x] = True
for y in range(h):
    if not is_ribbon[y, 0]: q.append((y, 0)); visited[y, 0] = True
    if not is_ribbon[y, w-1]: q.append((y, w-1)); visited[y, w-1] = True

while q:
    cy, cx = q.popleft()
    mask[cy, cx] = True
    for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
        ny, nx = cy + dy, cx + dx
        if 0 <= ny < h and 0 <= nx < w:
            if not visited[ny, nx] and not is_ribbon[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

# Smooth alpha
alpha = np.where(mask, 0, 255).astype(np.uint8)
alpha_img = Image.fromarray(alpha, mode="L").filter(ImageFilter.GaussianBlur(radius=0.8))
rib.putalpha(alpha_img)

out_p = "tools/test_crops/ribbon_header_rewards_extracted.png"
rib.save(out_p)
print(f"Saved {out_p}: {rib.size}")
