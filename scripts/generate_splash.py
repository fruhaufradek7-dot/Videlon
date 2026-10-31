from pathlib import Path
import cairosvg

source = Path("assets/branding/logo.svg").read_bytes()
outputs = {
    "assets/branding/splash.png": 512,
    "assets/branding/splash_android12.png": 1152,
}
for filename, size in outputs.items():
    cairosvg.svg2png(
        bytestring=source,
        write_to=filename,
        output_width=size,
        output_height=size,
    )
    print(f"Generated {filename} ({size}x{size}) from the Videlon V mark")
