package editor.stage;

import editor.StageEditorState;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import game.StageTimeline;
import game.StageTimeline.TlEvent;

using StringTools;

private class Row extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var label:FlxText;
	public var ev:Null<TlEvent>;
	public var hot:Float = 0;

	public function new(x:Float, y:Float, w:Int)
	{
		super();
		bg = EdTheme.round(x, y, w, 24, 7);
		bg.color = EdTheme.SURFACE;
		add(bg);
		label = EdTheme.text(x + 8, y + 5, w - 16, 12, "", EdTheme.TEXT);
		add(label);
	}
}

/** Aba TIMELINE: eventos que mudam o cenário em momentos exatos (em beats). Roda igual no jogo. */
class TimelineTab extends FlxSpriteGroup
{
	static inline var ROWS:Int = 6;
	static inline var LIST_Y:Int = 306;
	static inline var ROW_H:Int = 26;

	var ed:StageEditorState;
	var rows:Array<Row> = [];
	var scrollRow:Int = 0;
	var selEv:Null<TlEvent>;
	var valueG:FlxSpriteGroup = new FlxSpriteGroup();
	var imageG:FlxSpriteGroup = new FlxSpriteGroup();
	var x0:Float;
	var w0:Int;

	public function new(ed:StageEditorState)
	{
		super();
		this.ed = ed;
		x0 = EdTheme.SIDE_X + 16;
		w0 = EdTheme.SIDE_W - 32;
		var x = x0;
		var w = w0;

		add(new Toggle(x, 124, w, "Ver a timeline no palco", function() return ed.view.tlOn, function(v) ed.view.tlOn = v));
		add(new Stepper(x, 158, w, "Beat atual", function() return ed.curBeat(), function(v) ed.gotoBeat(v), 1, 0, 2000, 2));
		var third = Std.int((w - 12) / 3);
		add(new Btn(x, 196, third, 28, "+ EVENTO", addEvent, 1));
		add(new Btn(x + third + 6, 196, third, 28, "DUPLICAR", dup, 0, hasSel));
		add(new Btn(x + (third + 6) * 2, 196, third, 28, "EXCLUIR", del, 0, hasSel));
		var half = Std.int((w - 8) / 2);
		add(new Btn(x, 232, half, 28, "MOSTRAR (fade)", function() quick(1), 0, hasLayer));
		add(new Btn(x + half + 8, 232, half, 28, "OCULTAR (fade)", function() quick(0), 0, hasLayer));
		add(EdTheme.text(x, 276, w, 12, "EVENTOS  (beat | peça | o que muda)", EdTheme.DIM));

		for (i in 0...ROWS)
		{
			var r = new Row(x, LIST_Y + i * ROW_H, w);
			rows.push(r);
			add(r);
		}

		var ey = LIST_Y + ROWS * ROW_H + 10; // 472
		add(new Selector(x, ey, w, "Peça", function() return [for (o in ed.doc.objs) o.id], function() return selEv != null ? selEv.target : "", function(v) change("peça", function(e) e.target = v), 70));
		add(new Selector(x, ey + 30, w, "Muda", function() return StageTimeline.PROPS, function() return selEv != null ? selEv.prop : "", function(v) change("propriedade", function(e) {
			e.prop = v;
			e.value = defaultValue(v);
		}), 70));
		valueG.add(EdTheme.text(x, ey + 64, 70, 12, "Para", EdTheme.DIM));
		valueG.add(new TextInput(x + 74, ey + 60, w - 74, function() return selEv != null ? selEv.value : "", function(v) change("valor", function(e) e.value = v.trim())));
		imageG.add(new Selector(x, ey + 60, w - 76, "Para", function() return ed.images(), function() return selEv != null && selEv.value != "" ? selEv.value : "(escolha)", function(v) change("imagem", function(e) e.value = v), 44));
		imageG.add(new Btn(x + w - 70, ey + 60, 70, 26, "+ PNG", function() ed.importImage(function(img) change("imagem", function(e) e.value = img)), 1, hasSel, 12));
		add(valueG);
		add(imageG);
		add(new Stepper(x, ey + 94, w, "No beat", function() return selEv != null ? selEv.beat : 0, function(v) change("beat", function(e) e.beat = v), 0.25, 0, 2000, 2));
		add(new Stepper(x, ey + 122, w, "Duração (beats)", function() return selEv != null ? selEv.dur : 0, function(v) change("duração", function(e) e.dur = v), 0.25, 0, 500, 2));
		add(new Selector(x, ey + 152, w, "Curva", function() return StageTimeline.EASES, function() return selEv != null ? selEv.ease : "linear", function(v) change("curva", function(e) e.ease = v), 70));
		add(EdTheme.text(x, ey + 186, w, 12, "anim = toca a animação (prefixo do atlas; \"prefixo:loop\" repete). Cor: hex. Outros: número. Duração 0 = instantâneo.", EdTheme.DIM));
	}

	/** O grupo pai propaga "visible" aos filhos; por isso a escolha texto/imagem é refeita a cada desenho. */
	override public function draw():Void
	{
		var isImg = selEv != null && selEv.prop == "image";
		valueG.visible = !isImg;
		imageG.visible = isImg;
		super.draw();
	}

