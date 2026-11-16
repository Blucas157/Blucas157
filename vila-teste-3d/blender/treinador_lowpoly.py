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


def cabeca_lp(nome, centro, r, material=None):
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
    me.materials.append(material or CINZA)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    o.location = centro
    return o


# ------------------------------------------------------------ cores provisorias (texturas vem na etapa 4)
PELE = mat("pele", (0.9, 0.62, 0.48))
JAQUETA = mat("jaqueta", (0.7, 0.06, 0.05))
BRANCO = mat("branco", (0.86, 0.85, 0.82))
JEANS = mat("jeans", (0.06, 0.13, 0.36))
CABELO = mat("cabelo", (0.08, 0.035, 0.015))
SOLA = mat("sola", (0.75, 0.75, 0.75))
POCHETE = mat("pochete", (0.88, 0.47, 0.03))
PRETO = mat("preto", (0.02, 0.02, 0.025))


def caixa_lp(nome, centro, tam, material, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(tam) * H, verts=bm.verts)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    o.location = centro
    o.rotation_euler = rot
    return o


def cabelo_lp(centro, rx, ry, rz, n_lon=18, n_lat=5):
    """Casca de cabelo low-poly com borda em zigue-zague: franja na frente,
    mechas ate o queixo dos lados e pontas na nuca."""
    bm = bmesh.new()
    topo = bm.verts.new(centro + Vector((0, 0, rz * H)))
    colunas = []
    for k in range(n_lon):
        th = 2 * math.pi * k / n_lon  # 0 = frente
        a = abs(math.degrees(math.atan2(math.sin(th), math.cos(th))))  # 0..180
        if a < 40:
            fim = 64          # franja (acima dos olhos)
        elif a < 75:
            fim = 64 + (a - 40) / 35 * 52  # desce ate o queixo
        elif a < 120:
            fim = 116         # mechas dos lados
        else:
            fim = 116 + (a - 120) / 60 * 18  # nuca
        ponta = (k % 2 == 0)
        col = []
        for i in range(1, n_lat + 1):
            phi = math.radians(fim * i / n_lat)
            esp = 1.0
            if i == n_lat:
                phi += math.radians(16 if ponta else -6)
                esp = 1.12 if ponta else 0.96
            if a < 40 and i == n_lat:
                esp = 1.0
            p = Vector((math.sin(phi) * math.sin(th) * rx * esp, -math.sin(phi) * math.cos(th) * ry * esp,
                        math.cos(phi) * rz)) * H
            col.append(bm.verts.new(centro + p))
        colunas.append(col)
    for k in range(n_lon):
        a, b = colunas[k], colunas[(k + 1) % n_lon]
        bm.faces.new((topo, a[0], b[0]))
        for i in range(n_lat - 1):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new("cabelo")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(CABELO)
    o = bpy.data.objects.new("cabelo", me)
    CENA.collection.objects.link(o)
    return o


def calota(nome, centro, rx, ry, rz, material, n=12, aneis=4):
    """Meia elipsoide low-poly (copa do bone)."""
    bm = bmesh.new()
    topo = bm.verts.new(centro + Vector((0, 0, rz * H)))
    lacos = []
    for i in range(1, aneis + 1):
        phi = math.radians(90 * i / aneis)
        laco = []
        for k in range(n):
            th = 2 * math.pi * k / n
            laco.append(bm.verts.new(centro + Vector((math.sin(phi) * math.sin(th) * rx,
                                                      -math.sin(phi) * math.cos(th) * ry,
                                                      math.cos(phi) * rz)) * H))
        lacos.append(laco)
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((topo, lacos[0][k], lacos[0][j]))
        for i in range(aneis - 1):
            bm.faces.new((lacos[i][k], lacos[i + 1][k], lacos[i + 1][j], lacos[i][j]))
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


# ------------------------------------------------------------ pernas (jeans) com barra dobrada
for s in (-1, 1):
    tubo("perna", [(v(s * 0.038, 0.0, 0.085), 0.026, 0.028),
                   (v(s * 0.039, 0.0, 0.17), 0.031, 0.034),
                   (v(s * 0.038, -0.004, 0.27), 0.029, 0.031),
                   (v(s * 0.040, -0.002, 0.36), 0.038, 0.040),
                   (v(s * 0.042, 0.0, 0.44), 0.046, 0.048)], tampa_fim=False, material=JEANS)
    tubo("barra", [(v(s * 0.038, 0.0, 0.07), 0.031, 0.033), (v(s * 0.038, 0.0, 0.1), 0.031, 0.033)],
         material=JEANS)
# ------------------------------------------------------------ tronco (jaqueta)
tubo("quadril", [(v(0, 0.0, 0.405), 0.058, 0.041), (v(0, 0.0, 0.44), 0.074, 0.047),
                 (v(0, 0.0, 0.47), 0.075, 0.047)], n=10, material=JEANS)
tubo("tronco", [(v(0, 0.0, 0.452), 0.079, 0.05),
                (v(0, 0.0, 0.53), 0.068, 0.044),
                (v(0, -0.002, 0.61), 0.072, 0.047),
                (v(0, -0.004, 0.69), 0.080, 0.052),
                (v(0, 0.0, 0.745), 0.084, 0.048),
                (v(0, 0.004, 0.775), 0.050, 0.038),
                (v(0, 0.006, 0.80), 0.024, 0.024),
                (v(0, 0.006, 0.83), 0.022, 0.022)], n=10, material=JAQUETA)
