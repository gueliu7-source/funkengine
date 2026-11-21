package editor;

import core.Conductor.BpmSegment;

/** Conversão entre tempo (ms), batida e step para um mapa de BPMs. Independe do Conductor do jogo. */
class TempoMap
{
	public var segs:Array<BpmSegment>;

	public function new(segs:Array<BpmSegment>)
	{
		this.segs = segs;
		rebuild();
	}

	/** Ordena por batida e recalcula o tempo em ms de cada trecho. */
	public function rebuild():Void
	{
		if (segs.length == 0)
			segs.push(new BpmSegment(0, 0, 100));
		segs.sort(function(a, b) return a.beat < b.beat ? -1 : (a.beat > b.beat ? 1 : 0));
		segs[0].beat = 0;
		segs[0].timeMs = 0;
		for (i in 1...segs.length)
		{
			var p = segs[i - 1];
			segs[i].timeMs = p.timeMs + (segs[i].beat - p.beat) * 60000 / p.bpm;
		}
	}

	function indexAtBeat(beat:Float):Int
	{
		var i = segs.length - 1;
		while (i > 0 && segs[i].beat > beat)
			i--;
		return i;
	}

	function indexAtMs(ms:Float):Int
	{
		var i = segs.length - 1;
		while (i > 0 && segs[i].timeMs > ms)
			i--;
		return i;
	}

	public function msAt(beat:Float):Float
	{
		var s = segs[indexAtBeat(beat)];
		return s.timeMs + (beat - s.beat) * 60000 / s.bpm;
	}

	public function beatAt(ms:Float):Float
	{
		var s = segs[indexAtMs(ms)];
		return s.beat + (ms - s.timeMs) * s.bpm / 60000;
	}

	public function bpmAt(beat:Float):Float
		return segs[indexAtBeat(beat)].bpm;

	/** Segmento que começa exatamente nessa batida (ou null). */
	public function segmentAt(beat:Float):Null<BpmSegment>
	{
		for (s in segs)
			if (Math.abs(s.beat - beat) < 0.0001)
				return s;
		return null;
	}

	public function clone():Array<BpmSegment>
		return [for (s in segs) new BpmSegment(s.timeMs, s.beat, s.bpm)];
}
