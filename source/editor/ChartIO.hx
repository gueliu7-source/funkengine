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
	public static function open(id:String, suffix:String, lengthMs:Float, fromAutosave:Bool = false):ChartDoc
	{
		var c:Chart = null;
		#if sys
		if (fromAutosave)
		{
			try
				c = ChartLoader.parseText(id, File.getContent(autosavePathFor(id, suffix)), 0)
			catch (e:Dynamic)
				trace('[ChartIO] autosave ilegível: $e');
		}
		#end
		var recovered = c != null;
		if (c == null)
			c = ChartLoader.load(id, suffix, 0);
		var isNew = (c == null) || !Paths.exists('data/songs/$id/$id$suffix.json');
		if (c == null)
		{
			c = new Chart();
			c.id = id;
			c.name = id;
			c.segments = [new BpmSegment(0, 0, 100)];
		}
		var doc = new ChartDoc(c, id, suffix, lengthMs);
		doc.dirty = isNew || recovered;
		return doc;
	}

	static function autosavePathFor(id:String, suffix:String):String
		return ModManager.saveRoot() + '/data/songs/$id/$id$suffix.autosave';

	/** Cópia de segurança (não mexe no chart salvo nem no estado "alterado"). */
	public static function autosave(doc:ChartDoc):Bool
	{
		#if sys
		try
		{
			var path = autosavePathFor(doc.songId, doc.suffix);
			ModManager.mkdirs(path.substr(0, path.lastIndexOf("/")));
			File.saveContent(path, Json.stringify(toJson(doc.chart)));
			return true;
		}
		catch (e:Dynamic)
			trace('[ChartIO] erro no autosave: $e');
		#end
		return false;
	}

	/** Existe autosave mais novo que o chart salvo? */
	public static function hasNewerAutosave(id:String, suffix:String):Bool
	{
		#if sys
		var a = autosavePathFor(id, suffix);
		if (!sys.FileSystem.exists(a))
			return false;
		var c = ModManager.saveRoot() + '/data/songs/$id/$id$suffix.json';
		return !sys.FileSystem.exists(c) || sys.FileSystem.stat(a).mtime.getTime() > sys.FileSystem.stat(c).mtime.getTime();
		#else
		return false;
		#end
	}

	public static function clearAutosave(id:String, suffix:String):Void
	{
		#if sys
		var a = autosavePathFor(id, suffix);
		if (sys.FileSystem.exists(a))
			sys.FileSystem.deleteFile(a);
		#end
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
			clearAutosave(doc.songId, doc.suffix);
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
			events: events,
			markers: [for (m in c.markers) {beat: m.beat, name: m.name, color: m.color}]
		};
	}

	static inline function round(v:Float):Float
		return Math.round(v * 100) / 100;
}
