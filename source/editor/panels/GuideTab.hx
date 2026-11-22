package editor.panels;

import core.Chart.NoteData;
import editor.ChartEditorState;
import editor.analysis.AudioPeaks;
import editor.analysis.ChartGen;
import editor.analysis.GenOpts;
import editor.analysis.Onset;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

using StringTools;

/** Aba GUIA: analisa a voz (ou o Inst), desenha sugestões de notas na grade, compara com o chart e gera notas. */
class GuideTab extends FlxSpriteGroup
{
	static final SRC:Array<String> = ["Voz", "Inst"];
	static final DIV:Array<String> = ["1/4", "1/8", "1/16", "1/32"];
	static final MODE:Array<String> = ["Altura", "Variado"];
	static var src:Int = 0;
	static var sens:Float = 0.5;
	static var quant:Int = 16;
	static var mode:Int = 0;
	static var sustains:Bool = true;

	var ed:ChartEditorState;
	var info:FlxText;
	var report:FlxText;
	var rows:Array<Btn> = [];
	var rowMs:Array<Float> = [0, 0, 0, 0];
	var ons:Array<Onset> = [];
	var guide:Array<NoteData> = [];

	public function new(ed:ChartEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		add(EdTheme.text(x, 124, w, 12, "ÁUDIO DE REFERÊNCIA", EdTheme.DIM));
		add(new Segments(x - 2, 144, w + 4, SRC, function() return SRC[src], function(v) src = SRC.indexOf(v)));

		add(new Slider(x, 184, w, "Sensibilidade (mais notas →)", function() return sens, function(v) sens = v, 0, 1, 2));
		add(EdTheme.text(x, 238, w, 12, "ENCAIXAR NA GRADE", EdTheme.DIM));
		add(new Segments(x - 2, 256, w + 4, DIV, function() return "1/" + quant, function(v) quant = Std.parseInt(v.substr(2))));
		add(EdTheme.text(x, 292, w, 12, "COLUNA PELA ALTURA DA VOZ", EdTheme.DIM));
		add(new Segments(x - 2, 310, w + 4, MODE, function() return MODE[mode], function(v) mode = MODE.indexOf(v)));
		add(new Toggle(x, 346, w, "Sustain nos sons longos", function() return sustains, function(v) sustains = v));
		add(new Toggle(x, 374, w, "Mostrar guia na grade", function() return ed.guide.show, function(v) ed.guide.show = v));

		add(new Btn(x, 408, w, 32, "ANALISAR E MOSTRAR GUIA", analyze, 1));
		info = EdTheme.text(x, 448, w, 12, "Escolha a fonte e clique em analisar. As bolinhas brancas na grade são as sugestões.", EdTheme.DIM);
		add(info);

		add(EdTheme.rect(x, 494, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 502, w, 12, "CONFERÊNCIA DO SEU CHART", EdTheme.DIM));
		report = EdTheme.text(x, 518, w, 12, "", EdTheme.TEXT);
		add(report);
		for (i in 0...4)
		{
			var k = i;
			var b = new Btn(x, 552 + i * 23, w, 22, "", function() {
				if (rows[k].visible)
					ed.seek(Math.max(0, rowMs[k] - 400));
			}, 2);
			rows.push(b);
			add(b);
		}
		var half = Std.int((w - 8) / 2);
		add(new Btn(x, 650, half, 28, "ACEITAR SEÇÃO", acceptSection, 0));
		add(new Btn(x + half + 8, 650, half, 28, "GERAR TUDO", generateAll, 0));
	}

	function soundForSource():Null<openfl.media.Sound>
	{
		if (src == 0)
		{
			var v = ed.voicesSound();
			if (v != null)
				return v;
			ed.say("Sem Voices.ogg: usando o Inst.", false);
		}
		return ed.instSound();
	}

	function opts():GenOpts
		return {sens: sens, quant: quant, mode: mode, sustains: sustains};

	function analyze():Void
	{
		var p = ChartGen.pcm(soundForSource());
		if (p == null)
		{
			info.text = "Falhou: " + AudioPeaks.lastError;
			ed.say("Guia: " + AudioPeaks.lastError, false);
			return;
		}
		ons = ChartGen.onsets(p, sens);
		guide = ChartGen.build(ed.doc, ons, opts());
		ed.guide.set(guide);
		ed.guide.show = true;
		var lo = 1e9;
		var hi = 0.0;
		var voiced = 0;
		for (o in ons)
			if (!Math.isNaN(o.hz))
			{
				voiced++;
				lo = Math.min(lo, o.hz);
				hi = Math.max(hi, o.hz);
			}
		info.text = guide.length + " sugestões (" + ons.length + " ataques). "
			+ (voiced > 0 ? "Altura de " + Std.int(lo) + " a " + Std.int(hi) + " Hz em " + voiced + " deles." : "Sem altura definida (som sem tom claro).");
		refresh();
		ed.say("Guia pronto: " + guide.length + " sugestões.");
	}

	function refresh():Void
	{
		if (ons.length == 0)
			return;
		var c = ChartGen.compare(ed.doc.chart.notes, ons, guide);
		var pct = c.total == 0 ? 0 : Std.int(c.anchored * 100 / c.total);
		var pl = c.anchored == 0 ? 0 : Std.int(c.laneOk * 100 / c.anchored);
		report.text = c.total + " notas: " + pct + "% caem num som do áudio, " + pl + "% delas na coluna sugerida.\n" + c.missing.length + " sons sem nota, "
			+ c.orphan.length + " notas sem som.";
		var i = 0;
		var a = 0;
		var b = 0;
		while (i < 4)
		{
			var takeMissing = (i % 2 == 0 && a < c.missing.length) || b >= c.orphan.length;
			if (takeMissing && a >= c.missing.length)
				break;
			rowMs[i] = takeMissing ? c.missing[a] : c.orphan[b];
			rows[i].setText((takeMissing ? "sem nota   " : "sem som   ") + clock(rowMs[i]));
			rows[i].visible = true;
			if (takeMissing)
				a++;
			else
				b++;
			i++;
		}
		for (k in i...4)
			rows[k].visible = false;
	}

	function acceptSection():Void
	{
		if (guide.length == 0)
		{
			ed.say("Analise o áudio primeiro.", false);
			return;
		}
		var a = ed.doc.chart.sections[ed.curSection].startMs;
		var b = ed.curSection + 1 < ed.doc.chart.sections.length ? ed.doc.chart.sections[ed.curSection + 1].startMs : 1e12;
		var part = [for (n in guide) if (n.time >= a - 0.5 && n.time < b - 0.5) n];
		var added = ed.doc.mergeNotes(part, "aceitar guia");
		ed.say(added + " notas adicionadas na seção " + ed.curSection + ".");
		refresh();
	}

	function generateAll():Void
	{
		if (guide.length == 0)
		{
			ed.say("Analise o áudio primeiro.", false);
			return;
		}
		ed.doc.replaceAllNotes(guide, "gerar chart");
		ed.say("Chart gerado com " + guide.length + " notas (Ctrl+Z volta ao anterior).");
		refresh();
	}

	static function clock(ms:Float):String
	{
		var s = Std.int(Math.max(0, ms) / 1000);
		return Std.int(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60);
	}

	var lastVersion:Int = -1;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (ons.length > 0 && ed.doc.version != lastVersion)
		{
			lastVersion = ed.doc.version;
			refresh();
		}
	}
}
