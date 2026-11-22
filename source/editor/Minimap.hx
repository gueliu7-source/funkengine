package editor;

import core.Chart.NoteData;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

/** Faixa vertical da música inteira: densidade de notas, seções, posição atual. Clique/arraste para ir a qualquer ponto. */
class Minimap extends FlxGroup
{
	public static inline var MX:Int = GridView.GX + GridView.CELL * GridView.COLS + 14;
	public static inline var MW:Int = 26;
	public static inline var MY:Int = EdTheme.TOP_H + 14;
	public static inline var MH:Int = 720 - EdTheme.TOP_H - 28;

	var doc:ChartDoc;
	var getLen:Void->Float;
	var getTime:Void->Float;
	var onSeek:Float->Void;
	var heat:FlxSprite;
	var marker:FlxSprite;
	var view:FlxSprite;
	var drawn:Int = -1;
	var dragging:Bool = false;

	public function new(doc:ChartDoc, getLen:Void->Float, getTime:Void->Float, onSeek:Float->Void)
	{
		super();
		this.doc = doc;
		this.getLen = getLen;
		this.getTime = getTime;
		this.onSeek = onSeek;
		var bg = EdTheme.round(MX, MY, MW, MH, 8);
		bg.color = EdTheme.SURFACE;
		add(bg);
		heat = new FlxSprite(MX, MY);
		heat.makeGraphic(MW, MH, FlxColor.TRANSPARENT, true);
		heat.scrollFactor.set();
		add(heat);
		view = EdTheme.rect(MX, MY, MW, 10, EdTheme.CYAN);
		view.alpha = 0.16;
		add(view);
		marker = EdTheme.rect(MX - 3, MY, MW + 6, 3, EdTheme.ACCENT);
		add(marker);
	}

	function redraw():Void
	{
		var len = Math.max(1, getLen());
		var bd = new BitmapData(MW, MH, true, 0x00000000);
		var rows = MH;
		var counts:Array<Int> = [for (i in 0...rows) 0];
		var maxC = 1;
		for (n in doc.chart.notes)
		{
			var r = Std.int(n.time / len * rows);
			if (r >= 0 && r < rows)
			{
				counts[r]++;
				if (counts[r] > maxC)
					maxC = counts[r];
			}
		}
		for (r in 0...rows)
			if (counts[r] > 0)
			{
				var w = Std.int(Math.max(2, (MW - 6) * counts[r] / maxC));
				bd.fillRect(new Rectangle(3, r, w, 1), 0xFF3C536E);
			}
		for (s in doc.chart.sections)
		{
			var r = Std.int(s.startMs / len * rows);
			if (r >= 0 && r < rows)
				bd.fillRect(new Rectangle(0, r, MW, 1), 0x55FFB347);
		}
		heat.pixels = bd;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var key = doc.version * 1000 + Std.int(getLen() / 100);
		if (key != drawn)
		{
			drawn = key;
			redraw();
		}
		var len = Math.max(1, getLen());
		marker.y = MY + getTime() / len * MH - 1;
		view.y = marker.y - 3;

		var over = !EdLock.locked && FlxG.mouse.x >= MX - 4 && FlxG.mouse.x <= MX + MW + 4 && FlxG.mouse.y >= MY && FlxG.mouse.y <= MY + MH;
		if (over && FlxG.mouse.justPressed)
			dragging = true;
		if (dragging)
		{
			if (FlxG.mouse.pressed)
				onSeek(Math.max(0, Math.min(1, (FlxG.mouse.y - MY) / MH)) * len);
			else
				dragging = false;
		}
	}
}
