package core;

import core.Conductor.BpmSegment;
import game.NoteSprite;
import haxe.Json;

using StringTools;

/** Marcador de estrutura musical (Intro, Verso, Refrão...). Cor em hex "RRGGBB". */
typedef ChartMarker =
{
	var beat:Float;
	var name:String;
	var color:String;
}

/** Uma nota do chart (dado puro; o sprite só existe enquanto a nota está na tela). */
class NoteData
{
	public var time:Float; // ms
	public var lane:Int; // 0..3
	public var player:Bool; // true = jogador, false = oponente
	public var sustain:Float; // ms (0 = nota simples)
	public var type:String; // tipo de nota para scripts ("" = normal)
	public var alt:Bool; // usa animação alternativa
	public var section:Int;

	// ajustes feitos por scripts Psych (setPropertyFromGroup('notes'/'unspawnNotes', i, ...))
	public var id:Int = 0; // posição em chart.notes
	public var yOff:Float = 0;
	public var nAlpha:Float = 1;
	public var nVisible:Bool = true;
	public var texture:String = "";
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var noAnim:Bool = false;
	public var scrollSpeed:Null<Float> = null; // velocidade só desta nota (estilo Codename); null = a da seta/jogo

	// estado de jogo
	public var spawned:Bool = false;
	public var hit:Bool = false;
	public var missed:Bool = false;
	public var holding:Bool = false;
	public var dropped:Bool = false;
	public var done:Bool = false;

	public var head:NoteSprite;
	public var body:NoteSprite;
	public var tail:NoteSprite;

	public function new(time:Float, lane:Int, player:Bool, sustain:Float, type:String, alt:Bool, section:Int)
	{
		this.time = time;
		this.lane = lane;
		this.player = player;
		this.sustain = sustain;
		this.type = type;
		this.alt = alt;
		this.section = section;
	}
}

class SectionData
{
	public var startMs:Float;
	public var startBeat:Float;
	public var steps:Int;
	public var mustHit:Bool;
	public var alt:Bool;

	public function new(startMs:Float, startBeat:Float, steps:Int, mustHit:Bool, alt:Bool)
	{
		this.startMs = startMs;
		this.startBeat = startBeat;
		this.steps = steps;
		this.mustHit = mustHit;
		this.alt = alt;
	}
}

class EventData
{
	public var time:Float;
	public var name:String;
	public var v1:String;
	public var v2:String;
	public var done:Bool = false;

	public function new(time:Float, name:String, v1:String, v2:String)
	{
		this.time = time;
		this.name = name;
		this.v1 = v1;
		this.v2 = v2;
	}
}

class Chart
{
	public var id:String = "";
	public var name:String = "";
	public var bpm:Float = 100;
	public var speed:Float = 1;
	public var needsVoices:Bool = true;
	public var player1:String = "bf";
	public var player2:String = "dad";
	public var gf:String = "gf";
	public var stage:String = "stage";
	public var noteStyle:String = "normal";
	public var offset:Float = 0;
	public var notes:Array<NoteData> = [];
	public var sections:Array<SectionData> = [];
	public var segments:Array<BpmSegment> = [];
	public var events:Array<EventData> = [];
	public var markers:Array<ChartMarker> = [];
	public var gameOverChar:String = ""; // campos do Psych: personagem/música da tela de game over
	public var gameOverLoop:String = "";
	public var gameOverEnd:String = "";
	public var gameOverSound:String = "";

	public function new()
	{
	}

	public function sectionStartBeats():Array<Float>
		return [for (s in sections) s.startBeat];
}

/**
 * Carrega charts. Aceita o formato legado (FNF/Kade: song.notes[].sectionNotes)
 * e o formato "funkforge-2" gerado por tools/convert_charts.py.
 */
class ChartLoader
{
	/** suffix: "" (normal), "-easy" ou "-hard". */
	public static function load(id:String, suffix:String = "", week:Int = 0):Null<Chart>
	{
		var text = Paths.getText('data/songs/$id/$id$suffix.json');
		if (text == null)
			text = Paths.getText('data/songs/$id/$id.json');
		if (text == null)
		{
			trace('[Chart] chart não encontrado: $id$suffix');
			return null;
		}

		var meta:Dynamic = null;
		var metaText = Paths.getText('data/songs/$id/_meta.json');
		if (metaText != null)
		{
			try
				meta = Json.parse(extractJson(metaText))
			catch (e:Dynamic)
				trace('[Chart] _meta.json inválido em $id');
		}

		var json:Dynamic = Json.parse(extractJson(text));
		var chart:Chart = (Reflect.field(json, "format") == "funkforge-2") ? fromV2(id, json) : fromLegacy(id, json, week);

		if (meta != null)
		{
			if (Reflect.field(meta, "name") != null)
				chart.name = Reflect.field(meta, "name");
			if (Reflect.field(meta, "offset") != null)
				chart.offset = Reflect.field(meta, "offset");
		}
		if (chart.name == "")
			chart.name = id.replace("-", " ");

		finish(chart);
		return chart;
	}

