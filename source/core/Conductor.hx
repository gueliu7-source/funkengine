package core;

import flixel.sound.FlxSound;
import flixel.util.FlxSignal.FlxTypedSignal;

/** Mudança de BPM: a partir de timeMs (ms) / beat (batida), o andamento passa a ser bpm. */
class BpmSegment
{
	public var timeMs:Float;
	public var beat:Float;
	public var bpm:Float;

	public function new(timeMs:Float, beat:Float, bpm:Float)
	{
		this.timeMs = timeMs;
		this.beat = beat;
		this.bpm = bpm;
	}
}

/**
 * Relógio da música. Tudo (notas, câmera, scripts) se sincroniza por aqui.
 * - songPosition: posição da música em ms (negativa durante a contagem regressiva).
 * - sinais stepHit/beatHit/sectionHit são disparados a cada step/beat/seção.
 */
@:keep
class Conductor
{
	public static var songPosition:Float = 0;
	public static var rate:Float = 1;

	public static var bpm(default, null):Float = 100;
	public static var crochet(default, null):Float = 600; // ms por beat
	public static var stepCrochet(default, null):Float = 150; // ms por step (1/4 de beat)

	public static var curStep(default, null):Int = 0;
	public static var curBeat(default, null):Int = 0;
	public static var curSection(default, null):Int = 0;
	public static var curDecBeat(default, null):Float = 0;

	public static var segments:Array<BpmSegment> = [new BpmSegment(0, 0, 100)];
	public static var sectionBeats:Array<Float> = [0];

	public static var stepHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public static var beatHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();
	public static var sectionHit:FlxTypedSignal<Int->Void> = new FlxTypedSignal<Int->Void>();

	static var lastMusicTime:Float = -1;
	static var lastStamp:Float = 0;
	static var segIndex:Int = 0;

	/** Prepara o relógio para uma música. startPos costuma ser -(5 * crochet). */
	public static function setup(segs:Array<BpmSegment>, sectionStartBeats:Array<Float>, startPos:Float):Void
	{
		segments = segs.length > 0 ? segs : [new BpmSegment(0, 0, 100)];
		sectionBeats = sectionStartBeats.length > 0 ? sectionStartBeats : [0];
		songPosition = startPos;
		lastMusicTime = -1;
		segIndex = 0;
		applyBpm(segments[0].bpm);
		var b = beatAt(startPos);
		curDecBeat = b;
		curStep = Math.floor(b * 4);
		curBeat = Math.floor(b);
		curSection = 0;
		touch();
	}

	public static function clearSignals():Void
	{
		stepHit.removeAll();
		beatHit.removeAll();
		sectionHit.removeAll();
	}

	/** Chame a cada frame de jogo. music = faixa Inst (ou null durante a contagem). */
	public static function update(elapsed:Float, music:FlxSound):Void
	{
		songPosition += elapsed * 1000 * rate;

		if (music != null && music.playing)
		{
			var t = music.time;
			if (t != lastMusicTime) // o relógio do áudio andou
			{
				lastMusicTime = t;
				var diff = t - songPosition;
				if (diff > 40 || diff < -40)
					songPosition = t; // dessincronizou: corrige de uma vez
				else
					songPosition += diff * 0.2; // pequena deriva: corrige suave
			}
		}

		while (segIndex + 1 < segments.length && segments[segIndex + 1].timeMs <= songPosition)
		{
			segIndex++;
			applyBpm(segments[segIndex].bpm);
		}

		var b = beatAt(songPosition);
		curDecBeat = b;
		var step = Math.floor(b * 4);
		var beat = Math.floor(b);

		while (curStep < step)
		{
			curStep++;
			stepHit.dispatch(curStep);
		}
		while (curBeat < beat)
		{
			curBeat++;
			beatHit.dispatch(curBeat);
		}
		while (curSection + 1 < sectionBeats.length && b >= sectionBeats[curSection + 1])
		{
			curSection++;
			sectionHit.dispatch(curSection);
		}

		touch();
	}

	/** Marca "agora" como último update (use ao voltar de uma pausa). */
	public static inline function touch():Void
		lastStamp = haxe.Timer.stamp();

	/** Posição estimada AGORA, entre dois frames. Dá precisão de input independente do FPS. */
	public static inline function positionNow():Float
		return songPosition + (haxe.Timer.stamp() - lastStamp) * 1000 * rate;

	public static function beatAt(ms:Float):Float
	{
		var s = segmentAtTime(ms);
		return s.beat + (ms - s.timeMs) / (60000 / s.bpm);
	}

	public static function timeAtBeat(beat:Float):Float
	{
		var i = segments.length - 1;
		while (i > 0 && segments[i].beat > beat)
			i--;
		var s = segments[i];
		return s.timeMs + (beat - s.beat) * (60000 / s.bpm);
	}

	static function segmentAtTime(ms:Float):BpmSegment
	{
		var i = segments.length - 1;
		while (i > 0 && segments[i].timeMs > ms)
			i--;
		return segments[i];
	}

	static function applyBpm(v:Float):Void
	{
		bpm = v;
		crochet = 60000 / v;
		stepCrochet = crochet / 4;
	}
}
