# Slime Fever — v0.5

## Abrir o jogo
Use Godot 4.7.2. Extraia o ZIP pelo Windows em uma pasta nova e importe o arquivo project.godot; aguarde a importação dos PNGs e pressione F5. Este pacote contém o projeto-fonte, não APK, executável nem build Web. O ZIP possui pastas explícitas e project.godot na raiz.

Na abertura, clique/toque em JOGAR ou pressione Enter. Segure as setas na tela ou use A/D e setas do teclado. II/Esc pausa; CONTINUAR retoma. SOM/MUDO alterna efeitos sonoros. Ao perder foco, uma partida em andamento pausa.

## Atualização
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
