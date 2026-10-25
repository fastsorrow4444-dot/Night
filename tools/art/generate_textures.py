"""Original tileable character materials. Optional asset-authoring tool, not a game dependency."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

DEST = Path(__file__).resolve().parents[2] / 'assets' / 'character' / 'textures'
DEST.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(13)
size = 512
y, x = np.mgrid[:size, :size]
materials = {
    'work_canvas': ((43, 68, 73), 'canvas'),
    'work_trousers': ((51, 64, 65), 'canvas'),
    'hoodie': ((107, 47, 49), 'cotton'),
    'denim': ((49, 73, 100), 'denim'),
    'leather': ((43, 36, 29), 'leather'),
    'skin': ((187, 139, 108), 'skin'),
}
for name, (base, kind) in materials.items():
    fibers = np.sin(x * np.pi) * .6 + np.cos(y * np.pi) * .6
    if kind == 'denim':
        fibers = np.sin((x + y * 2) * np.pi / 3) * 4 + np.cos(x * np.pi) * 2
    elif kind == 'canvas':
        fibers = np.sin(x * np.pi / 2) * 2 + np.cos(y * np.pi / 2) * 2
        fibers += ((x % 64 < 2) | (y % 64 < 2)) * 2
    elif kind == 'cotton':
        fibers = np.sin(x * np.pi / 2) * np.sin(y * np.pi / 3) * 2
    coarse = (np.sin(x * np.pi * 2 / size) * np.cos(y * np.pi * 4 / size) * 2)
    noise = rng.normal(0, 1.1 if kind == 'skin' else 2.2, (size, size))
    value = fibers + noise + coarse
    if kind == 'leather':
        value += np.maximum(0, np.sin(x * .17) + np.cos(y * .21)) * 3
    color = np.clip(np.array(base)[None, None, :] + value[..., None], 0, 255).astype(np.uint8)
    Image.fromarray(color).save(DEST / f'{name}.png')
    dx = np.roll(value, 1, axis=1) - np.roll(value, -1, axis=1)
    dy = np.roll(value, 1, axis=0) - np.roll(value, -1, axis=0)
    normal = np.stack([128 + dx * 1.5, 128 - dy * 1.5, np.full_like(dx, 252)], axis=-1)
    Image.fromarray(np.clip(normal, 0, 255).astype(np.uint8)).save(DEST / f'{name}_normal.png')

patch = Image.new('RGB', (512, 256), '#c3b898')
d = ImageDraw.Draw(patch)
font_root = Path('/usr/share/fonts/truetype/dejavu')
d.rounded_rectangle((9, 9, 503, 247), radius=12, outline='#564f3c', width=5)
for px in range(22, 494, 12):
    d.line((px, 18, px + 5, 18), fill='#e1d6b5', width=2)
    d.line((px, 238, px + 5, 238), fill='#e1d6b5', width=2)
d.text((32, 27), 'С / Т', font=ImageFont.truetype(str(font_root / 'DejaVuSans-Bold.ttf'), 70), fill='#263b3c')
d.text((34, 122), 'ОПЕРАТОР', font=ImageFont.truetype(str(font_root / 'DejaVuSans.ttf'), 43), fill='#263b3c')
d.text((333, 40), '013', font=ImageFont.truetype(str(font_root / 'DejaVuSansMono.ttf'), 65), fill='#765b34')
patch.save(DEST / 'operator_patch.png')
print('Original clothing and skin textures:', DEST)
