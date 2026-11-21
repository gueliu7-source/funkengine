# FunkForge
Engine de FNF em Haxe/HaxeFlixel (reescrita modular inspirada na Kade 1.8). Scripts `.hx` e `.lua`.

## Compilar
1. Instale Haxe 4.3.x e rode:
   `haxelib install lime && haxelib install openfl && haxelib install flixel && haxelib install flixel-addons && haxelib install hscript && haxelib install linc_luajit`
   `haxelib run lime setup` e `haxelib run lime setup flixel`
2. Importe os assets: `python tools/import_assets.py --src PASTA_DOS_ZIPS --out assets`
   (já feito se a pasta `assets/` veio preenchida)
3. `lime test windows` (ou `lime test hl` para compilar mais rápido)
   Sem Lua: `lime test windows -DNO_LUA`

## Mods (estilo Psych/Codename)
Pasta `mods/<nome>/` com `pack.json`, `scripts/`, `data/`, `images/`, `songs/`... (estrutura completa em `mods/README.txt`).
No menu, F5 abre a tela de mods: liga/desliga e muda a prioridade. Sem recompilar.

## Desempenho
- Os arquivos de assets/ e mods/ são indexados uma vez; procurar um arquivo não acessa o disco.
- Notas e sprites reaproveitados (pool), texturas/atlas/sons em cache e liberados a cada música.
- Scripts só são chamados se definem a função do callback.

## Scripts
Veja `mods/example/scripts` e `assets/data/stages/halloween.hx`. Callbacks: onCreate, onUpdate,
onBeatHit, onStepHit, onEvent, goodNoteHit, noteMiss, etc. Mesma API em .hx e .lua.
Modcharts antigos da Kade foram salvos como `.kade` e não são compatíveis.

## Menus (estilo FNF original)
Título (intro + ENTER) -> Menu principal (Story Mode / Freeplay / Options) -> telas.
Setas ou W/S/A/D navegam, ENTER confirma, ESC volta. Os antigos atalhos F1-F5 agora estão em Options
(downscroll, middlescroll, ghost tap, botplay, velocidade, offset, mods e opções do HUD).

## HUD
Barra de vida e ícones deslizam suaves; ícones pulsam na batida, crescem ao acertar e encolhem ao errar;
suportam 3 frames (normal/perdendo/ganhando). Score conta subindo; accuracy com 2 casas.
