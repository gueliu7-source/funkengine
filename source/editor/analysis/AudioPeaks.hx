package editor.analysis;

import core.Chart.NoteData;
import lime.media.AudioBuffer;
import openfl.media.Sound;

typedef Alignment =
{
	var median:Float; // ms; positivo = as notas estão DEPOIS dos picos de áudio
	var matched:Int;
	var total:Int;
}

/**
 * Detecção de transientes (batidas de bateria, ataques) direto dos samples do Inst, e comparação com as notas
 * do chart. Rodar sob demanda: decodifica a música inteira em memória, o que leva uma fração de segundo.
 */
class AudioPeaks
{
	public static var lastError:String = "";
	static var cache:Map<Sound, Array<Float>> = new Map();

	/** Tempos (ms) dos picos de ataque, ou null se o áudio não pôde ser lido (veja lastError). */
	public static function detect(snd:Null<Sound>):Null<Array<Float>>
	{
		if (snd == null)
		{
			lastError = "esta música não tem Inst.ogg";
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
			lastError = "não consegui acessar os samples do áudio";
			return null;
		}
		if (buf.bitsPerSample != 16)
		{
			lastError = "só áudio de 16 bits é suportado (este tem " + buf.bitsPerSample + ")";
			return null;
		}
		var ch = Std.int(Math.max(1, buf.channels));
		var data = buf.data;
		var frames = Std.int(data.length / (2 * ch));
		var hop = Std.int(Math.max(1, buf.sampleRate * 0.010)); // janelas de 10 ms
		var n = Std.int(frames / hop);
		if (n < 10)
		{
			lastError = "áudio curto demais";
			return null;
		}

		// energia do "sinal diferenciado": realça ataques e ignora notas longas e graves constantes
		var env:Array<Float> = [];
		var prev = 0.0;
		for (h in 0...n)
		{
			var sum = 0.0;
			for (i in 0...hop)
			{
				var idx = (h * hop + i) * ch * 2;
				var v = (data[idx + 1] << 8) | data[idx];
				if (v >= 32768)
					v -= 65536;
				var s = v / 32768.0;
				if (ch >= 2)
				{
					var v2 = (data[idx + 3] << 8) | data[idx + 2];
					if (v2 >= 32768)
						v2 -= 65536;
					s = (s + v2 / 32768.0) / 2;
				}
				var d = s - prev;
				prev = s;
				sum += d * d;
			}
			env.push(Math.sqrt(sum / hop));
		}

		// fluxo de energia: quanto cada janela subiu em relação às 3 anteriores
		var flux:Array<Float> = [for (_ in 0...n) 0.0];
		var maxF = 0.0;
		for (i in 3...n)
		{
			var base = (env[i - 1] + env[i - 2] + env[i - 3]) / 3;
			flux[i] = Math.max(0, env[i] - base);
			if (flux[i] > maxF)
				maxF = flux[i];
		}
		var pref:Array<Float> = [0.0];
		for (i in 0...n)
			pref.push(pref[i] + flux[i]);

		var peaks:Array<Float> = [];
		var lastMs = -1000.0;
		for (i in 3...n - 2)
		{
			var a = Std.int(Math.max(0, i - 50));
			var b = Std.int(Math.min(n, i + 50));
			var localMean = (pref[b] - pref[a]) / (b - a);
			var thr = Math.max(localMean * 2.2, maxF * 0.08);
			var f = flux[i];
			if (f > thr && f >= flux[i - 1] && f >= flux[i - 2] && f >= flux[i + 1] && f >= flux[i + 2])
			{
				var ms = i * 10.0;
				if (ms - lastMs >= 70)
				{
					peaks.push(ms);
					lastMs = ms;
				}
			}
		}
		cache.set(snd, peaks);
		lastError = "";
		return peaks;
	}

	/** Compara cada nota com o pico mais próximo (até win ms) e devolve o desvio mediano. */
	public static function alignment(notes:Array<NoteData>, peaks:Array<Float>, win:Float = 60):Alignment
	{
		var deltas:Array<Float> = [];
		var j = 0;
		for (n in notes)
		{
			while (j + 1 < peaks.length && Math.abs(peaks[j + 1] - n.time) <= Math.abs(peaks[j] - n.time))
				j++;
			if (j < peaks.length && Math.abs(peaks[j] - n.time) <= win)
				deltas.push(n.time - peaks[j]);
		}
		deltas.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		var med = deltas.length == 0 ? 0.0 : deltas[Std.int(deltas.length / 2)];
		return {median: med, matched: deltas.length, total: notes.length};
	}
}
