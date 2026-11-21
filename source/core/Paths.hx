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

/** Uma raiz de arquivos (mods/<mod>, mods ou assets) com o índice dela, montado uma vez só. */
typedef Root =
{
	var path:String;
	var files:Map<String, Bool>; // caminho relativo -> existe
	var dirs:Map<String, Array<String>>; // pasta relativa ("" = raiz) -> nomes dentro dela
}

/**
 * Acesso a arquivos no estilo Psych/Codename. Ordem de prioridade (a primeira que tiver o arquivo vence):
 *   1. mods/<mod ativo>/   (na ordem definida na tela de mods; o de cima vence)
 *   2. mods/               (arquivos globais, fora de pasta de mod)
 *   3. assets/
 * Cada raiz é varrida uma única vez em rebuild(), então find()/exists() não tocam no disco.
 * Tudo é lido pelo sistema de arquivos, então mods e scripts não exigem recompilar.
 * Os caminhos são sempre relativos, ex.: "images/characters/BOYFRIEND.png".
 */
@:keep
class Paths
{
	public static inline var FONT:String = "assets/fonts/vcr.ttf";
	public static inline var PIXEL_FONT:String = "assets/fonts/pixel.otf";

	/** Identifica o conjunto de mods ativo; entra na chave dos caches. */
	public static var stamp:String = "";

	static var roots:Array<Root> = [];

	static var graphics:Map<String, FlxGraphic> = new Map();
	static var atlases:Map<String, FlxAtlasFrames> = new Map();
	static var sounds:Map<String, Sound> = new Map();

	/** Monta as raízes e o índice. enabled = mods ativos, do de maior prioridade ao de menor. */
	public static function rebuild(enabled:Array<String>):Void
	{
		roots = [];
		stamp = enabled.join(",");
		#if sys
		var all = ModManager.folderNames();
		for (m in enabled)
			if (all.indexOf(m) >= 0)
				addRoot("mods/" + m, null);
		if (FileSystem.exists("mods"))
			addRoot("mods", all); // globais: ignora as pastas de mod
		addRoot("assets", null);
		#end
	}

	#if sys
	static function addRoot(path:String, skipTop:Null<Array<String>>):Void
	{
		if (!FileSystem.exists(path))
			return;
		var r:Root = {path: path, files: new Map(), dirs: new Map()};
		scan(r, "", skipTop);
		roots.push(r);
	}

	static function scan(r:Root, sub:String, skip:Null<Array<String>>):Void
	{
		var full = sub == "" ? r.path : r.path + "/" + sub;
		var names:Array<String> = [];
		for (n in FileSystem.readDirectory(full))
		{
			if (n.charAt(0) == "." || (skip != null && sub == "" && skip.indexOf(n) >= 0))
				continue;
			names.push(n);
			var rel = sub == "" ? n : sub + "/" + n;
			if (FileSystem.isDirectory(full + "/" + n))
				scan(r, rel, null);
			else
				r.files.set(rel, true);
		}
		r.dirs.set(sub, names);
	}
	#end

	/** Devolve o caminho real do arquivo (mod primeiro, depois assets) ou null. */
	public static function find(rel:String):Null<String>
	{
		for (r in roots)
			if (r.files.exists(rel))
				return r.path + "/" + rel;
		return null;
	}

	/** Todas as versões de um arquivo, da menor para a maior prioridade (para juntar listas e scripts). */
	public static function findAll(rel:String):Array<String>
	{
		var out:Array<String> = [];
		var i = roots.length - 1;
		while (i >= 0)
		{
			if (roots[i].files.exists(rel))
				out.push(roots[i].path + "/" + rel);
			i--;
		}
		return out;
	}

	/** Arquivos de uma pasta em TODAS as raízes (caminhos reais), da menor para a maior prioridade. */
	public static function listAll(dir:String):Array<String>
	{
		var out:Array<String> = [];
		var i = roots.length - 1;
		while (i >= 0)
		{
			var names = roots[i].dirs.get(dir);
			if (names != null)
				for (n in names)
					if (roots[i].files.exists(dir + "/" + n))
						out.push(roots[i].path + "/" + dir + "/" + n);
			i--;
		}
		return out;
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
		var cached = graphics.get(rel + "|" + stamp);
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
		var g = FlxGraphic.fromBitmapData(bd, false, p + "|" + stamp);
		g.persist = true;
		graphics.set(rel + "|" + stamp, g);
		return g;
	}

	/** Atlas Sparrow. rel sem extensão: "images/characters/BOYFRIEND". */
	public static function sparrow(rel:String):Null<FlxAtlasFrames>
	{
		var key = rel + "|" + stamp;
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
		var key = rel + "|packer|" + stamp;
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
		var c = sounds.get(rel + "|" + stamp);
		if (c != null)
			return c;
		var s = loadSound(rel);
		if (s != null)
			sounds.set(rel + "|" + stamp, s);
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

	/** Nomes dentro de uma pasta, juntando mods + assets (sem repetir). */
	public static function list(rel:String):Array<String>
	{
		var out:Array<String> = [];
		for (r in roots)
		{
			var names = r.dirs.get(rel);
			if (names != null)
				for (n in names)
					if (out.indexOf(n) < 0)
						out.push(n);
		}
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
