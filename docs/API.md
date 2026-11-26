# API de scripts do FunkForge

_Gerado por `tools/gen_api_docs.py` a partir do código — não edite à mão._

Scripts `.hx` (HScript) e `.lua` usam as mesmas funções. **F6** no jogo recarrega os scripts da música.

## Callbacks e onde ficam os scripts

```
Carrega e dispara scripts .hx e .lua. Os dois tipos usam os mesmos callbacks:
   onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed), onStepHit(step), onBeatHit(beat),
   onSectionHit(sec), onCountdown(tick), onSongStart, onSongEnd, goodNoteHit(lane, rating, isSustain, type),
   opponentNoteHit(lane, isSustain, type), noteMiss(lane, type), onEvent(name, v1, v2), onPause, onResume,
   onGameOver (devolva "stop" para impedir), onTimerCompleted(tag, loops, loopsLeft), onTweenCompleted(tag), onDestroy.

 Onde procura scripts (todos opcionais):
   scripts/*.hx|lua                     globais, em toda música
   data/songs/<musica>/*.hx|lua         da música
   data/stages/<stage>.hx|lua           do cenário
   data/characters/<personagem>.hx|lua  de cada personagem em uso
 scripts/ e data/songs/<musica>/ somam os arquivos de assets/ e de todos os mods ativos;
 stage e personagem usam só o arquivo de maior prioridade (o mod substitui o original).
```

## Funções dos scripts de música


### utilidades

- `debugPrint(text?)`
- `rgb(r, gr, b)` → `Int`
- `randomInt(min, max)` → `Int`
- `randomFloat(min, max)` → `Float`
- `randomBool(percent)` → `Bool`
- `fileExists(rel)` → `Bool`

### propriedades genéricas

- `getProperty(path)` → `Dynamic`
- `setProperty(path, value)`
- `getSetting(name)` → `Dynamic`

### sprites criados por script

- `makeSprite(tag, image, x?, y?)` → `Bool`
- `makeAnimatedSprite(tag, atlas, x?, y?)` → `Bool`
- `addAnimationByPrefix(tag, name, prefix, fps?, loop?)`
- `playSpriteAnim(tag, name, force?)`
- `addSprite(tag, layer?)` — layer: "back", "gf", "dad", "front" (cenário) ou "hud"
- `removeSprite(tag)`
- `setScrollFactor(tag, x, y)`
- `setSpriteScale(tag, sx, sy?)`
- `screenCenter(tag, axis?)`

### tweens e timers

- `doTween(tag, objPath, props, duration, easeName?)` — props: tabela/objeto, ex.: doTween("t1", "boyfriend", {x = 100, alpha = 0.5}, 1, "quadOut")
- `cancelTween(tag)`
- `runTimer(tag, seconds, loops?)`
- `cancelTimer(tag)`

### câmera

- `cameraShake(camName, intensity, duration)`
- `cameraFlash(camName, col, duration)`
- `cameraFade(camName, col, duration)`
- `setCameraZoom(camName, z)`
- `getCameraZoom(camName)` → `Float`
- `setDefaultCamZoom(z)`
- `cameraFocus(target)`

### personagens

- `characterPlayAnim(name, anim, force?)`
- `characterDance(name)`

### áudio

- `playSound(name, volume?)`

### estado do jogo

- `getScore()` → `Int`
- `getMisses()` → `Int`
- `getCombo()` → `Int`
- `getAccuracy()` → `Float`
- `getHealth()` → `Float`
- `setHealth(v)`
- `addHealth(v)`
- `getSongPosition()` → `Float`
- `getBpm()` → `Float`
- `getCurStep()` → `Int`
- `getCurBeat()` → `Int`
- `getCurSection()` → `Int`
- `setStrumSpeed(player, lane, v?)`
- `setScrollSpeed(v)`
- `getScrollSpeed()` → `Float`
- `endSong()`
- `triggerEvent(name, v1?, v2?)`

### receptores (0-3 oponente, 4-7 jogador)

- `getReceptorX(i)` → `Float`
- `getReceptorY(i)` → `Float`
- `setReceptorPos(i, x, y)`
- `setReceptorAngle(i, a)`
- `setReceptorAlpha(i, a)`

### modchart (ver game/Modchart.hx). alvo: 0-7, "player", "opponent", "all" ou "0,2,5"

- `tweenStrum(tag, target, props, duration, easeName?, stagger?)` — tweenStrum("t", "player", {y = 300, angle = 360}, 1, "quadOut", 0.1)   (0,1 = atraso entre setas)
- `setStrum(target, props)`
- `getStrum(i, prop)` → `Float`
- `resetStrums(duration?)`

## Modchart

Alvo: `0-7` (0-3 oponente, 4-7 jogador), `"player"`, `"opponent"`, `"all"` ou `"0,2,5"`. Propriedades: `x`, `y`, `angle`, `alpha`, `size`, `waveX`, `waveY`, `waveSpeed`, `wavePhase`.

