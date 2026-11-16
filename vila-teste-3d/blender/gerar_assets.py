# Gera os assets 3D estilizados da "Vila do Pescador" (teste de estilo).
# Uso: python gerar_assets.py <pasta_saida_glb> <pasta_saida_ui>
# Precisa do modulo bpy (Blender 5.3 como modulo Python).
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Euler, noise

args = [a for a in sys.argv[1:] if not a.startswith("-")]
OUT = os.path.abspath(args[0]) if args else os.path.abspath("modelos")
OUT_UI = os.path.abspath(args[1]) if len(args) > 1 else OUT
os.makedirs(OUT, exist_ok=True)
os.makedirs(OUT_UI, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
CENA = bpy.context.scene


# ---------------------------------------------------------------- materiais
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


_MATS = {}


def M(nome, hexcor, rough=0.85, metal=0.0, emit=0.0):
    if nome in _MATS:
        return _MATS[nome]
    h = hexcor.lstrip("#")
    rgb = [_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)]
    cor = (*rgb, 1.0)
    m = bpy.data.materials.new(nome)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = cor
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = cor
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = cor
    _MATS[nome] = m
    return m


# ---------------------------------------------------------------- primitivas
def _obj(bm, nome, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return o


def caixa(dim, loc, mat, bevel=0.03, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(dim), verts=bm.verts)
    b = min(bevel, min(dim) * 0.45)
    if b > 0.001:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=b,
                        segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _obj(bm, "caixa", mat, loc, rot)


def cilindro(r, h, loc, mat, seg=12, rot=(0, 0, 0), r2=None, esc=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r, radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.scale(bm, vec=Vector(esc), verts=bm.verts)
    bm.normal_update()
    for f in bm.faces:
        f.smooth = abs(f.normal.z) < 0.7
    return _obj(bm, "cilindro", mat, loc, rot)


def esfera(r, loc, mat, sub=2, esc=(1, 1, 1), ruido=0.0, rot=(0, 0, 0), semente=0.0, metade=False):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    if ruido > 0:
        off = Vector((semente * 3.1, semente * 1.7, semente * 2.9))
        for v in bm.verts:
            n = noise.noise(v.co * (1.6 / r) + off)
            v.co *= 1.0 + ruido * n
    if metade:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.02 * r], context="VERTS")
    bmesh.ops.scale(bm, vec=Vector(esc), verts=bm.verts)
    for f in bm.faces:
        f.smooth = True
    return _obj(bm, "esfera", mat, loc, rot)


def toro(R, r, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=20,
                                     minor_segments=8, location=loc, rotation=rot)
    o = bpy.context.object
    o.data.materials.append(mat)
    o.data.shade_smooth()
    return o


def texto(txt, loc, tam, mat, extr=0.015):
    bpy.ops.object.text_add(location=loc, rotation=(math.pi / 2, 0, 0))
    t = bpy.context.object
    t.data.body = txt
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.size = tam
    t.data.extrude = extr
    t.data.materials.append(mat)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


# ---------------------------------------------------------------- exportar
def limpar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def juntar(nome):
    malhas = [o for o in CENA.objects if o.type == "MESH"]
    base = bpy.data.objects.new(nome, bpy.data.meshes.new(nome))
    CENA.collection.objects.link(base)
    for o in CENA.objects:
        o.select_set(o in malhas or o == base)
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.join()
    base.name = nome
    return base


def exportar(nome):
    o = juntar(nome)
    for x in CENA.objects:
        x.select_set(x == o)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + ".glb"),
                              export_format="GLB", use_selection=True, export_apply=True)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print(f"[asset] {nome}: {tris} triangulos")
    limpar()
    return tris


def retrato(nome, alvo, dist, alt=0.0):
    """Renderiza um retrato PNG (fundo transparente) para a interface."""
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 85
    cam = bpy.data.objects.new("cam", cam_d)
    CENA.collection.objects.link(cam)
    cam.location = (alvo[0] + dist * 0.25, alvo[1] - dist, alvo[2] + alt)
    d = Vector(alvo) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    CENA.camera = cam
    for loc, en in (((-2, -3, 3), 3.5), ((0, -3, 0.5), 2.0), ((3, -1, 2), 1.2)):
        ld = bpy.data.lights.new("sol", "SUN")
        ld.energy = en
        lo = bpy.data.objects.new("sol", ld)
        CENA.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if CENA.world is None:
        CENA.world = bpy.data.worlds.new("mundo")
    CENA.world.color = (0.6, 0.65, 0.7)
    r = CENA.render
    r.engine = "CYCLES"
    CENA.cycles.samples = 48
    CENA.cycles.device = "CPU"
    r.film_transparent = True
    r.resolution_x = r.resolution_y = 256
    r.filepath = os.path.join(OUT_UI, nome + ".png")
    bpy.ops.render.render(write_still=True)
    for o in list(CENA.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)


