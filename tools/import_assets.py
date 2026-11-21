#!/usr/bin/env python3
"""
Importa os assets do FNF / Kade Engine (os zips que você baixou) para o formato do FunkForge.

Uso:
    python tools/import_assets.py --src PASTA_COM_OS_ZIPS --out assets

O que faz:
  * copia áudio (.ogg), atlas (.png/.xml/.txt), fontes, ícones e noteskins para assets/
    (ignora .mp3, .fla, .bmp, .webm, que o jogo não usa);
  * converte os charts legados (data/songs/*) para o formato "funkforge-2" (carrega mais rápido);
  * gera data/characters/*.json lendo o switch de personagens do source/Character.hx da Kade
    + os arquivos *Offsets.txt + data/characters/gf.json;
  * gera data/songs.json (lista do freeplay).

Só usa a biblioteca padrão do Python 3.8+. É seguro rodar de novo: sobrescreve a saída.
"""
import argparse
import io
import json
import os
import re
import sys
import zipfile
from collections import OrderedDict

SKIP_EXT = {".mp3", ".fla", ".bmp", ".webm", ".zip", ".md", ".yml", ".html"}

# Offsets do bf que NÃO vieram nos zips (bfOffsets.txt e variantes). Valores do FNF original.
BF_OFFSETS = OrderedDict([
    ("idle", (-5, 0)), ("singUP", (-29, 27)), ("singRIGHT", (-38, -7)), ("singLEFT", (12, -6)),
    ("singDOWN", (-10, -50)), ("singUPmiss", (-29, 27)), ("singRIGHTmiss", (-30, 21)),
    ("singLEFTmiss", (12, 24)), ("singDOWNmiss", (-11, -19)), ("hey", (7, 4)),
    ("firstDeath", (37, 11)), ("deathLoop", (37, 5)), ("deathConfirm", (37, 69)), ("scared", (-4, 0)),
])
FALLBACK_OFFSETS = {
    "bf": BF_OFFSETS, "bf-christmas": BF_OFFSETS, "bf-car": BF_OFFSETS,
    "bf-pixel-dead": {"firstDeath": (0, 0), "deathLoop": (-37, 0), "deathConfirm": (-37, 0)},
}

# Posição da câmera por personagem (Kade/FNF original): [dx, dy] somado ao ponto médio.
CAM_OFFSETS = {"mom": [150, 0], "mom-car": [150, 0], "senpai": [-100, -430], "senpai-angry": [-100, -430]}


def zkind(path):
    """'75899a7b-characters-1.zip' -> 'characters-1'"""
    stem = os.path.splitext(os.path.basename(path))[0]
    return re.sub(r"^[0-9a-f]{8}-", "", stem)


class Source:
    def __init__(self, folder):
        self.members = []  # (zip_kind, name, ZipFile)
        self.zips = []
        for f in sorted(os.listdir(folder)):
            if f.lower().endswith(".zip"):
                z = zipfile.ZipFile(os.path.join(folder, f))
                self.zips.append(z)
                kind = zkind(f)
                for n in z.namelist():
                    if not n.endswith("/"):
                        self.members.append((kind, n.replace("\\", "/"), z))

    def read(self, z, name):
        return z.read(name)

    def find(self, suffix):
        for kind, n, z in self.members:
            if n.endswith(suffix):
                return z.read(n)
        return None


def route(kind, name):
    """Decide onde cada arquivo do zip vai dentro de assets/. Devolve None para ignorar."""
    parts = name.split("/")
    base = parts[-1]
    ext = os.path.splitext(base)[1].lower()
    if ext in SKIP_EXT or base.endswith("-go-here.txt") or base.endswith("_stuff_here.txt") or base.endswith("-here.txt"):
        return None
    # áudio de música: <id>/Inst.ogg, <id>/Voices.ogg
    if ext == ".ogg" and base in ("Inst.ogg", "Voices.ogg") and len(parts) == 2:
        return "songs/%s/%s" % (parts[0], base)
    top = parts[0]
    if top in ("music", "sounds") and ext == ".ogg":
        return name
    if top == "fonts" and ext in (".ttf", ".otf"):
        return name
    if top in ("icons", "storymenu", "noteskins") and ext in (".png", ".xml"):
        return "images/" + name
    m = re.match(r"week\d+$", top)
    if m and len(parts) > 2:
        sub, rest = parts[1], "/".join(parts[2:])
        if sub == "images":
            if rest.startswith("weeb/pixelUI/"):
                return "images/pixelUI/" + rest[len("weeb/pixelUI/"):]
            return "images/stages/" + rest
        if sub in ("music", "sounds") and ext == ".ogg":
            return sub + "/" + rest
        return None
    # arquivos soltos na raiz do zip
    if len(parts) == 1:
        if kind.startswith("characters") and ext in (".png", ".xml", ".txt") and not base.endswith("Offsets.txt"):
            return "images/characters/" + base
        if kind.startswith("images") and ext in (".png", ".xml"):
            stem = os.path.splitext(base)[0]
            if stem in ("stageback", "stagefront", "stagecurtains", "stage_light"):
                return "images/stages/stage/" + base
            return "images/" + base
    return None


