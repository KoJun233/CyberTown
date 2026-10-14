"""Extract the supplied art and export directional Aseprite animations.

Run with Python + Pillow. Godot needs only the resulting PNGs/JSON, not Python.
"""
import argparse
import io
import json
import random
import struct
import zipfile
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "client/assets/sunnyside"


def read_aseprite(path):
    data = path.read_bytes()
    count, width, height, depth = struct.unpack_from("<4H", data, 6)
    if depth != 32:
        raise ValueError("Expected RGBA Aseprite source")
    layers, frames, tags = [], [], {}
    offset = 128
    for frame_index in range(count):
        size, magic, chunks, duration = struct.unpack_from("<I3H", data, offset)
        if magic != 0xF1FA:
            raise ValueError("Invalid Aseprite frame")
        pos = offset + 16
        cels = {}
        for _ in range(chunks):
            chunk_size, kind = struct.unpack_from("<IH", data, pos)
            p = data[pos + 6:pos + chunk_size]
            if kind == 0x2004:
                name_size = struct.unpack_from("<H", p, 16)[0]
                layers.append(p[18:18 + name_size].decode("utf-8"))
            elif kind == 0x2005:
                layer, x, y, opacity, cel_type = struct.unpack_from("<HhhBH", p)
                if cel_type == 1:
                    linked = struct.unpack_from("<H", p, 16)[0]
                    source = frames[linked]["cels"].get(layer)
                    if source:
                        cels[layer] = (source[0], x, y, opacity)
                elif cel_type in (0, 2):
                    w, h = struct.unpack_from("<HH", p, 16)
                    pixels = p[20:] if cel_type == 0 else zlib.decompress(p[20:])
                    if w and h:
                        cels[layer] = (Image.frombytes("RGBA", (w, h), pixels), x, y, opacity)
            elif kind == 0x2018:
                tag_count = struct.unpack_from("<H", p)[0]
                tp = 10
                for _ in range(tag_count):
                    first, last = struct.unpack_from("<HH", p, tp)
                    name_size = struct.unpack_from("<H", p, tp + 17)[0]
                    name = p[tp + 19:tp + 19 + name_size].decode("utf-8")
                    tags[name] = (first, last)
                    tp += 19 + name_size
            pos += chunk_size
        frames.append({"cels": cels, "duration": duration})
        offset += size
    return layers, frames, tags, (width, height)


