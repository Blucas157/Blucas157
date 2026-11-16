extends Node3D
## Monta a Vila do Pescador inteira em codigo (teste de estilo 3D).
## Os modelos vem do Blender (pasta modelos/, gerados por blender/gerar_assets.py).

const MODELOS := "res://modelos/"
var rng := RandomNumberGenerator.new()
var caminho: Array[Vector3] = []  # discos de terra (x, z, raio)
var _cache := {}


func _ready() -> void:
	rng.seed = 42
	_ambiente()
	_terreno()
	_agua()
	_caminhos()
	_construcoes()
	_natureza()
	_grama()
	_personagens()
	_camera()
	add_child(preload("res://Interface.gd").new())
	_talvez_capturar()


# ------------------------------------------------------------------ util
func modelo(nome: String, pos: Vector3, rot_y := 0.0, escala := 1.0) -> Node3D:
	if not _cache.has(nome):
		_cache[nome] = load(MODELOS + nome + ".glb")
	var n: Node3D = _cache[nome].instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * escala
	add_child(n)
	return n


func textura_ruido(c1: Color, c2: Color, freq := 0.02, semente := 1) -> NoiseTexture2D:
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.frequency = freq
	ruido.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, c1)
	grad.set_color(1, c2)
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = ruido
	t.color_ramp = grad
	return t


