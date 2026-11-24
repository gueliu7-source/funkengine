package scripting;

import core.Chart;
import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import states.PlayState;

using StringTools;

/**
 * Carrega e dispara scripts .hx e .lua. Os dois tipos usam os mesmos callbacks:
 *   onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed), onStepHit(step), onBeatHit(beat),
 *   onSectionHit(sec), onCountdown(tick), onSongStart, onSongEnd, goodNoteHit(lane, rating, isSustain, type),
 *   opponentNoteHit(lane, isSustain, type), noteMiss(lane, type), onEvent(name, v1, v2), onPause, onResume,
 *   onGameOver (devolva "stop" para impedir), onTimerCompleted(tag, loops, loopsLeft), onTweenCompleted(tag), onDestroy.
 *
 * Onde procura scripts (todos opcionais):
 *   scripts/*.hx|lua                     globais, em toda música
 *   data/songs/<musica>/*.hx|lua         da música
 *   data/stages/<stage>.hx|lua           do cenário
 *   data/characters/<personagem>.hx|lua  de cada personagem em uso
 * scripts/ e data/songs/<musica>/ somam os arquivos de assets/ e de todos os mods ativos;
 * stage e personagem usam só o arquivo de maior prioridade (o mod substitui o original).
 */
class ScriptManager
{
	public var game:PlayState;
	public var api:Map<String, Dynamic>;
	public var classes:Map<String, Dynamic>;
	public var runners:Array<ScriptRunner> = [];
	public var errors:Array<String> = [];
	public var curNote:core.Chart.NoteData; // nota do callback em andamento (PsychLua.translate)
	public var hasPsych:Bool = false;
	var psychMap:Map<String, Dynamic>;

	public function psychApi():Map<String, Dynamic>
	{
		if (psychMap == null)
			psychMap = PsychLua.build(game, this);
		return psychMap;
	}

	/** Script Psych: mods com psych.txt na raiz e as pastas custom_events/ e custom_notetypes/. */
	static function isPsychPath(real:String):Bool
	{
		var p = real.replace("\\", "/");
		if (p.indexOf("/custom_events/") >= 0 || p.indexOf("/custom_notetypes/") >= 0)
			return true;
		var i = p.indexOf("mods/");
		if (i < 0)
			return false;
		var rest = p.substr(i + 5);
		var slash = rest.indexOf("/");
		if (slash < 0)
			return false;
		return sys.FileSystem.exists(p.substr(0, i + 5 + slash) + "/psych.txt");
	}

	// nomes antigos da Kade Engine, chamados também em scripts Lua
	static var legacy:Map<String, String> = [
		"onCreatePost" => "start", "onUpdate" => "update", "onBeatHit" => "beatHit", "onStepHit" => "stepHit", "onSongStart" => "songStart"
	];

	public function new(game:PlayState)
	{
		this.game = game;
		api = ScriptApi.build(game, this);
		classes = new Map();
		classes.set("FlxG", FlxG);
		classes.set("FlxSprite", FlxSprite);
		classes.set("FlxText", FlxText);
		classes.set("FlxTween", FlxTween);
		classes.set("FlxTimer", FlxTimer);
		classes.set("FlxMath", FlxMath);
		classes.set("FlxEase", ScriptApi.easeObject());
		classes.set("Paths", Paths);
		classes.set("Conductor", Conductor);
		classes.set("Settings", Settings);
		classes.set("Math", Math);
		classes.set("Std", Std);
		classes.set("StringTools", StringTools);
		classes.set("Reflect", Reflect);
	}

	public function loadAll(chart:Chart):Void
	{
		loadDir("scripts");
		loadDir("data/songs/" + chart.id);
		// eventos e tipos de nota customizados do Psych: só carrega os que a música usa
		var seen = new Map<String, Bool>();
		for (e in chart.events)
			if (!seen.exists("e" + e.name))
			{
				seen.set("e" + e.name, true);
				loadNamed("custom_events/" + e.name);
			}
		for (n in chart.notes)
			if (n.type != null && n.type != "" && !seen.exists("n" + n.type))
			{
				seen.set("n" + n.type, true);
				loadNamed("custom_notetypes/" + n.type);
			}
		loadNamed("data/stages/" + chart.stage);
		for (c in [chart.player1, chart.player2, chart.gf])
			loadNamed("data/characters/" + c);
		pushGlobals();
	}

	function loadDir(dir:String):Void
	{
		// soma os scripts de TODAS as raízes (assets e cada mod ativo), como no Psych
		for (real in Paths.listAll(dir))
			if (real.endsWith(".hx") || real.endsWith(".lua"))
				loadReal(real);
	}

	function loadNamed(basePath:String):Void
	{
		if (Paths.exists(basePath + ".hx"))
			loadFile(basePath + ".hx");
		if (Paths.exists(basePath + ".lua"))
			loadFile(basePath + ".lua");
	}

	public function loadFile(rel:String):Void
	{
		var real = Paths.find(rel);
		if (real != null)
			loadReal(real);
	}

	function loadReal(real:String):Void
	{
		for (r in runners)
			if (r.path == real)
				return; // já carregado (personagem repetido)
		var rel = real;

		if (rel.endsWith(".hx"))
			runners.push(new HScriptRunner(this, real, Paths.readFile(real)));
		else
		{
			#if FEATURE_LUA
			var ps = isPsychPath(real);
			if (ps)
				hasPsych = true;
			runners.push(new LuaRunner(this, real, ps));
			#else
			reportError('[$rel] Lua desativado nesta build (compilada com -DNO_LUA)');
			#end
		}
	}

	/** Variáveis globais no estilo Kade/Psych, visíveis nos scripts. */
	function pushGlobals():Void
	{
		for (r in runners)
		{
			r.set("songName", game.chart.id);
			r.set("bpm", game.chart.bpm);
			r.set("crochet", Conductor.crochet);
			r.set("scrollSpeed", game.scrollSpeed);
			r.set("downscroll", Settings.d.downscroll);
			r.set("middlescroll", Settings.d.middlescroll);
			r.set("botplay", Settings.d.botplay);
			r.set("difficulty", PlayState.difficulty);
			r.set("stepCrochet", Conductor.crochet / 4);
		}
	}

	/** Chama a função em todos os scripts. Devolve true se algum devolveu "stop". */
	public function call(fn:String, ?args:Array<Dynamic>):Bool
	{
		if (runners.length == 0)
			return false;
		if (args == null)
			args = [];
		var stop = false;
		for (r in runners)
		{
			if (r.closed)
				continue;
			if (r.psych)
			{
				if (!r.hasFn(fn))
					continue;
				var pa = PsychLua.translate(this, fn, args);
				if (pa == null)
					continue;
				if (r.syncStep != Conductor.curStep)
				{
					r.syncStep = Conductor.curStep;
					PsychLua.sync(r);
				}
				var pv = r.call(fn, pa);
				if (pv != null && Std.string(pv) == "stop")
					stop = true;
				continue;
			}
			if (!r.hasFn(fn) && !(r.isLua && legacy.exists(fn)))
				continue;
			var v = r.call(fn, args);
			if (r.isLua && legacy.exists(fn))
				r.call(legacy.get(fn), args);
			if (v != null && Std.string(v) == "stop")
				stop = true;
		}
		return stop;
	}

	public function reportError(msg:String):Void
	{
		errors.push(msg);
		if (game != null)
			game.showError(msg);
	}

	public function destroy():Void
	{
		call("onDestroy");
		for (r in runners)
			r.destroy();
		runners = [];
	}
}
