package editor;

import core.Chart.NoteData;
import editor.analysis.ChartGen;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;

/** Guia do gerador: bolinhas sobre a grade onde o áudio sugere notas. Fortes = ainda sem nota; fracas = já cobertas pelo chart. */
class GuideLayer extends FlxGroup
{
	static inline var POOL:Int = 110;

	public var show:Bool = true;
	public var notes(default, null):Array<NoteData> = [];

	var doc:ChartDoc;
	var grid:GridView;
	var pool:Array<FlxSprite> = [];
	var covered:Array<Bool> = [];
	var version:Int = -1;

	public function new(doc:ChartDoc, grid:GridView)
	{
		super();
		this.doc = doc;
		this.grid = grid;
		for (_ in 0...POOL)
		{
			var s = EdTheme.circle(0, 0, GridView.CELL - 22);
			s.visible = false;
			pool.push(s);
			add(s);
		}
	}

	public function set(list:Array<NoteData>):Void
	{
		notes = list;
		version = -1;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (version != doc.version)
		{
			version = doc.version;
			covered = ChartGen.coverage(doc.chart.notes, notes);
		}
		var used = 0;
		if (show)
			for (i in 0...notes.length)
			{
				if (used >= POOL)
					break;
				var n = notes[i];
				var y = grid.stepY(doc.tempo.beatAt(n.time) * 4);
				if (y < EdTheme.TOP_H - GridView.CELL || y > FlxG.height)
					continue;
				var s = pool[used++];
				s.visible = true;
				s.x = GridView.GX + (n.lane + (n.player ? 4 : 0)) * GridView.CELL + 11;
				s.y = y + 11;
				s.color = 0xFFFFFFFF;
				s.alpha = covered[i] ? 0.22 : 0.85;
			}
		for (i in used...POOL)
			pool[i].visible = false;
	}
}
