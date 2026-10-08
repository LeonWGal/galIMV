"""Generate Aurora SVG variants from the Lobe accent palette."""
from pathlib import Path
import colorsys
import re
from html import escape

root = Path(__file__).resolve().parents[1]
source = root / "resources" / "app.svg"
out = root / "resources" / "lobe-variants"
out.mkdir(parents=True, exist_ok=True)
template = source.read_text(encoding="utf-8")

palette = {
    "blue": ("Lobe Blue", "#1677ff"),
    "purple": ("Lobe Purple", "#722ed1"),
    "magenta": ("Lobe Magenta", "#eb2f96"),
    "cyan": ("Lobe Cyan", "#13c2c2"),
    "green": ("Lobe Green", "#52c41a"),
    "orange": ("Lobe Orange", "#fa8c16"),
    "zinc": ("Monochrome Zinc", "#71717a"),
}

def recolor(hex_value: str, target_hue: float) -> str:
    rgb = tuple(int(hex_value[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hue, saturation, lightness = colorsys.rgb_to_hls(*rgb)
    if lightness > 0.9 and saturation < 0.3:
        return hex_value.upper()
    if saturation < 0.12:
        return hex_value.upper()
    # Preserve the Aurora's depth while using an accent-specific hue.
    saturation = min(0.88, max(0.14, saturation))
    if target_hue < 0.02:  # Zinc: quiet neutral glass instead of colored glow.
        saturation = min(0.18, saturation)
    red, green, blue = colorsys.hls_to_rgb(target_hue % 1.0, lightness, saturation)
    return "#%02X%02X%02X" % tuple(round(v * 255) for v in (red, green, blue))

hex_pattern = re.compile(r"#[0-9A-Fa-f]{6}")
cards = []
for slug, (name, accent) in palette.items():
    accent_rgb = tuple(int(accent[i:i + 2], 16) / 255 for i in (1, 3, 5))
    accent_hue = colorsys.rgb_to_hls(*accent_rgb)[0]

    def replace(match):
        value = match.group(0)
        rgb = tuple(int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))
        hue, saturation, lightness = colorsys.rgb_to_hls(*rgb)
        if saturation < 0.12 or lightness > 0.9:
            return value.upper()
        # Cyan/teal Aurora folds and blue/violet folds remain distinct.
        target = accent_hue + (0.055 if hue > 0.58 else -0.035)
        return recolor(value, target)

    svg = hex_pattern.sub(replace, template)
    svg = svg.replace("Aurora — glass image icon", f"Aurora — {name} icon")
    target = out / f"aurora-{slug}.svg"
    target.write_text(svg, encoding="utf-8")
    cards.append((name, target.name, accent))

sizes = (16, 24, 32, 48, 64, 128, 256)
header = """<!doctype html><meta charset='utf-8'><title>galIMV · Aurora Lobe variants</title>
<style>*{box-sizing:border-box}body{margin:0;background:#09090b;color:#f4f4f5;font:14px 'Segoe UI',sans-serif}main{max-width:1280px;margin:auto;padding:32px}h1{font-size:24px;font-weight:500;margin:0 0 8px}p{color:#a1a1aa;margin:0 0 26px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}.card{padding:16px;border:1px solid #27272a;border-radius:16px;background:#121215}.name{font-weight:600}.hex{margin-top:5px;color:#a1a1aa;font-family:monospace}.backgrounds{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-top:14px}.stage{height:140px;border-radius:10px;display:grid;place-items:center;border:1px solid rgba(255,255,255,.12)}.stage img{width:112px;height:112px}.light{background:#f4f4f5}.dark{background:#09090b}.color{background:#334155}.warm{background:#f8ead8}.checker{background-color:#d4d4d8;background-image:linear-gradient(45deg,#a1a1aa 25%,transparent 25%),linear-gradient(-45deg,#a1a1aa 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#a1a1aa 75%),linear-gradient(-45deg,transparent 75%,#a1a1aa 75%);background-size:20px 20px;background-position:0 0,0 10px,10px -10px,-10px 0}.label{font-size:11px;color:#a1a1aa;margin-top:5px}.sizes{display:flex;align-items:end;gap:12px;min-height:145px;padding:14px 4px 4px;overflow-x:auto}.size{display:flex;flex-direction:column;align-items:center;gap:5px;color:#a1a1aa;font-size:10px;min-width:30px}.size img{object-fit:contain}</style>
<main><h1>galIMV · Aurora Lobe variants</h1><p>Контраст на пяти фонах и реальные размеры Windows-иконки.</p><div class='grid'>"""

def render_card(card):
    name, filename, accent = card
    sizes_html = "".join(f"<div class='size'><img src='{escape(filename)}' width='{size}' height='{size}' alt='{size}px'><span>{size}</span></div>" for size in sizes)
    stages = "".join(f"<div><div class='stage {cls}'><img src='{escape(filename)}' alt='{escape(name)} {cls}'></div><div class='label'>{label}</div></div>" for cls, label in (("light", "light"), ("dark", "dark"), ("color", "slate"), ("warm", "warm"), ("checker", "transparent")))
    return f"<article class='card'><div class='name'>{escape(name)}</div><div class='hex'>{accent}</div><div class='backgrounds'>{stages}</div><div class='sizes'>{sizes_html}</div></article>"

(out / "preview.html").write_text(header + "\n".join(render_card(card) for card in cards) + "</div></main>", encoding="utf-8")
print(f"Generated {len(cards)} Aurora variants in {out}")
