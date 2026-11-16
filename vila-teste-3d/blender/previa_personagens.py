# Renderiza os personagens de frente e de costas (para conferir o design).
import bpy, sys, os, math
from mathutils import Vector
pasta, saida = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene
for i, (nome, x, rz) in enumerate((("treinador", -1.3, 0), ("treinador", -0.45, math.pi), ("criatura", 0.45, 0), ("criatura", 1.35, math.pi * 0.75))):
    bpy.ops.import_scene.gltf(filepath=os.path.join(pasta, nome + ".glb"))
    for o in bpy.context.selected_objects:
        if o.parent is None:
            o.location.x = x
            o.rotation_mode = "XYZ"
            o.rotation_euler.z = rz
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cena.collection.objects.link(cam)
cam.location = (0, -6, 1.6)
cam.rotation_euler = (Vector((0, 0, 0.65)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 60
cena.camera = cam
for loc, en in (((-3, -4, 5), 3.5), ((2, -3, 1), 1.2), ((0, 4, 3), 2.0)):
    l = bpy.data.objects.new("l", bpy.data.lights.new("l", "SUN"))
    l.data.energy = en
    cena.collection.objects.link(l)
    l.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
cena.world = bpy.data.worlds.new("w")
cena.world.color = (0.55, 0.7, 0.85)
r = cena.render
r.engine = "CYCLES"
cena.cycles.samples = 48
r.resolution_x, r.resolution_y = 1200, 600
r.use_freestyle = True
r.line_thickness = 1.5
cena.view_layers[0].freestyle_settings.linesets.new("linhas")
r.filepath = saida
bpy.ops.render.render(write_still=True)
