package ui;

import core.Paths;
import game.Character;

/** Dados rápidos de uma música para o Freeplay (sem carregar o chart inteiro). */
class SongInfo
{
	static var cache:Map<String, String> = new Map();

	/** Nome do ícone do oponente (player2 do chart → healthicon do personagem). */
	public static function opponentIcon(id:String):String
	{
		var c = cache.get(id);
		if (c != null)
			return c;
		var icon = "face";
		try
		{
			var text:String = null;
			for (s in ["", "-hard", "-easy"])
				if (text == null)
					text = Paths.getText('data/songs/$id/$id$s.json');
			if (text != null)
			{
				var j:Dynamic = haxe.Json.parse(core.Chart.ChartLoader.extractJson(text));
				var s:Dynamic = Reflect.field(j, "song") != null && !Std.isOfType(Reflect.field(j, "song"), String) ? Reflect.field(j, "song") : j;
				var p2:String = Reflect.field(s, "player2") != null ? Std.string(Reflect.field(s, "player2")) : "dad";
				icon = p2;
				var ct = Paths.getText('data/characters/$p2.json');
				if (ct != null)
				{
					var def = Character.parseDef(ct, p2);
					if (def.icon != null)
						icon = def.icon;
				}
			}
		}
		catch (e:Dynamic)
			trace("[SongInfo] " + id + ": " + e);
		cache.set(id, icon);
		return icon;
	}
}
