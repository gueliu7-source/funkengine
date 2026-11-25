package ui;

import core.Paths;
import core.Settings;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;

/**
 * Texto com a fonte desenhada do FNF (images/alphabet.png/.xml). Letras viram maiúsculas em negrito;
 * números e símbolos usam os glifos comuns. Caracteres que não existem no atlas viram espaço.
 * O atlas pode ser trocado por um mod (images/alphabet.*).
 */
class Alphabet extends FlxSpriteGroup
{
	static final SYMBOLS:Map<String, String> = [
		"!" => "exclamation point", "?" => "question mark", "." => "period", "," => "comma", "'" => "apostraphie",
		"(" => "start parentheses", ")" => "end parentheses", "/" => "forward slash", "-" => "-", "_" => "_",
		"+" => "+", "=" => "=", "*" => "*", "&" => "&", "%" => "%", "$" => "$", "#" => "#", "@" => "@", ":" => ":",
		";" => ";", "<" => "<", ">" => ">", "[" => "[", "]" => "]", "^" => "^", "~" => "~", "|" => "|", "\\" => "\\",
		"x" => "multiply x"
	];

	public static inline var LINE_H:Float = 70;

	var atlas:FlxAtlasFrames;
	public var textValue(default, null):String = "";
	public var letterScale:Float = 1;

	public function new(x:Float, y:Float, text:String, scale:Float = 1)
	{
		super(x, y);
		letterScale = scale;
		atlas = Paths.sparrow("images/alphabet");
		setText(text);
	}

	public function setText(text:String):Void
	{
		textValue = text;
		for (m in members.copy())
		{
			remove(m, true);
			m.destroy();
		}
		if (atlas == null)
			return;
		var cx:Float = 0;
		var line:Float = 0;
		for (i in 0...text.length)
		{
			var ch = text.charAt(i);
			if (ch == "\n")
			{
				cx = 0;
				line++;
				continue;
			}
			if (ch == " ")
			{
				cx += 40 * letterScale;
				continue;
			}
			var spr = glyph(ch);
			if (spr == null)
			{
				cx += 40 * letterScale;
				continue;
			}
			spr.scale.set(letterScale, letterScale);
			spr.updateHitbox();
			// letras alinhadas pela base da linha
			spr.setPosition(cx, line * LINE_H * letterScale + (LINE_H - 4) * letterScale - spr.height);
			add(spr);
			cx += spr.width + 3 * letterScale;
		}
	}

	function glyph(ch:String):FlxSprite
	{
		var up = ch.toUpperCase();
		var prefix:String = null;
		if (up.length == 1 && up >= "A" && up <= "Z")
			prefix = up + " bold";
		else if (up >= "0" && up <= "9")
			prefix = up;
		else
			prefix = SYMBOLS.get(ch);
		if (prefix == null)
			return null;
		var s = new FlxSprite();
		s.frames = atlas;
		s.animation.addByPrefix("g", prefix, 24, true);
		if (s.animation.getByName("g") == null)
		{
			s.destroy();
			return null;
		}
		s.animation.play("g");
		s.antialiasing = Settings.d.antialiasing;
		s.scrollFactor.set();
		return s;
	}
}
