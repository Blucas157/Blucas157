# Regras do projeto (Mystic Woods RPG)

- Responder sempre em português.
- O usuário joga e testa no Android (Godot 4.7.2 no celular).
- Este repositório é público: os sprites do pacote Mystic Woods não podem vir para cá (licença). Eles ficam só no repositório privado **Blucas157/RepGodot** (`main`).
- **A cada alteração no jogo:**
  1. Rodar os testes (`tests/verify_*.gd`, headless).
  2. Fazer commit e push aqui e sincronizar/push no RepGodot (`main`), sem copiar `.import`, `.godot`, `.gitignore` e `LEIA-ME.md`.
  3. **Gerar o APK** com `tools/android/build_apk.sh <godot> <RepGodot>/android/mysticwoods.keystore mysticwoods mysticwoods`. O script sobe o `version/code` sozinho; esse `export_presets.cfg` alterado também vai no commit.
  4. Publicar o APK no branch `apk` do RepGodot (branch órfão com um só commit, push forçado, arquivo `MysticWoodsRPG.apk`) e enviar o arquivo ao usuário.
- Arte: estilo do pacote (contorno preto, 2–3 tons, paleta do pacote). Monstros comuns na escala do herói (grade de 32 px), golens como mini-chefes, Ent como chefe. Mostrar cada design novo para validação antes de animar.
