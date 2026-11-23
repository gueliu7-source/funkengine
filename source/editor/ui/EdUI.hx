package editor.ui;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import openfl.events.KeyboardEvent;

/** Cores, medidas e criadores básicos do editor: superfícies suaves, sem bordas pesadas. */
class EdTheme
{
	public static inline var BG:FlxColor = 0xFF0B0E13;
	public static inline var SURFACE:FlxColor = 0xFF12161D;
	public static inline var SURFACE2:FlxColor = 0xFF1A202A;
	public static inline var HOVER:FlxColor = 0xFF262F3D;
	public static inline var LINE:FlxColor = 0xFF222A36;
	public static inline var ACCENT:FlxColor = 0xFFFFB347;
	public static inline var CYAN:FlxColor = 0xFF4DD0E1;
	public static inline var TEXT:FlxColor = 0xFFE6EDF3;
	public static inline var DIM:FlxColor = 0xFF9AA6B8;
	public static inline var GOOD:FlxColor = 0xFF7BE0A4;
	public static inline var BAD:FlxColor = 0xFFFF6B6B;
	public static final LANE:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	// layout (1280x720)
	public static inline var TOP_H:Int = 52;
	public static inline var LEFT_X:Int = 16;
	public static inline var LEFT_W:Int = 340;
	public static inline var SIDE_X:Int = 884;
	public static inline var SIDE_W:Int = 380;

	/** Texto. Todos os textos do editor passam por aqui (mesma fonte, sem contorno). */
	public static function text(x:Float, y:Float, w:Float, size:Int, s:String = "", color:FlxColor = TEXT, align:FlxTextAlign = FlxTextAlign.LEFT):FlxText
	{
		var t = new FlxText(x, y, w, s, size);
		t.setFormat(Paths.UI_FONT, size, color, align);
		t.antialiasing = true;
		t.scrollFactor.set();
		t.active = false;
		return t;
	}

	public static function rect(x:Float, y:Float, w:Int, h:Int, c:FlxColor):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(w, h, c);
		s.scrollFactor.set();
		s.moves = false;
		s.active = false;
		return s;
	}

	/** Retângulo arredondado branco (pinte com .color). */
	public static function round(x:Float, y:Float, w:Int, h:Int, r:Int):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(s, 0, 0, w, h, r * 2, r * 2, FlxColor.WHITE);
		s.scrollFactor.set();
		s.moves = false;
		s.active = false;
		return s;
	}

	public static function circle(x:Float, y:Float, d:Int):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(d, d, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(s, d / 2, d / 2, d / 2 - 0.5, FlxColor.WHITE);
		s.scrollFactor.set();
		s.moves = false;
		s.active = false;
		return s;
	}

	public static inline function lerpf(a:Float, b:Float, dt:Float, speed:Float):Float
		return a + (b - a) * (1 - Math.exp(-dt * speed));

	public static function mix(a:FlxColor, b:FlxColor, t:Float):FlxColor
		return FlxColor.interpolate(a, b, t < 0 ? 0 : (t > 1 ? 1 : t));
}

/** Cartão: superfície arredondada com título pequeno (sem moldura). */
class Card extends FlxSpriteGroup
{
	public function new(x:Float, y:Float, w:Int, h:Int, title:String = "")
	{
		super();
		var bg = EdTheme.round(x, y, w, h, 10);
		bg.color = EdTheme.SURFACE;
		add(bg);
		if (title != "")
			add(EdTheme.text(x + 16, y + 12, w - 32, 12, title.toUpperCase(), EdTheme.DIM));
	}
}

/**
 * Botão com hover suave. estilo: 0 = normal, 1 = destaque (âmbar), 2 = fantasma (só aparece no hover).
 * repeat: segurando, repete o clique (útil para - e +).
 */
class Btn extends FlxSpriteGroup
{
	public var onClick:Void->Void;
	public var enabledFn:Void->Bool;
	public var repeat:Bool = false;

	var bg:FlxSprite;
	var label:FlxText;
	var kind:Int;
	var hot:Float = 0;
	var flash:Float = 0;
	var textValue:String;
	var heldFor:Float = 0;
	var lastRepeat:Float = 0;

