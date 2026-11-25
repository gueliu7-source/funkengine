package core;

import core.Chart;
import core.Conductor.BpmSegment;

/**
 * Formato próprio de chart do FunkForge: ".ffc" (texto em linhas, campos separados por TAB, sem JSON).
 *
 *   #FFC 1                              cabeçalho com a versão
 *   name <nome>                         speed <vel>      offset <ms>      voices <0|1>      style <estilo>
 *   chars <jogador> <oponente> <gf> <stage>
 *   over <char> <loop> <fim> <som>      (game over, opcional)
 *   bpm <beat> <ms> <bpm>               uma linha por mudança de BPM
 *   sec <beat> <ms> <steps> <flags>     flags: m = mustHit, a = alt, - = nenhum
 *   n <ms> <coluna 0-7> <sustain ms> <seção> <flags> <tipo> <vel>   coluna: 0-3 oponente, 4-7 jogador; flags: a = alt;
 *                                       vel = velocidade só desta nota (vazio = a do jogo)
 *   e <ms> <nome> <v1> <v2>             evento
 *   k <beat> <cor> <nome>               marcador
 *
 * Textos usam \t \n \r \\ como escape. Linhas começando com # (menos o cabeçalho) são comentários.
 * Campos que faltam no fim da linha valem o padrão, então versões novas continuam legíveis por versões antigas.
 */
class ChartFormat
{
	public static inline var MAGIC:String = "#FFC";
	public static inline var VERSION:Int = 1;

	public static function isFfc(text:Null<String>):Bool
		return text != null && StringTools.startsWith(StringTools.ltrim(text), MAGIC);

	static function esc(s:String):String
	{
		if (s == null)
			return "";
		return s.split("\\").join("\\\\").split("\t").join("\\t").split("\n").join("\\n").split("\r").join("\\r");
	}

	static function unesc(s:String):String
	{
		if (s.indexOf("\\") < 0)
			return s;
		var b = new StringBuf();
		var i = 0;
		while (i < s.length)
		{
			var ch = s.charAt(i);
			if (ch == "\\" && i + 1 < s.length)
			{
				var nx = s.charAt(i + 1);
				b.add(switch (nx)
				{
					case "t": "\t";
					case "n": "\n";
					case "r": "\r";
					default: nx;
				});
				i += 2;
			}
			else
			{
				b.add(ch);
				i++;
			}
		}
		return b.toString();
	}

	static inline function f(v:Float):String
		return Std.string(Math.round(v * 100) / 100);

	static function put(b:StringBuf, fields:Array<String>):Void
	{
		b.add([for (x in fields) esc(x)].join("\t"));
		b.add("\n");
	}

	public static function write(c:Chart):String
	{
		var b = new StringBuf();
		b.add(MAGIC + " " + VERSION + "\n");
		put(b, ["name", c.name]);
		put(b, ["speed", Std.string(c.speed)]);
		put(b, ["offset", f(c.offset)]);
		put(b, ["voices", c.needsVoices ? "1" : "0"]);
		put(b, ["style", c.noteStyle]);
		put(b, ["chars", c.player1, c.player2, c.gf, c.stage]);
		if (c.gameOverChar != "" || c.gameOverLoop != "" || c.gameOverEnd != "" || c.gameOverSound != "")
			put(b, ["over", c.gameOverChar, c.gameOverLoop, c.gameOverEnd, c.gameOverSound]);
		for (s in c.segments)
			put(b, ["bpm", f(s.beat), f(s.timeMs), Std.string(s.bpm)]);
		for (s in c.sections)
			put(b, ["sec", f(s.startBeat), f(s.startMs), Std.string(s.steps), (s.mustHit ? "m" : "") + (s.alt ? "a" : "") + ((s.mustHit || s.alt) ? "" : "-")]);
		for (n in c.notes)
			put(b, [
				"n",
				f(n.time),
				Std.string(n.lane + (n.player ? 4 : 0)),
				f(n.sustain),
				Std.string(n.section),
				n.alt ? "a" : "-",
				n.type,
				n.scrollSpeed == null ? "" : Std.string(n.scrollSpeed)
			]);
		for (e in c.events)
			put(b, ["e", f(e.time), e.name, e.v1, e.v2]);
		for (m in c.markers)
			put(b, ["k", Std.string(m.beat), m.color, m.name]);
		return b.toString();
	}

	static inline function fl(p:Array<String>, i:Int, def:Float):Float
	{
		if (i >= p.length || p[i] == "")
			return def;
		var v = Std.parseFloat(p[i]);
		return Math.isNaN(v) ? def : v;
	}

	static inline function st(p:Array<String>, i:Int, def:String):String
		return i < p.length ? unesc(p[i]) : def;

	public static function read(id:String, text:String):Chart
	{
		var c = new Chart();
		c.id = id;
		for (raw in text.split("\n"))
		{
			var line = raw;
			if (line.length > 0 && line.charCodeAt(line.length - 1) == 13)
				line = line.substr(0, line.length - 1);
			if (line == "" || line.charAt(0) == "#")
				continue;
			var p = line.split("\t");
			switch (p[0])
			{
				case "name":
					c.name = st(p, 1, "");
				case "speed":
					c.speed = fl(p, 1, 1);
				case "offset":
					c.offset = fl(p, 1, 0);
				case "voices":
					c.needsVoices = st(p, 1, "1") != "0";
				case "style":
					c.noteStyle = st(p, 1, "normal");
				case "chars":
					c.player1 = st(p, 1, "bf");
					c.player2 = st(p, 2, "dad");
					c.gf = st(p, 3, "gf");
					c.stage = st(p, 4, "stage");
				case "over":
					c.gameOverChar = st(p, 1, "");
					c.gameOverLoop = st(p, 2, "");
					c.gameOverEnd = st(p, 3, "");
					c.gameOverSound = st(p, 4, "");
				case "bpm":
					c.segments.push(new BpmSegment(fl(p, 2, 0), fl(p, 1, 0), fl(p, 3, 100)));
				case "sec":
					var fg = st(p, 4, "-");
					c.sections.push(new SectionData(fl(p, 2, 0), fl(p, 1, 0), Std.int(fl(p, 3, 16)), fg.indexOf("m") >= 0, fg.indexOf("a") >= 0));
				case "n":
					var col = Std.int(fl(p, 2, 0));
					var n = new NoteData(fl(p, 1, 0), col % 4, col >= 4, fl(p, 3, 0), st(p, 6, ""), st(p, 5, "-").indexOf("a") >= 0, Std.int(fl(p, 4, 0)));
					if (p.length > 7 && p[7] != "")
						n.scrollSpeed = fl(p, 7, 1);
					c.notes.push(n);
				case "e":
					c.events.push(new EventData(fl(p, 1, 0), st(p, 2, ""), st(p, 3, ""), st(p, 4, "")));
				case "k":
					c.markers.push({beat: fl(p, 1, 0), color: st(p, 2, "FFFFFF"), name: st(p, 3, "")});
				default: // linha desconhecida (de uma versão mais nova): ignora
			}
		}
		if (c.segments.length == 0)
			c.segments.push(new BpmSegment(0, 0, 100));
		c.bpm = c.segments[0].bpm;
		return c;
	}
}
