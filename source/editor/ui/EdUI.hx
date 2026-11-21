package editor.ui;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Cores e criadores de texto do editor (identidade própria: grafite + âmbar + ciano). */
class EdTheme
{
	public static inline var BG:FlxColor = 0xFF0E1116;
	public static inline var PANEL:FlxColor = 0xFF171C24;
	public static inline var EDGE:FlxColor = 0xFF2A3342;
	public static inline var ACCENT:FlxColor = 0xFFFFB347;
	public static inline var CYAN:FlxColor = 0xFF4DD0E1;
	public static inline var TEXT:FlxColor = 0xFFE6EDF3;
	public static inline var DIM:FlxColor = 0xFF8A97A6;
	public static inline var BTN:FlxColor = 0xFF222B38;
	public static inline var BTN_HOT:FlxColor = 0xFF2F3B4D;
	public static inline var BTN_DOWN:FlxColor = 0xFF45566F;
	public static inline var GOOD:FlxColor = 0xFF7BE0A4;
	public static inline var BAD:FlxColor = 0xFFFF6B6B;
	public static final LANE:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];

	public static function text(x:Float, y:Float, w:Float, size:Int, s:String = "", color:FlxColor = TEXT, align:FlxTextAlign = FlxTextAlign.LEFT):FlxText
	{
		var t = new FlxText(x, y, w, s, size);
		t.setFormat(Paths.FONT, size, color, align);
		t.scrollFactor.set();
		return t;
	}

	public static function rect(x:Float, y:Float, w:Int, h:Int, c:FlxColor):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(w, h, c);
		s.scrollFactor.set();
		s.moves = false;
		return s;
	}
}

/** Painel com título. Os widgets são adicionados por cima, com coordenadas de tela. */
class Panel extends FlxSpriteGroup
{
	public function new(x:Float, y:Float, w:Int, h:Int, title:String)
	{
		super();
		add(EdTheme.rect(x, y, w, h, EdTheme.EDGE));
		add(EdTheme.rect(x + 1, y + 1, w - 2, h - 2, EdTheme.PANEL));
		add(EdTheme.rect(x + 1, y + 1, w - 2, 22, 0xFF1E2530));
		add(EdTheme.rect(x + 1, y + 1, 3, 22, EdTheme.ACCENT));
		add(EdTheme.text(x + 10, y + 4, w - 20, 14, title.toUpperCase(), EdTheme.ACCENT));
	}
}

/** Botão. `enabledFn` (opcional) deixa o botão cinza e inerte. */
class Btn extends FlxSpriteGroup
{
	public var onClick:Void->Void;
	public var enabledFn:Void->Bool;

	var bg:FlxSprite;
	var label:FlxText;
	var textValue:String;

	public function new(x:Float, y:Float, w:Int, h:Int, text:String, onClick:Void->Void, ?enabledFn:Void->Bool)
	{
		super();
		this.onClick = onClick;
		this.enabledFn = enabledFn;
		textValue = text;
		bg = EdTheme.rect(x, y, w, h, EdTheme.BTN);
		add(bg);
		label = EdTheme.text(x, y + (h - 14) / 2 - 1, w, 14, text, EdTheme.TEXT, FlxTextAlign.CENTER);
		add(label);
	}

	public function setText(t:String):Void
	{
		if (t == textValue)
			return;
		textValue = t;
		label.text = t;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var on = enabledFn == null || enabledFn();
		label.color = on ? EdTheme.TEXT : EdTheme.DIM;
		if (!on)
		{
			bg.color = EdTheme.BTN;
			return;
		}
		var over = FlxG.mouse.overlaps(bg);
		bg.color = over ? (FlxG.mouse.pressed ? EdTheme.BTN_DOWN : EdTheme.BTN_HOT) : EdTheme.BTN;
		if (over && FlxG.mouse.justPressed && onClick != null)
			onClick();
	}
}

/** Valor numérico com - e +. SHIFT multiplica o passo por 10. */
class Stepper extends FlxSpriteGroup
{
	var minus:Btn;
	var plus:Btn;
	var value:FlxText;
	var get:Void->Float;
	var decimals:Int;
	var lastText:String = "";

	public function new(x:Float, y:Float, w:Int, label:String, get:Void->Float, set:Float->Void, step:Float, min:Float, max:Float, decimals:Int = 0)
	{
		super();
		this.get = get;
		this.decimals = decimals;
		add(EdTheme.text(x, y + 3, w - 130, 14, label, EdTheme.DIM));
		var bx = x + w - 124;
		minus = new Btn(bx, y, 24, 22, "-", function() {
			set(clamp(get() - step * (FlxG.keys.pressed.SHIFT ? 10 : 1), min, max));
		});
		plus = new Btn(bx + 100, y, 24, 22, "+", function() {
			set(clamp(get() + step * (FlxG.keys.pressed.SHIFT ? 10 : 1), min, max));
		});
		value = EdTheme.text(bx + 24, y + 3, 76, 14, "", EdTheme.TEXT, FlxTextAlign.CENTER);
		add(minus);
		add(plus);
		add(value);
	}

	static inline function clamp(v:Float, a:Float, b:Float):Float
		return v < a ? a : (v > b ? b : v);

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var f = get();
		var p = Math.pow(10, decimals);
		var s = Std.string(Math.round(f * p) / p);
		if (s != lastText)
		{
			lastText = s;
			value.text = s;
		}
	}
}

/** Caixa liga/desliga. */
class Toggle extends FlxSpriteGroup
{
	var box:FlxSprite;
	var mark:FlxSprite;
	var get:Void->Bool;

	public function new(x:Float, y:Float, label:String, get:Void->Bool, set:Bool->Void)
	{
		super();
		this.get = get;
		box = EdTheme.rect(x, y + 2, 16, 16, EdTheme.EDGE);
		mark = EdTheme.rect(x + 3, y + 5, 10, 10, EdTheme.ACCENT);
		add(box);
		add(mark);
		add(EdTheme.text(x + 24, y + 3, 260, 14, label, EdTheme.TEXT));
		this.setter = set;
	}

	var setter:Bool->Void;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		mark.visible = get();
		if (FlxG.mouse.justPressed && (FlxG.mouse.overlaps(box) || FlxG.mouse.overlaps(members[2])))
			setter(!get());
	}
}

/** Escolha de uma lista com < >. */
class Selector extends FlxSpriteGroup
{
	var value:FlxText;
	var get:Void->String;
	var options:Void->Array<String>;
	var lastText:String = "\u0000";

	public function new(x:Float, y:Float, w:Int, label:String, options:Void->Array<String>, get:Void->String, set:String->Void)
	{
		super();
		this.get = get;
		this.options = options;
		add(EdTheme.text(x, y + 3, 90, 14, label, EdTheme.DIM));
		var bx = x + 92;
		var bw = w - 92;
		var move = function(dir:Int) {
			var o = options();
			if (o.length == 0)
				return;
			var i = o.indexOf(get());
			set(o[(i + dir + o.length * 2) % o.length]);
		};
		add(new Btn(bx, y, 24, 22, "<", function() move(-1)));
		add(new Btn(bx + bw - 24, y, 24, 22, ">", function() move(1)));
		value = EdTheme.text(bx + 26, y + 3, bw - 52, 14, "", EdTheme.TEXT, FlxTextAlign.CENTER);
		add(value);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = get();
		if (s != lastText)
		{
			lastText = s;
			value.text = s == "" ? "(nenhum)" : s;
		}
	}
}
