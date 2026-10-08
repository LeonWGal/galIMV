import os
import math
import random
from PIL import Image, ImageDraw, ImageFilter
from PIL.PngImagePlugin import PngInfo

def gradient_vertical(draw, width, height, top_color, bottom_color):
    for y in range(height):
        factor = y / max(1, height - 1)
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * factor)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * factor)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * factor)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

def draw_stars(draw, width, height, count=70, max_y=None):
    random.seed(42)
    limit_y = max_y or height
    for _ in range(count):
        x = random.randint(0, width - 1)
        y = random.randint(0, limit_y)
        brightness = random.randint(180, 255)
        size = random.choice([1, 1, 1, 2])
        draw.rectangle([x, y, x + size - 1, y + size - 1], fill=(brightness, brightness, brightness))

def make_cyberpunk_city(w=800, h=450):
    img = Image.new("RGB", (w, h), (10, 10, 24))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (12, 14, 38), (34, 18, 56))
    draw_stars(draw, w, int(h * 0.6), count=90)
    
    # Distant glowing moon/billboard
    draw.ellipse([w * 0.7, h * 0.15, w * 0.7 + 120, h * 0.15 + 120], fill=(255, 60, 140))
    
    # Layer 1: Far skyline
    random.seed(101)
    x = 0
    while x < w:
        bw = random.randint(40, 90)
        bh = random.randint(int(h * 0.35), int(h * 0.65))
        draw.rectangle([x, h - bh, x + bw, h], fill=(20, 24, 45))
        x += bw + random.randint(-5, 10)
        
    # Layer 2: Mid skyline with lit windows
    random.seed(202)
    x = 0
    while x < w:
        bw = random.randint(50, 110)
        bh = random.randint(int(h * 0.25), int(h * 0.55))
        top = h - bh
        draw.rectangle([x, top, x + bw, h], fill=(12, 15, 28))
        # Neon antenna
        draw.line([(x + bw // 2, top), (x + bw // 2, top - 35)], fill=(0, 220, 255), width=2)
        draw.ellipse([x + bw // 2 - 3, top - 38, x + bw // 2 + 3, top - 32], fill=(255, 0, 120))
        # Windows
        for wy in range(top + 15, h - 20, 18):
            for wx in range(x + 10, x + bw - 10, 14):
                if random.random() > 0.4:
                    win_color = random.choice([(0, 230, 255), (255, 220, 100), (255, 50, 150)])
                    draw.rectangle([wx, wy, wx + 6, wy + 8], fill=win_color)
        x += bw + random.randint(5, 20)
        
    # Neon highway/water reflection at bottom
    for y in range(int(h * 0.85), h):
        factor = (y - h * 0.85) / (h * 0.15)
        alpha = int(120 * factor)
        draw.line([(0, y), (w, y)], fill=(int(20 + alpha), int(10 + alpha * 0.5), int(50 + alpha * 1.5)))
    return img

def make_fantasy_landscape(w=900, h=500):
    img = Image.new("RGB", (w, h), (30, 15, 45))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (40, 25, 75), (255, 140, 70))
    
    # Sun
    sun_x, sun_y = w * 0.55, h * 0.42
    draw.ellipse([sun_x - 70, sun_y - 70, sun_x + 70, sun_y + 70], fill=(255, 245, 200))
    
    # Distant mountains
    random.seed(303)
    pts1 = [(0, h)]
    for x in range(0, w + 40, 40):
        y = int(h * 0.48 + math.sin(x * 0.015) * 60 + random.randint(-15, 15))
        pts1.append((x, y))
    pts1.append((w, h))
    draw.polygon(pts1, fill=(120, 65, 100))
    
    # Mid mountains
    pts2 = [(0, h)]
    for x in range(0, w + 30, 30):
        y = int(h * 0.62 + math.cos(x * 0.02) * 45 + random.randint(-12, 12))
        pts2.append((x, y))
    pts2.append((w, h))
    draw.polygon(pts2, fill=(65, 30, 65))
    
    # Foreground lake and pine silhouettes
    draw.rectangle([0, int(h * 0.78), w, h], fill=(28, 18, 42))
    # Sun reflection on lake
    for y in range(int(h * 0.78), h, 4):
        width_ref = int(60 + (y - h * 0.78) * 1.2)
        draw.line([(sun_x - width_ref, y), (sun_x + width_ref, y)], fill=(255, 175, 110))
    # Pine trees
    random.seed(404)
    for x in range(0, w, 25):
        if random.random() > 0.3:
            th = random.randint(45, 95)
            ty = h - th
            draw.polygon([(x - 12, h), (x, ty), (x + 12, h)], fill=(15, 10, 22))
    return img

def make_shinkai_clouds(w=840, h=480):
    img = Image.new("RGB", (w, h), (18, 90, 180))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (14, 95, 210), (160, 215, 255))
    
    # Fluffy cumulus clouds
    random.seed(505)
    cloud_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(cloud_layer)
    
    # Huge cloud formation
    cx_base, cy_base = w * 0.5, h * 0.55
    # Shadow base
    for _ in range(35):
        cx = int(cx_base + random.randint(-220, 220))
        cy = int(cy_base + random.randint(-40, 80))
        rad = random.randint(60, 110)
        cdraw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(175, 195, 225, 220))
    # Bright illuminated tops
    for _ in range(40):
        cx = int(cx_base + random.randint(-200, 200))
        cy = int(cy_base - random.randint(30, 140))
        rad = random.randint(55, 95)
        cdraw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(255, 255, 255, 240))
        
    cloud_layer = cloud_layer.filter(ImageFilter.GaussianBlur(radius=8))
    img.paste(cloud_layer, (0, 0), cloud_layer)
    
    # Sun flare rays
    draw = ImageDraw.Draw(img)
    for i in range(5):
        angle = 0.3 + i * 0.12
        rx = int(w * 0.85 - math.cos(angle) * 350)
        ry = int(h * 0.1 + math.sin(angle) * 350)
        draw.line([(w * 0.85, int(h * 0.1)), (rx, ry)], fill=(255, 255, 230), width=3)
        
    # Foreground green field silhouette
    draw.polygon([(0, h), (0, int(h * 0.86)), (w * 0.6, int(h * 0.82)), (w, int(h * 0.88)), (w, h)], fill=(20, 60, 35))
    return img

def make_anime_girl(w=512, h=768):
    img = Image.new("RGB", (w, h), (245, 235, 242))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (40, 25, 60), (220, 140, 170))
    
    # Glowing magical bokeh particles
    random.seed(606)
    for _ in range(40):
        px = random.randint(30, w - 30)
        py = random.randint(50, h - 50)
        prad = random.randint(8, 28)
        color = random.choice([(255, 200, 220), (200, 220, 255), (255, 240, 180)])
        draw.ellipse([px - prad, py - prad, px + prad, py + prad], fill=color)
        
    # Stylized anime figure silhouette
    cx = w // 2
    # Flowing hair back
    draw.ellipse([cx - 110, int(h * 0.28), cx + 110, int(h * 0.75)], fill=(32, 18, 38))
    # Left pigtail flow
    draw.polygon([(cx - 70, int(h * 0.35)), (cx - 180, int(h * 0.55)), (cx - 140, int(h * 0.72)), (cx - 60, int(h * 0.45))], fill=(38, 20, 44))
    # Right pigtail flow
    draw.polygon([(cx + 70, int(h * 0.35)), (cx + 180, int(h * 0.55)), (cx + 140, int(h * 0.72)), (cx + 60, int(h * 0.45))], fill=(38, 20, 44))
    # Shoulders and torso
    draw.polygon([(cx - 85, int(h * 0.45)), (cx + 85, int(h * 0.45)), (cx + 120, h), (cx - 120, h)], fill=(26, 14, 30))
    # Head & neck
    draw.rectangle([cx - 16, int(h * 0.38), cx + 16, int(h * 0.46)], fill=(245, 205, 195))
    draw.ellipse([cx - 45, int(h * 0.22), cx + 45, int(h * 0.40)], fill=(255, 218, 205))
    # Eyes
    draw.ellipse([cx - 30, int(h * 0.30), cx - 12, int(h * 0.34)], fill=(40, 120, 220))
    draw.ellipse([cx + 12, int(h * 0.30), cx + 30, int(h * 0.34)], fill=(40, 120, 220))
    # Hair bangs
    draw.polygon([(cx - 48, int(h * 0.22)), (cx + 48, int(h * 0.22)), (cx + 25, int(h * 0.29)), (cx, int(h * 0.27)), (cx - 25, int(h * 0.30))], fill=(38, 20, 44))
    return img

