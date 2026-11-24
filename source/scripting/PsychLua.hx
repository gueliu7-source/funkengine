package scripting;

import core.Chart.NoteData;
import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import game.Character;
import game.Receptor;
import states.PlayState;

using StringTools;

/** "scale" de uma nota para scripts Psych (grava em NoteData). */
@:keep
class NoteScale
{
	var n:NoteData;

	public function new(n:NoteData)
		this.n = n;

	public var x(get, set):Float;
	public var y(get, set):Float;

	function get_x():Float
		return n.scaleX;

	function set_x(v:Float):Float
	{
		n.scaleX = v;
		return v;
	}

	function get_y():Float
		return n.scaleY;

	function set_y(v:Float):Float
	{
		n.scaleY = v;
		return v;
	}
}

/** Uma nota vista como no Psych (noteType, mustPress, texture, scale, noAnimation...). Escreve em NoteData. */
@:keep
class NoteProxy
{
	var n:NoteData;

	public var scale:NoteScale;

	public function new(n:NoteData)
	{
		this.n = n;
		scale = new NoteScale(n);
	}

	public var noteType(get, set):String;
	public var mustPress(get, never):Bool;
	public var isSustainNote(get, set):Bool;
	public var strumTime(get, never):Float;
	public var noteData(get, never):Int;
	public var noAnimation(get, set):Bool;
	public var texture(get, set):String;
	public var visible(get, set):Bool;
	public var alpha(get, set):Float;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var sustainLength(get, never):Float;

	function get_noteType():String
		return n.type;

	function set_noteType(v:String):String
	{
		n.type = v;
		return v;
	}

	function get_mustPress():Bool
		return n.player;

	function get_isSustainNote():Bool
		return false; // as notas daqui são só a cabeça; o corpo do sustain é parte dela

	function set_isSustainNote(v:Bool):Bool
	{
		if (!v)
			n.sustain = 0; // o script quer uma nota simples (ex.: custard)
		return v;
	}

	function get_strumTime():Float
		return n.time;

	function get_noteData():Int
		return n.lane;

	function get_noAnimation():Bool
		return n.noAnim;

	function set_noAnimation(v:Bool):Bool
	{
		n.noAnim = v;
		return v;
	}

	function get_texture():String
		return n.texture;

	function set_texture(v:String):String
	{
		n.texture = v == null ? "" : v;
		return v;
	}

	function get_visible():Bool
		return n.nVisible;

	function set_visible(v:Bool):Bool
	{
		n.nVisible = v;
		return v;
	}

	function get_alpha():Float
		return n.nAlpha;

	function set_alpha(v:Float):Float
	{
		n.nAlpha = v;
		return v;
	}

	// no Psych a nota segue a posição do receptor a cada frame, então mexer em x/y da nota não muda nada
	function get_x():Float
		return 0;

	function set_x(v:Float):Float
		return v;

	function get_y():Float
		return n.yOff;

	function set_y(v:Float):Float
		return v;

	function get_sustainLength():Float
		return n.sustain;
}

/**
 * Camada de compatibilidade com a API Lua do Psych Engine. Só é ativada para scripts Psych
 * (mods com psych.txt, e as pastas custom_events/ e custom_notetypes/). Os scripts FunkForge
 * continuam com a API de ScriptApi.
 *
 * Mapeamento feito de memória sobre o Psych; o que não existe aqui vira no-op em vez de erro.
 */
class PsychLua
{
	/** Converte os argumentos dos callbacks da engine para a assinatura do Psych. null = não chamar. */
	public static function translate(mgr:ScriptManager, fn:String, args:Array<Dynamic>):Null<Array<Dynamic>>
	{
		switch (fn)
		{
			case "goodNoteHit" | "opponentNoteHit" | "noteMiss" | "onSpawnNote":
				var n = mgr.curNote;
				if (n == null)
					return null;
				return [n.id, n.lane, n.type == null ? "" : n.type, false]; // id, direction, noteType, isSustainNote
			case "onKeyPress" | "onCountdown":
				return null;
			default:
				return args;
		}
	}

