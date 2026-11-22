package editor.analysis;

import core.Chart.NoteData;
import lime.media.AudioBuffer;
import openfl.media.Sound;

typedef Pcm =
{
	var data:Array<Float>; // mono, reamostrado para ~11 kHz
	var rate:Float;
}

typedef Onset =
{
	var ms:Float;
	var env:Float;
	var pitch:Float; // semitons acima de 55 Hz (NaN se sem altura definida)
	var hz:Float;
	var len:Float; // ms em que o som continua depois do ataque
}

typedef GenOpts =
{
	var sens:Float; // 0..1: mais alto = mais notas
	var quant:Int; // 4, 8, 16, 32: divisão da grade para encaixar as notas
	var mode:Int; // 0 = altura (quartis), 1 = variado
	var sustains:Bool;
}

typedef Compare =
{
	var total:Int; // notas do chart
	var anchored:Int; // com um ataque de áudio por perto
	var laneOk:Int; // ... e na coluna que o guia sugeriria
	var missing:Array<Float>; // ms de sugestões sem nota
	var orphan:Array<Float>; // ms de notas sem som por perto
}

/**
 * Gerador de chart a partir do áudio: acha os ataques (sílabas, notas), mede a altura de cada um e transforma em notas.
 * Serve de GUIA (sugestões desenhadas na grade) e de GERADOR (vira notas de verdade). Sem dependência de interface.
 */
class ChartGen
{
	static var cache:Map<Sound, Pcm> = new Map();

	/** Mono de ~11 kHz a partir do buffer decodificado. null (com AudioPeaks.lastError) se não der. */
	public static function pcm(snd:Null<Sound>):Null<Pcm>
	{
		if (snd == null)
		{
			AudioPeaks.lastError = "áudio não encontrado";
			return null;
		}
		var hit = cache.get(snd);
		if (hit != null)
			return hit;
		var buf:AudioBuffer = null;
		try
			buf = @:privateAccess snd.__buffer
		catch (e:Dynamic)
			buf = null;
		if (buf == null || buf.data == null)
		{
			AudioPeaks.lastError = "não consegui acessar os samples do áudio";
			return null;
		}
		if (buf.bitsPerSample != 16)
		{
			AudioPeaks.lastError = "só áudio de 16 bits é suportado";
			return null;
		}
		var ch = Std.int(Math.max(1, buf.channels));
		var used = ch >= 2 ? 2 : 1;
		var data = buf.data;
		var frames = Std.int(data.length / (2 * ch));
		var f = Std.int(Math.max(1, Math.round(buf.sampleRate / 11025)));
		var n = Std.int(frames / f);
		if (n < 2000)
		{
			AudioPeaks.lastError = "áudio curto demais";
			return null;
		}
		var out:Array<Float> = [];
		out.resize(n);
		for (i in 0...n)
		{
			var sum = 0.0;
			for (k in 0...f)
			{
				var idx = (i * f + k) * ch * 2;
				for (c in 0...used)
				{
					var v = (data[idx + c * 2 + 1] << 8) | data[idx + c * 2];
					if (v >= 32768)
						v -= 65536;
					sum += v;
				}
			}
			out[i] = sum / (f * used * 32768.0);
		}
		var p:Pcm = {data: out, rate: buf.sampleRate / f};
		cache.set(snd, p);
		return p;
	}

