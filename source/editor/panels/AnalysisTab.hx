package editor.panels;

import editor.ChartEditorState;
import editor.analysis.Analyzer;
import editor.analysis.Analyzer.Finding;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import openfl.geom.Rectangle;

using StringTools;

/** Aba ANÁLISE: densidade e fadiga ao longo da música, padrões de mão, relatório de coesão e marcadores de estrutura. */
class AnalysisTab extends FlxSpriteGroup
{
	static final SIDES:Array<String> = ["Oponente", "Jogador", "Ambos"];
	static final PRESETS:Array<String> = ["Intro", "Verso", "Pré-refrão", "Refrão", "Ponte", "Solo", "Outro"];
	static final PRESET_COLORS:Array<String> = ["7D8896", "4DD0E1", "B48CFF", "FFB347", "FF8FB1", "7BE0A4", "FF6B6B"];
	static var side:Int = 1;
	static var preset:Int = 0;

	var ed:ChartEditorState;
	var graph:FlxSprite;
	var stats:FlxText;
	var markerText:FlxText;
	var patRows:Array<Btn> = [];
	var cohRows:Array<Btn> = [];
	var patList:Array<Finding> = [];
	var cohList:Array<Finding> = [];
	var cohTitle:FlxText;
	var gx:Float;
	var gy:Float;
	var gw:Int;
	var gh:Int = 64;
	var drawnVersion:Int = -1;
	var drawnSide:Int = -1;
	var cooldown:Float = 0;
	var lengthMs:Float = 1;
	var lastMarkers:String = "\u0000";

	public function new(ed:ChartEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;
		gx = x;
		gw = w;

		add(EdTheme.text(x, 124, w, 12, "LADO ANALISADO", EdTheme.DIM));
		add(new Segments(x - 2, 144, w + 4, SIDES, function() return SIDES[side], function(v) side = SIDES.indexOf(v)));

		gy = 188;
		var bg = EdTheme.round(x, gy, w, gh, 8);
		bg.color = EdTheme.SURFACE;
		add(bg);
		graph = new FlxSprite(x, gy);
		graph.makeGraphic(w, gh, 0x00000000, true);
		add(graph);
		stats = EdTheme.text(x, gy + gh + 6, w, 12, "", EdTheme.TEXT);
		add(stats);

		add(EdTheme.text(x, 290, w, 12, "PADRÕES DE MÃO (clique para ir)", EdTheme.DIM));
		for (i in 0...4)
		{
			var k = i;
			var b = new Btn(x, 308 + i * 24, w, 22, "", function() jump(patList, k), 2);
			patRows.push(b);
			add(b);
		}

		add(EdTheme.text(x, 414, w, 12, "COESÃO", EdTheme.DIM));
		add(new Btn(x + w - 150, 408, 150, 24, "GERAR RELATÓRIO", function() runCohesion(true), 0));
		cohTitle = EdTheme.text(x + 56, 414, w - 220, 12, "", EdTheme.DIM);
		add(cohTitle);
		for (i in 0...5)
		{
			var k = i;
			var b = new Btn(x, 438 + i * 24, w, 22, "", function() jump(cohList, k), 2);
			cohRows.push(b);
			add(b);
		}

		add(EdTheme.rect(x, 568, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 580, w, 12, "MARCADORES DE ESTRUTURA", EdTheme.DIM));
		add(new Selector(x, 600, w, "Tipo", function() return PRESETS, function() return PRESETS[preset], function(v) preset = PRESETS.indexOf(v), 50));
		var half = Std.int((w - 8) / 2);
		add(new Btn(x, 636, half, 28, "MARCAR AQUI", addMarker, 1));
		add(new Btn(x + half + 8, 636, half, 28, "REMOVER ESTE", removeMarker, 0));
		markerText = EdTheme.text(x, 670, w, 12, "", EdTheme.DIM);
		add(markerText);
	}

	function jump(list:Array<Finding>, i:Int):Void
	{
		if (i < list.length)
			ed.seek(Math.max(0, list[i].ms - 400));
	}

	// ------------------------------------------------------------------ marcadores

	function addMarker():Void
	{
		var beat = Math.max(0, Math.round(ed.doc.tempo.beatAt(ed.songTimeNow()) * 4) / 4);
		ed.doc.addMarker(beat, PRESETS[preset], PRESET_COLORS[preset]);
		ed.say("Marcador \"" + PRESETS[preset] + "\" no beat " + beat);
	}

	function removeMarker():Void
	{
		var beat = ed.doc.tempo.beatAt(ed.songTimeNow());
		var best:Null<core.Chart.ChartMarker> = null;
		var bd = 1e9;
		for (m in ed.doc.chart.markers)
		{
			var d = Math.abs(m.beat - beat);
			if (d < bd)
			{
				bd = d;
				best = m;
			}
		}
		if (best == null)
		{
			ed.say("Não há marcadores.", false);
			return;
		}
		ed.doc.removeMarker(best);
		ed.say("Marcador \"" + best.name + "\" removido");
	}

