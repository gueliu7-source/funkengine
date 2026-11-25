package core;

import flixel.util.FlxSave;
import game.Judge;

typedef ScoreRec =
{
	var score:Int;
	var accuracy:Float;
	var rank:String;
	var maxCombo:Int;
	var misses:Int;
	var sicks:Int;
	var goods:Int;
	var bads:Int;
	var shits:Int;
}

/** Melhor resultado por música e dificuldade (salvo em "scores"). */
class Scores
{
	static var save:FlxSave;

	static function box():Dynamic
	{
		if (save == null)
		{
			save = new FlxSave();
			save.bind("scores", "FunkForge");
		}
		if (save.data.best == null)
			save.data.best = {};
		return save.data.best;
	}

	static inline function key(song:String, diff:String):String
		return song + "|" + diff;

	public static function best(song:String, diff:String):Null<ScoreRec>
		return Reflect.field(box(), key(song, diff));

	/** Guarda se for melhor que o anterior (por pontuação). */
	public static function submit(song:String, diff:String, j:Judge):Void
	{
		if (j.totalPlayed == 0)
			return;
		var old = best(song, diff);
		if (old != null && old.score >= j.score)
			return;
		var rec:ScoreRec = {
			score: j.score,
			accuracy: j.accuracy,
			rank: j.rank,
			maxCombo: j.maxCombo,
			misses: j.misses,
			sicks: j.sicks,
			goods: j.goods,
			bads: j.bads,
			shits: j.shits
		};
		Reflect.setField(box(), key(song, diff), rec);
		save.flush();
	}
}
