from PIL import Image
import os

filename = input("Enter the exact image filename: ").strip()

try:
    img = Image.open(filename)

    new_size = (img.width // 2, img.height // 2)

    resized = img.resize(new_size, Image.Resampling.NEAREST)

    name, ext = os.path.splitext(filename)
    output_file = f"{name}_50{ext}"

    resized.save(output_file)

    print(f"\nDone!")
    print(f"Original: {img.size}")
    print(f"Resized:  {resized.size}")
    print(f"Saved as: {output_file}")

except FileNotFoundError:
    print(f"\nFile not found: {filename}")
except Exception as e:
    print(f"\nError: {e}")

input("\nPress Enter to exit...")