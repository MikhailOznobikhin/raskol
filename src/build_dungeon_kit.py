#!/usr/bin/env python3
"""Сборка модулей набора Medieval Underground Dungeon под сетку игры.

Набор — Sketchfab-выгрузка одного помещения: модуль стены это кладка 4 м с
полуметровой толщей плюс свод, который поднимается от стены в сторону зала
(гребень свода 4,844 м). Модуль проёма — та же кладка с арочным проходом,
модуль угла — угловая стойка со сводом на всю клетку.

Скрипт перекладывает каждый модуль в СВОЮ локальную систему координат, удобную
генератору уровня:

  каноническая стена: x — вдоль стены (центр 0), z=0 — плоскость лицевой
  кладки, z>0 — внутрь стены, z<0 — в зал (туда же уходит свод), y=0 — пол.

  канонический пол: клетка 2×2 (4×4 м), верхняя поверхность на y=0, центр (0,0).

Запуск:

  python.exe src/build_dungeon_kit.py --analyze     # печать габаритов/срезов
  python.exe src/build_dungeon_kit.py               # сборка assets/models/dungeon_kit
"""
import argparse
import io
import json
import os
import struct

import numpy as np
from PIL import Image

SRC = "tools/assets_incoming/dungeon_kit.glb"
OUT_DIR = "assets/models/dungeon_kit"
TEX_DIR = os.path.join(OUT_DIR, "textures")
GLB_OUT = os.path.join(OUT_DIR, "dungeon_kit.glb")

CELL = 2.0          # размер клетки уровня
VAULT_TOP = 4.844   # верх свода модуля стены (плоскость потолка = WALL_H)
WALL_DEPTH = 1.901  # габаритная глубина модуля стены по z

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16,
      5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


class Glb:
    def __init__(self, path):
        data = open(path, 'rb').read()
        off, self.js, self.bin = 12, None, b''
        while off < len(data):
            clen, ctype = struct.unpack('<II', data[off:off + 8])
            body = data[off + 8:off + 8 + clen]
            if ctype == 0x4E4F534A:
                self.js = json.loads(body.decode('utf-8'))
            elif ctype == 0x004E4942:
                self.bin = body
            off += 8 + clen

    def acc(self, idx):
        a = self.js['accessors'][idx]
        bv = self.js['bufferViews'][a['bufferView']]
        n, dt = NC[a['type']], np.dtype(CT[a['componentType']])
        start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride, count = bv.get('byteStride'), a['count']
        if stride and stride != n * dt.itemsize:
            raw = np.frombuffer(self.bin, dtype=np.uint8, count=stride * count,
                                offset=start).reshape(count, stride)
            return np.frombuffer(raw[:, :n * dt.itemsize].tobytes(), dtype=dt).reshape(count, n)
        return np.frombuffer(self.bin, dtype=dt, count=count * n, offset=start).reshape(count, n)

    def image_bytes(self, tex_index):
        src = self.js['textures'][tex_index]['source']
        bv = self.js['bufferViews'][self.js['images'][src]['bufferView']]
        o = bv.get('byteOffset', 0)
        return self.bin[o:o + bv['byteLength']]

    def part(self, mesh_name, mat_name=None):
        """Один меш (первый вариант) как словарь массивов."""
        for m in self.js['meshes']:
            if m['name'] == mesh_name:
                pr = m['primitives'][0]
                mat = self.js['materials'][pr.get('material', 0)]['name']
                return {
                    'pos': self.acc(pr['attributes']['POSITION']).astype(np.float64),
                    'nor': self.acc(pr['attributes']['NORMAL']).astype(np.float64),
                    'uv': self.acc(pr['attributes']['TEXCOORD_0']).astype(np.float64),
                    'idx': self.acc(pr['indices']).reshape(-1).astype(np.int64),
                    'mat': mat_name or mat,
                }
        raise KeyError(mesh_name)

    def material(self, name):
        for m in self.js['materials']:
            if m.get('name') == name:
                return m
        raise KeyError(name)

    def map_name(self, material, key):
        """Имя карты материала ('base'|'mr'|'normal'|'emissive')."""
        m = self.material(material)
        tex = None
        if key == 'base':
            tex = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
        elif key == 'mr':
            tex = m.get('pbrMetallicRoughness', {}).get('metallicRoughnessTexture')
        elif key == 'normal':
            tex = m.get('normalTexture')
        elif key == 'emissive':
            tex = m.get('emissiveTexture')
        return None if tex is None else tex['index']


