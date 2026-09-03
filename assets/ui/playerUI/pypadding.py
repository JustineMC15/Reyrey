from PIL import Image, ImageOps

# HP Star
img = Image.open("hpstar.png")
padded = ImageOps.expand(img, border=int(img.width * 0.3), fill=(0, 0, 0, 0))
padded.save("hpstar_glow.png")

# HP Bar
img = Image.open("hpbar.png")
padded = ImageOps.expand(img, border=int(img.width * 0.18), fill=(0, 0, 0, 0))
padded.save("hpbar_glow.png")

# HP Frame
img = Image.open("hpframe.png")
padded = ImageOps.expand(img, border=int(img.width * 0.18), fill=(0, 0, 0, 0))
padded.save("hpframe_glow.png")