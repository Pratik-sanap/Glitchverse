#!/usr/bin/env python3
"""
tools/prep_sprite.py — Sprite preparation pipeline for Rift Runner (Godot 4).

Usage:
    python tools/prep_sprite.py
    python tools/prep_sprite.py --name crate --export-size 256x256
    python tools/prep_sprite.py --input assets/sprites/crate.png --output assets/art/world/crate.png --export-size 256x256

Pipeline steps:
1. Set alpha to 0 where alpha < 40 (removes faint haze).
   Crop to the bounding box of pixels with alpha > 128, plus a 2 px transparent margin.
2. Resize with LANCZOS to the EXPORT size given in the task (keep aspect ratio; do not stretch).
3. Save as assets/art/world/<name>.png (RGBA). Keep original files untouched.
4. Report final pixel size and verify transparent-margin check (outer 2px alpha == 0).
"""

import argparse
import os
import sys
from typing import Dict, Optional, Tuple
import numpy as np
from PIL import Image

# Default export sizes based on level bounding boxes and astronaut scale
DEFAULT_EXPORT_SIZES: Dict[str, Tuple[int, int]] = {
    "crate": (112, 112),
    "exit": (560, 224),
    "exit_ship": (560, 224),
    "oxygen": (128, 260),
    "energy_cell": (60, 88),
    "parts": (192, 112),
    "ship_part": (192, 112),
    "rift": (320, 320),
    "portal": (320, 320),
    "spike": (330, 128),
    "spike_tile": (330, 128),
}


def find_source_image(name: str) -> str:
    """Look for source PNG in assets/art/ or assets/sprites/."""
    names_to_check = [name]
    if name in ("energy_cell", "oxygen"):
        names_to_check.extend(["oxygen", "energy_cell", "oxygen_cylinder"])
    elif name in ("ship_part", "parts"):
        names_to_check.extend(["parts", "ship_part", "part"])
    elif name in ("exit_ship", "exit"):
        names_to_check.extend(["exit", "exit_ship", "spaceship", "ship"])
    elif name in ("portal", "rift"):
        names_to_check.extend(["rift", "portal", "dimensional_rift"])
    elif name in ("spike_tile", "spike"):
        names_to_check.extend(["spike", "spike_tile", "spikes"])
    
    candidates = []
    for n in names_to_check:
        candidates.extend([
            os.path.join("assets", "art", f"{n}.png"),
            os.path.join("assets", "sprites", f"{n}.png"),
            os.path.join("assets", "art", "world", f"{n}.png"),
        ])
    for p in candidates:
        if os.path.isfile(p):
            return p
    raise FileNotFoundError(f"Could not locate source image for '{name}'. Checked: {candidates}")