	public function new(x:Float, y:Float, w:Int, h:Int, text:String, onClick:Void->Void, kind:Int = 0, ?enabledFn:Void->Bool, size:Int = 14)
	{
		super();
		this.onClick = onClick;
		this.enabledFn = enabledFn;
		this.kind = kind;
		textValue = text;
		bg = EdTheme.round(x, y, w, h, Std.int(Math.min(10, h / 2)));
		bg.active = true;
		add(bg);
		label = EdTheme.text(x, y + (h - size) / 2 - 1, w, size, text, kind == 1 ? 0xFF1A1305 : EdTheme.TEXT, FlxTextAlign.CENTER);
		add(label);
		paint(0);
	}

	public function setText(t:String):Void
	{
		if (t == textValue)
			return;
		textValue = t;
		label.text = t;
	}

	function paint(h:Float):Void
	{
		var base:FlxColor = kind == 1 ? EdTheme.ACCENT : (kind == 2 ? FlxColor.TRANSPARENT : EdTheme.SURFACE2);
		var hov:FlxColor = kind == 1 ? 0xFFFFC978 : EdTheme.HOVER;
		if (kind == 2)
		{
			bg.color = hov;
			bg.alpha = h;
		}
		else
			bg.color = EdTheme.mix(base, hov, h);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var on = enabledFn == null || enabledFn();
		if (kind != 1)
			label.color = on ? EdTheme.TEXT : EdTheme.DIM;
		else
			label.alpha = on ? 1 : 0.5;
		var over = on && EdLock.free() && FlxG.mouse.overlaps(bg);
		hot = EdTheme.lerpf(hot, over ? 1 : 0, elapsed, 18);
		flash = EdTheme.lerpf(flash, 0, elapsed, 10);
		paint(Math.min(1, hot + flash * 0.6));
		bg.scale.set(1 + 0.03 * hot - 0.03 * (over && FlxG.mouse.pressed ? 1 : 0), 1 + 0.03 * hot - 0.03 * (over && FlxG.mouse.pressed ? 1 : 0));
		if (!over)
		{
			heldFor = 0;
			return;
		}
		if (FlxG.mouse.justPressed)
		{
			flash = 1;
			heldFor = 0;
			lastRepeat = 0;
			if (onClick != null)
				onClick();
		}
		else if (repeat && FlxG.mouse.pressed)
		{
			heldFor += elapsed;
			if (heldFor > 0.4 && heldFor - lastRepeat > 0.07)
			{
				lastRepeat = heldFor;
				if (onClick != null)
					onClick();
			}
		}
	}
}

/** Bloqueio de mouse: enquanto um overlay (ajuda, etc.) está aberto, os widgets de baixo ignoram o mouse. */
class EdLock
{
	public static var locked:Bool = false;

	public static inline function free():Bool
		return !locked;
}

/** Interruptor com animação. Clicar na linha inteira alterna. */
class Toggle extends FlxSpriteGroup
{
	var track:FlxSprite;
	var knob:FlxSprite;
	var row:FlxSprite;
	var get:Void->Bool;
	var setter:Bool->Void;
	var k:Float;
	var rowX:Float;
	var rowW:Int;
	var hot:Float = 0;

	public function new(x:Float, y:Float, w:Int, label:String, get:Void->Bool, set:Bool->Void)
	{
		super();
		this.get = get;
		setter = set;
		rowX = x;
		rowW = w;
		row = EdTheme.round(x - 8, y - 3, w + 16, 28, 8);
		row.color = EdTheme.HOVER;
		row.alpha = 0;
		row.active = true;
		add(row);
		add(EdTheme.text(x, y + 2, w - 52, 14, label, EdTheme.TEXT));
		track = EdTheme.round(x + w - 38, y + 2, 38, 20, 10);
		track.color = EdTheme.LINE;
		add(track);
		knob = EdTheme.circle(x + w - 36, y + 4, 16);
		knob.color = 0xFFCBD3DC;
		add(knob);
		k = get() ? 1 : 0;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var on = get();
		k = EdTheme.lerpf(k, on ? 1 : 0, elapsed, 16);
		track.color = EdTheme.mix(EdTheme.LINE, EdTheme.ACCENT, k);
		knob.x = rowX + rowW - 36 + 18 * k;
		var over = EdLock.free() && FlxG.mouse.overlaps(row);
		hot = EdTheme.lerpf(hot, over ? 0.5 : 0, elapsed, 16);
		row.alpha = hot;
		if (over && FlxG.mouse.justPressed)
			setter(!on);
	}
}

