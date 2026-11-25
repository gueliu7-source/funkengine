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