# ---------------------------------------------------------------- paleta
PEDRA = [M("pedra_a", "#8e877b"), M("pedra_b", "#77726a"), M("pedra_c", "#9d9585")]
MADEIRA = M("madeira", "#8a5a34")
MADEIRA_ESC = M("madeira_escura", "#6b4226")
MADEIRA_CLARA = M("madeira_clara", "#94592f")
PAREDE = M("parede_creme", "#ead3a2")
BRANCO = M("branco", "#f4f1ea")
VIDRO = M("vidro", "#3a78c9", rough=0.25)
FOLHA = [M("folha_a", "#3f8a2a"), M("folha_b", "#5aa437"), M("folha_c", "#2f7524")]
FLOR = {"vermelha": M("flor_vermelha", "#e2392f"), "branca": M("flor_branca", "#f7f4ee"),
        "amarela": M("flor_amarela", "#f5c531"), "rosa": M("flor_rosa", "#ef7aa6")}
MIOLO = M("miolo", "#f2b62a")
PRETO = M("ferro", "#2b2b30", rough=0.5, metal=0.4)
LUZ = M("luz", "#ffd27a", emit=4.0)


# ---------------------------------------------------------------- casas
def floreira(cx, y, z, larg=0.95):
    caixa((larg, 0.3, 0.22), (cx, y - 0.02, z), MADEIRA, 0.03)
    k = 0
    x = cx - larg / 2 + 0.1
    while x < cx + larg / 2 - 0.05:
        esfera(0.1, (x, y - 0.05, z + 0.14), random.choice(FOLHA), sub=1)
        esfera(0.06, (x + 0.03, y - 0.12, z + 0.24), random.choice(list(FLOR.values())), sub=1)
        x += 0.15
        k += 1


def janela(cx, y, cz, moldura):
    caixa((0.74, 0.06, 0.74), (cx, y + 0.02, cz), VIDRO, 0.0)
    for dz in (-0.41, 0.41):
        caixa((0.92, 0.13, 0.1), (cx, y - 0.04, cz + dz), moldura, 0.02)
    for dx in (-0.41, 0.41):
        caixa((0.1, 0.13, 0.92), (cx + dx, y - 0.04, cz), moldura, 0.02)
    caixa((0.05, 0.1, 0.74), (cx, y - 0.02, cz), moldura, 0.0)
    caixa((0.74, 0.1, 0.05), (cx, y - 0.02, cz), moldura, 0.0)
    floreira(cx, y - 0.16, cz - 0.56)


