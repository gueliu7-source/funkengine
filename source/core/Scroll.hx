package core;

/**
 * Velocidade de rolagem das notas, num só lugar. Modos (Opções):
 *  0 = chart: usa a velocidade do chart e obedece aos eventos "Change Scroll Speed";
 *  1 = fixa: sempre Settings.d.scrollSpeed (ignora chart e eventos);
 *  2 = multiplicador: (chart ou evento) × Settings.d.scrollMult.
 * Em pixels por ms a velocidade vale 0.45 × velocidade (ver Strumline.setSpeed).
 */
class Scroll
{
	/** Velocidade efetiva para uma velocidade base (a do chart, ou chart × evento). */
	public static function effective(base:Float):Float
	{
		return switch (Settings.d.scrollMode)
		{
			case 1: Settings.d.scrollSpeed;
			case 2: base * Settings.d.scrollMult;
			default: base;
		}
	}

	/** Os eventos de mudança de velocidade valem? (não no modo fixo) */
	public static inline function eventsApply():Bool
		return Settings.d.scrollMode != 1;

	public static function modeName():String
		return switch (Settings.d.scrollMode)
		{
			case 1: "fixa";
			case 2: "multiplicador";
			default: "do chart";
		}

	public static function describe():String
		return switch (Settings.d.scrollMode)
		{
			case 1: "Fixa " + fmt(Settings.d.scrollSpeed);
			case 2: "Chart × " + fmt(Settings.d.scrollMult);
			default: "Do chart";
		}

	public static function fmt(v:Float):String
		return Std.string(Math.round(v * 100) / 100);
}
