package core;

import core.Chart;

/**
 * Mapa de posição de rolagem ("scroll velocity", como Quaver/StepMania).
 * A posição P(t) é a integral da velocidade relativa m(t) (1 = normal). Uma nota fica a
 * (P(nota) - P(agora)) × px/ms da seta, então mudar m move as notas de forma contínua e
 * sem pulo. Sem eventos P(t) = t e tudo se comporta como antes.
 *
 * Eventos do chart: "Scroll Velocity" v1 = multiplicador, v2 = duração da transição em ms (0 = instantâneo).
 * m entre dois pontos varia linearmente; antes de t=0 vale 1; depois do último ponto fica constante.
 */
class ScrollMap
{
	public static inline var EVENT:String = "Scroll Velocity";
	public static inline var MIN_MULT:Float = 0.05;

	var ts:Array<Float> = [0.0];
	var ms:Array<Float> = [1.0];
	var cum:Array<Float> = [0.0];

	public var trivial(default, null):Bool = true; // sem mudanças: P(t) = t

	public function new()
	{
	}

	public static function fromChart(c:Chart):ScrollMap
	{
		var m = new ScrollMap();
		var prev = 1.0;
		for (e in c.events) // já ordenados por tempo
		{
			if (e.name != EVENT)
				continue;
			var mult = Math.max(MIN_MULT, parse(e.v1, 1));
			var ramp = Math.max(1, parse(e.v2, 0));
			var t = Math.max(m.ts[m.ts.length - 1] + 0.001, e.time);
			m.push(t, prev); // segura a velocidade anterior até o início da transição
			m.push(t + ramp, mult);
			prev = mult;
		}
		m.trivial = m.ts.length == 1;
		return m;
	}

	static function parse(s:String, def:Float):Float
	{
		var v = Std.parseFloat(s);
		return Math.isNaN(v) ? def : v;
	}

	function push(t:Float, m:Float):Void
	{
		var last = ts.length - 1;
		if (t <= ts[last])
			t = ts[last] + 0.001;
		cum.push(cum[last] + (ms[last] + m) * 0.5 * (t - ts[last]));
		ts.push(t);
		ms.push(m);
	}

	/** Posição de rolagem (em "ms equivalentes") para o tempo t. */
	public function at(t:Float):Float
	{
		if (trivial || t <= 0)
			return t;
		var lo = 0;
		var hi = ts.length - 1;
		while (lo < hi)
		{
			var mid = (lo + hi + 1) >> 1;
			if (ts[mid] <= t)
				lo = mid;
			else
				hi = mid - 1;
		}
		var dt = t - ts[lo];
		if (lo == ts.length - 1)
			return cum[lo] + ms[lo] * dt;
		var span = ts[lo + 1] - ts[lo];
		return cum[lo] + ms[lo] * dt + (ms[lo + 1] - ms[lo]) / (2 * span) * dt * dt;
	}

	/** Multiplicador instantâneo no tempo t (para o F3). */
	public function multAt(t:Float):Float
	{
		if (trivial || t <= 0)
			return 1;
		var lo = 0;
		while (lo + 1 < ts.length && ts[lo + 1] <= t)
			lo++;
		if (lo == ts.length - 1)
			return ms[lo];
		return ms[lo] + (ms[lo + 1] - ms[lo]) * (t - ts[lo]) / (ts[lo + 1] - ts[lo]);
	}
}
