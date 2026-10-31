# Slime Fever — v0.20

## Abrir o jogo
Use Godot 4.7.2. Extraia o ZIP pelo Windows em uma pasta nova e importe o arquivo project.godot; aguarde a importação dos PNGs e pressione F5. Este pacote contém o projeto-fonte, não APK, executável nem build Web. O ZIP possui pastas explícitas e project.godot na raiz.

Na abertura, clique/toque em JOGAR ou pressione Enter. Segure as setas na tela ou use A/D e setas do teclado. II/Esc pausa; CONTINUAR retoma. SOM/MUDO alterna efeitos sonoros. Ao perder foco, uma partida em andamento pausa.

## v0.20 — Painel de Destino removido, melhorias de volta na loja
- O Painel de Destino e o botão DESTINO saíram do menu. A LOJA voltou a ter a aba MELHORAR, com as mesmas 12 melhorias (até nível 25) agrupadas em COLETA, PODER e SOBREVIVÊNCIA.
- Sem corrente de desbloqueio: todas abrem desde o começo. As de chefão (FEBRE DOURADA, ÍMÃ AUTOMÁTICO, SEGUNDA CHANCE) abrem ao derrotar o chefão.
- Cada linha mostra o efeito atual -> próximo, uma barra de nível com "12/25" e o preço (TRAVADO ou MÁX quando for o caso).
- Níveis, moedas e poderes já comprados foram mantidos (o save continua na mesma seção). Saves da loja antiga de 5 níveis seguem convertidos (x3).
- Os testes do painel foram para Tests/verify_shop.gd.

## v0.19 — Controle por toque no celular
- Celular (APK e navegador do celular): as setas da tela saem. Segure e arraste o dedo em qualquer lugar abaixo do HUD e o slime anda até a posição do dedo e para embaixo dele; um anel no chão marca o destino. Soltar o dedo para o slime.
- O slime usa a velocidade normal (com o bônus de AGILIDADE), então a rota segura das moedas continua valendo igual às setas.
- Toques no topo (pausa e som) continuam indo para os botões; o primeiro dedo manda (um segundo dedo não rouba o controle); pausar solta o dedo.
- PC: continua com as setas na tela, as setas do teclado e A/D. O modo é escolhido sozinho pela tela de toque do aparelho (TouchSteer.gd, GameManager.touch_controls()).
- Novo teste Tests/verify_touch.gd; testado também no Chromium em modo celular e desktop.

## v0.18 — Abertura variada e DIFÍCIL de verdade
- Abertura: o padrão CHUVA CALMA deixava todas as moedas na mesma coluna. Agora as moedas passeiam para os lados em passos pequenos (sempre alcançáveis): de 1 para 11-13 colunas nos primeiros segundos. Novo padrão PASSEIO (passos maiores) entra no sorteio do resto da partida.
- Regras por modo (GameManager.MODE_*):
  - DIFÍCIL: bombas a partir de 2 s (antes 8 s), velocidade inicial 1,25x (antes 1,15x), bombas bem mais próximas (~198 por minuto no 1º minuto, antes ~109), chuva no máximo em 45 s (antes 80 s), bombas deslizam mais, ímãs mais raros, chefões com +2 de vida e 35 s. Em troca, moedas e pontos valem 1,5x.
  - FÁCIL: 10 s sem bombas e chuva crescendo mais devagar. MÉDIO segue igual.
- A auditoria da chuva de bombas continua passando nos 3 modos (nenhuma bomba cai no caminho das moedas); partida automática vence o chefão do DIFÍCIL com folga de 21 s.

## v0.17 — Painel de Destino (fase 2 do incremental)
- Novo botão DESTINO no menu abre o Painel de Destino, estilo Albion: um mapa de nós a partir do slime, em 3 ramos (COLETA, PODER e SOBREVIVÊNCIA), cada nó com até 25 níveis.
  - COLETA: ALCANCE (+4% de área por nível), AGILIDADE (+1,2% de velocidade), VALOR (novo: +5% de pontos por moeda e chance de moeda extra na carteira) e FEBRE DOURADA.
  - PODER: FEBRE (+0,2 s), SORTE (ímãs 4% mais frequentes), ÍMÃ (+0,4 s e mais alcance) e ÍMÃ AUTOMÁTICO (intervalo cai de 40 s até 15 s).
  - SOBREVIVÊNCIA: ESCUDO (novo: +3% de chance de começar com escudo), RESISTÊNCIA (novo: +2,5% de chance de não perder o combo ao errar uma moeda), TESOURO (novo: +8% no baú dos chefões) e SEGUNDA CHANCE (1, 2 ou 3 por partida nos níveis 0, 10 e 20).
