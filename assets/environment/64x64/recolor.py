import colorsys
from PIL import Image

def recolor_elven_forest(input_filename, output_filename):
    # 1. Open the original tileset image and enforce RGBA to preserve transparency
    img = Image.open(input_filename).convert('RGBA')
    pixels = img.load()
    width, height = img.size
    
    # Helper to prevent color values from breaking boundaries
    def clip(val):
        return max(0.0, min(1.0, val))

    # 2. Iterate through every pixel in the 1024x1024 grid
    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            
            # CRITICAL: If the pixel is transparent, skip it completely.
            # Your alpha channel remains completely untouched for your atlas compiler.
            if a == 0:
                continue
            
            # Convert the RGB values (0-255) to HSV decimals (0.0-1.0)
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            
            # 3. Identify and isolate the brown dirt vs the green grass
            # Brown/earthy hues typically live between 0.05 and 0.18
            if 0.05 <= h <= 0.18:
                h = 0.40           # Shift dirt hue to a dark, deep pine green
                s = clip(s * 0.7)  # Increased saturation slightly so it doesn't look too grey
                v = clip(v * 0.65) # BOOSTED: Was 0.35, now 0.65 to bring back visibility to the dirt textures
                
            # Grass hues typically live between 0.18 and 0.45
            elif 0.18 < h <= 0.45:
                h = 0.35           # Shift grass to a vibrant, clean elven moss green
                s = clip(s * 1.3)  # Keep the vibrancy high so it feels lush
                v = clip(v * 0.95) # BOOSTED: Was 0.6, now 0.95 to keep the grass bright and readable
                
            else:
                # Catch-all for any transitional edge pixels to keep them dark but visible
                v = clip(v * 0.8)

            # Convert the adjusted values back to standard RGB
            new_r, new_g, new_b = colorsys.hsv_to_rgb(h, s, v)
            
            # Overwrite the pixel on our working copy while maintaining original alpha 'a'
            pixels[x, y] = (int(new_r * 255), int(new_g * 255), int(new_b * 255), a)
            
    # 4. Save to a brand-new file. Your original file remains untouched.
    img.save(output_filename)
    print(f"Success! Perfect alpha transparency preserved. File saved as: {output_filename}")

# Run the function using your exact file name
recolor_elven_forest('MONTAGE_aureth_64.png', 'dark_elven_forest_tileset.png')
