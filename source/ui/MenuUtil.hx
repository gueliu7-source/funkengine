package ui;

import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Pequenas funções compartilhadas pelas telas de menu (fundo, texto, som, música). */
class MenuUtil
{
	/** Carrega uma imagem como fundo; se não existir, usa uma cor sólida. */
	public static function bg(rel:String, fallback:FlxColor):FlxSprite
	{
		var s = new FlxSprite();
		var g = Paths.graphic(rel);
		if (g != null)
			s.loadGraphic(g);
		else
			s.makeGraphic(FlxG.width, FlxG.height, fallback);
		s.antialiasing = Settings.d.antialiasing;
		return s;
	}

	public static function text(x:Float, y:Float, w:Float, size:Int, align:FlxTextAlign, s:String = ""):FlxText
	{
		var t = new FlxText(x, y, w, s, size);
		t.setFormat(Paths.FONT, size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 2;
		return t;
	}

	public static function sfx(name:String, vol:Float = 0.7):Void
	{
		var s = Paths.sound('sounds/$name.ogg');
		if (s != null)
			FlxG.sound.play(s, vol);
	}

	/** Toca a música de menu (freakyMenu) se nada estiver tocando. */
	public static function ensureMenuMusic():Void
	{
		if ((FlxG.sound.music == null || !FlxG.sound.music.playing) && Paths.exists("music/freakyMenu.ogg"))
		{
			var m = Paths.loadSound("music/freakyMenu.ogg");
			if (m != null)
				FlxG.sound.playMusic(m, 0.7);
		}
	}
}
