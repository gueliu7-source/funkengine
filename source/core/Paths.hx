package core;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.display.BitmapData;
import openfl.media.Sound;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Acesso a arquivos. Procura primeiro em mods/<mod ativo>/ e depois em assets/.
 * Tudo é lido pelo sistema de arquivos, então mods e scripts não exigem recompilar.
 * Os caminhos são sempre relativos, ex.: "images/characters/BOYFRIEND.png".
 */
@:keep
class Paths
{
	public static inline var FONT:String = "assets/fonts/vcr.ttf";
	public static inline var PIXEL_FONT:String = "assets/fonts/pixel.otf";

	/** Pasta do mod ativo dentro de mods/ ("" = nenhum). */
	public static var mod:String = "";

	static var graphics:Map<String, FlxGraphic> = new Map();
	static var atlases:Map<String, FlxAtlasFrames> = new Map();
	static var sounds:Map<String, Sound> = new Map();

	/** Devolve o caminho real do arquivo (mod primeiro, depois assets) ou null. */
	public static function find(rel:String):Null<String>
	{
		#if sys
		if (mod != "")
		{
			var m = 'mods/$mod/$rel';
			if (FileSystem.exists(m))
				return m;
		}
		var a = 'assets/$rel';
		if (FileSystem.exists(a))
			return a;
		#end
		return null;
	}

	public static function exists(rel:String):Bool
		return find(rel) != null;

	public static function getText(rel:String):Null<String>
	{
		#if sys
		var p = find(rel);
		return p == null ? null : readFile(p);
		#else
		return null;
		#end
	}

	/** Lê um arquivo de texto removendo o BOM UTF-8 (os XML do Adobe Animate têm). */
	public static function readFile(path:String):String
	{
		#if sys
		var bytes = File.getBytes(path);
		var skip = (bytes.length >= 3 && bytes.get(0) == 0xEF && bytes.get(1) == 0xBB && bytes.get(2) == 0xBF) ? 3 : 0;
		return bytes.getString(skip, bytes.length - skip);
		#else
		return "";
		#end
	}

	public static function graphic(rel:String):Null<FlxGraphic>
	{
		var cached = graphics.get(rel + "|" + mod);
		if (cached != null && cached.bitmap != null)
			return cached;
		var p = find(rel);
		if (p == null)
		{
			trace('[Paths] imagem não encontrada: $rel');
			return null;
		}
		var bd = BitmapData.fromFile(p);
		if (bd == null)
			return null;
		var g = FlxGraphic.fromBitmapData(bd, false, p + "|" + mod);
		g.persist = true;
		graphics.set(rel + "|" + mod, g);
		return g;
	}

	/** Atlas Sparrow. rel sem extensão: "images/characters/BOYFRIEND". */
	public static function sparrow(rel:String):Null<FlxAtlasFrames>
	{
		var key = rel + "|" + mod;
		var cached = atlases.get(key);
		if (cached != null)
			return cached;
		var g = graphic(rel + ".png");
		var xml = getText(rel + ".xml");
		if (g == null || xml == null)
			return null;
		var f = FlxAtlasFrames.fromSparrow(g, xml);
		atlases.set(key, f);
		return f;
	}

	/** Atlas "Packer" (.txt), usado por spirit e weebTrees. */
	public static function packer(rel:String):Null<FlxAtlasFrames>
	{
		var key = rel + "|packer|" + mod;
		var cached = atlases.get(key);
		if (cached != null)
			return cached;
		var g = graphic(rel + ".png");
		var txt = getText(rel + ".txt");
		if (g == null || txt == null)
			return null;
		var f = FlxAtlasFrames.fromSpriteSheetPacker(g, txt);
		atlases.set(key, f);
		return f;
	}

	/** Som curto (efeitos), com cache. rel: "sounds/missnote1.ogg" */
	public static function sound(rel:String):Null<Sound>
	{
		var c = sounds.get(rel + "|" + mod);
		if (c != null)
			return c;
		var s = loadSound(rel);
		if (s != null)
			sounds.set(rel + "|" + mod, s);
		return s;
	}

	/** Som sem cache (músicas grandes). */
	public static function loadSound(rel:String):Null<Sound>
	{
		var p = find(rel);
		if (p == null)
			return null;
		return Sound.fromFile(p);
	}

	public static function song(id:String, track:String):Null<Sound>
		return loadSound('songs/$id/$track.ogg');

	/** Lista nomes de arquivos de uma pasta, juntando mod + assets (sem repetir). */
	public static function list(rel:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var roots = ['assets/$rel'];
		if (mod != "")
			roots.unshift('mods/$mod/$rel');
		for (r in roots)
			if (FileSystem.exists(r) && FileSystem.isDirectory(r))
				for (n in FileSystem.readDirectory(r))
					if (out.indexOf(n) < 0)
						out.push(n);
		#end
		return out;
	}

	/** Nomes das pastas dentro de mods/. */
	public static function listMods():Array<String>
	{
		var out:Array<String> = [];
		#if sys
		if (FileSystem.exists("mods") && FileSystem.isDirectory("mods"))
			for (n in FileSystem.readDirectory("mods"))
				if (FileSystem.isDirectory("mods/" + n))
					out.push(n);
		#end
		return out;
	}

	/** Libera texturas/atlas/sons entre músicas (usa pouca RAM em PCs fracos). */
	public static function clearCache():Void
	{
		for (k in graphics.keys())
		{
			var g = graphics.get(k);
			g.persist = false;
			g.destroyOnNoUse = true;
			FlxG.bitmap.removeByKey(g.key);
		}
		graphics = new Map();
		atlases = new Map();
		sounds = new Map();
	}
}
