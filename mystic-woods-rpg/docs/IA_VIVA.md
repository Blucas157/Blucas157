# IA viva: monstros que aprendem, evoluem e disputam o mundo

Este documento descreve o sistema de facções do jogo (`scripts/Factions.gd`, `scripts/Camp.gd`, a IA do `scripts/Enemy.gd`) e as obras que o inspiraram. A ideia é um mundo que não espera o herói: os monstros lembram como foram vencidos, mudam de tática, crescem, erguem acampamentos, tomam territórios e brigam entre si.

## Referências (o que pegamos de cada uma)

| Obra | Tipo | O que inspira no jogo |
|---|---|---|
| **Tensei Shitara Slime Datta Ken** (Tensura) | isekai / mangá / anime | Monstros que se organizam em **nações** e **evoluem** de nível ("Táticos", "Veteranos"...), alianças e guerras entre raças (goblins, orcs, lobos). |
| **Goblin Slayer** | mangá / anime | Goblins que **aprendem com os aventureiros** (copiam táticas, armam emboscadas), **ninhos/acampamentos** que crescem e **invadem vilas à noite**. |
| **Overlord** | light novel / anime | Facções com **territórios**, mapa político que muda, o mundo reagindo ao jogador. |
| **Re:Monster** | isekai / mangá | Um goblin que **evolui lutando** e transforma o bando em clã: evolução por experiência de combate. |
| **Kumo desu ga, Nani ka?** (Sou uma aranha) | isekai / anime | **Ninho das Aranhas** que se espalha, monstros que **se adaptam** e ganham habilidades com o tempo. |
| **Shangri-La Frontier** | mangá / anime | **Monstros únicos que lembram do jogador** (Lycagon marca quem enfrentou, à noite); base do sistema de **Rivais** e do **rancor**. |
| **Solo Leveling** | manhwa | **"Dungeon break"**: quando ninguém contém, os monstros **transbordam** para fora e avançam sobre cidades. É o modelo das **expansões e invasões**. |
| **Tower of God** | manhwa | Grupos com interesses próprios, **guerras de facção** e alianças que mudam. |
| **Omniscient Reader's Viewpoint** | manhwa | O mundo como **cenários que escalam**: cada dia o equilíbrio de poder muda. |
| **The Beginning After the End** | manhwa | **Exércitos de bestas** organizados por líderes, guerras de continente. |
| **Battle Through the Heavens** / **Soul Land** | donghwa | **Bestas espirituais que crescem com o tempo** (anos de cultivo = mais poder), territórios de feras e hierarquia de força. |
| **Tales of Demons and Gods** | donghwa / manhua | **Marés de bestas** atacando cidades, bestas que ficam mais fortes a cada onda. |
| **Dungeon Meshi** | mangá / anime | **Ecossistema**: monstros que caçam outros monstros e seguem regras do próprio mundo. |
| **Frieren** | mangá / anime | Demônios que **estudam os humanos e aprendem** a enganar: adaptação como inteligência. |
| **DanMachi** (Xenos) | light novel / anime | Monstros com **memória e vontade própria**, que lembram vidas e encontros passados. |
| **Kingdom** | mangá / anime | **Conquista de território** e batalhas decididas pela força de cada lado. |

## Como funciona no jogo

### Facções
Cada monstro pertence a uma facção (`Factions.DATA`):

| Facção | Monstros | Casa | Ambição |
|---|---|---|---|
| Clã Goblin | goblin, chefe goblin | Floresta Sombria | alta |
| Horda Orc | orc | Coração da Floresta | alta |
| Legião dos Mortos | esqueletos, piromante, fantasma | Ruínas Antigas | média |
| Ninho das Aranhas | aranha | Pedreira Rochosa | média |
| Matilha Selvagem | lobo, morcego | Floresta Sombria | baixa |
| Brejo Vivo | gosmas, cogumelo, sapo | Pântano dos Lírios | baixa |
| Guardiões de Pedra | golem, elemental de cristal | Pedreira Rochosa | nenhuma (só defendem) |
| Bando de Saqueadores | (bandidos: esperando a arte) | Prado | alta |

Cada facção guarda (e salva) força, nível de evolução, XP, territórios (% de controle por região), acampamentos, o que aprendeu, rancor do herói e guerras.

### Aprender com o herói (adaptação)
Como você mata importa. A facção conta e, passado o limite, **se adapta para sempre**:
- **Espada** (12 mortes) → *Escudos improvisados*: -20% de dano corpo a corpo e 25% de chance de **bloquear** metade.
- **Bola de Fogo** (6 mortes) → *Formação dispersa*: -25% de dano mágico e eles **se espalham** para não serem pegos juntos pela explosão.
- **Esquiva** (10 esquivas de golpes deles) → *Fintas*: esperam a sua esquiva acabar, rondando, antes de atacar.

### Evolução (níveis)
XP vem do tempo, de acampamentos, de batalhas contra outras facções (vencer **e perder** ensina) e de derrotar o herói. Níveis: Selvagens → Organizados → Táticos → Veteranos → Elite → Lendários. Cada nível dá +12% vida, +8% ataque, +4% velocidade, mais **elites** (chefes goblin, esqueletos sombrios...) e táticas:
- Nível 2, *Grito de guerra*: quando um apanha, os da mesma facção por perto vêm ajudar.
- Nível 3, *Táticas de cerco*: cada um ataca por um lado.
- Nível 4, *Recuo tático*: feridos recuam e voltam.

O nome mostra o nível: "Goblin Tático", "Esqueleto Veterano".

### Acampamentos, territórios e guerras
A cada 12 segundos o mundo dá um passo (também longe do herói):
- A força cresce com territórios e acampamentos. Regiões bem controladas ganham um **acampamento** (fogueira e estandarte da facção), que sobe até o nível 3.
- Com força sobrando, a facção manda um grupo de guerra para uma **região vizinha**. Mais vezes **à noite**.
- Se outra facção domina a região, há **guerra**: a batalha é decidida pela força e pelo nível de cada lado, e muda o controle do território.
- Quem domina uma região aparece mais nela.
- Quando duas facções em guerra dividem a região onde você está, os grupos delas **se encontram e lutam de verdade na tela**. Monstros batem em monstros, e as mortes contam para a facção vencedora.
- **Acampamentos perto do herói** soltam guardas. O estandarte pode ser derrubado com a espada ou com a Bola de Fogo. Isso enfraquece a facção, tira território, dá ouro, XP e gema, e aumenta o **rancor**.
- **Rancor**: facções com muito rancor e força **invadem os portões da Vila do Bosque à noite**.

Tudo fica registrado nas **Crônicas do Mundo**: no menu de pausa, toque em "Crônicas".

### Noite
À noite os monstros enxergam 60% mais longe, correm 20% mais rápido, atacam 25% mais seguido, batem 20% mais forte e aparecem em maior número. Ao anoitecer aparece o aviso "A noite caiu...".

## Para criaturas e NPCs novos
Qualquer monstro novo entra no sistema sem código extra:
1. Coloque-o em `members` de uma facção em `Factions.DATA`, ou adicione `"faction": "<id>"` no `MonsterDB`.
2. Para uma facção nova (ex.: **bandidos**, quando houver a arte), preencha `members`, `elite`, `home`, `color`, `ambition` e `props` (visual do acampamento). Com `members` vazio a facção fica adormecida.

A partir daí ela aprende, evolui, ergue acampamentos, disputa territórios e entra nas guerras.