## Scripts de menu (`scripts/menus/*.hx` e `states/*.hx`)

Callbacks: `onCreate`, `onCreatePost`, `onUpdate(elapsed)`, `onSelect(id)` (true cancela), `onBack` (só telas de mod), `onDestroy`.

- `add(o)`
- `remove(o)`
- `insert(at, o)`
- `makeSprite(image?, x?, y?)` → `FlxSprite`
- `makeText(x, y, w, text, size?)` → `FlxText`
- `color(s)` → `Int`
- `sound(n, vol?)`
- `music(n, vol?)`
- `go(target)`
- `get(f)` → `Dynamic`
- `set(f, val)`
- `tween(obj, props, duration, easeName?, onDone?)` → `FlxTween`
- `timer(seconds, fn, loops?)` → `FlxTimer`
- `hover(o)` → `Bool`
- `clicked(o)` → `Bool`
- `button(x, y, w, h, text, onClick, col?)` → `MenuButton` — button(x, y, largura, altura, "texto", function() {...}, ?cor)  -> objeto com .bg, .label, .enabled, setText()
- `list(x, y, w, labels, onPick, size?)` → `MenuList` — list(x, y, largura, ["A", "B"], function(i, nome) {...}, ?tamanho)  -> objeto com .index, selected(), setIndex()
- `saveData(key, val)` — dados salvos por mod/tela: saveData("chave", valor) / loadData("chave", padrão)
- `loadData(key, def?)` → `Dynamic`
- `readText(rel)` → `String`
- `readJson(rel)` → `Dynamic`

## Eventos do chart

- **Add Character** — Coloca mais um personagem no palco. Ele canta junto com o slot que acompanha (dad/bf) e dança no ritmo. Use 'id:nome' para dar um nome (e poder ter dois iguais). · Personagem (id ou id:nome) (padrão pico); Seguir, dx, dy (padrão dad,-300,0)

- **Camera Angle** — Inclina a câmera do jogo (graus) com transição opcional. · Ângulo (padrão 10); Duração (s) (padrão 1)

- **Camera Flash** — Flash de tela. Cor em hex e duração em segundos. · Cor (padrão FFFFFF); Duração (s) (padrão 0.5)

- **Camera Focus** — Move o foco da câmera para um personagem (vale até a próxima seção). · Quem (padrão bf)

- **Camera Zoom** — Soma zoom na câmera do jogo e na do HUD (volta suave ao normal). · Zoom do jogo (padrão 0.03); Zoom do HUD (padrão 0.05)

- **Change Character** — Troca quem ocupa um slot (bf, dad ou gf) a partir deste ponto da música. · Slot (padrão dad); Personagem (id) (padrão pico)

- **Character Visible** — Mostra ou esconde um personagem. · Personagem (padrão gf); Visível (padrão true)

- **Hey!** — Bf e/ou GF fazem a animação 'hey' (se existir). · Quem (padrão bf)

- **Move Character** — Move um personagem (bf, dad, gf ou nome de um extra) para x, y em segundos. · Personagem (padrão dad); x, y, segundos (padrão 500,300,1)

- **Play Animation** — Toca uma animação num personagem (ex.: hey, singUP). · Animação (padrão hey); Personagem (padrão bf)

- **Play Sound** — Toca um som de sounds/<nome>.ogg (do jogo ou de um mod). · Nome do som (padrão confirmMenu); Volume (padrão 1)

- **Remove Character** — Tira do palco um personagem criado com Add Character. · Nome (tag) (padrão pico)

- **Screen Fade** — Escurece/colore a tela inteira (acima do HUD). Cor vazia ou 'none' volta ao normal. · Cor (ou none) (padrão 000000); Duração (s) (padrão 1)

- **Screen Shake** — Treme a câmera do jogo. Intensidade (ex.: 0.01) e duração em segundos. · Intensidade (padrão 0.01); Duração (s) (padrão 0.4)

- **Scroll Velocity** — Muda a velocidade de rolagem das notas de forma contínua (estilo SV): as notas aceleram/desaceleram sem pular. · Multiplicador (padrão 1); Transição (ms) (padrão 0)

- **Set Dance Speed** — A cada quantos beats o personagem dança (bf, dad, gf ou extra). · Personagem (padrão gf); Beats (padrão 2)

- **Set Health** — Define a vida do jogador (0 a 100%). · Vida (%) (padrão 50); — (padrão )

- **Set Zoom** — Muda o zoom base da câmera do jogo (com transição opcional). · Zoom (padrão 1); Duração (s) (padrão 1)

- **Strum Tween** — Anima as setas. Alvo: player, opponent, all, 0-7 ou lista (0,2). Propriedades: x, y, angle, alpha, size, waveX, waveY, waveSpeed. · Alvo,propriedade,valor (padrão player,angle,360); Duração(s),ease,escalonamento(s) (padrão 1,quadOut,0.1)
