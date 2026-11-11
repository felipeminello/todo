"""Turns what capture.py saved in build/store_media/<device>/ into App Store
and Google Play media, in build/store_media/final/ (out of git: the videos
are large, and everything here can be made again):

- ios-1284x2778/: iPhone 6.5" PNGs (RGB), with a caption and a device frame;
  previews/ has the 886 × 1920 H.264 videos, 30 fps, with a silent stereo
  track;
- ipad-2064x2752/: iPad 13" PNGs, the same way; previews/ at 1200 × 1600;
- macos-desktop-2880x1800/: 2880 × 1800 PNGs, with the app in a window;
- macos-previews-1920x1080/: the Mac videos, the app's window over the same
  background;
- android-1080x1920/: 1080 × 1920 PNGs (9:16, for the Play phone
  screenshots), with a caption and a phone frame;
- android-graphics/: the 1024 × 500 feature graphic and the 512 × 512 icon
  the Play listing asks for.

Needs Pillow and ffmpeg:
    python3 tool/store_media/compose.py [iphone|ipad|mac|android ...]
(every device that was captured, by default).
"""

import dataclasses
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'build' / 'store_media'
OUT = SOURCE / 'final'

FONT = '/System/Library/Fonts/SFNS.ttf'


@dataclasses.dataclass
class Device:
    key: str
    name: str
    folder: str
    size: tuple
    screen_width: int
    bezel: int
    title_size: int
    subtitle_size: int
    bottom_margin: int
    # iPadOS draws a window resize handle inside this box, which full screen
    # apps don't have; its shape is taken from [handle_reference], a capture
    # with a plain background there. None when there is nothing to erase.
    handle: tuple = None
    handle_reference: str = None
    # The previews' size, or None for no previews.
    preview_size: tuple = None
    # Where the sign-in screenshot says the tasks are.
    devices: str = 'iPhone, iPad, Mac, Android e Windows'
    # Screens drawn off screen have no mask from the simulator: the display's
    # rounded corners (radius in screen pixels) and the camera's punch hole
    # are drawn instead.
    corner_radius: int = None
    camera: bool = False


MAC_SIZE = (2880, 1800)
MAC_TITLE_BAR = 56

DEVICES = {
    'iphone': Device('iphone', 'iPhone', 'ios-1284x2778', (1284, 2778),
                     screen_width=924, bezel=26, title_size=104,
                     subtitle_size=50, bottom_margin=110,
                     preview_size=(886, 1920)),
    'ipad': Device('ipad', 'iPad', 'ipad-2064x2752', (2064, 2752),
                   screen_width=1440, bezel=38, title_size=140,
                   subtitle_size=66, bottom_margin=120,
                   handle=(2004, 2692, 2058, 2748),
                   handle_reference='01_linha_do_tempo',
                   preview_size=(1200, 1600)),
    'android': Device('android', 'celular', 'android-1080x1920', (1080, 1920),
                      screen_width=640, bezel=18, title_size=78,
                      subtitle_size=38, bottom_margin=64,
                      devices='Celular, tablet e computador',
                      corner_radius=96, camera=True),
}

# In store order: captured screen, headline, subtitle.
SCREENSHOTS = [
    ('01_linha_do_tempo', 'Sem data no topo,\no resto na linha do tempo',
     'Hoje e as atrasadas sempre em destaque'),
    ('02_detalhes', 'Tudo o que a\ntarefa precisa',
     'Listas e links que abrem com um toque'),
    ('03_nova_tarefa', 'Data? Só se\nvocê quiser',
     'Título, descrição e, se precisar, o dia'),
    ('04_concluidas', 'Marcou,\nconcluiu',
     'As concluídas ficam guardadas à parte'),
    ('05_escuro', 'Também no\nmodo escuro',
     'Segue o tema do seu {device}'),
    ('06_entrar', 'Suas tarefas em\ntodos os aparelhos',
     '{devices}'),
]

