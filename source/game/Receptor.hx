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
	// --- modchart: deslocamentos em cima da posição base (cx, cy). As notas seguem px()/py().
	public var ox:Float = 0;
	public var oy:Float = 0;
	public var waveX:Float = 0; // amplitude do balanço horizontal (px)
	public var waveY:Float = 0; // amplitude do balanço vertical (px)
	public var waveSpeed:Float = 1; // ciclos por segundo (x2π)
	public var wavePhase:Float = 0;
	public var posX(get, set):Float; // centro X absoluto (tween-ável)
	public var posY(get, set):Float;
	public var size(get, set):Float; // escala relativa à original (1 = normal)
	var wx:Float = 0;
	var wy:Float = 0;
	var baseScale:Float = 1;
	public var scrollSpeed:Null<Float> = null; // velocidade das notas desta lane (estilo Codename); null = a do jogo

	public function new(lane:Int, cx:Float, cy:Float)
	{
		super();
		this.lane = lane;
		NoteSkin.setupReceptor(this, lane);
		scrollFactor.set();
		moves = false;
		baseScale = scale.x;
		setCenter(cx, cy);
	}

	public inline function px():Float
		return cx + ox + wx;

	public inline function py():Float
		return cy + oy + wy;

	function syncPos():Void
	{
		x = px() - width / 2;
		y = py() - height / 2;
	}

	function get_posX():Float
		return cx + ox;

	function set_posX(v:Float):Float
	{
		ox = v - cx;
		syncPos();
		return v;
	}

	function get_posY():Float
		return cy + oy;

	function set_posY(v:Float):Float
	{
		oy = v - cy;
		syncPos();
		return v;
	}

	function get_size():Float
		return scale.x / baseScale;

	function set_size(v:Float):Float
	{
		scale.set(baseScale * v, baseScale * v);
		updateHitbox();
		syncPos();
		return v;
	}

	/** Volta tudo ao normal na hora (posição, ondas, ângulo, alpha e tamanho). */
	public function resetMods():Void
	{
		ox = oy = waveX = waveY = wx = wy = 0;
		angle = 0;
		alpha = 1;
		size = 1;
	}

	/** Chamado pela Strumline todo frame: aplica o balanço. */
	public function tickMods(songPos:Float):Void
	{
		if (waveX != 0 || waveY != 0)
		{
			var t = songPos / 1000 * waveSpeed * 6.2831853 + wavePhase;
			wx = waveX * Math.sin(t);
			wy = waveY * Math.cos(t);
			syncPos();
		}
		else if (wx != 0 || wy != 0)
		{
			wx = wy = 0;
			syncPos();
		}
	}

	public function setCenter(x:Float, y:Float):Void
	{
		cx = x;
		cy = y;
		syncPos();
	}

	/** name: "static", "pressed" ou "confirm" */
	public function play(name:String, force:Bool = true):Void
	{
		animation.play(name, force);
		updateHitbox();
		syncPos();
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