func material_chao(c1: Color, c2: Color, escala := 0.12, semente := 1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = textura_ruido(c1, c2, 0.012, semente)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * escala
	m.roughness = 0.95
	return m


func caixa(tam: Vector3, centro: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = centro
	add_child(mi)
	return mi


func perto_do_caminho(x: float, z: float, folga := 0.0) -> bool:
	for c in caminho:
		if Vector2(x - c.x, z - c.y).length() < c.z + folga:
			return true
	return false


# ------------------------------------------------------------------ ceu e luz
func _ambiente() -> void:
	var sol := DirectionalLight3D.new()
	add_child(sol)
	sol.look_at_from_position(Vector3(-9, 14, 9), Vector3.ZERO)
	sol.light_color = Color("fff1d6")
	sol.light_energy = 1.05
	sol.shadow_enabled = true
	sol.shadow_blur = 1.5
	sol.directional_shadow_max_distance = 55.0

	var ceu_mat := ProceduralSkyMaterial.new()
	ceu_mat.sky_top_color = Color("3b8be0")
	ceu_mat.sky_horizon_color = Color("bfe3ff")
	ceu_mat.ground_horizon_color = Color("bfe3ff")
	ceu_mat.ground_bottom_color = Color("6a8f5a")
	var ceu := Sky.new()
	ceu.sky_material = ceu_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("cfe6ff")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# nuvens fofas ao fundo
	var nuvem := StandardMaterial3D.new()
	nuvem.albedo_color = Color(1, 1, 1)
	nuvem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 6:
		var base := Vector3(rng.randf_range(-70, 70), rng.randf_range(24, 34), rng.randf_range(-95, -80))
		for k in 5:
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			var r := rng.randf_range(3.0, 5.5)
			s.radius = r
			s.height = r * 1.4
			mi.mesh = s
			mi.material_override = nuvem
			mi.position = base + Vector3(k * 3.6 - 7.0, rng.randf_range(-0.5, 1.5), 0)
			add_child(mi)


# ------------------------------------------------------------------ chao
func _terreno() -> void:
	var grama := material_chao(Color("3f8f2a"), Color("6cb33f"), 0.1, 3)
	var terra_lago := material_chao(Color("6d6a55"), Color("8c8466"), 0.2, 5)
	# chao de baixo (com recorte para o lago a direita)
	caixa(Vector3(34.5, 1, 19.6), Vector3(-12.75, -0.5, 2.2), grama)
	caixa(Vector3(25.5, 1, 8), Vector3(17.25, -0.5, 8), grama)
	caixa(Vector3(25.5, 1, 11.6), Vector3(17.25, -1.7, -1.8), terra_lago)
	# plato das casas vermelhas e plato do fundo
	caixa(Vector3(60, 4, 10), Vector3(0, 0.5, -12.6), grama)
	caixa(Vector3(60, 6, 28), Vector3(0, 4.5, -31.3), grama)
	# paredoes de pedra (fica um vao para a escada em x = -5)
	for x in [-28.0, -22.0, -16.0, -10.0, 0.0, 6.0, 12.0, 18.0, 24.0]:
		modelo("paredao", Vector3(x, 0, -7.55))
	for x in range(-27, 30, 6):
		modelo("paredao_alto", Vector3(x, 2.5, -17.3))
	modelo("escada", Vector3(-5, 0, -4.5))
	for x in [-7.0, -3.0]:
		modelo("pedra_3", Vector3(x, 0, -7.0), rng.randf() * TAU, 0.9)


func _agua() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 raso : source_color = vec4(0.30, 0.66, 0.90, 1.0);
uniform vec4 fundo : source_color = vec4(0.06, 0.33, 0.66, 1.0);
uniform vec4 ceu : source_color = vec4(0.78, 0.90, 1.0, 1.0);
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = mundo.xz;
	float t = TIME * 0.6;
	float w = sin(p.x * 1.7 + t) * 0.5 + sin(p.y * 2.3 - t * 1.3) * 0.5 + sin((p.x + p.y) * 3.1 + t * 2.0) * 0.25;
	vec3 n = normalize(vec3(cos(p.x * 1.7 + t) * 0.12 + cos((p.x + p.y) * 3.1 + t * 2.0) * 0.1, 1.0,
		cos(p.y * 2.3 - t * 1.3) * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 cor = mix(fundo.rgb, raso.rgb, 0.45 + 0.18 * w);
	ALBEDO = mix(cor, ceu.rgb, fres * 0.55);
	float brilho = smoothstep(0.93, 1.0, sin(p.x * 3.0 + sin(p.y * 2.0 + t) * 2.5 + t * 1.5));
	EMISSION = vec3(brilho * 0.35);
	ROUGHNESS = 0.06;
	SPECULAR = 0.8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(25.5, 11.6)
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(17.25, -0.32, -1.8)
	add_child(mi)
	# pedras da margem
	var z := -7.0
	while z < 4.2:
		modelo("pedra_%d" % rng.randi_range(1, 3), Vector3(4.6 + rng.randf_range(-0.15, 0.2), -0.35, z),
			rng.randf() * TAU, rng.randf_range(0.65, 0.95))
		z += rng.randf_range(0.8, 1.1)
	var x := 5.4
	while x < 22.0:
		modelo("pedra_%d" % rng.randi_range(1, 3), Vector3(x, -0.35, 4.1 + rng.randf_range(-0.1, 0.2)),
			rng.randf() * TAU, rng.randf_range(0.65, 0.95))
		x += rng.randf_range(0.8, 1.1)
	modelo("deck", Vector3(4.4, 0.0, -1.6))


# ------------------------------------------------------------------ caminhos de terra
func _trilha(pontos: Array, larg: float) -> void:
	for i in pontos.size() - 1:
		var a: Vector2 = pontos[i]
		var b: Vector2 = pontos[i + 1]
		var passos := int(a.distance_to(b) / 0.45) + 1
		for k in passos:
			var p := a.lerp(b, float(k) / passos)
			p += Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
			caminho.append(Vector3(p.x, p.y, larg * rng.randf_range(0.8, 1.1)))


func _caminhos() -> void:
	_trilha([Vector2(-5, -4.6), Vector2(-5.2, -1.5), Vector2(-6.5, 1.0), Vector2(-9.5, 3.5), Vector2(-14, 5.5)], 1.1)
	_trilha([Vector2(-6.0, 0.4), Vector2(-2.0, 0.2), Vector2(1.5, 0.4), Vector2(4.3, -1.5)], 0.85)
	_trilha([Vector2(0, -1.0), Vector2(0, 0.3)], 0.9)
	_trilha([Vector2(-16, -9.0), Vector2(-5, -9.1), Vector2(14, -9.0)], 0.9)
	var terra := material_chao(Color("a07445"), Color("c39a62"), 0.25, 9)
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.04
	disco.radial_segments = 20
	for c in caminho:
		var mi := MeshInstance3D.new()
		mi.mesh = disco
		mi.material_override = terra
		var y := 2.5 if c.y < -7.6 else 0.0
		mi.position = Vector3(c.x, y + 0.005, c.y)
		mi.scale = Vector3(c.z, 1, c.z)
		add_child(mi)


# ------------------------------------------------------------------ casas e objetos
func _construcoes() -> void:
	modelo("casa_pescador", Vector3(0, 0, -3.4))
	for x in [-13.0, -1.5, 5.5, 12.5]:
		modelo("casa_vermelha", Vector3(x, 2.5, -12.0), rng.randf_range(-0.05, 0.05))
	for p in [Vector3(-3.7, 0, -1.7), Vector3(-3.45, 0, -2.6), Vector3(3.6, 0, -1.6), Vector3(3.7, 0, -2.5)]:
		modelo("barril", p, rng.randf() * TAU)
	modelo("barril", Vector3(3.65, 0.94, -2.05), 0.4)
	for x in [-7.0, -3.0]:
		modelo("poste_luz", Vector3(x, 0, -4.2))
	for x in [-9.5, 2.0, 9.0]:
		modelo("poste_luz", Vector3(x, 2.5, -9.9))
	# cerca da frente
	var x := -12.0
	while x < 12.0:
		modelo("cerca", Vector3(x, 0, 5.7), 0.0)
		x += 2.0
	modelo("cerca_poste", Vector3(x, 0, 5.7))


func _natureza() -> void:
	modelo("arvore_grande", Vector3(4.1, 0, 2.0), 0.6)
	for p in [Vector3(-10, 0, -3.5), Vector3(-13, 0, 0.5), Vector3(-8.5, 0, -6.0)]:
		modelo("arvore_media", p, rng.randf() * TAU, rng.randf_range(0.9, 1.2))
	for x in [-16.5, -7.5, 2.0, 9.0, 16.0]:
		modelo("arvore_media", Vector3(x + rng.randf_range(-0.6, 0.6), 2.5, -14.5), rng.randf() * TAU,
			rng.randf_range(1.0, 1.3))
	for i in 40:
		var p := Vector3(rng.randf_range(-30, 30), 7.5, rng.randf_range(-19.5, -30))
		if rng.randf() < 0.65:
			modelo("pinheiro", p, rng.randf() * TAU, rng.randf_range(1.1, 1.6))
		else:
			modelo("arvore_media", p, rng.randf() * TAU, rng.randf_range(1.1, 1.5))
	for i in 9:
		var x := rng.randf_range(-15, 3.5)
		if absf(x + 5) < 2.2 or absf(x) < 3.2:
			continue
		modelo("arbusto", Vector3(x, 0, -6.9), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	for p in [Vector3(-2.2, 0, -5.3), Vector3(2.4, 0, -5.4), Vector3(-6.5, 0, 4.4), Vector3(2.9, 0, 3.6)]:
		modelo("arbusto", p, rng.randf() * TAU, 0.8)
	var cores := ["flores_vermelha", "flores_branca", "flores_amarela"]
	var colocadas := 0
	while colocadas < 34:
		var p := Vector3(rng.randf_range(-12, 4.2), 0, rng.randf_range(-6.5, 5.6))
		if perto_do_caminho(p.x, p.z, 0.4) or (absf(p.x) < 3.3 and p.z < -0.6 and p.z > -6.0):
			continue
		modelo(cores[rng.randi() % 3], p, rng.randf() * TAU, rng.randf_range(0.9, 1.4))
		colocadas += 1
	for p in [Vector3(-3.6, 0, 5.0), Vector3(-4.6, 0, 4.6), Vector3(5.3, 0, 5.0), Vector3(1.8, 0, 5.2)]:
		modelo(cores[rng.randi() % 3], p, rng.randf() * TAU, 1.5)
	modelo("pedra_3", Vector3(2.7, 0, 0.9), 1.0, 0.7)
	modelo("pedra_1", Vector3(10.5, 0, 5.4), 0.3, 1.1)


# ------------------------------------------------------------------ grama em tufos
func _malha_tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 7:
		var ang := r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x) * 0.035
		var base := dir * r.randf_range(0.0, 0.08)
		var h := r.randf_range(0.22, 0.4)
		var ponta := base + dir * r.randf_range(0.06, 0.14) + Vector3(0, h, 0)
		st.set_uv(Vector2(0, 0)); st.set_normal(Vector3.UP); st.add_vertex(base - lado)
		st.set_uv(Vector2(1, 0)); st.set_normal(Vector3.UP); st.add_vertex(base + lado)
		st.set_uv(Vector2(0.5, 1)); st.set_normal(Vector3.UP); st.add_vertex(ponta)
	return st.commit()


func _grama() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_cor : source_color = vec4(0.22, 0.48, 0.14, 1.0);
uniform vec4 ponta_cor : source_color = vec4(0.50, 0.76, 0.28, 1.0);
void fragment() {
	ALBEDO = mix(base_cor.rgb, ponta_cor.rgb, UV.y) * COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var malha := _malha_tufo()
	var pos: Array[Transform3D] = []
	var cores: Array[Color] = []
	var areas := [Rect2(-16, -7.2, 20.3, 12.8), Rect2(4.6, 4.4, 10, 1.8), Rect2(-20, -9.5, 40, 2.0)]
	for area: Rect2 in areas:
		var n := int(area.get_area() * 9.0)
		for i in n:
			var x := area.position.x + rng.randf() * area.size.x
			var z := area.position.y + rng.randf() * area.size.y
			var y := 2.5 if z < -7.6 else 0.0
			if perto_do_caminho(x, z, 0.05):
				continue
			if y == 0.0 and absf(x) < 3.1 and z < -1.1 and z > -5.7:
				continue
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.55, 1.0))
			pos.append(Transform3D(b, Vector3(x, y, z)))
			var v := rng.randf_range(0.85, 1.12)
			cores.append(Color(v, v, v * 0.95))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha
	mm.instance_count = pos.size()
	for i in pos.size():
		mm.set_instance_transform(i, pos[i])
		mm.set_instance_color(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ------------------------------------------------------------------ personagens e camera
func _personagens() -> void:
	estilo_desenho(modelo("treinador", Vector3(0.9, 0, 3.0), PI + 0.15, 1.12))
	estilo_desenho(modelo("criatura", Vector3(-1.5, 0, 3.3), deg_to_rad(50), 1.12))


const SHADER_DESENHO := """
shader_type spatial;
uniform vec4 cor : source_color = vec4(1.0);
uniform float brilho = 0.25;
void fragment() {
	ALBEDO = cor.rgb;
	ROUGHNESS = 0.6;
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = cor.rgb * borda * 0.45;
}
void light() {
	float d = dot(NORMAL, LIGHT);
	float t = smoothstep(0.0, 0.18, d) * ATTENUATION;
	vec3 lc = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += mix(0.35, 1.0, t) * lc;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += smoothstep(0.94, 0.97, dot(NORMAL, h)) * t * brilho * lc * 3.0;
}
"""

const SHADER_CONTORNO := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 cor : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform float grossura = 0.014;
void vertex() { VERTEX += NORMAL * grossura; }
void fragment() { ALBEDO = cor.rgb; }
"""


## Sombreado de desenho animado (luz em 2 tons + brilho na borda) e contorno escuro.
func estilo_desenho(raiz: Node) -> void:
	var sh := Shader.new()
	sh.code = SHADER_DESENHO
	var sh_linha := Shader.new()
	sh_linha.code = SHADER_CONTORNO
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		pilha.append_array(n.get_children())
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var c := base.albedo_color if base else Color.WHITE
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_parameter("cor", c)
			m.set_shader_parameter("brilho", 1.0 if c.get_luminance() < 0.1 else 0.25)
			var linha := ShaderMaterial.new()
			linha.shader = sh_linha
			linha.set_shader_parameter("cor", c.darkened(0.75))
			m.next_pass = linha
			mi.set_surface_override_material(i, m)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 52
	add_child(cam)
	cam.look_at_from_position(Vector3(0.4, 2.6, 8.6), Vector3(0.6, 1.0, -3.0))
	cam.current = true


# ------------------------------------------------------------------ print automatico
func _talvez_capturar() -> void:
	var destino := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturar="):
			destino = a.get_slice("=", 1)
	if destino == "":
		return
	for i in 90:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(destino)
	print("PRINT SALVO: ", destino, " ", img.get_size())
	get_tree().quit()
