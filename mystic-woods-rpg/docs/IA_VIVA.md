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

### Referências novas (pesquisa de out/2026)

| Obra | Tipo | O que inspira no jogo |
|---|---|---|
| **Hell Mode: The Hardcore Gamer Dominates in Another World with Garbage Balancing** (Yarikomizuki no Gamer wa Hai Settei no Isekai de Musou suru) | light novel de Hamuo → anime (jan–mar/2026, 12 ep.) | O gamer que **escolhe a dificuldade "Inferno"** e renasce dentro do jogo como Allen, um servo, na classe **Invocador**. Para o jogo: um **"Modo Inferno"** ao começar, com monstros mais fortes, facções que aprendem e evoluem mais rápido e, em troca, **mais XP e drops**; e a futura classe/magia de **invocação**. |
| **Overgeared** (Tempal: Item no Chikara) | web novel/manhwa coreano → anime da J.C.Staff (outono/2026) | Grid, jogador mediano no VRMMO *Satisfy*, acha o tomo do **Sucessor de Pagma**, o ferreiro lendário: o poder vem de **forjar, avaliar, reparar e aprimorar itens**, não só de subir de nível. Para o jogo: **missão lendária na forja** que dá uma "classe" de ferreiro, **itens únicos com nome**, chance de forja épica/lendária, e monstros que **atacam por causa do seu equipamento** (facções de olho nos seus itens). |
| **I Became the Tyrant of a Defense Game** (디펜스 게임의 폭군이 되었다) | manhwa (Naver Webtoon) | O jogador que zerou o "Protect the Empire" no **modo mais difícil** é puxado para dentro dele. Para o jogo: **defender a vila contra ondas**, com as **invasões noturnas** das facções crescendo em ondas e uma **"Lua de Sangue"** de tempos em tempos. |
| **Kingdom: Two Crowns** | jogo | Tipos de onda: noturna, **Lua de Sangue**, defesa, contra-ataque e final. É o modelo direto para escalonar as invasões. |
| **Re:Monster** (temporada 2 anunciada) | isekai / anime | O goblin que **fica mais forte comendo outros** e sobe ao topo da comunidade. Para o jogo: monstros que **evoluem ao matar** (a facção vencedora de uma batalha fica com o poder do perdedor). |
| **Reincarnated as a Dragon Hatchling** | anime (jan–mar/2026) | Renascer como ovo numa floresta cheia de feras e **evoluir até o dragão mais forte**. Para o jogo: um **chefe que evolui ao longo do mundo** (um filhote que cresce enquanto o herói não o derrota). |
| **Chrysalis** | web novel / manhwa (colmeia de monstros) | Uma **colmeia/colônia** que cresce e se especializa (operárias, soldados, rainha). Para o jogo: o **Ninho das Aranhas** com rainha, larvas e soldados. Destruir a rainha derruba a facção. |
| **Low-Rank Soldier Becoming a Monarch** | manhwa | **Expansão de território militar**: avançar região por região. |
| **Solo Glitch Player** | manhwa | O jogador que sabe o futuro de um VRMMO e **reforma o território antes de uma guerra e uma fome**. Para o jogo: **eventos de mundo anunciados** (a guerra entre facções está chegando: prepare a vila). |
| **Tyrant of a Defense Game** / **Dungeon Reset** / **The Greatest Estate Developer** | manhwa | **Construção e recursos**: no futuro, o herói **fortifica a vila** (muralhas, torres, guardas) com os materiais que tira das facções. |
| **Renegade Immortal**, **Perfect World**, **Swallowed Star**, **Throne of Seal** | donghwa (2025–2026) | Escala de **cultivo e reinos de poder**, **seitas** como facções e **bestas demoníacas** com hierarquia. Para o jogo: os níveis das facções (Selvagens → Lendários) e futuras **bestas-rei** por região. |