# ---------------------------------------------------------------------------
# геометрия

def transform(part, matrix):
    """Умножает позиции и нормали на матрицу 4×4 (нормали — без сдвига)."""
    p = np.hstack([part['pos'], np.ones((len(part['pos']), 1))])
    part['pos'] = (p @ matrix.T)[:, :3]
    part['nor'] = part['nor'] @ matrix[:3, :3].T
    return part


def rot_y180():
    m = np.eye(4)
    m[0, 0] = m[2, 2] = -1.0
    return m


def rot_y90():
    """(x,y,z) -> (z,y,-x): ось длины модуля проёма переезжает на x."""
    m = np.eye(4)
    m[0, 0], m[0, 2], m[2, 0], m[2, 2] = 0, 1, -1, 0
    return m


def translate(dx, dy, dz):
    m = np.eye(4)
    m[:3, 3] = (dx, dy, dz)
    return m


def scale(sx, sy, sz):
    m = np.eye(4)
    m[0, 0], m[1, 1], m[2, 2] = sx, sy, sz
    return m


def offset_part(part, d):
    part['pos'] = part['pos'] + np.asarray(d, dtype=np.float64)
    return part


def clip_axis(part, axis, lo, hi, cap=True, end_axis_value=None, end_axis_axis=0):
    """Обрезает меш по плоскостям axis=lo и axis=hi, зашивая открытые срезы.

    Треугольники режутся полигональным отсечением с интерполяцией нормалей и
    UV, затем на каждой плоскости среза ищутся открытые (принадлежащие одному
    треугольнику) рёбра, сшиваются в контуры и зашиваются веером. UV заглушки
    считаются аффинным отображением по торцу модуля (end_axis_value) — иначе
    срез остаётся чёрной дырой.
    """
    pos, nor, uv = part['pos'], part['nor'], part['uv']
    idx = part['idx'].reshape(-1, 3)
    planes = []
    if lo is not None:
        planes.append((lo, True))    # оставляем axis >= lo
    if hi is not None:
        planes.append((hi, False))   # оставляем axis <= hi
    out_pos, out_nor, out_uv = [], [], []
    for t in idx:
        poly = [(pos[i], nor[i], uv[i]) for i in t]
        for value, keep_ge in planes:
            nxt = []
            for k in range(len(poly)):
                a, b = poly[k], poly[(k + 1) % len(poly)]
                da = a[0][axis] - value
                db = b[0][axis] - value
                ina = da >= -1e-9 if keep_ge else da <= 1e-9
                inb = db >= -1e-9 if keep_ge else db <= 1e-9
                if ina:
                    nxt.append(a)
                if ina != inb:
                    f = da / (da - db)
                    nxt.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f,
                                a[2] + (b[2] - a[2]) * f))
            poly = nxt
            if not poly:
                break
        for k in range(1, len(poly) - 1):
            for v in (poly[0], poly[k], poly[k + 1]):
                out_pos.append(v[0])
                out_nor.append(v[1])
                out_uv.append(v[2])

    res = {'pos': np.array(out_pos, dtype=np.float64).reshape(-1, 3),
           'nor': np.array(out_nor, dtype=np.float64).reshape(-1, 3),
           'uv': np.array(out_uv, dtype=np.float64).reshape(-1, 2),
           'idx': np.arange(len(out_pos), dtype=np.int64), 'mat': part['mat']}
    # Склейка до зашивки: в исходнике вершины на плоскости среза продублированы,
    # контуры из таких рёбер не собираются в петлю, и один из торцов модуля
    # оставался открытым — в кадре это чёрный зазубренный силуэт у косяков.
    res = weld(res)
    if cap:
        for value, keep_ge in planes:
            sign = -1.0 if keep_ge else 1.0
            caps = _cap_plane(res, axis, value, sign, part, end_axis_value, end_axis_axis)
            if caps['pos'].size:
                res = merge_parts(res, caps)
    return res


