package core;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef ModInfo =
{
	var id:String; // nome da pasta em mods/
	var name:String;
	var description:String;
	var author:String;
	var version:String;
	var color:Int; // 0xAARRGGBB
	var enabled:Bool;
}

/**
 * Lista os mods de mods/<pasta>/ (cada um com um pack.json opcional) e guarda quais estão ativos e em que ordem.
 * pack.json: { "name": "...", "description": "...", "author": "...", "version": "1.0", "color": "#FF66AA" }
 */
@:keep
class ModManager
{
	/** Todos os mods encontrados: ativos primeiro (na ordem de prioridade), depois os desativados. */
	public static var mods:Array<ModInfo> = [];

	/** Chamado uma vez no início (depois de Settings.load). */
	public static function init():Void
	{
		scan();
		Paths.rebuild(enabledIds());
	}

	public static function folderNames():Array<String>
	{
		var out:Array<String> = [];
		#if sys
		if (FileSystem.exists("mods") && FileSystem.isDirectory("mods"))
			for (n in FileSystem.readDirectory("mods"))
				if (n.charAt(0) != "." && FileSystem.isDirectory("mods/" + n))
					out.push(n);
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		#end
		return out;
	}

	public static function scan():Void
	{
		var folders = folderNames();
		var saved:Array<String> = Settings.d.enabledMods;
		var ordered:Array<ModInfo> = [];
		for (id in saved)
			if (folders.indexOf(id) >= 0)
				ordered.push(read(id, true));
		for (id in folders)
			if (saved.indexOf(id) < 0)
				ordered.push(read(id, false));
		mods = ordered;
	}

	static function read(id:String, enabled:Bool):ModInfo
	{
		var info:ModInfo = {
			id: id,
			name: id,
			description: "",
			author: "",
			version: "",
			color: 0xFFFFFFFF,
			enabled: enabled
		};
		#if sys
		var p = 'mods/$id/pack.json';
		if (FileSystem.exists(p))
		{
			try
			{
				var j:Dynamic = Json.parse(Paths.readFile(p));
				if (j.name != null)
					info.name = Std.string(j.name);
				if (j.description != null)
					info.description = Std.string(j.description);
				if (j.author != null)
					info.author = Std.string(j.author);
				if (j.version != null)
					info.version = Std.string(j.version);
				if (j.color != null)
				{
					info.color = core.Hex.color(Std.string(j.color), info.color);
				}
			}
			catch (e:Dynamic)
			{
				trace('[ModManager] pack.json inválido em $id: $e');
			}
		}
		#end
		return info;
	}

	public static function enabledIds():Array<String>
	{
		var out:Array<String> = [];
		for (m in mods)
			if (m.enabled)
				out.push(m.id);
		return out;
	}

	/** Move o mod i uma posição (dir -1 = mais prioridade). Devolve o novo índice. */
	public static function move(i:Int, dir:Int):Int
	{
		var j = i + dir;
		if (j < 0 || j >= mods.length)
			return i;
		var t = mods[i];
		mods[i] = mods[j];
		mods[j] = t;
		return j;
	}

	/** Mantém os ativos antes dos desativados (a ordem entre eles é a prioridade). */
	public static function normalize():Void
	{
		var on = mods.filter(function(m) return m.enabled);
		var off = mods.filter(function(m) return !m.enabled);
		mods = on.concat(off);
	}

	/**
	 * Pasta onde os editores salvam: o mod ativo de maior prioridade. Se não houver nenhum,
	 * cria e ativa o mod "editor" (sem limpar o cache, para não derrubar as texturas em uso).
	 */
	public static function saveRoot():String
	{
		var on = enabledIds();
		if (on.length > 0)
			return "mods/" + on[0];
		#if sys
		if (!FileSystem.exists("mods/editor"))
		{
			mkdirs("mods/editor");
			File.saveContent("mods/editor/pack.json",
				'{ "name": "Editor", "description": "Criado pelos editores do FunkForge", "author": "", "version": "1.0", "color": "#FFB347" }');
		}
		scan();
		for (m in mods)
			if (m.id == "editor")
				m.enabled = true;
		normalize();
		Settings.d.enabledMods = enabledIds();
		Settings.flush();
		Paths.rebuild(Settings.d.enabledMods);
		#end
		return "mods/editor";
	}

	/** Cria a pasta e as pais dela. */
	public static function mkdirs(path:String):Void
	{
		#if sys
		var cur = "";
		for (part in path.split("/"))
		{
			cur = cur == "" ? part : cur + "/" + part;
			if (!FileSystem.exists(cur))
				FileSystem.createDirectory(cur);
		}
		#end
	}

	/** Salva a escolha e reindexa os arquivos. Libera o cache para não misturar texturas de mods diferentes. */
	public static function apply():Void
	{
		normalize();
		Settings.d.enabledMods = enabledIds();
		Settings.flush();
		Paths.clearCache();
		Paths.rebuild(Settings.d.enabledMods);
	}
}
