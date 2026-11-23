package editor.character;

import editor.CharEditorState;
import editor.character.CharDoc.EAnim;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

using StringTools;

private class Row extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var label:FlxText;
	public var tag:FlxText;
	public var name:String = "";
	public var hot:Float = 0;

	public function new(x:Float, y:Float, w:Int)
	{
		super();
		bg = EdTheme.round(x, y, w, 24, 7);
		bg.color = EdTheme.SURFACE;
		add(bg);
		label = EdTheme.text(x + 10, y + 5, w - 140, 12, "", EdTheme.TEXT);
		add(label);
		tag = EdTheme.text(x + w - 130, y + 6, 122, 11, "", EdTheme.DIM, FlxTextAlign.RIGHT);
		add(tag);
	}
}

/** Aba ANIMAÇÕES: lista, atlas, fps, loop e offsets. Clicar numa animação a toca no palco. */
class AnimTab extends FlxSpriteGroup
{
	static inline var ROWS:Int = 8;
	static inline var LIST_Y:Int = 142;
	static inline var ROW_H:Int = 26;

	static var addChoice:String = "";

	var ed:CharEditorState;
	var rows:Array<Row> = [];
	var scrollRow:Int = 0;
	var x0:Float;
	var w0:Int;

	public function new(ed:CharEditorState)
	{
		super();
		this.ed = ed;
		x0 = EdTheme.SIDE_X + 16;
		w0 = EdTheme.SIDE_W - 32;
		var x = x0;
		var w = w0;
		add(EdTheme.text(x, 124, w, 12, "ANIMAÇÕES  (clique para tocar)", EdTheme.DIM));
		for (i in 0...ROWS)
		{
			var r = new Row(x, LIST_Y + i * ROW_H, w);
			rows.push(r);
			add(r);
		}
		var third = Std.int((w - 12) / 3);
		var by = LIST_Y + ROWS * ROW_H + 8; // 358
		add(new Btn(x, by, third, 28, "+ ADICIONAR", addAnim, 1));
		add(new Btn(x + third + 6, by, third, 28, "DUPLICAR", dup, 0, hasSel));
		add(new Btn(x + (third + 6) * 2, by, third, 28, "EXCLUIR", del, 0, hasSel));
		add(new Selector(x, by + 36, w, "Do atlas", function() return ed.doc.atlasPrefixes(), function() {
			var l = ed.doc.atlasPrefixes();
			if (addChoice == "" || l.indexOf(addChoice) < 0)
				addChoice = l.length > 0 ? l[0] : "";
			return addChoice == "" ? "(atlas vazio)" : addChoice;
		}, function(v) addChoice = v, 62));

		var ey = by + 84; // 442
		add(EdTheme.text(x, ey, 60, 12, "Nome", EdTheme.DIM));
		add(new TextInput(x + 64, ey - 5, w - 64, function() return cur() != null ? cur().name : "", function(v) {
			var a = cur();
			var nv = v.trim();
			if (a == null || nv == "" || nv == a.name || ed.doc.animByName(nv) != null)
				return;
			ed.doc.edit("renomear animação", function() a.name = nv);
			ed.view.curAnim = nv;
		}));
		add(new Selector(x, ey + 28, w, "Prefixo", function() return ed.doc.atlasPrefixes(), function() return cur() != null ? cur().prefix : "", function(v) edit("prefixo", function(a) a.prefix = v), 62));
		add(new Stepper(x, ey + 58, w, "FPS", function() return cur() != null ? cur().fps : 24, function(v) edit("fps", function(a) a.fps = Std.int(v)), 1, 1, 120, 0));
		add(new Toggle(x, ey + 88, w, "Repetir (loop)", function() return cur() != null && cur().loop, function(v) edit("loop", function(a) a.loop = v)));
		add(new Stepper(x, ey + 120, w, "Offset X", function() return cur() != null ? cur().ox : 0, function(v) edit("offset", function(a) a.ox = v), 1, -2000, 2000, 0));
		add(new Stepper(x, ey + 148, w, "Offset Y", function() return cur() != null ? cur().oy : 0, function(v) edit("offset", function(a) a.oy = v), 1, -2000, 2000, 0));
		add(EdTheme.text(x, ey + 182, 60, 12, "Quadros", EdTheme.DIM));
		add(new TextInput(x + 64, ey + 177, w - 64, function() return cur() != null ? cur().indices : "", function(v) edit("quadros", function(a) a.indices = v.trim())));
		add(EdTheme.text(x, ey + 210, w, 12, "Arraste o personagem no palco (ou use as setas) para ajustar o offset. Quadros: vazio = todos; ex.: 0,1,2,3.", EdTheme.DIM));
	}

