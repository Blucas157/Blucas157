# Desenha os rostos (estilo anime de 3DS) como texturas PNG transparentes.
# Uso: python3 rostos.py <pasta_saida>
# Cada rosto e desenhado em "metros" do modelo (mesmo retangulo usado no Blender),
# entao as posicoes batem com a cabeca 3D.
import sys, os
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
SS = 2  # desenha em dobro e reduz (bordas lisas)


class Tela:
    def __init__(self, x0, x1, z0, z1, larg=1024):
        self.x0, self.x1, self.z0, self.z1 = x0, x1, z0, z1
        self.W = larg * SS
        self.H = int(self.W * (z1 - z0) / (x1 - x0))
        self.img = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def p(self, x, z):
        return ((x - self.x0) / (self.x1 - self.x0) * self.W, (1 - (z - self.z0) / (self.z1 - self.z0)) * self.H)

    def m(self, metros):
        return metros / (self.x1 - self.x0) * self.W

    def caixa(self, x, z, w, h):
        a = self.p(x - w / 2, z + h / 2)
        b = self.p(x + w / 2, z - h / 2)
        return [a, b]

    def elipse(self, x, z, w, h, cor, contorno=None, esp=0.0):
        self.d.ellipse(self.caixa(x, z, w, h), fill=cor, outline=contorno,
                       width=int(self.m(esp)) if contorno else 0)

    def arco(self, x, z, w, h, ini, fim, cor, esp):
        self.d.arc(self.caixa(x, z, w, h), ini, fim, fill=cor, width=max(1, int(self.m(esp))))

    def bochecha(self, x, z, w, h, cor):
        camada = Image.new("RGBA", self.img.size, cor[:3] + (0,))
        ImageDraw.Draw(camada).ellipse(self.caixa(x, z, w, h), fill=cor)
        camada = camada.filter(ImageFilter.GaussianBlur(self.m(0.008)))
        self.img = Image.alpha_composite(self.img, camada)
        self.d = ImageDraw.Draw(self.img)

    def salvar(self, nome):
        out = self.img.resize((self.W // SS, self.H // SS), Image.LANCZOS)
        out.save(os.path.join(OUT, nome))
        print("rosto:", nome, out.size)


def olho_anime(t, x, z, w, h, iris_esc, iris_clara, lado):
    """Olho de anime: branco, iris alta com degrade, pupila, brilhos e cilio grosso em cima."""
    t.elipse(x, z, w * 1.15, h * 1.02, (255, 255, 255, 255))
    t.elipse(x + lado * w * 0.05, z - h * 0.03, w * 0.9, h * 0.92, iris_esc)
    t.elipse(x + lado * w * 0.05, z - h * 0.2, w * 0.7, h * 0.5, iris_clara)
    t.elipse(x + lado * w * 0.05, z - h * 0.02, w * 0.42, h * 0.5, (20, 12, 10, 255))
    t.elipse(x - w * 0.18, z + h * 0.2, w * 0.36, h * 0.3, (255, 255, 255, 255))
    t.elipse(x + w * 0.22, z - h * 0.28, w * 0.16, h * 0.13, (255, 255, 255, 235))
    # cilio de cima, mais grosso e saindo para fora
    t.arco(x, z - h * 0.02, w * 1.3, h * 1.12, 195, 345, (28, 18, 16, 255), w * 0.16)
    a = t.p(x + lado * w * 0.62, z + h * 0.22)
    b = t.p(x + lado * w * 0.78, z + h * 0.32)
    t.d.line([a, b], fill=(28, 18, 16, 255), width=int(t.m(w * 0.14)))


def rosto_treinador():
    t = Tela(-0.16, 0.16, 1.18, 1.40)
    for lado in (-1, 1):
        x = lado * 0.062
        olho_anime(t, x, 1.312, 0.036, 0.058, (58, 36, 20, 255), (132, 84, 44, 255), lado)
        t.arco(x, 1.372, 0.05, 0.02, 200, 340, (60, 36, 22, 255), 0.006)  # sobrancelha
        t.bochecha(lado * 0.098, 1.262, 0.04, 0.018, (240, 120, 110, 120))
    t.arco(0, 1.248, 0.03, 0.016, 20, 160, (110, 50, 40, 255), 0.004)  # sorriso
    t.arco(0, 1.29, 0.008, 0.01, 30, 150, (200, 130, 100, 200), 0.003)  # nariz
    t.salvar("rosto_treinador.png")


def rosto_criatura():
    t = Tela(-0.28, 0.28, 0.6, 1.04)
    for lado in (-1, 1):
        x = lado * 0.125
        t.elipse(x, 0.885, 0.1, 0.122, (18, 22, 40, 255))
        t.elipse(x, 0.855, 0.075, 0.06, (40, 80, 150, 255))
        t.elipse(x, 0.875, 0.05, 0.07, (12, 14, 26, 255))
        t.elipse(x - 0.022, 0.915, 0.04, 0.04, (255, 255, 255, 255))
        t.elipse(x + 0.022, 0.85, 0.018, 0.018, (255, 255, 255, 240))
        t.bochecha(lado * 0.21, 0.79, 0.07, 0.04, (245, 130, 150, 170))
    # boca aberta sorrindo com lingua
    t.d.chord(t.caixa(0, 0.755, 0.07, 0.06), 0, 180, fill=(70, 24, 40, 255))
    t.d.chord(t.caixa(0, 0.738, 0.04, 0.026), 0, 180, fill=(240, 110, 130, 255))
    t.arco(0, 0.755, 0.07, 0.06, 0, 180, (30, 20, 30, 255), 0.004)
    t.d.line([t.p(-0.035, 0.755), t.p(0.035, 0.755)], fill=(30, 20, 30, 255), width=int(t.m(0.004)))
    t.salvar("rosto_criatura.png")


rosto_treinador()
rosto_criatura()