def check_transparent_margin(img: Image.Image, margin: int = 2) -> Tuple[bool, Dict[str, int]]:
    """Verify that all outer boundary pixels within `margin` px have alpha == 0."""
    arr = np.array(img)
    if arr.ndim != 3 or arr.shape[2] != 4:
        raise ValueError("Image must be RGBA to check transparent margin.")
    alpha = arr[:, :, 3]
    h, w = alpha.shape

    m = min(margin, h // 2, w // 2)
    top_max = int(alpha[0:m, :].max())
    bottom_max = int(alpha[-m:, :].max())
    left_max = int(alpha[:, 0:m].max())
    right_max = int(alpha[:, -m:].max())

    passed = (top_max == 0 and bottom_max == 0 and left_max == 0 and right_max == 0)
    details = {
        "top_max_alpha": top_max,
        "bottom_max_alpha": bottom_max,
        "left_max_alpha": left_max,
        "right_max_alpha": right_max,
    }
    return passed, details


def prep_sprite(src_path: str, dst_path: str, export_size: Tuple[int, int]) -> Tuple[Tuple[int, int], bool, Dict[str, int]]:
    """
    Process a single sprite according to pipeline specifications:
    1. Set alpha to 0 where alpha < 40, crop to bbox of alpha > 128 + 2px transparent margin.
    2. Resize with LANCZOS to export_size (keep aspect ratio; no stretching).
    3. Save as RGBA PNG without touching the original source.
    """
    # Load and ensure RGBA
    orig = Image.open(src_path).convert("RGBA")

    # 1a. Set alpha to 0 where alpha < 40 (remove faint haze)
    r, g, b, a = orig.split()
    a_arr = np.array(a)
    a_arr[a_arr < 40] = 0
    cleaned_alpha = Image.fromarray(a_arr)
    orig.putalpha(cleaned_alpha)

    # 1b. Find bounding box of pixels with alpha > 128
    mask = cleaned_alpha.point(lambda v: 255 if v > 128 else 0)
    bbox = mask.getbbox()
    if not bbox:
        raise ValueError(f"No pixels with alpha > 128 found in '{src_path}'.")

    core = orig.crop(bbox)

    # 2. Resize with LANCZOS to the EXPORT size (keep aspect ratio; do not stretch)
    target_w, target_h = export_size
    margin = 2

    # Reserve the 2px transparent margin in the target bounds
    avail_w = max(1, target_w - margin * 2)
    avail_h = max(1, target_h - margin * 2)

    scale = min(avail_w / core.width, avail_h / core.height)
    new_w = max(1, int(round(core.width * scale)))
    new_h = max(1, int(round(core.height * scale)))

    resized_core = core.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Construct final image with exact 2px transparent margin (centered on target bounds)
    final_w = target_w if target_w >= new_w + margin * 2 else new_w + margin * 2
    final_h = target_h if target_h >= new_h + margin * 2 else new_h + margin * 2
    final_img = Image.new("RGBA", (final_w, final_h), (0, 0, 0, 0))
    offset_x = (final_w - new_w) // 2
    offset_y = (final_h - new_h) // 2
    final_img.paste(resized_core, (offset_x, offset_y))

    # 3. Save as assets/art/world/<name>.png (RGBA)
    os.makedirs(os.path.dirname(os.path.abspath(dst_path)), exist_ok=True)
    final_img.save(dst_path, format="PNG")

    # 4. Generate .import file with Mipmaps off
    write_godot_import(dst_path)

    # 5. Transparent-margin check
    passed, details = check_transparent_margin(final_img, margin=margin)

    return (final_w, final_h), passed, details


def write_godot_import(png_path: str) -> None:
    """Generate Godot 4 .import file with Mipmaps off."""
    import_path = f"{png_path}.import"
    # Convert path to Godot res:// format
    norm_path = png_path.replace("\\", "/")
    if not norm_path.startswith("res://"):
        norm_path = f"res://{norm_path}"

    content = f"""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{norm_path}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    with open(import_path, "w", encoding="utf-8") as f:
        f.write(content)



def main() -> None:
    parser = argparse.ArgumentParser(description="Prep sprites for Rift Runner.")
    parser.add_argument("--name", type=str, help="Sprite name (e.g. crate, exit, monster, etc.)")
    parser.add_argument("--input", type=str, help="Explicit input path")
    parser.add_argument("--output", type=str, help="Explicit output path")
    parser.add_argument("--export-size", type=str, help="Export size formatted as WxH, e.g. 256x256")
    parser.add_argument("--all", action="store_true", help="Process all default sprites")

    args = parser.parse_args()

    # Determine tasks
    tasks = []
    if args.input and args.output:
        size = (256, 256)
        if args.export_size:
            w, h = map(int, args.export_size.lower().split("x"))
            size = (w, h)
        tasks.append((args.input, args.output, size, os.path.basename(args.output)))
    elif args.name:
        name = args.name.lower()
        src = args.input if args.input else find_source_image(name)
        dst = args.output if args.output else os.path.join("assets", "art", "world", f"{name}.png")
        if args.export_size:
            w, h = map(int, args.export_size.lower().split("x"))
            size = (w, h)
        else:
            size = DEFAULT_EXPORT_SIZES.get(name, (256, 256))
        tasks.append((src, dst, size, name))
    else:
        # Default: process all standard sprites
        for name, size in DEFAULT_EXPORT_SIZES.items():
            src = find_source_image(name)
            dst = os.path.join("assets", "art", "world", f"{name}.png")
            tasks.append((src, dst, size, name))

    print("=" * 70)
    print("RIFT RUNNER — SPRITE PREPARATION PIPELINE")
    print("=" * 70)

    results = []
    all_passed = True
    for src, dst, size, label in tasks:
        final_size, passed, details = prep_sprite(src, dst, size)
        if not passed:
            all_passed = False
        status_str = "PASSED" if passed else "FAILED"
        print(f"[{status_str}] {label:8s} | Source: {src} -> Destination: {dst}")
        print(f"         Export Bound: {size[0]}x{size[1]} | Final Pixel Size: {final_size[0]}x{final_size[1]}")
        print(f"         Transparent Margin Check: {status_str} (top={details['top_max_alpha']}, "
              f"bottom={details['bottom_max_alpha']}, left={details['left_max_alpha']}, right={details['right_max_alpha']})")
        print("-" * 70)
        results.append({
            "name": label,
            "final_size": final_size,
            "passed": passed,
            "details": details
        })

    print(f"\nCompleted processing {len(results)} sprite(s). All checks passed: {all_passed}")
    if not all_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