def export_characters(path):
    layers, frames, tags, canvas_size = read_aseprite(path)
    if canvas_size != (96, 64):
        raise ValueError("Expected 96x64 character frames")
    names = ["bowl hair", "short hair", "mop hair", "spikey hair", "curly hair", "long hair"]
    body_layer = layers.index("base")
    metadata = {}
    for variant, hair in enumerate(names):
        rows = []
        for action in ("idle", "walk"):
            for direction in ("s", "se", "ne", "n"):
                tag = action + "-" + direction
                first, last = tags[tag]
                if not 0 < last - first + 1 <= 8:
                    raise ValueError(f"Unsupported frame count for {tag}")
                row = len(rows)
                images = []
                for index in range(first, last + 1):
                    image = Image.new("RGBA", canvas_size)
                    body = frames[index]["cels"].get(body_layer)
                    if body is None or body[0].getbbox() is None:
                        raise ValueError(f"Missing body in {tag} frame {index}")
                    hair_layer = layers.index(hair)
                    hairstyle = frames[index]["cels"].get(hair_layer)
                    if hairstyle is None:
                        # The directional walk tags contain only bowl hair.
                        # Preserve each other hairstyle using its matching idle
                        # direction, aligned to this frame's moving head/body.
                        idle_first, idle_last = tags["idle-" + direction]
                        reference = frames[idle_first + (index - first) % (idle_last - idle_first + 1)]["cels"]
                        reference_body = reference[body_layer]
                        cel, x, y, opacity = reference[hair_layer]
                        hairstyle = (cel, x + body[1] - reference_body[1], y + body[2] - reference_body[2], opacity)
                    if hairstyle[0].getbbox() is None:
                        raise ValueError(f"Missing {hair} in {tag} frame {index}")
                    for cel, x, y, opacity in (body, hairstyle):
                        cel = cel.copy()
                        if opacity != 255:
                            cel.putalpha(cel.getchannel("A").point(lambda a: a * opacity // 255))
                        image.alpha_composite(cel, (x, y))
                    images.append(image)
                rows.append(images)
                if variant == 0:
                    metadata[tag] = {"row": row, "frames": len(images), "seconds": frames[first]["duration"] / 1000}
        sheet = Image.new("RGBA", (canvas_size[0] * 8, canvas_size[1] * 8))
        for row, images in enumerate(rows):
            for col, image in enumerate(images):
                sheet.alpha_composite(image, (col * canvas_size[0], row * canvas_size[1]))
        sheet.save(OUT / f"resident_{variant}.png")
    (OUT / "animations.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print("Character pivot reference:", rows[0][0].getbbox())


def export_world():
    atlas = Image.open(OUT / "Tileset/spr_tileset_sunnysideworld_16px.png").convert("RGBA")
    ground = Image.new("RGBA", (640, 360), "#61be48")
    rng = random.Random(218)

    def fill(area, tiles):
        x, y, w, h = area
        for py in range(y, y + h, 16):
            for px in range(x, x + w, 16):
                tx, ty = rng.choice(tiles)
                ground.alpha_composite(atlas.crop((tx, ty, tx + 16, ty + 16)), (px, py))

    fill((0, 0, 640, 368), [(16, 16)] * 12 + [(32, 32), (48, 48), (16, 48)])
    dirt = [(48, 16)] * 12 + [(144, 112), (176, 112)]
    fill((0, 168, 640, 48), dirt)
    for x, y, w, h in [(80, 100, 32, 80), (288, 96, 48, 80), (432, 112, 32, 64), (288, 208, 48, 144)]:
        fill((x, y, w, h), dirt)
    # River and bridge share their bounds with client-side navigation.
    fill((528, 0, 64, 368), [(192, 320), (208, 320)])
    d = ImageDraw.Draw(ground)
    d.rectangle((524, 0, 527, 359), fill="#367f57")
    d.rectangle((592, 0, 595, 359), fill="#367f57")
    d.rectangle((520, 184, 599, 224), fill="#c99561")
    for x in range(520, 600, 8):
        d.line((x, 184, x, 224), fill="#a47050", width=2)
    d.rectangle((520, 181, 599, 184), fill="#725344")
    d.rectangle((520, 223, 599, 226), fill="#725344")
    # A small decorative garden; it is not a farming minigame.
    d.rectangle((48, 254, 183, 313), fill="#805440")
    for row in range(3):
        d.rectangle((52, 258 + row * 18, 179, 269 + row * 18), fill="#68483e")
        for col in range(8):
            crop = Image.open(OUT / ("Elements/Crops/carrot_05.png" if row % 2 else "Elements/Crops/cabbage_05.png")).convert("RGBA")
            ground.alpha_composite(crop, (54 + col * 16, 253 + row * 18))
    for x in range(44, 188, 16):
        for y in (246, 316):
            ground.alpha_composite(atlas.crop((616, 16, 632, 32)), (x, y))
    for x, y in [(212, 140), (370, 148), (464, 274), (244, 300), (605, 120), (32, 218)]:
        ground.alpha_composite(atlas.crop((480, 32, 496, 48)), (x, y))
    ground.save(OUT / "ground.png")

    # Assemble cottage facades from original timber, door and roof tiles.
    for index, roof_y in enumerate((160, 288, 416)):
        house = Image.new("RGBA", (128, 100))
        hd = ImageDraw.Draw(house)
        hd.rectangle((12, 46, 115, 96), fill="#a66d50")
        for y in range(48, 96, 16):
            for x in range(16, 112, 16):
                house.alpha_composite(atlas.crop((48, 160, 64, 176)), (x, y))
        # Assemble an isolated gable from roof shingles; the atlas includes
        # modular edges which must not be pasted as a complete building.
        roof = Image.new("RGBA", (128, 58))
        roof_tile = atlas.crop((256, 176, 272, 192))
        # Keep the same native shingle pattern in each supplied roof palette.
        if index:
            for py in range(16):
                for px in range(16):
                    r, g, b, alpha = roof_tile.getpixel((px, py))
                    color = (int(g * .47 + 30), int(g * .77 + 26), int(g * .27 + 15), alpha) if index == 1 else (min(255, int(g * 1.1 + 20)), int(g * .67 + 28), int(g * .28 + 10), alpha)
                    roof_tile.putpixel((px, py), color)
        for y in range(0, 58, 16):
            for x in range(0, 128, 16):
                roof.alpha_composite(roof_tile, (x, y))
        mask = Image.new("L", roof.size)
        ImageDraw.Draw(mask).polygon([(0, 42), (64, 0), (127, 42), (127, 56), (0, 56)], fill=255)
        roof.putalpha(mask)
        house.alpha_composite(roof, (0, 0))
        hd.line([(0, 43), (64, 2), (127, 43)], fill="#875a45", width=5)
        hd.line([(1, 46), (64, 5), (126, 46)], fill="#dfab77", width=2)
        hd.polygon([(20, 47), (64, 20), (108, 47), (108, 58), (20, 58)], fill="#b88058")
        for y in range(40, 59, 6):
            hd.line((42 - (y - 40), y, 86 + (y - 40), y), fill="#d5a36e", width=2)
        hd.rectangle((58, 33, 70, 44), fill="#6d5347")
        hd.rectangle((60, 35, 68, 42), fill="#addec7")
        for x in (22, 85):
            hd.rectangle((x, 64, x + 17, 80), fill="#654b48")
            hd.rectangle((x + 2, 66, x + 15, 78), fill="#a9e7db")
            hd.line((x + 8, 66, x + 8, 78), fill="#725344", width=2)
        hd.rectangle((53, 65, 73, 96), fill="#654b48")
        hd.rectangle((56, 68, 70, 94), fill="#89604f")
        hd.rectangle((66, 81, 68, 83), fill="#e6c36e")
        hd.rectangle((47, 96, 79, 99), fill="#dfb17d")
        house.save(OUT / f"house_{index}.png")
    # Useful props extracted from the tileset, kept at their native scale.
    for name, box in {"well": (640, 304, 672, 352), "bench": (704, 192, 768, 224), "notice": (800, 560, 832, 592)}.items():
        atlas.crop(box).save(OUT / (name + ".png"))
    mill = Image.new("RGBA", (56, 92))
    brick = atlas.crop((16, 256, 32, 272))
    for y in range(0, 92, 16):
        for x in range(0, 56, 16):
            mill.alpha_composite(brick, (x, y))
    mask = Image.new("L", mill.size)
    ImageDraw.Draw(mask).polygon([(18, 0), (38, 0), (51, 87), (5, 87)], fill=255)
    mill.putalpha(mask)
    md = ImageDraw.Draw(mill)
    md.rectangle((18, 63, 37, 87), fill="#785544")
    md.rectangle((22, 67, 34, 86), fill="#aa7751")
    md.rectangle((22, 26, 33, 42), fill="#a7dbd6")
    md.rectangle((3, 88, 53, 91), fill="#bd9063")
    mill.save(OUT / "mill_base.png")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", type=Path, default=Path("E:/GoogleDownload/Sunnyside_World_ASSET_PACK_V2.1.zip"))
    parser.add_argument("--character", type=Path, default=Path("E:/GoogleDownload/sunnyside_world_chatacter_anim_human_v1.0.aseprite"))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.pack) as archive:
        prefix = next(n.split("Tileset/")[0] for n in archive.namelist() if n.endswith("spr_tileset_sunnysideworld_16px.png") and "Gamemaker" not in n)
        for name in archive.namelist():
            if not name.startswith(prefix) or not name.endswith(".png"):
                continue
            relative = name[len(prefix):]
            if not relative.startswith(("UI/", "Elements/", "Tileset/")):
                continue
            destination = OUT / relative
            if not destination.resolve().is_relative_to(OUT.resolve()):
                raise ValueError("Asset path escapes the output directory")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(name))
        # Reassemble the supplied nine-slice pieces without resampling.
        panel = Image.new("RGBA", (9, 9))
        for y, row in enumerate((("tl", "tc", "tr"), ("lc", "c", "rc"), ("bl", "bc", "br"))):
            for x, suffix in enumerate(row):
                piece = Image.open(io.BytesIO(archive.read(prefix + f"UI/9slice_box_white/w_box_9slice_{suffix}.png"))).convert("RGBA")
                panel.alpha_composite(piece, (x * 3, y * 3))
        panel.save(OUT / "panel.png")
    export_characters(args.character)
    export_world()
    print("Prepared Sunnyside assets in", OUT)


if __name__ == "__main__":
    main()