def _cap_plane(part, axis, value, sign, src, end_axis_value, end_axis_axis):
    """Зашивает срез в плоскости axis=value по открытым рёбрам."""
    pos = part['pos']
    idx = part['idx'].reshape(-1, 3)
    key = [tuple(np.round(p, 5)) for p in pos]
    edges = {}
    for t in idx:
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            e = (a, b) if key[a] <= key[b] else (b, a)
            edges[e] = edges.get(e, 0) + 1
    open_edges = [e for e, cnt in edges.items() if cnt == 1]
    on_plane = [e for e in open_edges if abs(pos[e[0]][axis] - value) < 1e-4
                and abs(pos[e[1]][axis] - value) < 1e-4]
    if not on_plane:
        return {'pos': np.zeros((0, 3)), 'nor': np.zeros((0, 3)),
                'uv': np.zeros((0, 2)), 'idx': np.zeros(0, dtype=np.int64), 'mat': part['mat']}
    # сшиваем рёбра в контуры
    nxt = {}
    for a, b in on_plane:
        nxt.setdefault(a, []).append(b)
        nxt.setdefault(b, []).append(a)
    loops = []
    seen = set()
    for start in list(nxt.keys()):
        if start in seen:
            continue
        loop = [start]
        seen.add(start)
        cur = start
        while True:
            cands = [x for x in nxt.get(cur, []) if x not in seen]
            if not cands:
                break
            cur = cands[0]
            seen.add(cur)
            loop.append(cur)
        if len(loop) >= 3:
            loops.append(loop)
    out_pos, out_nor, out_uv, out_idx = [], [], [], []
    normal = _axis_normal(axis, sign)
    for loop in loops:
        ctr = pos[loop].mean(0)
        base = len(out_pos)
        pts = [pos[i] for i in loop]
        n = len(pts)
        # ориентация контура: считаем знак площади в плоскости среза
        u_axis = [a for a in range(3) if a != axis]
        area = 0.0
        for k in range(n):
            a, b = pts[k], pts[(k + 1) % n]
            area += (a[u_axis[0]] * b[u_axis[1]] - b[u_axis[0]] * a[u_axis[1]])
        ccw = area > 0
        for k in range(n):
            out_pos.append(pts[k])
            out_nor.append(normal)
            out_uv.append(_map_end_uv(src, end_axis_value, pts[k], end_axis_axis))
        out_pos.append(ctr)
        out_nor.append(normal)
        out_uv.append(_map_end_uv(src, end_axis_value, ctr, end_axis_axis))
        c_i = base + n
        # веер: контур среза почти всегда выпуклый
        for k in range(n):
            a_i, b_i = base + k, base + (k + 1) % n
            if ccw:
                out_idx += [c_i, a_i, b_i]
            else:
                out_idx += [c_i, b_i, a_i]
    return {'pos': np.array(out_pos, dtype=np.float64).reshape(-1, 3),
            'nor': np.array(out_nor, dtype=np.float64).reshape(-1, 3),
            'uv': np.array(out_uv, dtype=np.float64).reshape(-1, 2),
            'idx': np.array(out_idx, dtype=np.int64), 'mat': part['mat']}


def _axis_normal(axis, sign):
    n = np.zeros(3)
    n[axis] = sign
    return n


def _map_end_uv(part, end_axis_value, p, end_axis_axis=0):
    """UV точки среза — аффинным отображением по торцу модуля.

    Отображение экстраполирует UV торца на весь срез, поэтому попадает и в
    пустые (белые) области атласа: срез кладки на кадре читался светлым
    листом. Полученные UV зажимаем в охват UV самого модуля — там только
    кирпич.
    """
    umin, vmin, umax, vmax = uv_bounds(part)

    def clamp(uvq):
        return np.array([min(max(float(uvq[0]), umin), umax),
                         min(max(float(uvq[1]), vmin), vmax)])

    if end_axis_value is None:
        return clamp([part['uv'][:, 0].mean(), part['uv'][:, 1].mean()])
    idx = part['idx'].reshape(-1, 3)
    pos, uv = part['pos'], part['uv']
    sel = np.all(np.abs(pos[idx][:, :, end_axis_axis] - end_axis_value) < 5e-3, axis=1)
    if sel.sum() < 3:
        return clamp([uv[:, 0].mean(), uv[:, 1].mean()])
    verts = idx[sel].reshape(-1)
    others = [a for a in range(3) if a != end_axis_axis]
    yz = pos[verts][:, others]
    uvq = uv[verts]
    a = np.hstack([yz, np.ones((len(yz), 1))])
    sol, *_ = np.linalg.lstsq(a, uvq, rcond=None)
    return clamp(np.array([p[others[0]], p[others[1]], 1.0]) @ sol)


