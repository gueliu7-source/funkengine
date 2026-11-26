#!/usr/bin/env python3
"""Cria um mod novo do FunkForge com arquivos de exemplo prontos.

  python3 tools/new_mod.py meu-mod
  python3 tools/new_mod.py meu-mod --com modchart menu tela musica stage personagem
  python3 tools/new_mod.py meu-mod --autor "Fulano" --descricao "Meu primeiro mod"

--com aceita: script (padrão), modchart, menu, tela, musica, stage, personagem, tudo.
Nada é sobrescrito: arquivos que já existem são mantidos.
"""
import argparse, json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mods")

SCRIPT = '''// Script de música (roda em TODAS as músicas deste mod). F6 no jogo recarrega este arquivo.
// Callbacks: onCreate, onCreatePost, onUpdate(elapsed), onBeatHit(beat), onStepHit(step), onSectionHit(sec),
//            onSongStart, goodNoteHit(lane, rating, isSustain, type), noteMiss(lane, type), onEvent(name, v1, v2)...
// Veja docs/API.md para todas as funções.

function onCreate() {
    debugPrint("%(nome)s carregado");
}

function onBeatHit(beat) {
    // exemplo: a cada 4 batidas, mostra a velocidade
    // if (beat %% 4 == 0) debugPrint("beat " + beat);
}
'''

MODCHART = '''// Modchart de exemplo: balanço contínuo nas setas e giro a cada 16 batidas.
// Alvo: 0-7, "player", "opponent", "all". Propriedades: x, y, angle, alpha, size, waveX, waveY, waveSpeed.
// Apague o "//" das linhas para ativar.

function onSongStart() {
    // setStrum("all", {waveX: 20, waveSpeed: 0.4});
}

function onBeatHit(beat) {
    // if (beat %% 16 == 0) tweenStrum("giro", "player", {angle: 360}, 1, "quadOut", 0.1);
}
'''

MENU = '''// Script de menu: roda em todas as telas (scripts/menus/all.hx). Para uma tela só, use <tela>.hx
// (title, mainmenu, story, freeplay, options, mods, controls).
// Callbacks: onCreate, onCreatePost, onUpdate(elapsed), onSelect(id) -> true cancela o padrão, onDestroy.

function onCreate() {
    // var t = makeText(10, 10, 400, "Meu mod ativo", 20);
    // add(t);
}
'''

TELA = '''// Tela inteira feita por script. Abra com go("mod:minhatela") ou com um item {"state":"mod:minhatela"} no mainmenu.json.
// ESC volta ao menu principal (onBack devolvendo true cancela).

function onCreate() {
    add(makeSprite().makeGraphic(FlxG.width, FlxG.height, color("#202030")));
    var titulo = makeText(0, 60, FlxG.width, "Minha tela", 48);
    titulo.alignment = "center";
    add(titulo);
    button(FlxG.width / 2 - 120, 200, 240, 56, "Voltar", function() { go("mainmenu"); });
}
'''

MAINMENU = {"items": [
    {"id": "story", "anim": "story mode", "state": "story"},
    {"id": "freeplay", "anim": "freeplay", "state": "freeplay"},
    {"id": "minhatela", "label": "Minha tela", "state": "mod:minhatela"},
    {"id": "options", "anim": "options", "state": "options"}]}

STAGE = {"name": "meustage", "defaultZoom": 0.9, "objects": []}


def put(path, text):
    if os.path.exists(path):
        print("  (mantido)", os.path.relpath(path, ROOT))
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("  criado  ", os.path.relpath(path, ROOT))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("nome")
    ap.add_argument("--com", nargs="*", default=["script"])
    ap.add_argument("--autor", default="")
    ap.add_argument("--descricao", default="Mod criado com tools/new_mod.py")
    a = ap.parse_args()

    slug = re.sub(r"[^a-z0-9_-]+", "-", a.nome.lower()).strip("-")
    if not slug:
        sys.exit("nome inválido")
    base = os.path.join(ROOT, slug)
    wants = set(a.com)
    if "tudo" in wants:
        wants = {"script", "modchart", "menu", "tela", "musica", "stage", "personagem"}
    print("Mod:", slug)
    put(os.path.join(base, "pack.json"), json.dumps(
        {"name": a.nome, "description": a.descricao, "author": a.autor, "version": "1.0", "color": "#6C8CFF"},
        ensure_ascii=False, indent=2) + "\n")
    if "script" in wants:
        put(os.path.join(base, "scripts", "main.hx"), SCRIPT % {"nome": a.nome})
    if "modchart" in wants:
        put(os.path.join(base, "scripts", "modchart.hx"), MODCHART)
    if "menu" in wants:
        put(os.path.join(base, "scripts", "menus", "all.hx"), MENU)
        put(os.path.join(base, "data", "menus", "mainmenu.json"), json.dumps(MAINMENU, ensure_ascii=False, indent=2) + "\n")
    if "tela" in wants:
        put(os.path.join(base, "states", "minhatela.hx"), TELA)
    if "stage" in wants:
        put(os.path.join(base, "data", "stages", "meustage.json"), json.dumps(STAGE, indent=2) + "\n")
        put(os.path.join(base, "data", "stages", "meustage.hx"), "// Efeitos do cenário (mesmos callbacks dos scripts de música)\nfunction onCreate() {\n}\n")
    if "personagem" in wants:
        put(os.path.join(base, "data", "characters", "meuchar.hx"), "// Script do personagem 'meuchar' (o .json do personagem vem do Character Editor)\nfunction onCreate() {\n}\n")
    if "musica" in wants:
        put(os.path.join(base, "data", "songs.json"), json.dumps(
            {"songs": [{"id": "minha-musica", "name": "Minha Música", "week": 0}]}, ensure_ascii=False, indent=2) + "\n")
        put(os.path.join(base, "data", "songs", "minha-musica", "minha-musica.hx"), "// Script só desta música\nfunction onCreate() {\n}\n")
        print("  dica: ponha o chart (.ffc ou .json) e songs/minha-musica/Inst.ogg + Voices.ogg, ou use tools/add_song.py")
    print("Pronto. Ative em F5 (Mods) no menu do jogo.")


main()