	/** Altura (autocorrelação) numa janela de 50 ms a partir de `start`. NaN se não houver altura clara. */
	static function pitchAt(p:Pcm, start:Int):Float
	{
		var d = p.data;
		var lo = Std.int(p.rate / 800); // 800 Hz
		var hi = Std.int(p.rate / 80); // 80 Hz
		var win = Std.int(p.rate * 0.05);
		if (start < 0 || start + win + hi + 1 >= d.length)
			return Math.NaN;
		var e0 = 0.0;
		for (k in 0...win)
			e0 += d[start + k] * d[start + k];
		if (e0 < 1e-7)
			return Math.NaN;
		var vals:Array<Float> = [];
		var best = 0.0;
		for (lag in lo...hi + 1)
		{
			var r = 0.0;
			var e1 = 0.0;
			for (k in 0...win)
			{
				var b = d[start + k + lag];
				r += d[start + k] * b;
				e1 += b * b;
			}
			var v = e1 < 1e-9 ? 0.0 : r / Math.sqrt(e0 * e1);
			vals.push(v);
			if (v > best)
				best = v;
		}
		if (best < 0.45)
			return Math.NaN;
		// primeiro pico local perto do máximo (evita erro de oitava para baixo)
		for (i in 1...vals.length - 1)
			if (vals[i] >= best * 0.88 && vals[i] >= vals[i - 1] && vals[i] >= vals[i + 1])
				return p.rate / (lo + i);
		return Math.NaN;
	}

	public static function onsets(p:Pcm, sens:Float):Array<Onset>
	{
		var hop = Std.int(Math.max(1, Math.round(p.rate * 0.010)));
		var n = Std.int(p.data.length / hop);
		var env:Array<Float> = [];
		var maxEnv = 0.0;
		for (h in 0...n)
		{
			var s = 0.0;
			for (i in 0...hop)
			{
				var v = p.data[h * hop + i];
				s += v * v;
			}
			var e = Math.sqrt(s / hop);
			env.push(e);
			if (e > maxEnv)
				maxEnv = e;
		}
		var gate = maxEnv * 0.05;
		var le = [for (e in env) Math.log(e + 1e-5)];
		var rise:Array<Float> = [for (_ in 0...n) 0.0];
		for (i in 3...n)
			rise[i] = le[i] - (le[i - 1] + le[i - 2] + le[i - 3]) / 3;

		var thr = 1.2 + (0.35 - 1.2) * sens;
		var gap = 260 + (110 - 260) * sens;
		var out:Array<Onset> = [];
		var last = -1000.0;
		for (i in 3...n - 3)
		{
			var r = rise[i];
			if (r > thr && env[i] > gate && r >= rise[i - 1] && r >= rise[i - 2] && r >= rise[i + 1] && r >= rise[i + 2])
			{
				var ms = i * 10.0;
				if (ms - last >= gap)
				{
					var hz = pitchAt(p, i * hop + 3 * hop);
					out.push({ms: ms, env: env[i], pitch: Math.isNaN(hz) ? Math.NaN : 12 * Math.log(hz / 55) / Math.log(2), hz: hz, len: 0});
					last = ms;
				}
			}
		}
		// duração: enquanto o volume continuar acima de 35% do ataque
		for (k in 0...out.length)
		{
			var o = out[k];
			var j = Std.int(o.ms / 10) + 1;
			while (j < n && env[j] > o.env * 0.35)
				j++;
			var end = j * 10.0;
			if (k + 1 < out.length)
				end = Math.min(end, out[k + 1].ms - 40);
			o.len = Math.max(0, end - o.ms);
		}
		return out;
	}

