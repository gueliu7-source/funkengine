package editor;

import core.Chart;
import core.Conductor.BpmSegment;

/** Uma ação desfazível. */
class Cmd
{
	public var name:String;
	public var redo:Void->Void;
	public var undo:Void->Void;

	public function new(name:String, redo:Void->Void, undo:Void->Void)
	{
		this.name = name;
		this.redo = redo;
		this.undo = undo;
	}
}

/** Nota copiada, com posição relativa ao início da seção. */
typedef ClipNote =
{
	var beat:Float;
	var lane:Int;
	var player:Bool;
	var sustain:Float; // em batidas
	var type:String;
	var alt:Bool;
}

/**
 * Documento do chart: dados + desfazer/refazer. Nenhuma tela altera chart.notes diretamente;
 * tudo passa por aqui para manter a lista ordenada, as seções coerentes e o histórico correto.
 * A posição das notas é guardada em ms (formato do jogo), mas as edições pensam em batidas
 * (assim uma mudança de BPM não desloca as notas na grade).
 */
class ChartDoc
{
	public var chart:Chart;
	public var tempo:TempoMap;
	public var songId:String;
	public var suffix:String;
	public var dirty:Bool = false;
	public var version:Int = 0; // sobe a cada mudança; as views comparam para redesenhar
	public var lengthMs:Float = 0;
	public var maxSustainMs:Float = 0;

	var undoStack:Array<Cmd> = [];
	var redoStack:Array<Cmd> = [];

	public var canUndo(get, never):Bool;
	public var canRedo(get, never):Bool;

	public function new(chart:Chart, songId:String, suffix:String, lengthMs:Float)
	{
		this.chart = chart;
		this.songId = songId;
		this.suffix = suffix;
		this.lengthMs = lengthMs;
		tempo = new TempoMap(chart.segments);
		chart.segments = tempo.segs;
		ensureSections();
		normalize();
	}

	inline function get_canUndo():Bool
		return undoStack.length > 0;

	inline function get_canRedo():Bool
		return redoStack.length > 0;

	// ------------------------------------------------------------ histórico

	public function run(c:Cmd):Void
	{
		c.redo();
		undoStack.push(c);
		redoStack = [];
		changed();
	}

	public function undo():Null<String>
	{
		var c = undoStack.pop();
		if (c == null)
			return null;
		c.undo();
		redoStack.push(c);
		changed();
		return c.name;
	}

	public function redo():Null<String>
	{
		var c = redoStack.pop();
		if (c == null)
			return null;
		c.redo();
		undoStack.push(c);
		changed();
		return c.name;
	}

	function changed():Void
	{
		dirty = true;
		version++;
		normalize();
	}

	/** Mantém tudo ordenado e com a seção de cada nota certa. */
	function normalize():Void
	{
		chart.notes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		chart.events.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		maxSustainMs = 0;
		for (n in chart.notes)
		{
			n.section = sectionIndexAtMs(n.time);
			if (n.sustain > maxSustainMs)
				maxSustainMs = n.sustain;
		}
		chart.bpm = tempo.segs[0].bpm;
	}

	// ------------------------------------------------------------ seções

	/** Garante seções até o fim da música (e uma de folga). */
	public function ensureSections():Void
	{
		if (chart.sections.length == 0)
			chart.sections.push(new SectionData(0, 0, 16, true, false));
		var lastEnd = function() {
			var s = chart.sections[chart.sections.length - 1];
			return tempo.msAt(s.startBeat + s.steps / 4);
		};
		while (lastEnd() < lengthMs + 1000)
		{
			var s = chart.sections[chart.sections.length - 1];
			var b = s.startBeat + s.steps / 4;
			chart.sections.push(new SectionData(tempo.msAt(b), b, 16, s.mustHit, false));
		}
		recomputeSections();
	}

	function recomputeSections():Void
	{
		var b = 0.0;
		for (s in chart.sections)
		{
			s.startBeat = b;
			s.startMs = tempo.msAt(b);
			b += s.steps / 4;
		}
	}

	public function sectionIndexAtBeat(beat:Float):Int
	{
		var i = chart.sections.length - 1;
		while (i > 0 && chart.sections[i].startBeat > beat + 0.00001)
			i--;
		return i;
	}

	public inline function sectionIndexAtMs(ms:Float):Int
		return sectionIndexAtBeat(tempo.beatAt(ms));

