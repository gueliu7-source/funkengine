MODS DO FUNKFORGE (estilo Psych Engine / Codename Engine)
=========================================================
Cada pasta em mods/ é um mod. No menu, F5 abre a tela de mods: ENTER liga/desliga,
SHIFT+setas muda a prioridade (o de cima vence), ESC aplica. Não precisa recompilar.

Ordem de prioridade dos arquivos: mods ativos (de cima para baixo) > mods/ (arquivos globais) > assets/.
Um mod só precisa ter os arquivos que muda ou adiciona.

mods/<nome>/
  pack.json                       nome, descrição, autor, versão e cor (opcional)
  scripts/*.hx|*.lua              rodam em TODA música
  data/songs.json                 { "songs": [ { "id": "minha-musica", "name": "Minha Música", "week": 0 } ] }
                                  (pastas em data/songs/ sem entrada no songs.json entram sozinhas)
  data/songs/<id>/<id>.json       chart (-easy / -hard para dificuldades) — formato funkforge-2 ou o legado do FNF/Kade
  data/songs/<id>/*.hx|*.lua      scripts só dessa música
  data/stages/<stage>.json        cenário (+ <stage>.hx|lua com o efeito do cenário)
  data/characters/<id>.json       personagem (+ <id>.hx|lua)
  images/...                      imagens e atlas (characters/, stages/, noteskins...)
  songs/<id>/Inst.ogg, Voices.ogg áudio da música
  music/, sounds/, fonts/         substituem o arquivo de mesmo nome do jogo base

Arquivos soltos direto em mods/ (fora de qualquer pasta de mod) valem para todos os mods, como no Psych.
Scripts de scripts/ e data/songs/<id>/ SOMAM (rodam os do jogo base e de todos os mods ativos).
Stage, personagem, chart, imagens e sons SUBSTITUEM pelo arquivo do mod de maior prioridade.
Veja mods/example para um mod pronto. Para criar o seu: copie mods/example e edite o pack.json.

ADICIONAR MÚSICAS AO FREEPLAY
-----------------------------
  python3 tools/add_song.py <pasta-ou-zip-da-musica> --mod meu-mod --name "Nome da Música"
A pasta/zip traz o chart (.json; -easy/-hard viram dificuldades) e Inst.ogg/Voices.ogg (mp3/wav são convertidos
se houver ffmpeg). Ele cria os arquivos em mods/<mod>/ e registra a música em data/songs.json. Detalhes: --help.


=== MENUS POR MOD ===
- data/menus/mainmenu.json : troca os botões do menu principal.
  {"items":[{"id":"story","anim":"story mode","state":"story"},
            {"id":"extra","label":"Extras","state":"mod:extras"}]}
  Cada item: anim (nome no atlas FNF_main_menu_assets) OU image (images/...) OU label (texto);
  state: title, mainmenu, story, freeplay, options, mods, controls, editors ou mod:<nome>.
- scripts/menus/<tela>.hx (title, mainmenu, story, freeplay, options, mods, controls) e scripts/menus/all.hx:
  onCreate, onCreatePost, onUpdate(elapsed), onSelect(id) (devolva true para cancelar o padrão), onDestroy.
  Funções: add, remove, insert, makeSprite, makeText, color, sound, music, go, get, set, readText, readJson; variável `state`.
- states/<nome>.hx : tela inteira feita por mod (abra com go("mod:<nome>")); ESC volta ao menu (onBack devolvendo true cancela).

=== EVENTOS NOVOS ===
Add Character (v1 "id" ou "id:tag"; v2 "seguir,dx,dy"), Remove Character, Move Character, Character Visible,
Set Dance Speed, Set Zoom, Camera Angle, Screen Fade, Set Health, Play Sound. Play Animation também aceita a tag de extras.
F3 no jogo: painel de FPS/RAM (oculto, simples, completo).

=== MODCHART (scripts .hx/.lua da música) ===
Alvo: 0-7 (0-3 oponente, 4-7 jogador), "player", "opponent", "all" ou lista "0,2,5".
Propriedades: x, y (centro da seta na tela), angle, alpha, size (1 = normal), waveX, waveY (balanço em px), waveSpeed (ciclos/s).
As notas acompanham a seta. A velocidade por seta continua em setStrumSpeed(jogador, lane, velocidade).
  tweenStrum("giro", "player", {angle = 360}, 1, "quadOut", 0.1)   -- 0,1 s de atraso entre uma seta e a próxima
  setStrum("opponent", {alpha = 0.3, x = 200})                      -- muda na hora
  getStrum(4, "y")                                                  -- lê uma propriedade
  resetStrums(0.5)                                                  -- volta tudo ao normal em 0,5 s (0 = na hora)
  setStrum("all", {waveX = 30, waveSpeed = 0.5})                    -- balanço contínuo
Sem script: o evento "Strum Tween" do chart (Chart Editor) faz o mesmo: Alvo,propriedade,valor + duração,ease,escalonamento.

=== EXTRAS DOS SCRIPTS DE MENU ===
tween(obj, {x=100}, 0.5, "quadOut", aoTerminar) · timer(seg, fn, ?vezes) · hover(obj) · clicked(obj)
button(x, y, largura, altura, "texto", function() ... end, ?cor)  → objeto com .bg, .label, .enabled, setText()
list(x, y, largura, ["A","B"], function(i, nome) ... end, ?tamanho) → ↑↓/W S/mouse/ENTER; objeto com .index, selected(), setIndex()
saveData("chave", valor) / loadData("chave", padrão): salva entre sessões. Exemplo completo: mods/example/states/demo.hx
