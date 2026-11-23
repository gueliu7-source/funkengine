package editor.character;

import core.ModManager;
import core.Paths;
import core.Settings;
import game.Character.AnimDef;
import game.Character.CharDef;
import haxe.Json;
#if sys
import sys.io.File;
#end

using StringTools;

/** Uma animação do personagem como o editor a enxerga (indices e offsets viram campos simples). */
typedef EAnim =
{
	var name:String;
	var prefix:String;
	var fps:Int;
	var loop:Bool;
	var indices:String; // "0,1,2" ou ""
	var ox:Float;
	var oy:Float;
}

private typedef Snap =
{
	var before:String;
	var after:String;
	var name:String;
}

/**
 * Documento do personagem: dados + desfazer/refazer. Mesmo padrão do StageDoc (edit() = uma ação; begin()/end() = arrasto).
 * Salva em mods/<mod ativo>/data/characters/<id>.json, o mesmo arquivo que o jogo, o Chart Editor e o Stage Editor leem.
 */
class CharDoc
{
	public var id:String;
	public var asset:String = "characters/BOYFRIEND";
	public var packer:Bool = false;
	public var barColor:String = "#31B0D1";
	public var icon:String = "face";
	public var flipX:Bool = false;
	public var swapSides:Bool = true;
	public var scale:Float = 1;
	public var aa:Bool = true;
	public var singDuration:Float = 4;
	public var danceEvery:Int = 2;
	public var danceLR:Bool = false;
	public var camX:Float = 150;
	public var camY:Float = -100;
	public var anims:Array<EAnim> = [];
	public var version:Int = 0;
	public var dirty:Bool = false;
	public var isNew:Bool = false;

	var raw:Dynamic = {};
	var undoS:Array<Snap> = [];
	var redoS:Array<Snap> = [];
	var pending:Null<String>;

	public var canUndo(get, never):Bool;
	public var canRedo(get, never):Bool;

	function get_canUndo():Bool
		return undoS.length > 0;

	function get_canRedo():Bool
		return redoS.length > 0;

	public function new(id:String)
	{
		this.id = id;
	}

	// ------------------------------------------------------------------ carregar / salvar

	public static function load(id:String):CharDoc
	{
		var d = new CharDoc(id);
		var text = Paths.getText('data/characters/$id.json');
		if (text == null)
		{
			d.isNew = true;
			d.dirty = true;
			return d;
		}
		var j:Dynamic = Json.parse(text);
		d.raw = j;
		if (j.asset != null)
			d.asset = j.asset;
		d.packer = j.packer == true;
		if (j.barColor != null)
			d.barColor = j.barColor;
		if (j.icon != null)
			d.icon = j.icon;
		d.flipX = j.flipX == true;
		d.swapSides = j.swapSides != false;
		d.scale = j.scale != null ? j.scale : 1;
		d.aa = j.antialiasing != false;
		d.singDuration = j.singDuration != null ? j.singDuration : 4;
		d.danceEvery = j.danceEvery != null ? Std.int(j.danceEvery) : 2;
		d.danceLR = j.danceLR == true;
		if (j.camOffset != null)
		{
			var c:Array<Float> = j.camOffset;
			d.camX = c[0];
			d.camY = c[1];
		}
		var list:Array<Dynamic> = j.animations;
		if (list != null)
			for (a in list)
				d.anims.push(fromJson(a));
		return d;
	}

	static function fromJson(a:Dynamic):EAnim
	{
		var off:Array<Float> = a.offsets;
		var idx:Array<Int> = a.indices;
		return {
			name: a.name,
			prefix: a.prefix != null ? a.prefix : "",
			fps: a.fps != null ? Std.int(a.fps) : 24,
			loop: a.loop == true,
			indices: idx != null ? idx.join(",") : "",
			ox: off != null && off.length >= 2 ? off[0] : 0,
			oy: off != null && off.length >= 2 ? off[1] : 0
		};
	}

	static function parseIndices(s:String):Array<Int>
	{
		var out:Array<Int> = [];
		for (p in s.split(","))
		{
			var n = Std.parseInt(p.trim());
			if (n != null)
				out.push(n);
		}
		return out;
	}

	static function round(v:Float):Float
		return Math.round(v * 100) / 100;

	/** A mesma estrutura que o jogo lê (usada também para pré-visualizar sem salvar). */
	public function toDef():CharDef
	{
		var list:Array<AnimDef> = [];
		for (a in anims)
		{
			var d:AnimDef = {
				name: a.name,
				prefix: a.prefix,
				fps: a.fps,
				loop: a.loop,
				offsets: [round(a.ox), round(a.oy)]
			};
			var ix = parseIndices(a.indices);
			if (ix.length > 0)
				d.indices = ix;
			list.push(d);
		}
		var def:CharDef = {
			name: id,
			asset: asset,
			animations: list,
			packer: packer,
			barColor: barColor,
			icon: icon,
			flipX: flipX,
			swapSides: swapSides,
			scale: scale,
			antialiasing: aa,
			singDuration: singDuration,
			danceEvery: danceEvery,
			danceLR: danceLR,
			camOffset: [camX, camY]
		};
		return def;
	}

