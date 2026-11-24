package ui;

import core.Paths;
import haxe.Json;

typedef SongEntry =
{
	var id:String;
	var name:String;
	var week:Int;
}

/** Lista de músicas (data/songs.json de assets/ e dos mods) usada pelo Freeplay e pelo Story Mode. */
class SongList
{
	public static final DIFF_SUFFIX:Array<String> = ["-easy", "", "-hard"];
	public static final DIFF_NAME:Array<String> = ["EASY", "NORMAL", "HARD"];

	/** Junta os songs.json; pastas de música sem entrada entram com o nome da pasta. */
	public static function load():Array<SongEntry>
	{
		var songs:Array<SongEntry> = [];
		var seen:Map<String, Bool> = new Map();
		for (file in Paths.findAll("data/songs.json"))
		{
			try
			{
				var arr:Array<Dynamic> = Json.parse(Paths.readFile(file)).songs;
				for (s in arr)
				{
					var id:String = Std.string(s.id);
					if (seen.exists(id) || !hasAny(id))
						continue;
					seen.set(id, true);
					var w:Dynamic = Reflect.field(s, "week");
					var nm:Dynamic = Reflect.field(s, "name");
					songs.push({id: id, name: nm != null ? Std.string(nm) : id, week: w != null ? Std.int(w) : 0});
				}
			}
			catch (e:Dynamic)
				trace('[SongList] songs.json inválido em $file: $e');
		}
		var extra = Paths.list("data/songs");
		extra.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		for (id in extra)
			if (!seen.exists(id) && hasAny(id))
			{
				seen.set(id, true);
				songs.push({id: id, name: id, week: 0});
			}
		return songs;
	}

	/** A música tem chart em alguma dificuldade (alguns mods só trazem o -hard). */
	public static function hasAny(id:String):Bool
	{
		for (s in DIFF_SUFFIX)
			if (Paths.exists('data/songs/$id/$id$s.json'))
				return true;
		return false;
	}

	public static function hasDiff(id:String, diff:Int):Bool
		return Paths.exists('data/songs/$id/$id${DIFF_SUFFIX[diff]}.json');
}