	/** Transforma ataques em notas: encaixa na grade, escolhe lado pela seção e coluna pela altura. */
	public static function build(doc:ChartDoc, ons:Array<Onset>, o:GenOpts):Array<NoteData>
	{
		var unit = 4.0 / o.quant;
		var voiced:Array<Float> = [for (x in ons) if (!Math.isNaN(x.pitch)) x.pitch];
		voiced.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		var q1 = voiced.length > 0 ? voiced[Std.int(voiced.length * 0.25)] : 0.0;
		var q2 = voiced.length > 0 ? voiced[Std.int(voiced.length * 0.50)] : 0.0;
		var q3 = voiced.length > 0 ? voiced[Std.int(voiced.length * 0.75)] : 0.0;

		var out:Array<NoteData> = [];
		var seen:Map<String, Bool> = new Map();
		var lastLane = [1, 1]; // por lado (0 oponente, 1 jogador)
		var repeat = [0, 0];
		var lastPitch = [Math.NaN, Math.NaN];
		for (x in ons)
		{
			var beat = Math.round(doc.tempo.beatAt(x.ms) / unit) * unit;
			if (beat < 0)
				continue;
			var si = doc.sectionIndexAtBeat(beat);
			var player = doc.chart.sections[si].mustHit;
			var side = player ? 1 : 0;
			var t = doc.tempo.msAt(beat);
			var key = side + ":" + Math.round(t);
			if (seen.exists(key))
				continue;
			seen.set(key, true);

			var lane:Int;
			if (Math.isNaN(x.pitch))
				lane = repeat[side] >= 2 ? (lastLane[side] + 1) % 4 : lastLane[side];
			else
			{
				lane = x.pitch < q1 ? 0 : (x.pitch < q2 ? 1 : (x.pitch < q3 ? 2 : 3));
				if (o.mode == 1 && lane == lastLane[side] && repeat[side] >= 2)
				{
					var up = Math.isNaN(lastPitch[side]) || x.pitch >= lastPitch[side];
					lane = up ? Std.int(Math.min(3, lane + 1)) : Std.int(Math.max(0, lane - 1));
					if (lane == lastLane[side])
						lane = lane == 3 ? 2 : lane + 1;
				}
			}
			repeat[side] = lane == lastLane[side] ? repeat[side] + 1 : 0;
			lastLane[side] = lane;
			if (!Math.isNaN(x.pitch))
				lastPitch[side] = x.pitch;

			var sus = 0.0;
			if (o.sustains && x.len >= 350)
			{
				var endBeat = Math.round(doc.tempo.beatAt(x.ms + x.len) / unit) * unit;
				if (endBeat - beat >= unit * 2)
					sus = doc.tempo.msAt(endBeat) - t;
			}
			out.push(new NoteData(t, lane, player, sus, "", false, si));
		}
		out.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		return out;
	}

	/** Para cada nota sugerida: já existe nota real perto (mesma coluna e lado)? Ambos ordenados por tempo. */
	public static function coverage(real:Array<NoteData>, guide:Array<NoteData>, tol:Float = 70):Array<Bool>
	{
		var out:Array<Bool> = [];
		var j = 0;
		for (g in guide)
		{
			while (j < real.length && real[j].time < g.time - tol)
				j++;
			var ok = false;
			var k = j;
			while (k < real.length && real[k].time <= g.time + tol)
			{
				if (real[k].lane == g.lane && real[k].player == g.player)
				{
					ok = true;
					break;
				}
				k++;
			}
			out.push(ok);
		}
		return out;
	}

	/** Compara o chart atual com os ataques do áudio (tolerância em ms). */
	public static function compare(real:Array<NoteData>, ons:Array<Onset>, guide:Array<NoteData>, tol:Float = 70):Compare
	{
		var anchored = 0;
		var laneOk = 0;
		var orphan:Array<Float> = [];
		var j = 0;
		for (n in real)
		{
			while (j + 1 < ons.length && Math.abs(ons[j + 1].ms - n.time) <= Math.abs(ons[j].ms - n.time))
				j++;
			if (j < ons.length && Math.abs(ons[j].ms - n.time) <= tol)
			{
				anchored++;
				for (g in guide)
					if (Math.abs(g.time - n.time) <= tol && g.lane == n.lane && g.player == n.player)
					{
						laneOk++;
						break;
					}
			}
			else
				orphan.push(n.time);
		}
		var cov = coverage(real, guide, tol);
		var missing:Array<Float> = [];
		for (i in 0...guide.length)
			if (!cov[i])
				missing.push(guide[i].time);
		return {total: real.length, anchored: anchored, laneOk: laneOk, missing: missing, orphan: orphan};
	}
}
