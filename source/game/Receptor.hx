package game;

import flixel.FlxSprite;

/** Seta fixa (receptor) de uma lane. Mantém o centro fixo mesmo quando o frame muda de tamanho. */
@:keep
class Receptor extends FlxSprite
{
	public var lane:Int;
	public var cx:Float;
	public var cy:Float;
	public var glowTimer:Float = 0;
	public var scrollSpeed:Null<Float> = null; // velocidade das notas desta lane (estilo Codename); null = a do jogo

	public function new(lane:Int, cx:Float, cy:Float)
	{
		super();
		this.lane = lane;
		NoteSkin.setupReceptor(this, lane);
		scrollFactor.set();
		moves = false;
		setCenter(cx, cy);
	}

	public function setCenter(x:Float, y:Float):Void
	{
		cx = x;
		cy = y;
		this.x = cx - width / 2;
		this.y = cy - height / 2;
	}

	/** name: "static", "pressed" ou "confirm" */
	public function play(name:String, force:Bool = true):Void
	{
		animation.play(name, force);
		updateHitbox();
		x = cx - width / 2;
		y = cy - height / 2;
	}

	/** Acende o receptor por um instante (usado pelo oponente). */
	public function flash(seconds:Float = 0.15):Void
	{
		play("confirm");
		glowTimer = seconds;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (glowTimer > 0)
		{
			glowTimer -= elapsed;
			if (glowTimer <= 0)
				play("static");
		}
	}
}
