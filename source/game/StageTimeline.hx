package game;

import core.Paths;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

using StringTools;

/** Um evento da timeline do cenário. value é texto: número, cor hex "RRGGBB" ou caminho de imagem (prop "image"). */
typedef TlEvent =
{
	var beat:Float;
	var target:String; // id da peça
	var prop:String; // alpha, x, y, scale, angle, color, image
	var value:String;
	var dur:Float; // em beats (0 = instantâneo)
	var ease:String; // linear, in, out, inout
}

/** Valores iniciais de uma peça (antes de qualquer evento). */
typedef TlBase =
{
	var x:Float;
	var y:Float;
	var scale:Float;
	var alpha:Float;
	var angle:Float;
	var color:Int;
	var image:String;
}

/**
 * Timeline do cenário: o estado de cada peça é uma FUNÇÃO PURA do beat atual (não acumula nada),
 * então pular na música, voltar e repetir sempre dão o mesmo resultado. O jogo e o editor usam este mesmo código.
 */
class StageTimeline
{
	public static final PROPS:Array<String> = ["alpha", "x", "y", "scale", "angle", "color", "image", "anim"];
	public static final EASES:Array<String> = ["linear", "in", "out", "inout"];

	public var events:Array<TlEvent> = [];

	var index:Map<String, Array<TlEvent>> = new Map(); // "id|prop" -> eventos ordenados
	var targets:Map<String, Array<String>> = new Map(); // id -> props animadas
	var curImage:Map<String, String> = new Map();
	var curAnim:Map<String, TlEvent> = new Map();

	public function new(?list:Array<TlEvent>)
	{
		setEvents(list != null ? list : []);
	}

	public var empty(get, never):Bool;

	inline function get_empty():Bool
		return events.length == 0;

	public static function parse(raw:Null<Array<Dynamic>>):Array<TlEvent>
	{
		var out:Array<TlEvent> = [];
		if (raw == null)
			return out;
		for (r in raw)
		{
			if (r == null || r.target == null || r.prop == null)
				continue;
			out.push({
				beat: r.beat != null ? r.beat : 0,
				target: Std.string(r.target),
				prop: Std.string(r.prop),
				value: r.value != null ? Std.string(r.value) : "",
				dur: r.dur != null ? r.dur : 0,
				ease: r.ease != null ? Std.string(r.ease) : "linear"
			});
		}
		return out;
	}

	public static function sortEvents(l:Array<TlEvent>):Void
		l.sort(function(a, b) return a.beat < b.beat ? -1 : (a.beat > b.beat ? 1 : 0));

	public function setEvents(list:Array<TlEvent>):Void
	{
		events = list;
		index = new Map();
		targets = new Map();
		var sorted = events.copy();
		sortEvents(sorted);
		for (e in sorted)
		{
			var k = e.target + "|" + e.prop;
			if (!index.exists(k))
				index.set(k, []);
			index.get(k).push(e);
			if (!targets.exists(e.target))
				targets.set(e.target, []);
			if (targets.get(e.target).indexOf(e.prop) < 0)
				targets.get(e.target).push(e.prop);
		}
	}

	/** Esquece qual imagem cada peça está mostrando (use ao recriar os sprites). */
	public function forget():Void
	{
		curImage = new Map();
		curAnim = new Map();
	}

	public function animates(id:String):Bool
		return targets.exists(id);

	static function ease(name:String, t:Float):Float
		return switch (name)
		{
			case "in": FlxEase.quadIn(t);
			case "out": FlxEase.quadOut(t);
			case "inout": FlxEase.quadInOut(t);
			default: t;
		}

	static function hex(s:String):Int
	{
		var t = s.split("#").join("").toUpperCase();
		if (t == "")
			return 0xFFFFFFFF;
		var c = FlxColor.fromString("#" + t);
		return c != null ? c : 0xFFFFFFFF;
	}