	/** Constantes globais do Psych visíveis nos scripts. */
	public static function globals():Map<String, Dynamic>
	{
		return [
			"screenWidth" => FlxG.width,
			"screenHeight" => FlxG.height,
			"Function_Stop" => "stop",
			"Function_Continue" => "continue",
			"Function_StopLua" => "stop",
			"Function_StopHScript" => "stop",
			"Function_StopAll" => "stop",
			"luaDebugMode" => false,
			"version" => "0.7.3",
			"isStoryMode" => PlayState.isStory,
			"inGameOver" => false
		];
	}

	/** Variáveis que mudam durante a música (curStep, curBeat...). */
	public static function sync(r:ScriptRunner):Void
	{
		r.set("curStep", Conductor.curStep);
		r.set("curBeat", Conductor.curBeat);
		r.set("curSection", Conductor.curSection);
		r.set("crochet", Conductor.crochet);
		r.set("stepCrochet", Conductor.crochet / 4);
		r.set("botPlay", Settings.d.botplay);
		r.set("cpuControlled", Settings.d.botplay);
	}

	static function hex(v:Dynamic, def:FlxColor = FlxColor.WHITE):FlxColor
	{
		if (v == null)
			return def;
		if (!Std.isOfType(v, String))
			return (v : Int);
		var s = StringTools.trim(cast(v, String));
		s = s.replace("#", "").replace("0x", "").replace("0X", "");
		if (s.length == 6)
			s = "FF" + s;
		var n = Std.parseInt("0x" + s);
		return n == null ? def : (n : FlxColor);
	}

	static function ease(name:String):Float->Float
	{
		if (name == null || name == "")
			return FlxEase.linear;
		var f:Dynamic = Reflect.field(ScriptApi.easeObject(), name);
		return f == null ? FlxEase.linear : f;
	}

