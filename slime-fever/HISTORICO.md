# Slime Fever — v0.2

## Como abrir
Extraia o ZIP, importe slime-fever/project.godot no Godot 4.7.2 e pressione F5. Aguarde a importação dos PNGs na primeira abertura. O pacote contém o código-fonte; não é um APK, executável ou build Web.

## Controles
Segure esquerda/direita na tela por toque ou mouse, ou use A/D e setas do teclado. II ou Esc pausa; CONTINUAR retoma. SOM alterna o áudio. Ao perder foco o jogo pausa. Jogar de novo reinicia imediatamente.

## Implementado
- Caverna e bomba novas geradas pelo PixelLab e integradas; slime e moedas originais mantidos.
- Deformação do slime, partículas, números flutuantes e tremor curto de impacto.
- Sons sintetizados localmente para coleta, febre e derrota, com limite de vozes e opção de silenciar.
- Moedas valem 10 pontos base; cinco coletas em sequência elevam o multiplicador, até x4. Perder uma moeda fora da febre zera a sequência.
- Vinte moedas carregam uma febre automática de seis segundos: ímã curto, mudança visual e bombas tocadas valendo 20 pontos. Barra não recarrega durante a febre.
- Sinalização visual nos últimos 1,5 s e 0,6 s de proteção ao terminar a febre.
- Primeiros oito segundos sem bombas. Bombas laterais alternadas, pistas visuais e aumento limitado da velocidade.
- Colisões filtradas e coleta resolvida uma única vez; derrota, replay e recorde local em ConfigFile.
- Pausa interrompe movimento, queda e temporizadores; interface continua ativa.

## Validação realizada
Godot 4.7.2: importação, execução e inspeção de captura renderizada. Passaram 14 verificações automatizadas: movimento nos dois sentidos, botão touch pressionado/solto, coleta única, combo/febre, bomba na febre, pausa dos timers, proteção, combo perdido, filtro de contato, derrota, save e replay. O teste de save usou um caminho temporário no workspace porque o ambiente restringe AppData.

Ainda falta teste manual de mouse e multitouch em aparelho físico, matriz de navegadores, export Web e SDK do portal. Não há templates de exportação disponíveis no ambiente verificado. O recorde no diretório padrão do usuário precisa de validação no ambiente normal. Logs do ambiente restrito apontam acesso negado a logs/shader cache e certificado do sistema, sem erro de script nos testes finais.

## Próximas etapas
- Playtest em celular para calibrar velocidade, alcance e momento da primeira febre.
- Adaptar templates Web, testar carregamento e limites do navegador; integrar CrazyGames após validar a build genérica.
- Ampliar padrões com verificação matemática de rotas: o diretor atual usa bombas laterais esparsas, não implementa ainda o validador de trajetórias completo do GDD.
- Mais animações do slime, música, opção de movimento reduzido, menu inicial e progressão cosmética.
- Esta versão é um primeiro vertical slice, não a implementação integral do GDD.

## Assets PixelLab
Gerados em 15/10/2026, custo informado pelo serviço: duas gerações no total.
- Assets/New/cave.png: 216x384, job 99511a0a-7a00-4741-aa0e-048bfa861100, asset d0769d58-6c82-5e3c-ad94-856a457c0069.
- Assets/New/bomb.png: 32x32 com transparência, job f617a218-b4f2-4b13-97fb-5e513f8eabab, asset 7989cee6-f6c3-5f44-a136-1ed7f68edbe8.
Resultados concluídos, salvos na galeria PixelLab e verificados localmente. Uso sujeito aos termos do serviço PixelLab. Arte original é proveniente do ZIP fornecido pelo usuário.

## v0.3 — padrões e controles, 17/10/2026

Quatro novos padrões de sete linhas: arco, zigue-zague, corredor e troca de lado. Cada padrão tem duas linhas extras de recuperação. A introdução usa chuva calma. A seleção evita repetir o último padrão e desbloqueia corredores com até duas bombas depois de 45 s. A etiqueta na interface identifica o padrão que está entrando; os itens anteriores podem continuar em queda.

Cada moeda tem um deslocamento máximo de 180 unidades em relação à anterior. Intervalo nominal de 0,72 s, com pelo menos 0,25 s de reação mais tempo de deslocamento a 850 unidades/s. Bombas são colocadas fora da faixa horizontal entre os alvos anterior, atual e seguinte, com margem de 185 unidades. Primeira e última linha do padrão, além da recuperação, não têm bombas. Todos os itens surgem abaixo do HUD, em y=410, e compartilham 1,7 s de viagem até y=1640; não há ultrapassagem entre linhas. Frames lentos adiam a próxima linha em vez de criar rajadas para compensar atraso.

