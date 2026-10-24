# Mystic Woods RPG — v0.1

RPG de ação de mundo aberto em pixel art, feito no **Godot 4.7.2** com o pack **Mystic Woods** e 6 monstros novos desenhados no mesmo estilo do pack.

![Novos monstros](docs/novos_monstros.png)

## Abrir o jogo
1. A licença do Mystic Woods não permite redistribuir os arquivos, então eles **não** ficam no repositório. Extraia o ZIP do pack e copie a pasta `sprites` para `assets/mystic_woods/`, ficando `assets/mystic_woods/sprites/characters/player.png` etc.
2. Abra o Godot 4.7.2, importe `project.godot`, espere a importação dos PNGs e aperte **F5**.

## Controles
| Ação | Teclado | Controle |
|---|---|---|
| Mover | WASD / setas | analógico / direcional |
| Atacar | J, Espaço, Z ou clique | A |
| Esquiva (invulnerável) | K, Shift ou X | B |
| Poção | Q ou H | X |
| Interagir (baú, placa, fonte) | E ou Enter | Y |
| Mapa | M ou Tab | Back |
| Pausa | Esc ou P | Start |

No celular/tablet aparecem joystick e botões na tela (ATK, ESQ, E, Q, M, II).

## O mundo
Mapa de 200×200 tiles (3.200×3.200 px) gerado a partir de uma semente salva com o jogo — cada jogo novo tem um mundo diferente. Tiles com borda automática (trilhas, rochas), lagos animados com lírios e ilhas, platôs, ruínas de pedra, cercas e centenas de árvores, arbustos, troncos, lápides etc.

| Região | Onde | Monstros |
|---|---|---|
| Vila do Bosque | centro (segura) | — fonte cura e salva, placa mostra a missão, baú inicial |
| Prado Verdejante | em volta da vila | Slime, Cogumelo, Morcego |
| Floresta Sombria | leste | Goblin, Goblin Chefe, Cogumelo, Morcego |
| Ruínas Antigas | norte | Esqueleto, Esqueleto Sombrio, Fantasma |
| Pedreira Rochosa | oeste | Golem de Pedra, Morcego, Slime de Fogo |
| Pântano dos Lírios | sul | Slime Venenoso, Cogumelo, Fantasma |
| Coração da Floresta | extremo leste | **Ent Ancião** (chefe) |

- O nível dos monstros sobe com a distância da vila (Nv 1 a 12).
- Ciclo de dia e noite (6 min); à noite aparecem mais monstros e fantasmas em todo lugar.
- Minimapa com névoa: só aparece o que você já explorou. O mapa grande (M) marca vila, regiões e baús vistos.
- 35 baús espalhados (ouro, poções, Espada melhorada +3 ATK, Cristal de Vida +5 HP), potes e caixotes quebráveis.

## Monstros novos (assets/monsters)
Todos seguem as regras do pack: grade de 32 px (como o slime) ou 48 px (como o esqueleto), contorno de 1 px, 2–4 tons de sombreamento com luz de cima, sombra elíptica translúcida `#171c31`, paleta extraída do próprio pack e o mesmo layout de linhas: `[0-2]` parado, `[3-5]` andando, `[6-8]` ataque, `[9-11]` dano (baixo, lado, cima) e `[12]` morte.

| Monstro | Grade | Comportamento |
|---|---|---|
| Cogumelo | 32 | anda pulando; ataque em área com nuvem de esporos |
| Morcego | 32 | voo errático, investida com mordida, voa sobre água |
| Fantasma | 32 | atravessa paredes, assusta ("boo") com chamas azuis |
| Goblin | 48 | rápido, golpe de clava com rastro |
| Golem de Pedra | 48 | lento e resistente, soco no chão com onda de choque |
| Ent Ancião | 64 | chefe: pancada em área, chama cogumelos e goblins a 75/50/25% da vida |

Variantes por shader (sem novos PNGs): Slime de Fogo, Slime Venenoso, Goblin Chefe (mudança de matiz) e Esqueleto Sombrio (tinta). Também foram desenhados a moeda girando e os ícones do HUD (`assets/ui`).

Para editar ou criar monstros: os sprites são gerados por código em `tools/` (Python + Pillow).

```
python3 tools/generate_monsters.py   # recria assets/monsters/*.png
python3 tools/generate_items.py      # moeda e ícones
```

## Progressão
- XP sobe de nível (+6 vida, +2 ataque, +1 defesa a cada 2 níveis).
- 9 missões em sequência: slimes → cogumelos → explorar 3 regiões → abrir 4 baús → goblins → esqueletos → fantasmas → golens → Ent Ancião. Depois o mundo fica livre.
- Vencer o chefe libera o baú lendário na arena (Espada Lendária +6 ATK e +20 de vida).
- Ao cair, você renasce na vila e perde metade do ouro carregado.
- Salva sozinho a cada 45 s, ao abrir baús e na fonte; também pelo menu de pausa.

## Estrutura
```
scenes/main.tscn        cena única
scripts/Game.gd         estado, XP, missões, save (autoload)
scripts/Sfx.gd          efeitos sonoros sintetizados (autoload)
scripts/WorldGen.gd     geração do mundo (dados)
scripts/World.gd        TileSet, camadas, objetos, minimapa
scripts/Player.gd       herói
scripts/Enemy.gd        IA genérica dos monstros
scripts/MonsterDB.gd    atributos dos monstros e tabelas de spawn
scripts/Main.gd         fluxo do jogo, spawner, dia/noite, interações
scripts/Hud.gd          HUD e menus
tests/                  testes automáticos
tools/                  gerador dos sprites novos
```

## Testes
```
godot --headless --path . -s res://tests/verify_world.gd   # mundo desenhável e todo alcançável a pé
godot --headless --path . -s res://tests/verify_game.gd    # movimento, combate, 11 monstros, baús, missões, chefe, morte, save
```
Os dois passam no Godot 4.7.2 (3 sementes de mundo, 0 falhas).
