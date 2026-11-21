package game;

import core.Paths;
import core.Settings;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;

/** Carrega a skin das notas/receptores ("normal" = atlas Sparrow, "pixel" = grade 17x17). */
class NoteSkin
{
	public static inline var SIZE:Float = 112; // espaçamento entre lanes (160 * 0.7)
	public static inline var PIXEL_ZOOM:Float = 6;

	public static var pixel:Bool = false;
	public static var colors:Array<String> = ["purple", "blue", "green", "red"];
	public static var dirs:Array<String> = ["left", "down", "up", "right"];

	static var atlas:FlxAtlasFrames;
	static var pixelNotes:FlxGraphic;
	static var pixelEnds:FlxGraphic;

	public static function load(style:String):Void
	{
		pixel = (style == "pixel");
		if (pixel)
		{
			pixelNotes = Paths.graphic("images/noteskins/Arrows-pixel.png");
			pixelEnds = Paths.graphic("images/noteskins/Arrows-pixel-ends.png");
		}
		else
			atlas = Paths.sparrow("images/noteskins/Arrows");
	}

	/** kind: 0 = cabeça da nota, 1 = corpo do sustain, 2 = ponta do sustain */
	public static function setupNote(s:FlxSprite, kind:Int, lane:Int):Void
	{
		if (pixel)
		{
			if (kind == 0)
			{
				s.loadGraphic(pixelNotes, true, 17, 17);
				s.animation.add("a", [lane + 4]);
			}
			else
			{
				s.loadGraphic(pixelEnds, true, 7, 6);
				s.animation.add("a", [kind == 1 ? lane : lane + 4]);
			}
			s.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);
			s.antialiasing = false;
		}
		else
		{
			s.frames = atlas;
			var c = colors[lane];
			s.animation.addByPrefix("a", c + (kind == 0 ? " alone" : (kind == 1 ? " hold" : " tail")), 24, true);
			s.scale.set(0.7, 0.7);
			s.antialiasing = Settings.d.antialiasing;
		}
		s.animation.play("a");
		s.updateHitbox();
	}

	public static function setupReceptor(s:FlxSprite, lane:Int):Void
	{
		if (pixel)
		{
			s.loadGraphic(pixelNotes, true, 17, 17);
			s.animation.add("static", [lane]);
			s.animation.add("pressed", [4 + lane, 8 + lane], 12, false);
			s.animation.add("confirm", [12 + lane, 16 + lane], 24, false);
			s.scale.set(PIXEL_ZOOM, PIXEL_ZOOM);
			s.antialiasing = false;
		}
		else
		{
			s.frames = atlas;
			var d = dirs[lane];
			s.animation.addByPrefix("static", "arrow" + d.toUpperCase(), 24, false);
			s.animation.addByPrefix("pressed", d + " press", 24, false);
			s.animation.addByPrefix("confirm", d + " confirm", 24, false);
			s.scale.set(0.7, 0.7);
			s.antialiasing = Settings.d.antialiasing;
		}
		s.animation.play("static");
		s.updateHitbox();
	}
}
