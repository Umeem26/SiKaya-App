# Membuat gambar splash dari assets/icon_ayam.png (jalankan dari folder aplikasi):
#   python tool/buat_splash.py && dart run flutter_native_splash:create
#
# Android 12+ (dokumentasi Android "Splash screens"): ikon dengan latar ikon
# 240x240dp, isi harus muat di lingkaran 160dp (2/3 diameter); sisanya terpotong.
# flutter_native_splash: 960x960px, isi di lingkaran 640px. Isi logo (panah + koin)
# dipotong dari kanvasnya lalu diskalakan agar DIAGONAL-nya <= 600px (aman di
# dalam lingkaran 640px dengan sisa 20px tiap sisi).
#
# Android 11 ke bawah dan splash Flutter: lingkaran putih 640px (=160dp di
# xxxhdpi) berisi logo yang sama, sehingga semua versi tampak identik.
import math
import os

from PIL import Image, ImageDraw

SUMBER = 'assets/icon_ayam.png'
KELUAR = 'assets/splash'
DIAGONAL_MAKS = 600


def isi_logo():
    im = Image.open(SUMBER).convert('RGBA')
    rgb = im.convert('RGB')
    w, h = rgb.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if min(rgb.getpixel((x, y))) < 235:
                xs.append(x)
                ys.append(y)
    pad = 6
    kotak = (max(min(xs) - pad, 0), max(min(ys) - pad, 0), min(max(xs) + pad, w), min(max(ys) + pad, h))
    isi = im.crop(kotak)
    # Latar logo hampir putih (bergradasi): jadikan putih murni agar menyatu dengan lingkaran.
    px = isi.load()
    for y in range(isi.size[1]):
        for x in range(isi.size[0]):
            if min(px[x, y][:3]) >= 240:
                px[x, y] = (255, 255, 255, 255)
    sisi = int(DIAGONAL_MAKS / math.sqrt(2))
    skala = sisi / max(isi.size)
    return isi.resize((round(isi.size[0] * skala), round(isi.size[1] * skala)), Image.LANCZOS)


def tengah(kanvas, isi):
    kanvas.alpha_composite(isi, ((kanvas.size[0] - isi.size[0]) // 2, (kanvas.size[1] - isi.size[1]) // 2))
    return kanvas


def main():
    os.makedirs(KELUAR, exist_ok=True)
    isi = isi_logo()

    # Android 12+: transparan, latar putih digambar sistem (icon_background_color).
    a12 = tengah(Image.new('RGBA', (960, 960), (0, 0, 0, 0)), isi)
    a12.save(f'{KELUAR}/splash_android12.png')

    # Android 11- dan Flutter: lingkaran putih 640px berisi logo (diperhalus 4x).
    besar = Image.new('RGBA', (2560, 2560), (0, 0, 0, 0))
    ImageDraw.Draw(besar).ellipse((0, 0, 2559, 2559), fill=(255, 255, 255, 255))
    lingkaran = besar.resize((640, 640), Image.LANCZOS)
    tengah(lingkaran, isi).save(f'{KELUAR}/splash_logo.png')
    print('isi logo', isi.size, '-> diagonal', round(math.hypot(*isi.size)), 'px (batas 640)')


if __name__ == '__main__':
    main()
