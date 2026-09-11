from PIL import Image
import colorsys

def convert_to_dark_high_contrast_fixed(input_filename, output_filename):
    # Open the tileset image and maintain its alpha layer
    img = Image.open(input_filename).convert("RGBA")
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            
            # Skip transparent spaces
            if a == 0:
                continue
                
            # Normalize to 0.0 - 1.0 float values
            r_norm, g_norm, b_norm = r / 255.0, g / 255.0, b / 255.0
            h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
            
            # Select only the blue/purple tileset palette hue range
            if 0.55 <= h <= 0.82:
                # 1. Hue: Deep gothic brown tone
                new_h = 0.07 
                
                # 2. Saturation: Boost slightly to keep the color visible when dark
                new_s = min(s * 1.25, 1.0)
                
                # 3. Safe Contrast & Darkness: 
                # This drops brightness safely while widening the gap between light and dark pixels.
                # It preserves details without crushing everything to 0 (pure black).
                new_v = (v ** 1.5) * 0.55
                
                # Reassemble the RGB pixels
                new_r, new_g, new_b = colorsys.hsv_to_rgb(new_h, new_s, new_v)
                pixels[x, y] = (int(new_r * 255), int(new_g * 255), int(new_b * 255), a)

    # Output your dark fantasy cathedral asset pack
    img.save(output_filename)
    print(f"Fixed transformation complete! Saved to {output_filename}")

# Run execution using your exact file naming configuration
convert_to_dark_high_contrast_fixed("Dungeon Tile Set_64.png", "Gothic_HighContrast_Fixed.png")
