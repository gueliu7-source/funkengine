package editor;

import core.Chart.NoteData;
import core.Paths;
import editor.ChartDoc.ClipNote;
import editor.ChartDoc.Cmd;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxState;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import game.NoteSkin;
import states.EditorsState;
import states.PlayState;

using StringTools;

/**
 * Chart Editor (Etapa 1): grade, notas/sustains, seções, BPM, tocar com a música, salvar e desfazer.
 * Esta classe só orquestra: os dados ficam em ChartDoc, o desenho da grade em GridView e os controles em editor.ui.
 */
class ChartEditorState extends FlxState
{
	public static var songId:String = "bopeebo";
	public static var suffix:String = "";

	static final QUANTS:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64];
	static var clip:Array<ClipNote> = [];

	var doc:ChartDoc;
	var grid:GridView;
	var inst:FlxSound;
	var voices:FlxSound;
	var hasVoices:Bool = false;

	var songTime:Float = 0;
	var playing:Bool = false;
	var lengthMs:Float = 0;
	var hitIdx:Int = 0;
	var lastBeat:Int = -1;
	var holdTimer:Float = 0;

	// opções de reprodução
	var hitPlayer:Bool = true;
	var hitOpp:Bool = false;
	var metronome:Bool = false;
	var muteVoices:Bool = false;

	var curSection:Int = 0;
	var infoText:FlxText;
	var titleText:FlxText;
	var selText:FlxText;
	var secText:FlxText;
	var statusText:FlxText;
	var statusTimer:Float = 0;
	var exitArmed:Bool = false;
	var cache:Map<FlxText, String> = new Map();

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		NoteSkin.load("normal");

		inst = new FlxSound();
		var s = Paths.song(songId, "Inst");
		if (s != null)
			inst.loadEmbedded(s);
		FlxG.sound.list.add(inst);
		voices = new FlxSound();
		var v = Paths.song(songId, "Voices");
		if (v != null)
		{
			voices.loadEmbedded(v);
			hasVoices = true;
		}
		FlxG.sound.list.add(voices);
		lengthMs = inst.length;

		doc = ChartIO.open(songId, suffix, lengthMs);
		if (s == null)
			lengthMs = doc.tempo.msAt(doc.totalBeats());

		add(EdTheme.rect(0, 0, FlxG.width, FlxG.height, EdTheme.BG));
		grid = new GridView(doc);
		add(grid);
		buildLeft();
		buildRight();

		statusText = EdTheme.text(GridView.GX, FlxG.height - 20, 600, 14, "", EdTheme.GOOD);
		add(statusText);
		msg(s == null ? "Sem Inst.ogg em songs/" + songId + "/ — só edição, sem áudio." : "Pronto. ESPAÇO toca, clique na grade para colocar notas.", s != null);
	}

	// ------------------------------------------------------------------ montagem dos painéis

	function buildLeft():Void
	{
		var x = 10;
		add(new Panel(x, 10, 350, 150, "Música"));
		titleText = EdTheme.text(x + 10, 36, 330, 16, "", EdTheme.TEXT);
		add(titleText);
		infoText = EdTheme.text(x + 10, 58, 330, 14, "", EdTheme.CYAN);
		add(infoText);
		add(new Btn(x + 10, 84, 100, 26, "PLAY / PAUSE", togglePlay));
		add(new Btn(x + 118, 84, 70, 26, "INÍCIO", function() seek(0)));
		add(new Btn(x + 196, 84, 70, 26, "FIM", function() seek(lengthMs - 1)));
		add(new Btn(x + 274, 84, 66, 26, "SALVAR", save));
		add(new Btn(x + 10, 118, 100, 26, "TESTAR (ENTER)", testPlay));
		add(new Btn(x + 118, 118, 100, 26, "RECARREGAR", reload));
		add(new Btn(x + 226, 118, 114, 26, "SAIR (ESC)", leave));

		add(new Panel(x, 170, 350, 260, "Chart"));
		var c = doc.chart;
		add(new Selector(x + 10, 198, 330, "Oponente", function() return list("data/characters"), function() return c.player2,
			function(v) prop("oponente", c.player2, function(a) c.player2 = a, v)));
		add(new Selector(x + 10, 226, 330, "Jogador", function() return list("data/characters"), function() return c.player1,
			function(v) prop("jogador", c.player1, function(a) c.player1 = a, v)));
		add(new Selector(x + 10, 254, 330, "GF", function() return list("data/characters"), function() return c.gf,
			function(v) prop("gf", c.gf, function(a) c.gf = a, v)));
		add(new Selector(x + 10, 282, 330, "Cenário", function() return list("data/stages"), function() return c.stage,
			function(v) prop("cenário", c.stage, function(a) c.stage = a, v)));
		add(new Selector(x + 10, 310, 330, "Notas", function() return ["normal", "pixel"], function() return c.noteStyle,
			function(v) prop("estilo das notas", c.noteStyle, function(a) c.noteStyle = a, v)));
		add(new Stepper(x + 10, 342, 330, "Velocidade", function() return c.speed, function(v) prop("velocidade", c.speed, function(a) c.speed = a, v), 0.1, 0.1,
			10, 1));
		add(new Stepper(x + 10, 370, 330, "BPM da seção", currentBpm, setCurrentBpm, 1, 10, 999, 2));
		add(new Toggle(x + 10, 400, "Música tem voz (Voices.ogg)", function() return c.needsVoices, function(v) prop("voz", c.needsVoices, function(a) c.needsVoices = a, v)));

		add(new Panel(x, 440, 350, 270, "Reprodução"));
		add(new Selector(x + 10, 468, 330, "Divisão", function() return [for (q in QUANTS) "1/" + q], function() return "1/" + grid.quant, function(v) grid.quant = Std.parseInt(v.substr(2))));
		add(new Toggle(x + 10, 500, "Som ao passar nota do jogador", function() return hitPlayer, function(v) hitPlayer = v));
		add(new Toggle(x + 10, 524, "Som ao passar nota do oponente", function() return hitOpp, function(v) hitOpp = v));
		add(new Toggle(x + 10, 548, "Metrônomo (a cada batida)", function() return metronome, function(v) metronome = v));
		add(new Toggle(x + 10, 572, "Silenciar voz", function() return muteVoices, function(v) {
			muteVoices = v;
			voices.volume = v ? 0 : 1;
		}));
		add(EdTheme.text(x + 10, 604, 330, 13, "ESPAÇO tocar   ↑↓/roda mover   ←→ seção", EdTheme.DIM));
		add(EdTheme.text(x + 10, 622, 330, 13, "Q/E divisão   Clique: nota   Arraste: sustain", EdTheme.DIM));
		add(EdTheme.text(x + 10, 640, 330, 13, "Botão direito/DEL: apagar   Ctrl+Z/Y desfaz", EdTheme.DIM));
		add(EdTheme.text(x + 10, 658, 330, 13, "Ctrl+S salvar   SHIFT nos botões +/-: x10", EdTheme.DIM));
	}

	function buildRight():Void
	{
		var x = 730;
		add(new Panel(x, 10, 540, 200, "Seção"));
		secText = EdTheme.text(x + 10, 36, 520, 16, "", EdTheme.TEXT);
		add(secText);
		add(new Toggle(x + 10, 62, "Câmera no jogador nesta seção (mustHit)", function() return doc.chart.sections[curSection].mustHit, function(v) doc.setMustHit(curSection, v)));
		add(new Btn(x + 10, 94, 120, 26, "◀ SEÇÃO", function() gotoSection(curSection - 1)));
		add(new Btn(x + 138, 94, 120, 26, "SEÇÃO ▶", function() gotoSection(curSection + 1)));
		add(new Btn(x + 10, 130, 120, 26, "COPIAR", copySection));
		add(new Btn(x + 138, 130, 120, 26, "COLAR (troca)", function() paste(true)));
		add(new Btn(x + 266, 130, 120, 26, "COLAR (soma)", function() paste(false)));
		add(new Btn(x + 394, 130, 136, 26, "DUPLICAR ▶", dupSection));
		add(new Btn(x + 10, 164, 120, 26, "ESPELHAR", function() doc.swapSides(curSection)));
		add(new Btn(x + 138, 164, 120, 26, "LIMPAR", function() doc.clearSection(curSection)));

		add(new Panel(x, 220, 540, 170, "Nota selecionada"));
		selText = EdTheme.text(x + 10, 246, 520, 14, "", EdTheme.TEXT);
		add(selText);
		add(new Toggle(x + 10, 270, "Animação alternativa (alt)", function() return grid.sel != null && grid.sel.alt, function(v) {
			if (grid.sel != null)
				doc.setNoteAlt(grid.sel, v);
		}));
		add(new Selector(x + 10, 298, 400, "Tipo", function() return [""].concat(noteTypes()), function() return grid.sel != null ? grid.sel.type : "", function(v) {
			if (grid.sel != null)
				doc.setNoteType(grid.sel, v);
		}));
		add(new Btn(x + 10, 332, 120, 26, "APAGAR (DEL)", function() grid.deleteSelected()));

		add(new Panel(x, 400, 540, 310, "Histórico"));
		add(new Btn(x + 10, 428, 120, 26, "DESFAZER", function() doUndo(), function() return doc.canUndo));
		add(new Btn(x + 138, 428, 120, 26, "REFAZER", function() doRedo(), function() return doc.canRedo));
		add(EdTheme.text(x + 10, 470, 520, 14, "Etapas seguintes: eventos, preview de personagens,", EdTheme.DIM));
		add(EdTheme.text(x + 10, 488, 520, 14, "mapa de densidade, fadiga, variantes e relatório.", EdTheme.DIM));
	}

	// ------------------------------------------------------------------ utilidades de painel

	function list(dir:String):Array<String>
	{
		var out:Array<String> = [];
		for (n in Paths.list(dir))
			if (n.endsWith(".json"))
				out.push(n.substr(0, n.length - 5));
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	function noteTypes():Array<String>
	{
		var out:Array<String> = [];
		for (n in Paths.list("data/notetypes"))
		{
			var i = n.lastIndexOf(".");
			var name = i > 0 ? n.substr(0, i) : n;
			if (out.indexOf(name) < 0)
				out.push(name);
		}
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	function prop<T>(name:String, cur:T, set:T->Void, v:T):Void
	{
		if (cur == v)
			return;
		doc.run(new Cmd(name, function() set(v), function() set(cur)));
	}

	function currentBpm():Float
		return doc.tempo.bpmAt(doc.chart.sections[curSection].startBeat);

	function setCurrentBpm(v:Float):Void
	{
		var keep = doc.tempo.beatAt(songTime);
		doc.setBpmAt(doc.chart.sections[curSection].startBeat, v);
		seek(doc.tempo.msAt(keep));
	}

	function setText(t:FlxText, s:String):Void
	{
		if (cache.get(t) != s)
		{
			cache.set(t, s);
			t.text = s;
		}
	}

	function msg(s:String, good:Bool = true):Void
	{
		statusText.text = s;
		statusText.color = good ? EdTheme.GOOD : EdTheme.BAD;
		statusTimer = 5;
	}

	// ------------------------------------------------------------------ transporte

	function togglePlay():Void
	{
		if (playing)
			pausePlayback();
		else
			startPlayback();
	}

	function startPlayback():Void
	{
		if (lengthMs <= 0)
			return;
		if (songTime >= lengthMs - 50)
			songTime = 0;
		inst.play(true, songTime);
		if (hasVoices && doc.chart.needsVoices)
			voices.play(true, songTime);
		voices.volume = muteVoices ? 0 : 1;
		hitIdx = doc.lowerBound(songTime);
		lastBeat = Math.floor(doc.tempo.beatAt(songTime));
		playing = true;
	}

	function pausePlayback():Void
	{
		inst.pause();
		voices.pause();
		playing = false;
	}

	function seek(ms:Float):Void
	{
		songTime = Math.max(0, Math.min(lengthMs, ms));
		if (playing)
		{
			inst.time = songTime;
			if (hasVoices && doc.chart.needsVoices)
				voices.time = songTime;
		}
		hitIdx = doc.lowerBound(songTime);
		lastBeat = Math.floor(doc.tempo.beatAt(songTime));
	}

	function moveUnits(dir:Int):Void
	{
		var u = grid.unit();
		var b = doc.tempo.beatAt(songTime);
		var idx = Math.round(b / u) + dir;
		seek(doc.tempo.msAt(Math.max(0, idx * u)));
	}

	function gotoSection(i:Int):Void
	{
		i = Std.int(Math.max(0, Math.min(doc.chart.sections.length - 1, i)));
		seek(doc.chart.sections[i].startMs);
	}

	// ------------------------------------------------------------------ ações

	function copySection():Void
	{
		clip = doc.copyNotes(doc.chart.sections[curSection].startBeat, doc.sectionEndBeat(curSection));
		msg("Copiadas " + clip.length + " notas da seção " + curSection);
	}

	function paste(replace:Bool):Void
	{
		if (clip.length == 0)
		{
			msg("Nada copiado ainda.", false);
			return;
		}
		doc.pasteInto(curSection, clip, replace);
	}

	function dupSection():Void
	{
		if (curSection + 1 >= doc.chart.sections.length)
			return;
		var c = doc.copyNotes(doc.chart.sections[curSection].startBeat, doc.sectionEndBeat(curSection));
		doc.pasteInto(curSection + 1, c, true);
		gotoSection(curSection + 1);
	}

	function save():Void
	{
		var p = ChartIO.save(doc);
		if (p != null)
			msg("Salvo em " + p);
		else
			msg("Erro ao salvar (veja o log).", false);
	}

	function reload():Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			msg("Há alterações não salvas! Clique de novo para recarregar mesmo assim.", false);
			return;
		}
		FlxG.resetState();
	}

	function doUndo():Void
	{
		var n = doc.undo();
		if (n != null)
			msg("Desfeito: " + n);
	}

	function doRedo():Void
	{
		var n = doc.redo();
		if (n != null)
			msg("Refeito: " + n);
	}

	function testPlay():Void
	{
		if (ChartIO.save(doc) == null)
		{
			msg("Não foi possível salvar para testar.", false);
			return;
		}
		pausePlayback();
		PlayState.songId = songId;
		PlayState.difficulty = suffix;
		PlayState.week = 0;
		PlayState.isStory = false;
		PlayState.fromEditor = true;
		FlxG.switchState(new PlayState());
	}

	function leave():Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			msg("Há alterações não salvas! Aperte ESC/SAIR de novo para sair sem salvar.", false);
			return;
		}
		inst.stop();
		voices.stop();
		FlxG.switchState(new EditorsState());
	}

	// ------------------------------------------------------------------ loop

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (playing)
		{
			songTime += elapsed * 1000;
			if (inst.playing)
			{
				if (Math.abs(inst.time - songTime) > 40)
					songTime = inst.time;
			}
			if (songTime >= lengthMs)
			{
				pausePlayback();
				songTime = lengthMs - 1;
			}
			var notes = doc.chart.notes;
			while (hitIdx < notes.length && notes[hitIdx].time <= songTime)
			{
				var n = notes[hitIdx++];
				grid.flashColumn(n.lane + (n.player ? 4 : 0));
				if (n.player ? hitPlayer : hitOpp)
					sfx("SNAP");
			}
			if (metronome)
			{
				var b = Math.floor(doc.tempo.beatAt(songTime));
				if (b != lastBeat)
				{
					lastBeat = b;
					sfx("CLAP");
				}
			}
		}

		keys(elapsed);

		var beat = doc.tempo.beatAt(songTime);
		curSection = doc.sectionIndexAtBeat(Math.max(0, beat));
		grid.sync(beat * 4, elapsed);
		grid.mouse();

		if (statusTimer > 0)
		{
			statusTimer -= elapsed;
			if (statusTimer <= 0)
				statusText.text = "";
		}

		setText(titleText, songId + (suffix == "" ? "  [normal]" : "  [" + suffix.substr(1) + "]") + (doc.dirty ? "  *" : ""));
		setText(infoText, fmtTime(songTime) + " / " + fmtTime(lengthMs) + "   beat " + Math.floor(beat * 100) / 100 + "   " + (playing ? "TOCANDO" : "pausado"));
		var s = doc.chart.sections[curSection];
		setText(secText, "Seção " + curSection + "  (" + s.steps + " steps)   BPM " + currentBpm() + "   câmera: " + (s.mustHit ? "jogador" : "oponente"));
		var n = grid.sel;
		setText(selText, n == null ? "(clique numa nota para selecionar)" : "lado: " + (n.player ? "jogador" : "oponente") + "   lane " + n.lane + "   beat "
			+ Math.round(doc.beatOf(n) * 1000) / 1000 + "   sustain " + Math.round(n.sustain) + " ms");
	}

	function sfx(name:String):Void
	{
		var s = Paths.sound('sounds/$name.ogg');
		if (s != null)
			FlxG.sound.play(s, 0.6);
	}

	static function fmtTime(ms:Float):String
	{
		var t = Math.max(0, ms);
		var m = Std.int(t / 60000);
		var sec = Std.int(t / 1000) % 60;
		var mil = Std.int(t) % 1000;
		return m + ":" + (sec < 10 ? "0" : "") + sec + "." + (mil < 100 ? (mil < 10 ? "00" : "0") : "") + mil;
	}

	function keys(elapsed:Float):Void
	{
		var k = FlxG.keys;
		var ctrl = k.pressed.CONTROL;

		if (k.justPressed.ESCAPE)
			leave();
		if (k.justPressed.SPACE)
			togglePlay();
		if (k.justPressed.ENTER)
			testPlay();
		if (ctrl && k.justPressed.S)
			save();
		if (ctrl && k.justPressed.Z)
			doUndo();
		if (ctrl && k.justPressed.Y)
			doRedo();
		if (k.justPressed.DELETE || k.justPressed.BACKSPACE)
			grid.deleteSelected();
		if (k.justPressed.Q)
			cycleQuant(-1);
		if (k.justPressed.E)
			cycleQuant(1);
		if (k.justPressed.HOME)
			seek(0);
		if (k.justPressed.END)
			seek(lengthMs - 1);
		if (k.justPressed.LEFT || k.justPressed.A || k.justPressed.PAGEUP)
			gotoSection(doc.tempo.beatAt(songTime) > doc.chart.sections[curSection].startBeat + 0.1 && !playing ? curSection : curSection - 1);
		if (k.justPressed.RIGHT || k.justPressed.D || k.justPressed.PAGEDOWN)
			gotoSection(curSection + 1);

		var dir = 0;
		if (k.pressed.UP || k.pressed.W)
			dir = -1;
		if (k.pressed.DOWN || k.pressed.S)
			dir = 1;
		if (dir != 0 && !ctrl)
		{
			if (k.justPressed.UP || k.justPressed.W || k.justPressed.DOWN || k.justPressed.S)
			{
				moveUnits(dir);
				holdTimer = -0.3;
			}
			else
			{
				holdTimer += elapsed;
				if (holdTimer > 0.04)
				{
					holdTimer = 0;
					moveUnits(dir);
				}
			}
		}

		if (FlxG.mouse.wheel != 0)
		{
			var steps = (k.pressed.SHIFT ? 4 : 1);
			for (_ in 0...steps)
				moveUnits(FlxG.mouse.wheel < 0 ? 1 : -1);
		}
	}

	function cycleQuant(dir:Int):Void
	{
		var i = QUANTS.indexOf(grid.quant);
		grid.quant = QUANTS[(i + dir + QUANTS.length) % QUANTS.length];
	}

	override public function destroy():Void
	{
		if (inst != null)
			inst.stop();
		if (voices != null)
			voices.stop();
		super.destroy();
	}
}
