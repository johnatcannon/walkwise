#!/usr/bin/env python3
"""
Generate Apple App Store iPhone portrait screenshot sizes from a set of source PNG/JPG screenshots.

Input:
  walkwise/app_store_screenshots/source/
    - 01.png, 02.png, ... (any names; will be processed in sorted order)

Output:
  walkwise/app_store_screenshots/output/iphone_6.9/ (1290x2796)
  walkwise/app_store_screenshots/output/iphone_6.5/ (1242x2688)

Approach:
  - Preserve aspect ratio
  - Fit-to-height (with small margins), then center on a solid background
  - No cropping by default (avoid cutting off status bars)
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass(frozen=True)
class Target:
    name: str
    width: int
    height: int


TARGETS: list[Target] = [
    Target(name="iphone_6.9", width=1290, height=2796),
    Target(name="iphone_6.5", width=1242, height=2688),
]


def _load_images(source_dir: Path) -> list[Path]:
    exts = {".png", ".jpg", ".jpeg"}
    paths = [p for p in sorted(source_dir.iterdir()) if p.suffix.lower() in exts and p.is_file()]
    return paths


def _composite_on_canvas(img: Image.Image, target: Target) -> Image.Image:
    # Canvas background (white) - simplest, review-friendly.
    canvas = Image.new("RGB", (target.width, target.height), color=(255, 255, 255))

    # Scale image to fit within canvas with margins.
    margin = int(target.height * 0.03)  # ~3% top/bottom
    max_w = target.width - 2 * margin
    max_h = target.height - 2 * margin

    src_w, src_h = img.size
    scale = min(max_w / src_w, max_h / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))

    resized = img.resize((new_w, new_h), Image.LANCZOS)
    x = (target.width - new_w) // 2
    y = (target.height - new_h) // 2
    canvas.paste(resized, (x, y))
    return canvas


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    base_dir = repo_root / "app_store_screenshots"
    source_dir = base_dir / "source"
    out_dir = base_dir / "output"

    source_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    src_paths = _load_images(source_dir)
    if not src_paths:
        print(f"[generate_app_store_screenshots] No images found in: {source_dir}")
        print("Put your 6 portrait screenshots (png/jpg) into that folder, then re-run.")
        return 2

    print(f"[generate_app_store_screenshots] Found {len(src_paths)} source image(s).")

    for t in TARGETS:
        t_out = out_dir / t.name
        t_out.mkdir(parents=True, exist_ok=True)

        for idx, path in enumerate(src_paths, start=1):
            with Image.open(path) as im:
                im = im.convert("RGB")
                composed = _composite_on_canvas(im, t)
                out_name = f"{idx:02d}_{t.width}x{t.height}.png"
                out_path = t_out / out_name
                composed.save(out_path, format="PNG", optimize=True)
                print(f"  - {t.name}: {out_path.relative_to(repo_root)}")

    print("[generate_app_store_screenshots] Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


