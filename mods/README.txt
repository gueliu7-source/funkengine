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
