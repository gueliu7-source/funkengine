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
