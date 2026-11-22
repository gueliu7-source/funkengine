package editor.analysis;

import core.Chart.NoteData;

using StringTools;

/** Um achado de análise (padrão de mão ou problema do relatório). level: 0 info, 1 atenção, 2 erro. */
typedef Finding =
{
	var ms:Float;
	var kind:String;
	var text:String;
	var level:Int;
}

typedef StaminaResult =
{
	var curve:Array<Float>; // fadiga em % por janela (pode passar de 100)
	var peak:Float;
	var peakMs:Float;
	var binMs:Float;
}

typedef DensityResult =
{
	var bins:Array<Float>; // notas por segundo, por janela
	var avg:Float;
	var peak:Float;
	var peakMs:Float;
	var binMs:Float;
}

private typedef Frame =
{
	var t:Float;
	var lanes:Array<Int>;
}

/**
 * Análises do chart, sem nenhuma dependência de interface (só dados). Tudo é calculado a partir de doc.chart,
 * então pode ser chamado de qualquer painel. side: 0 = oponente, 1 = jogador, 2 = ambos.
 */
class Analyzer
{
	/** Ajustes do simulador de fadiga (1 nota = 1 de carga; a carga cai DECAY por segundo; LIMIT = 100%). */
	public static inline var DECAY:Float = 1.6;
	public static inline var LIMIT:Float = 10;
	static inline var MAX_GAP:Float = 220; // ms entre notas para contar como "mesmo trecho"

	public static function pick(doc:ChartDoc, side:Int):Array<NoteData>
		return [for (n in doc.chart.notes) if (side == 2 || (side == 1) == n.player) n];

	// ------------------------------------------------------------------ densidade

	public static function density(notes:Array<NoteData>, lengthMs:Float, binMs:Float = 1000):DensityResult
	{
		var count = Std.int(Math.max(1, Math.ceil(lengthMs / binMs)));
		var bins:Array<Float> = [for (_ in 0...count) 0.0];
		for (n in notes)
		{
			var i = Std.int(n.time / binMs);
			if (i >= 0 && i < count)
				bins[i] += 1000 / binMs;
		}
		var peak = 0.0;
		var peakMs = 0.0;
		var sum = 0.0;
		for (i in 0...count)
		{
			sum += bins[i];
			if (bins[i] > peak)
			{
				peak = bins[i];
				peakMs = i * binMs;
			}
		}
		return {bins: bins, avg: sum / count, peak: peak, peakMs: peakMs, binMs: binMs};
	}

	// ------------------------------------------------------------------ fadiga

	static function frames(notes:Array<NoteData>):Array<Frame>
	{
		var out:Array<Frame> = [];
		for (n in notes)
		{
			var f = out.length > 0 ? out[out.length - 1] : null;
			if (f != null && Math.abs(n.time - f.t) <= 3)
			{
				if (f.lanes.indexOf(n.lane) < 0)
					f.lanes.push(n.lane);
			}
			else
				out.push({t: n.time, lanes: [n.lane]});
		}
		return out;
	}

	/** Balde furado: cada nota enche, o tempo esvazia. Acordes pesam mais, e repetir a mesma tecla rápido também. */
	public static function stamina(notes:Array<NoteData>, lengthMs:Float, binMs:Float = 500):StaminaResult
	{
		var count = Std.int(Math.max(1, Math.ceil(lengthMs / binMs)));
		var curve:Array<Float> = [for (_ in 0...count) 0.0];
		var load = 0.0;
		var t0 = 0.0;
		var peak = 0.0;
		var peakMs = 0.0;
		var prev:Null<Frame> = null;
		for (f in frames(notes))
		{
			load = Math.max(0, load - DECAY * (f.t - t0) / 1000);
			t0 = f.t;
			var w = 1 + 0.35 * (f.lanes.length - 1);
			if (prev != null && f.t - prev.t <= 150)
				for (l in f.lanes)
					if (prev.lanes.indexOf(l) >= 0)
					{
						w += 0.3;
						break;
					}
			load += w;
			var pct = load / LIMIT * 100;
			var i = Std.int(f.t / binMs);
			if (i >= 0 && i < count && pct > curve[i])
				curve[i] = pct;
			if (pct > peak)
			{
				peak = pct;
				peakMs = f.t;
			}
			prev = f;
		}
		return {curve: curve, peak: peak, peakMs: peakMs, binMs: binMs};
	}