	public function sectionEndBeat(i:Int):Float
		return chart.sections[i].startBeat + chart.sections[i].steps / 4;

	public function setMustHit(i:Int, v:Bool):Void
	{
		var old = chart.sections[i].mustHit;
		if (old == v)
			return;
		run(new Cmd("câmera da seção", function() chart.sections[i].mustHit = v, function() chart.sections[i].mustHit = old));
	}

	// ------------------------------------------------------------ notas

	public function beatOf(n:NoteData):Float
		return tempo.beatAt(n.time);

	/** Primeiro índice com time >= ms (busca binária). */
	public function lowerBound(ms:Float):Int
	{
		var lo = 0;
		var hi = chart.notes.length;
		while (lo < hi)
		{
			var mid = (lo + hi) >> 1;
			if (chart.notes[mid].time < ms)
				lo = mid + 1;
			else
				hi = mid;
		}
		return lo;
	}

	/** Nota nessa posição (tolerância de 1/200 de batida). */
	public function noteAt(beat:Float, lane:Int, player:Bool):Null<NoteData>
	{
		var ms = tempo.msAt(beat);
		var i = lowerBound(ms - 30);
		while (i < chart.notes.length && chart.notes[i].time <= ms + 30)
		{
			var n = chart.notes[i];
			if (n.lane == lane && n.player == player && Math.abs(beatOf(n) - beat) < 0.005)
				return n;
			i++;
		}
		return null;
	}

	/** Nota cuja cabeça ou sustain cobre essa posição. */
	public function noteCovering(beat:Float, lane:Int, player:Bool):Null<NoteData>
	{
		var ms = tempo.msAt(beat);
		var i = lowerBound(ms - maxSustainMs - 30);
		var found:NoteData = null;
		while (i < chart.notes.length && chart.notes[i].time <= ms + 30)
		{
			var n = chart.notes[i];
			if (n.lane == lane && n.player == player)
			{
				var b0 = beatOf(n);
				var end = b0 + 0.25; // a cabeça ocupa 1 step
				if (n.sustain > 0)
					end = Math.max(end, tempo.beatAt(n.time + n.sustain));
				if (beat >= b0 - 0.005 && beat < end)
					found = n;
			}
			i++;
		}
		return found;
	}

	public function addNote(beat:Float, lane:Int, player:Bool):NoteData
	{
		var n = new NoteData(tempo.msAt(beat), lane, player, 0, "", false, 0);
		run(new Cmd("adicionar nota", function() chart.notes.push(n), function() chart.notes.remove(n)));
		return n;
	}

	public function removeNote(n:NoteData):Void
		run(new Cmd("remover nota", function() chart.notes.remove(n), function() chart.notes.push(n)));

	/** Ajusta o sustain sem registrar no histórico (usado durante o arrasto). */
	public function setSustainLive(n:NoteData, lenBeats:Float):Void
	{
		var b = beatOf(n);
		n.sustain = lenBeats <= 0 ? 0 : tempo.msAt(b + lenBeats) - n.time;
		version++;
		dirty = true;
		if (n.sustain > maxSustainMs)
			maxSustainMs = n.sustain;
	}

	public function commitSustain(n:NoteData, oldMs:Float):Void
	{
		var now = n.sustain;
		if (Math.abs(now - oldMs) < 0.5)
			return;
		undoStack.push(new Cmd("sustain", function() n.sustain = now, function() n.sustain = oldMs));
		redoStack = [];
		changed();
	}

	public function setNoteAlt(n:NoteData, v:Bool):Void
	{
		var old = n.alt;
		run(new Cmd("nota alternativa", function() n.alt = v, function() n.alt = old));
	}

	public function setNoteType(n:NoteData, t:String):Void
	{
		var old = n.type;
		run(new Cmd("tipo da nota", function() n.type = t, function() n.type = old));
	}

	// ------------------------------------------------------------ operações em seção

	public function copyNotes(beatA:Float, beatB:Float):Array<ClipNote>
	{
		var out:Array<ClipNote> = [];
		for (n in notesIn(beatA, beatB))
		{
			var b = beatOf(n);
			out.push({
				beat: b - beatA,
				lane: n.lane,
				player: n.player,
				sustain: n.sustain > 0 ? tempo.beatAt(n.time + n.sustain) - b : 0,
				type: n.type,
				alt: n.alt
			});
		}
		return out;
	}