# The Mac screenshots show the desktop layout (the list beside the editing
# panel, the details in place of the list). They come from the `mac` scene.
MAC_SCREENSHOTS = [
    ('01_paineis', 'A lista e a edição, lado a lado',
     'Crie e edite tarefas sem sair da linha do tempo'),
    ('02_detalhes', 'Os detalhes no lugar da lista',
     'Listas e links na descrição, e Esc volta para as tarefas'),
    ('03_editar', 'Um clique e a tarefa está no painel',
     'Mude o título, a descrição ou a data ali mesmo'),
    ('04_escuro', 'Também no modo escuro',
     'Segue o tema do seu Mac'),
    ('05_entrar', 'Suas tarefas em todos os aparelhos',
     'Mac, iPhone, iPad, Android e Windows'),
]

# Recordings, and the name of each preview.
PREVIEWS = [
    ('preview_1_organize', '01_organize'),
    ('preview_2_dia_a_dia', '02_dia_a_dia'),
]

# The icon's purple.
TOP, BOTTOM = (132, 96, 207), (42, 17, 103)
GLOW = (210, 196, 241)
SHADOW = (18, 6, 48)
SUBTITLE = (236, 229, 251)


def font(size, weight, optical):
    f = ImageFont.truetype(FONT, size)
    # Axes: width, optical size, grade, weight.
    f.set_variation_by_axes([100, optical, 400, weight])
    return f


def fitting_font(draw, text, size, max_width):
    """The subtitle's font, a little smaller when [text] would not fit."""
    while True:
        f = font(size, 500, 28)
        box = draw.textbbox((0, 0), text, font=f)
        if box[2] - box[0] <= max_width or size <= 20:
            return f
        size -= 2