- Regra de desbloqueio: um nó abre quando o nó abaixo dele chega ao nível 5. Os nós de chefão (topo de cada ramo) também precisam do chefão derrotado. As linhas acendem na cor do ramo conforme abrem.
- Custo sobe 17% a cada nível (o primeiro nível custa de 30 a 150 moedas conforme o nó). Valores grandes aparecem como "1,2 mil".
- Progresso antigo convertido: cada nível de upgrade da loja antiga vira 3 níveis no painel. A loja agora tem ITENS e VISUAL; melhorias e poderes ficam no painel.
- Ícones novos de VALOR e RESISTÊNCIA (PixelLab). Novo teste Tests/verify_destiny.gd.

## v0.16 — Chefões animados e efeitos VFX
- Animações PixelLab (animate-with-text-v3, 9 quadros de 128 px) para os 3 chefões: arremesso, dano e morte (Assets/Boss/boss{1,2,3}_{throw,hurt,death}.png).
- Durante a luta, cada bomba sai da mão do chefão (ele toca a animação de arremesso) e voa até o ponto de onde cai; a bomba de verdade e a regra de segurança continuam as mesmas.
- Bomba dourada devolvida: impacto VFX em estrela (Assets/VFX/boss_hit.png), animação de dano, recuo e clarão vermelho.
- Derrota: animação de morte com pequenas explosões, depois a grande explosão VFX com fumaça e moedas voando (Assets/VFX/boss_death.png), tremor e achatamento. A celebração (vitória, poder, zona, baú) vem depois, e a lojinha em seguida.
- Avisos ficam abaixo do chefão enquanto ele está na tela. Função genérica play_vfx() para os efeitos PixelLab.

## v0.15 — Fase 1 do incremental: chefões e zonas
- Níveis sem limite: um nível a cada 1.000 pontos. A velocidade continua com teto (1,45x) e a densidade de bombas tem piso, então seguir as moedas continua sempre seguro.
- Chefão a cada 5 níveis (NV 5, 10, 15...): TOUPEIRA BOMBARDEIRA, GOLEM DE CRISTAL e REI SLIME (arte PixelLab), depois repetem mais fortes. O chefão chega pelo topo da caverna, com barra de vida e 45 s.
- Luta: uma a cada 4 moedas da rota vira uma BOMBA DOURADA (anel e faíscas). Pegando, o slime arremessa a bomba de volta no chefão. Bombas normais continuam machucando; a dourada sempre cai na rota segura. Vida do chefão: 4 + 2 por zona.
- Vitória: baú com 60 x zona moedas, a próxima ZONA (cenário muda de cor: Caverna Azul, Gruta de Cristal, Covil do Rei; moedas valem +50% de pontos e +1 na carteira por zona) e a lojinha de recompensa. Se o tempo acabar, o chefão foge sem recompensa.
- Poderes ganhos na primeira vitória contra cada chefão (permanentes, aba PODERES da loja): SEGUNDA CHANCE (sobrevive a 1 bomba por partida), ÍMÃ AUTOMÁTICO (a cada 40 s) e FEBRE DOURADA (moedas em dobro na febre).
- A lojinha da partida agora aparece depois de cada chefão vencido, não a cada nível. Os 3 modos continuam.
- Teste novo Tests/verify_boss.gd e auditoria da chuva de bombas incluindo as lutas. Partida automática de teste vence o primeiro chefão em ~11 s sem erros.
- Próximas fases: painel de destino (estilo Albion) com habilidades de 25+ níveis e renascimento (prestígio).

