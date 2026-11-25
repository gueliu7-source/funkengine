package core;

/** Onde ficam os charts: data/songs/<id>/<id><dif>.ffc (formato novo) ou .json (Psych/Kade/funkforge-2). O .ffc tem prioridade. */
class ChartFiles
{
	public static function text(id:String, suffix:String):Null<String>
	{
		for (ext in ["ffc", "json"])
		{
			var t = Paths.getText('data/songs/$id/$id$suffix.$ext');
			if (t != null)
				return t;
		}
		return null;
	}

	public static function exists(id:String, suffix:String):Bool
		return Paths.exists('data/songs/$id/$id$suffix.ffc') || Paths.exists('data/songs/$id/$id$suffix.json');
}
