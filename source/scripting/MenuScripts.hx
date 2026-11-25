package scripting;

import core.Hex;
import core.Nav;
import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import hscript.Interp;
import hscript.Parser;
import ui.MenuUtil;

/**
 * Scripts de menu vindos dos mods: mods/<mod>/scripts/menus/<tela>.hx (e all.hx, para todas as telas).
 * Telas: title, mainmenu, story, freeplay, options, mods, controls (e states/<nome>.hx, ver ScriptedState).
 * Callbacks: onCreate, onCreatePost, onUpdate(elapsed), onSelect(id) (true = cancela o padrão), onDestroy.
 * Cada script enxerga `state` (a tela), FlxG/FlxSprite/FlxText/FlxTween/FlxTimer/FlxEase/Paths/Settings/Math/Std
 * e as funções add, remove, insert, makeSprite, makeText, color, sound, music, go, get, set, readText, readJson.
 */
class MenuScripts
{
	var state:FlxState;
	var name:String;
	var interps:Array<Interp> = [];
	var paths:Array<String> = [];
	var started:Bool = false;
	var shownError:Bool = false;

	var rels:Array<String>;

	/** Scripts de uma tela de menu (scripts/menus/all.hx + scripts/menus/<name>.hx). */
	public static function make(state:FlxState, name:String):MenuScripts
		return new MenuScripts(state, name, ["scripts/menus/all.hx", "scripts/menus/" + name + ".hx"]);

	/** Scripts em caminhos específicos (usado pelo ScriptedState). */
	public static function makeFor(state:FlxState, name:String, rels:Array<String>):MenuScripts
		return new MenuScripts(state, name, rels);

	function new(state:FlxState, name:String, rels:Array<String>)
	{
		this.state = state;
		this.name = name;
		this.rels = rels;
	}

	/** Liga os scripts na primeira atualização da tela (a tela já está montada). */
	public function update(elapsed:Float):Void
	{
		if (!started)
		{
			started = true;
			#if sys
			for (r in rels)
				for (f in Paths.findAll(r))
					load(f);
			#end
			call("onCreate");
			call("onCreatePost");
		}
		if (interps.length > 0)
			call("onUpdate", [elapsed]);
	}

	public function destroy():Void
	{
		call("onDestroy");
		interps = [];
	}

	public function has():Bool
		return interps.length > 0;

	/** Chama a função em todos os scripts; true se algum devolveu true. */
	public function call(fn:String, ?args:Array<Dynamic>):Bool
	{
		var res = false;
		for (i in interps)
		{
			var f = i.variables.get(fn);
			if (f == null || !Reflect.isFunction(f))
				continue;
			try
			{
				if (Reflect.callMethod(null, f, args == null ? [] : args) == true)
					res = true;
			}
			catch (e:Dynamic)
				report(fn + "(): " + e);
		}
		return res;
	}

	function report(msg:String):Void
	{
		trace("[menu:" + name + "] " + msg);
		if (shownError)
			return;
		shownError = true;
		var t = MenuUtil.text(10, 6, FlxG.width - 20, 14, FlxTextAlign.LEFT, "erro no script de menu: " + msg);
		t.color = 0xFFFF6666;
		t.scrollFactor.set();
		state.add(t);
	}

	function load(path:String):Void
	{
		#if sys
		try
		{
			var p = new Parser();
			p.allowJSON = true;
			p.allowTypes = true;
			p.allowMetadata = true;
			var i = new Interp();
			var v = i.variables;
			v.set("state", state);
			v.set("FlxG", FlxG);
			v.set("FlxSprite", FlxSprite);
			v.set("FlxText", FlxText);
			v.set("FlxTween", FlxTween);
			v.set("FlxTimer", FlxTimer);
			v.set("FlxEase", ScriptApi.easeObject());
			v.set("Paths", Paths);
			v.set("Settings", Settings);
			v.set("Math", Math);
			v.set("Std", Std);
			v.set("Reflect", Reflect);
			v.set("StringTools", StringTools);
			v.set("add", function(o:Dynamic) state.add(o));
			v.set("remove", function(o:Dynamic) state.remove(o, true));
			v.set("insert", function(at:Int, o:Dynamic) state.insert(at, o));
			v.set("makeSprite", function(?image:String, ?x:Float, ?y:Float):FlxSprite {
				var s = new FlxSprite(x == null ? 0 : x, y == null ? 0 : y);
				var g = image == null ? null : Paths.graphic(image.indexOf("/") < 0 ? "images/" + image : image);
				if (g != null)
					s.loadGraphic(g);
				else
					s.makeGraphic(64, 64, 0xFFFFFFFF);
				s.antialiasing = Settings.d.antialiasing;
				return s;
			});
			v.set("makeText", function(x:Float, y:Float, w:Float, text:String, ?size:Int):FlxText {
				var t = MenuUtil.text(x, y, w, size == null ? 32 : size, FlxTextAlign.LEFT, text);
				return t;
			});
			v.set("color", function(s:String):Int return Hex.color(s, 0xFFFFFFFF));
			v.set("sound", function(n:String, ?vol:Float) MenuUtil.sfx(n, vol == null ? 0.7 : vol));
			v.set("music", function(n:String, ?vol:Float) {
				var m = Paths.loadSound("music/" + n + ".ogg");
				if (m != null)
					FlxG.sound.playMusic(m, vol == null ? 0.7 : vol);
			});
			v.set("go", function(target:String) Nav.go(target));
			v.set("get", function(f:String):Dynamic return Reflect.getProperty(state, f));
			v.set("set", function(f:String, val:Dynamic) Reflect.setProperty(state, f, val));
			v.set("readText", function(rel:String):String return Paths.getText(rel));
			v.set("readJson", function(rel:String):Dynamic {
				var t = Paths.getText(rel);
				return t == null ? null : haxe.Json.parse(t);
			});
			i.execute(p.parseString(Paths.readFile(path), path));
			interps.push(i);
			paths.push(path);
		}
		catch (e:Dynamic)
			report(path + ": " + e);
		#end
	}
}
