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

typedef EventConflict =
{
	var a:EventData;
	var b:EventData;
	var reason:String;
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

	// ------------------------------------------------------------ marcadores de estrutura

	function sortMarkers():Void
		chart.markers.sort(function(a, b) return a.beat < b.beat ? -1 : (a.beat > b.beat ? 1 : 0));

	/** Desloca todas as notas e eventos por delta ms (alinhamento com o áudio). */
	public function shiftTimes(delta:Float):Void
	{
		var ns = [for (n in chart.notes) n.time];
		var es = [for (e in chart.events) e.time];
		run(new Cmd("alinhar " + Math.round(delta * 10) / 10 + " ms", function() {
			for (n in chart.notes)
				n.time = Math.max(0, n.time + delta);
			for (e in chart.events)
				e.time = Math.max(0, e.time + delta);
		}, function() {
			for (i in 0...chart.notes.length)
				chart.notes[i].time = ns[i];
			for (i in 0...chart.events.length)
				chart.events[i].time = es[i];
		}));
	}

	/** Troca todas as notas de uma vez (gerador). */
	public function replaceAllNotes(list:Array<core.Chart.NoteData>, name:String):Void
	{
		var old = chart.notes.copy();
		run(new Cmd(name, function() {
			chart.notes = list.copy();
		}, function() {
			chart.notes = old.copy();
		}));
	}

	/** Soma notas novas às existentes, sem duplicar (mesmo tempo, coluna e lado). */
	public function mergeNotes(list:Array<core.Chart.NoteData>, name:String):Int
	{
		var old = chart.notes.copy();
		var merged = old.copy();
		var added = 0;
		for (n in list)
		{
			var dup = false;
			for (o in old)
				if (Math.abs(o.time - n.time) <= 1 && o.lane == n.lane && o.player == n.player)
				{
					dup = true;
					break;
				}
			if (!dup)
			{
				merged.push(n);
				added++;
			}
		}
		merged.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		run(new Cmd(name, function() {
			chart.notes = merged.copy();
		}, function() {
			chart.notes = old.copy();
		}));
		return added;
	}

	public function addMarker(beat:Float, name:String, color:String):Void
	{
		var m:core.Chart.ChartMarker = {beat: beat, name: name, color: color};
		run(new Cmd("marcador " + name, function() {
			chart.markers.push(m);
			sortMarkers();
		}, function() {
			chart.markers.remove(m);
		}));
	}

	public function removeMarker(m:core.Chart.ChartMarker):Void
	{
		run(new Cmd("remover marcador", function() {
			chart.markers.remove(m);
		}, function() {
			chart.markers.push(m);
			sortMarkers();
		}));
	}

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

	public function removeNotes(list:Array<NoteData>):Void
	{
		if (list.length == 0)
			return;
		var l = list.copy();
		run(new Cmd(l.length == 1 ? "remover nota" : "remover " + l.length + " notas", function() {
			for (n in l)
				chart.notes.remove(n);
		}, function() {
			for (n in l)
				chart.notes.push(n);
		}));
	}

	/** Coluna de uma nota na grade: 0-3 oponente, 4-7 jogador. */
	public static inline function colOf(n:NoteData):Int
		return n.lane + (n.player ? 4 : 0);

	/** Move várias notas de uma vez (um único passo no histórico). Devolve false se não houve movimento. */
	public function moveNotes(list:Array<NoteData>, dBeat:Float, dCol:Int):Bool
	{
		if (list.length == 0)
			return false;
		var minB = 1e9;
		var minC = 99;
		var maxC = -99;
		for (n in list)
		{
			minB = Math.min(minB, beatOf(n));
			minC = Std.int(Math.min(minC, colOf(n)));
			maxC = Std.int(Math.max(maxC, colOf(n)));
		}
		dBeat = Math.max(dBeat, -minB);
		dCol = Std.int(Math.max(dCol, -minC));
		dCol = Std.int(Math.min(dCol, 7 - maxC));
		if (Math.abs(dBeat) < 0.0001 && dCol == 0)
			return false;
		var l = list.copy();
		var oT:Array<Float> = [];
		var oS:Array<Float> = [];
		var oL:Array<Int> = [];
		var oP:Array<Bool> = [];
		var nT:Array<Float> = [];
		var nS:Array<Float> = [];
		var nL:Array<Int> = [];
		var nP:Array<Bool> = [];
		for (n in l)
		{
			var b = beatOf(n);
			var sb = n.sustain > 0 ? tempo.beatAt(n.time + n.sustain) - b : 0;
			var t = tempo.msAt(b + dBeat);
			var c = colOf(n) + dCol;
			oT.push(n.time);
			oS.push(n.sustain);
			oL.push(n.lane);
			oP.push(n.player);
			nT.push(t);
			nS.push(sb > 0 ? tempo.msAt(b + dBeat + sb) - t : 0);
			nL.push(c % 4);
			nP.push(c >= 4);
		}
		run(new Cmd(l.length == 1 ? "mover nota" : "mover " + l.length + " notas", function() {
			for (i in 0...l.length)
			{
				l[i].time = nT[i];
				l[i].sustain = nS[i];
				l[i].lane = nL[i];
				l[i].player = nP[i];
			}
		}, function() {
			for (i in 0...l.length)
			{
				l[i].time = oT[i];
				l[i].sustain = oS[i];
				l[i].lane = oL[i];
				l[i].player = oP[i];
			}
		}));
		return true;
	}

	/** Copia uma lista de notas; as posições ficam relativas à primeira. */
	public function copyList(list:Array<NoteData>):Array<ClipNote>
	{
		var first = 1e9;
		for (n in list)
			first = Math.min(first, beatOf(n));
		var out:Array<ClipNote> = [];
		for (n in list)
		{
			var b = beatOf(n);
			out.push({
				beat: b - first,
				lane: n.lane,
				player: n.player,
				sustain: n.sustain > 0 ? tempo.beatAt(n.time + n.sustain) - b : 0,
				type: n.type,
				alt: n.alt
			});
		}
		return out;
	}

	/** Cola notas copiadas com copyList a partir de atBeat. Devolve as notas criadas. */
	public function pasteNotes(clip:Array<ClipNote>, atBeat:Float):Array<NoteData>
	{
		var made:Array<NoteData> = [];
		var end = totalBeats();
		for (c in clip)
		{
			var b = atBeat + c.beat;
			if (b >= end)
				continue;
			var t = tempo.msAt(b);
			var sus = c.sustain > 0 ? tempo.msAt(b + c.sustain) - t : 0;
			made.push(new NoteData(t, c.lane, c.player, sus, c.type, c.alt, 0));
		}
		if (made.length == 0)
			return made;
		run(new Cmd(made.length == 1 ? "colar nota" : "colar " + made.length + " notas", function() {
			for (n in made)
				chart.notes.push(n);
		}, function() {
			for (n in made)
				chart.notes.remove(n);
		}));
		return made;
	}

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

	// ------------------------------------------------------------ eventos

	public function eventBeat(e:EventData):Float
		return tempo.beatAt(e.time);

	public function addEvent(beat:Float, name:String, v1:String, v2:String):EventData
	{
		var e = new EventData(tempo.msAt(beat), name, v1, v2);
		run(new Cmd("adicionar evento", function() chart.events.push(e), function() chart.events.remove(e)));
		return e;
	}

	public function removeEvent(e:EventData):Void
		run(new Cmd("remover evento", function() chart.events.remove(e), function() chart.events.push(e)));

	public function setEventFields(e:EventData, name:String, v1:String, v2:String):Void
	{
		var on = e.name;
		var o1 = e.v1;
		var o2 = e.v2;
		if (on == name && o1 == v1 && o2 == v2)
			return;
		run(new Cmd("editar evento", function() {
			e.name = name;
			e.v1 = v1;
			e.v2 = v2;
		}, function() {
			e.name = on;
			e.v1 = o1;
			e.v2 = o2;
		}));
	}

	public function moveEventLive(e:EventData, beat:Float):Void
	{
		e.time = tempo.msAt(Math.max(0, beat));
		version++;
		dirty = true;
	}

	public function commitEventMove(e:EventData, oldTime:Float):Void
	{
		var now = e.time;
		if (Math.abs(now - oldTime) < 0.5)
			return;
		undoStack.push(new Cmd("mover evento", function() e.time = now, function() e.time = oldTime));
		redoStack = [];
		changed();
	}

	public function eventsIn(beatA:Float, beatB:Float):Array<EventData>
	{
		var a = tempo.msAt(beatA) - 0.5;
		var b = tempo.msAt(beatB) - 0.5;
		return [for (e in chart.events) if (e.time >= a && e.time < b) e];
	}

	var conflictVersion:Int = -1;
	var conflictCache:Array<EventConflict> = [];

	/** Eventos iguais no mesmo step (ou colados, a menos de meia batida): podem causar tranco visual. */
	public function conflicts():Array<EventConflict>
	{
		if (conflictVersion == version)
			return conflictCache;
		conflictVersion = version;
		conflictCache = [];
		var ev = chart.events;
		for (i in 0...ev.length)
		{
			var bi = eventBeat(ev[i]);
			var j = i + 1;
			while (j < ev.length && eventBeat(ev[j]) - bi < 0.5)
			{
				if (ev[j].name == ev[i].name)
				{
					var same = (eventBeat(ev[j]) - bi) < 0.25;
					conflictCache.push({a: ev[i], b: ev[j], reason: same ? "mesmo step" : "muito colados"});
				}
				j++;
			}
		}
		return conflictCache;
	}

	public function inConflict(e:EventData):Bool
	{
		for (c in conflicts())
			if (c.a == e || c.b == e)
				return true;
		return false;
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