	// ------------------------------------------------------------------ padrões de mão

	public static function patterns(notes:Array<NoteData>):Array<Finding>
	{
		var out:Array<Finding> = [];
		var fr = frames(notes);

		// acordes e saltos seguidos
		var jumpRun = 0;
		for (i in 0...fr.length)
		{
			var f = fr[i];
			if (f.lanes.length >= 3)
				out.push({ms: f.t, kind: "acorde", text: "Acorde de " + f.lanes.length + " notas", level: f.lanes.length >= 4 ? 2 : 1});
			var isJump = f.lanes.length >= 2 && (i == 0 || f.t - fr[i - 1].t <= 250);
			if (f.lanes.length >= 2)
			{
				jumpRun = isJump ? jumpRun + 1 : 1;
				if (jumpRun == 3)
					out.push({ms: fr[i - 2].t, kind: "saltos", text: "Saltos seguidos", level: 1});
			}
			else
				jumpRun = 0;
		}

		// trechos de nota única (uma mão por vez) separados por pausas
		var run:Array<Frame> = [];
		for (i in 0...fr.length + 1)
		{
			var f = i < fr.length ? fr[i] : null;
			var cut = f == null || f.lanes.length != 1 || (run.length > 0 && f.t - run[run.length - 1].t > MAX_GAP);
			if (cut)
			{
				if (run.length >= 4)
					scanRun(run, out);
				run = [];
			}
			if (f != null && f.lanes.length == 1)
				run.push(f);
		}
		out.sort(function(a, b) return a.ms < b.ms ? -1 : (a.ms > b.ms ? 1 : 0));
		return out;
	}

	static function scanRun(run:Array<Frame>, out:Array<Finding>):Void
	{
		var l = [for (f in run) f.lanes[0]];
		var i = 0;
		while (i < l.length - 1)
		{
			// trilo: a b a b a b ...
			var t = 2;
			while (i + t < l.length && l[i + t] == l[i + t - 2] && l[i + t] != l[i + t - 1] && l[i] != l[i + 1])
				t++;
			if (l[i] != l[i + 1] && t >= 6)
			{
				out.push({ms: run[i].t, kind: "trilo", text: "Trilo de " + t + " notas", level: t >= 12 ? 2 : 1});
				i += t;
				continue;
			}
			// repetição na mesma tecla
			var j = 1;
			while (i + j < l.length && l[i + j] == l[i])
				j++;
			if (j >= 4)
			{
				out.push({ms: run[i].t, kind: "repetição", text: "Mesma tecla " + j + "x seguidas", level: j >= 8 ? 2 : 1});
				i += j;
				continue;
			}
			// escada / escada invertida (passos de uma coluna)
			var k = 1;
			var rev = 0;
			var dir = 0;
			while (i + k < l.length && Math.abs(l[i + k] - l[i + k - 1]) == 1)
			{
				var d = l[i + k] - l[i + k - 1];
				if (dir != 0 && d != dir)
					rev++;
				dir = d;
				k++;
			}
			if (k >= 6 && rev >= 1)
			{
				out.push({ms: run[i].t, kind: "escada invertida", text: "Escada invertida (" + k + " notas)", level: 1});
				i += k;
				continue;
			}
			if (k >= 4 && rev == 0)
			{
				out.push({ms: run[i].t, kind: "escada", text: "Escada (" + k + " notas)", level: 0});
				i += k;
				continue;
			}
			i++;
		}
		// rolagem 0 1 2 3 0 1 2 3 (passo +1 em círculo)
		var r = 0;
		var start = 0;
		for (i in 1...l.length + 1)
		{
			var ok = i < l.length && (l[i] - l[i - 1] + 4) % 4 == 1;
			if (ok)
			{
				if (r == 0)
					start = i - 1;
				r++;
			}
			else
			{
				if (r >= 7)
					out.push({ms: run[start].t, kind: "rolagem", text: "Rolagem circular (" + (r + 1) + " notas)", level: 1});
				r = 0;
			}
		}
	}

	public static function countBy(list:Array<Finding>, kind:String):Int
	{
		var n = 0;
		for (f in list)
			if (f.kind == kind)
				n++;
		return n;
	}

	// ------------------------------------------------------------------ relatório de coesão