/** Barra deslizante. onLive roda enquanto arrasta; onCommit(antigo, novo) roda ao soltar. */
class Slider extends FlxSpriteGroup
{
	var track:FlxSprite;
	var fill:FlxSprite;
	var knob:FlxSprite;
	var valueText:FlxText;
	var get:Void->Float;
	var onLive:Float->Void;
	var onCommit:Null<Float->Float->Void>;
	var min:Float;
	var max:Float;
	var decimals:Int;
	var tx:Float;
	var tw:Int;
	var dragging:Bool = false;
	var startValue:Float = 0;
	var hot:Float = 0;
	var lastShown:String = "";

	public function new(x:Float, y:Float, w:Int, label:String, get:Void->Float, onLive:Float->Void, min:Float, max:Float, decimals:Int = 1, ?onCommit:Float->Float->Void)
	{
		super();
		this.get = get;
		this.onLive = onLive;
		this.onCommit = onCommit;
		this.min = min;
		this.max = max;
		this.decimals = decimals;
		tx = x;
		tw = w;
		add(EdTheme.text(x, y, w - 80, 14, label, EdTheme.DIM));
		valueText = EdTheme.text(x + w - 80, y, 80, 14, "", EdTheme.TEXT, FlxTextAlign.RIGHT);
		add(valueText);
		track = EdTheme.round(x, y + 24, w, 4, 2);
		track.color = EdTheme.LINE;
		add(track);
		fill = EdTheme.round(x, y + 24, w, 4, 2);
		fill.color = EdTheme.ACCENT;
		fill.origin.set(0, 2);
		fill.active = true;
		add(fill);
		knob = EdTheme.circle(x, y + 19, 14);
		knob.color = 0xFFFFFFFF;
		knob.active = true;
		add(knob);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var v = get();
		var p = (v - min) / (max - min);
		p = p < 0 ? 0 : (p > 1 ? 1 : p);
		var near = EdLock.free() && (FlxG.mouse.x >= tx - 8 && FlxG.mouse.x <= tx + tw + 8 && FlxG.mouse.y >= track.y - 12 && FlxG.mouse.y <= track.y + 16);
		if (near && FlxG.mouse.justPressed)
		{
			dragging = true;
			startValue = v;
		}
		if (dragging)
		{
			if (FlxG.mouse.pressed)
			{
				var q = (FlxG.mouse.x - tx) / tw;
				q = q < 0 ? 0 : (q > 1 ? 1 : q);
				var pw = Math.pow(10, decimals);
				var nv = Math.round((min + q * (max - min)) * pw) / pw;
				if (nv != v)
					onLive(nv);
				v = nv;
				p = q;
			}
			else
			{
				dragging = false;
				if (onCommit != null)
					onCommit(startValue, get());
			}
		}
		hot = EdTheme.lerpf(hot, (near || dragging) ? 1 : 0, elapsed, 16);
		fill.scale.x = Math.max(0.001, p);
		var d = 12 + 4 * hot;
		knob.scale.set(d / 14, d / 14);
		knob.x = tx + p * tw - 7;
		var s = Std.string(Math.round(v * Math.pow(10, decimals)) / Math.pow(10, decimals));
		if (s != lastShown)
		{
			lastShown = s;
			valueText.text = s;
		}
	}
}

/** Valor numérico com - e + (segurar repete). SHIFT = x10. */
class Stepper extends FlxSpriteGroup
{
	var value:FlxText;
	var get:Void->Float;
	var decimals:Int;
	var lastShown:String = "";

	public function new(x:Float, y:Float, w:Int, label:String, get:Void->Float, set:Float->Void, step:Float, min:Float, max:Float, decimals:Int = 0)
	{
		super();
		this.get = get;
		this.decimals = decimals;
		add(EdTheme.text(x, y + 4, w - 150, 14, label, EdTheme.DIM));
		var bx = x + w - 150;
		var clamp = function(v:Float) return v < min ? min : (v > max ? max : v);
		var minus = new Btn(bx, y, 30, 26, "-", function() set(clamp(get() - step * (FlxG.keys.pressed.SHIFT ? 10 : 1))), 0);
		var plus = new Btn(bx + 120, y, 30, 26, "+", function() set(clamp(get() + step * (FlxG.keys.pressed.SHIFT ? 10 : 1))), 0);
		minus.repeat = true;
		plus.repeat = true;
		value = EdTheme.text(bx + 30, y + 5, 90, 14, "", EdTheme.TEXT, FlxTextAlign.CENTER);
		add(minus);
		add(plus);
		add(value);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var p = Math.pow(10, decimals);
		var s = Std.string(Math.round(get() * p) / p);
		if (s != lastShown)
		{
			lastShown = s;
			value.text = s;
		}
	}
}