	public function notesIn(beatA:Float, beatB:Float):Array<NoteData>
	{
		var a = tempo.msAt(beatA) - 0.5;
		var b = tempo.msAt(beatB) - 0.5;
		return [for (n in chart.notes) if (n.time >= a && n.time < b) n];
	}

	/** Troca as notas de [beatA, beatB) por `clip` (posições relativas a beatA). */
	public function replaceRange(name:String, beatA:Float, beatB:Float, clip:Array<ClipNote>):Void
	{
		var oldNotes = notesIn(beatA, beatB);
		var newNotes:Array<NoteData> = [];
		for (c in clip)
		{
			var t = tempo.msAt(beatA + c.beat);
			var sus = c.sustain > 0 ? tempo.msAt(beatA + c.beat + c.sustain) - t : 0;
			newNotes.push(new NoteData(t, c.lane, c.player, sus, c.type, c.alt, 0));
		}
		run(new Cmd(name, function() {
			for (n in oldNotes)
				chart.notes.remove(n);
			for (n in newNotes)
				chart.notes.push(n);
		}, function() {
			for (n in newNotes)
				chart.notes.remove(n);
			for (n in oldNotes)
				chart.notes.push(n);
		}));
	}

	public function clearSection(i:Int):Void
		replaceRange("limpar seção", chart.sections[i].startBeat, sectionEndBeat(i), []);

	public function swapSides(i:Int):Void
	{
		var a = chart.sections[i].startBeat;
		var clip = copyNotes(a, sectionEndBeat(i));
		for (c in clip)
			c.player = !c.player;
		replaceRange("espelhar lados", a, sectionEndBeat(i), clip);
	}

	/** Cola `clip` na seção i, somando às notas que já existem. */
	public function pasteInto(i:Int, clip:Array<ClipNote>, replace:Bool):Void
	{
		var a = chart.sections[i].startBeat;
		var b = sectionEndBeat(i);
		var all = replace ? [] : copyNotes(a, b);
		for (c in clip)
			if (c.beat < b - a)
				all.push(c);
		replaceRange("colar", a, b, all);
	}

	// ------------------------------------------------------------ tempo

	/** Define o BPM a partir dessa batida. As notas ficam na mesma posição da grade (mudam de ms). */
	public function setBpmAt(beat:Float, bpm:Float):Void
	{
		if (bpm < 10 || bpm > 999)
			return;
		var oldSegs = tempo.clone();
		var newSegs = tempo.clone();
		var hit:BpmSegment = null;
		for (s in newSegs)
			if (Math.abs(s.beat - beat) < 0.0001)
				hit = s;
		if (hit != null)
			hit.bpm = bpm;
		else
			newSegs.push(new BpmSegment(0, beat, bpm));
		// remove segmentos redundantes (mesmo BPM do anterior)
		newSegs.sort(function(a, b) return a.beat < b.beat ? -1 : 1);
		var i = newSegs.length - 1;
		while (i > 0)
		{
			if (newSegs[i].bpm == newSegs[i - 1].bpm)
				newSegs.splice(i, 1);
			i--;
		}
		retime("mudar BPM", oldSegs, newSegs);
	}

	function retime(name:String, oldSegs:Array<BpmSegment>, newSegs:Array<BpmSegment>):Void
	{
		var notes = chart.notes.copy();
		var b0 = [for (n in notes) tempo.beatAt(n.time)];
		var b1 = [for (n in notes) n.sustain > 0 ? tempo.beatAt(n.time + n.sustain) : -1.0];
		var evs = chart.events.copy();
		var eb = [for (e in evs) tempo.beatAt(e.time)];

		var apply = function(segs:Array<BpmSegment>) {
			tempo.segs = [for (s in segs) new BpmSegment(s.timeMs, s.beat, s.bpm)];
			chart.segments = tempo.segs;
			tempo.rebuild();
			for (i in 0...notes.length)
			{
				notes[i].time = tempo.msAt(b0[i]);
				notes[i].sustain = b1[i] < 0 ? 0 : tempo.msAt(b1[i]) - notes[i].time;
			}
			for (i in 0...evs.length)
				evs[i].time = tempo.msAt(eb[i]);
			recomputeSections();
		};
		run(new Cmd(name, function() apply(newSegs), function() apply(oldSegs)));
	}

	/** Duração total (ms) da última seção: serve de limite da grade. */
	public function totalBeats():Float
		return sectionEndBeat(chart.sections.length - 1);
}