def casa(nome, w, d, telhado, telhado_esc, porta, moldura, placa=None, chamine=False,
         boia=False, peixe=False):
    random.seed(len(nome))
    bh, wh = 0.45, 2.3
    top = bh + wh
    rise = w * 0.3
    fy = -d / 2  # frente (fica de frente para a camera no Godot)
    # base de pedra com blocos
    caixa((w + 0.2, d + 0.2, bh), (0, 0, bh / 2), PEDRA[1], 0.05)
    for fila, z in enumerate((0.11, 0.33)):
        x = -w / 2 - 0.1 + (0.2 if fila else 0)
        while x < w / 2 + 0.05:
            bw = min(random.uniform(0.35, 0.65), w / 2 + 0.1 - x)
            if bw > 0.12:
                caixa((bw - 0.04, 0.08, 0.19), (x + bw / 2, fy - 0.12, z), random.choice(PEDRA), 0.03)
            x += bw
    # paredes e vigas
    caixa((w, d, wh), (0, 0, bh + wh / 2), PAREDE, 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            caixa((0.22, 0.22, wh), (sx * w / 2, sy * d / 2, bh + wh / 2), MADEIRA, 0.03)
    for sy in (-1, 1):
        caixa((w + 0.3, 0.24, 0.22), (0, sy * d / 2, top), MADEIRA, 0.03)
    for sx in (-1, 1):
        caixa((0.24, d + 0.3, 0.22), (sx * w / 2, 0, top), MADEIRA, 0.03)
    # oitao (triangulo da parede)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-w / 2, -d / 2, top), (w / 2, -d / 2, top), (0, -d / 2, top + rise),
                                     (-w / 2, d / 2, top), (w / 2, d / 2, top), (0, d / 2, top + rise))]
    for f in ((0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _obj(bm, "oitao", PAREDE)
    # telhado
    ov = 0.45
    a = math.atan2(rise, w / 2)
    L = (w / 2 + ov) / math.cos(a)
    t = 0.24
    D = d + 0.9
    cume = Vector((0, 0, top + rise))
    for s in (1, -1):
        dirv = Vector((s * math.cos(a), 0, -math.sin(a)))
        nor = Vector((s * math.sin(a), 0, math.cos(a)))
        c = cume + dirv * (L / 2) + nor * (t / 2)
        caixa((L, D, t), c, telhado, 0.05, rot=(0, s * a, 0))
        n = max(3, int(L / 0.34))
        for i in range(n):
            p = cume + dirv * (L * (i + 0.75) / (n + 0.2)) + nor * (t + 0.02)
            caixa((0.13, D, 0.08), p, telhado_esc, 0.03, rot=(0, s * a, 0))
        # acabamento de madeira na beira do oitao
        cf = cume + dirv * ((L - ov) / 2) - nor * 0.06 + Vector((0, fy - 0.08, 0))
        caixa((L - ov * 0.6, 0.14, 0.18), cf, MADEIRA_ESC, 0.03, rot=(0, s * a, 0))
    caixa((0.4, D + 0.06, 0.26), cume + Vector((0, 0, t * 0.85)), telhado_esc, 0.06)
    # porta
    dw, dh = 0.95, 1.85
    caixa((dw, 0.1, dh), (0, fy - 0.03, bh + dh / 2), porta, 0.02)
    for dx in (-0.22, 0.22):
        caixa((0.05, 0.12, dh * 0.85), (dx, fy - 0.05, bh + dh / 2), porta, 0.0)
    caixa((dw + 0.3, 0.16, 0.16), (0, fy - 0.05, bh + dh + 0.06), MADEIRA, 0.03)
    for sx in (-1, 1):
        caixa((0.13, 0.16, dh), (sx * (dw / 2 + 0.07), fy - 0.05, bh + dh / 2), MADEIRA, 0.03)
    esfera(0.05, (dw * 0.32, fy - 0.12, bh + dh * 0.48), M("ouro", "#e0b040", 0.35, 0.8), sub=1)
    caixa((dw + 0.8, 0.7, 0.2), (0, fy - 0.45, 0.1), PEDRA[0], 0.04)
    caixa((dw + 0.5, 0.45, 0.4), (0, fy - 0.3, 0.2), PEDRA[2], 0.04)
    # janelas
    wx = min(w / 2 - 0.85, 1.45)
    for sx in (-1, 1):
        janela(sx * wx, fy - 0.03, bh + 1.25, moldura)
    # placa
    if placa:
        caixa((2.5, 0.12, 0.55), (0, fy - 0.16, top + 0.14), MADEIRA_ESC, 0.05)
        caixa((2.35, 0.13, 0.42), (0, fy - 0.17, top + 0.14), MADEIRA_CLARA, 0.03)
        texto(placa, (0, fy - 0.25, top + 0.13), 0.32, M("creme", "#fff2d2"))
    if peixe:
        cz = top + rise * 0.5 + 0.12
        cilindro(0.42, 0.08, (0, fy - 0.03, cz), M("placa_azul", "#cfe7f5"), seg=24, rot=(math.pi / 2, 0, 0))
        cilindro(0.47, 0.06, (0, fy - 0.01, cz), MADEIRA_ESC, seg=24, rot=(math.pi / 2, 0, 0))
        prata = M("peixe", "#7fa3b8", 0.5)
        esfera(0.22, (-0.04, fy - 0.1, cz), prata, esc=(1, 0.35, 0.5))
        esfera(0.12, (0.22, fy - 0.1, cz), prata, esc=(0.6, 0.3, 1.0))
        esfera(0.03, (-0.17, fy - 0.17, cz + 0.03), PRETO, sub=1)
    if boia:
        bx = w / 2 - 0.42
        toro(0.27, 0.07, (bx, fy - 0.1, bh + 1.5), M("boia", "#e8432f", 0.6), rot=(math.pi / 2, 0, 0))
        for k in range(4):
            ang = k * math.pi / 2 + math.pi / 4
            caixa((0.09, 0.17, 0.16), (bx + 0.27 * math.cos(ang), fy - 0.1, bh + 1.5 + 0.27 * math.sin(ang)),
                  BRANCO, 0.02, rot=(0, -ang, 0))
    if chamine:
        cx = w * 0.22
        caixa((0.5, 0.5, 1.6), (cx, d * 0.15, top + rise * 0.55 + 0.4), M("chamine", "#c9c1b2"), 0.04)
        caixa((0.64, 0.64, 0.14), (cx, d * 0.15, top + rise * 0.55 + 1.25), PEDRA[1], 0.03)
    if not placa:
        # lampiao ao lado da porta + vasos
        caixa((0.18, 0.18, 0.28), (dw / 2 + 0.38, fy - 0.12, bh + 1.75), PRETO, 0.02)
        caixa((0.12, 0.2, 0.2), (dw / 2 + 0.38, fy - 0.13, bh + 1.75), LUZ, 0.01)
        for sx in (-1, 1):
            cilindro(0.17, 0.3, (sx * (dw / 2 + 0.55), fy - 0.55, 0.15), M("vaso", "#b8643a"), seg=10, r2=0.21)
            esfera(0.24, (sx * (dw / 2 + 0.55), fy - 0.55, 0.45), FOLHA[0], ruido=0.15, semente=sx)


# ---------------------------------------------------------------- props
def cerca():
    caixa((0.24, 0.24, 1.15), (0, 0, 0.575), MADEIRA_CLARA, 0.05)
    for z in (0.45, 0.85):
        caixa((2.0, 0.09, 0.24), (1.0, -0.17, z), M("madeira_cerca", "#a0653a"), 0.03)


def barril():
    bm = bmesh.new()
    perfil = [(0.0, 0.30), (0.12, 0.35), (0.47, 0.39), (0.82, 0.35), (0.94, 0.30)]
    seg = 16
    aneis = [[bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
              for i in range(seg)] for z, r in perfil]
    for a, b in zip(aneis, aneis[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i])).smooth = True
    bm.faces.new(list(reversed(aneis[0])))
    bm.faces.new(aneis[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _obj(bm, "barril", M("barril", "#9b6236"))
    for z, r in ((0.17, 0.36), (0.77, 0.36)):
        toro(r, 0.025, (0, 0, z), M("aro", "#4a4440", 0.5, 0.5))
    cilindro(0.29, 0.03, (0, 0, 0.94), MADEIRA_ESC, seg=16)


def deck():
    random.seed(3)
    tons = [MADEIRA_CLARA, M("tabua", "#b98250"), M("madeira_cerca", "#a0653a")]
    n = 16
    for i in range(n):
        caixa((0.29, 2.6, 0.08), (0.16 + i * 0.32, 0, 0.02), random.choice(tons), 0.02,
              rot=(0, 0, random.uniform(-0.015, 0.015)))
    for sy in (-1, 1):
        caixa((5.2, 0.16, 0.16), (2.6, sy * 1.1, -0.1), MADEIRA_ESC, 0.02)
    for x in (0.4, 2.6, 4.9):
        for sy in (-1, 1):
            cilindro(0.11, 1.6, (x, sy * 1.2, -0.65), MADEIRA_ESC, seg=10)
    for x in (1.0, 3.0, 5.0):
        for sy in (-1, 1):
            caixa((0.15, 0.15, 0.95), (x, sy * 1.22, 0.5), MADEIRA, 0.03)
    for sy in (-1, 1):
        for z in (0.5, 0.88):
            caixa((4.2, 0.08, 0.12), (3.0, sy * 1.22, z), MADEIRA_CLARA, 0.02)
    caixa((0.08, 2.5, 0.12), (5.0, 0, 0.88), MADEIRA_CLARA, 0.02)


def pedra(semente, esc):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    off = Vector((semente * 3.1, semente * 1.7, semente * 2.3))
    for v in bm.verts:
        v.co *= 1 + 0.3 * noise.noise(v.co * 1.2 + off)
    for v in bm.verts:
        v.co.x *= esc[0]
        v.co.y *= esc[1]
        v.co.z *= esc[2]
        v.co.z = max(v.co.z, -esc[2] * 0.25)
    for v in bm.verts:
        v.co.z += esc[2] * 0.25
    for f in bm.faces:
        f.smooth = True
    _obj(bm, "pedra", PEDRA[semente % 3])


def arvore(altura, copa, semente, n_bolhas=14):
    random.seed(semente)
    tronco = M("tronco", "#7a5232")
    ht = altura * 0.62
    cilindro(0.42 * copa / 3, ht, (0, 0, ht / 2), tronco, seg=10, r2=0.24 * copa / 3)
    for k in range(5):
        ang = k * 2 * math.pi / 5 + random.uniform(-0.3, 0.3)
        cilindro(0.2 * copa / 3, 1.0 * copa / 3, (math.cos(ang) * 0.5 * copa / 3, math.sin(ang) * 0.5 * copa / 3, 0.15),
                 tronco, seg=8, r2=0.04, rot=(0, math.pi / 2 + 0.35, ang))
    for k in range(3):
        ang = k * 2 * math.pi / 3 + 0.5
        cilindro(0.14 * copa / 3, copa * 0.55, (math.cos(ang) * copa * 0.18, math.sin(ang) * copa * 0.18, ht * 0.95),
                 tronco, seg=8, r2=0.06, rot=(0, 0.75, ang))
    for i in range(n_bolhas):
        ang = random.uniform(0, 2 * math.pi)
        rr = random.uniform(0.15, 0.75) * copa
        h = ht + copa * 0.25 + random.uniform(-0.35, 0.65) * copa * 0.6
        r = random.uniform(0.38, 0.55) * copa
        esfera(r, (rr * math.cos(ang), rr * math.sin(ang), h), random.choice(FOLHA), sub=2,
               esc=(1, 1, 0.82), ruido=0.18, semente=i + semente * 10)


def pinheiro(semente):
    random.seed(semente)
    cilindro(0.18, 1.4, (0, 0, 0.7), M("tronco", "#7a5232"), seg=8, r2=0.12)
    verdes = [M("pinho_a", "#2f6e3a"), M("pinho_b", "#3b7f43")]
    for i in range(4):
        r = 1.45 - i * 0.3
        cilindro(r, 1.7, (0, 0, 1.6 + i * 0.95), random.choice(verdes), seg=9, r2=0.08,
                 rot=(0, 0, random.uniform(0, 1)))


def arbusto(semente):
    random.seed(semente)
    for i in range(5):
        ang = random.uniform(0, 2 * math.pi)
        esfera(random.uniform(0.32, 0.5), (math.cos(ang) * 0.35, math.sin(ang) * 0.3, 0.32),
               random.choice(FOLHA), ruido=0.15, semente=i + semente)


def flores(cor):
    random.seed(len(cor))
    esfera(0.22, (0, 0, 0.08), FOLHA[0], esc=(1.3, 1.1, 0.5), ruido=0.2)
    for i in range(6):
        ang = random.uniform(0, 2 * math.pi)
        rr = random.uniform(0.05, 0.3)
        x, y = rr * math.cos(ang), rr * math.sin(ang)
        h = random.uniform(0.18, 0.32)
        cilindro(0.012, h, (x, y, h / 2), FOLHA[2], seg=5)
        for p in range(5):
            pa = p * 2 * math.pi / 5
            esfera(0.045, (x + 0.05 * math.cos(pa), y + 0.05 * math.sin(pa), h), FLOR[cor], sub=1,
                   esc=(1, 1, 0.45))
        esfera(0.03, (x, y, h + 0.01), MIOLO, sub=1)


def poste_luz():
    cilindro(0.17, 0.3, (0, 0, 0.15), PRETO, seg=10, r2=0.13)
    cilindro(0.06, 2.2, (0, 0, 1.4), PRETO, seg=8)
    caixa((0.26, 0.26, 0.36), (0, 0, 2.68), LUZ, 0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            caixa((0.04, 0.04, 0.4), (sx * 0.14, sy * 0.14, 2.68), PRETO, 0.0)
    caixa((0.34, 0.34, 0.05), (0, 0, 2.48), PRETO, 0.01)
    cilindro(0.27, 0.22, (0, 0, 2.97), PRETO, seg=4, r2=0.04, rot=(0, 0, math.pi / 4))
    esfera(0.05, (0, 0, 3.1), PRETO, sub=1)


def escada(n=8, h_total=2.5, larg=2.4, prof=0.38):
    random.seed(11)
    hs = h_total / n
    for i in range(n):
        caixa((larg, prof, (i + 1) * hs), (0, i * prof + prof / 2, (i + 1) * hs / 2), random.choice(PEDRA), 0.03)
    for s in (-1, 1):
        for i in range(n):
            hh = (i + 1) * hs + 0.35
            caixa((0.42, prof + 0.01, hh), (s * (larg / 2 + 0.21), i * prof + prof / 2, hh / 2), PEDRA[1], 0.05)


def paredao(W, H, semente):
    random.seed(semente)
    caixa((W, 0.8, H), (0, 0.4, H / 2), PEDRA[1], 0.0)
    z = 0.0
    while z < H - 0.05:
        rh = random.uniform(0.55, 0.9)
        if H - z - rh < 0.35:
            rh = H - z
        x = -W / 2 + random.uniform(-0.4, 0.0)
        while x < W / 2:
            bw = random.uniform(0.7, 1.6)
            x0, x1 = max(x, -W / 2), min(x + bw, W / 2)
            if x1 - x0 > 0.2:
                caixa((x1 - x0 - 0.05, 0.5, rh - 0.05),
                      ((x0 + x1) / 2, 0.25 - random.uniform(0.04, 0.2), z + rh / 2),
                      random.choice(PEDRA), 0.1, rot=(random.uniform(-0.03, 0.03), 0, random.uniform(-0.03, 0.03)))
            x += bw
        z += rh
    caixa((W, 0.4, 0.14), (0, 0.05, H + 0.03), M("grama_borda", "#5ea83a"), 0.05)


# ---------------------------------------------------------------- personagens
def treinador():
    pele = M("pele", "#f1c7a0", 0.7)
    camisa = M("camisa", "#d8433b", 0.8)
    jeans = M("jeans", "#2f4a7a", 0.9)
    cabelo = M("cabelo", "#3b2618", 0.8)
    bone = M("bone", "#d63a32", 0.7)
    for sx in (-1, 1):
        esfera(0.11, (sx * 0.1, -0.03, 0.07), BRANCO, esc=(0.9, 1.35, 0.6))
        esfera(0.06, (sx * 0.1, -0.03, 0.03), M("sola", "#c23a32"), esc=(1.6, 2.4, 0.5))
        cilindro(0.075, 0.36, (sx * 0.1, 0, 0.3), jeans, seg=10)
        cilindro(0.05, 0.3, (sx * 0.25, 0, 0.66), pele, seg=8, rot=(0, sx * 0.22, 0))
        esfera(0.08, (sx * 0.22, 0, 0.81), camisa, sub=2)
        esfera(0.055, (sx * 0.285, 0, 0.5), M("luva", "#3a3a40", 0.8), sub=2)
    esfera(0.17, (0, 0, 0.5), jeans, esc=(1.15, 0.85, 0.6))
    esfera(0.2, (0, 0, 0.7), camisa, esc=(1, 0.75, 1.1))
    esfera(0.27, (0, 0, 1.1), pele, sub=3)
    esfera(0.28, (0, 0.06, 1.13), cabelo, sub=3)
    esfera(0.292, (0, 0.01, 1.17), bone, sub=3, esc=(1, 1, 0.82), metade=True)
    cilindro(0.2, 0.025, (0, -0.27, 1.19), bone, seg=16, esc=(1, 0.85, 1))
    esfera(0.035, (0, 0.01, 1.41), bone, sub=1)
    for sx in (-1, 1):
        esfera(0.04, (sx * 0.09, -0.245, 1.08), PRETO, sub=1, esc=(0.7, 0.4, 1.1))
    # mochila (com folha, sem nada de marca famosa)
    caixa((0.32, 0.18, 0.34), (0, 0.18, 0.74), M("mochila", "#e8b53a"), 0.07)
    caixa((0.33, 0.06, 0.15), (0, 0.27, 0.86), M("mochila_esc", "#c9932a"), 0.03)
    esfera(0.06, (0, 0.285, 0.7), FOLHA[1], esc=(0.7, 0.3, 1.2))
    for sx in (-1, 1):
        caixa((0.05, 0.36, 0.05), (sx * 0.1, 0.0, 0.88), M("alca", "#3a3a40"), 0.01, rot=(0.25, 0, 0))


def criatura():
    azul = M("criatura_azul", "#4aa3e8", 0.55)
    azul_esc = M("criatura_azul_esc", "#2f7fcf", 0.55)
    barriga = M("criatura_barriga", "#f4f7fb", 0.6)
    esfera(0.42, (0, 0, 0.52), azul, sub=3, esc=(0.95, 0.85, 1.25))
    esfera(0.33, (0, -0.2, 0.46), barriga, sub=3, esc=(0.82, 0.62, 1.05))
    esfera(0.14, (0, -0.33, 0.8), barriga, sub=2, esc=(1.1, 0.9, 0.75))
    for sx in (-1, 1):
        esfera(0.055, (sx * 0.15, -0.3, 0.9), PRETO, sub=2)
        esfera(0.018, (sx * 0.15 - 0.015, -0.35, 0.92), BRANCO, sub=1)
        esfera(0.16, (sx * 0.37, -0.03, 0.5), azul, esc=(0.45, 0.6, 1.1), rot=(0, sx * 0.6, 0))
        esfera(0.11, (sx * 0.16, -0.12, 0.05), azul_esc, esc=(1, 1.4, 0.5))
        esfera(0.13, (sx * 0.17, 0.78, 0.26), azul_esc, esc=(1.1, 0.6, 0.35), rot=(0, 0, sx * 0.5))
    cilindro(0.17, 0.42, (0, 0.06, 1.12), azul_esc, seg=12, r2=0.0, esc=(0.35, 1, 1), rot=(-0.45, 0, 0))
    esfera(0.25, (0, 0.42, 0.22), azul, esc=(0.6, 1.4, 0.38), rot=(0.25, 0, 0))


# ---------------------------------------------------------------- gerar tudo
relatorio = {}


def gera(nome, fn, *a, **k):
    fn(*a, **k)
    relatorio[nome] = exportar(nome)


gera("casa_pescador", casa, "casa_pescador", 5.6, 4.0, M("telhado_azul", "#3f84dc", 0.6),
     M("telhado_azul_esc", "#2c62b5", 0.6), M("porta_azul", "#2f63b0", 0.6), MADEIRA,
     placa="PESCADOR", boia=True, peixe=True)
gera("casa_vermelha", casa, "casa_vermelha", 4.2, 3.6, M("telhado_verm", "#d9443a", 0.6),
     M("telhado_verm_esc", "#ac2f29", 0.6), M("porta_marrom", "#7a4a28", 0.7), BRANCO, chamine=True)
gera("cerca", cerca)
gera("cerca_poste", caixa, (0.24, 0.24, 1.15), (0, 0, 0.575), MADEIRA_CLARA, 0.05)
gera("barril", barril)
gera("deck", deck)
for i, e in enumerate(((0.9, 0.75, 0.6), (0.6, 0.55, 0.5), (1.2, 0.8, 0.7))):
    gera(f"pedra_{i + 1}", pedra, i + 1, e)
gera("arvore_grande", arvore, 6.8, 3.2, 5, 18)
gera("arvore_media", arvore, 4.2, 1.8, 9, 10)
gera("pinheiro", pinheiro, 2)
gera("arbusto", arbusto, 4)
for c in ("vermelha", "branca", "amarela"):
    gera(f"flores_{c}", flores, c)
gera("poste_luz", poste_luz)
gera("escada", escada)
gera("paredao", paredao, 6.0, 2.5, 21)
gera("paredao_alto", paredao, 6.0, 5.0, 33)

treinador()
juntar("treinador")
retrato("retrato_treinador", (0, 0, 1.12), 2.2, 0.05)
relatorio["treinador"] = exportar("treinador")
criatura()
juntar("criatura")
retrato("retrato_criatura", (0, -0.1, 0.6), 3.2, 0.2)
relatorio["criatura"] = exportar("criatura")

print("RESUMO", relatorio, "total", sum(relatorio.values()))
