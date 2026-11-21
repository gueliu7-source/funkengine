package hud;

import core.Paths;
import core.Settings;
import flixel.FlxSprite;

/**
 * Ícone de vida. Aceita 2 frames (normal / perdendo) ou 3 (normal / perdendo / ganhando).
 * A escala sempre volta suavemente para 1, venha ela de cima (pulso) ou de baixo (encolhida),
 * e o resultado não depende do FPS.
 */
class HealthIcon extends FlxSprite
{
	public var isPlayer:Bool;

	var frameCount:Int = 2;

	public function new(name:String, isPlayer:Bool)
	{
		super();
		this.isPlayer = isPlayer;
		moves = false;
		scrollFactor.set();

		var g = Paths.graphic('images/icons/icon-$name.png');
		if (g == null)
			g = Paths.graphic("images/icons/icon-face.png");
		if (g != null)
		{
			frameCount = (g.width / g.height >= 2.5) ? 3 : 2;
			loadGraphic(g, true, Std.int(g.width / frameCount), Std.int(g.height));
			animation.add("i", [for (i in 0...frameCount) i], 0, false);
			animation.play("i");
		}
		flipX = isPlayer;
		antialiasing = Settings.d.antialiasing && name.indexOf("pixel") < 0 && name != "senpai" && name != "spirit";
	}

	/** 0 = normal, 1 = perdendo, 2 = ganhando (cai no normal se o ícone só tem 2 frames). */
	public inline function setState(s:Int):Void
		animation.frameIndex = (s == 2 && frameCount < 3) ? 0 : s;

	public inline function setLosing(losing:Bool):Void
		setState(losing ? 1 : 0);

	/** Pulso da batida. */
	public inline function bump():Void
		scale.set(1.2, 1.2);

	/** Empurra a escala para `to` (>1 aumenta, <1 encolhe) sem diminuir um efeito que já está maior. */
	public function kick(to:Float):Void
	{
		if (to >= 1 ? scale.x < to : scale.x > to)
			scale.set(to, to);
	}

	/** Volta a escala para 1 de forma suave (independente do FPS). */
	public function settle(elapsed:Float):Void
	{
		var k = Math.exp(-elapsed * 9);
		var s = 1 + (scale.x - 1) * k;
		scale.set(s, s);
	}
}
