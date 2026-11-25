package scripting;

import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import game.Character;
import states.PlayState;

using StringTools;

/**
 * A API que os scripts enxergam. É escrita UMA vez aqui e exposta igual para HScript
 * (como variáveis) e para Lua (como funções globais), então nunca há duas APIs divergentes.
 *
 * Caminhos de propriedade ("bf.x", "camGame.zoom", "meuSprite.alpha") começam por uma tag de
 * sprite criado pelo script ou por um campo do PlayState (boyfriend, dad, gf, camHUD, hud, judge...).
 */
class ScriptApi
{
	static var eases:Map<String, Float->Float>;

	public static function easeObject():Dynamic
	{
		var o:Dynamic = {};
		for (k in easeMap().keys())
			Reflect.setField(o, k, easeMap().get(k));
		return o;
	}

	static function easeMap():Map<String, Float->Float>
	{
		if (eases != null)
			return eases;
		eases = [
			"linear" => FlxEase.linear,
			"quadIn" => FlxEase.quadIn,
			"quadOut" => FlxEase.quadOut,
			"quadInOut" => FlxEase.quadInOut,
			"cubeIn" => FlxEase.cubeIn,
			"cubeOut" => FlxEase.cubeOut,
			"cubeInOut" => FlxEase.cubeInOut,
			"quartIn" => FlxEase.quartIn,
			"quartOut" => FlxEase.quartOut,
			"quartInOut" => FlxEase.quartInOut,
			"quintIn" => FlxEase.quintIn,
			"quintOut" => FlxEase.quintOut,
			"quintInOut" => FlxEase.quintInOut,
			"sineIn" => FlxEase.sineIn,
			"sineOut" => FlxEase.sineOut,
			"sineInOut" => FlxEase.sineInOut,
			"circIn" => FlxEase.circIn,
			"circOut" => FlxEase.circOut,
			"circInOut" => FlxEase.circInOut,
			"expoIn" => FlxEase.expoIn,
			"expoOut" => FlxEase.expoOut,
			"expoInOut" => FlxEase.expoInOut,
			"backIn" => FlxEase.backIn,
			"backOut" => FlxEase.backOut,
			"backInOut" => FlxEase.backInOut,
			"bounceIn" => FlxEase.bounceIn,
			"bounceOut" => FlxEase.bounceOut,
			"bounceInOut" => FlxEase.bounceInOut,
			"elasticIn" => FlxEase.elasticIn,
			"elasticOut" => FlxEase.elasticOut,
			"elasticInOut" => FlxEase.elasticInOut,
			"smoothStepIn" => FlxEase.smoothStepIn,
			"smoothStepOut" => FlxEase.smoothStepOut,
			"smoothStepInOut" => FlxEase.smoothStepInOut,
			"smootherStepIn" => FlxEase.smootherStepIn,
			"smootherStepOut" => FlxEase.smootherStepOut,
			"smootherStepInOut" => FlxEase.smootherStepInOut
		];
		return eases;
	}

	static function ease(name:String):Float->Float
	{
		var f = easeMap().get(name == null ? "linear" : name);
		return f == null ? FlxEase.linear : f;
	}

	static function color(v:Dynamic):FlxColor
	{
		if (Std.isOfType(v, String))
		{
			var c = FlxColor.fromString(cast(v, String));
			return c == null ? FlxColor.WHITE : c;
		}
		return (v : Int);
	}

	static function getObj(g:PlayState, path:String):Dynamic
	{
		var parts = path.split(".");
		var cur:Dynamic = g.tagged.get(parts[0]);
		if (cur == null)
			cur = Reflect.getProperty(g, parts[0]);
		for (i in 1...parts.length)
		{
			if (cur == null)
				return null;
			cur = Reflect.getProperty(cur, parts[i]);
		}
		return cur;
	}

	static function setProp(g:PlayState, path:String, value:Dynamic):Void
	{
		var i = path.lastIndexOf(".");
		if (i < 0)
		{
			Reflect.setProperty(g, path, value);
			return;
		}
		var obj = getObj(g, path.substr(0, i));
		if (obj != null)
			Reflect.setProperty(obj, path.substr(i + 1), value);
	}

	static function cam(g:PlayState, name:String):FlxCamera
		return (name == "hud" || name == "camHUD") ? g.camHUD : g.camGame;

	static function who(g:PlayState, name:String):Character
	{
		return switch (name)
		{
			case "dad" | "opponent": g.dad;
			case "gf" | "girlfriend": g.gf;
			default: g.boyfriend;
		}
	}