	/**
	 * Alguns charts têm lixo depois do JSON (ex.: ridge.json). Pega só o primeiro
	 * objeto {...} balanceado, ignorando chaves dentro de strings.
	 */
	public static function extractJson(text:String):String
	{
		var start = text.indexOf("{");
		if (start < 0)
			return text;
		var depth = 0;
		var inStr = false;
		var esc = false;
		for (i in start...text.length)
		{
			var c = text.charCodeAt(i);
			if (inStr)
			{
				if (esc)
					esc = false;
				else if (c == 92)
					esc = true;
				else if (c == 34)
					inStr = false;
			}
			else if (c == 34)
				inStr = true;
			else if (c == 123)
				depth++;
			else if (c == 125)
			{
				depth--;
				if (depth == 0)
					return text.substring(start, i + 1);
			}
		}
		return text.substring(start);
	}

	static function stageForWeek(week:Int, id:String):String
	{
		return switch (week)
		{
			case 2: "halloween";
			case 3: "philly";
			case 4: "limo";
			case 5: id == "winter-horrorland" ? "mallEvil" : "mall";
			case 6: id == "thorns" ? "schoolEvil" : "school";
			default: "stage";
		}
	}

	static function gfForWeek(week:Int):String
	{
		return switch (week)
		{
			case 4: "gf-car";
			case 5: "gf-christmas";
			case 6: "gf-pixel";
			default: "gf";
		}
	}

	static function fromLegacy(id:String, json:Dynamic, week:Int):Chart
	{
		// alguns charts (smash.json) guardam os campos direto na raiz
		var s:Dynamic = json;
		if (Reflect.field(json, "song") != null && !Std.isOfType(Reflect.field(json, "song"), String))
			s = Reflect.field(json, "song");

		var c = new Chart();
		c.id = id;
		c.bpm = num(Reflect.field(s, "bpm"), 100);
		c.speed = num(Reflect.field(s, "speed"), 1);
		c.needsVoices = Reflect.field(s, "needsVoices") != false;
		c.player1 = str(Reflect.field(s, "player1"), "bf");
		c.player2 = str(Reflect.field(s, "player2"), "dad");
		c.gf = str(Reflect.field(s, "gfVersion"), gfForWeek(week));
		c.stage = str(Reflect.field(s, "stage"), stageForWeek(week, id));
		c.noteStyle = str(Reflect.field(s, "noteStyle"), week == 6 ? "pixel" : "normal");

		var curBpm = c.bpm;
		var timeMs = 0.0;
		var beat = 0.0;
		c.segments.push(new BpmSegment(0, 0, curBpm));

		var secs:Array<Dynamic> = Reflect.field(s, "notes");
		if (secs == null)
			secs = [];

		for (i in 0...secs.length)
		{
			var sec:Dynamic = secs[i];
			var changes = Reflect.field(sec, "changeBPM") == true;
			var secBpm = num(Reflect.field(sec, "bpm"), curBpm);
			if (changes && secBpm > 0 && secBpm != curBpm)
			{
				curBpm = secBpm;
				c.segments.push(new BpmSegment(timeMs, beat, curBpm));
			}

			var beatsPsych = Reflect.field(sec, "sectionBeats"); // formato do Psych: seção em beats
			var steps = Std.int(num(Reflect.field(sec, "lengthInSteps"), beatsPsych != null ? num(beatsPsych, 4) * 4 : 16));
			var mustHit = Reflect.field(sec, "mustHitSection") == true;
			var alt = Reflect.field(sec, "altAnim") == true;
			c.sections.push(new SectionData(timeMs, beat, steps, mustHit, alt));

			var list:Array<Dynamic> = Reflect.field(sec, "sectionNotes");
			if (list != null)
			{
				for (n in list)
				{
					var raw = Std.int(num(n[1], 0));
					if (raw < 0)
						continue; // notas-evento antigas
					var t:Float = num(n[0], 0);
					var sus:Float = n.length > 2 ? num(n[2], 0) : 0;
					var type = (n.length > 3 && Std.isOfType(n[3], String)) ? (n[3] : String) : "";
					var player = raw > 3 ? !mustHit : mustHit; // regra do FNF: lane 4-7 inverte o lado da seção
					var noteAlt = (alt && !player) || type == "Alt Animation"; // tipo "Alt Animation" do Psych
					c.notes.push(new NoteData(t, raw % 4, player, sus > 0 ? sus : 0, type, noteAlt, i));
				}
			}

			var stepMs = 60000 / curBpm / 4;
			timeMs += steps * stepMs;
			beat += steps / 4;
		}

		// eventos no formato do Psych: [tempo_ms, [[nome, valor1, valor2], ...]]
		var evs:Array<Dynamic> = Reflect.field(s, "events");
		if (evs == null)
			evs = Reflect.field(json, "events");
		if (evs != null)
			for (e in evs)
			{
				if (e == null || e.length < 2 || !Std.isOfType(e[1], Array))
					continue;
				for (sub in (e[1] : Array<Dynamic>))
					c.events.push(new EventData(num(e[0], 0), str(sub[0], ""), str(sub[1], ""), str(sub[2], "")));
			}
		c.gameOverChar = str(Reflect.field(s, "gameOverChar"), "");
		c.gameOverLoop = str(Reflect.field(s, "gameOverLoop"), "");
		c.gameOverEnd = str(Reflect.field(s, "gameOverEnd"), "");
		c.gameOverSound = str(Reflect.field(s, "gameOverSound"), "");
		return c;
	}