Essa construção conserva uma rota testemunha que pode coletar as moedas sem tocar as bombas. Isso pressupõe arena, colisões e velocidade atuais: mudanças nesses valores exigem rever as margens e repetir os testes. Não garante recuperação de qualquer erro do jogador nem substitui avaliação de dificuldade com pessoas.

Controles da tela agora tratam mouse e toque diretamente, sem emulação: suportam dois dedos, arrastar de uma seta à outra, cancelamento de toque e soltura do mouse fora do botão. Comandos opostos se anulam; teclado e tela combinam sem somar velocidade. Soltar um botão não cancela uma tecla ainda pressionada. Pausa, derrota e perda de foco limpam os estados virtuais. O estilo do botão é reutilizado, evitando criar um recurso por frame.

Testes novos: 100 seeds, 2.000 padrões e 18.000 linhas, incluindo 9.063 bombas, verificando alcance das moedas, margens, densidade e emendas. Nenhuma falha nas 85.099 verificações, incluindo eventos sintéticos de mouse, touch, A/D e setas, três tamanhos de viewport, pausa e bordas. Regressão de gameplay: 14 verificações aprovadas. Eventos foram enviados ao sistema de entrada do Godot; não são testes em hardware físico nem no navegador.

Testes incluídos em Tests/. Para executar com Godot disponível no PATH, a partir da pasta do projeto:

    godot --headless --path . --script res://Tests/verify_patterns_controls.gd
    godot --headless --path . --script res://Tests/verify_gameplay.gd

A regressão grava um arquivo separado test-regression-save.cfg na pasta de dados do usuário. O ambiente restrito ainda emite avisos de logs/certificados e a regressão registrou quatro instâncias ObjectDB no encerramento; investigar esse aviso antes de declarar um teste prolongado de memória aprovado.

Não foram gerados novos assets PixelLab nesta etapa. Testar em celular real e exportar Web continuam pendentes.

## Pacote v0.3.1
Correção de empacotamento: project.godot diretamente na raiz do ZIP, caminhos de arte abreviados, sem cache .godot nem sidecars .import e referências de recursos por caminho. Extraia em uma pasta curta, como C:\Jogos\SlimeFever, depois use Import no Godot e selecione project.godot. Não extraia sobre uma versão anterior. As mecânicas da v0.3 foram preservadas.

## Slime v0.4 — novas reações

Melhorias do personagem: animações PixelLab para coleta, susto, febre e derrota, a partir do sprite verde frontal original. Cada sequência tem sete quadros de 52x52 (o original mais seis gerados), com transparência. Idle e corrida anteriores foram mantidos.

A coleta dispara uma comemoração curta com moeda. Uma bomba próxima pode provocar um recuo, com cooldown de 1,3 s para evitar repetição excessiva. Febre tem prioridade sobre coleta/susto, usa loop próprio e um anel luminoso desenhado por código. Derrota interrompe as outras reações, toca uma vez e comprime apenas o sprite; a forma de colisão não é alterada. Movimento continua durante coleta/susto/febre. Pausa congela também a animação.

Teste novo: Tests/verify_slime.gd verifica quadros, prioridades, movimento durante reação, pausa, fim sem loop e integridade da colisão. Passou sem falhas. Testes de padrões/controles passaram com 18.000 linhas; regressão de gameplay passou nas 14 verificações. O save da regressão foi redirecionado para o workspace com SLIME_TEST_SAVE por restrição de AppData. Ainda não foi feito playtest em aparelho físico ou navegador.

PixelLab: quatro gerações informadas pelo serviço, resultados concluídos e salvos na galeria:
- collect: job 35dc38e6-070f-490f-a663-6f8f6e414077; asset 166b8e7d-e7f5-589a-ae57-337d3ab814cc.
- startle: job fb131b12-2696-4000-b4f9-c57a1726a86f; asset 933c57ea-12c8-59e5-9cb4-7728855c9446.
- fever: job 72389b78-4517-41bb-8f6e-7212f232ec3d; asset e415426b-6273-5019-9b3f-e6fbc1592d7d.
- defeat: job bc9c4575-fbf6-47ee-996d-1da963e4b70c; asset a9e7ec80-0fe5-5db2-ba26-72b9088550f6.

O pacote possui project.godot na raiz e entradas explícitas de pastas. Prefira abrir a cópia já extraída local ou extrair pelo Windows em uma pasta nova antes de importar project.godot.