	static function onGrid(doc:ChartDoc, ms:Float):Bool
	{
		var beat = doc.tempo.beatAt(ms);
		for (u in [1 / 12, 1 / 16])
		{
			var snapped = doc.tempo.msAt(Math.round(beat / u) * u);
			if (Math.abs(snapped - ms) <= 3)
				return true;
		}
		return false;
	}

	public static function cohesion(doc:ChartDoc, lengthMs:Float):Array<Finding>
	{
		var out:Array<Finding> = [];
		var c = doc.chart;
		var hasLen = lengthMs > 1000;

		if (c.notes.length == 0)
			out.push({ms: 0, kind: "notas", text: "O chart não tem nenhuma nota", level: 2});

		var before = 0;
		var after = 0;
		var sustainAfter = 0;
		var off = 0;
		var firstBefore = -1.0;
		var firstAfter = -1.0;
		var firstOff = -1.0;
		var dup = 0;
		var firstDup = -1.0;
		var prev:Map<String, Float> = new Map();
		for (n in c.notes)
		{
			if (n.time < 0)
			{
				if (before++ == 0)
					firstBefore = n.time;
			}
			if (hasLen && n.time > lengthMs + 50)
			{
				if (after++ == 0)
					firstAfter = n.time;
			}
			else if (hasLen && n.time + n.sustain > lengthMs + 50)
				sustainAfter++;
			if (!onGrid(doc, n.time))
			{
				if (off++ == 0)
					firstOff = n.time;
			}
			var key = (n.player ? "p" : "o") + n.lane;
			var p = prev.get(key);
			if (p != null && Math.abs(p - n.time) <= 1)
			{
				if (dup++ == 0)
					firstDup = n.time;
			}
			prev.set(key, n.time);
		}
		if (before > 0)
			out.push({ms: 0, kind: "tempo", text: before + " nota(s) antes do início (tempo negativo)", level: 2});
		if (after > 0)
			out.push({ms: firstAfter, kind: "fim", text: after + " nota(s) depois do fim da música", level: 2});
		if (sustainAfter > 0)
			out.push({ms: Math.max(0, lengthMs - 2000), kind: "fim", text: sustainAfter + " sustain(s) passam do fim da música", level: 1});
		if (dup > 0)
			out.push({ms: firstDup, kind: "duplicada", text: dup + " nota(s) duplicada(s) (mesmo tempo e coluna)", level: 1});
		if (off > 0)
			out.push({ms: firstOff, kind: "grade", text: off + " nota(s) fora da grade 1/12 e 1/16 (podem ser intencionais)", level: 0});

		// eventos
		var transitions = ["Camera Flash", "Play Animation", "Hey!", "Screen Shake", "Camera Zoom"];
		for (e in c.events)
		{
			if (hasLen && e.time > lengthMs + 50)
				out.push({ms: e.time, kind: "evento", text: "Evento \"" + e.name + "\" depois do fim da música", level: 2});
			if (!EventRegistry.known(e.name))
			{
				out.push({ms: e.time, kind: "evento", text: "Evento \"" + e.name + "\" sem definição (só scripts tratam)", level: 0});
				continue;
			}
			var def = EventRegistry.get(e.name);
			var v1 = e.v1 == null ? "" : e.v1.trim();
			var v2 = e.v2 == null ? "" : e.v2.trim();
			if (def.params.length > 0 && v1 == "" && (def.params.length < 2 || v2 == ""))
				out.push({ms: e.time, kind: "evento", text: "Evento \"" + e.name + "\" sem parâmetros", level: 1});
			if (e.name == "Change Character")
			{
				if (v2 == "")
					out.push({ms: e.time, kind: "evento", text: "Troca de personagem sem o id do personagem", level: 2});
				var smooth = false;
				for (o in c.events)
					if (o != e && Math.abs(o.time - e.time) <= 1500 && transitions.indexOf(o.name) >= 0)
						smooth = true;
				if (!smooth)
					out.push({ms: e.time, kind: "transição", text: "Troca de personagem brusca (sem flash/animação por perto)", level: 1});
			}
		}
		var cf = doc.conflicts();
		if (cf.length > 0)
			out.push({ms: cf[0].a.time, kind: "evento", text: cf.length + " conflito(s) de eventos (" + cf[0].a.name + ")", level: 1});

		out.sort(function(a, b) return a.level != b.level ? b.level - a.level : (a.ms < b.ms ? -1 : (a.ms > b.ms ? 1 : 0)));
		return out;
	}
}
