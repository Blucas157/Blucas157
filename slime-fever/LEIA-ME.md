# Slime Fever — v0.11

## Abrir o jogo
Use Godot 4.7.2. Extraia o ZIP pelo Windows em uma pasta nova e importe o arquivo project.godot; aguarde a importação dos PNGs e pressione F5. Este pacote contém o projeto-fonte, não APK, executável nem build Web. O ZIP possui pastas explícitas e project.godot na raiz.

Na abertura, clique/toque em JOGAR ou pressione Enter. Segure as setas na tela ou use A/D e setas do teclado. II/Esc pausa; CONTINUAR retoma. SOM/MUDO alterna efeitos sonoros. Ao perder foco, uma partida em andamento pausa.

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

## APK Android
O APK pronto fica em releases/SlimeFever-v0.11.apk na raiz do repositório (arm64 e armv7, Android 7+ recomendado). Para gerar de novo: Godot 4.7.2 com os templates de exportação, apksigner do Android SDK e uma keystore; preset "Android" em export_presets.cfg (pacote com.blucas157.slimefever, sem Gradle, ícone em Assets/Icon/).

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
