package editor;

import core.Chart;
import core.Conductor.BpmSegment;
import core.ModManager;
import core.Paths;
import core.Settings;
import haxe.Json;
#if sys
import sys.io.File;
#end

/** Carregar e salvar charts (formato funkforge-2). Salva sempre em mods/<mod ativo>/, nunca em assets/. */
class ChartIO
{
	/** Abre o chart (ou cria um vazio se ainda não existir). lengthMs = duração do Inst. */
	public static function open(id:String, suffix:String, lengthMs:Float):ChartDoc
	{
		var c = ChartLoader.load(id, suffix, 0);
		var isNew = (c == null) || !Paths.exists('data/songs/$id/$id$suffix.json');
		if (c == null)
		{
			c = new Chart();
			c.id = id;
			c.name = id;
			c.segments = [new BpmSegment(0, 0, 100)];
		}
		var doc = new ChartDoc(c, id, suffix, lengthMs);
		doc.dirty = isNew;
		return doc;
	}

	public static function pathFor(doc:ChartDoc):String
		return ModManager.saveRoot() + '/data/songs/${doc.songId}/${doc.songId}${doc.suffix}.json';

	/** Devolve o caminho salvo (ou null em caso de erro). */
	public static function save(doc:ChartDoc):Null<String>
	{
		#if sys
		try
		{
			var path = pathFor(doc);
			ModManager.mkdirs(path.substr(0, path.lastIndexOf("/")));
			File.saveContent(path, Json.stringify(toJson(doc.chart)));
			Paths.rebuild(Settings.d.enabledMods);
			doc.dirty = false;
			return path;
		}
		catch (e:Dynamic)
		{
			trace('[ChartIO] erro ao salvar: $e');
			return null;
		}
		#else
		return null;
		#end
	}

	public static function toJson(c:Chart):Dynamic
	{
		var notes:Array<Dynamic> = [];
		for (n in c.notes)
			notes.push([round(n.time), n.lane, n.player ? 1 : 0, round(n.sustain), n.type, n.section, n.alt ? 1 : 0]);
		var events:Array<Dynamic> = [];
		for (e in c.events)
			events.push([round(e.time), e.name, e.v1, e.v2]);
		return {
			format: "funkforge-2",
			name: c.name,
			bpm: c.segments[0].bpm,
			speed: c.speed,
			needsVoices: c.needsVoices,
			player1: c.player1,
			player2: c.player2,
			gf: c.gf,
			stage: c.stage,
			noteStyle: c.noteStyle,
			bpmChanges: [for (s in c.segments) {time: round(s.timeMs), beat: s.beat, bpm: s.bpm}],
			sections: [for (s in c.sections) {start: round(s.startMs), beat: s.startBeat, steps: s.steps, mustHit: s.mustHit, alt: s.alt}],
			notes: notes,
			events: events
		};
	}

	static inline function round(v:Float):Float
		return Math.round(v * 100) / 100;
}