def merge_parts(*parts):
    out = {'pos': [], 'nor': [], 'uv': [], 'idx': [], 'mat': parts[0]['mat']}
    base = 0
    for p in parts:
        if p['pos'].size == 0:
            continue
        out['pos'].append(p['pos'])
        out['nor'].append(p['nor'])
        out['uv'].append(p['uv'])
        out['idx'].append(np.asarray(p['idx']).reshape(-1) + base)
        base += len(p['pos'])
    return {'pos': np.vstack(out['pos']) if out['pos'] else np.zeros((0, 3)),
            'nor': np.vstack(out['nor']) if out['nor'] else np.zeros((0, 3)),
            'uv': np.vstack(out['uv']) if out['uv'] else np.zeros((0, 2)),
            'idx': np.concatenate(out['idx']) if out['idx'] else np.zeros(0, dtype=np.int64),
            'mat': out['mat']}


def weld(part, pos_tol=1e-4, uv_tol=1e-5, nor_tol=1e-2):
    """Склеивает совпадающие вершины и убирает вырожденные треугольники."""
    scale_v = np.array([1.0 / pos_tol, 1.0 / pos_tol, 1.0 / pos_tol])
    key = np.hstack([np.round(part['pos'] * scale_v),
                     np.round(part['uv'] / uv_tol),
                     np.round(part['nor'] / nor_tol)])
    # first выровнен с уникальными строками, inverse переводит старые вершины
    # в их номера — remap больше не нужен (иначе в индексах остаются -1)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    idx = inverse.reshape(-1)[part['idx'].reshape(-1, 3)]
    keep = (idx[:, 0] != idx[:, 1]) & (idx[:, 1] != idx[:, 2]) & (idx[:, 0] != idx[:, 2])
    idx = idx[keep]
    tri = part['pos'][first][idx]
    area = np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)
    idx = idx[area > 1e-9]
    return {'pos': part['pos'][first], 'nor': part['nor'][first], 'uv': part['uv'][first],
            'idx': idx.reshape(-1), 'mat': part['mat']}


def mirror_x(part):
    """Зеркальный вариант модуля: кладка вдоль стены не повторяется дважды подряд.

    Зеркало по X не поворачивает модуль (свод остаётся со стороны зала), но
    меняет обход треугольников — без перестановки индексов Godot рисует грань
    с изнанки, и в кадре появляются дыры вместо кладки.
    """
    out = {'pos': part['pos'].copy(), 'nor': part['nor'].copy(),
           'uv': part['uv'].copy(), 'mat': part['mat'],
           'idx': part['idx'].reshape(-1, 3)[:, [0, 2, 1]].reshape(-1).copy()}
    out['pos'][:, 0] *= -1.0
    out['nor'][:, 0] *= -1.0
    return out


def uv_bounds(part):
    if part['uv'].size == 0:
        return None
    return (part['uv'][:, 0].min(), part['uv'][:, 1].min(),
            part['uv'][:, 0].max(), part['uv'][:, 1].max())


def side_profile(part, label):
    """Печатает, где у модуля свод: высота геометрии у каждой грани."""
    pos = part['pos']
    mn, mx = pos.min(0), pos.max(0)
    print('  %s: bbox %s .. %s' % (label, np.round(mn, 3), np.round(mx, 3)))
    for axis, name in ((0, 'x'), (2, 'z')):
        for lo_hi, lim in (('min', mn[axis]), ('max', mx[axis])):
            sel = np.abs(pos[:, axis] - lim) < 0.06
            top = pos[sel][:, 1].max() if sel.any() else float('nan')
            cnt = int(sel.sum())
            print('     грань %s-%s: вершин %5d, верх y=%.2f' % (name, lo_hi, cnt, top))


# ---------------------------------------------------------------------------
# текстуры

