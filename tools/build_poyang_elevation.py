"""Resample public Terrain Tiles DEM to the game's existing WGS84 map extent.

Requires Pillow. Raw tiles are cached in ignored build/, never used at runtime.
Terrarium decoding and attribution: https://github.com/tilezen/joerd/tree/master/docs
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import datetime
import json
import math
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ZOOM = 8
SIZE = 128
CACHE = ROOT / 'build' / 'terrain-tiles'

def tile_point(lon, lat):
    n = 2 ** ZOOM
    return ((lon + 180) / 360 * n,
            (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) * n / 2)

def main():
    bounds = json.loads((ROOT / 'docs/geography/poyang-hydrography.geojson').read_text(encoding='utf-8'))['map_view']['bounds_wgs84']
    west, south, east, north = bounds
    positions = []
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = (x + .5) / SIZE * 2 - .5, (y + .5) / SIZE * 2 - .5
            positions.append(tile_point(west + u * (east - west), north - v * (north - south)))
    keys = sorted({(math.floor(x), math.floor(y)) for x, y in positions})
    CACHE.mkdir(parents=True, exist_ok=True)
    def fetch(key):
        x, y = key
        path = CACHE / f'{ZOOM}-{x}-{y}.png'
        url = f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{x}/{y}.png'
        if not path.exists():
            with urllib.request.urlopen(url, timeout=45) as response:
                path.write_bytes(response.read())
        image = Image.open(path).convert('RGB')
        assert image.size == (256, 256)
        return key, image, url
    with ThreadPoolExecutor(max_workers=4) as pool:
        downloaded = list(pool.map(fetch, keys))
    tiles = {key: image for key, image, _ in downloaded}
    def elevation(px, py):
        image = tiles[(px // 256, py // 256)]
        r, g, b = image.getpixel((px % 256, py % 256))
        return r * 256 + g + b / 256 - 32768
    values = []
    for x, y in positions:
        px, py = x * 256 - .5, y * 256 - .5
        ix, iy = math.floor(px), math.floor(py)
        fx, fy = px - ix, py - iy
        value = ((elevation(ix, iy) * (1-fx) + elevation(ix+1, iy) * fx) * (1-fy)
                 + (elevation(ix, iy+1) * (1-fx) + elevation(ix+1, iy+1) * fx) * fy)
        values.append(round(value, 2))
    data = {'source': 'Mapzen Terrain Tiles / SRTM and other open elevation data',
            'source_url': 'https://registry.opendata.aws/terrain-tiles/',
            'attribution': 'https://github.com/tilezen/joerd/blob/master/docs/attribution.md',
            'credits': ['Mapzen / Tilezen Terrain Tiles', 'SRTM and GMTED2010 elevation data courtesy of the U.S. Geological Survey', 'Global ETOPO1: U.S. National Oceanic and Atmospheric Administration'],
            'retrieved': str(datetime.date.today()), 'zoom': ZOOM,
            'bounds_wgs84': bounds, 'uv_extent': [-.5, -.5, 1.5, 1.5],
            'size': SIZE, 'north_up': True, 'units': 'meters',
            'tile_urls': [url for _, _, url in downloaded], 'elevation': values}
    target = ROOT / 'assets/geography/poyang-elevation.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
    print(f'{len(tiles)} public tiles; {SIZE}x{SIZE} elevations; range {min(values)}..{max(values)} m; {target}')

if __name__ == '__main__':
    main()