	/** Cópia de outro personagem com um id novo (ponto de partida para criar um personagem). */
	public static function copyOf(src:String, newId:String):CharDoc
	{
		var d = load(src);
		d.id = newId;
		d.raw = {};
		d.isNew = true;
		d.dirty = true;
		return d;
	}

	public function savePath():String
		return ModManager.saveRoot() + '/data/characters/$id.json';

	/** Caminho salvo, ou null em erro. */
	public function save():Null<String>
	{
		#if sys
		try
		{
			var path = savePath();
			ModManager.mkdirs(path.substr(0, path.lastIndexOf("/")));
			var out:Dynamic = {};
			for (f in Reflect.fields(raw)) // preserva campos que o editor não conhece
				Reflect.setField(out, f, Reflect.field(raw, f));
			var def = toDef();
			for (f in Reflect.fields(def))
				Reflect.setField(out, f, Reflect.field(def, f));
			if (!packer)
				Reflect.deleteField(out, "packer");
			File.saveContent(path, Json.stringify(out, null, "  "));
			raw = out;
			Paths.rebuild(Settings.d.enabledMods);
			dirty = false;
			isNew = false;
			return path;
		}
		catch (e:Dynamic)
		{
			trace('[CharDoc] erro ao salvar: $e');
			return null;
		}
		#else
		return null;
		#end
	}

	// ------------------------------------------------------------------ atlas

	/** Prefixos de animação encontrados no atlas (nomes dos quadros sem o número final). */
	public function atlasPrefixes():Array<String>
	{
		var out:Array<String> = [];
		var txt = Paths.getText("images/" + asset + (packer ? ".txt" : ".xml"));
		if (txt == null)
			return out;
		var re = packer ? ~/^\s*(.+?)\s*=\s*\d+/ : ~/name="([^"]+)"/;
		var strip = ~/[0-9]+$/;
		for (line in txt.split("\n"))
			if (re.match(line))
			{
				var n = strip.replace(re.matched(1), "");
				if (n != "" && out.indexOf(n) < 0)
					out.push(n);
			}
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	public function animByName(n:String):Null<EAnim>
	{
		for (a in anims)
			if (a.name == n)
				return a;
		return null;
	}

	public function uniqueName(base:String):String
	{
		if (animByName(base) == null)
			return base;
		var i = 2;
		while (animByName(base + i) != null)
			i++;
		return base + i;
	}

	// ------------------------------------------------------------------ desfazer

	function snapshot():String
		return Json.stringify({
			asset: asset,
			packer: packer,
			barColor: barColor,
			icon: icon,
			flipX: flipX,
			swapSides: swapSides,
			scale: scale,
			aa: aa,
			singDuration: singDuration,
			danceEvery: danceEvery,
			danceLR: danceLR,
			camX: camX,
			camY: camY,
			anims: anims
		});

	function restore(s:String):Void
	{
		var j:Dynamic = Json.parse(s);
		asset = j.asset;
		packer = j.packer;
		barColor = j.barColor;
		icon = j.icon;
		flipX = j.flipX;
		swapSides = j.swapSides;
		scale = j.scale;
		aa = j.aa;
		singDuration = j.singDuration;
		danceEvery = j.danceEvery;
		danceLR = j.danceLR;
		camX = j.camX;
		camY = j.camY;
		var list:Array<Dynamic> = j.anims;
		anims = [for (a in list) (cast a : EAnim)];
		version++;
		dirty = true;
	}

	public function begin():Void
	{
		if (pending == null)
			pending = snapshot();
	}

	public function end(label:String):Void
	{
		if (pending == null)
			return;
		var after = snapshot();
		if (after != pending)
		{
			undoS.push({before: pending, after: after, name: label});
			redoS = [];
			dirty = true;
			version++;
		}
		pending = null;
	}

	public var editing(get, never):Bool;

	function get_editing():Bool
		return pending != null;

	public function edit(label:String, fn:Void->Void):Void
	{
		begin();
		fn();
		end(label);
	}

	public function undo():Null<String>
	{
		if (undoS.length == 0)
			return null;
		var s = undoS.pop();
		restore(s.before);
		redoS.push(s);
		return s.name;
	}

	public function redo():Null<String>
	{
		if (redoS.length == 0)
			return null;
		var s = redoS.pop();
		restore(s.after);
		undoS.push(s);
		return s.name;
	}
}