def export_texture(glb, material, key, path, max_size=2048, quality=92):
    tex = glb.map_name(material, key)
    if tex is None:
        return None
    img = Image.open(io.BytesIO(glb.image_bytes(tex)))
    img.load()
    if max_size and max(img.size) > max_size:
        k = max_size / max(img.size)
        img = img.resize((max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k))),
                         Image.LANCZOS)
    if img.mode in ('P', 'L'):
        img = img.convert('RGB')
    if path.endswith('.jpg'):
        img.convert('RGB').save(path, quality=quality, subsampling=0, optimize=True)
    else:
        img.save(path, optimize=True)
    return {'file': os.path.basename(path), 'size': img.size}


# ---------------------------------------------------------------------------
# сборка GLB на выходе

def write_glb(path, meshes, materials, textures, tex_dir_rel):
    """Пишет GLB: меши в локальных системах координат + внешние текстуры."""
    buffers = []
    offset = 0

    def add_view(data, target=None):
        nonlocal offset
        if offset % 4:                     # выравнивание буфера до 4 байт
            pad = 4 - (offset % 4)
            buffers.append(b'\0' * pad)
            offset += pad
        start = offset
        buffers.append(data)
        offset += len(data)
        view = {'buffer': 0, 'byteOffset': start, 'byteLength': len(data)}
        if target:
            view['target'] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    accessors, buffer_views, gltf_meshes, gltf_nodes, gltf_mats = [], [], [], [], []

    def add_acc(arr, ctype, atype, target=None):
        data = arr.tobytes()
        view = add_view(data, target)
        acc = {'bufferView': view, 'componentType': ctype, 'count': len(arr), 'type': atype}
        if atype == 'VEC3' and arr.dtype.kind == 'f':
            acc['min'] = [float(x) for x in arr.min(0)]
            acc['max'] = [float(x) for x in arr.max(0)]
        accessors.append(acc)
        return len(accessors) - 1

    images, gltf_textures, samplers = [], [], [{'magFilter': 9729, 'minFilter': 9987,
                                                'wrapS': 10497, 'wrapT': 10497}]
    tex_lookup = {}
    for name, info in textures.items():
        images.append({'uri': '%s/%s' % (tex_dir_rel, info['file'])})
        gltf_textures.append({'sampler': 0, 'source': len(images) - 1})
        tex_lookup[name] = len(gltf_textures) - 1

    for name, m in materials.items():
        mat = {'name': name, 'doubleSided': False,
               'pbrMetallicRoughness': {}, 'normalTexture': None}
        if m.get('base') in tex_lookup:
            mat['pbrMetallicRoughness']['baseColorTexture'] = {'index': tex_lookup[m['base']]}
        if m.get('mr') in tex_lookup:
            mat['pbrMetallicRoughness']['metallicRoughnessTexture'] = {'index': tex_lookup[m['mr']]}
        if m.get('normal') in tex_lookup:
            mat['normalTexture'] = {'index': tex_lookup[m['normal']]}
        if m.get('roughness') is not None:
            mat['pbrMetallicRoughness']['roughnessFactor'] = m['roughness']
        if m.get('emissive') in tex_lookup:
            mat['emissiveTexture'] = {'index': tex_lookup[m['emissive']]}
            mat['emissiveFactor'] = [1.0, 1.0, 1.0]
        if m.get('alpha'):
            mat['alphaMode'] = 'BLEND'
        if m.get('emissive_strength'):
            mat.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {
                'emissiveStrength': m['emissive_strength']}
        if mat['normalTexture'] is None:
            del mat['normalTexture']
        gltf_mats.append(mat)

    for name, parts in meshes.items():
        prims = []
        for part in parts:
            pos = part['pos'].astype(np.float32)
            nor = part['nor'].astype(np.float32)
            uv = part['uv'].astype(np.float32)
            idx = part['idx'].astype(np.uint32)
            prim = {'attributes': {
                'POSITION': add_acc(pos, 5126, 'VEC3', 34962),
                'NORMAL': add_acc(nor, 5126, 'VEC3', 34962),
                'TEXCOORD_0': add_acc(uv, 5126, 'VEC2', 34962)},
                'indices': add_acc(idx, 5125, 'SCALAR', 34963),
                'material': [m['name'] for m in gltf_mats].index(part['mat'])}
            prims.append(prim)
        gltf_meshes.append({'name': name, 'primitives': prims})
        gltf_nodes.append({'name': name, 'mesh': len(gltf_meshes) - 1})

    blob = b''.join(buffers)
    while len(blob) % 4:
        blob += b'\0'
    js = {
        'asset': {'version': '2.0', 'generator': 'build_dungeon_kit.py'},
        'scene': 0,
        'scenes': [{'name': 'dungeon_kit', 'nodes': list(range(len(gltf_nodes)))}],
        'nodes': gltf_nodes,
        'meshes': gltf_meshes,
        'materials': gltf_mats,
        'textures': gltf_textures,
        'images': images,
        'samplers': samplers,
        'accessors': accessors,
        'bufferViews': buffer_views,
        'buffers': [{'byteLength': len(blob)}],
        'extensionsUsed': ['KHR_materials_emissive_strength'],
    }
    js_chunk = json.dumps(js, separators=(',', ':')).encode('utf-8')
    while len(js_chunk) % 4:
        js_chunk += b' '
    total = 12 + 8 + len(js_chunk) + 8 + len(blob)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js_chunk), 0x4E4F534A) + js_chunk)
        f.write(struct.pack('<II', len(blob), 0x004E4942) + blob)
    return total


