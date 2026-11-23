package editor.stage;

import editor.StageEditorState;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

using StringTools;

private class Row extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var eye:FlxSprite;
	public var lock:FlxSprite;
	public var name:FlxText;
	public var tag:FlxText;
	public var id:String = "";
	public var hot:Float = 0;

	public function new(x:Float, y:Float, w:Int)
	{
		super();
		bg = EdTheme.round(x, y, w, 24, 7);
		bg.color = EdTheme.SURFACE;
		add(bg);
		eye = EdTheme.circle(x + 9, y + 7, 10);
		add(eye);
		lock = EdTheme.round(x + 34, y + 7, 10, 10, 3);
		add(lock);
		name = EdTheme.text(x + 54, y + 4, w - 130, 13, "", EdTheme.TEXT);
		add(name);
		tag = EdTheme.text(x + w - 74, y + 5, 66, 11, "", EdTheme.DIM, FlxTextAlign.RIGHT);
		add(tag);
	}
}

/** Aba CAMADAS: lista da frente para o fundo (com os personagens como marcadores), olho, cadeado, ordem e imagens novas. */
class LayersTab extends FlxSpriteGroup
{
	static inline var ROWS:Int = 12;
	static inline var LIST_Y:Int = 262;
	static inline var ROW_H:Int = 26;

	static var addChoice:String = "";

	var ed:StageEditorState;
	var rows:Array<Row> = [];
	var scrollRow:Int = 0;
	var shown:Array<String> = []; // ids, da frente para o fundo
	var x0:Float;
	var w0:Int;
	var sig:String = "";

	public function new(ed:StageEditorState)
	{
		super();
		this.ed = ed;
		x0 = EdTheme.SIDE_X + 16;
		w0 = EdTheme.SIDE_W - 32;
		var x = x0;
		var w = w0;

		var third = Std.int((w - 12) / 3);
		add(new Btn(x, 124, w, 32, "IMPORTAR IMAGEM DO COMPUTADOR...", function() ed.importImage(), 1));
		add(new Btn(x, 164, third, 28, "+ ADICIONAR", addLayer, 0));
		add(new Btn(x + third + 6, 164, third, 28, "DUPLICAR", dup, 0, hasObj));
		add(new Btn(x + (third + 6) * 2, 164, third, 28, "EXCLUIR", del, 0, hasObj));
		add(new Selector(x, 202, w, "Do jogo", function() return ed.images(), function() {
			var l = ed.images();
			if (addChoice == "" || l.indexOf(addChoice) < 0)
				addChoice = l.length > 0 ? l[0] : "";
			return addChoice == "" ? "(nenhuma)" : addChoice;
		}, function(v) addChoice = v, 62));
		add(EdTheme.text(x, 242, w, 12, "CAMADAS  (frente → fundo)", EdTheme.DIM));

		for (i in 0...ROWS)
		{
			var r = new Row(x, LIST_Y + i * ROW_H, w);
			rows.push(r);
			add(r);
		}
		var half = Std.int((w - 8) / 2);
		var by = LIST_Y + ROWS * ROW_H + 8;
		add(new Btn(x, by, half, 28, "PRA FRENTE", function() ed.doc.move(ed.view.sel, 1), 0, hasObj));
		add(new Btn(x + half + 8, by, half, 28, "PRA TRÁS", function() ed.doc.move(ed.view.sel, -1), 0, hasObj));
		add(EdTheme.text(x, by + 36, w, 12, "Olho = mostrar/ocultar, quadrado = travar. Os pontos mostram onde ficam os personagens.", EdTheme.DIM));
	}

	function hasObj():Bool
		return ed.view.sel != "" && !ed.view.sel.startsWith("@");

	function addLayer():Void
	{
		if (addChoice == "")
		{
			ed.say("Nenhuma imagem encontrada em images/stages/.", false);
			return;
		}
		var c = ed.view.centerOfView();
		var animated = core.Paths.exists("images/" + addChoice + ".xml");
		var o = ed.doc.add(addChoice, animated, c[0] - 200, c[1] - 150);
		ed.view.sel = o.id;
		ed.say("Camada \"" + o.id + "\" adicionada" + (animated ? " (animada: defina o prefixo do idle em Propriedades)" : ""));
	}

	function dup():Void
	{
		var o = ed.doc.duplicate(ed.view.sel);
		if (o != null)
			ed.view.sel = o.id;
	}

	function del():Void
	{
		ed.doc.remove(ed.view.sel);
		ed.view.sel = "";
	}

	function charLabel(id:String):String
		return switch (id)
		{
			case "@bf": "● Jogador  (" + StageView.idBf + ")";
			case "@dad": "● Oponente  (" + StageView.idDad + ")";
			default: "● GF  (" + StageView.idGf + ")";
		}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		shown = ed.doc.flat();
		shown.reverse();

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var inList = mx >= x0 && mx < x0 + w0 && my >= LIST_Y && my < LIST_Y + ROWS * ROW_H;
		if (inList && FlxG.mouse.wheel != 0 && !EdLock.locked)
			scrollRow -= FlxG.mouse.wheel > 0 ? 1 : -1;
		scrollRow = Std.int(Math.max(0, Math.min(Math.max(0, shown.length - ROWS), scrollRow)));

		for (i in 0...ROWS)
		{
			var r = rows[i];
			var idx = scrollRow + i;
			if (idx >= shown.length)
			{
				r.visible = false;
				r.id = "";
				continue;
			}
			r.visible = true;
			var id = shown[idx];
			r.id = id;
			var isChar = id.startsWith("@");
			var o = isChar ? null : ed.doc.byId(id);
			var selected = ed.view.sel == id;
			var over = inList && !EdLock.locked && my >= LIST_Y + i * ROW_H && my < LIST_Y + i * ROW_H + 24;
			r.hot = EdTheme.lerpf(r.hot, over ? 1 : 0, elapsed, 18);
			r.bg.color = selected ? EdTheme.mix(EdTheme.SURFACE2, EdTheme.ACCENT, 0.28) : EdTheme.mix(EdTheme.SURFACE, EdTheme.HOVER, r.hot);
			var label = isChar ? charLabel(id) : id;
			if (r.name.text != label)
				r.name.text = label;
			r.name.color = isChar ? EdTheme.CYAN : (o != null && o.visible ? EdTheme.TEXT : EdTheme.DIM);
			var tag = isChar ? "" : (o != null ? o.group : "");
			if (r.tag.text != tag)
				r.tag.text = tag;
			r.eye.visible = !isChar;
			r.lock.visible = !isChar;
			if (!isChar && o != null)
			{
				r.eye.color = o.visible ? EdTheme.CYAN : EdTheme.LINE;
				r.lock.color = o.locked ? EdTheme.ACCENT : EdTheme.LINE;
			}
		}

		if (inList && FlxG.mouse.justPressed && !EdLock.locked && !TextInput.typing())
		{
			var i = Std.int((my - LIST_Y) / ROW_H);
			if (i >= 0 && i < ROWS && rows[i].visible && rows[i].id != "")
			{
				var id = rows[i].id;
				var o = id.startsWith("@") ? null : ed.doc.byId(id);
				if (o != null && mx < x0 + 30)
					ed.doc.edit(o.visible ? "ocultar camada" : "mostrar camada", function() o.visible = !o.visible);
				else if (o != null && mx < x0 + 52)
					ed.doc.edit(o.locked ? "destravar camada" : "travar camada", function() o.locked = !o.locked);
				else
					ed.view.sel = id;
			}
		}
	}
}