	static function fromV2(id:String, j:Dynamic):Chart
	{
		var c = new Chart();
		c.id = id;
		c.name = str(j.name, "");
		c.bpm = num(j.bpm, 100);
		c.speed = num(j.speed, 1);
		c.needsVoices = j.needsVoices != false;
		c.player1 = str(j.player1, "bf");
		c.player2 = str(j.player2, "dad");
		c.gf = str(j.gf, "gf");
		c.stage = str(j.stage, "stage");
		c.noteStyle = str(j.noteStyle, "normal");

		for (b in (j.bpmChanges : Array<Dynamic>))
			c.segments.push(new BpmSegment(num(b.time, 0), num(b.beat, 0), num(b.bpm, 100)));
		if (c.segments.length == 0)
			c.segments.push(new BpmSegment(0, 0, c.bpm));

		for (s in (j.sections : Array<Dynamic>))
			c.sections.push(new SectionData(num(s.start, 0), num(s.beat, 0), Std.int(num(s.steps, 16)), s.mustHit == true, s.alt == true));

		// notas: [tempo_ms, lane, jogador(0/1), sustain_ms, tipo, seção, alt(0/1)]
		for (n in (j.notes : Array<Dynamic>))
			c.notes.push(new NoteData(num(n[0], 0), Std.int(num(n[1], 0)), num(n[2], 0) == 1, num(n[3], 0), str(n[4], ""), num(n[6], 0) == 1,
				Std.int(num(n[5], 0))));

		var ev:Array<Dynamic> = j.events;
		if (ev != null)
			for (e in ev)
				c.events.push(new EventData(num(e[0], 0), str(e[1], ""), str(e[2], ""), str(e[3], "")));
		var mk:Array<Dynamic> = Reflect.field(j, "markers");
		if (mk != null)
			for (m in mk)
				c.markers.push({beat: num(m.beat, 0), name: str(m.name, ""), color: str(m.color, "FFFFFF")});
		return c;
	}

	/** Ordena e remove notas duplicadas (mesmo tempo, lane e lado). */
	static function finish(c:Chart):Void
	{
		c.notes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		var out:Array<NoteData> = [];
		for (n in c.notes)
		{
			var dup = false;
			var k = out.length - 1;
			while (k >= 0 && n.time - out[k].time < 1)
			{
				if (out[k].lane == n.lane && out[k].player == n.player)
				{
					dup = true;
					break;
				}
				k--;
			}
			if (!dup)
				out.push(n);
		}
		c.notes = out;
		c.events.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		if (c.sections.length == 0)
			c.sections.push(new SectionData(0, 0, 16, true, false));
	}

	static inline function num(v:Dynamic, def:Float):Float
		return (v == null) ? def : (Std.isOfType(v, Bool) ? def : (v : Float));

	static inline function str(v:Dynamic, def:String):String
		return (v == null) ? def : Std.string(v);
}