	function hasSel():Bool
		return selEv != null && ed.doc.tl.indexOf(selEv) >= 0;

	function hasLayer():Bool
		return ed.view.sel != "" && !ed.view.sel.startsWith("@");

	static function defaultValue(prop:String):String
		return switch (prop)
		{
			case "alpha": "0";
			case "scale": "1";
			case "color": "FFFFFF";
			case "image": "";
			case "anim": "idle";
			case "angle": "0";
			default: "0";
		}

	function snap(b:Float):Float
		return Math.round(b * 4) / 4;

	function change(label:String, fn:TlEvent->Void):Void
	{
		var e = selEv;
		if (e == null)
			return;
		ed.doc.edit("timeline: " + label, function() {
			fn(e);
			StageTimeline.sortEvents(ed.doc.tl);
		});
	}

	function addEvent():Void
	{
		var t = hasLayer() ? ed.view.sel : (ed.doc.objs.length > 0 ? ed.doc.objs[0].id : "");
		if (t == "")
		{
			ed.say("Adicione uma peça no palco primeiro.", false);
			return;
		}
		var e:TlEvent = {
			beat: snap(ed.curBeat()),
			target: t,
			prop: "alpha",
			value: "0",
			dur: 1,
			ease: "linear"
		};
		ed.doc.edit("timeline: novo evento", function() {
			ed.doc.tl.push(e);
			StageTimeline.sortEvents(ed.doc.tl);
		});
		selEv = e;
	}

	function dup():Void
	{
		var s = selEv;
		if (s == null)
			return;
		var e:TlEvent = {
			beat: s.beat + 1,
			target: s.target,
			prop: s.prop,
			value: s.value,
			dur: s.dur,
			ease: s.ease
		};
		ed.doc.edit("timeline: duplicar", function() {
			ed.doc.tl.push(e);
			StageTimeline.sortEvents(ed.doc.tl);
		});
		selEv = e;
	}

	function del():Void
	{
		var s = selEv;
		if (s == null)
			return;
		ed.doc.edit("timeline: excluir", function() ed.doc.tl.remove(s));
		selEv = null;
	}

	/** Atalho: faz a peça selecionada aparecer/sumir com fade de 2 beats a partir do beat atual. */
	function quick(to:Int):Void
	{
		var id = ed.view.sel;
		var b = snap(ed.curBeat());
		var made:Null<TlEvent> = null;
		ed.doc.edit(to == 1 ? "timeline: mostrar" : "timeline: ocultar", function() {
			var has = false;
			for (e in ed.doc.tl)
				if (e.target == id && e.prop == "alpha" && e.beat <= b)
					has = true;
			if (!has && to == 1) // antes do primeiro evento a peça precisa estar invisível
				ed.doc.tl.push({
					beat: 0,
					target: id,
					prop: "alpha",
					value: "0",
					dur: 0,
					ease: "linear"
				});
			made = {
				beat: b,
				target: id,
				prop: "alpha",
				value: to == 1 ? "1" : "0",
				dur: 2,
				ease: "inout"
			};
			ed.doc.tl.push(made);
			StageTimeline.sortEvents(ed.doc.tl);
		});
		selEv = made;
		ed.view.tlOn = true;
	}

	function fmt(e:TlEvent):String
	{
		var v = e.prop == "image" ? e.value.substr(e.value.lastIndexOf("/") + 1) : e.value;
		return Std.string(Math.round(e.beat * 100) / 100) + " | " + e.target + " | " + e.prop + " → " + v + (e.dur > 0 ? "  (" + e.dur + "b)" : "");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var list = ed.doc.tl;
		if (selEv != null && list.indexOf(selEv) < 0)
			selEv = null; // desfazer/refazer troca os objetos

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
				r.ev = null;
				continue;
			}
			r.visible = true;
			var e = list[idx];
			r.ev = e;
			var over = inList && !EdLock.locked && my >= LIST_Y + i * ROW_H && my < LIST_Y + i * ROW_H + 24;
			r.hot = EdTheme.lerpf(r.hot, over ? 1 : 0, elapsed, 18);
			r.bg.color = e == selEv ? EdTheme.mix(EdTheme.SURFACE2, EdTheme.ACCENT, 0.28) : EdTheme.mix(EdTheme.SURFACE, EdTheme.HOVER, r.hot);
			var t = fmt(e);
			if (r.label.text != t)
				r.label.text = t;
			r.label.color = e.beat <= ed.curBeat() ? EdTheme.CYAN : EdTheme.TEXT; // ciano = já aconteceu
		}

		if (inList && FlxG.mouse.justPressed && !EdLock.locked && !TextInput.typing())
		{
			var i = Std.int((my - LIST_Y) / ROW_H);
			if (i >= 0 && i < ROWS && rows[i].visible && rows[i].ev != null)
			{
				selEv = rows[i].ev;
				if (selEv.target != "" && ed.doc.byId(selEv.target) != null)
					ed.view.sel = selEv.target;
			}
		}
	}
}
