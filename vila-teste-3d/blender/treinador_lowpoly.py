# Treinador original no jeito dos modelos de 3DS: malha simples (low-poly) feita de
# "aneis" ligados (loft), proporcao de adolescente (~5 cabecas). Etapa 1 = so a forma.
# Uso: python treinador_lowpoly.py <saida.glb> [previa.png]
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

H = 1.55  # altura do personagem (m). Todas as medidas abaixo sao fracao de H.
args = [a for a in sys.argv[1:] if not a.startswith("-")]
SAIDA = args[0] if args else "treinador_lp.glb"
PREVIA = args[1] if len(args) > 1 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
CENA = bpy.context.scene


def mat(nome, cor):
    m = bpy.data.materials.new(nome)
    m.diffuse_color = (*cor, 1)
    try:
        m.use_nodes = True
    except Exception:
        pass
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*cor, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    return m


CINZA = mat("forma", (0.6, 0.6, 0.62))


def v(x, y, z):
    return Vector((x * H, y * H, z * H))


def tubo(nome, aneis, n=8, tampa_ini=True, tampa_fim=True, material=CINZA, ref=Vector((1, 0, 0))):
    """aneis = [(centro, rx, ry, (opcional) giro)]. Cada anel fica perpendicular ao caminho."""
    bm = bmesh.new()
    cs = [a[0] for a in aneis]
    lacos = []
    for i, a in enumerate(aneis):
        c, rx, ry = a[0], a[1] * H, a[2] * H
        t = (cs[min(i + 1, len(cs) - 1)] - cs[max(i - 1, 0)]).normalized()
        eixo_x = (ref - t * ref.dot(t)).normalized()
        eixo_y = t.cross(eixo_x).normalized()
        laco = []
        for k in range(n):
            ang = 2 * math.pi * k / n + math.pi / n
            p = c + eixo_x * math.cos(ang) * rx + eixo_y * math.sin(ang) * ry
            laco.append(bm.verts.new(p))
        lacos.append(laco)
    for a, b in zip(lacos, lacos[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if tampa_ini:
        bm.faces.new(list(reversed(lacos[0])))
    if tampa_fim:
        bm.faces.new(lacos[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    return o


def cabeca_lp(nome, centro, r, material=CINZA):
    """Cabeca low-poly: esfera de 12x9 com queixo afinado e nuca cheia."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=9, radius=r * H)
    for vt in bm.verts:
        co = vt.co / (r * H)
        if co.z < 0:  # parte de baixo: afina para formar o queixo
            f = 1 - 0.35 * (-co.z)
            vt.co.x *= f
            if co.y < 0:
                vt.co.y *= 1 - 0.1 * (-co.z)
                vt.co.z *= 1.12
            else:
                vt.co.y *= f
        vt.co.x *= 0.9
        vt.co.y *= 0.98
        vt.co.z *= 1.08
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    o.location = centro
    return o


# ------------------------------------------------------------ corpo
# pernas (calca): do tornozelo ate a virilha
for s in (-1, 1):
    tubo("perna", [(v(s * 0.038, 0.0, 0.07), 0.024, 0.026),
                   (v(s * 0.039, 0.0, 0.17), 0.031, 0.034),
                   (v(s * 0.038, -0.004, 0.27), 0.029, 0.031),
                   (v(s * 0.040, -0.002, 0.36), 0.038, 0.040),
                   (v(s * 0.042, 0.0, 0.44), 0.046, 0.048)], tampa_fim=False)
# quadril + tronco + pescoco num tubo so
tubo("tronco", [(v(0, 0.0, 0.415), 0.060, 0.042),
                (v(0, 0.0, 0.46), 0.078, 0.048),
                (v(0, 0.0, 0.53), 0.068, 0.044),
                (v(0, -0.002, 0.61), 0.072, 0.047),
                (v(0, -0.004, 0.69), 0.080, 0.052),
                (v(0, 0.0, 0.745), 0.084, 0.048),
                (v(0, 0.004, 0.775), 0.050, 0.038),
                (v(0, 0.006, 0.80), 0.024, 0.024),
                (v(0, 0.006, 0.83), 0.022, 0.022)], n=10)
# bracos levemente abertos (pose A), com mao simples
for s in (-1, 1):
    tubo("braco", [(v(s * 0.082, 0.0, 0.748), 0.026, 0.026),
                   (v(s * 0.106, 0.0, 0.69), 0.024, 0.024),
                   (v(s * 0.128, 0.002, 0.60), 0.021, 0.020),
                   (v(s * 0.145, -0.004, 0.52), 0.018, 0.017),
                   (v(s * 0.152, -0.006, 0.478), 0.016, 0.015)], ref=Vector((0, 1, 0)))
    tubo("mao", [(v(s * 0.154, -0.006, 0.472), 0.012, 0.017),
                 (v(s * 0.159, -0.008, 0.445), 0.011, 0.020),
                 (v(s * 0.161, -0.010, 0.415), 0.009, 0.015)], n=6, ref=Vector((0, 1, 0)))
# tenis: tubo deitado do calcanhar ate a ponta
for s in (-1, 1):
    tubo("tenis", [(v(s * 0.038, 0.034, 0.033), 0.025, 0.026),
                   (v(s * 0.039, 0.004, 0.040), 0.030, 0.036),
                   (v(s * 0.040, -0.034, 0.030), 0.030, 0.028),
                   (v(s * 0.041, -0.066, 0.022), 0.025, 0.019)], ref=Vector((1, 0, 0)))
# cabeca
cabeca_lp("cabeca", v(0, 0.0, 0.9), 0.078)
# cabelo: casca um pouco maior, cobrindo tras, lados e topo
cab = cabeca_lp("cabelo", v(0, 0.014, 0.915), 0.088)
bm = bmesh.new()
bm.from_mesh(cab.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -0.02 * H and f.calc_center_median().z < 0.012 * H],
                 context="FACES")
bm.to_mesh(cab.data)
bm.free()
# bone: copa + aba (fica no alto da cabeca)
copa = cabeca_lp("bone", v(0, 0.008, 0.935), 0.091)
bm = bmesh.new()
bm.from_mesh(copa.data)
bmesh.ops.delete(bm, geom=[vt for vt in bm.verts if vt.co.z < 0.012 * H], context="VERTS")
bm.to_mesh(copa.data)
bm.free()
tubo("aba", [(v(0, -0.05, 0.952), 0.066, 0.004), (v(0, -0.1, 0.944), 0.055, 0.004)], n=8,
     ref=Vector((1, 0, 0)))
# mochila
tubo("mochila", [(v(0, 0.05, 0.54), 0.052, 0.028), (v(0, 0.063, 0.6), 0.06, 0.036),
                 (v(0, 0.063, 0.68), 0.058, 0.035), (v(0, 0.05, 0.72), 0.048, 0.025)], n=8)

# ------------------------------------------------------------ juntar, contar e exportar
malhas = [o for o in CENA.objects if o.type == "MESH"]
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in malhas)
print("TRIANGULOS", tris)
for o in CENA.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = malhas[0]
bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True)

if PREVIA:  # 3 vistas (frente, lado, costas) com camera ortografica
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    CENA.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = H * 1.15
    CENA.camera = cam
    sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    sol.data.energy = 3.5
    CENA.collection.objects.link(sol)
    sol.rotation_euler = (0.8, 0, -0.6)
    CENA.world = bpy.data.worlds.new("w")
    CENA.world.color = (0.75, 0.75, 0.78)
    r = CENA.render
    r.engine = "CYCLES"
    CENA.cycles.samples = 16
    r.resolution_x, r.resolution_y = 600, 800
    base, ext = os.path.splitext(PREVIA)
    for nome, pos in (("frente", (0, -5, H / 2)), ("lado", (5, 0, H / 2)), ("costas", (0, 5, H / 2))):
        cam.location = pos
        cam.rotation_euler = (Vector((0, 0, H / 2)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        r.filepath = f"{base}_{nome}{ext}"
        bpy.ops.render.render(write_still=True)
