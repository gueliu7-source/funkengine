package editor;

import core.Chart.ChartMarker;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Marcadores de estrutura (Intro, Verso, Refrão...) desenhados como uma linha colorida atravessando a grade, com o nome na ponta. */
class MarkerLayer extends FlxGroup
{
	static inline var POOL:Int = 6;

	var doc:ChartDoc;
	var grid:GridView;
	var lines:Array<FlxSprite> = [];
	var pills:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];

	public function new(doc:ChartDoc, grid:GridView)
	{
		super();
		this.doc = doc;
		this.grid = grid;
		var w = GridView.CELL * GridView.COLS;
		for (_ in 0...POOL)
		{
			var l = EdTheme.rect(GridView.GX, 0, w, 2, FlxColor.WHITE);
			l.alpha = 0.55;
			var p = EdTheme.round(0, 0, 110, 18, 9);
			var t = EdTheme.text(0, 0, 110, 11, "", 0xFF10141A, FlxTextAlign.CENTER);
			lines.push(l);
			pills.push(p);
			labels.push(t);
			add(l);
			add(p);
			add(t);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var used = 0;
		var right = GridView.GX + GridView.CELL * GridView.COLS;
		for (m in doc.chart.markers)
		{
			var y = grid.stepY(m.beat * 4);
			if (y < EdTheme.TOP_H || y > FlxG.height + 20 || used >= POOL)
				continue;
			var col = EventRegistry.parseColor(m.color);
			lines[used].visible = pills[used].visible = labels[used].visible = true;
			lines[used].y = y - 1;
			lines[used].color = col;
			pills[used].x = right - 114;
			pills[used].y = y - 19;
			pills[used].color = col;
			labels[used].x = right - 114;
			labels[used].y = y - 17;
			if (labels[used].text != m.name)
				labels[used].text = m.name;
			used++;
		}
		for (i in used...POOL)
			lines[i].visible = pills[i].visible = labels[i].visible = false;
	}
}