def make_miku(w=480, h=720):
    img = Image.new("RGB", (w, h), (14, 20, 32))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (10, 16, 28), (18, 55, 68))
    
    # Soundwave visualizer bars at background
    random.seed(707)
    for bx in range(20, w - 20, 16):
        bh = random.randint(40, 160)
        draw.rectangle([bx, int(h * 0.45) - bh // 2, bx + 8, int(h * 0.45) + bh // 2], fill=(24, 180, 190))
        
    cx = w // 2
    # Twin long teal braids
    draw.polygon([(cx - 40, int(h * 0.35)), (cx - 160, int(h * 0.5)), (cx - 130, h), (cx - 50, int(h * 0.5))], fill=(16, 185, 190))
    draw.polygon([(cx + 40, int(h * 0.35)), (cx + 160, int(h * 0.5)), (cx + 130, h), (cx + 50, int(h * 0.5))], fill=(16, 185, 190))
    # Head & torso silhouette
    draw.polygon([(cx - 70, int(h * 0.48)), (cx + 70, int(h * 0.48)), (cx + 90, h), (cx - 90, h)], fill=(30, 35, 48))
    draw.ellipse([cx - 40, int(h * 0.25), cx + 40, int(h * 0.41)], fill=(255, 220, 210))
    # Headset red ribbon
    draw.rectangle([cx - 44, int(h * 0.30), cx - 36, int(h * 0.38)], fill=(255, 50, 90))
    draw.rectangle([cx + 36, int(h * 0.30), cx + 44, int(h * 0.38)], fill=(255, 50, 90))
    # Teal eyes
    draw.ellipse([cx - 24, int(h * 0.32), cx - 10, int(h * 0.36)], fill=(10, 220, 220))
    draw.ellipse([cx + 10, int(h * 0.32), cx + 24, int(h * 0.36)], fill=(10, 220, 220))
    return img

def make_minimalist(w=600, h=600):
    img = Image.new("RGB", (w, h), (24, 24, 32))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (18, 20, 32), (48, 52, 75))
    
    # Geometric art
    cx, cy = w // 2, h // 2
    for r in range(180, 40, -30):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(90, 160, 255), width=3)
    draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=(255, 90, 120))
    return img

