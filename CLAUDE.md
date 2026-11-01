# Cérebro do Slime Fever

Memória do projeto para qualquer sessão do Claude. Leia isto antes de mexer no jogo.
A versão completa e editável pelo dono fica no cofre Obsidian: repositório `Blucas157/Slime_fever`, pasta `Cérebro/`.

## Quem é o dono e como falar com ele
- O dono é Blucas157. Ele fala **português do Brasil**: responda sempre em português, com frases simples e passos numerados quando for algo no celular.
- Ele joga e testa **no celular Android** (APK) e no navegador do celular (itch.io), e manda prints e vídeos dos bugs.
- Ele anota ideias no Obsidian (cofre `Slime_fever`, nota `Tarefas/Quadro de tarefas.md`, formato Kanban). Item marcado `[x]` na coluna Ideias = pedido para fazer. Depois de fazer, mova para ✅ Pronto e registre no diário.

## O jogo
- Godot 4.7.2, GDScript, renderer GL Compatibility, retrato 1080x1920. Projeto em `slime-fever/`.
- Um slime anda na horizontal pegando moedas que caem e desviando de bombas. 20 moedas = FEBRE. Combo até x4. Níveis a cada 1000 pontos, sem fim. Chefão a cada 5 níveis (NV 5, 10, 15...), derrotado devolvendo bombas brilhantes. Vencer o chefão muda a zona (cor, moedas valem mais) e libera um poder.
- Incremental + arcade: as moedas vão direto para a carteira e compram melhorias permanentes (12, até nível 25), itens e visuais na LOJA do menu. Lojinha rápida na partida depois do chefão.
- Modos FÁCIL, MÉDIO e DIFÍCIL com recordes separados. DIFÍCIL tem que ser difícil de verdade.
- Celular: controle por arrastar o dedo (TouchSteer.gd). PC: setas na tela e teclado.

## Regras que não podem quebrar
1. **Justiça das bombas**: bomba nunca cai na rota das moedas (margem 185 px entre moeda anterior, atual e seguinte). Qualquer mudança em velocidade, queda ou arena precisa passar no `Tests/verify_patterns_controls.gd` (auditoria de ~100 mil verificações).
2. Velocidade máxima `MAX_SPEED` 1.45 e densidade mínima `MIN_BOMB_GAP` protegem os níveis altos.
3. Save em `user://slime.cfg`. Nunca perca progresso do jogador: as melhorias ficam na seção `destiny` (nome antigo, mantido de propósito); saves antigos são convertidos.
4. Toda a interface é criada em código (`Main.gd` + `HudKit.gd`), com a arte PixelLab em `Assets/UI/`.
5. Arte nova sempre pelo **PixelLab** (API/MCP), no estilo pixel art do jogo.

## Arquivos principais
- `Assets/Scripts/GameManager.gd` (autoload): modos, níveis, chefões, zonas, melhorias, itens, visuais, oferta do dia, vibração, save.
- `Assets/Scripts/Main.gd`: HUD, menu, loja, lojinha, chefão, efeitos e sons.
- `Assets/Scripts/spawner.gd`: padrões de moedas, chuva de bombas justa e power-ups.
- `Assets/Scripts/FallingItem.gd`, `player.gd`, `TouchSteer.gd`, `DirectionButton.gd`, `HudKit.gd`.
- `Tests/verify_*.gd` + `Tests/run_all.sh`: a regressão. `verify_regression.gd` é a varredura geral: arte, saves quebrados ou antigos, robô jogando cada modo sem poder morrer, ciclos de reinício.
- `slime-fever/LEIA-ME.md`: notas de cada versão (em português).

## Como entregar uma versão
1. Suba `config/name` em `project.godot` e `version/code`/`version/name` no preset Android em `export_presets.cfg`.
2. Escreva a seção da versão no `LEIA-ME.md`.
3. **Rode a regressão completa (obrigatória):** `GODOT=<godot> slime-fever/Tests/run_all.sh`. Ela precisa terminar com "REGRESSÃO: tudo passou". Todo bug encontrado vira um teste novo (de preferência em `Tests/verify_regression.gd`), e o resultado vai para `Cérebro/Regressão.md` no cofre, na seção Histórico.
4. Exporte o APK assinado (`releases/SlimeFever-vX.apk`) e o zip Web sem threads para o itch.io (`releases/SlimeFever-web-vX.zip`, index.html na raiz). Apague os builds da versão anterior.
5. Commit e push no branch de trabalho. Mande os links `https://github.com/Blucas157/Blucas157/raw/<branch>/releases/...`.
6. Atualize o cofre Obsidian: diário da versão, quadro de tarefas, links e o Cérebro.

## Decisões já tomadas (não desfazer sem o dono pedir)
- O Painel de Destino (estilo Albion) foi feito na v0.17 e **removido na v0.20** a pedido do dono: fica só a LOJA.
- Chefões são derrotados **devolvendo bombas**, não atirando.
- Os 3 modos ficam; não há modo infinito separado (os níveis já são infinitos).
- Mobile = arrastar; PC = setas. As setas não aparecem no celular.
- Ritmo (v0.23): cada nível custa 1000 × bônus da zona, e os níveis ficam parados durante a luta com o chefão. Nenhum chefão pode ser pulado; a regressão confere.

## Objetivo do dono
"Criar um jogo diferente dos demais." Proponha ideias com identidade própria (veja `Cérebro/Identidade.md` no cofre), sempre perguntando antes de mudanças grandes no design.
