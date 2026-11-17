# Prepara um modelo gerado por IA (Tripo/Meshy) para o jogo:
#  - junta as malhas, poe os pes no chao, ajusta a altura;
#  - baixa os bracos da pose T para uma pose relaxada (so na altura dos bracos);
#  - cria uma copia leve para o celular, com UV novo, e TRANSFERE (bake) a cor do modelo original;
#  - exporta .glb para o Godot.
# Uso: python preparar_modelo_ia.py <entrada.glb> <saida.glb> [altura_m] [triangulos] [graus_braco]
import bpy, sys, math, os

args = [a for a in sys.argv[1:] if not a.startswith("--")]
ENTRADA, SAIDA = args[0], os.path.abspath(args[1])
ALTURA = float(args[2]) if len(args) > 2 else 1.55
ALVO = int(args[3]) if len(args) > 3 else 8000
GRAUS = float(args[4]) if len(args) > 4 else 68.0
TEX_MAX = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ENTRADA)
cena = bpy.context.scene
malhas = [o for o in cena.objects if o.type == "MESH"]
for o in cena.objects:
    o.select_set(o in malhas)
bpy.context.view_layer.objects.active = malhas[0]
if len(malhas) > 1:
    bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for x in list(cena.objects):
    if x != o:
        bpy.data.objects.remove(x, do_unlink=True)

# ---------------------------------------------------------------- pes no chao e altura certa
me = o.data
n = len(me.vertices)
import numpy as np
co = np.empty(n * 3, np.float32)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
esc = ALTURA / (co[:, 2].max() - co[:, 2].min())
off = np.array([(co[:, 0].max() + co[:, 0].min()) / 2, (co[:, 1].max() + co[:, 1].min()) / 2, co[:, 2].min()])
co = (co - off) * esc

# ---------------------------------------------------------------- baixar os bracos (so na altura deles)
largura = np.abs(co[:, 0]).max()
if GRAUS and largura > ALTURA * 0.3:
    bracos = co[np.abs(co[:, 0]) > ALTURA * 0.25]
    z_braco = float(bracos[:, 2].mean())
    x_ombro = ALTURA * 0.11
    z_min = z_braco - ALTURA * 0.09
    ax = np.abs(co[:, 0])
    w = np.clip((ax - (x_ombro - ALTURA * 0.02)) / (ALTURA * 0.07), 0, 1)
    w = w * w * (3 - 2 * w)
    w *= np.clip((co[:, 2] - z_min) / (ALTURA * 0.03), 0, 1)
    lado = np.where(co[:, 0] > 0, 1.0, -1.0)
    th = np.radians(GRAUS) * w * lado
    px = co[:, 0] - lado * x_ombro
    pz = co[:, 2] - z_braco
    co[:, 0] = px * np.cos(th) + pz * np.sin(th) + lado * x_ombro
    co[:, 2] = -px * np.sin(th) + pz * np.cos(th) + z_braco
    print("BRACOS baixados", GRAUS, "graus; ombro em z =", round(z_braco, 3))
me.vertices.foreach_set("co", co.ravel())
me.update()

# ---------------------------------------------------------------- copia leve com UV novo
alto = o
baixo = alto.copy()
baixo.data = alto.data.copy()
cena.collection.objects.link(baixo)
tris = sum(len(p.vertices) - 2 for p in alto.data.polygons)
bpy.context.view_layer.objects.active = baixo
for x in cena.objects:
    x.select_set(x == baixo)
import bmesh
bm = bmesh.new()
bm.from_mesh(baixo.data)
antes = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=ALTURA * 1e-5)  # solda as emendas da textura
print("SOLDA", antes, "->", len(bm.verts), "vertices")
bm.to_mesh(baixo.data)
bm.free()
d = baixo.modifiers.new("reduzir", "DECIMATE")
d.ratio = min(1.0, ALVO / tris)
bpy.ops.object.modifier_apply(modifier="reduzir")
baixo.data.shade_smooth()
while baixo.data.uv_layers:
    baixo.data.uv_layers.remove(baixo.data.uv_layers[0])
baixo.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.008)
bpy.ops.object.mode_set(mode="OBJECT")
print("TRIANGULOS", tris, "->", sum(len(p.vertices) - 2 for p in baixo.data.polygons))

# ---------------------------------------------------------------- bake da cor: original -> copia leve
nome = os.path.splitext(os.path.basename(SAIDA))[0]
img = bpy.data.images.new("cor_" + nome, TEX_MAX, TEX_MAX)
mat = bpy.data.materials.new("cor_" + nome)
try:
    mat.use_nodes = True
except Exception:
    pass
nt = mat.node_tree
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = img
nt.links.new(tx.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
nt.nodes.active = tx
baixo.data.materials.clear()
baixo.data.materials.append(mat)

cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 1
bk = cena.render.bake
bk.use_pass_direct = False
bk.use_pass_indirect = False
bk.use_pass_color = True
bk.use_selected_to_active = True
bk.cage_extrusion = ALTURA * 0.02
bk.max_ray_distance = ALTURA * 0.1
bk.margin = 16
for x in cena.objects:
    x.select_set(x in (alto, baixo))
bpy.context.view_layer.objects.active = baixo
bpy.ops.object.bake(type="DIFFUSE")
pasta_tex = os.path.join(os.path.dirname(os.path.abspath(__file__)), "texturas")
os.makedirs(pasta_tex, exist_ok=True)
img.filepath_raw = os.path.join(pasta_tex, nome + "_cor.png")  # copia de trabalho (fora do projeto Godot)
img.file_format = "PNG"
img.save()
img.pack()
print("BAKE ok")
bpy.data.objects.remove(alto, do_unlink=True)

# ---------------------------------------------------------------- exportar
baixo.name = nome
for x in cena.objects:
    x.select_set(x == baixo)
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True,
                          export_image_format="AUTO")
print("EXPORTADO", SAIDA, os.path.getsize(SAIDA) // 1024, "KB")