def make_retro(w=400, h=700):
    img = Image.new("RGB", (w, h), (20, 10, 30))
    draw = ImageDraw.Draw(img)
    gradient_vertical(draw, w, h, (25, 10, 40), (240, 80, 120))
    
    # Sliced retro neon sun
    sun_y = int(h * 0.42)
    draw.ellipse([w // 2 - 80, sun_y - 80, w // 2 + 80, sun_y + 80], fill=(255, 220, 50))
    for sy in range(sun_y - 20, sun_y + 80, 14):
        draw.rectangle([w // 2 - 85, sy, w // 2 + 85, sy + 4], fill=(25, 10, 40))
        
    # Perspective grid floor
    for gy in range(int(h * 0.65), h, 18):
        draw.line([(0, gy), (w, gy)], fill=(0, 230, 255), width=2)
    for gx in range(-w, w * 2, 45):
        draw.line([(w // 2, int(h * 0.65)), (gx, h)], fill=(0, 230, 255), width=1)
    return img

def save_sample(name, img, prompt, neg_prompt, steps, model="anime_diffusion_v1.5"):
    w, h = img.size
    param_text = f"{prompt}\nNegative prompt: {neg_prompt}\nSteps: {steps}, Sampler: Euler a, CFG scale: 7, Seed: 1234567, Size: {w}x{h}, Model: {model}"
    info = PngInfo()
    info.add_text("parameters", param_text)
    
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test_gallery")
    target = os.path.join(out_dir, name)
    img.save(target, "PNG", pnginfo=info)
    print(f"Saved rich artwork: {name} ({w}x{h})")

if __name__ == "__main__":
    save_sample("cyberpunk_city.png", make_cyberpunk_city(), 
                "masterpiece, cyberpunk, city, night, neon lights, highly detailed", "text, watermark, blurry", 25)
    save_sample("fantasy_landscape.png", make_fantasy_landscape(), 
                "scenery, fantasy, nature, sunset, clouds, sky, oil painting", "monochrome", 20)
    save_sample("makoto_shinkai_clouds.png", make_shinkai_clouds(), 
                "scenery, makoto shinkai, sky, clouds, sunlight, beautiful", "dark, gloomy", 24)
    save_sample("anime_portrait_girl.png", make_anime_girl(), 
                "1girl, solo, masterpiece, blue eyes, long hair, smile, portrait", "worst quality, low quality", 30)
    save_sample("miku_hatsune.png", make_miku(), 
                "hatsune miku, 1girl, solo, upper body, twin braids, glowing eyes", "lowres", 35)
    save_sample("minimalist_square.png", make_minimalist(), 
                "abstract, digital art, high resolution, geometric", "", 15)
    save_sample("retro_character.png", make_retro(), 
                "1girl, solo, standing, jacket, retro, sunglasses", "bad anatomy", 28)
    print("All rich test artworks generated successfully!")