def write(out, rel, data):
    path = os.path.join(out, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def extract_json(text):
    """Primeiro objeto {...} balanceado (alguns charts, como ridge.json, têm lixo depois)."""
    if text.startswith("﻿"):
        text = text[1:]
    start = text.find("{")
    if start < 0:
        return text
    depth, in_str, esc = 0, False, False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return text[start:]


# --------------------------------------------------------------------------- charts


def stage_for_week(week, sid):
    return {2: "halloween", 3: "philly", 4: "limo"}.get(
        week, ("mallEvil" if sid == "winter-horrorland" else "mall") if week == 5
        else (("schoolEvil" if sid == "thorns" else "school") if week == 6 else "stage"))


def gf_for_week(week):
    return {4: "gf-car", 5: "gf-christmas", 6: "gf-pixel"}.get(week, "gf")


def convert_chart(sid, text, week):
    j = json.loads(extract_json(text))
    s = j["song"] if isinstance(j.get("song"), dict) else j
    bpm = float(s.get("bpm", 100))
    cur = bpm
    t = 0.0
    beat = 0.0
    changes = [{"time": 0, "beat": 0, "bpm": cur}]
    sections, notes = [], []
    raw_count = 0
    for i, sec in enumerate(s.get("notes", [])):
        sb = sec.get("bpm")
        if sec.get("changeBPM") and sb and float(sb) > 0 and float(sb) != cur:
            cur = float(sb)
            changes.append({"time": t, "beat": beat, "bpm": cur})
        steps = int(sec.get("lengthInSteps", 16) or 16)
        must = bool(sec.get("mustHitSection", False))
        alt = bool(sec.get("altAnim", False))
        sections.append({"start": t, "beat": beat, "steps": steps, "mustHit": must, "alt": alt})
        for n in sec.get("sectionNotes", []):
            raw = int(n[1])
            if raw < 0:
                continue
            raw_count += 1
            player = (not must) if raw > 3 else must
            sus = float(n[2]) if len(n) > 2 and not isinstance(n[2], bool) else 0.0
            typ = n[3] if len(n) > 3 and isinstance(n[3], str) else ""
            notes.append([n[0], raw % 4, 1 if player else 0, sus if sus > 0 else 0, typ, i, 1 if (alt and not player) else 0])
        t += steps * (60000.0 / cur / 4)
        beat += steps / 4.0
    notes.sort(key=lambda x: x[0])
    # remove duplicadas (mesmo tempo, lane e lado), igual ao ChartLoader.finish
    out = []
    dups = 0
    for n in notes:
        dup = False
        k = len(out) - 1
        while k >= 0 and n[0] - out[k][0] < 1:
            if out[k][1] == n[1] and out[k][2] == n[2]:
                dup = True
                break
            k -= 1
        if dup:
            dups += 1
        else:
            out.append(n)
    chart = OrderedDict([
        ("format", "funkforge-2"), ("id", sid),
        ("name", s.get("song") if isinstance(s.get("song"), str) else sid),
        ("bpm", bpm), ("speed", s.get("speed", 1)),
        ("needsVoices", s.get("needsVoices", True) is not False),
        ("player1", s.get("player1", "bf")), ("player2", s.get("player2", "dad")),
        ("gf", s.get("gfVersion") or gf_for_week(week)),
        ("stage", s.get("stage") or stage_for_week(week, sid)),
        ("noteStyle", s.get("noteStyle") or ("pixel" if week == 6 else "normal")),
        ("bpmChanges", changes), ("sections", sections), ("notes", out), ("events", []),
    ])
    return chart, raw_count, dups


# --------------------------------------------------------------------------- personagens


def parse_character_cases(src):
    """Quebra o switch de personagens do Character.hx em {id: texto_do_bloco}."""
    start = src.index("switch (curCharacter)")
    end = src.index("default:", start)
    body = src[start:end]
    cases = OrderedDict()
    for m in re.finditer(r"case '([^']+)':(.*?)(?=\n\t\t\tcase '|\Z)", body, re.S):
        cases[m.group(1)] = m.group(2)
    return cases


def parse_offsets(text):
    res = OrderedDict()
    for line in text.splitlines():
        p = line.strip().split(" ")
        if len(p) >= 2 and p[0]:
            try:
                res[p[0]] = (int(p[1]), int(p[2]) if len(p) > 2 else 0)
            except ValueError:
                pass
    return res


def find_icon(cid, icons):
    cands = [cid]
    if cid == "parents-christmas":
        cands.append("parents")
    while "-" in cands[-1]:
        cands.append(cands[-1].rsplit("-", 1)[0])
    for c in cands:
        if c in icons:
            return c
    return "face"


def convert_character(cid, block, index, offsets_text, icons):
    flat = re.sub(r"\s+", " ", block)
    atlas = re.search(r"getSparrowAtlas\('([^']+)'", flat)
    packer = False
    if not atlas:
        atlas = re.search(r"getPackerAtlas\('([^']+)'", flat)
        packer = atlas is not None
    if not atlas:
        return None, "sem atlas"
    base = os.path.basename(atlas.group(1)).lower()
    asset = index.get((base, ".txt" if packer else ".xml")) or index.get((base, ".png"))
    asset_rel = None
    if asset:
        asset_rel = os.path.splitext(asset)[0]
        if asset_rel.startswith("images/"):
            asset_rel = asset_rel[len("images/"):]
    else:
        asset_rel = "characters/" + os.path.basename(atlas.group(1))

    offs = OrderedDict()
    if offsets_text is not None:
        offs = parse_offsets(offsets_text)
    elif cid in FALLBACK_OFFSETS:
        offs = OrderedDict(FALLBACK_OFFSETS[cid])

    anims = []
    seen = set()

    def push(name, prefix, fps, loop, indices):
        a = OrderedDict([("name", name), ("prefix", prefix), ("fps", fps), ("loop", loop)])
        if indices is not None:
            a["indices"] = indices
        o = offs.get(name)
        a["offsets"] = [o[0], o[1]] if o else [0, 0]
        if name in seen:
            anims[:] = [x for x in anims if x["name"] != name]
        seen.add(name)
        anims.append(a)

    # addByIndices('nome', 'prefixo', [i, ...], "", fps, loop)
    for m in re.finditer(r"animation\.addByIndices\('([^']+)',\s*['\"]([^'\"]*)['\"],\s*\[([^\]]*)\],\s*\"[^\"]*\"(?:,\s*(\d+))?(?:,\s*(true|false))?", flat):
        idx = [int(x) for x in m.group(3).split(",") if x.strip()]
        push(m.group(1), m.group(2), int(m.group(4) or 24), (m.group(5) != "false"), idx)
    # addByPrefix('nome', 'prefixo', fps, loop)
    for m in re.finditer(r"animation\.addByPrefix\('([^']+)',\s*['\"]([^'\"]*)['\"](?:,\s*(\d+))?(?:,\s*(true|false))?", flat):
        push(m.group(1), m.group(2), int(m.group(3) or 24), (m.group(4) != "false"), None)

    # preserva a ordem original do código
    order = {}
    for m in re.finditer(r"animation\.addBy(?:Indices|Prefix)\('([^']+)'", flat):
        order.setdefault(m.group(1), len(order))
    anims.sort(key=lambda a: order.get(a["name"], 999))

    col = re.search(r"barColor = 0x([0-9a-fA-F]{8})", flat)
    if col:
        bar = "#" + col.group(1)[2:].upper()
    else:
        bar = "#66FF33" if cid.startswith("bf") else "#FF0000"

    names = {a["name"] for a in anims}
    lr = "danceLeft" in names and "danceRight" in names
    d = OrderedDict([("name", cid), ("asset", asset_rel)])
    if packer:
        d["packer"] = True
    d["barColor"] = bar
    d["icon"] = find_icon(cid, icons)
    if re.search(r"\bflipX = true", flat):
        d["flipX"] = True
    if not cid.startswith("bf"):
        d["swapSides"] = True
    else:
        d["swapSides"] = False
    if re.search(r"setGraphicSize\(Std\.int\(width \* (?:CoolUtil\.daPixelZoom|6)\)\)", flat):
        d["scale"] = 6
    if re.search(r"antialiasing = false", flat):
        d["antialiasing"] = False
    d["singDuration"] = 4
    d["danceEvery"] = 1 if lr else 2
    if lr:
        d["danceLR"] = True
    if cid in CAM_OFFSETS:
        d["camOffset"] = CAM_OFFSETS[cid]
    d["animations"] = anims
    return d, None


def convert_gf(gf_json, offs_unused=None):
    j = json.loads(gf_json)
    anims = []
    for a in j["animations"]:
        o = OrderedDict([("name", a["name"]), ("prefix", a["prefix"]), ("fps", a.get("frameRate", 24)), ("loop", bool(a.get("looped", False)))])
        if a.get("frameIndices"):
            o["indices"] = a["frameIndices"]
        o["offsets"] = a.get("offsets", [0, 0])
        anims.append(o)
    return OrderedDict([("name", "gf"), ("asset", j["asset"]), ("barColor", j.get("barColor", "#A5004D")), ("icon", "gf"),
                        ("swapSides", True), ("singDuration", 4), ("danceEvery", 1), ("danceLR", True), ("animations", anims)])


# --------------------------------------------------------------------------- principal


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, help="pasta com os .zip")
    ap.add_argument("--out", default="assets", help="pasta de saída (padrão: assets)")
    a = ap.parse_args()

    src = Source(a.src)
    if not src.members:
        sys.exit("Nenhum .zip encontrado em " + a.src)
    out = a.out
    report = {"copied": 0, "skipped": 0, "charts": 0, "chart_problems": [], "chars": [], "char_problems": [], "missing_atlas": []}

    # 1) copia arquivos
    index = {}  # (nome_sem_ext_minúsculo, ext) -> caminho relativo
    for kind, name, z in src.members:
        dest = route(kind, name)
        if dest is None:
            report["skipped"] += 1
            continue
        write(out, dest, z.read(name))
        report["copied"] += 1
        stem, ext = os.path.splitext(os.path.basename(dest))
        index[(stem.lower(), ext.lower())] = dest

    # 2) charts
    freeplay = src.find("freeplaySonglist.txt")
    weeks, order = {}, []
    if freeplay:
        for line in freeplay.decode("utf-8", "replace").splitlines():
            p = line.strip().split(":")
            if len(p) >= 3:
                weeks[p[0]] = int(p[2])
                order.append(p[0])

    for kind, name, z in src.members:
        m = re.match(r"data/songs/([^/]+)/([^/]+)$", name)
        if not m:
            continue
        sid, fn = m.groups()
        if fn == "_meta.json":
            write(out, "data/songs/%s/_meta.json" % sid, z.read(name))
        elif fn.endswith(".json"):
            text = z.read(name).decode("utf-8-sig", "replace")
            try:
                chart, raw, dups = convert_chart(sid, text, weeks.get(sid, 0))
            except Exception as e:  # noqa
                report["chart_problems"].append("%s/%s: %s" % (sid, fn, e))
                continue
            if len(chart["notes"]) + dups != raw:
                report["chart_problems"].append("%s/%s: notas %d != %d" % (sid, fn, len(chart["notes"]) + dups, raw))
            write(out, "data/songs/%s/%s" % (sid, fn), json.dumps(chart, separators=(",", ":")).encode("utf-8"))
            report["charts"] += 1
        elif fn.endswith(".lua"):
            # modcharts antigos da Kade usam outra API: guardados com extensão .kade para não rodarem sozinhos
            write(out, "data/songs/%s/%s.kade" % (sid, fn), z.read(name))

    # 3) personagens
    char_src = src.find("source/Character.hx")
    icons = {os.path.splitext(os.path.basename(p))[0][5:] for (s, e), p in index.items() if False}
    icons = {k[0][5:] for k in index if k[0].startswith("icon-") and k[1] == ".png"}
    if char_src:
        cases = parse_character_cases(char_src.decode("utf-8", "replace"))
        offsets = {}
        for kind, name, z in src.members:
            if name.endswith("Offsets.txt") and "/" not in name:
                offsets[name[:-len("Offsets.txt")]] = z.read(name).decode("utf-8", "replace")
        for cid, block in cases.items():
            d, err = convert_character(cid, block, index, offsets.get(cid), icons)
            if d is None:
                report["char_problems"].append("%s: %s" % (cid, err))
                continue
            if cid not in offsets and cid not in FALLBACK_OFFSETS:
                report["char_problems"].append("%s: sem arquivo de offsets (animações ficam em 0,0)" % cid)
            elif cid not in offsets:
                report["char_problems"].append("%s: offsets reconstruídos do FNF original (não vieram nos zips)" % cid)
            if not os.path.exists(os.path.join(out, "images", d["asset"] + (".txt" if d.get("packer") else ".xml"))):
                report["missing_atlas"].append("%s -> images/%s" % (cid, d["asset"]))
            write(out, "data/characters/%s.json" % cid, json.dumps(d, indent=1).encode("utf-8"))
            report["chars"].append(cid)
    gf = src.find("data/characters/gf.json")
    if gf:
        d = convert_gf(gf.decode("utf-8-sig"))
        write(out, "data/characters/gf.json", json.dumps(d, indent=1).encode("utf-8"))
        report["chars"].append("gf")

    # 4) lista de músicas
    songs = [{"id": sid, "name": sid.replace("-", " ").title(), "week": weeks.get(sid, 0)} for sid in order]
    write(out, "data/songs.json", json.dumps({"songs": songs}, indent=1).encode("utf-8"))

    print(json.dumps(report, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
