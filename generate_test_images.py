import struct
import zlib
import os

def create_png(filename, width, height, r, g, b, prompt="", neg_prompt="", steps=20):
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = struct.pack('>I', len(ihdr_data)) + b'IHDR' + ihdr_data + struct.pack('>I', zlib.crc32(b'IHDR' + ihdr_data))
    
    chunks = [ihdr]
    if prompt:
        param_text = f"{prompt}\nNegative prompt: {neg_prompt}\nSteps: {steps}, Sampler: Euler a, CFG scale: 7, Seed: 1234567, Size: {width}x{height}, Model: anime_diffusion_v1.5"
        text_data = b'parameters\x00' + param_text.encode('utf-8')
        text_chunk = struct.pack('>I', len(text_data)) + b'tEXt' + text_data + struct.pack('>I', zlib.crc32(b'tEXt' + text_data))
        chunks.append(text_chunk)
        
    raw_scanlines = bytearray()
    for y in range(height):
        raw_scanlines.append(0)
        for x in range(width):
            raw_scanlines.extend([
                int(r * (0.3 + 0.7 * (x / width))),
                int(g * (0.3 + 0.7 * (y / height))),
                int(b * (0.5 + 0.5 * ((x + y) / (width + height))))
            ])
    compressed_data = zlib.compress(bytes(raw_scanlines))
    idat = struct.pack('>I', len(compressed_data)) + b'IDAT' + compressed_data + struct.pack('>I', zlib.crc32(b'IDAT' + compressed_data))
    chunks.append(idat)
    
    iend = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', zlib.crc32(b'IEND'))
    chunks.append(iend)
    
    with open(filename, 'wb') as f:
        f.write(sig + b''.join(chunks))

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_gallery")
os.makedirs(out_dir, exist_ok=True)

samples = [
    ("cyberpunk_city.png", 800, 450, 40, 180, 240, 
     "masterpiece, cyberpunk, city, night, neon lights, highly detailed", "text, watermark, blurry", 25),
    ("anime_portrait_girl.png", 512, 768, 240, 80, 140, 
     "1girl, solo, masterpiece, blue eyes, long hair, smile, portrait", "worst quality, low quality", 30),
    ("fantasy_landscape.png", 900, 500, 60, 200, 90, 
     "scenery, fantasy, nature, sunset, clouds, sky, oil painting", "monochrome", 20),
    ("retro_character.png", 400, 700, 220, 160, 40, 
     "1girl, solo, standing, jacket, retro, sunglasses", "bad anatomy", 28),
    ("minimalist_square.png", 600, 600, 100, 100, 220, 
     "abstract, digital art, high resolution, geometric", "", 15),
    ("makoto_shinkai_clouds.png", 840, 480, 70, 140, 230, 
     "scenery, makoto shinkai, sky, clouds, sunlight, beautiful", "dark, gloomy", 24),
    ("miku_hatsune.png", 480, 720, 30, 220, 200, 
     "hatsune miku, 1girl, solo, upper body, twin braids, glowing eyes", "lowres", 35)
]

for name, w, h, r, g, b, prompt, neg, steps in samples:
    path = os.path.join(out_dir, name)
    create_png(path, w, h, r, g, b, prompt, neg, steps)
    print(f"Created sample: {name} ({w}x{h})")

print("All test images created successfully!")