tubo("pescoco", [(v(0, 0.006, 0.79), 0.022, 0.022), (v(0, 0.006, 0.85), 0.021, 0.021)], n=8, material=PELE)
# faixa branca na barra, gola alta branca e ziper
tubo("barra_jaq", [(v(0, 0.0, 0.452), 0.082, 0.052), (v(0, 0.0, 0.49), 0.076, 0.049)], n=10, material=BRANCO)
tubo("gola", [(v(0, 0.004, 0.775), 0.042, 0.036), (v(0, 0.006, 0.80), 0.036, 0.032),
              (v(0, 0.004, 0.825), 0.038, 0.034)], n=10, tampa_ini=False, tampa_fim=False, material=BRANCO)
caixa_lp("ziper", v(0, -0.05, 0.615), (0.012, 0.006, 0.31), BRANCO, rot=(0.02, 0, 0))
# ------------------------------------------------------------ bracos, punhos e maos com polegar
for s in (-1, 1):
    tubo("braco", [(v(s * 0.07, 0.0, 0.742), 0.027, 0.028),
                   (v(s * 0.088, 0.0, 0.73), 0.027, 0.027),
                   (v(s * 0.106, 0.0, 0.69), 0.024, 0.024),
                   (v(s * 0.128, 0.002, 0.60), 0.021, 0.020),
                   (v(s * 0.143, -0.004, 0.53), 0.019, 0.018),
                   (v(s * 0.149, -0.006, 0.5), 0.018, 0.017)], ref=Vector((0, 1, 0)), material=JAQUETA)
    tubo("punho", [(v(s * 0.149, -0.006, 0.502), 0.021, 0.02), (v(s * 0.153, -0.006, 0.48), 0.02, 0.019)],
         ref=Vector((0, 1, 0)), material=BRANCO)
    tubo("mao", [(v(s * 0.154, -0.006, 0.48), 0.011, 0.016),
                 (v(s * 0.159, -0.008, 0.45), 0.011, 0.02),
                 (v(s * 0.161, -0.010, 0.418), 0.009, 0.016),
                 (v(s * 0.161, -0.010, 0.405), 0.006, 0.01)], n=6, ref=Vector((0, 1, 0)), material=PELE)
    tubo("polegar", [(v(s * 0.154, -0.02, 0.465), 0.006, 0.006), (v(s * 0.154, -0.03, 0.44), 0.005, 0.005)],
         n=5, material=PELE)
# ------------------------------------------------------------ tenis: cano, corpo, lingua e sola
for s in (-1, 1):
    x = s * 0.039
    tubo("tenis", [(v(x, 0.034, 0.05), 0.026, 0.024),
                   (v(x, 0.006, 0.058), 0.031, 0.036),
                   (v(x, -0.03, 0.04), 0.031, 0.026),
                   (v(x, -0.062, 0.03), 0.027, 0.018),
                   (v(x, -0.074, 0.03), 0.018, 0.012)], ref=Vector((1, 0, 0)), material=JAQUETA)
    tubo("lingua", [(v(x, -0.004, 0.075), 0.017, 0.006), (v(x, -0.022, 0.06), 0.017, 0.006)],
         ref=Vector((1, 0, 0)), material=BRANCO)
    tubo("sola", [(v(x, 0.04, 0.012), 0.029, 0.011), (v(x, 0.0, 0.012), 0.033, 0.012),
                  (v(x, -0.05, 0.012), 0.033, 0.012), (v(x, -0.08, 0.014), 0.024, 0.01)],
         ref=Vector((1, 0, 0)), material=BRANCO)
# ------------------------------------------------------------ cabeca, orelhas, cabelo e bone
cabeca_lp("cabeca", v(0, 0.0, 0.9), 0.078, material=PELE)
for s in (-1, 1):
    tubo("orelha", [(v(s * 0.068, 0.006, 0.9), 0.006, 0.013), (v(s * 0.076, 0.008, 0.9), 0.005, 0.011)],
         n=6, material=PELE)
cabelo_lp(v(0, 0.006, 0.9), 0.084, 0.088, 0.094)
calota("bone", v(0, 0.008, 0.94), 0.084, 0.089, 0.074, JAQUETA)
tubo("aba", [(v(0, -0.074, 0.946), 0.066, 0.008), (v(0, -0.11, 0.934), 0.06, 0.008),
             (v(0, -0.136, 0.922), 0.042, 0.007)], n=8, ref=Vector((1, 0, 0)), material=JAQUETA)
tubo("botao", [(v(0, 0.008, 1.012), 0.009, 0.009), (v(0, 0.008, 1.02), 0.005, 0.005)], n=6, material=BRANCO)
# ------------------------------------------------------------ pochete amarela na cintura (no lugar da mochila)
tubo("cinto", [(v(0, 0.0, 0.43), 0.076, 0.049), (v(0, 0.0, 0.44), 0.077, 0.049)], n=10,
     tampa_ini=False, tampa_fim=False, material=PRETO)
tubo("pochete", [(v(0.03, -0.05, 0.425), 0.009, 0.024), (v(0.055, -0.054, 0.43), 0.022, 0.03),
                 (v(0.08, -0.046, 0.435), 0.009, 0.022)], n=8, ref=Vector((0, 1, 0)), material=POCHETE)

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
    for nome, pos in (("frente", (0, -5, H / 2)), ("34", (3.5, -3.5, H / 2)), ("lado", (5, 0, H / 2)),
                      ("costas", (0, 5, H / 2))):
        cam.location = pos
        cam.rotation_euler = (Vector((0, 0, H / 2)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        r.filepath = f"{base}_{nome}{ext}"
        bpy.ops.render.render(write_still=True)