	function cur():Null<EAnim>
		return ed.doc.animByName(ed.view.curAnim);

	function hasSel():Bool
		return cur() != null;

	function edit(label:String, fn:EAnim->Void):Void
	{
		var a = cur();
		if (a != null)
			ed.doc.edit(label, function() fn(a));
	}

	static function guessName(prefix:String):String
	{
		var p = prefix.toLowerCase();
		for (k in ["idle", "left", "down", "up", "right", "hey", "scared"])
			if (p.indexOf(k) >= 0)
			{
				var base = k == "idle" || k == "hey" || k == "scared" ? k : "sing" + k.toUpperCase();
				return p.indexOf("miss") >= 0 ? base + "miss" : base;
			}
		var clean = new EReg("[^A-Za-z0-9]+", "g").replace(prefix, "_");
		return clean == "" ? "anim" : clean;
	}

	function addAnim():Void
	{
		if (addChoice == "")
		{
			ed.say("O atlas não tem animações (verifique o atlas na aba PERSONAGEM).", false);
			return;
		}
		var n = ed.doc.uniqueName(guessName(addChoice));
		ed.doc.edit("nova animação", function() ed.doc.anims.push({
			name: n,
			prefix: addChoice,
			fps: 24,
			loop: false,
			indices: "",
			ox: 0,
			oy: 0
		}));
		ed.view.play(n);
		ed.say("Animação \"" + n + "\" criada. Renomeie se precisar (ex.: singLEFT, idle).");
	}

	function dup():Void
	{
		var a = cur();
		if (a == null)
			return;
		var n = ed.doc.uniqueName(a.name);
		ed.doc.edit("duplicar animação", function() ed.doc.anims.push({
			name: n,
			prefix: a.prefix,
			fps: a.fps,
			loop: a.loop,
			indices: a.indices,
			ox: a.ox,
			oy: a.oy
		}));
		ed.view.play(n);
	}

	function del():Void
	{
		var a = cur();
		if (a == null)
			return;
		ed.doc.edit("excluir animação", function() ed.doc.anims.remove(a));
		ed.view.play(ed.doc.anims.length > 0 ? ed.doc.anims[0].name : "idle");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var list = ed.doc.anims;
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var inList = mx >= x0 && mx < x0 + w0 && my >= LIST_Y && my < LIST_Y + ROWS * ROW_H;
		if (inList && FlxG.mouse.wheel != 0 && !EdLock.locked)
			scrollRow -= FlxG.mouse.wheel > 0 ? 1 : -1;
		scrollRow = Std.int(Math.max(0, Math.min(Math.max(0, list.length - ROWS), scrollRow)));
		for (i in 0...ROWS)
		{
			var r = rows[i];
			var idx = scrollRow + i;
			if (idx >= list.length)
			{
				r.visible = false;
				r.name = "";
				continue;
			}
			r.visible = true;
			var a = list[idx];
			r.name = a.name;
			var over = inList && !EdLock.locked && my >= LIST_Y + i * ROW_H && my < LIST_Y + i * ROW_H + 24;
			r.hot = EdTheme.lerpf(r.hot, over ? 1 : 0, elapsed, 18);
			var selected = a.name == ed.view.curAnim;
			r.bg.color = selected ? EdTheme.mix(EdTheme.SURFACE2, EdTheme.ACCENT, 0.28) : EdTheme.mix(EdTheme.SURFACE, EdTheme.HOVER, r.hot);
			if (r.label.text != a.name)
				r.label.text = a.name;
			var t = Std.int(a.ox) + ", " + Std.int(a.oy);
			if (r.tag.text != t)
				r.tag.text = t;
		}
		if (inList && FlxG.mouse.justPressed && !EdLock.locked && !TextInput.typing())
		{
			var i = Std.int((my - LIST_Y) / ROW_H);
			if (i >= 0 && i < ROWS && rows[i].visible && rows[i].name != "")
				ed.view.play(rows[i].name);
		}
	}
}
