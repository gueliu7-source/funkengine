#!/usr/bin/env python3
"""Confere um mod antes de jogar: acha arquivos que os scripts/charts usam e não existem, e funções Lua do Psych
que o FunkForge ainda não implementa.   python3 tools/audit_mod.py mods/meu-mod
"""
import glob, json, os, re, sys, collections

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
mod = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)

def exists(rel):
    for root in (mod, os.path.join(ROOT, "assets"), os.path.join(ROOT, "mods")):
        p = os.path.join(root, rel); d = os.path.dirname(p); b = os.path.basename(p).lower()
        if os.path.isdir(d) and any(f.lower() == b for f in os.listdir(d)):
            return True
    return False

def strip(t):
    t = re.sub(r"--\[\[.*?\]\]", "", t, flags=re.S)
    return re.sub(r"--[^\n]*", "", t)

problems = 0
src = ""
for f in ("source/scripting/PsychLua.hx", "source/scripting/ScriptApi.hx"):
    src += open(os.path.join(ROOT, f), encoding="utf-8").read()
known = set(re.findall(r'm\.set\("(\w+)"', src))
calls, defined = collections.Counter(), set()
LUA = {"if", "for", "while", "function", "return", "and", "or", "not", "print", "pairs", "ipairs", "tostring", "tonumber", "type",
       "math", "string", "table", "require", "pcall", "select", "unpack", "setmetatable", "getmetatable", "error", "assert", "next",
       "rawget", "rawset", "os", "elseif", "until"}
for f in glob.glob(mod + "/**/*.lua", recursive=True):
    t = strip(open(f, encoding="utf-8", errors="ignore").read())
    defined |= set(re.findall(r"function\s+(?:\w+\.)?(\w+)\s*\(", t))
    for n in re.findall(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(", t):
        calls[n] += 1
    rel = os.path.relpath(f, mod)
    for fn in ("makeLuaSprite", "makeAnimatedLuaSprite"):
        for m in re.finditer(fn + r"\(\s*['\"][^'\"]*['\"]\s*,\s*['\"]([^'\"]+)['\"]", t):
            r = m.group(1)
            if r and not r.endswith("/") and not exists("images/" + r + ".png"):
                print("[imagem ausente]", rel, "->", r); problems += 1
    for m in re.finditer(r"(?:makeVideoSprite|startVideo)\(\s*(?:['\"][^'\"]*['\"]\s*,\s*)?['\"]([^'\"]+)['\"]", t):
        if not exists("videos/" + m.group(1) + ".mp4"):
            print("[vídeo ausente]", rel, "->", m.group(1) + ".mp4"); problems += 1
    for m in re.finditer(r"playSound\(\s*['\"]([^'\"]+)['\"]", t):
        if not exists("sounds/" + m.group(1) + ".ogg"):
            print("[som ausente]", rel, "->", m.group(1)); problems += 1
for n, c in sorted(calls.items(), key=lambda x: -x[1]):
    if n not in known and n not in defined and n not in LUA and not n.startswith(("doTween", "noteTween")):
        print("[função Lua não implementada]", n, "(%dx)" % c); problems += 1
for c in glob.glob(mod + "/data/songs/*/*.json"):
    try:
        j = json.load(open(c, encoding="utf-8"))
    except Exception as e:
        print("[chart inválido]", c, e); problems += 1; continue
    s = j["song"] if isinstance(j.get("song"), dict) else j
    name = os.path.relpath(c, mod)
    for k in ("player1", "player2", "gfVersion", "gf"):
        v = s.get(k)
        if isinstance(v, str) and v and not exists("data/characters/%s.json" % v):
            print("[personagem ausente]", name, k, v); problems += 1
    st = s.get("stage")
    if isinstance(st, str) and st and not exists("data/stages/%s.json" % st):
        print("[stage ausente]", name, st); problems += 1
    for sec in s.get("notes", []) if isinstance(s.get("notes"), list) else []:
        pass
print("Nenhum problema encontrado." if not problems else "%d problema(s)." % problems)