	// ------------------------------------------------------------------ cálculos

	function recompute():Void
	{
		lengthMs = Math.max(1000, ed.lengthNow());
		var notes = Analyzer.pick(ed.doc, side);
		var dens = Analyzer.density(notes, lengthMs, 1000);
		var st = Analyzer.stamina(notes, lengthMs, 1000);
		patList = Analyzer.patterns(notes);
		// os mais pesados primeiro (nível alto), depois por tempo
		patList.sort(function(a, b) return a.level != b.level ? b.level - a.level : (a.ms < b.ms ? -1 : 1));

		var bd = graph.pixels;
		bd.fillRect(new Rectangle(0, 0, gw, gh), 0x00000000);
		var maxN = Math.max(8, dens.peak);
		for (px in 0...gw)
		{
			var bi = Std.int(px / gw * dens.bins.length);
			var h = Std.int(dens.bins[bi] / maxN * (gh - 6));
			if (h > 0)
				bd.fillRect(new Rectangle(px, gh - 3 - h, 1, h), 0xFF2F4A68);
			var f = st.curve[Std.int(Math.min(st.curve.length - 1, px / gw * st.curve.length))];
			var fh = Std.int(Math.min(1.0, f / 100) * (gh - 6));
			if (fh > 0)
				bd.fillRect(new Rectangle(px, gh - 3 - fh, 1, 2), f >= 100 ? 0xFFFF6B6B : 0xFFFFB347);
		}
		for (s in ed.doc.chart.sections) // régua de seções
			bd.fillRect(new Rectangle(Std.int(s.startMs / lengthMs * gw), gh - 3, 1, 3), 0x66FFFFFF);
		graph.pixels = bd;

		var pk = Std.int(Math.round(st.peak));
		stats.text = "NPS médio " + fmt(dens.avg) + "   pico " + fmt(dens.peak) + " (" + clock(dens.peakMs) + ")\nFadiga máx " + pk + "% (" + clock(st.peakMs)
			+ ")   padrões " + patList.length;
		for (i in 0...patRows.length)
			patRows[i].setText(i < patList.length ? clock(patList[i].ms) + "  " + mark(patList[i].level) + patList[i].text : (i == 0 ? "nenhum padrão marcante" : ""));
	}

	function runCohesion(announce:Bool):Void
	{
		cohList = Analyzer.cohesion(ed.doc, ed.lengthNow());
		var errs = 0;
		var warns = 0;
		for (f in cohList)
		{
			if (f.level == 2)
				errs++;
			else if (f.level == 1)
				warns++;
		}
		cohTitle.text = cohList.length == 0 ? "tudo certo" : errs + " erro(s), " + warns + " aviso(s)";
		for (i in 0...cohRows.length)
			cohRows[i].setText(i < cohList.length ? clock(cohList[i].ms) + "  " + mark(cohList[i].level) + cohList[i].text : (i == 0 && cohList.length == 0 ? "nenhum problema encontrado" : ""));
		if (announce)
			ed.say(cohList.length == 0 ? "Relatório de coesão: nenhum problema." : "Relatório: " + errs + " erro(s), " + warns + " aviso(s).", cohList.length == 0);
	}

	/** Resumo curto para o toast ao salvar (null se está tudo certo). */
	public function cohesionSummary():Null<String>
	{
		runCohesion(false);
		var n = 0;
		for (f in cohList)
			if (f.level >= 1)
				n++;
		return n == 0 ? null : n + " ponto(s) de atenção na aba ANÁLISE";
	}

	static function mark(level:Int):String
		return level >= 2 ? "[!] " : (level == 1 ? "[~] " : "");

	static function fmt(v:Float):String
		return Std.string(Math.round(v * 10) / 10);

	static function clock(ms:Float):String
	{
		var s = Std.int(Math.max(0, ms) / 1000);
		return Std.int(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
	}

	// ------------------------------------------------------------------ loop

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!visible)
			return;
		cooldown -= elapsed;
		if ((ed.doc.version != drawnVersion || side != drawnSide) && cooldown <= 0)
		{
			drawnVersion = ed.doc.version;
			drawnSide = side;
			cooldown = 0.4;
			recompute();
		}
		var ms = "";
		for (m in ed.doc.chart.markers)
			ms += m.name + " @" + (Math.round(m.beat * 10) / 10) + "  ";
		var shown = ms == "" ? "nenhum marcador ainda" : ms;
		if (shown != lastMarkers)
		{
			lastMarkers = shown;
			markerText.text = shown;
		}
		// clique no gráfico = ir para aquele ponto
		if (!EdLock.locked && FlxG.mouse.justPressed && FlxG.mouse.x >= gx && FlxG.mouse.x <= gx + gw && FlxG.mouse.y >= gy && FlxG.mouse.y <= gy + gh)
			ed.seek((FlxG.mouse.x - gx) / gw * lengthMs);
	}
}