/** Escolha de uma lista com ‹ ›. */
class Selector extends FlxSpriteGroup
{
	var value:FlxText;
	var get:Void->String;
	var lastShown:String = "\u0000";

	public function new(x:Float, y:Float, w:Int, label:String, options:Void->Array<String>, get:Void->String, set:String->Void, labelW:Int = 96)
	{
		super();
		this.get = get;
		add(EdTheme.text(x, y + 4, labelW, 14, label, EdTheme.DIM));
		var bx = x + labelW;
		var bw = w - labelW;
		var pill = EdTheme.round(bx, y, bw, 26, 13);
		pill.color = EdTheme.SURFACE2;
		add(pill);
		var move = function(dir:Int) {
			var o = options();
			if (o.length == 0)
				return;
			var i = o.indexOf(get());
			set(o[(i + dir + o.length * 2) % o.length]);
		};
		add(new Btn(bx, y, 28, 26, "<", function() move(-1), 2));
		add(new Btn(bx + bw - 28, y, 28, 26, ">", function() move(1), 2));
		value = EdTheme.text(bx + 30, y + 5, bw - 60, 14, "", EdTheme.TEXT, FlxTextAlign.CENTER);
		add(value);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = get();
		if (s != lastShown)
		{
			lastShown = s;
			value.text = s == "" ? "(nenhum)" : s;
		}
	}
}

/** Fileira de opções (controle segmentado): a escolhida fica âmbar. */
class Segments extends FlxSpriteGroup
{
	var chips:Array<Btn> = [];
	var names:Array<String>;
	var get:Void->String;
	var hl:Array<FlxSprite> = [];

	public function new(x:Float, y:Float, w:Int, names:Array<String>, get:Void->String, set:String->Void)
	{
		super();
		this.names = names;
		this.get = get;
		var cw = Std.int(w / names.length);
		for (i in 0...names.length)
		{
			var n = names[i];
			var h = EdTheme.round(x + i * cw + 2, y, cw - 4, 26, 8);
			h.color = EdTheme.ACCENT;
			h.alpha = 0;
			hl.push(h);
			add(h);
			chips.push(new Btn(x + i * cw + 2, y, cw - 4, 26, n, function() set(n), 2));
			add(chips[i]);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var cur = get();
		for (i in 0...names.length)
			hl[i].alpha = EdTheme.lerpf(hl[i].alpha, names[i] == cur ? 0.28 : 0, elapsed, 16);
	}
}

/** Abas com sublinhado deslizante; cada aba mostra um grupo (com fade). */
class Tabs extends FlxSpriteGroup
{
	public var index(default, null):Int = 0;

	var titles:Array<FlxText> = [];
	var buttons:Array<Btn> = [];
	var under:FlxSprite;
	var contents:Array<FlxSpriteGroup> = [];
	var cw:Float;
	var tx:Float;
	var cur:Float;

	public function new(x:Float, y:Float, w:Int, names:Array<String>)
	{
		super();
		tx = x;
		cw = w / names.length;
		for (i in 0...names.length)
		{
			var b = new Btn(x + i * cw, y, Std.int(cw), 30, names[i], function() select(i), 2, null, names.length > 3 ? 11 : 14);
			buttons.push(b);
			add(b);
		}
		add(EdTheme.rect(x, y + 33, w, 1, EdTheme.LINE));
		under = EdTheme.round(x + 10, y + 32, Std.int(cw) - 20, 3, 1);
		under.color = EdTheme.ACCENT;
		under.active = true;
		add(under);
		cur = 0;
	}

	public function setContents(groups:Array<FlxSpriteGroup>):Void
	{
		contents = groups;
		for (i in 0...contents.length)
		{
			contents[i].alpha = i == index ? 1 : 0;
			contents[i].visible = i == index;
			contents[i].active = i == index;
		}
	}