## v0.14 — Loja com vendedor, lojinha na partida, itens e visuais
- Cada moeda pega entra na carteira na hora (com MOEDAS x2 entra em dobro), então dá para gastar durante a partida.
- LOJA do menu com vendedor (slime roxo gerado no PixelLab) e 3 abas:
  - MELHORAR (permanente, 5 níveis): ÍMÃ, FEBRE, SORTE e as novas ALCANCE (+15% de área para pegar moedas por nível) e AGILIDADE (+5% de velocidade por nível).
  - ITENS (até 3 de cada, usados sozinhos ao começar a próxima partida): ESCUDO INICIAL (60) e ÍMÃ INICIAL (40).
  - VISUAL: cores do slime (AZUL 150, ROXO 250, ROSA 300, OURO 500), compradas uma vez e trocadas quando quiser. A cor é um shader que muda só o verde do corpo.
- LOJINHA na partida: a cada nível (5.000 pontos) o jogo pausa e oferece ESCUDO (40, aguenta 1 bomba), ÍMÃ AGORA (25) e MOEDAS x2 por 20 s (35). Só abre se der para comprar pelo menos um item; Esc ou CONTINUAR volta ao jogo.
- Escudo: bolha azul em volta do slime e ícone no HUD; ao absorver uma bomba dá 1 s de proteção. MOEDAS x2 mostra o tempo no HUD.
- As setas de toque só aparecem durante a partida. Avisos na tela não se sobrepõem mais.
- verify_shop.gd cobre itens, escudo, lojinha, moedas x2, alcance, visuais e o save.

## v0.13 — Ímã, carteira e loja de upgrades
- Ímã (power-up): a cada ~22 s (depois dos 8 s iniciais) uma moeda da rota vira um ímã, então ele sempre cai num lugar seguro. Pegar o ímã atrai as moedas próximas por alguns segundos; um anel rosa mostra o alcance e o HUD mostra o tempo restante. Não conta como moeda nem quebra o combo.
- Carteira: cada moeda pega soma 1, salva entre partidas. O fim de jogo mostra "+N MOEDAS".
- LOJA no menu, com 3 upgrades de 5 níveis:
  - ÍMÃ: 5 s +1,5 s por nível e alcance maior (60/150/300/500/800 moedas).
  - FEBRE: 6 s +0,8 s por nível (80/180/350/600/900).
  - SORTE: power-ups mais frequentes, de 22 s até ~9 s (70/160/320/550/850).
- Novos upgrades: basta adicionar uma entrada em GameManager.UPGRADES e ler o nível onde fizer efeito.
- Ícones (ímã, chama, trevo) gerados no PixelLab. Novo teste Tests/verify_shop.gd; o teste da chuva de bombas confirma que os power-ups caem na rota protegida.

## v0.12 — Correção: seta presa no navegador do celular
- Bug: jogando pelo navegador no celular, uma seta podia ficar "segurada" depois de soltar o dedo; segurando a outra, as duas se anulavam e o slime ficava parado na borda.
- Causa: na versão Web o Godot repassa o movimento do dedo (evento pointermove do navegador) como movimento de mouse com o botão pressionado, e nenhum "soltar" chega quando o dedo sai da tela. A seta tratava isso como mouse segurado.
- Correção (DirectionButton.gd): enquanto houver um dedo na tela, as setas ignoram eventos de mouse, que nesse caso são só o eco do toque. Mouse de verdade no PC continua funcionando.
- Teste de regressão em verify_patterns_controls.gd (falha no código antigo, passa no novo) e cenário reproduzido no Chromium em modo celular.

## v0.11 — Bomba animada
- Bomba com animação nova gerada no PixelLab (animate-with-text-v3 a partir da arte original): pavio aceso com faíscas em loop enquanto cai (Assets/VFX/bomb_fuse.png, 6 quadros a 12 fps).
- Ao encostar, a bomba para, incha, esquenta em vermelho com rachaduras de luz e fica quase branca (Assets/VFX/bomb_detonate.png, 5 quadros a 24 fps); esse branco emenda no clarão inicial da explosão. Vale para a derrota e para as bombas da febre.
- Removidos os quadros antigos da bomba (pasta north/), que ficavam escondidos. A tela de fim de jogo agora espera 1,2 s.

## v0.10 — Voltar ao menu e limpeza
- Botão MENU PRINCIPAL na pausa e no fim de jogo. Sair pela pausa abandona a partida (a pontuação não conta como recorde); o menu permite trocar de modo e jogar de novo.
- Removidos arquivos sem uso: original_art_1-4.png, untitled (1).png, a pasta rotations/ e a cena item.tscn. Removidos de main.tscn o fundo antigo (Fundo_Parede), o chão (Chao_Visual) e o placar antigo (ScoreLabel), que ficavam escondidos.
- verify_flow.gd agora testa os dois caminhos de volta ao menu e jogar de novo em seguida.

