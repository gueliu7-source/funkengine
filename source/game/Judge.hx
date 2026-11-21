package game;

import core.Settings;

/**
 * Pontuação, vida, combo e precisão. Valores e fórmulas seguem a Kade Engine 1.8
 * (acurácia Wife3 do Etterna). As constantes de vida ficam aqui para ajustar fácil.
 */
@:keep
class Judge
{
	public static inline var MISS_HEALTH:Float = 0.15;
	public static inline var WRONG_KEY_HEALTH:Float = 0.04;
	public static inline var DROP_HOLD_HEALTH:Float = 0.15;

	public var score:Int = 0;
	public var combo:Int = 0;
	public var maxCombo:Int = 0;
	public var misses:Int = 0;
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0;
	public var health:Float = 1; // 0..2
	public var totalHit:Float = 0;
	public var totalPlayed:Int = 0;

	public var accuracy(get, never):Float;
	public var rank(get, never):String;

	public function new()
	{
	}

	public function ratingFor(absMs:Float):String
	{
		if (absMs < Settings.d.sickMs)
			return "sick";
		if (absMs < Settings.d.goodMs)
			return "good";
		if (absMs < Settings.d.badMs)
			return "bad";
		return "shit";
	}

	/** Registra um acerto. diffMs = tempo da nota - tempo do toque. Devolve o rating. */
	public function registerHit(diffMs:Float):String
	{
		var abs = Math.abs(diffMs);
		var r = ratingFor(abs);
		var ts = Settings.d.shitMs / 166;

		combo++;
		totalPlayed++;
		totalHit += wife3(abs, ts);

		switch (r)
		{
			case "shit":
				score -= 300;
				combo = 0;
				misses++;
				shits++;
				health -= 0.1;
			case "bad":
				score += 0;
				bads++;
				health -= 0.06;
			case "good":
				score += 200;
				goods++;
			default:
				score += 350;
				sicks++;
				if (health < 2)
					health += 0.04;
		}
		if (combo > maxCombo)
			maxCombo = combo;
		clampHealth();
		return r;
	}

	public function registerMiss(healthLoss:Float):Void
	{
		combo = 0;
		misses++;
		totalPlayed++;
		totalHit -= 1;
		score -= 10;
		health -= healthLoss;
		clampHealth();
	}

	/** Toque na tecla errada (ghost tapping desligado): pune sem contar como nota. */
	public function registerWrongKey():Void
	{
		combo = 0;
		misses++;
		score -= 10;
		health -= WRONG_KEY_HEALTH;
		clampHealth();
	}

	public inline function addHealth(v:Float):Void
	{
		health += v;
		clampHealth();
	}

	inline function clampHealth():Void
	{
		if (health > 2)
			health = 2;
		if (health < 0)
			health = 0;
	}

	function get_accuracy():Float
	{
		if (totalPlayed == 0)
			return 0;
		var a = totalHit / totalPlayed * 100;
		return a < 0 ? 0 : a;
	}

	function get_rank():String
	{
		if (totalPlayed == 0)
			return "N/A";
		var fc = "";
		if (misses == 0 && bads == 0 && shits == 0 && goods == 0)
			fc = "(MFC) ";
		else if (misses == 0 && bads == 0 && shits == 0)
			fc = "(GFC) ";
		else if (misses == 0)
			fc = "(FC) ";
		else if (misses < 10)
			fc = "(SDCB) ";
		else
			fc = "(Clear) ";

		var acc = accuracy;
		var letters:Array<Array<Dynamic>> = [
			[99.9935, "AAAAA"], [99.980, "AAAA:"], [99.970, "AAAA."], [99.955, "AAAA"], [99.90, "AAA:"], [99.80, "AAA."], [99.70, "AAA"],
			[99, "AA:"], [96.50, "AA."], [93, "AA"], [90, "A:"], [85, "A."], [80, "A"], [70, "B"], [60, "C"], [0, "D"]
		];
		for (l in letters)
			if (acc >= (l[0] : Float))
				return fc + (l[1] : String);
		return fc + "D";
	}

	/** Pontuação de precisão Wife3 (Etterna): 1 = perfeito, negativo = miss. */
	public static function wife3(maxms:Float, ts:Float):Float
	{
		var maxPoints = 1.0;
		var missWeight = -5.5;
		var ridic = 5 * ts;
		var maxBoo = 166 * ts;
		var zero = 65 * Math.pow(ts, 0.75);
		var dev = 22.7 * Math.pow(ts, 0.75);
		if (maxms <= ridic)
			return maxPoints;
		else if (maxms <= zero)
			return maxPoints * erf((zero - maxms) / dev);
		else if (maxms <= maxBoo)
			return (maxms - zero) * missWeight / (maxBoo - zero);
		return missWeight;
	}

	/** Aproximação da função erro (Abramowitz-Stegun 7.1.26). */
	static function erf(x:Float):Float
	{
		var sign = x < 0 ? -1.0 : 1.0;
		x = Math.abs(x);
		var t = 1.0 / (1.0 + 0.3275911 * x);
		var y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x);
		return sign * y;
	}
}
