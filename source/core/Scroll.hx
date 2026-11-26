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
	/** A velocidade é sempre a do chart (e dos eventos); não há mais modos nas Opções. */
	public static inline function effective(base:Float):Float
		return base;

	public static inline function eventsApply():Bool
		return true;

	public static function modeName():String
		return "do chart";

	public static function describe():String
		return "Do chart";

	public static function fmt(v:Float):String
		return Std.string(Math.round(v * 100) / 100);
}