def background(size):
    width, height = size
    gradient = Image.linear_gradient('L').resize(size)
    image = Image.composite(Image.new('RGB', size, BOTTOM),
                            Image.new('RGB', size, TOP), gradient)
    # Soft light behind the caption.
    glow = Image.new('L', size, 0)
    ImageDraw.Draw(glow).ellipse(
        (-width * 0.3, -height * 0.25, width * 1.3, height * 0.3), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    return Image.composite(Image.new('RGB', size, GLOW), image, glow)


def load_screen(device, name, handle):
    """The captured screen, as RGB, and the display's shape as a mask."""
    screen = Image.open(SOURCE / device.key / 'raw' / f'{name}.png')
    screen = screen.convert('RGB')
    if handle:
        erase(screen, handle)
    if device.corner_radius:
        return drawn_display(device, screen)
    mask = Image.open(SOURCE / device.key / 'masked' / f'{name}.png')
    return screen, mask.getchannel('A')


def drawn_display(device, screen):
    """A display with rounded corners and, at the top, the camera's punch
    hole, for screens that did not come from a simulator."""
    mask = Image.new('L', screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen.width - 1, screen.height - 1), device.corner_radius,
        fill=255)
    if device.camera:
        # Centered in the status bar, as on most Android phones.
        radius, center = 20, (screen.width // 2, 36)
        ImageDraw.Draw(screen).ellipse(
            (center[0] - radius, center[1] - radius,
             center[0] + radius, center[1] + radius), fill=(8, 8, 10))
    return screen, mask


def handle_pixels(device):
    """The resize handle's pixels, with a margin for its antialiasing."""
    reference = Image.open(
        SOURCE / device.key / 'raw' / f'{device.handle_reference}.png',
    ).convert('RGB')
    left, top, right, bottom = device.handle
    plain = reference.getpixel((left, top))
    found = [(x, y) for x in range(left, right) for y in range(top, bottom)
             if sum(abs(a - b) for a, b in
                    zip(reference.getpixel((x, y)), plain)) > 6]
    return sorted({(x + dx, y + dy) for x, y in found
                   for dx in range(-2, 3) for dy in range(-2, 3)})


def erase(image, pixels):
    """Fills [pixels] from their surroundings, by repeatedly averaging each
    one's neighbors, which carries the soft shadows around them through."""
    image_pixels = image.load()
    # In floats: rounding every step would stall short of the background.
    values = {pixel: image_pixels[pixel] for pixel in pixels}

    def value(pixel):
        return values[pixel] if pixel in values else image_pixels[pixel]

    for _ in range(500):
        for x, y in pixels:
            neighbors = (value((x - 1, y)), value((x + 1, y)),
                         value((x, y - 1)), value((x, y + 1)))
            values[x, y] = tuple(sum(c) / 4 for c in zip(*neighbors))
    for pixel, color in values.items():
        image_pixels[pixel] = tuple(round(c) for c in color)


def framed(device, screen, mask):
    """[screen] inside a device frame shaped after [mask]."""
    width = device.screen_width
    scale = width / screen.width
    size = (width, round(screen.height * scale))
    screen = screen.convert('RGBA').resize(size, Image.LANCZOS)
    screen.putalpha(mask.resize(size, Image.LANCZOS))
    # Corners are rounder than a circle: the mask reaches the top edge a
    # little further in than the matching radius.
    corner = next(x for x in range(mask.width) if mask.getpixel((x, 0)) > 128)
    radius = round(corner * 0.89 * scale)
    bezel = device.bezel
    outer = (size[0] + 2 * bezel, size[1] + 2 * bezel)
    frame = Image.new('RGBA', outer, (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle((0, 0, outer[0] - 1, outer[1] - 1),
                           radius + bezel, fill=(58, 58, 70, 255))
    draw.rounded_rectangle((4, 4, outer[0] - 5, outer[1] - 5),
                           radius + bezel - 4, fill=(10, 10, 14, 255))
    frame.alpha_composite(screen, (bezel, bezel))
    return frame, radius + bezel


def screenshot(device, screen, mask, headline, subtitle):
    size = device.size
    width, height = size
    image = background(size)

    frame, radius = framed(device, screen, mask)
    top = height - device.bottom_margin - frame.height
    left = (width - frame.width) // 2

    shadow = Image.new('L', size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left + 10, top + 40, left + frame.width - 10,
         top + frame.height + 20), radius, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    image = Image.composite(Image.new('RGB', size, SHADOW), image, shadow)
    image.paste(frame, (left, top), frame)

    draw = ImageDraw.Draw(image)
    title_font = font(device.title_size, 700, 96)
    subtitle_font = fitting_font(draw, subtitle, device.subtitle_size,
                                 width * 0.88)
    spacing = round(device.title_size * 0.17)
    gap = round(device.title_size * 0.35)
    title_box = draw.multiline_textbbox((0, 0), headline, font=title_font,
                                        spacing=spacing, align='center')
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    block = (title_box[3] - title_box[1]) + gap + (
        subtitle_box[3] - subtitle_box[1])
    y = (top - block) // 2 + 10
    draw.multiline_text((width // 2, y - title_box[1]), headline,
                        font=title_font, fill='white', anchor='ma',
                        spacing=spacing, align='center')
    y += title_box[3] - title_box[1] + gap
    draw.text((width // 2, y - subtitle_box[1]), subtitle,
              font=subtitle_font, fill=SUBTITLE, anchor='ma')
    return image


def preview(device, recording, name, marks):
    # A little of the still screen before the first touch and after the last.
    start = max(marks['begin'] - 0.3, 0)
    duration = marks['end'] + 0.4 - start
    if not 15 <= duration <= 30:
        raise SystemExit(f'{name}: {duration:.1f}s, outside the 15–30s range')
    target = OUT / device.folder / 'previews' / f'{name}.mp4'
    width, height = device.preview_size
    subprocess.run([
        'ffmpeg', '-y', '-v', 'error',
        '-ss', f'{start:.3f}', '-t', f'{duration:.3f}',
        '-i', str(SOURCE / device.key / 'video' / f'{recording}.mov'),
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        # The simulator's screen is rarely the exact shape Apple asks for:
        # fill the size, then trim what is left over.
        '-vf', f'fps=30,scale={width}:{height}:flags=lanczos:'
               f'force_original_aspect_ratio=increase,crop={width}:{height},'
               'format=yuv420p',
        '-map', '0:v', '-map', '1:a', '-shortest',
        # Constant bit rate: Apple asks for 10–12 Mbps, and a mostly still
        # screen would otherwise come out far below it.
        '-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0',
        '-b:v', '11M', '-minrate', '11M', '-maxrate', '11M',
        '-bufsize', '11M', '-x264-params', 'nal-hrd=cbr',
        '-color_primaries', 'bt709', '-color_trc', 'bt709',
        '-colorspace', 'bt709',
        '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2',
        '-movflags', '+faststart', str(target),
    ], check=True)
    return target, duration


def mac_window(screen, dark):
    """[screen], the app's content, under a macOS title bar."""
    width, height = screen.width, screen.height + MAC_TITLE_BAR
    radius = 28
    bar, line, text = (((44, 44, 48), (24, 24, 27), (190, 190, 196)) if dark
                       else ((236, 236, 238), (206, 206, 210), (96, 96, 102)))
    window = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(window)
    draw.rectangle((0, 0, width, MAC_TITLE_BAR), fill=bar)
    draw.line((0, MAC_TITLE_BAR - 1, width, MAC_TITLE_BAR - 1), fill=line,
              width=2)
    for index, color in enumerate(((255, 95, 87), (254, 188, 46),
                                   (40, 200, 64))):
        x = 36 + index * 40
        draw.ellipse((x - 13, MAC_TITLE_BAR // 2 - 13,
                      x + 13, MAC_TITLE_BAR // 2 + 13), fill=color)
    title = font(26, 600, 28)
    draw.text((width // 2, MAC_TITLE_BAR // 2), 'ToDo Bomber',
              font=title, fill=text, anchor='mm')
    window.paste(screen.convert('RGBA'), (0, MAC_TITLE_BAR))
    mask = Image.new('L', window.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1),
                                           radius, fill=255)
    window.putalpha(mask)
    return window, radius


def mac_screenshot(screen, headline, subtitle, dark):
    size = MAC_SIZE
    width, height = size
    image = background(size)
    window, radius = mac_window(screen, dark)
    left, top = (width - window.width) // 2, height - 84 - window.height

    shadow = Image.new('L', size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left + 20, top + 50, left + window.width - 20,
         top + window.height + 30), radius, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    image = Image.composite(Image.new('RGB', size, SHADOW), image, shadow)
    # A hairline around the window, as macOS draws.
    edge = Image.new('RGBA', size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        (left - 2, top - 2, left + window.width + 1, top + window.height + 1),
        radius + 2, outline=(255, 255, 255, 60), width=2)
    image.paste(edge, (0, 0), edge)
    image.paste(window, (left, top), window)

    draw = ImageDraw.Draw(image)
    title_font = font(110, 700, 96)
    subtitle_font = font(54, 500, 28)
    spacing, gap = 19, 38
    title_box = draw.multiline_textbbox((0, 0), headline, font=title_font,
                                        spacing=spacing, align='center')
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    block = (title_box[3] - title_box[1]) + gap + (
        subtitle_box[3] - subtitle_box[1])
    y = (top - block) // 2 + 10
    draw.multiline_text((width // 2, y - title_box[1]), headline,
                        font=title_font, fill='white', anchor='ma',
                        spacing=spacing, align='center')
    y += title_box[3] - title_box[1] + gap
    draw.text((width // 2, y - subtitle_box[1]), subtitle,
              font=subtitle_font, fill=SUBTITLE, anchor='ma')
    return image


def compose_mac():
    out = OUT / 'macos-desktop-2880x1800'
    out.mkdir(parents=True, exist_ok=True)
    for index, (name, headline, subtitle) in enumerate(MAC_SCREENSHOTS, 1):
        file = f'{index:02d}_{name[3:]}.png'
        screen = Image.open(SOURCE / 'mac' / 'raw' / f'{name}.png')
        screen = screen.convert('RGB')
        mac_screenshot(screen, headline.replace('\n', ' '), subtitle,
                       name.endswith('escuro')).save(out / file)
        print(f'macos-desktop-2880x1800/{file}')
    if (SOURCE / 'mac' / 'marks.json').exists():
        compose_mac_previews()


# The preview's window: the content is 1760 × 1000 under a title bar.
MAC_PREVIEW_SIZE = (1920, 1080)
MAC_PREVIEW_CONTENT = (1760, 1000)


def mac_preview(recording, name, marks, work):
    """Encodes the frames of [recording], taken at no fixed rate, as a
    30 fps video over the window's background."""
    width, height = MAC_PREVIEW_CONTENT
    left = (MAC_PREVIEW_SIZE[0] - width) // 2
    top = (MAC_PREVIEW_SIZE[1] - height - MAC_TITLE_BAR) // 2 + MAC_TITLE_BAR
    # The still screen a little before the first touch and after the last.
    start, end = marks['begin'] - 0.3, marks['end'] + 0.4
    if not 15 <= end - start <= 30:
        raise SystemExit(f'{name}: {end - start:.1f}s, outside 15–30s')

    frames = sorted(
        (SOURCE / 'mac' / 'frames' / recording).glob('*.png'),
        key=lambda f: int(f.stem))
    times = [int(f.stem) / 1000 for f in frames]
    first = max(i for i, t in enumerate(times) if t <= start)
    chosen = [(frames[i], max(times[i], start)) for i, t in enumerate(times)
              if i >= first and t < end]
    lines = []
    for index, (frame, taken) in enumerate(chosen):
        following = chosen[index + 1][1] if index + 1 < len(chosen) else end
        lines += [f"file '{frame}'", f'duration {following - taken:.4f}']
    lines.append(f"file '{chosen[-1][0]}'")
    (work / 'frames.txt').write_text('\n'.join(lines))

    # The window around the content: title bar, rounded corners, shadow.
    image = background(MAC_PREVIEW_SIZE)
    window = Image.new('RGB', (width, height + MAC_TITLE_BAR))
    window, radius = mac_window(window, False)
    shadow = Image.new('L', MAC_PREVIEW_SIZE, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left + 10, top - MAC_TITLE_BAR + 24, left + width - 10,
         top + height + 14), radius, fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    image = Image.composite(Image.new('RGB', MAC_PREVIEW_SIZE, SHADOW),
                            image, shadow)
    image.paste(window, (left, top - MAC_TITLE_BAR), window)
    image.save(work / 'background.png')
    # Only the content's bottom corners are round.
    corner = Image.new('L', (width, height), 0)
    ImageDraw.Draw(corner).rounded_rectangle(
        (0, -radius, width - 1, height - 1), radius, fill=255)
    corner.save(work / 'mask.png')

    target = OUT / 'macos-previews-1920x1080' / f'{name}.mp4'
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        'ffmpeg', '-y', '-v', 'error',
        '-f', 'concat', '-safe', '0', '-i', str(work / 'frames.txt'),
        '-loop', '1', '-framerate', '30', '-i', str(work / 'background.png'),
        '-loop', '1', '-framerate', '30', '-i', str(work / 'mask.png'),
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-filter_complex',
        '[0:v]fps=30,format=rgba[c];[2:v]format=gray[m];'
        '[c][m]alphamerge[w];'
        f'[1:v][w]overlay={left}:{top}:shortest=1,format=yuv420p[v]',
        '-map', '[v]', '-map', '3:a', '-r', '30', '-t', f'{end - start:.3f}',
        '-c:v', 'libx264', '-profile:v', 'high', '-level:v', '4.0',
        '-b:v', '11M', '-minrate', '11M', '-maxrate', '11M',
        '-bufsize', '11M', '-x264-params', 'nal-hrd=cbr',
        '-color_primaries', 'bt709', '-color_trc', 'bt709',
        '-colorspace', 'bt709',
        '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2',
        '-movflags', '+faststart', str(target),
    ], check=True)
    return target, end - start


def compose_mac_previews():
    marks = json.loads((SOURCE / 'mac' / 'marks.json').read_text())
    with tempfile.TemporaryDirectory() as work:
        for recording, name in PREVIEWS:
            if recording not in marks or 'end' not in marks[recording]:
                continue
            target, duration = mac_preview(recording, name, marks[recording],
                                           pathlib.Path(work))
            print(f'macos-previews-1920x1080/{target.name}: {duration:.1f}s, '
                  f'{target.stat().st_size / 1e6:.1f} MB')


ICON = ROOT / 'assets' / 'icon' / 'png' / 'full_1024.png'


def compose_play_graphics():
    """The Play listing's 1024 × 500 feature graphic (the icon, the name and
    the pitch over the screenshots' background) and its 512 × 512 icon."""
    out = OUT / 'android-graphics'
    out.mkdir(parents=True, exist_ok=True)
    icon = Image.open(ICON).convert('RGBA')
    icon.resize((512, 512), Image.LANCZOS).convert('RGB').save(
        out / 'icon_512.png')

    size = (1024, 500)
    image = background(size)
    mark = icon.resize((300, 300), Image.LANCZOS)
    left, top = 80, (size[1] - mark.height) // 2
    shadow = Image.new('L', size, 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left + 20, top + 30, left + mark.width - 20, top + mark.height + 10),
        60, fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    image = Image.composite(Image.new('RGB', size, SHADOW), image, shadow)
    image.paste(mark, (left, top), mark)

    draw = ImageDraw.Draw(image)
    x = left + mark.width + 50
    title = font(76, 700, 96)
    subtitle = font(34, 500, 28)
    draw.text((x, 170), 'ToDo Bomber', font=title, fill='white', anchor='ls')
    draw.multiline_text((x, 230), 'Tarefas sem data no topo,\n'
                        'o resto na linha do tempo', font=subtitle,
                        fill=SUBTITLE, spacing=10)
    image.save(out / 'feature_graphic_1024x500.png')
    print('android-graphics/feature_graphic_1024x500.png, icon_512.png')


def compose(key):
    if key == 'mac':
        return compose_mac()
    device = DEVICES[key]
    out = OUT / device.folder
    out.mkdir(parents=True, exist_ok=True)
    handle = handle_pixels(device) if device.handle else None

    for index, (name, headline, subtitle) in enumerate(SCREENSHOTS, 1):
        file = f'{index:02d}_{name[3:]}.png'
        screen, mask = load_screen(device, name, handle)
        subtitle = subtitle.format(device=device.name, devices=device.devices)
        screenshot(device, screen, mask, headline, subtitle).save(out / file)
        print(f'{device.folder}/{file}')

    if key == 'android':
        compose_play_graphics()
    if not device.preview_size or not (SOURCE / key / 'marks.json').exists():
        return
    (out / 'previews').mkdir(exist_ok=True)
    marks = json.loads((SOURCE / key / 'marks.json').read_text())
    for recording, name in PREVIEWS:
        if 'end' not in marks.get(recording, {}):
            continue
        target, duration = preview(device, recording, name, marks[recording])
        size = target.stat().st_size / 1e6
        print(f'{device.folder}/previews/{target.name}: {duration:.1f}s, '
              f'{size:.1f} MB')


def main():
    keys = sys.argv[1:] or [key for key in [*DEVICES, 'mac']
                            if (SOURCE / key).exists()]
    for key in keys:
        compose(key)


if __name__ == '__main__':
    main()