## v0.9 — Explosão das bombas
- Animação de explosão gerada no PixelLab VFX (Assets/VFX/explosion.png, 10 quadros a 10 fps): clarão branco, bola de fogo e fumaça.
- Ao encostar numa bomba: explosão grande sobre o slime, clarão rápido na tela e tremor; a tela de fim de jogo espera 1 s para a explosão aparecer, com o HUD ainda visível.
- Durante a febre, a bomba tocada também explode (menor) enquanto vira +20 pontos.

## v0.8 — Modos de dificuldade, níveis e moedas valorizadas
- Menu com FÁCIL, MÉDIO e DIFÍCIL. O modo escolhido fica salvo e cada modo tem o próprio recorde (o recorde antigo virou o do MÉDIO).
  - FÁCIL: queda 12% mais lenta e bombas mais espaçadas. MÉDIO: o ritmo da v0.7. DIFÍCIL: queda 15% mais rápida e bombas mais próximas.
- A cada 5.000 pontos sobe um nível (até o nível 7): tudo cai 7% mais rápido e as bombas ficam 10% mais frequentes. Aviso "NÍVEL X! MAIS RÁPIDO" na tela. O HUD mostra modo e nível.
- Valor das moedas pelas febres da partida (no combo x4): 40 normalmente, 75 a partir da 3ª febre e 100 a partir da 5ª. Nos outros multiplicadores é proporcional (x1 = 10, 19, 25). Aviso "MOEDAS VALEM ATÉ 75!/100!".
- A velocidade máxima é limitada (1,45x) para que a distância entre moedas continue alcançável, e a chuva de bombas continua sem cair no caminho das moedas em todos os modos e níveis.
- Novo teste Tests/verify_modes.gd; o teste da chuva agora cobre os três modos e todos os níveis (7.793 bombas auditadas).

## Versão Web (itch.io)
Zip pronto em releases/SlimeFever-web-v0.20.zip (index.html na raiz, versão sem threads, que roda no itch.io sem configuração extra). Para gerar de novo, com os templates Web do Godot 4.7.2 instalados:

    godot --headless --path . --export-release "Web" ../web/index.html

No itch.io: Kind of project = HTML, enviar o zip e marcar "This file will be played in the browser"; Viewport 450 x 800, "Mobile friendly" (orientação retrato) e "Fullscreen button".

## APK Android
O APK pronto fica em releases/SlimeFever-v0.20.apk na raiz do repositório (arm64 e armv7, Android 7+ recomendado). Para gerar de novo: Godot 4.7.2 com os templates de exportação, apksigner do Android SDK e uma keystore; preset "Android" em export_presets.cfg (pacote com.blucas157.slimefever, sem Gradle, ícone em Assets/Icon/).

    godot --headless --path . --export-release "Android" ../releases/SlimeFever.apk

A keystore não vai para o repositório. Um APK assinado com outra chave exige desinstalar a versão anterior antes de instalar.

## v0.7 — Chuva de bombas aleatória
As bombas deixaram de cair em fileiras (5 colunas fixas, junto com as moedas). Agora têm ritmo próprio:
- Posição livre em toda a largura, intervalo aleatório e rajadas de 2 a 3 bombas seguidas.
- Velocidades diferentes (queda de 1,25 s a 2,5 s) e cerca de metade desliza na diagonal, balançando.
- A intensidade cresce aos poucos durante cerca de 80 s depois dos 8 s iniciais sem bombas.
- Continua justo: o spawner conhece as próximas moedas e nunca solta uma bomba que caia no caminho entre a moeda anterior e a próxima. No máximo 3 bombas chegam ao chão no mesmo instante.

Teste novo em verify_patterns_controls.gd: 40 partidas simuladas de 90 s (5.234 bombas) conferindo cada bomba contra cada moeda, uso da largura toda, variedade de velocidades, deriva e rajadas. Todos os testes passaram no Godot 4.7.2.

