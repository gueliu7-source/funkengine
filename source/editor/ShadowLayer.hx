package editor;

import core.Chart.ChartLoader;
import core.Chart.NoteData;
import core.Paths;
import editor.ChartDoc.ClipNote;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;

/**
 * Modo sombra: mostra as notas de OUTRO chart (outra dificuldade, ou a versão já salva deste) como fantasmas
 * translúcidos na mesma grade, só para referência. Posições são convertidas por tempo, então funciona mesmo
 * com BPM diferente. Não é editável; "importar" copia as notas da seção atual da sombra para o chart.
 */
class ShadowLayer extends FlxGroup
{
	public static inline var NONE:String = "Nenhuma";
	public static inline var SAVED:String = "Versão salva";
	static inline var POOL:Int = 110;

	public var source(default, null):String = NONE;
	public var count(default, null):Int = 0;

	var doc:ChartDoc;
	var grid:GridView;
	var notes:Array<NoteData> = [];
	var pool:Array<FlxSprite> = [];

	public function new(doc:ChartDoc, grid:GridView)
	{
		super();
		this.doc = doc;
		this.grid = grid;
		for (_ in 0...POOL)
		{
			var s = EdTheme.round(0, 0, GridView.CELL - 14, GridView.CELL - 14, 9);
			s.alpha = 0.36;
			s.visible = false;
			pool.push(s);
			add(s);
		}
	}

	static function suffixOf(name:String):String
		return switch (name)
		{
			case "normal": "";
			case "easy": "-easy";
			case "hard": "-hard";
			default: "";
		}

	/** Fontes que existem para esta música (a dificuldade aberta só aparece como "Versão salva"). */
	public function options():Array<String>
	{
		var out = [NONE];
		for (n in ["normal", "easy", "hard"])
		{
			var suf = suffixOf(n);
			if (suf != ChartEditorState.suffix && Paths.exists('data/songs/${doc.songId}/${doc.songId}$suf.json'))
				out.push(n);
		}
		if (Paths.exists('data/songs/${doc.songId}/${doc.songId}${ChartEditorState.suffix}.json'))
			out.push(SAVED);
		return out;
	}

	public function set(name:String):Bool
	{
		source = name;
		notes = [];
		count = 0;
		if (name == NONE)
			return true;
		var suf = name == SAVED ? ChartEditorState.suffix : suffixOf(name);
		var c = ChartLoader.load(doc.songId, suf, 0);
		if (c == null)
		{
			source = NONE;
			return false;
		}
		notes = c.notes;
		count = notes.length;
		return true;
	}

	/** Notas da sombra no intervalo de batidas [a, b) do chart atual, já em formato de colar. */
	public function clip(a:Float, b:Float):Array<ClipNote>
	{
		var out:Array<ClipNote> = [];
		var ma = doc.tempo.msAt(a) - 0.5;
		var mb = doc.tempo.msAt(b) - 0.5;
		for (n in notes)
			if (n.time >= ma && n.time < mb)
			{
				var nb = doc.tempo.beatAt(n.time);
				out.push({
					beat: nb - a,
					lane: n.lane,
					player: n.player,
					sustain: n.sustain > 0 ? doc.tempo.beatAt(n.time + n.sustain) - nb : 0,
					type: n.type,
					alt: n.alt
				});
			}
		return out;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var used = 0;
		if (source != NONE)
			for (n in notes)
			{
				if (used >= POOL)
					break;
				var y = grid.stepY(doc.tempo.beatAt(n.time) * 4);
				if (y < EdTheme.TOP_H - GridView.CELL || y > FlxG.height)
					continue;
				var s = pool[used++];
				s.visible = true;
				s.x = GridView.GX + (n.lane + (n.player ? 4 : 0)) * GridView.CELL + 7;
				s.y = y + 7;
				s.color = EdTheme.LANE[n.lane % 4];
			}
		for (i in used...POOL)
			pool[i].visible = false;
	}
}
