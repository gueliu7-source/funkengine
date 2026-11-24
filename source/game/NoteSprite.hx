package game;

import flixel.FlxSprite;

/**
 * Sprite reutilizável de nota. Existem poucos (pool): a cabeça, o corpo e a ponta de um
 * sustain são sprites separados; o corpo é esticado em vez de ser dezenas de pedaços.
 */
class NoteSprite extends FlxSprite
{
	public var kind:Int; // 0 cabeça, 1 corpo, 2 ponta
	public var lane:Int;

	public var custom:Bool = false; // textura própria de um script: não entra no pool

	/** Nota com atlas próprio (ex.: texture = "custard" num script Psych). Prefixos: purple0, blue0, green0, red0. */
	public static function withTexture(tex:String, lane:Int, sx:Float, sy:Float):Null<NoteSprite>
	{
		var f = core.Paths.sparrow("images/" + tex);
		if (f == null)
			return null;
		var s = new NoteSprite(0, lane);
		s.frames = f;
		s.animation.addByPrefix("a", NoteSkin.colors[lane] + "0", 24, true);
		s.animation.play("a");
		s.scale.set(sx, sy);
		s.updateHitbox();
		s.antialiasing = core.Settings.d.antialiasing;
		s.custom = true;
		return s;
	}

	public function new(kind:Int, lane:Int)
	{
		super();
		this.kind = kind;
		this.lane = lane;
		NoteSkin.setupNote(this, kind, lane);
		scrollFactor.set();
		moves = false; // a posição é calculada pela Strumline; sem física
		active = false; // sem update por frame (animação de 1 frame)
	}
}
