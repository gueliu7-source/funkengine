#!/usr/bin/env python3
"""Gera docs/API.md lendo o código: funções dos scripts (ScriptApi.hx), dos menus (MenuScripts.hx),
callbacks (ScriptManager.hx) e eventos (assets/data/events/*.json). Rode depois de mudar a API:
  python3 tools/gen_api_docs.py
"""
import glob, json, os, re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def rd(p):
    with open(os.path.join(SRC, p), encoding="utf-8") as f:
        return f.read()

def funcs(text, var):
    """Acha  <var>.set("nome", function(args):Ret ...  e devolve (comentário anterior, nome, assinatura)."""
    out = []
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        m = re.search(r'\b' + var + r'\.set\("(\w+)",\s*function\(([^)]*)\)(?:\s*:\s*([\w<>]+))?', ln)
        if not m or m.group(1).startswith("__"):
            continue
        doc = []
        sec = ""
        j = i - 1
        while j >= 0 and lines[j].strip().startswith("//"):
            c = lines[j].strip()[2:].strip()
            h = re.match(r"^-{3,}\s*(.*)$", c)
            if h:
                sec = h.group(1).strip()
            else:
                doc.insert(0, c)
            j -= 1
        args = ", ".join(re.sub(r':[^,]+', '', a.strip()).replace("?", "") + ("?" if a.strip().startswith("?") else "")
                         for a in m.group(2).split(",") if a.strip())
        out.append((" ".join(doc), m.group(1), args, (m.group(3) or "").strip(), sec))
    return out

def table(rows):
    s = ""
    for doc, name, args, ret, sec in rows:
        if sec:
            s += "\n### %s\n\n" % sec
        s += "- `%s(%s)`%s%s\n" % (name, args, " → `%s`" % ret if ret and ret != "Void" else "", " — " + doc if doc else "")
    return s

api = rd("source/scripting/ScriptApi.hx")
menu = rd("source/scripting/MenuScripts.hx")
mgr = rd("source/scripting/ScriptManager.hx")
head = re.search(r"/\*\*(.*?)\*/\s*class ScriptManager", mgr, re.S).group(1)
head = "\n".join(l.strip().lstrip("*").rstrip() for l in head.split("\n")).strip()

out = ["# API de scripts do FunkForge\n",
       "_Gerado por `tools/gen_api_docs.py` a partir do código — não edite à mão._\n",
       "Scripts `.hx` (HScript) e `.lua` usam as mesmas funções. **F6** no jogo recarrega os scripts da música.\n",
       "## Callbacks e onde ficam os scripts\n", "```\n" + head + "\n```\n",
       "## Funções dos scripts de música\n", table(funcs(api, "m")),
       "## Modchart\n",
       "Alvo: `0-7` (0-3 oponente, 4-7 jogador), `\"player\"`, `\"opponent\"`, `\"all\"` ou `\"0,2,5\"`. "
       "Propriedades: `x`, `y`, `angle`, `alpha`, `size`, `waveX`, `waveY`, `waveSpeed`, `wavePhase`.\n",
       "## Scripts de menu (`scripts/menus/*.hx` e `states/*.hx`)\n",
       "Callbacks: `onCreate`, `onCreatePost`, `onUpdate(elapsed)`, `onSelect(id)` (true cancela), `onBack` (só telas de mod), `onDestroy`.\n",
       table(funcs(menu, "v")),
       "## Eventos do chart\n"]
for p in sorted(glob.glob(os.path.join(SRC, "assets/data/events/*.json"))):
    try:
        e = json.load(open(p, encoding="utf-8"))
    except Exception:
        continue
    params = "; ".join("%s (padrão %s)" % (x.get("label", "?"), x.get("default", "")) for x in e.get("params", []))
    out.append("- **%s** — %s%s\n" % (e.get("name", os.path.basename(p)), e.get("description", ""), " · " + params if params else ""))

os.makedirs(os.path.join(SRC, "docs"), exist_ok=True)
with open(os.path.join(SRC, "docs", "API.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("docs/API.md gerado")
