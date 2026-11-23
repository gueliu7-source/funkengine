package editor.stage;

import core.Chart.EventData;
import core.Chart.NoteData;
import core.Paths;
import flixel.FlxG;
import flixel.sound.FlxSound;

using StringTools;

/**
 * Música + chart dentro do Stage Editor (só leitura do chart). Cuida do relógio de reprodução, loop de trecho e de avisar
 * quem quiser reagir: notas (personagens cantam), batidas (dançam) e o foco de câmera das seções.
 */
class StageSong
{
	/** Última música carregada: reabre sozinha ao trocar de stage dentro do editor. */
	public static var lastId:String = "";
	public static var lastSuffix:String = "";

	public var id:String = "";
	public var suffix:String = "";
	public var doc:Null<ChartDoc>;
	public var hasAudio:Bool = false;
	public var ms:Float = 0;
	public var lengthMs:Float = 0;
	public var playing:Bool = false;
	public var loopOn:Bool = false;
	public var loopA:Float = 0;
	public var loopB:Float = 0;

	public var onNote:NoteData->Bool->Float->Void; // nota, usa alt, passo em segundos
	public var onBeat:Int->Void;

	public var loaded(get, never):Bool;

	var inst:FlxSound;
	var voices:FlxSound;
	var hasVoices:Bool = false;
	var hitIdx:Int = 0;
	var lastBeat:Int = -999;

	function get_loaded():Bool
		return doc != null;

	public function new() {}

	/** Carrega a música e o chart. Devolve uma mensagem de problema ou null se deu certo. */
	public function load(id:String, suffix:String):Null<String>
	{
		unload();
		var s = Paths.song(id, "Inst");
		inst = new FlxSound();
		if (s != null)
			inst.loadEmbedded(s);
		FlxG.sound.list.add(inst);
		voices = new FlxSound();
		var v = Paths.song(id, "Voices");
		hasVoices = v != null;
		if (v != null)
			voices.loadEmbedded(v);
		FlxG.sound.list.add(voices);
		hasAudio = s != null;
		lengthMs = hasAudio ? inst.length : 0;
		try
			doc = ChartIO.open(id, suffix, lengthMs)
		catch (e:Dynamic)
		{
			trace('[StageSong] chart inválido: $e');
			doc = null;
			return "não consegui ler o chart de " + id;
		}
		if (!hasAudio)
			lengthMs = doc.tempo.msAt(doc.totalBeats());
		this.id = id;
		this.suffix = suffix;
		lastId = id;
		lastSuffix = suffix;
		loopA = 0;
		loopB = 0;
		seek(0);
		return hasAudio ? null : "sem Inst.ogg: só o chart será usado (sem áudio)";
	}

	public function unload():Void
	{
		if (inst != null)
		{
			inst.stop();
			FlxG.sound.list.remove(inst);
			inst.destroy();
		}
		if (voices != null)
		{
			voices.stop();
			FlxG.sound.list.remove(voices);
			voices.destroy();
		}
		inst = null;
		voices = null;
		doc = null;
		playing = false;
		ms = 0;
	}

	// ------------------------------------------------------------------ transporte

	public function play():Void
	{
		if (doc == null || lengthMs <= 0)
			return;
		if (ms >= lengthMs - 50)
			ms = 0;
		if (hasAudio)
		{
			inst.play(true, ms);
			if (hasVoices && doc.chart.needsVoices)
				voices.play(true, ms);
		}
		hitIdx = doc.lowerBound(ms);
		lastBeat = Math.floor(doc.tempo.beatAt(ms));
		playing = true;
	}

	public function pause():Void
	{
		if (inst != null)
			inst.pause();
		if (voices != null)
			voices.pause();
		playing = false;
	}

	public function toggle():Void
	{
		if (playing)
			pause();
		else
			play();
	}

	public function seek(t:Float):Void
	{
		if (doc == null)
			return;
		ms = Math.max(0, Math.min(lengthMs, t));
		if (playing && hasAudio)
		{
			inst.time = ms;
			if (hasVoices && doc.chart.needsVoices)
				voices.time = ms;
		}
		hitIdx = doc.lowerBound(ms);
		lastBeat = Math.floor(doc.tempo.beatAt(ms));
	}

	public function sectionIndex():Int
		return doc == null ? 0 : doc.sectionIndexAtBeat(Math.max(0, doc.tempo.beatAt(ms)));

	public function gotoSection(i:Int):Void
	{
		if (doc == null)
			return;
		i = Std.int(Math.max(0, Math.min(doc.chart.sections.length - 1, i)));
		seek(doc.chart.sections[i].startMs);
	}

	public function stepBeats(dir:Int):Void
	{
		if (doc == null)
			return;
		var b = Math.round(doc.tempo.beatAt(ms)) + dir;
		seek(doc.tempo.msAt(Math.max(0, b)));
	}

	/** Liga o loop. Sem pontos A/B válidos, usa a seção atual. */
	public function setLoop(on:Bool):Void
	{
		loopOn = on;
		if (on && loopB <= loopA + 100)
			loopSection();
	}

	public function loopSection():Void
	{
		if (doc == null)
			return;
		var i = sectionIndex();
		loopA = doc.chart.sections[i].startMs;
		loopB = i + 1 < doc.chart.sections.length ? doc.chart.sections[i + 1].startMs : lengthMs;
		loopOn = true;
	}

	// ------------------------------------------------------------------ foco de câmera

	/** Quem a câmera segue agora: o lado da seção, trocado por eventos "Camera Focus" dessa seção. */
	public function focusSlot():String
	{
		if (doc == null)
			return "bf";
		var sec = doc.chart.sections[sectionIndex()];
		var f = sec.mustHit ? "bf" : "dad";
		for (e in doc.chart.events)
		{
			if (e.time > ms)
				break;
			if (e.name == "Camera Focus" && e.time >= sec.startMs)
			{
				switch (e.v1.trim().toLowerCase())
				{
					case "bf", "boyfriend", "player":
						f = "bf";
					case "dad", "opponent":
						f = "dad";
					case "gf", "girlfriend":
						f = "gf";
					default:
				}
			}
		}
		return f;
	}

	public function stepSec():Float
		return doc == null ? 0.15 : 15.0 / doc.tempo.bpmAt(Math.max(0, doc.tempo.beatAt(ms)));

	// ------------------------------------------------------------------ loop

	public function tick(dt:Float):Void
	{
		if (doc == null || !playing)
			return;
		ms += dt * 1000;
		if (hasAudio && inst.playing && Math.abs(inst.time - ms) > 40)
			ms = inst.time;
		if (loopOn && loopB > loopA && ms >= loopB)
		{
			seek(loopA);
			if (!hasAudio)
				playing = true;
			return;
		}
		if (ms >= lengthMs)
		{
			pause();
			ms = Math.max(0, lengthMs - 1);
			return;
		}
		var notes = doc.chart.notes;
		while (hitIdx < notes.length && notes[hitIdx].time <= ms)
		{
			var n = notes[hitIdx++];
			if (onNote != null)
			{
				var sec = doc.chart.sections[Std.int(Math.min(doc.chart.sections.length - 1, Math.max(0, n.section)))];
				onNote(n, n.alt || (!n.player && sec.alt), stepSec());
			}
		}
		var b = Math.floor(doc.tempo.beatAt(ms));
		if (b != lastBeat)
		{
			lastBeat = b;
			if (onBeat != null)
				onBeat(b);
		}
	}

	public function destroy():Void
		unload();
}
