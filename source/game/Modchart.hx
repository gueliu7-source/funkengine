package game;

import flixel.tweens.FlxTween;
import scripting.ScriptApi;
import states.PlayState;

/**
 * Modchart: anima as setas (receptores) por scripts, eventos do chart ou código.
 *
 * Alvos: 0..7 (0-3 oponente, 4-7 jogador) · "player" · "opponent" · "all" · -1 (todas) · "0,2,5" (lista).
 * Propriedades: x, y (centro na tela), angle, alpha, size (1 = normal), waveX, waveY (amplitude do balanço em px),
 *               waveSpeed (ciclos/s), wavePhase (rad).
 * As notas acompanham a seta (e a velocidade por seta continua valendo).
 */
class Modchart
{
	static var tweens:Map<String, FlxTween> = new Map();

	public static function targets(g:PlayState, t:Dynamic):Array<Receptor>
	{
		var out:Array<Receptor> = [];
		if (Std.isOfType(t, Int) || Std.isOfType(t, Float))
		{
			var i:Int = Std.int(t);
			if (i < 0)
				return targets(g, "all");
			if (i < 8)
				out.push(g.receptor(i));
			return out;
		}
		var s = StringTools.trim(Std.string(t).toLowerCase());
		switch (s)
		{
			case "player", "bf", "jogador":
				for (r in g.playerStrum.receptors)
					out.push(r);
			case "opponent", "dad", "oponente":
				for (r in g.opponentStrum.receptors)
					out.push(r);
			case "all", "todas", "":
				for (r in g.opponentStrum.receptors)
					out.push(r);
				for (r in g.playerStrum.receptors)
					out.push(r);
			default:
				for (part in s.split(","))
				{
					var i = Std.parseInt(StringTools.trim(part));
					if (i != null && i >= 0 && i < 8)
						out.push(g.receptor(i));
				}
		}
		return out;
	}

	/** x e y viram posX/posY (centro absoluto). */
	static function field(k:String):String
		return switch (k)
		{
			case "x": "posX";
			case "y": "posY";
			default: k;
		}

	static function mapProps(props:Dynamic):Dynamic
	{
		var o:Dynamic = {};
		for (k in Reflect.fields(props))
			Reflect.setField(o, field(k), Reflect.field(props, k));
		return o;
	}

	/** Muda na hora. */
	public static function set(g:PlayState, target:Dynamic, props:Dynamic):Void
	{
		var m = mapProps(props);
		for (r in targets(g, target))
			for (k in Reflect.fields(m))
				Reflect.setProperty(r, k, Reflect.field(m, k));
	}

	/** Anima. stagger = atraso (s) entre uma seta e a próxima. tag cancela a animação anterior de mesmo nome. */
	public static function tween(g:PlayState, tag:String, target:Dynamic, props:Dynamic, duration:Float, ?easeName:String, ?stagger:Float):Void
	{
		if (duration <= 0)
		{
			set(g, target, props);
			return;
		}
		var m = mapProps(props);
		var n = 0;
		for (r in targets(g, target))
		{
			var key = tag + "#" + (g.playerStrum.receptors.indexOf(r) >= 0 ? r.lane + 4 : r.lane);
			var old = tweens.get(key);
			if (old != null)
				old.cancel();
			var tw = FlxTween.tween(r, m, duration, {
				ease: ScriptApi.ease(easeName),
				startDelay: (stagger == null ? 0 : stagger) * n,
				onComplete: function(_) tweens.remove(key)
			});
			tweens.set(key, tw);
			n++;
		}
	}

	/** Volta tudo ao normal (animando se duration > 0). */
	public static function reset(g:PlayState, ?duration:Float):Void
	{
		var d = duration == null ? 0 : duration;
		for (r in targets(g, "all"))
		{
			if (d <= 0)
				r.resetMods();
			else
				FlxTween.tween(r, {posX: r.cx, posY: r.cy, angle: 0, alpha: 1, size: 1, waveX: 0, waveY: 0}, d);
		}
	}

	public static function get(g:PlayState, i:Int, prop:String):Float
	{
		var r = g.receptor(i);
		var v:Dynamic = Reflect.getProperty(r, field(prop));
		return v == null ? 0 : v;
	}

	/** Evento do chart "Strum Tween": v1 = "alvo,propriedade,valor", v2 = "duração,ease,escalonamento". */
	public static function fromEvent(g:PlayState, v1:String, v2:String):Void
	{
		var a = v1.split(",");
		if (a.length < 3)
			return;
		var target = StringTools.trim(a[0]);
		var prop = StringTools.trim(a[1]);
		var val = Std.parseFloat(a[2]);
		if (Math.isNaN(val))
			return;
		var b = v2.split(",");
		var dur = b.length > 0 ? Std.parseFloat(b[0]) : 0;
		if (Math.isNaN(dur))
			dur = 0;
		var easeName = b.length > 1 ? StringTools.trim(b[1]) : "linear";
		var st = b.length > 2 ? Std.parseFloat(b[2]) : 0;
		if (Math.isNaN(st))
			st = 0;
		var props:Dynamic = {};
		Reflect.setField(props, prop, val);
		tween(g, "ev_" + prop, target, props, dur, easeName, st);
	}
}