# ---------------------------------------------------------------------------
# модули

def flatten_relief(part, plane, normal, max_dist, cos_min=0.55):
    """Схлопывает мелкий рельеф на плоскость: кладка остаётся в текстуре и
    нормал-карте, а тысячи треугольников боковин кирпича уходят."""
    pos, nor = part['pos'], part['nor']
    nn = nor / (np.linalg.norm(nor, axis=1, keepdims=True) + 1e-9)
    dist = np.abs((pos - np.asarray(plane, dtype=np.float64)) @ np.asarray(normal))
    facing = nn @ np.asarray(normal) > cos_min
    sel = facing & (dist < max_dist)
    shift = ((np.asarray(plane) - pos) @ np.asarray(normal))
    part['pos'][sel] += np.outer(shift[sel], np.asarray(normal))
    return part


def build_modules(glb, flatten=False):
    """Возвращает {имя: [части]} в канонических системах координат."""
    mods = {}

    # --- стена: 4 м и 2 м (половинка берётся из середины модуля) ---
    # Лицевая кладка набора смотрит в +Z (z=4.005), свод уходит назад и вверх.
    # Канон: лицо на z=0, зал при z<0, толща стены при z>0.
    wall = glb.part('Brick_wall_BRICKWALLS_0')
    transform(wall, translate(-4.0, 0, 4.005) @ rot_y180())
    wall['uv'] = wall['uv'].copy()
    if flatten:
        flatten_relief(wall, (0, 0, 0.0), (0, 0, 1), 1.2)
    mods['wall_4m'] = [weld(clip_axis(wall, 0, -2.0, 2.0, True, -2.084))]
    mods['wall_2m'] = [weld(clip_axis(wall, 0, -1.0, 1.0, True, -2.084))]

    # --- проём с аркой: длина модуля переезжает на x, лицо на z=0 ---
    arch = glb.part('Brick_wall_doorway_BRICKWALLS_0')
    transform(arch, translate(4.0, 0, 0.005) @ rot_y90())
    mods['arch_2m'] = [weld(clip_axis(arch, 0, -1.0, 1.0, True, -2.084))]

    # --- пол: клетка 4×4 м, верхняя поверхность на y=0 ---
    floor = glb.part('Tile_floor_Tile_Floor_0')
    fmin, fmax = floor['pos'].min(0), floor['pos'].max(0)
    transform(floor, translate(-(fmin[0] + fmax[0]) * 0.5, -fmax[1], -(fmin[2] + fmax[2]) * 0.5))
    transform(floor, scale(CELL * 2.0 / (fmax[0] - fmin[0]), 1.0, CELL * 2.0 / (fmax[2] - fmin[2])))
    if flatten:
        flatten_relief(floor, (0, 0, 0), (0, 1, 0), 0.2, 0.5)
    mods['floor_4m'] = [weld(floor)]

    # Зеркальные варианты тех же модулей: соседние блоки стены отличаются
    # кладкой. Поворот на 180° для этого не годится — он разворачивал свод
    # внутрь стены, и половина уровня светила в чёрный фон сквозь дыры.
    for name in ('wall_4m', 'wall_2m', 'arch_2m'):
        mods[name + '_b'] = [mirror_x(mods[name][0])]

    # --- земля/песок: заплатка на полу ---
    dirt = glb.part('Dirt_ground_Sand_0')
    dmin, dmax = dirt['pos'].min(0), dirt['pos'].max(0)
    transform(dirt, translate(-(dmin[0] + dmax[0]) * 0.5, -dmin[1], -(dmin[2] + dmax[2]) * 0.5))
    mods['dirt'] = [weld(dirt)]

    # --- настенный факел: крепление в плоскости стены (z=0), рожок в зал (−z) ---
    torch = glb.part('Wall_Torch_TORCHCHEST_0')
    tmin, tmax = torch['pos'].min(0), torch['pos'].max(0)
    transform(torch, translate(0, -tmin[1], -tmin[2]))
    torch['pos'][:, 0] -= (tmin[0] + tmax[0]) * 0.5
    mods['torch'] = [weld(torch)]

    # --- сундук: реквизит ---
    body = glb.part('Chest_Body_TORCHCHEST_0')
    hood = glb.part('Chest_Hood_TORCHCHEST_0')
    for p in (body, hood):
        mn, mx = p['pos'].min(0), p['pos'].max(0)
        transform(p, translate(-(mn[0] + mx[0]) * 0.5, -mn[1], -(mn[2] + mx[2]) * 0.5))
    mods['chest'] = [body, hood]
    return mods


