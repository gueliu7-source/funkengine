#!/usr/bin/env python3
"""Adiciona uma música ao Freeplay de um mod do FunkForge.

Uso:
  python3 tools/add_song.py <pasta-ou-zip-da-musica> --mod meu-mod [--id id] [--name "Nome"] [--week 0]
  python3 tools/add_song.py --mod meu-mod --id minha-musica --name "Minha Música" \
      --chart chart.json [--easy easy.json] [--hard hard.json] --inst Inst.ogg [--voices Voices.ogg] \
      [--voices-player Vp.ogg --voices-opponent Vo.ogg]

A pasta/zip pode ter o formato do Psych/Kade/FNF: charts .json (nomes terminando em -easy/-hard viram as
dificuldades) e os áudios Inst*.ogg/Voices*.ogg. O script:
  - cria mods/<mod>/ (com pack.json) se ainda não existir
  - copia os charts para data/songs/<id>/<id>[-easy|-hard].json
  - copia/converte os áudios para songs/<id>/ (mp3/wav/flac viram .ogg se o ffmpeg existir)
  - registra a música em data/songs.json do mod (Freeplay)
Depois é só ativar o mod em F5 (ou Opções > Mods) e abrir o Freeplay.
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, tempfile, zipfile

AUDIO = (".ogg", ".mp3", ".wav", ".flac")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def slug(s):
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s or "musica"


def to_ogg(src, dst_dir):
    """Copia o áudio; se não for .ogg, converte com o ffmpeg."""
    base = os.path.basename(src)
    name, ext = os.path.splitext(base)
    if ext.lower() == ".ogg":
        shutil.copyfile(src, os.path.join(dst_dir, base))
        return base
    if not shutil.which("ffmpeg"):
        sys.exit(f"'{base}' não é .ogg e o ffmpeg não está instalado: converta para .ogg e rode de novo.")
    out = os.path.join(dst_dir, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    return name + ".ogg"


def chart_ok(path):
    try:
        with open(path, encoding="utf-8-sig") as f:
            j = json.load(f)
    except Exception as e:
        sys.exit(f"chart inválido ({path}): {e}")
    # formatos aceitos pelo jogo: legado {"song":{notes:[..]}} / psych {"notes":[..]} / funkforge-2
    if not isinstance(j, dict):
        sys.exit(f"chart inválido ({path}): raiz não é objeto")
    return j


def scan(folder):
    """Procura charts e áudios dentro de uma pasta já extraída."""
    charts, audios = {}, {}
    for p in sorted(glob.glob(os.path.join(folder, "**", "*"), recursive=True)):
        if not os.path.isfile(p):
            continue
        low = os.path.basename(p).lower()
        stem, ext = os.path.splitext(low)
        if ext == ".json":
            if stem in ("events", "meta", "metadata", "pack", "songs") or "events" in stem:
                continue
            diff = "-hard" if stem.endswith("-hard") else "-easy" if stem.endswith("-easy") else ""
            if diff not in charts:  # o primeiro de cada dificuldade vence
                charts[diff] = p
        elif ext in AUDIO:
            audios[low] = p
    return charts, audios


def main():
    ap = argparse.ArgumentParser(description="Adiciona uma música ao Freeplay de um mod.")
    ap.add_argument("source", nargs="?", help="pasta ou .zip com chart(s) e áudio")
    ap.add_argument("--mod", required=True, help="nome da pasta em mods/")
    ap.add_argument("--id")
    ap.add_argument("--name")
    ap.add_argument("--week", type=int, default=0)
    ap.add_argument("--chart"), ap.add_argument("--easy"), ap.add_argument("--hard")
    ap.add_argument("--inst"), ap.add_argument("--voices")
    ap.add_argument("--voices-player"), ap.add_argument("--voices-opponent")
    ap.add_argument("--repo", default=ROOT, help="raiz do projeto (padrão: a deste script)")
    a = ap.parse_args()

    tmp = None
    charts, audios = {}, {}
    if a.source:
        src = a.source
        if zipfile.is_zipfile(src):
            tmp = tempfile.mkdtemp(prefix="addsong-")
            with zipfile.ZipFile(src) as z:
                for m in z.namelist():  # sem sair da pasta temporária
                    if os.path.isabs(m) or ".." in m.replace("\\", "/").split("/"):
                        sys.exit("zip com caminho suspeito: " + m)
                z.extractall(tmp)
            src = tmp
        if not os.path.isdir(src):
            sys.exit("origem não encontrada: " + a.source)
        charts, audios = scan(src)
    for key, f in (("", a.chart), ("-easy", a.easy), ("-hard", a.hard)):
        if f:
            charts[key] = f
    if not charts:
        sys.exit("nenhum chart (.json) encontrado: use a pasta/zip ou --chart")

    # áudios: (arquivo de origem, papel)
    pick = []
    def find(*names):
        for n in names:
            if n in audios:
                return audios[n]
        for k, v in audios.items():
            if any(k.startswith(os.path.splitext(n)[0]) for n in names):
                return v
        return None
    inst = a.inst or find("inst.ogg", "inst.mp3", "inst.wav", "inst.flac")
    voices = a.voices or find("voices.ogg", "voices.mp3", "voices.wav", "voices.flac")
    vp = a.voices_player or audios.get("voices-player.ogg")
    vo = a.voices_opponent or audios.get("voices-opponent.ogg")
    if not inst:
        sys.exit("não achei o Inst (instrumental): use --inst ou um arquivo Inst.ogg na pasta")
    pick = [("Inst", inst)] + [(r, f) for r, f in (("Voices", voices), ("Voices-Player", vp), ("Voices-Opponent", vo)) if f]

    sid = slug(a.id or os.path.splitext(os.path.basename(charts.get("", next(iter(charts.values())))))[0].replace("-hard", "").replace("-easy", ""))
    name = a.name or sid.replace("-", " ").title()

    mod = os.path.join(a.repo, "mods", a.mod)
    os.makedirs(os.path.join(mod, "data", "songs", sid), exist_ok=True)
    os.makedirs(os.path.join(mod, "songs", sid), exist_ok=True)
    pack = os.path.join(mod, "pack.json")
    if not os.path.exists(pack):
        with open(pack, "w", encoding="utf-8") as f:
            json.dump({"name": a.mod, "description": "", "author": "", "version": "1.0", "color": "#FF66AA"}, f, indent=2, ensure_ascii=False)

    for diff, f in charts.items():
        chart_ok(f)
        shutil.copyfile(f, os.path.join(mod, "data", "songs", sid, f"{sid}{diff}.json"))
    for role, f in pick:
        out = to_ogg(f, os.path.join(mod, "songs", sid))
        want = role + ".ogg"
        if out != want:  # nomes padronizados: Inst.ogg, Voices.ogg...
            os.replace(os.path.join(mod, "songs", sid, out), os.path.join(mod, "songs", sid, want))

    sj = os.path.join(mod, "data", "songs.json")
    data = {"songs": []}
    if os.path.exists(sj):
        with open(sj, encoding="utf-8-sig") as f:
            data = json.load(f)
    data["songs"] = [s for s in data.get("songs", []) if s.get("id") != sid] + [{"id": sid, "name": name, "week": a.week}]
    with open(sj, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    if tmp:
        shutil.rmtree(tmp, ignore_errors=True)
    diffs = ", ".join({"": "Normal", "-easy": "Easy", "-hard": "Hard"}[d] for d in charts)
    print(f"OK: '{name}' ({sid}) adicionada em mods/{a.mod}/ — dificuldades: {diffs}; áudios: {', '.join(r for r, _ in pick)}")


if __name__ == "__main__":
    main()
