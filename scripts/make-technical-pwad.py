# Builds the Crysis technical PWAD from the pinned Freedoom Phase 2 IWAD.
# Geometry (vertices, segs, ssectors, nodes, sectors, reject, blockmap) is
# preserved byte-for-byte; only THINGS and LINEDEFS are rewritten:
#  - the ten monsters nearest the player start become KPA soldiers (3001);
#  - four unused lines around the start carry the project specials
#    (301 tags 1/2 = objectives, 303 = jammer, 302 = exit).
# Usage: python make-technical-pwad.py <iwad> <output.wad>

import struct
import sys

OBJECTIVE_USE = 301
MISSION_EXIT = 302
JAMMER = 303
KPA_TYPE = 30001
MONSTER_TYPES = {3004, 3005, 9, 65}  # zombieman, shotguy, former human
LUMPS = ["THINGS", "LINEDEFS", "SIDEDEFS", "VERTEXES", "SEGS",
         "SSECTORS", "NODES", "SECTORS", "REJECT", "BLOCKMAP"]


def read_wad(path):
    data = open(path, 'rb').read()
    sig, count, diroff = struct.unpack_from('<4sii', data, 0)
    lumps = []
    for i in range(count):
        off, size, name = struct.unpack_from('<ii8s', data, diroff + i * 16)
        lumps.append((name.rstrip(b'\0').decode('ascii', 'replace'),
                      data[off:off + size]))
    return lumps


def write_wad(path, lumps):
    payload = b''
    directory = b''
    offset = 12
    for name, data in lumps:
        directory += struct.pack('<ii8s', offset, len(data),
                                 name.encode('ascii').ljust(8, b'\0'))
        payload += data
        offset += len(data)
    header = struct.pack('<4sii', b'PWAD', len(lumps), 12 + len(payload))
    open(path, 'wb').write(header + payload + directory)


def main():
    iwad_path, out_path = sys.argv[1], sys.argv[2]
    lumps = read_wad(iwad_path)
    names = [name for name, _ in lumps]
    start = names.index('MAP01')
    map_lumps = dict(lumps[start + 1:start + 1 + len(LUMPS)])

    # Player start.
    things = bytearray(map_lumps['THINGS'])
    start_x = start_y = None
    for i in range(0, len(things), 10):
        t = struct.unpack_from('<h', things, i + 6)[0]
        if t == 1:
            start_x, start_y = struct.unpack_from('<hh', things, i)

    # Ten nearest monsters become KPA.
    candidates = []
    for i in range(0, len(things), 10):
        x, y, ang, t, flags = struct.unpack_from('<hhhhH', things, i)
        if t in MONSTER_TYPES:
            dist = abs(x - start_x) + abs(y - start_y)
            candidates.append((dist, i))
    candidates.sort()
    for dist, i in candidates[:10]:
        struct.pack_into('<h', things, i + 6, KPA_TYPE)

    # Four unused lines near the start carry the project specials.
    lines = bytearray(map_lumps['LINEDEFS'])
    vertexes = map_lumps['VERTEXES']
    near = []
    for i in range(0, len(lines), 14):
        special = struct.unpack_from('<H', lines, i + 6)[0]
        tag = struct.unpack_from('<H', lines, i + 8)[0]
        v1 = struct.unpack_from('<H', lines, i + 0)[0]
        v2 = struct.unpack_from('<H', lines, i + 2)[0]
        if special != 0 or tag != 0:
            continue
        x1, y1 = struct.unpack_from('<hh', vertexes, v1 * 4)
        x2, y2 = struct.unpack_from('<hh', vertexes, v2 * 4)
        mx, my = (x1 + x2) // 2, (y1 + y2) // 2
        dist = abs(mx - start_x) + abs(my - start_y)
        if 48 <= dist <= 640:
            near.append((dist, i, mx, my))
    near.sort()
    if len(near) < 4:
        raise SystemExit('not enough candidate lines near the start')

    picks = []
    for dist, i, mx, my in near:
        if all(abs(mx - px) + abs(my - py) > 96 for _, _, px, py in picks):
            picks.append((dist, i, mx, my))
        if len(picks) == 4:
            break
    if len(picks) < 4:
        picks = near[:4]

    settings = [(1, OBJECTIVE_USE), (2, OBJECTIVE_USE), (0, JAMMER),
                (0, MISSION_EXIT)]
    for (dist, i, mx, my), (tag, special) in zip(picks, settings):
        struct.pack_into('<H', lines, i + 6, special)
        struct.pack_into('<H', lines, i + 8, tag)
        print(f'line {i // 14}: special={special} tag={tag} at ({mx},{my})')

    map_lumps['THINGS'] = bytes(things)
    map_lumps['LINEDEFS'] = bytes(lines)

    out = [('MAP01', b'')] + [(name, map_lumps[name]) for name in LUMPS]
    write_wad(out_path, out)

    info_path = out_path.rsplit('.', 1)[0] + '.info'
    with open(info_path, 'w') as f:
        f.write(f'objective1={picks[0][1] // 14}\n')
        f.write(f'objective2={picks[1][1] // 14}\n')
        f.write(f'jammer={picks[2][1] // 14}\n')
        f.write(f'exit={picks[3][1] // 14}\n')
        f.write('kpa_type=30001\n')

    print(f'wrote {out_path}: {len(out)} lumps, '
          f'{min(10, len(candidates))} KPA spawns')
    print(f'wrote {info_path}')


if __name__ == '__main__':
    main()