	static function fontPath(name:String):Null<String>
	{
		if (name == null)
			return null;
		var real = Paths.find("fonts/" + name);
		if (real == null)
			return null;
		try
		{
			if (!openfl.utils.Assets.cache.hasFont(real))
				openfl.utils.Assets.cache.setFont(real, openfl.text.Font.fromFile(real));
			return real;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function build(g:PlayState, mgr:ScriptManager):Map<String, Dynamic>
	{
		var m = new Map<String, Dynamic>();
		var texts = new Map<String, FlxText>();
		var tweens = new Map<String, FlxTween>();
		var timers = new Map<String, FlxTimer>();
		var warned = new Map<String, Bool>();
		added = new Map();

		// ------------------------------------------------------------ resolução de caminhos
		function camByName(n:String):FlxCamera
		{
			return switch (n)
			{
				case "camHUD" | "hud": g.camHUD;
				case "camOther" | "other": g.camOther;
				default: g.camGame;
			}
		}

		function lookup(name:String):Dynamic
		{
			var s = g.tagged.get(name);
			if (s != null)
				return s;
			var t = texts.get(name);
			if (t != null)
				return t;
			return switch (name)
			{
				case "boyfriend" | "boyfriendGroup": g.boyfriend;
				case "dad" | "dadGroup": g.dad;
				case "gf" | "gfGroup": g.gf;
				case "camGame": g.camGame;
				case "camHUD": g.camHUD;
				case "camOther": g.camOther;
				case "iconP1": g.hud.iconP1;
				case "iconP2": g.hud.iconP2;
				case "healthBar": g.hud.bar;
				case "scoreTxt": g.hud.scoreText;
				case "timeTxt": g.hud.timeTxt;
				case "botplayTxt": g.hud.botplayText;
				case "unspawnNotes" | "notes": g.chart.notes;
				default: null;
			}
		}

		function field(cur:Dynamic, name:String):Dynamic
		{
			var idx = Std.parseInt(name);
			if (idx != null && Std.string(idx) == name)
			{
				if (Std.isOfType(cur, Array))
					return cur[idx];
				var mem:Dynamic = Reflect.getProperty(cur, "members");
				if (mem != null && Std.isOfType(mem, Array))
					return mem[idx];
			}
			if (Std.isOfType(cur, Receptor))
			{
				var r:Receptor = cast cur;
				if (name == "x")
					return r.cx - r.width / 2;
				if (name == "y")
					return r.cy - r.height / 2;
			}
			return Reflect.getProperty(cur, name);
		}

		function resolve(path:String):Dynamic
		{
			var segs = path.split(".");
			var cur:Dynamic = null;
			var i = segs.length;
			while (i >= 1)
			{
				cur = lookup(segs.slice(0, i).join("."));
				if (cur != null)
					break;
				i--;
			}
			if (cur == null)
			{
				cur = Reflect.getProperty(g, segs[0]);
				i = 1;
			}
			for (k in i...segs.length)
			{
				if (cur == null)
					return null;
				cur = field(cur, segs[k]);
			}
			return cur;
		}

		function getOn(owner:Dynamic, name:String):Dynamic
		{
			if (owner == null)
				return null;
			var dot = name.indexOf(".");
			if (dot > 0)
			{
				var first = field(owner, name.substr(0, dot));
				return getOn(first, name.substr(dot + 1));
			}
			return field(owner, name);
		}

		function setOn(owner:Dynamic, name:String, v:Dynamic):Void
		{
			if (owner == null)
				return;
			var dot = name.indexOf(".");
			if (dot > 0)
			{
				setOn(field(owner, name.substr(0, dot)), name.substr(dot + 1), v);
				return;
			}
			if (Std.isOfType(owner, Receptor) && (name == "x" || name == "y"))
			{
				var r:Receptor = cast owner;
				if (name == "x")
					r.setCenter(v + r.width / 2, r.cy);
				else
					r.setCenter(r.cx, v + r.height / 2);
				return;
			}
			Reflect.setProperty(owner, name, v);
		}

		function getProp(path:String):Dynamic
		{
			switch (path)
			{
				case "health":
					return g.judge.health;
				case "defaultCamZoom":
					return g.defaultZoom;
				case "cpuControlled" | "botPlay":
					return Settings.d.botplay;
				case "songLength":
					return g.inst.length;
				case "cameraSpeed" | "playbackRate":
					return 1;
			}
			var i = path.lastIndexOf(".");
			if (i < 0)
			{
				var l = lookup(path);
				return l != null ? l : Reflect.getProperty(g, path);
			}
			// o dono pode ter ponto no nome (tag "forest0.5"): tenta o maior prefixo como objeto
			return getOn(resolve(path.substr(0, i)), path.substr(i + 1));
		}

		function setProp(path:String, v:Dynamic):Void
		{
			switch (path)
			{
				case "health":
					g.judge.health = Math.max(0, Math.min(2, v));
					return;
				case "defaultCamZoom":
					g.defaultZoom = v;
					return;
				case "cpuControlled" | "botPlay":
					return;
				case "showRating" | "showComboNum" | "showCombo" | "cameraSpeed" | "camZooming":
					return;
			}
			var i = path.lastIndexOf(".");
			if (i < 0)
			{
				var l = lookup(path);
				if (l == null)
					Reflect.setProperty(g, path, v);
				return;
			}
			setOn(resolve(path.substr(0, i)), path.substr(i + 1), v);
		}

		function groupItem(group:String, i:Int):Dynamic
		{
			return switch (group)
			{
				case "notes" | "unspawnNotes": (i >= 0 && i < g.chart.notes.length) ? new NoteProxy(g.chart.notes[i]) : null;
				case "opponentStrums": (i >= 0 && i < 4) ? g.receptor(i) : null;
				case "playerStrums": (i >= 0 && i < 4) ? g.receptor(i + 4) : null;
				case "strumLineNotes": (i >= 0 && i < 8) ? g.receptor(i) : null;
				default: null;
			}
		}

		function sprite(tag:String):Null<FlxSprite>
		{
			var o:Dynamic = lookup(tag);
			if (o != null && Std.isOfType(o, FlxSprite))
				return cast o;
			return null;
		}

		// ------------------------------------------------------------ propriedades
		m.set("getProperty", function(path:String):Dynamic return getProp(path));
		m.set("setProperty", function(path:String, value:Dynamic):Void setProp(path, value));
		m.set("getPropertyFromGroup", function(group:String, i:Int, prop:String):Dynamic return getOn(groupItem(group, i), prop));
		m.set("setPropertyFromGroup", function(group:String, i:Int, prop:String, value:Dynamic):Void setOn(groupItem(group, i), prop, value));
		m.set("getPropertyFromClass", function(cls:String, prop:String):Dynamic return null);
		m.set("setPropertyFromClass", function(cls:String, prop:String, value:Dynamic):Void {});

		// ------------------------------------------------------------ sprites
		function place(tag:String, front:Bool):Void
		{
			var s = sprite(tag);
			if (s == null)
				return;
			g.stage.back.remove(s, true);
			g.stage.front.remove(s, true);
			g.remove(s, true);
			var onGame = s.cameras == null || s.cameras.length == 0 || s.cameras[0] == g.camGame;
			if (onGame)
			{
				if (front)
					g.stage.front.add(s);
				else
					g.stage.back.add(s);
			}
			else
				g.add(s);
			added.set(tag, front);
		}

		m.set("makeLuaSprite", function(tag:String, ?image:String, ?x:Float, ?y:Float):Void {
			var old = sprite(tag);
			if (old != null)
				old.destroy();
			var s = new FlxSprite(x == null ? 0 : x, y == null ? 0 : y);
			if (image != null && image != "")
			{
				var gr = Paths.graphic("images/" + image + ".png");
				if (gr != null)
					s.loadGraphic(gr);
			}
			s.antialiasing = Settings.d.antialiasing;
			g.tagged.set(tag, s);
		});
		m.set("makeAnimatedLuaSprite", function(tag:String, ?image:String, ?x:Float, ?y:Float):Void {
			var old = sprite(tag);
			if (old != null)
				old.destroy();
			var s = new FlxSprite(x == null ? 0 : x, y == null ? 0 : y);
			if (image != null && image != "")
			{
				var f = Paths.sparrow("images/" + image);
				if (f == null)
					f = Paths.packer("images/" + image);
				if (f != null)
					s.frames = f;
			}
			s.antialiasing = Settings.d.antialiasing;
			g.tagged.set(tag, s);
		});
		m.set("makeGraphic", function(tag:String, ?w:Int, ?h:Int, ?color:String):Void {
			var s = sprite(tag);
			if (s != null)
				s.makeGraphic(w == null ? 256 : w, h == null ? 256 : h, hex(color, FlxColor.WHITE));
		});
		m.set("addAnimationByPrefix", function(tag:String, name:String, prefix:String, ?fps:Float, ?loop:Bool):Void {
			var s = sprite(tag);
			if (s != null && s.frames != null)
				s.animation.addByPrefix(name, prefix, fps == null ? 24 : Std.int(fps), loop == null ? true : loop);
		});
		m.set("addAnimation", function(tag:String, name:String, frames:Dynamic, ?fps:Float, ?loop:Bool):Void {
			var s = sprite(tag);
			if (s == null)
				return;
			var list:Array<Int> = [];
			if (Std.isOfType(frames, String))
				for (p in cast(frames, String).split(","))
				{
					var v = Std.parseInt(StringTools.trim(p));
					if (v != null)
						list.push(v);
				}
			else if (Std.isOfType(frames, Array))
				for (v in (frames : Array<Dynamic>))
					list.push(Std.int(v));
			s.animation.add(name, list, fps == null ? 24 : Std.int(fps), loop == null ? true : loop);
		});
		m.set("addAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, ?fps:Float, ?loop:Bool):Void {
			var s = sprite(tag);
			if (s == null || s.frames == null)
				return;
			var list:Array<Int> = [];
			for (p in indices.split(","))
			{
				var v = Std.parseInt(StringTools.trim(p));
				if (v != null)
					list.push(v);
			}
			s.animation.addByIndices(name, prefix, list, "", fps == null ? 24 : Std.int(fps), loop == null ? true : loop);
		});
		function playAnim(tag:String, name:String, ?force:Bool, ?reverse:Bool, ?frame:Int):Void
		{
			var o:Dynamic = lookup(tag);
			if (o == null)
				return;
			if (Std.isOfType(o, Character))
			{
				var c:Character = cast o;
				if (c.hasAnim(name))
					c.playAnim(name, force == true, reverse == true, frame == null ? 0 : frame);
			}
			else if (Std.isOfType(o, FlxSprite))
			{
				var s:FlxSprite = cast o;
				if (s.animation.exists(name))
					s.animation.play(name, force == true, reverse == true, frame == null ? 0 : frame);
			}
		}
		m.set("playAnim", playAnim);
		m.set("objectPlayAnimation", playAnim);
		m.set("characterPlayAnim", function(who:String, anim:String, ?force:Bool):Void playAnim(who, anim, force));
		m.set("scaleObject", function(tag:String, x:Float, y:Float, ?updateHitbox:Bool):Void {
			var s = sprite(tag);
			if (s == null)
				return;
			s.scale.set(x, y);
			if (updateHitbox != false)
				s.updateHitbox();
		});
		m.set("setGraphicSize", function(tag:String, ?w:Float, ?h:Float):Void {
			var s = sprite(tag);
			if (s != null)
			{
				s.setGraphicSize(w == null ? 0 : Std.int(w), h == null ? 0 : Std.int(h));
				s.updateHitbox();
			}
		});
		m.set("updateHitbox", function(tag:String):Void {
			var s = sprite(tag);
			if (s != null)
				s.updateHitbox();
		});
		m.set("setScrollFactor", function(tag:String, x:Float, y:Float):Void {
			var o:Dynamic = lookup(tag);
			if (o != null && Std.isOfType(o, FlxSprite))
				cast(o, FlxSprite).scrollFactor.set(x, y);
		});
		m.set("screenCenter", function(tag:String, ?axis:String):Void {
			var o:Dynamic = lookup(tag);
			if (o == null || !Std.isOfType(o, FlxSprite))
				return;
			var s:FlxSprite = cast o;
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
		m.set("setObjectCamera", function(tag:String, ?cam:String):Void {
			var o:Dynamic = lookup(tag);
			if (o == null || !Std.isOfType(o, FlxBasic))
				return;
			cast(o, FlxBasic).cameras = [camByName(cam == null ? "game" : cam)];
			if (added.exists(tag)) // já está na cena: muda de grupo conforme a câmera nova
				place(tag, added.get(tag));
		});
		m.set("addLuaSprite", function(tag:String, ?front:Bool):Void place(tag, front == true));
		m.set("removeLuaSprite", function(tag:String, ?destroy:Bool):Void {
			var s = sprite(tag);
			if (s == null)
				return;
			g.stage.back.remove(s, true);
			g.stage.front.remove(s, true);
			g.stage.gfLayer.remove(s, true);
			g.stage.dadLayer.remove(s, true);
			g.remove(s, true);
			added.remove(tag);
			if (destroy != false)
			{
				g.tagged.remove(tag);
				s.destroy();
			}
		});
		m.set("luaSpriteExists", function(tag:String):Bool return g.tagged.exists(tag));
		m.set("getObjectOrder", function(tag:String):Int {
			var o:Dynamic = lookup(tag);
			if (o == null)
				return 0;
			if (tag == "healthBar" || tag == "iconP1" || tag == "iconP2" || tag == "scoreTxt" || tag == "timeTxt" || tag == "botplayTxt")
				return g.members.indexOf(g.hud);
			var i = g.members.indexOf(o);
			return i < 0 ? 0 : i;
		});
		m.set("setObjectOrder", function(tag:String, order:Int):Void {
			var o:Dynamic = lookup(tag);
			if (o == null || !Std.isOfType(o, FlxBasic))
				return;
			var b:FlxBasic = cast o;
			if (g.members.indexOf(b) >= 0)
			{
				g.remove(b, true);
				g.insert(Std.int(Math.max(0, Math.min(order, g.members.length))), b);
			}
			else
				for (grp in [g.stage.back, g.stage.front])
					if (grp.members.indexOf(b) >= 0)
					{
						grp.remove(b, true);
						grp.insert(Std.int(Math.max(0, Math.min(order, grp.members.length))), b);
						break;
					}
		});
		m.set("setBlendMode", function(tag:String, mode:String):Void {
			var s = sprite(tag);
			if (s != null)
				s.blend = switch (mode.toLowerCase())
				{
					case "add": openfl.display.BlendMode.ADD;
					case "multiply": openfl.display.BlendMode.MULTIPLY;
					case "screen": openfl.display.BlendMode.SCREEN;
					default: openfl.display.BlendMode.NORMAL;
				};
		});
		m.set("precacheImage", function(name:String):Void {
			Paths.graphic("images/" + name + ".png");
		});
		m.set("addCharacterToList", function(name:String, ?type:String):Void {});

		// ------------------------------------------------------------ vídeo (a engine ainda não toca vídeo)
		function noVideo(fn:String):Void
		{
			if (!warned.exists(fn))
			{
				warned.set(fn, true);
				trace("[psych] vídeo ainda não é suportado: " + fn);
			}
		}
		m.set("makeVideoSprite", function(?tag:String, ?file:String, ?x:Float, ?y:Float, ?cam:String, ?loop:Bool):Void noVideo("makeVideoSprite"));
		m.set("playVideoSprite", function(?tag:String):Void noVideo("playVideoSprite"));
		m.set("startVideo", function(?file:String):Void noVideo("startVideo"));

		// ------------------------------------------------------------ textos
		m.set("makeLuaText", function(tag:String, ?text:String, ?width:Float, ?x:Float, ?y:Float):Void {
			var old = texts.get(tag);
			if (old != null)
				old.destroy();
			var t = new FlxText(x == null ? 0 : x, y == null ? 0 : y, width == null ? 0 : width, text == null ? "" : text, 16);
			t.setFormat(Paths.FONT, 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			t.scrollFactor.set();
			texts.set(tag, t);
		});
		m.set("addLuaText", function(tag:String, ?front:Bool):Void {
			var t = texts.get(tag);
			if (t != null)
			{
				g.remove(t, true);
				g.add(t);
			}
		});
		m.set("removeLuaText", function(tag:String, ?destroy:Bool):Void {
			var t = texts.get(tag);
			if (t == null)
				return;
			g.remove(t, true);
			if (destroy != false)
			{
				texts.remove(tag);
				t.destroy();
			}
		});
		m.set("luaTextExists", function(tag:String):Bool return texts.exists(tag));
		m.set("setTextString", function(tag:String, text:String):Void {
			var t = texts.get(tag);
			if (t != null)
				t.text = text;
		});
		m.set("getTextString", function(tag:String):String {
			var t = texts.get(tag);
			return t == null ? "" : t.text;
		});
		m.set("setTextSize", function(tag:String, size:Float):Void {
			var t = texts.get(tag);
			if (t != null)
				t.size = Std.int(size);
		});
		m.set("setTextColor", function(tag:String, color:String):Void {
			var t = texts.get(tag);
			if (t != null)
				t.color = hex(color);
		});
		m.set("setTextFont", function(tag:String, font:String):Void {
			var t:FlxText = texts.get(tag);
			if (t == null && Std.isOfType(lookup(tag), FlxText))
				t = cast lookup(tag);
			if (t == null)
				return;
			var p = fontPath(font);
			if (p != null)
				t.font = p;
		});
		m.set("setTextAlignment", function(tag:String, align:String):Void {
			var t = texts.get(tag);
			if (t != null)
				t.alignment = switch (align)
				{
					case "center": FlxTextAlign.CENTER;
					case "right": FlxTextAlign.RIGHT;
					default: FlxTextAlign.LEFT;
				};
		});
		m.set("setTextBorder", function(tag:String, size:Float, color:String):Void {
			var t:FlxText = texts.get(tag);
			if (t == null && Std.isOfType(lookup(tag), FlxText))
				t = cast lookup(tag);
			if (t == null)
				return;
			if (size <= 0)
				t.borderStyle = FlxTextBorderStyle.NONE;
			else
			{
				t.borderStyle = FlxTextBorderStyle.OUTLINE;
				t.borderSize = size;
				t.borderColor = hex(color, FlxColor.BLACK);
			}
		});
		m.set("setTextWidth", function(tag:String, w:Float):Void {
			var t = texts.get(tag);
			if (t != null)
				t.fieldWidth = w;
		});

		// ------------------------------------------------------------ tweens e timers
		function startTween(tag:String, target:Dynamic, prop:String, value:Float, duration:Float, easeName:String):Void
		{
			if (target == null)
				return;
			var old = tweens.get(tag);
			if (old != null)
				old.cancel();
			var vars:Dynamic = {};
			Reflect.setField(vars, prop, value);
			tweens.set(tag, FlxTween.tween(target, vars, duration, {
				ease: ease(easeName),
				onComplete: function(_) {
					tweens.remove(tag);
					mgr.call("onTweenCompleted", [tag]);
				}
			}));
		}
		for (p in ["x", "y", "alpha", "angle", "zoom"])
		{
			var cap = p.charAt(0).toUpperCase() + p.substr(1);
			m.set("doTween" + cap, function(tag:String, obj:String, value:Float, duration:Float, ?easeName:String):Void {
				startTween(tag, resolve(obj), p, value, duration, easeName);
			});
		}
		m.set("doTweenColor", function(tag:String, obj:String, color:String, duration:Float, ?easeName:String):Void {
			var s = sprite(obj);
			if (s == null)
				return;
			var old = tweens.get(tag);
			if (old != null)
				old.cancel();
			tweens.set(tag, FlxTween.color(s, duration, s.color, hex(color), {
				ease: ease(easeName),
				onComplete: function(_) {
					tweens.remove(tag);
					mgr.call("onTweenCompleted", [tag]);
				}
			}));
		});
		function noteTween(tag:String, i:Int, prop:String, value:Float, duration:Float, easeName:String):Void
		{
			var r = (i >= 0 && i < 8) ? g.receptor(i) : null;
			if (r == null)
				return;
			if (prop == "x" || prop == "y")
			{
				var old = tweens.get(tag);
				if (old != null)
					old.cancel();
				var from = prop == "x" ? r.cx - r.width / 2 : r.cy - r.height / 2;
				tweens.set(tag, FlxTween.num(from, value, duration, {
					ease: ease(easeName),
					onComplete: function(_) {
						tweens.remove(tag);
						mgr.call("onTweenCompleted", [tag]);
					}
				}, function(v:Float) {
					if (prop == "x")
						r.setCenter(v + r.width / 2, r.cy);
					else
						r.setCenter(r.cx, v + r.height / 2);
				}));
			}
			else
				startTween(tag, r, prop, value, duration, easeName);
		}
		for (p in ["x", "y", "alpha", "angle"])
		{
			var cap = p.charAt(0).toUpperCase() + p.substr(1);
			m.set("noteTween" + cap, function(tag:String, i:Int, value:Float, duration:Float, ?easeName:String):Void {
				noteTween(tag, i, p, value, duration, easeName);
			});
		}
		m.set("cancelTween", function(tag:String):Void {
			var t = tweens.get(tag);
			if (t != null)
			{
				t.cancel();
				tweens.remove(tag);
			}
		});
		m.set("runTimer", function(tag:String, ?seconds:Float, ?loops:Int):Void {
			var old = timers.get(tag);
			if (old != null)
				old.cancel();
			timers.set(tag, new FlxTimer().start(seconds == null ? 1 : seconds, function(t:FlxTimer) {
				if (t.finished)
					timers.remove(tag);
				mgr.call("onTimerCompleted", [tag, t.elapsedLoops, t.loopsLeft]);
			}, loops == null ? 1 : loops));
		});
		m.set("cancelTimer", function(tag:String):Void {
			var t = timers.get(tag);
			if (t != null)
			{
				t.cancel();
				timers.remove(tag);
			}
		});

		// ------------------------------------------------------------ jogo
		m.set("getRandomInt", function(min:Int, ?max:Int, ?exclude:String):Int {
			var ex:Array<Int> = [];
			if (exclude != null)
				for (p in exclude.split(","))
				{
					var v = Std.parseInt(StringTools.trim(p));
					if (v != null)
						ex.push(v);
				}
			return FlxG.random.int(min, max == null ? min : max, ex);
		});
		m.set("getRandomFloat", function(min:Float, ?max:Float):Float return FlxG.random.float(min, max == null ? 1 : max));
		m.set("getRandomBool", function(?chance:Float):Bool return FlxG.random.bool(chance == null ? 50 : chance));
		m.set("setHealth", function(v:Float):Void {
			g.judge.health = Math.max(0, Math.min(2, v));
		});
		m.set("getHealth", function():Float return g.judge.health);
		m.set("addHealth", function(v:Float):Void g.judge.addHealth(v));
		m.set("getSongPosition", function():Float return Conductor.songPosition);
		m.set("triggerEvent", function(name:String, ?v1:String, ?v2:String):Void g.runEvent(name, v1 == null ? "" : v1, v2 == null ? "" : v2));
		m.set("restartSong", function(?skip:Bool):Void FlxG.switchState(new PlayState()));
		m.set("exitSong", function(?skip:Bool):Void FlxG.switchState(PlayState.leave()));
		m.set("endSong", function():Void g.endSong());
		m.set("cameraShake", function(cam:String, intensity:Float, duration:Float):Void camByName(cam).shake(intensity, duration));
		m.set("cameraFlash", function(cam:String, color:String, duration:Float, ?force:Bool):Void camByName(cam).flash(hex(color), duration));
		m.set("cameraFade", function(cam:String, color:String, duration:Float, ?force:Bool):Void camByName(cam).fade(hex(color), duration));
		m.set("playSound", function(name:String, ?volume:Float, ?tag:String):Void {
			var s = Paths.sound("sounds/" + name + ".ogg");
			if (s != null)
				FlxG.sound.play(s, volume == null ? 1 : volume);
		});

		// telas customizadas (pausa etc.): ainda não existem; a pausa normal do jogo continua valendo
		m.set("openCustomSubstate", function(?name:String, ?pause:Bool):Void {});
		m.set("closeCustomSubstate", function():Void {});

		// ------------------------------------------------------------ teclado
		function lanePressed(lane:Int):Bool
		{
			var keys:Array<Dynamic> = cast Settings.d.keys[lane];
			return FlxG.keys.anyJustPressed([for (k in keys) (k : FlxKey)]);
		}
		m.set("keyJustPressed", function(name:String):Bool {
			return switch (name)
			{
				case "note_left": lanePressed(0);
				case "note_down": lanePressed(1);
				case "note_up": lanePressed(2);
				case "note_right": lanePressed(3);
				case "ui_left": FlxG.keys.anyJustPressed([LEFT, A]);
				case "ui_down": FlxG.keys.anyJustPressed([DOWN, S]);
				case "ui_up": FlxG.keys.anyJustPressed([UP, W]);
				case "ui_right": FlxG.keys.anyJustPressed([RIGHT, D]);
				case "accept": FlxG.keys.anyJustPressed([ENTER, SPACE]);
				case "back": FlxG.keys.justPressed.ESCAPE;
				case "pause": FlxG.keys.anyJustPressed([ENTER, ESCAPE]);
				case "reset": FlxG.keys.justPressed.R;
				default: false;
			}
		});
		m.set("keyPressed", function(name:String):Bool return false);
		m.set("keyReleased", function(name:String):Bool return false);
		m.set("keyboardJustPressed", function(name:String):Bool {
			var k = FlxKey.fromString(name.toUpperCase());
			return k != FlxKey.NONE && FlxG.keys.anyJustPressed([k]);
		});
		m.set("keyboardPressed", function(name:String):Bool {
			var k = FlxKey.fromString(name.toUpperCase());
			return k != FlxKey.NONE && FlxG.keys.anyPressed([k]);
		});
		m.set("keyboardReleased", function(name:String):Bool {
			var k = FlxKey.fromString(name.toUpperCase());
			return k != FlxKey.NONE && FlxG.keys.anyJustReleased([k]);
		});

		return m;
	}

	/** Sprites já postos na cena por addLuaSprite (tag -> estava "front"). */
	static var added:Map<String, Bool> = new Map();
}
