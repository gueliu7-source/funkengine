#!/usr/bin/env python3
"""
Monta mods/myths-of-tubbyland/ (port do mod "Myths of Tubbyland / Slendytubbies", feito para Psych Engine)
a partir das pastas extraídas dos zips originais.  Uso:

    python3 tools/port_psych_mod.py <pasta com os zips extraídos> <pasta do repositório>

A pasta de entrada deve ter as subpastas com os nomes dos zips (ver POOLS).
"""
import glob, json, os, re, shutil, sys, collections

SRC = sys.argv[1]
REPO = sys.argv[2]
MOD = os.path.join(REPO, "mods", "myths-of-tubbyland")

ASSETS = os.path.join(SRC, "49afd4cd-Assets_-_Myths_of_Tubbyland_Fan_Made")
# (pasta de origem, destino dentro de images/)
IMAGE_POOLS = [
    ("7e69373b-images-p1", ""),
    ("e11d5c5d-images-p2", ""),
    ("84ea37d7-dome", ""),  # o zip já tem a pasta dome/
    ("4c741460-characters", "characters"),
    ("ca07108a-characters-p2", "characters"),
    ("e6a5907d-thelionsmouth/thelionsmouth", "characters/thelionsmouth"),
    ("c8dfd234-morningpatrol", "characters/morningpatrol"),
    ("5e1554ac-morningpatrol-p1/morningpatrol-p1", "characters/morningpatrol"),
]
SKIP = {"readme.txt"}
NICE = {"the-lions-mouth": "The Lion's Mouth", "morning-patrol": "Morning Patrol", "nocturnal-protocol": "Nocturnal Protocol"}


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def main():
    if os.path.exists(MOD):
        shutil.rmtree(MOD)
    os.makedirs(MOD)

    refs = set()
    for jf in glob.glob(os.path.join(ASSETS, "characters", "*.json")):
        d = json.load(open(jf, encoding="utf8"))
        if "image" in d:
            refs.add(d["image"])
    for lf in glob.glob(os.path.join(ASSETS, "**", "*.lua"), recursive=True):
        s = open(lf, encoding="utf8", errors="ignore").read()
        for m in re.finditer(r"""make(?:Animated)?LuaSprite\(\s*['"][^'"]*['"]\s*,\s*['"]([^'"]+)['"]""", s):
            refs.add(m.group(1))
    refs_l = {r.lower() for r in refs}

    # ---------------------------------------------------------------- imagens
    placed = {}  # caminho (minúsculo) -> caminho real dentro de images/
    sources = collections.defaultdict(list)  # nome base minúsculo -> [arquivos]
    for pool, dest in IMAGE_POOLS:
        base = os.path.join(SRC, pool)
        for root, _, files in os.walk(base):
            for f in files:
                if f.lower() in SKIP or not f.lower().endswith((".png", ".xml", ".txt")):
                    continue
                full = os.path.join(root, f)
                rel = os.path.relpath(full, base).replace("\\", "/")
                target = (dest + "/" + rel).lstrip("/")
                sources[f.lower()].append(full)
                # pastas de personagens se sobrepõem entre os zips: só entra o que algum personagem/script usa
                if dest.startswith("characters") and os.path.splitext(target)[0].lower() not in refs_l:
                    continue
                copy(full, os.path.join(MOD, "images", target))
                placed[target.lower()] = target

    # caminhos de imagem referenciados por personagens e scripts que ainda faltam: busca pelo nome do arquivo
    missing = []
    for r in sorted(refs):
        for ext in (".png",):
            key = (r + ext).lower()
            if key in placed:
                continue
            base = os.path.basename(r).lower() + ext
            cands = sources.get(base)
            if cands:
                copy(cands[0], os.path.join(MOD, "images", r + ext))
                xml = cands[0][:-4] + ".xml"
                if os.path.exists(xml):
                    copy(xml, os.path.join(MOD, "images", r + ".xml"))
                placed[key] = r + ext
            else:
                missing.append(r)
    print("imagens sem arquivo de origem:", missing)

    # ---------------------------------------------------------------- personagens e stages
    for jf in glob.glob(os.path.join(ASSETS, "characters", "*.json")):
        copy(jf, os.path.join(MOD, "data", "characters", os.path.basename(jf)))
    for jf in glob.glob(os.path.join(ASSETS, "stages", "*.json")):
        copy(jf, os.path.join(MOD, "data", "stages", os.path.basename(jf)))

    # ---------------------------------------------------------------- músicas
    songs_dir = os.path.join(SRC, "82cb9663-songs")
    for sid in os.listdir(songs_dir):
        for f in os.listdir(os.path.join(songs_dir, sid)):
            copy(os.path.join(songs_dir, sid, f), os.path.join(MOD, "songs", sid, f))
        for jf in glob.glob(os.path.join(ASSETS, "data", sid, "*.json")):
            copy(jf, os.path.join(MOD, "data", "songs", sid, os.path.basename(jf)))

    # ---------------------------------------------------------------- áudio, fontes
    for sub in ("music", "sounds", "fonts"):
        for f in glob.glob(os.path.join(ASSETS, sub, "*")):
            if os.path.basename(f).lower() not in SKIP:
                copy(f, os.path.join(MOD, sub, os.path.basename(f)))

    # ---------------------------------------------------------------- Lua do Psych (rodam pela camada PsychLua)
    open(os.path.join(MOD, "psych.txt"), "w").write("scripts desta pasta usam a API Lua do Psych\n")
    for sub in ("custom_events", "custom_notetypes", "scripts"):
        for f in glob.glob(os.path.join(ASSETS, sub, "*")):
            if os.path.basename(f).lower() in SKIP:
                continue
            dest = os.path.join(MOD, sub, os.path.basename(f))
            if f.endswith(".hx"):
                dest = os.path.join(MOD, "psych_lua", sub, os.path.basename(f))  # HScript do Psych: ainda não suportado
            copy(f, dest)
    for f in glob.glob(os.path.join(ASSETS, "stages", "*.lua")):
        copy(f, os.path.join(MOD, "data", "stages", os.path.basename(f)))
    for f in glob.glob(os.path.join(ASSETS, "data", "*", "*.lua")):
        sid = os.path.basename(os.path.dirname(f))
        if os.path.basename(f).startswith("PauseMenu"):  # menus de pausa customizados: fase 3
            copy(f, os.path.join(MOD, "psych_lua", "fase3", sid, os.path.basename(f)))
        else:
            copy(f, os.path.join(MOD, "data", "songs", sid, os.path.basename(f)))

    # ---------------------------------------------------------------- pack.json e lista de músicas
    p = json.load(open(os.path.join(ASSETS, "pack.json"), encoding="utf8"))
    col = p.get("color", [143, 36, 179])
    pack = {
        "name": "Myths of Tubbyland (Slendytubbies)",
        "description": p.get("description", ""),
        "author": "Port do mod de Psych Engine",
        "version": "1.0",
        "color": "#%02X%02X%02X" % tuple(col),
    }
    json.dump(pack, open(os.path.join(MOD, "pack.json"), "w", encoding="utf8"), indent=2, ensure_ascii=False)
    if os.path.exists(os.path.join(ASSETS, "pack.png")):
        copy(os.path.join(ASSETS, "pack.png"), os.path.join(MOD, "pack.png"))

    names = {}
    for wf in glob.glob(os.path.join(ASSETS, "weeks", "*.json")):
        w = json.load(open(wf, encoding="utf8"))
        for s in w.get("songs", []):
            names[re.sub(r"[^a-z0-9]+", "-", s[0].lower()).strip("-")] = s[0]
    out = []
    for sid in sorted(os.listdir(songs_dir)):
        out.append({"id": sid, "name": NICE.get(sid) or names.get(sid, sid.replace("-", " ").title()), "week": 0})
    json.dump({"songs": out}, open(os.path.join(MOD, "data", "songs.json"), "w", encoding="utf8"), indent=2, ensure_ascii=False)
    print("songs:", out)


main()
