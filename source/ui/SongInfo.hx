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
			var ch = core.Chart.ChartLoader.load(id, "");
			if (ch == null)
				ch = core.Chart.ChartLoader.load(id, "-hard");
			if (ch != null)
			{
				var p2 = ch.player2;
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