#### Mecânicas que estas referências sugerem
Já no jogo: **Modo Inferno** (1) e **Sucessor de Pagma** (2), descritos no LEIA-ME. Próximas: 3 a 6.
1. **Modo Inferno** (Hell Mode): escolhido no "Novo jogo". Facções começam evoluídas, aprendem 2× mais rápido e invadem mais, com +50% XP e drops.
2. **Sucessor de Pagma** (Overgeared): missão do Ferreiro que libera a forja de **itens lendários com nome** e chance de forja épica.
3. **Lua de Sangue e ondas na vila** (Tyrant / Kingdom: Two Crowns): a cada X dias, as facções com rancor atacam a vila em ondas, e o herói prepara defesas.
4. **Rainha do Ninho** (Chrysalis): a facção das aranhas ganha uma rainha num ninho. Enquanto ela vive, o ninho repõe as aranhas.
5. **Dragão que cresce** (Dragon Hatchling): um chefe errante que evolui a cada dia sem ser derrotado.
6. **Invocação** (Hell Mode, classe Invocador): magia de invocar aliados, que também usa a mana.

Fontes da pesquisa: [Hell Mode (Wikipedia)](https://en.wikipedia.org/wiki/Hell_Mode), [Hell Mode (MyAnimeList)](https://myanimelist.net/anime/60460), [HIDIVE e Hell Mode (Anime Corner)](https://animecorner.me/exclusive-hidive-acquires-hell-mode-isekai-anime-for-winter-2026-simulcast-lineup/), [Overgeared (Anime Corner)](https://animecorner.me/db/anime/overgeared), [Overgeared ep. 1 (Final Weapon)](https://finalweapon.net/2026/09/21/overgeared-episode-1-review-crunchyroll-anime/), [Overgeared (Wuxiaworld)](https://www.wuxiaworld.com/novel/overgeared/og-chapter-99), [Tyrant of the Tower Defense Game](https://myanimepulse.com/manga/153518/tyrant-of-the-tower-defense-game), [Kingdom: Two Crowns, ondas](https://kingdomthegame.fandom.com/wiki/Waves), [Kingdom-building manhwa (Game Rant)](https://gamerant.com/best-kingdom-building-isekai-manhwa/), [Kingdom-building manhwa 2026 (SenpaiScore)](https://senpaiscore.com/best-kingdom-building-manhwa/), [Isekai do verão de 2026 (Anime Corner)](https://animecorner.me/the-season-of-isekai-anime-15-titles-from-another-world-releasing-in-summer-2026/), [Isekai do verão de 2026 (Mein-MMO)](https://mein-mmo.de/en/the-isekai-summer-2026-15-new-anime-set-in-strange-worlds,1577381/), [Reincarnated as a Dragon Hatchling](https://wrathofhobo.duckdns.org/tv/285291), [Donghua (GummySearch)](https://gummysearch.com/tools/best-products/donghua/).

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

### O inimigo número 1 é o herói
- Quando o herói entra no campo de visão, **facções em guerra param de brigar entre si e todas vão atrás dele** (trégua contra o inimigo comum).
- Quem apanha do herói fica focado nele por alguns segundos e ignora o resto.
- Elas só lutam entre si **com o herói longe**, e só por **território**.

### Riquezas da terra
- Cada região vale o que tem: **veios** (cobre, ferro, prata, ouro, cristal, ametista, rubi), ervas e frutos. A Pedreira e as regiões com ouro e cristal valem muito mais que o Prado.
- A terra controlada **alimenta** a facção: quanto mais rica, mais força por passo do mundo.
- As expansões e guerras **miram as regiões mais ricas**, e as crônicas dizem pelo que lutaram ("Batalha pelas riquezas da Pedreira Rochosa (prata, cristal e ferro)").
- Na região que domina, a facção **guarda os veios**: alguns monstros nascem de guarda ao lado dos minérios perto do herói.
- **Minerar ou colher na terra de uma facção** aumenta o rancor dela. Os membros por perto vêm atrás do "ladrão", e às vezes chegam reforços.
- Vencer monstros numa região **enfraquece o domínio** da facção ali. Monstro matando monstro **desloca o território** para o vencedor.

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