	public static function build(g:PlayState, mgr:ScriptManager):Map<String, Dynamic>
	{
		var m = new Map<String, Dynamic>();
		var tweens = new Map<String, FlxTween>();
		var timers = new Map<String, FlxTimer>();

		// ------------------------------------------------------------ utilidades
		m.set("debugPrint", function(?text:Dynamic) {
			trace(Std.string(text));
			g.showError(Std.string(text), 0xFFFFFFFF);
		});
		m.set("rgb", function(r:Int, gr:Int, b:Int):Int return FlxColor.fromRGB(r, gr, b));
		m.set("randomInt", function(min:Int, max:Int):Int return FlxG.random.int(min, max));
		m.set("randomFloat", function(min:Float, max:Float):Float return FlxG.random.float(min, max));
		m.set("randomBool", function(percent:Float):Bool return FlxG.random.bool(percent));
		m.set("fileExists", function(rel:String):Bool return Paths.exists(rel));

		// ------------------------------------------------------------ propriedades genéricas
		m.set("getProperty", function(path:String):Dynamic return getObj(g, path));
		m.set("setProperty", function(path:String, value:Dynamic):Void setProp(g, path, value));
		m.set("getSetting", function(name:String):Dynamic return Reflect.field(Settings.d, name));

		// ------------------------------------------------------------ sprites criados por script
		m.set("makeSprite", function(tag:String, image:String, ?x:Float, ?y:Float):Bool {
			var gr = Paths.graphic("images/" + image + ".png");
			if (gr == null)
				return false;
			var s = new FlxSprite(x == null ? 0 : x, y == null ? 0 : y);
			s.loadGraphic(gr);
			s.antialiasing = Settings.d.antialiasing;
			g.tagged.set(tag, s);
			return true;
		});
		m.set("makeAnimatedSprite", function(tag:String, atlas:String, ?x:Float, ?y:Float):Bool {
			var f = Paths.sparrow("images/" + atlas);
			if (f == null)
				return false;
			var s = new FlxSprite(x == null ? 0 : x, y == null ? 0 : y);
			s.frames = f;
			s.antialiasing = Settings.d.antialiasing;
			g.tagged.set(tag, s);
			return true;
		});
		m.set("addAnimationByPrefix", function(tag:String, name:String, prefix:String, ?fps:Int, ?loop:Bool):Void {
			var s = g.tagged.get(tag);
			if (s != null)
				s.animation.addByPrefix(name, prefix, fps == null ? 24 : fps, loop == true);
		});
		m.set("playSpriteAnim", function(tag:String, name:String, ?force:Bool):Void {
			var s = g.tagged.get(tag);
			if (s != null)
				s.animation.play(name, force != false);
		});
		// layer: "back", "gf", "dad", "front" (cenário) ou "hud"
		m.set("addSprite", function(tag:String, ?layer:String):Void {
			var s = g.tagged.get(tag);
			if (s != null)
				g.addToLayer(s, layer == null ? "front" : layer);
		});
		m.set("removeSprite", function(tag:String):Void {
			var s = g.tagged.get(tag);
			if (s != null)
			{
				s.kill();
				g.tagged.remove(tag);
			}
		});
		m.set("setScrollFactor", function(tag:String, x:Float, y:Float):Void {
			var s = g.tagged.get(tag);
			if (s != null)
				s.scrollFactor.set(x, y);
		});
		m.set("setSpriteScale", function(tag:String, sx:Float, ?sy:Float):Void {
			var s = g.tagged.get(tag);
			if (s != null)
			{
				s.scale.set(sx, sy == null ? sx : sy);
				s.updateHitbox();
			}
		});
		m.set("screenCenter", function(tag:String, ?axis:String):Void {
			var s = g.tagged.get(tag);
			if (s == null)
				return;
			switch (axis)
			{
				case "x":
					s.screenCenter(flixel.util.FlxAxes.X);
				case "y":
					s.screenCenter(flixel.util.FlxAxes.Y);
				default:
					s.screenCenter();
			}
		});

		// ------------------------------------------------------------ tweens e timers
		// props: tabela/objeto, ex.: doTween("t1", "boyfriend", {x = 100, alpha = 0.5}, 1, "quadOut")
		m.set("doTween", function(tag:String, objPath:String, props:Dynamic, duration:Float, ?easeName:String):Void {
			var obj = getObj(g, objPath);
			if (obj == null)
				return;
			var old = tweens.get(tag);
			if (old != null)
				old.cancel();
			tweens.set(tag, FlxTween.tween(obj, props, duration, {
				ease: ease(easeName),
				onComplete: function(_) {
					tweens.remove(tag);
					mgr.call("onTweenCompleted", [tag]);
				}
			}));
		});
		m.set("cancelTween", function(tag:String):Void {
			var t = tweens.get(tag);
			if (t != null)
			{
				t.cancel();
				tweens.remove(tag);
			}
		});
		m.set("runTimer", function(tag:String, seconds:Float, ?loops:Int):Void {
			var old = timers.get(tag);
			if (old != null)
				old.cancel();
			var n = loops == null ? 1 : loops;
			timers.set(tag, new FlxTimer().start(seconds, function(t:FlxTimer) {
				mgr.call("onTimerCompleted", [tag, t.elapsedLoops, t.loopsLeft]);
			}, n));
		});
		m.set("cancelTimer", function(tag:String):Void {
			var t = timers.get(tag);
			if (t != null)
			{
				t.cancel();
				timers.remove(tag);
			}
		});

		// ------------------------------------------------------------ câmera
		m.set("cameraShake", function(camName:String, intensity:Float, duration:Float):Void cam(g, camName).shake(intensity, duration));
		m.set("cameraFlash", function(camName:String, col:Dynamic, duration:Float):Void cam(g, camName).flash(color(col), duration));
		m.set("cameraFade", function(camName:String, col:Dynamic, duration:Float):Void cam(g, camName).fade(color(col), duration));
		m.set("setCameraZoom", function(camName:String, z:Float):Void {
			cam(g, camName).zoom = z;
		});
		m.set("getCameraZoom", function(camName:String):Float return cam(g, camName).zoom);
		m.set("setDefaultCamZoom", function(z:Float):Void {
			g.defaultZoom = z;
		});
		m.set("cameraFocus", function(target:String):Void g.focusCamera(target));

		// ------------------------------------------------------------ personagens
		m.set("characterPlayAnim", function(name:String, anim:String, ?force:Bool):Void {
			var c = who(g, name);
			if (c != null)
			{
				c.playAnim(anim, force != false);
				c.specialAnim = (c.animation.curAnim != null && !c.animation.curAnim.looped);
			}
		});
		m.set("characterDance", function(name:String):Void {
			var c = who(g, name);
			if (c != null)
			{
				c.specialAnim = false;
				c.dance();
			}
		});

		// ------------------------------------------------------------ áudio
		m.set("playSound", function(name:String, ?volume:Float):Void {
			var s = Paths.sound("sounds/" + name + ".ogg");
			if (s != null)
				FlxG.sound.play(s, volume == null ? 1 : volume);
		});

		// ------------------------------------------------------------ estado do jogo
		m.set("getScore", function():Int return g.judge.score);
		m.set("getMisses", function():Int return g.judge.misses);
		m.set("getCombo", function():Int return g.judge.combo);
		m.set("getAccuracy", function():Float return g.judge.accuracy);
		m.set("getHealth", function():Float return g.judge.health);
		m.set("setHealth", function(v:Float):Void {
			g.judge.health = Math.max(0, Math.min(2, v));
		});
		m.set("addHealth", function(v:Float):Void g.judge.addHealth(v));
		m.set("getSongPosition", function():Float return Conductor.songPosition);
		m.set("getBpm", function():Float return Conductor.bpm);
		m.set("getCurStep", function():Int return Conductor.curStep);
		m.set("getCurBeat", function():Int return Conductor.curBeat);
		m.set("getCurSection", function():Int return Conductor.curSection);
		m.set("setScrollSpeed", function(v:Float):Void g.setScrollSpeed(v));
		m.set("getScrollSpeed", function():Float return g.scrollSpeed);
		m.set("endSong", function():Void g.endSong());
		m.set("triggerEvent", function(name:String, ?v1:String, ?v2:String):Void {
			mgr.call("onEvent", [name, v1 == null ? "" : v1, v2 == null ? "" : v2]);
		});

		// ------------------------------------------------------------ receptores (0-3 oponente, 4-7 jogador)
		m.set("getReceptorX", function(i:Int):Float return g.receptor(i).cx);
		m.set("getReceptorY", function(i:Int):Float return g.receptor(i).cy);
		m.set("setReceptorPos", function(i:Int, x:Float, y:Float):Void g.receptor(i).setCenter(x, y));
		m.set("setReceptorAngle", function(i:Int, a:Float):Void {
			g.receptor(i).angle = a;
		});
		m.set("setReceptorAlpha", function(i:Int, a:Float):Void {
			g.receptor(i).alpha = a;
		});

		return m;
	}
}