def used_materials(mods):
    out = set()
    for parts in mods.values():
        for p in parts:
            out.add(p['mat'])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', default=SRC)
    ap.add_argument('--analyze', action='store_true')
    ap.add_argument('--max-tex', type=int, default=2048)
    ap.add_argument('--flatten', action='store_true',
                    help='схлопнуть мелкий рельеф кладки (меньше треугольников)')
    args = ap.parse_args()
    glb = Glb(args.src)

    if args.analyze:
        for name in ('Brick_wall_BRICKWALLS_0', 'Brick_wall_corner_BRICKWALLS_0',
                     'Brick_wall_doorway_BRICKWALLS_0', 'Tile_floor_Tile_Floor_0',
                     'Wall_Torch_TORCHCHEST_0'):
            side_profile(glb.part(name), name)
        for name, parts in build_modules(glb).items():
            for p in parts:
                print('MODULE %-10s verts %6d tris %6d uv %s' % (
                    name, len(p['pos']), len(p['idx']) // 3,
                    None if uv_bounds(p) is None else np.round(uv_bounds(p), 3)))
        return

    os.makedirs(TEX_DIR, exist_ok=True)
    mods = build_modules(glb, flatten=args.flatten)
    mats = used_materials(mods)
    textures, materials = {}, {}
    for mat in sorted(mats):
        entry = {}
        for key, suffix, max_size, quality in (
                ('base', 'basecolor.jpg', args.max_tex, 92),
                ('mr', 'mr.png', 1024, 92),
                ('normal', 'normal.jpg', args.max_tex, 95),
                ('emissive', 'emissive.png', 1024, 92)):
            tex_id = glb.map_name(mat, key)
            if tex_id is None:
                continue
            fname = '%s_%s' % (mat.lower(), suffix)
            info = export_texture(glb, mat, key, os.path.join(TEX_DIR, fname),
                                  max_size, quality)
            if info is None:
                continue
            key_name = '%s:%s' % (mat, key)
            textures[key_name] = {'file': fname}
            entry[key] = key_name
            print('TEX %-28s %s' % (fname, info['size']))
        m = glb.material(mat)
        entry['roughness'] = m.get('pbrMetallicRoughness', {}).get('roughnessFactor')
        entry['alpha'] = m.get('alphaMode') == 'BLEND'
        ext = m.get('extensions', {}).get('KHR_materials_emissive_strength', {})
        entry['emissive_strength'] = ext.get('emissiveStrength')
        materials[mat] = entry

    total = write_glb(GLB_OUT, mods, materials, textures, 'textures')
    print('GLB %s (%.1f МБ)' % (GLB_OUT, total / 1048576.0))
    for name, parts in mods.items():
        tris = sum(len(p['idx']) // 3 for p in parts)
        print('  %-10s tris %6d' % (name, tris))


if __name__ == '__main__':
    main()
