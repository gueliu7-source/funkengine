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

## Scripts
Veja `mods/example/scripts` e `assets/data/stages/halloween.hx`. Callbacks: onCreate, onUpdate,
onBeatHit, onStepHit, onEvent, goodNoteHit, noteMiss, etc. Mesma API em .hx e .lua.
Modcharts antigos da Kade foram salvos como `.kade` e não são compatíveis.

## Controles do menu
Setas, ENTER, F1 downscroll, F2 middlescroll, F3 botplay, F4 ghost tap, F5 mod, [ ] velocidade, ; ' offset.
