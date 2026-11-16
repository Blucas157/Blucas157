# Treinador original no estilo dos modelos de 3DS:
#  - malha simples (low-poly) feita de aneis ligados, com mapa UV em cada peca;
#  - TEXTURAS PINTADAS (sombra, costura, dobra, trama, fios, brilho), que e o que da a qualidade;
#  - rosto de anime pintado na textura da cabeca.
# Uso: python treinador_3ds.py <saida.glb> [previa.png]
import bpy, bmesh, math, sys, os, random
import numpy as np
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFilter

H = 1.55
args = [a for a in sys.argv[1:] if not a.startswith("-")]
SAIDA = os.path.abspath(args[0]) if args else os.path.abspath("treinador_3ds.glb")
PREVIA = args[1] if len(args) > 1 else None
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "texturas", "treinador")
os.makedirs(TEX, exist_ok=True)
random.seed(3)
np.random.seed(3)

bpy.ops.wm.read_factory_settings(use_empty=True)
CENA = bpy.context.scene


def v(x, y, z):
    return Vector((x * H, y * H, z * H))


# =============================================================== PINTURA (texturas)
def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


class Tela:
    """Textura em espaco UV (u para a direita, v para cima)."""

    def __init__(self, w, h, cor):
        self.w, self.h = w, h
        self.a = np.ones((h, w, 3), np.float32) * rgb(cor)

    def uv(self):
        u = (np.arange(self.w) + 0.5) / self.w
        vv = 1 - (np.arange(self.h) + 0.5) / self.h
        return np.meshgrid(u, vv)

    def volume(self, frente_u=0.75, forca=0.28, v_escuro=0.12, v_claro=0.0):
        """Sombra pintada: lados e costas mais escuros, frente clara, base escurecendo."""
        U, V = self.uv()
        luz = 0.5 + 0.5 * np.cos(2 * np.pi * (U - frente_u))
        f = (1 - forca) + forca * luz
        f *= 1 - v_escuro * (1 - V) ** 2
        f *= 1 + v_claro * V ** 2
        self.a *= f[..., None]

    def ruido(self, forca=0.05, escala=1, esticar=(1, 1)):
        n = np.random.rand(self.h // escala + 1, self.w // escala + 1).astype(np.float32)
        img = Image.fromarray((n * 255).astype(np.uint8)).resize((self.w * esticar[0], self.h * esticar[1]),
                                                                 Image.BILINEAR)
        n = np.asarray(img.resize((self.w, self.h)), np.float32) / 255
        self.a *= (1 + forca * (n - 0.5) * 2)[..., None]

    def pil(self):
        return Image.fromarray(np.clip(self.a, 0, 255).astype(np.uint8), "RGB")

    def de_pil(self, im):
        self.a = np.asarray(im.convert("RGB"), np.float32)

    def p(self, u, vv):
        return (u * self.w, (1 - vv) * self.h)

    def linhas(self, desenhar, borrar=0.6, alfa=1.0):
        """Desenha numa camada separada (com borrao leve) e mistura por cima."""
        cam = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        desenhar(ImageDraw.Draw(cam), self)
        if borrar:
            cam = cam.filter(ImageFilter.GaussianBlur(borrar))
        base = self.pil().convert("RGBA")
        if alfa < 1:
            r, g, b, al = cam.split()
            al = al.point(lambda x: int(x * alfa))
            cam = Image.merge("RGBA", (r, g, b, al))
        self.de_pil(Image.alpha_composite(base, cam))

    def salvar(self, nome):
        caminho = os.path.join(TEX, nome + ".png")
        self.pil().save(caminho)
        return caminho


def escuro(cor, f):
    c = rgb(cor) * f
    return tuple(int(x) for x in np.clip(c, 0, 255)) + (255,)


def dobra(d, t, u, vv, larg, alt, cor, esp=2):
    """Uma dobra de tecido: arco escuro curto."""
    a = t.p(u - larg / 2, vv + alt / 2)
    b = t.p(u + larg / 2, vv - alt / 2)
    d.arc([a, b], 200, 340, fill=cor, width=esp)


def tex_jaqueta():
    t = Tela(512, 512, "#c8322b")
    t.ruido(0.04, 2)
    t.volume(0.75, 0.32, 0.18, 0.08)

    def d(dr, t):
        sombra = escuro("#c8322b", 0.55)
        luz = (255, 140, 120, 150)
        for u in (0.0, 0.5, 1.0):  # costuras laterais
            dr.line([t.p(u, 0), t.p(u, 1)], fill=sombra, width=3)
            for vv in np.arange(0.02, 1, 0.025):
                dr.line([t.p(u + 0.008, vv), t.p(u + 0.008, vv + 0.012)], fill=escuro("#c8322b", 0.75), width=1)
        for k in range(7):  # pano franzido acima da barra
            u = 0.6 + k * 0.05
            dr.line([t.p(u, 0.02), t.p(u + 0.012, 0.16)], fill=sombra, width=2)
        for u0 in (0.66, 0.84):  # dobras sob o peito e na cintura
            dobra(dr, t, u0, 0.62, 0.12, 0.05, sombra, 3)
            dobra(dr, t, u0, 0.35, 0.1, 0.04, sombra, 2)
        dr.line([t.p(0.6, 0.92), t.p(0.9, 0.92)], fill=luz, width=4)  # brilho no ombro
        for u0 in (0.18, 0.32):  # costas: pregas
            dr.line([t.p(u0, 0.2), t.p(u0 + 0.03, 0.75)], fill=sombra, width=2)
    t.linhas(d, 1.0)
    return t.salvar("jaqueta")


def tex_manga():
    t = Tela(256, 512, "#c8322b")
    t.ruido(0.04, 2)
    t.volume(0.5, 0.3, 0.1, 0.1)

    def d(dr, t):
        sombra = escuro("#c8322b", 0.55)
        dr.line([t.p(0.0, 0), t.p(0.0, 1)], fill=sombra, width=3)
        dr.line([t.p(1.0, 0), t.p(1.0, 1)], fill=sombra, width=3)
        for k in range(4):  # dobras do cotovelo
            dobra(dr, t, 0.4 + k * 0.07, 0.5 + (k % 2) * 0.04, 0.16, 0.05, sombra, 3)
        for k in range(3):  # dobras perto do punho
            dobra(dr, t, 0.45 + k * 0.08, 0.12, 0.14, 0.04, sombra, 2)
        dr.line([t.p(0.4, 0.95), t.p(0.6, 0.95)], fill=(255, 140, 120, 140), width=5)
    t.linhas(d, 1.0)
    return t.salvar("manga")


def tex_branco_canelado():
    """Branco com canelado (gola, barra e punhos)."""
    t = Tela(256, 128, "#efede6")
    t.volume(0.75, 0.25, 0.2)

    def d(dr, t):
        for u in np.arange(0, 1, 1 / 48):
            dr.line([t.p(u, 0.05), t.p(u, 0.95)], fill=(160, 158, 150, 160), width=1)
        dr.line([t.p(0, 0.98), t.p(1, 0.98)], fill=(150, 148, 140, 200), width=3)
        dr.line([t.p(0, 0.02), t.p(1, 0.02)], fill=(150, 148, 140, 200), width=3)
    t.linhas(d, 0.5)
    return t.salvar("branco")


def tex_jeans(nome, quadril=False):
    t = Tela(256, 512, "#33568f")
    t.ruido(0.1, 1, (1, 3))  # trama do jeans
    t.volume(0.75, 0.3, 0.25, 0.0)
    U, V = t.uv()
    desbote = np.exp(-((U - 0.75) ** 2) / 0.01) * (np.exp(-((V - 0.65) ** 2) / 0.03) * 0.25 +
                                                     np.exp(-((V - 0.38) ** 2) / 0.006) * 0.18)
    t.a *= (1 + desbote)[..., None]

    def d(dr, t):
        costura = (214, 160, 90, 230)
        sombra = escuro("#33568f", 0.5)
        for u in (0.0, 0.5, 1.0):
            dr.line([t.p(u, 0), t.p(u, 1)], fill=sombra, width=3)
            for vv in np.arange(0.01, 1, 0.02):
                dr.line([t.p(u + 0.012, vv), t.p(u + 0.012, vv + 0.01)], fill=costura, width=1)
        if quadril:  # bolsos e passadores
            for uc in (0.62, 0.88):
                dr.arc([t.p(uc - 0.1, 0.95), t.p(uc + 0.1, 0.45)], 0, 90 if uc > 0.75 else 180,
                       fill=costura, width=2)
            for uc in (0.18, 0.32):
                dr.rectangle([t.p(uc - 0.07, 0.85), t.p(uc + 0.07, 0.3)], outline=costura, width=2)
            for uc in (0.1, 0.4, 0.6, 0.9):
                dr.rectangle([t.p(uc - 0.01, 1.0), t.p(uc + 0.01, 0.8)], fill=escuro("#33568f", 0.8))
        else:
            for k in range(4):  # dobras do joelho e atras do joelho
                dobra(dr, t, 0.68 + k * 0.05, 0.4 + (k % 2) * 0.03, 0.12, 0.03, sombra, 2)
                dobra(dr, t, 0.2 + k * 0.04, 0.42, 0.1, 0.03, sombra, 2)
            for k in range(3):  # tecido amontoado na barra
                dobra(dr, t, 0.6 + k * 0.1, 0.08, 0.14, 0.04, sombra, 3)
    t.linhas(d, 0.8)
    return t.salvar(nome)


def tex_cabelo():
    t = Tela(512, 256, "#4a2a18")
    t.ruido(0.18, 1, (1, 8))  # fios
    U, V = t.uv()
    t.a *= (0.55 + 0.45 * V ** 0.6)[..., None]  # pontas mais escuras
    brilho = np.exp(-((V - 0.62) ** 2) / 0.004) * (0.6 + 0.4 * np.sin(U * 2 * np.pi * 18) ** 2)
    t.a += (brilho * 70)[..., None] * np.array([1.0, 0.85, 0.7])

    def d(dr, t):
        for k in range(70):
            u = random.random()
            dr.line([t.p(u, 1), t.p(u + random.uniform(-0.01, 0.01), random.uniform(0.0, 0.5))],
                    fill=(30, 15, 8, 160), width=2)
    t.linhas(d, 0.6)
    return t.salvar("cabelo")


def tex_bone():
    t = Tela(512, 256, "#cf342c")
    t.ruido(0.04, 2)
    U, V = t.uv()
    t.a *= (0.72 + 0.28 * V)[..., None]

    def d(dr, t):
        sombra = escuro("#cf342c", 0.6)
        for k in range(6):  # costuras dos gomos
            u = k / 6 + 1 / 12
            dr.line([t.p(u, 1), t.p(u, 0)], fill=sombra, width=3)
            dr.line([t.p(u + 0.01, 1), t.p(u + 0.01, 0)], fill=escuro("#cf342c", 0.8), width=1)
        # emblema original na frente: folha inclinada com nervuras
        cx, cy, ang = 0.5, 0.42, math.radians(35)
        pts = []
        for a in np.linspace(0, 2 * math.pi, 48):
            lx = 0.05 * math.sin(a) * abs(math.sin(a)) ** 0.3
            ly = 0.16 * math.cos(a)
            pts.append(t.p(cx + (lx * math.cos(ang) - ly * math.sin(ang) * 0.35),
                           cy + (lx * math.sin(ang) * 2.5 + ly * math.cos(ang))))
        dr.polygon(pts, fill=(250, 248, 240, 255), outline=(70, 25, 20, 255), width=3)
        p0, p1 = t.p(cx + 0.02, cy - 0.15), t.p(cx - 0.02, cy + 0.15)
        dr.line([p0, p1], fill=(200, 60, 50, 255), width=3)
        for k in (-0.07, 0.0, 0.07):
            m = t.p(cx - k * 0.25, cy + k)
            dr.line([m, (m[0] + 12, m[1] - 8)], fill=(200, 60, 50, 255), width=2)
            dr.line([m, (m[0] - 12, m[1] - 8)], fill=(200, 60, 50, 255), width=2)
        dr.line([t.p(0, 0.03), t.p(1, 0.03)], fill=escuro("#cf342c", 0.5), width=6)
    t.linhas(d, 0.7)
    return t.salvar("bone")


def tex_aba():
    t = Tela(256, 128, "#cf342c")
    t.volume(0.75, 0.4)

    def d(dr, t):
        for vv in (0.3, 0.45, 0.6, 0.75):
            dr.line([t.p(0.55, vv), t.p(0.95, vv)], fill=escuro("#cf342c", 0.65), width=2)
    t.linhas(d, 0.6)
    return t.salvar("aba")


def tex_tenis():
    # u: 0.25 = em cima (peito do pe), 0/0.5 = lados, 0.75 = embaixo; v: 0 = calcanhar, 1 = ponta
    t = Tela(256, 256, "#d0352d")
    t.volume(0.25, 0.3, 0.0)

    def d(dr, t):
        branco = (245, 243, 236, 255)
        dr.rectangle([t.p(0, 1), t.p(1, 0.78)], fill=branco)  # biqueira branca
        dr.line([t.p(0, 0.78), t.p(1, 0.78)], fill=(120, 30, 25, 255), width=3)
        dr.rectangle([t.p(0, 0.12), t.p(1, 0)], fill=escuro("#d0352d", 0.7))  # reforco do calcanhar
        for k in range(4):  # cadarco em cima
            vv = 0.32 + k * 0.1
            dr.line([t.p(0.18, vv), t.p(0.32, vv + 0.06)], fill=branco, width=4)
            dr.line([t.p(0.32, vv), t.p(0.18, vv + 0.06)], fill=branco, width=4)
        for uc in (0.0, 0.5, 1.0):  # faixa lateral (logo original)
            dr.line([t.p(uc - 0.08, 0.3), t.p(uc + 0.08, 0.62)], fill=branco, width=6)
    t.linhas(d, 0.5)
    return t.salvar("tenis")


def tex_sola():
    t = Tela(128, 64, "#e8e6df")

    def d(dr, t):
        dr.line([t.p(0, 0.5), t.p(1, 0.5)], fill=(150, 150, 150, 255), width=2)
        for u in np.arange(0, 1, 0.06):
            dr.line([t.p(u, 0.1), t.p(u, 0.3)], fill=(180, 180, 175, 255), width=1)
    t.linhas(d, 0.3)
    return t.salvar("sola")


def tex_pochete():
    t = Tela(256, 128, "#f0b020")
    t.ruido(0.05, 2)
    t.volume(0.5, 0.35, 0.3)

    def d(dr, t):
        dr.line([t.p(0, 0.65), t.p(1, 0.65)], fill=(90, 60, 10, 255), width=3)  # ziper
        for u in np.arange(0, 1, 0.02):
            dr.line([t.p(u, 0.62), t.p(u, 0.68)], fill=(60, 40, 10, 200), width=1)
        dr.rectangle([t.p(0.45, 0.78), t.p(0.55, 0.62)], fill=(50, 50, 55, 255))
    t.linhas(d, 0.5)
    return t.salvar("pochete")


def tex_pele():
    t = Tela(128, 128, "#f6cdb0")
    t.volume(0.5, 0.18, 0.15)
    return t.salvar("pele")


def tex_preto():
    t = Tela(64, 64, "#222226")
    return t.salvar("preto")


def tex_rosto():
    """Cabeca inteira: u = volta em torno da cabeca (frente no meio), v = altura.
    Olhos de anime no estilo de 3DS: cilio grosso, iris escura com degrade, dois brilhos."""
    W, Hh = 1024, 512
    t = Tela(W, Hh, "#f6cdb0")
    U, V = t.uv()
    lado = np.abs(U - 0.5)
    t.a *= (1 - 0.35 * np.clip(lado - 0.12, 0, 1))[..., None]
    t.a *= (1 - 0.18 * np.clip(0.3 - V, 0, 1) / 0.3)[..., None]  # pescoco/queixo mais escuro
    bochecha = np.exp(-(((U - 0.5) ** 2 - 0.0042) ** 2) / 1e-6) * np.exp(-((V - 0.36) ** 2) / 0.002)
    t.a = t.a * (1 - 0.12 * bochecha[..., None]) + (bochecha * 0.12)[..., None] * np.array([250, 110, 110])

    def d(dr, t):
        linha = (34, 20, 16, 255)
        for s in (-1, 1):
            cx, cy = 0.5 + s * 0.058, 0.46
            w, h = 0.05, 0.155
            dr.ellipse([t.p(cx - w * 0.55, cy + h * 0.5), t.p(cx + w * 0.55, cy - h * 0.5)], fill=(255, 255, 255, 255))
            dr.ellipse([t.p(cx - w * 0.42, cy + h * 0.42), t.p(cx + w * 0.42, cy - h * 0.5)], fill=(52, 64, 110, 255))
            dr.ellipse([t.p(cx - w * 0.36, cy + h * 0.05), t.p(cx + w * 0.36, cy - h * 0.46)], fill=(92, 120, 190, 255))
            dr.ellipse([t.p(cx - w * 0.2, cy + h * 0.25), t.p(cx + w * 0.2, cy - h * 0.3)], fill=(18, 18, 30, 255))
            dr.ellipse([t.p(cx - w * 0.33, cy + h * 0.36), t.p(cx - w * 0.02, cy + h * 0.06)], fill=(255, 255, 255, 255))
            dr.ellipse([t.p(cx + w * 0.1, cy - h * 0.2), t.p(cx + w * 0.26, cy - h * 0.36)], fill=(255, 255, 255, 230))
            # cilio de cima grosso, puxado para fora
            dr.arc([t.p(cx - w * 0.62, cy + h * 0.62), t.p(cx + w * 0.62, cy - h * 0.55)], 195, 345, fill=linha, width=9)
            dr.line([t.p(cx + s * w * 0.5, cy + h * 0.28), t.p(cx + s * w * 0.78, cy + h * 0.38)], fill=linha, width=7)
            dr.arc([t.p(cx - w * 0.45, cy + h * 0.3), t.p(cx + w * 0.45, cy - h * 0.55)], 40, 140,
                   fill=(120, 70, 60, 200), width=2)
            # sobrancelha
            dr.arc([t.p(cx - w * 0.7, cy + h * 0.95), t.p(cx + w * 0.7, cy + h * 0.55)], 200, 340,
                   fill=(70, 40, 25, 255), width=5)
        dr.line([t.p(0.5, 0.38), t.p(0.503, 0.365)], fill=(200, 130, 105, 255), width=3)  # nariz
        dr.arc([t.p(0.485, 0.32), t.p(0.515, 0.285)], 20, 160, fill=(130, 60, 50, 255), width=4)  # boca
        dr.ellipse([t.p(0.24, 0.5), t.p(0.26, 0.38)], fill=(225, 160, 135, 255))  # orelha (sombra)
        dr.ellipse([t.p(0.74, 0.5), t.p(0.76, 0.38)], fill=(225, 160, 135, 255))
    t.linhas(d, 0.8)
    return t.salvar("rosto")


# =============================================================== MATERIAIS
def mat_tex(nome, caminho):
    m = bpy.data.materials.new(nome)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.85
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = bpy.data.images.load(caminho)
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    nt.links.new(uvn.outputs["UV"], tx.inputs["Vector"])
    nt.links.new(tx.outputs["Color"], b.inputs["Base Color"])
    return m


M = {}
for nome, fn in (("jaqueta", tex_jaqueta), ("manga", tex_manga), ("branco", tex_branco_canelado),
                 ("jeans", lambda: tex_jeans("jeans")), ("jeans_quadril", lambda: tex_jeans("jeans_quadril", True)),
                 ("cabelo", tex_cabelo), ("bone", tex_bone), ("aba", tex_aba), ("tenis", tex_tenis),
                 ("sola", tex_sola), ("pochete", tex_pochete), ("pele", tex_pele), ("preto", tex_preto),
                 ("rosto", tex_rosto)):
    M[nome] = mat_tex(nome, fn())


# =============================================================== GEOMETRIA
def _finaliza(bm, nome, material, liso=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = liso
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(nome, me)
    CENA.collection.objects.link(o)
    return o


def tubo(nome, aneis, material, n=12, tampa_ini=True, tampa_fim=True, ref=Vector((1, 0, 0)), quad=2.0):
    """Liga aneis (centro, rx, ry) em um tubo com UV: u = volta (frente em u=0.75 para ref X), v = comprimento.
    quad > 2 deixa a secao mais quadrada (roupa)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    cs = [a[0] for a in aneis]
    lacos = []
    for i, a in enumerate(aneis):
        c, rx, ry = a[0], a[1] * H, a[2] * H
        t = (cs[min(i + 1, len(cs) - 1)] - cs[max(i - 1, 0)]).normalized()
        ex = (ref - t * ref.dot(t)).normalized()
        ey = t.cross(ex).normalized()
        laco = []
        for k in range(n):
            ang = 2 * math.pi * k / n
            cx, sy = math.cos(ang), math.sin(ang)
            r = (abs(cx) ** quad + abs(sy) ** quad) ** (-1 / quad)
            laco.append(bm.verts.new(c + ex * cx * r * rx + ey * sy * r * ry))
        lacos.append(laco)
    comp = [0.0]
    for i in range(1, len(cs)):
        comp.append(comp[-1] + (cs[i] - cs[i - 1]).length)
    vs = [x / comp[-1] for x in comp]
    for i in range(len(lacos) - 1):
        a, b = lacos[i], lacos[i + 1]
        for k in range(n):
            j = (k + 1) % n
            f = bm.faces.new((a[k], a[j], b[j], b[k]))
            u0, u1 = k / n, (k + 1) / n
            for l, uv in zip(f.loops, ((u0, vs[i]), (u1, vs[i]), (u1, vs[i + 1]), (u0, vs[i + 1]))):
                l[uvl].uv = uv
    for laco, vv, inverte, usar in ((lacos[0], 0.0, True, tampa_ini), (lacos[-1], 1.0, False, tampa_fim)):
        if usar:
            f = bm.faces.new(list(reversed(laco)) if inverte else laco)
            for l in f.loops:
                l[uvl].uv = (0.75, min(max(vv, 0.01), 0.99))
    return _finaliza(bm, nome, material)


def esfera_uv(nome, centro, rx, ry, rz, material, seg=16, aneis=12, forma=None, phi_max=180.0,
              frente_meio=True, zigue=None):
    """Esfera/calota com UV cilindrico (frente em u=0.5). forma(x,y,z) pode deformar cada ponto.
    zigue(k) devolve quanto a ultima volta desce naquela coluna (cabelo com pontas)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    topo = bm.verts.new(centro + Vector((0, 0, rz * H)))
    lacos = []
    for i in range(1, aneis + 1):
        laco = []
        for k in range(seg):
            phi = math.radians(phi_max * i / aneis)
            esp = 1.0
            if zigue and i == aneis:
                dphi, esp = zigue(k)
                phi += math.radians(dphi)
            th = 2 * math.pi * k / seg
            x = math.sin(phi) * math.sin(th) * rx * esp
            y = -math.sin(phi) * math.cos(th) * ry * esp
            z = math.cos(phi) * rz
            if forma:
                x, y, z = forma(x, y, z)
            laco.append(bm.verts.new(centro + Vector((x, y, z)) * H))
        lacos.append(laco)
    fundo = None
    if phi_max >= 179:
        fundo = bm.verts.new(centro + Vector((0, 0, -rz * H)) if not forma else
                             centro + Vector(forma(0, 0, -rz)) * H)
        lacos = lacos[:-1]

    def uk(k):
        return ((k / seg) + 0.5) % 1.0 if frente_meio else k / seg

    nl = len(lacos)
    for k in range(seg):
        j = (k + 1) % seg
        u0, u1 = uk(k), uk(k) + 1 / seg
        f = bm.faces.new((topo, lacos[0][k], lacos[0][j]))
        for l, uv in zip(f.loops, ((u0 + 0.5 / seg, 1.0), (u0, 1 - 1 / (nl + 1)), (u1, 1 - 1 / (nl + 1)))):
            l[uvl].uv = uv
        for i in range(nl - 1):
            va, vb = 1 - (i + 1) / (nl + 1), 1 - (i + 2) / (nl + 1)
            f = bm.faces.new((lacos[i][k], lacos[i + 1][k], lacos[i + 1][j], lacos[i][j]))
            for l, uv in zip(f.loops, ((u0, va), (u0, vb), (u1, vb), (u1, va))):
                l[uvl].uv = uv
        if fundo is not None:
            f = bm.faces.new((lacos[-1][k], fundo, lacos[-1][j]))
            vb = 1 / (nl + 1)
            for l, uv in zip(f.loops, ((u0, vb), (u0 + 0.5 / seg, 0.0), (u1, vb))):
                l[uvl].uv = uv
    return _finaliza(bm, nome, material)


# ---------------------------------------------------------------- cabeca (anime: cranio redondo, queixo fino)
def forma_cabeca(x, y, z):
    r = 0.078
    zn = z / (r * 1.08)
    if zn < 0:
        f = 1 - 0.38 * (-zn) ** 1.3
        x *= f
        y *= 1 - 0.18 * (-zn) if y < 0 else f
        z *= 1.1
    if y < 0:  # rosto um pouco mais achatado
        y *= 0.93
    return x * 0.92, y, z * 1.08


esfera_uv("cabeca", v(0, 0, 0.9), 0.078, 0.078, 0.078, M["rosto"], seg=20, aneis=14, forma=forma_cabeca)
for s in (-1, 1):
    tubo("orelha", [(v(s * 0.066, 0.006, 0.895), 0.006, 0.014), (v(s * 0.075, 0.009, 0.897), 0.005, 0.012)],
         M["pele"], n=6)
tubo("pescoco", [(v(0, 0.006, 0.78), 0.023, 0.023), (v(0, 0.004, 0.86), 0.021, 0.021)], M["pele"], n=10)


# ---------------------------------------------------------------- cabelo: volume com pontas
def zigue_cabelo(k, seg=40):
    th = 360 * k / seg
    a = min(th, 360 - th)  # 0 = frente
    ponta = k % 2 == 0
    if a < 45:     # franja pontuda na testa
        return (14 if ponta else 2), (1.04 if ponta else 1.0)
    if a < 110:    # mechas dos lados
        return (16 if ponta else -4), (1.1 if ponta else 0.98)
    return (20 if ponta else -6), (1.16 if ponta else 0.97)  # nuca


def fim_cabelo(k, seg=40):
    th = 360 * k / seg
    a = min(th, 360 - th)
    if a < 45:
        return 62
    if a < 80:
        return 62 + (a - 45) / 35 * 50
    if a < 115:
        return 112
    return 112 + (a - 115) / 65 * 16


def cabelo():
    seg, aneis = 40, 6
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    centro = v(0, 0.004, 0.905)
    rx, ry, rz = 0.093, 0.097, 0.097
    topo = bm.verts.new(centro + Vector((0, 0, rz * H)))
    cols = []
    for k in range(seg):
        th = 2 * math.pi * k / seg
        fim = fim_cabelo(k, seg)
        col = []
        for i in range(1, aneis + 1):
            phi = fim * i / aneis
            esp = 1.0 + 0.05 * (i / aneis)  # mais volume embaixo
            if i == aneis:
                dphi, e2 = zigue_cabelo(k, seg)
                phi += dphi
                esp *= e2
            ph = math.radians(phi)
            p = Vector((math.sin(ph) * math.sin(th) * rx * esp, -math.sin(ph) * math.cos(th) * ry * esp,
                        math.cos(ph) * rz))
            col.append(bm.verts.new(centro + p * H))
        cols.append(col)
    for k in range(seg):
        j = (k + 1) % seg
        u0, u1 = k / seg, (k + 1) / seg
        f = bm.faces.new((topo, cols[k][0], cols[j][0]))
        for l, uv in zip(f.loops, ((u0, 1.0), (u0, 1 - 1 / aneis), (u1, 1 - 1 / aneis))):
            l[uvl].uv = uv
        for i in range(aneis - 1):
            va, vb = 1 - (i + 1) / aneis, 1 - (i + 2) / aneis
            f = bm.faces.new((cols[k][i], cols[k][i + 1], cols[j][i + 1], cols[j][i]))
            for l, uv in zip(f.loops, ((u0, va), (u0, vb), (u1, vb), (u1, va))):
                l[uvl].uv = uv
    return _finaliza(bm, "cabelo", M["cabelo"])


cabelo()


# ---------------------------------------------------------------- bone: copa estruturada (frente mais alta) e aba
def forma_bone(x, y, z):
    if y < 0:
        z += 0.012 * (-y / 0.09)
    return x, y, z


esfera_uv("bone", v(0, 0.008, 0.944), 0.087, 0.092, 0.07, M["bone"], seg=24, aneis=6, phi_max=90,
          forma=forma_bone)
tubo("faixa_bone", [(v(0, 0.008, 0.94), 0.0875, 0.0925), (v(0, 0.008, 0.952), 0.0878, 0.0928)], M["bone"],
     n=24, tampa_ini=False, tampa_fim=False)
tubo("aba", [(v(0, -0.08, 0.95), 0.068, 0.006), (v(0, -0.112, 0.94), 0.064, 0.007),
             (v(0, -0.138, 0.928), 0.05, 0.006), (v(0, -0.146, 0.924), 0.03, 0.005)], M["aba"], n=12,
     ref=Vector((1, 0, 0)), quad=3.0)
tubo("botao", [(v(0, 0.01, 1.012), 0.01, 0.01), (v(0, 0.01, 1.02), 0.006, 0.006)], M["bone"], n=8)

# ---------------------------------------------------------------- jaqueta (secao mais quadrada, barra larga)
tubo("jaqueta", [(v(0, 0.0, 0.44), 0.086, 0.055),
                 (v(0, 0.0, 0.47), 0.083, 0.053),
                 (v(0, 0.0, 0.53), 0.073, 0.048),
                 (v(0, -0.002, 0.61), 0.077, 0.051),
                 (v(0, -0.004, 0.68), 0.085, 0.056),
                 (v(0, -0.002, 0.725), 0.089, 0.055),
                 (v(0, 0.002, 0.755), 0.075, 0.048),
                 (v(0, 0.004, 0.778), 0.045, 0.038)], M["jaqueta"], n=16, tampa_ini=False, quad=2.6)
tubo("barra_jaq", [(v(0, 0.0, 0.428), 0.088, 0.057), (v(0, 0.0, 0.462), 0.085, 0.055)], M["branco"], n=16,
     tampa_ini=False, tampa_fim=False, quad=2.6)
tubo("gola", [(v(0, 0.004, 0.768), 0.046, 0.04), (v(0, 0.006, 0.8), 0.037, 0.033),
              (v(0, 0.004, 0.828), 0.04, 0.035)], M["branco"], n=14, tampa_ini=False, tampa_fim=False)
tubo("ziper", [(v(0, -0.0525, 0.46), 0.0045, 0.0015), (v(0, -0.0515, 0.53), 0.0045, 0.0015),
               (v(0, -0.0545, 0.61), 0.0045, 0.0015), (v(0, -0.0585, 0.68), 0.0045, 0.0015),
               (v(0, -0.0575, 0.725), 0.0045, 0.0015), (v(0, -0.047, 0.765), 0.0045, 0.0015)], M["branco"], n=6,
     ref=Vector((1, 0, 0)), quad=3.0)
# ---------------------------------------------------------------- bracos: manga que alarga no punho
for s in (-1, 1):
    tubo("manga", [(v(s * 0.066, 0.0, 0.742), 0.03, 0.031),
                   (v(s * 0.09, 0.0, 0.725), 0.03, 0.03),
                   (v(s * 0.11, 0.0, 0.67), 0.027, 0.027),
                   (v(s * 0.128, 0.002, 0.6), 0.024, 0.024),
                   (v(s * 0.141, -0.004, 0.535), 0.024, 0.023),
                   (v(s * 0.147, -0.006, 0.505), 0.026, 0.025)], M["manga"], n=12, tampa_ini=False,
         tampa_fim=False, ref=Vector((0, 1, 0)))
    tubo("punho", [(v(s * 0.147, -0.006, 0.508), 0.022, 0.021), (v(s * 0.152, -0.006, 0.482), 0.02, 0.019)],
         M["branco"], n=12, ref=Vector((0, 1, 0)))
    # mao: palma + dedos juntos + polegar
    tubo("mao", [(v(s * 0.153, -0.006, 0.486), 0.011, 0.015),
                 (v(s * 0.157, -0.007, 0.458), 0.012, 0.021),
                 (v(s * 0.16, -0.009, 0.43), 0.011, 0.02),
                 (v(s * 0.161, -0.011, 0.41), 0.008, 0.015),
                 (v(s * 0.16, -0.012, 0.4), 0.004, 0.008)], M["pele"], n=8, ref=Vector((0, 1, 0)), quad=2.5)
    tubo("polegar", [(v(s * 0.152, -0.02, 0.47), 0.006, 0.006), (v(s * 0.151, -0.03, 0.452), 0.0055, 0.0055),
                     (v(s * 0.15, -0.034, 0.44), 0.004, 0.004)], M["pele"], n=6)
# ---------------------------------------------------------------- jeans
tubo("quadril", [(v(0, 0.0, 0.4), 0.058, 0.041), (v(0, 0.0, 0.44), 0.075, 0.048),
                 (v(0, 0.0, 0.47), 0.076, 0.048)], M["jeans_quadril"], n=16, quad=2.3)
for s in (-1, 1):
    tubo("perna", [(v(s * 0.038, 0.0, 0.07), 0.031, 0.033),
                   (v(s * 0.039, 0.0, 0.17), 0.032, 0.035),
                   (v(s * 0.038, -0.004, 0.27), 0.03, 0.032),
                   (v(s * 0.04, -0.002, 0.36), 0.039, 0.041),
                   (v(s * 0.042, 0.0, 0.43), 0.047, 0.049)], M["jeans"], n=12, tampa_fim=False)
    tubo("barra", [(v(s * 0.038, 0.0, 0.066), 0.034, 0.036), (v(s * 0.038, 0.0, 0.098), 0.034, 0.036)],
         M["jeans"], n=12)
# ---------------------------------------------------------------- tenis robusto: cabedal, lingua e sola grossa
for s in (-1, 1):
    x = s * 0.039
    tubo("tenis", [(v(x, 0.036, 0.048), 0.027, 0.026),
                   (v(x, 0.01, 0.062), 0.032, 0.04),
                   (v(x, -0.025, 0.046), 0.033, 0.03),
                   (v(x, -0.058, 0.034), 0.03, 0.02),
                   (v(x, -0.074, 0.032), 0.02, 0.012)], M["tenis"], n=12, ref=Vector((1, 0, 0)), quad=2.4)
    tubo("lingua", [(v(x, 0.0, 0.088), 0.018, 0.006), (v(x, -0.022, 0.07), 0.018, 0.007)], M["sola"], n=8,
         ref=Vector((1, 0, 0)))
    tubo("sola", [(v(x, 0.044, 0.012), 0.03, 0.012), (v(x, 0.0, 0.012), 0.035, 0.013),
                  (v(x, -0.055, 0.012), 0.035, 0.013), (v(x, -0.084, 0.015), 0.024, 0.011)], M["sola"], n=12,
         ref=Vector((1, 0, 0)), quad=3.0)
# ---------------------------------------------------------------- pochete amarela (original, no lugar da mochila)
tubo("cinto", [(v(0, 0.0, 0.452), 0.08, 0.052), (v(0, 0.0, 0.462), 0.08, 0.052)], M["preto"], n=16,
     tampa_ini=False, tampa_fim=False, quad=2.4)
tubo("pochete", [(v(0.025, -0.054, 0.448), 0.012, 0.024), (v(0.055, -0.06, 0.452), 0.024, 0.03),
                 (v(0.085, -0.052, 0.456), 0.012, 0.022)], M["pochete"], n=10, ref=Vector((0, 1, 0)), quad=2.6)

# =============================================================== JUNTAR E EXPORTAR
malhas = [o for o in CENA.objects if o.type == "MESH"]
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in malhas)
print("TRIANGULOS", tris)
for o in CENA.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = malhas[0]
bpy.ops.object.join()
bpy.context.view_layer.objects.active.name = "treinador"
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True)
print("EXPORTADO", SAIDA)

if PREVIA:  # mesma luz e camera das vistas da referencia
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    CENA.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = H * 1.15
    CENA.camera = cam
    sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    sol.data.energy = 3
    CENA.collection.objects.link(sol)
    sol.rotation_euler = (0.8, 0, 0.6)
    CENA.world = bpy.data.worlds.new("w")
    CENA.world.color = (0.8, 0.8, 0.8)
    r = CENA.render
    r.engine = "CYCLES"
    CENA.cycles.samples = 24
    r.resolution_x, r.resolution_y = 600, 800
    base, ext = os.path.splitext(PREVIA)
    for nome, pos in (("frente", (0, -5, H / 2)), ("lado", (5, 0, H / 2)), ("costas", (0, 5, H / 2))):
        cam.location = pos
        cam.rotation_euler = (Vector((0, 0, H / 2)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        r.filepath = f"{base}_{nome}{ext}"
        bpy.ops.render.render(write_still=True)
    # close do rosto
    cam.data.ortho_scale = H * 0.3
    cam.location = (0, -5, 0.9 * H)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    r.resolution_x = r.resolution_y = 600
    r.filepath = f"{base}_rosto{ext}"
    bpy.ops.render.render(write_still=True)