	public function select(i:Int):Void
	{
		if (i == index || i < 0 || i >= contents.length)
			return;
		index = i;
		contents[i].visible = true;
		contents[i].active = true;
		contents[i].alpha = 0;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		cur = EdTheme.lerpf(cur, index, elapsed, 16);
		under.x = tx + cur * cw + 10;
		for (i in 0...contents.length)
		{
			var c = contents[i];
			if (i == index)
			{
				if (c.alpha < 1)
					c.alpha = Math.min(1, c.alpha + elapsed * 7);
			}
			else if (c.visible)
			{
				c.alpha -= elapsed * 12;
				if (c.alpha <= 0)
				{
					c.alpha = 0;
					c.visible = false;
					c.active = false;
				}
			}
		}
	}
}

/** Caixa de texto de uma linha. Clique para editar, ENTER confirma, ESC cancela. */
class TextInput extends FlxSpriteGroup
{
	public static var current:Null<TextInput> = null;
	public static var swallow:Bool = false; // uma tecla acabou de ser usada aqui: o editor deve ignorá-la neste frame
	static var hooked:Bool = false;

	public static inline function typing():Bool
		return current != null;

	var bg:FlxSprite;
	var edge:FlxSprite;
	var label:FlxText;
	var get:Void->String;
	var set:String->Void;
	var buf:String = "";
	var focused:Bool = false;
	var blink:Float = 0;
	var shown:String = "\u0000";
	var hot:Float = 0;

	public function new(x:Float, y:Float, w:Int, get:Void->String, set:String->Void)
	{
		super();
		this.get = get;
		this.set = set;
		edge = EdTheme.round(x - 1, y - 1, w + 2, 28, 9);
		edge.color = EdTheme.ACCENT;
		edge.alpha = 0;
		add(edge);
		bg = EdTheme.round(x, y, w, 26, 8);
		bg.color = EdTheme.SURFACE2;
		bg.active = true;
		add(bg);
		label = EdTheme.text(x + 10, y + 5, w - 20, 14, "", EdTheme.TEXT);
		add(label);
		if (!hooked)
		{
			hooked = true;
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
		}
	}

	static function onKey(e:KeyboardEvent):Void
	{
		var t = current;
		if (t == null)
			return;
		swallow = true;
		if (e.keyCode == 13)
			t.blur(true);
		else if (e.keyCode == 27)
			t.blur(false);
		else if (e.keyCode == 8)
			t.buf = t.buf.substr(0, t.buf.length - 1);
		else if (e.charCode >= 32 && e.charCode != 127 && !e.ctrlKey)
			t.buf += String.fromCharCode(e.charCode);
	}

	function blur(commit:Bool):Void
	{
		if (!focused)
			return;
		focused = false;
		if (current == this)
			current = null;
		if (commit && buf != get())
			set(buf);
	}

	override public function destroy():Void
	{
		if (current == this)
			current = null;
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var over = EdLock.free() && FlxG.mouse.overlaps(bg);
		if (FlxG.mouse.justPressed)
		{
			if (over && !focused)
			{
				if (current != null)
					current.blur(true);
				focused = true;
				current = this;
				buf = get();
				blink = 0;
			}
			else if (!over && focused)
				blur(true);
		}
		hot = EdTheme.lerpf(hot, focused ? 1 : (over ? 0.35 : 0), elapsed, 16);
		edge.alpha = hot * 0.9;
		blink += elapsed;
		var s = focused ? buf + ((Std.int(blink * 2) % 2 == 0) ? "|" : "") : get();
		if (s != shown)
		{
			shown = s;
			label.text = s;
		}
	}
}

/** Aviso rápido que desliza/some (status de salvar, desfazer, erros). */
class Toast extends FlxSpriteGroup
{
	var pill:FlxSprite;
	var label:FlxText;
	var life:Float = 0;
	var baseY:Float;
	var cx:Float;

	public function new(cx:Float, y:Float)
	{
		super();
		this.cx = cx;
		baseY = y;
		pill = EdTheme.round(cx - 260, y, 520, 32, 16);
		pill.color = EdTheme.SURFACE2;
		add(pill);
		label = EdTheme.text(cx - 250, y + 8, 500, 14, "", EdTheme.GOOD, FlxTextAlign.CENTER);
		add(label);
		alpha = 0;
	}

	public function show(s:String, good:Bool = true):Void
	{
		label.text = s;
		label.color = good ? EdTheme.GOOD : EdTheme.BAD;
		life = 4;
		alpha = 0.01;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (life > 0)
		{
			life -= elapsed;
			var a = life < 0.5 ? life / 0.5 : Math.min(1, alpha + elapsed * 8);
			alpha = a;
			var off = (1 - a) * 10;
			pill.y = baseY + off;
			label.y = baseY + 8 + off;
		}
		else
			alpha = 0;
	}
}