	function num(id:String, prop:String, b0:Float, beat:Float):Float
	{
		var l = index.get(id + "|" + prop);
		if (l == null)
			return b0;
		var cur = b0;
		for (e in l)
		{
			if (e.beat > beat)
				break;
			var v = Std.parseFloat(e.value);
			if (Math.isNaN(v))
				continue;
			if (e.dur <= 0 || beat >= e.beat + e.dur)
				cur = v;
			else
			{
				cur = cur + (v - cur) * ease(e.ease, (beat - e.beat) / e.dur);
				break;
			}
		}
		return cur;
	}

	function col(id:String, b0:Int, beat:Float):Int
	{
		var l = index.get(id + "|color");
		if (l == null)
			return b0;
		var cur:Int = b0;
		for (e in l)
		{
			if (e.beat > beat)
				break;
			var v = hex(e.value);
			if (e.dur <= 0 || beat >= e.beat + e.dur)
				cur = v;
			else
			{
				cur = FlxColor.interpolate(cur, v, ease(e.ease, (beat - e.beat) / e.dur));
				break;
			}
		}
		return cur;
	}

	function img(id:String, b0:String, beat:Float):String
	{
		var l = index.get(id + "|image");
		if (l == null)
			return b0;
		var cur = b0;
		for (e in l)
		{
			if (e.beat > beat)
				break;
			if (e.value != "")
				cur = e.value;
		}
		return cur;
	}

	/** Último evento "anim" já ocorrido para a peça (ou null). */
	function lastAnim(id:String, beat:Float):Null<TlEvent>
	{
		var l = index.get(id + "|anim");
		var cur:Null<TlEvent> = null;
		if (l != null)
			for (e in l)
			{
				if (e.beat > beat)
					break;
				cur = e;
			}
		return cur;
	}

	/** Valor "prefixo" toca uma vez; "prefixo:loop" repete. Toca do começo quando o evento muda. */
	function playAnim(id:String, s:FlxSprite, e:Null<TlEvent>):Void
	{
		if (e == curAnim.get(id))
			return;
		curAnim.set(id, e);
		if (e == null || e.value == "")
			return;
		var loop = e.value.endsWith(":loop");
		var prefix = loop ? e.value.substr(0, e.value.length - 5) : e.value;
		var key = "tl_" + prefix;
		if (!s.animation.exists(key))
			s.animation.addByPrefix(key, prefix, 24, loop);
		if (s.animation.exists(key))
		{
			s.active = true;
			s.animation.play(key, true);
		}
	}

	/** Aplica o estado do beat às peças que têm eventos (as outras não são tocadas). */
	public function apply(beat:Float, sprites:Map<String, FlxSprite>, baseOf:String->Null<TlBase>):Void
	{
		for (id in targets.keys())
		{
			var s = sprites.get(id);
			var b = baseOf(id);
			if (s == null || b == null)
				continue;
			var ps = targets.get(id);
			var swapped = false;
			if (ps.indexOf("image") >= 0)
			{
				var want = img(id, b.image, beat);
				var have = curImage.exists(id) ? curImage.get(id) : b.image;
				if (want != have)
				{
					var g = Paths.graphic("images/" + want + ".png");
					if (g != null)
					{
						s.loadGraphic(g);
						swapped = true;
					}
					curImage.set(id, want);
				}
			}
			if (ps.indexOf("anim") >= 0)
				playAnim(id, s, lastAnim(id, beat));
			if (ps.indexOf("scale") >= 0 || swapped)
			{
				var sc = num(id, "scale", b.scale, beat);
				s.scale.set(sc, sc);
				s.updateHitbox();
			}
			if (ps.indexOf("x") >= 0 || swapped)
				s.x = num(id, "x", b.x, beat);
			if (ps.indexOf("y") >= 0 || swapped)
				s.y = num(id, "y", b.y, beat);
			if (ps.indexOf("angle") >= 0)
				s.angle = num(id, "angle", b.angle, beat);
			if (ps.indexOf("alpha") >= 0)
			{
				var a = num(id, "alpha", b.alpha, beat);
				s.alpha = a < 0 ? 0 : (a > 1 ? 1 : a);
				s.visible = a > 0.001;
			}
			if (ps.indexOf("color") >= 0)
				s.color = col(id, b.color, beat);
		}
	}
}
