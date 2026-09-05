import colorsys
from PIL import Image

def recolor_to_perfect_ice(input_filename, output_filename):
    # 1. Open the original tileset image and enforce RGBA to preserve transparency
    img = Image.open(input_filename).convert('RGBA')
    pixels = img.load()
    width, height = img.size
    
    # 2. Process every pixel using direct mathematical curve adjustments
    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            
            # CRITICAL: If the pixel is transparent, skip it entirely.
            if a == 0:
                continue
                
            # Convert RGB (0-255) to float decimals (0.0-1.0)
            rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
            
            # Calculate actual lightness value of the original art pixel
            lightness = 0.2126 * rf + 0.7152 * gf + 0.0722 * bf

            # --- DYNAMIC COLOR EXPANSION MATRICES ---
            if lightness < 0.25:
                # DEEP SHADOWS: Shift heavily into a dark, rich navy-black abyss
                # This fixes the mud look by pulling cracks down into real darkness
                f = lightness / 0.25
                nr = 0.08 * f
                ng = 0.12 * f
                nb = 0.18 * f
            elif lightness < 0.65:
                # MIDTONES: Map the rock textures smoothly into cold slate blues
                f = (lightness - 0.25) / 0.40
                nr = 0.08 + (0.42 - 0.08) * f
                ng = 0.12 + (0.50 - 0.12) * f
                nb = 0.18 + (0.59 - 0.18) * f
            else:
                # CRISP HIGHLIGHTS: Punch the bright surfaces straight into pure frost-whites
                f = (lightness - 0.65) / 0.35
                nr = 0.42 + (0.92 - 0.42) * f
                ng = 0.50 + (0.96 - 0.50) * f
                nb = 0.59 + (1.00 - 0.59) * f

            # Prevent values from breaking out of bounds and apply clean pixel mapping
            final_r = int(max(0.0, min(1.0, nr)) * 255)
            final_g = int(max(0.0, min(1.0, ng)) * 255)
            final_b = int(max(0.0, min(1.0, nb)) * 255)

            pixels[x, y] = (final_r, final_g, final_b, a)
            
    # 3. Save directly to the new texture file name
    img.save(output_filename)
    print(f"File processed and saved successfully as: {output_filename}")

# Execute the transformation using your file names
recolor_to_perfect_ice('ATileset-Aureth.png', 'ATileset-Icefields.png')