## v0.6 — HUD novo (PixelLab)
Toda a interface foi refeita com um kit gerado pela API do PixelLab (generate-ui-v2, create-ui-asset e generate-font-pro), na mesma paleta da caverna: azul-marinho, teal, verde-menta e dourado.

- Placar com moeda animada, pontos, recorde e efeito de "pulo" a cada ponto. Badge dourado de multiplicador e contador de sequência.
- Barra de FEBRE com moldura em pixel art: enche em verde (x/20 moedas) e fica dourada e pulsando durante a febre.
- Botões de pausa e som com ícones (alto-falante/mudo), botões grandes JOGAR (verde), CONTINUAR (verde) e JOGAR DE NOVO (dourado), todos com afundamento e "squash" ao toque.
- Setas de toque com arte PixelLab e estado pressionado. Área de toque um pouco maior (250x224).
- Menu, pausa e fim de jogo em janelas com moldura de cristal, fundo escurecido e animação de entrada. O fim de jogo conta os pontos, destaca NOVO RECORDE! e mostra tempo, combo e febres.
- Logo do título gerado no PixelLab (Assets/UI/logo.png), flutuando no menu.
- Fonte pixelada própria (Assets/UI/slime_fever.ttf) com acentos do português adicionados.
- Código da interface em Assets/Scripts/HudKit.gd (nine-slice, fonte, botões); Main.gd monta as telas.

Os testes passaram no Godot 4.7.2 (headless): padrões e controles (85.099 verificações), gameplay (14), slime e fluxo (0 falhas). verify_flow.gd agora usa scene.play_button e scene.resume_button. Capturas foram renderizadas e inspecionadas. Ainda não houve teste em celular físico.

## Atualização (v0.5)
- Menu inicial com instruções; nenhuma moeda, perigo ou temporizador avança antes de começar.
- Toque convertido em mouse para os botões da interface. As setas ignoram esses eventos duplicados e mantêm suporte a múltiplos dedos e mouse real.
- Pausa e retomada do áudio e dos efeitos de interface junto com a simulação.
- Resultado com tempo, maior sequência, febres e recorde.
- Replay reaproveita a cena, restaura o slime e limpa itens/efeitos. Não recria controles nem conexões de sinais.
- Se a gravação do progresso falhar, o resultado informa que o progresso vale somente para a sessão.
- Mantidos padrões, combo, febre e quatro reações PixelLab da versão anterior. Não houve nova geração de assets nesta atualização.

## Validação
A versão anterior abriu nos testes locais sem reproduzir o erro relatado, cujo texto não foi fornecido. Esta atualização corrige problemas encontrados na revisão, sem atribuir uma causa confirmada à mensagem vista pelo usuário.

Testes no Godot 4.7.2: importação limpa; 18.000 linhas geradas com 100 seeds; teclado/mouse/toque sintético em três viewports; regressão de coleta/febre/save/replay; animações; toque nativo convertido em clique nos botões JOGAR, SOM e CONTINUAR; vinte replays seguidos sem duplicação de controles ou conexões. Capturas de menu e resultado foram renderizadas e inspecionadas.

O ambiente de testes restringe AppData e certificados do sistema, gerando avisos de logs/cache/certificados. O teste de save foi redirecionado ao workspace via SLIME_TEST_SAVE. Isso não equivale a teste em celular físico ou em navegador. Exportação Web, SDK CrazyGames e playtest com pessoas continuam pendentes.

## Reexecutar os testes
A partir da pasta do projeto, com o executável Godot disponível no PATH:

    godot --headless --path . --script res://Tests/verify_patterns_controls.gd
    godot --headless --path . --script res://Tests/verify_gameplay.gd
    godot --headless --path . --script res://Tests/verify_slime.gd
    godot --headless --path . --script res://Tests/verify_flow.gd

Os testes de save usam arquivos separados do progresso real. SLIME_TEST_SAVE pode indicar um caminho temporário alternativo. HISTORICO.md documenta o desenvolvimento anterior e a origem dos assets; LEIA-ME.md é a referência para o comportamento desta versão.

Observação de diagnóstico: a regressão executada sem janela ainda reporta oito recursos de áudio no encerramento do driver headless. Foram adicionadas parada explícita e liberação de streams no replay/fechamento, mas esse aviso não foi eliminado no teste. Não foi aprovado teste prolongado de memória/áudio em dispositivo real.
