package hud;

import core.Paths;
import core.Settings;
import flixel.FlxSprite;

/** Ícone de vida (2 frames: normal / perdendo). Pulsa na batida sem alocar nada. */
class HealthIcon extends FlxSprite
{
	public var isPlayer:Bool;

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
			loadGraphic(g, true, Std.int(g.width / 2), Std.int(g.height));
			animation.add("i", [0, 1], 0, false);
			animation.play("i");
		}
		flipX = isPlayer;
		antialiasing = Settings.d.antialiasing && name.indexOf("pixel") < 0 && name != "senpai" && name != "spirit";
	}

	public inline function setLosing(losing:Bool):Void
		animation.frameIndex = losing ? 1 : 0;

	public inline function bump():Void
		scale.set(1.2, 1.2);

	/** Volta a escala para 1 de forma suave (independente do FPS). */
	public function settle(elapsed:Float):Void
	{
		var k = Math.exp(-elapsed * 9);
		var s = 1 + (scale.x - 1) * k;
		scale.set(s, s);
	}
}
