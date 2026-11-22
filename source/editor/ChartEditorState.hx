package editor;

import core.Paths;
import editor.ChartDoc.ClipNote;
import editor.ChartDoc.Cmd;
import editor.panels.AnalysisTab;
import editor.panels.ChartTab;
import editor.panels.EventsTab;
import editor.panels.GuideTab;
import editor.panels.PreviewTab;
import editor.panels.SectionTab;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import game.NoteSkin;
import states.EditorsState;
import states.PlayState;

using StringTools;

/**
 * Chart Editor. Esta classe só orquestra: dados em ChartDoc, grade em GridView, eventos em EventLane,
 * painéis em editor/panels, widgets em editor/ui. Os membros públicos são a "API" que os painéis usam.
 */
class ChartEditorState extends FlxState
{
	public static var songId:String = "bopeebo";
	public static var suffix:String = "";
	static var tabIndex:Int = 0;
	static var clip:Array<ClipNote> = [];

	static final QUANTS:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64];

	public var doc:ChartDoc;
	public var grid:GridView;
	public var lane:EventLane;
	public var preview:CharPreview;
	public var curSection:Int = 0;

	var inst:FlxSound;
	var voices:FlxSound;
	var hasVoices:Bool = false;
	var songTime:Float = 0;
	var lengthMs:Float = 0;
	var playing:Bool = false;
	var hitIdx:Int = 0;
	var lastBeat:Int = -1;
	var holdTimer:Float = 0;

	var hitPlayer:Bool = true;
	var hitOpp:Bool = false;
	var metronome:Bool = false;
	var instVol:Float = 1;
	var voiceVol:Float = 1;
	var speed:Float = 1;
	var instSnd:Null<openfl.media.Sound>;

	var tabs:Tabs;
	var analysis:AnalysisTab;
	var markers:MarkerLayer;
	public var shadow:ShadowLayer;
	public var guide:GuideLayer;
	var voicesSnd:Null<openfl.media.Sound>;
	var help:HelpOverlay;
	var toast:Toast;
	var playBtn:Btn;
	var titleText:FlxText;
	var timeText:FlxText;
	var infoText:FlxText;
	var hoverText:FlxText;
	var exitArmed:Bool = false;
	var cache:Map<FlxText, String> = new Map();
	var savedMute:Array<FlxKey>;
	var savedUp:Array<FlxKey>;
	var savedDown:Array<FlxKey>;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		// digitar nas caixas de texto não pode mexer no volume do jogo
		savedMute = FlxG.sound.muteKeys;
		savedUp = FlxG.sound.volumeUpKeys;
		savedDown = FlxG.sound.volumeDownKeys;
		FlxG.sound.muteKeys = null;
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;
		EdLock.locked = false;
		NoteSkin.load("normal");
		EventRegistry.reload();

		inst = new FlxSound();
		var s = Paths.song(songId, "Inst");
		instSnd = s;
		if (s != null)
			inst.loadEmbedded(s);
		FlxG.sound.list.add(inst);
		voices = new FlxSound();
		var v = Paths.song(songId, "Voices");
		voicesSnd = v;
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
		lane = new EventLane(doc, grid);
		lane.onSelect = function(e) {
			if (e != null)
				tabs.select(2);
		};
		add(lane);
		markers = new MarkerLayer(doc, grid);
		add(markers);
		shadow = new ShadowLayer(doc, grid);
		add(shadow);
		guide = new GuideLayer(doc, grid);
		add(guide);
		add(new Minimap(doc, function() return lengthMs, function() return songTime, function(t) seek(t)));

		preview = new CharPreview(doc, function(s, good) say(s, good));
		add(preview);
		buildInfoCard();
		buildPlaybackCard();
		buildSidebar();
		buildTopBar();

		toast = new Toast(GridView.GX + GridView.CELL * 4, FlxG.height - 52);
		add(toast);
		help = new HelpOverlay();
		add(help);
		say(s == null ? "Sem Inst.ogg em songs/" + songId + "/ - só edição, sem áudio." : "Pronto. ESPAÇO toca; clique na grade para colocar notas. F1 = atalhos.", s != null);
	}

	// ------------------------------------------------------------------ montagem

	function buildTopBar():Void
	{
		add(EdTheme.rect(0, 0, FlxG.width, EdTheme.TOP_H, EdTheme.BG));
		add(EdTheme.rect(0, EdTheme.TOP_H - 1, FlxG.width, 1, EdTheme.LINE));
		titleText = EdTheme.text(EdTheme.LEFT_X, 8, 250, 16, "", EdTheme.TEXT);
		add(titleText);
		add(EdTheme.text(EdTheme.LEFT_X, 29, 250, 12, "CHART EDITOR", EdTheme.DIM));

		add(new Btn(272, 10, 70, 32, "INÍCIO", function() seek(0), 2));
		playBtn = new Btn(348, 10, 104, 32, "PLAY", togglePlay, 1);
		add(playBtn);
		add(new Btn(458, 10, 56, 32, "FIM", function() seek(lengthMs - 1), 2));
		timeText = EdTheme.text(534, 16, 200, 16, "", EdTheme.CYAN);
		add(timeText);

		add(new Btn(716, 10, 80, 32, "DESFAZER", doUndo, 2, function() return doc.canUndo));
		add(new Btn(802, 10, 80, 32, "REFAZER", doRedo, 2, function() return doc.canRedo));
		add(new Btn(900, 10, 84, 32, "SALVAR", save, 0));
		add(new Btn(990, 10, 100, 32, "TESTAR", testPlay, 0));
		add(new Btn(1100, 10, 34, 32, "?", function() help.toggle(), 2));
		add(new Btn(1180, 10, 84, 32, "SAIR", leave, 2));
	}

	function buildInfoCard():Void
	{
		var y = CharPreview.PY + CharPreview.PH + 12;
		add(new Card(EdTheme.LEFT_X, y, EdTheme.LEFT_W, 90, "Posição"));
		infoText = EdTheme.text(EdTheme.LEFT_X + 16, y + 34, EdTheme.LEFT_W - 32, 14, "", EdTheme.TEXT);
		add(infoText);
		hoverText = EdTheme.text(EdTheme.LEFT_X + 16, y + 72, EdTheme.LEFT_W - 32, 12, "", EdTheme.DIM);
		add(hoverText);
	}

	function buildPlaybackCard():Void
	{
		var x = EdTheme.LEFT_X;
		var y = CharPreview.PY + CharPreview.PH + 12 + 90 + 12;
		var h = FlxG.height - 14 - y;
		add(new Card(x, y, EdTheme.LEFT_W, h, "Reprodução"));
		var ix = x + 16;
		var iw = EdTheme.LEFT_W - 32;
		add(EdTheme.text(ix, y + 34, iw, 12, "DIVISÃO DA GRADE", EdTheme.DIM));
		add(new Segments(ix - 2, y + 52, iw + 4, [for (q in QUANTS) "1/" + q], function() return "1/" + grid.quant, function(v) grid.quant = Std.parseInt(v.substr(2))));
		add(new Slider(ix, y + 88, iw, "Volume da música", function() return instVol, function(v) {
			instVol = v;
			inst.volume = v;
		}, 0, 1, 2));
		add(new Slider(ix, y + 128, iw, "Volume da voz", function() return voiceVol, function(v) {
			voiceVol = v;
			voices.volume = v;
		}, 0, 1, 2));
		add(new Toggle(ix, y + 170, iw, "Som nas notas do jogador", function() return hitPlayer, function(v) hitPlayer = v));
		add(new Toggle(ix, y + 196, iw, "Som nas notas do oponente", function() return hitOpp, function(v) hitOpp = v));
		add(new Toggle(ix, y + 222, iw, "Metrônomo", function() return metronome, function(v) metronome = v));
		var spd = ["50%", "75%", "100%", "125%"];
		add(new Segments(ix - 2, y + 254, iw + 4, spd, function() return Std.int(speed * 100) + "%", function(v) setSpeed(Std.parseInt(v.substr(0, v.length - 1)) / 100)));
	}

	function buildSidebar():Void
	{
		add(new Card(EdTheme.SIDE_X, EdTheme.TOP_H + 12, EdTheme.SIDE_W, FlxG.height - EdTheme.TOP_H - 26));
		tabs = new Tabs(EdTheme.SIDE_X + 16, EdTheme.TOP_H + 22, EdTheme.SIDE_W - 32, ["CHART", "SEÇÃO", "EVENTOS", "PREVIEW", "ANÁLISE", "GUIA"]);
		var a = new ChartTab(this);
		var b = new SectionTab(this);
		var c = new EventsTab(this);
		var d = new PreviewTab(this);
		analysis = new AnalysisTab(this);
		add(a);
		add(b);
		add(c);
		add(d);
		var g = new GuideTab(this);
		add(analysis);
		add(g);
		tabs.setContents([a, b, c, d, analysis, g]);
		add(tabs);
		tabs.select(tabIndex);
	}

	// ------------------------------------------------------------------ API para os painéis

	public function listJson(dir:String):Array<String>
	{
		var out:Array<String> = [];
		for (n in Paths.list(dir))
			if (n.endsWith(".json"))
				out.push(n.substr(0, n.length - 5));
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	public function noteTypes():Array<String>
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

	public function prop<T>(name:String, cur:T, set:T->Void, v:T):Void
	{
		if (cur == v)
			return;
		doc.run(new Cmd(name, function() set(v), function() set(cur)));
	}

	public function currentBpm():Float
		return doc.tempo.bpmAt(doc.chart.sections[curSection].startBeat);

	public function setCurrentBpm(v:Float):Void
	{
		var keep = doc.tempo.beatAt(songTime);
		doc.setBpmAt(doc.chart.sections[curSection].startBeat, v);
		seek(doc.tempo.msAt(keep));
	}

	public function voicesSound():Null<openfl.media.Sound>
		return voicesSnd;

	public function instSound():Null<openfl.media.Sound>
		return instSnd;

	public function songTimeNow():Float
		return songTime;

	public function lengthNow():Float
		return lengthMs;

	/** Copia para a seção atual as notas que a sombra tem nesse trecho. */
	public function importShadow(replace:Bool):Void
	{
		if (shadow.source == ShadowLayer.NONE)
		{
			say("Escolha uma sombra primeiro (aba CHART).", false);
			return;
		}
		var c = shadow.clip(doc.chart.sections[curSection].startBeat, doc.sectionEndBeat(curSection));
		if (c.length == 0)
		{
			say("A sombra não tem notas nesta seção.", false);
			return;
		}
		doc.pasteInto(curSection, c, replace);
		say("Importadas " + c.length + " notas da sombra (" + shadow.source + ")");
	}

	/** Velocidade de reprodução. Atenção: muda o tom junto (sem preservação de pitch). */
	public function setSpeed(v:Float):Void
	{
		speed = Math.max(0.25, Math.min(2, v));
		inst.pitch = speed;
		voices.pitch = speed;
	}

	public function say(s:String, good:Bool = true):Void
		toast.show(s, good);

	public function seek(ms:Float):Void
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

	public function gotoSection(i:Int):Void
	{
		i = Std.int(Math.max(0, Math.min(doc.chart.sections.length - 1, i)));
		seek(doc.chart.sections[i].startMs);
	}

	public function copySection():Void
	{
		clip = doc.copyNotes(doc.chart.sections[curSection].startBeat, doc.sectionEndBeat(curSection));
		say("Copiadas " + clip.length + " notas da seção " + curSection);
	}

	public function paste(replace:Bool):Void
	{
		if (clip.length == 0)
		{
			say("Nada copiado ainda.", false);
			return;
		}
		doc.pasteInto(curSection, clip, replace);
	}

	public function dupSection():Void
	{
		if (curSection + 1 >= doc.chart.sections.length)
			return;
		var c = doc.copyNotes(doc.chart.sections[curSection].startBeat, doc.sectionEndBeat(curSection));
		doc.pasteInto(curSection + 1, c, true);
		gotoSection(curSection + 1);
	}

	// ------------------------------------------------------------------ transporte e ações

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
		inst.volume = instVol;
		voices.volume = voiceVol;
		inst.pitch = speed;
		voices.pitch = speed;
		inst.play(true, songTime);
		if (hasVoices && doc.chart.needsVoices)
			voices.play(true, songTime);
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

	function moveUnits(dir:Int):Void
	{
		var u = grid.unit();
		var idx = Math.round(doc.tempo.beatAt(songTime) / u) + dir;
		seek(doc.tempo.msAt(Math.max(0, idx * u)));
	}

	function save():Void
	{
		var p = ChartIO.save(doc);
		if (p != null)
		{
			var note = analysis.cohesionSummary();
			say(note == null ? "Salvo em " + p : "Salvo. Atenção: " + note, note == null);
		}
		else
			say("Erro ao salvar (veja o log).", false);
	}

	function doUndo():Void
	{
		var n = doc.undo();
		if (n != null)
			say("Desfeito: " + n);
	}

	function doRedo():Void
	{
		var n = doc.redo();
		if (n != null)
			say("Refeito: " + n);
	}

	function testPlay():Void
	{
		if (ChartIO.save(doc) == null)
		{
			say("Não foi possível salvar para testar.", false);
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
			say("Há alterações não salvas! Clique em SAIR / ESC de novo para sair sem salvar.", false);
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
			songTime += elapsed * 1000 * speed;
			if (inst.playing && Math.abs(inst.time - songTime) > 40)
				songTime = inst.time;
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

		if (!TextInput.typing() && !TextInput.swallow)
			keys(elapsed);
		TextInput.swallow = false;

		var beat = doc.tempo.beatAt(songTime);
		curSection = doc.sectionIndexAtBeat(Math.max(0, beat));
		grid.playing = playing;
		grid.sync(beat * 4, elapsed);
		lane.sync();
		preview.sync(songTime, playing, curSection, currentBpm(), elapsed);
		var allow = !EdLock.locked && !TextInput.typing();
		grid.mouse(allow);
		lane.mouse(allow);

		playBtn.setText(playing ? "PAUSAR" : "PLAY");
		setText(titleText, songId + (suffix == "" ? " [normal]" : " [" + suffix.substr(1) + "]") + (doc.dirty ? "  *" : ""));
		setText(timeText, fmtTime(songTime) + " / " + fmtTime(lengthMs));
		var s = doc.chart.sections[curSection];
		var secNotes = doc.notesIn(s.startBeat, doc.sectionEndBeat(curSection)).length;
		setText(infoText, "beat " + Math.floor(beat * 100) / 100 + "   step " + Math.floor(beat * 4) + "   seção " + curSection + "\nBPM " + currentBpm() + "   notas "
			+ doc.chart.notes.length + " (" + secNotes + " na seção)   eventos " + doc.chart.events.length);
		setText(hoverText, lane.hoverName != "" ? "evento: " + lane.hoverName : (playing ? "tocando a " + Std.int(speed * 100) + "%" : "pausado"));
	}

	function setText(t:FlxText, s:String):Void
	{
		if (cache.get(t) != s)
		{
			cache.set(t, s);
			t.text = s;
		}
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

		if (k.justPressed.F1)
			help.toggle();
		if (EdLock.locked)
		{
			if (k.justPressed.ESCAPE)
				help.toggle();
			return;
		}
		if (k.justPressed.ESCAPE)
			leave();
		if (k.justPressed.SPACE)
			togglePlay();
		if (k.justPressed.ENTER)
			testPlay();
		if (k.justPressed.TAB)
			tabs.select((tabs.index + 1) % 6);
		if (ctrl && k.justPressed.S)
			save();
		if (ctrl && k.justPressed.Z)
			doUndo();
		if (ctrl && k.justPressed.Y)
			doRedo();
		if (k.justPressed.DELETE || k.justPressed.BACKSPACE)
		{
			if (lane.sel != null && grid.sel == null)
				lane.deleteSelected();
			else
				grid.deleteSelected();
		}
		if (k.justPressed.LBRACKET)
			setSpeed(speed - 0.25);
		if (k.justPressed.RBRACKET)
			setSpeed(speed + 0.25);
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
			for (_ in 0...(k.pressed.SHIFT ? 4 : 1))
				moveUnits(FlxG.mouse.wheel < 0 ? 1 : -1);
	}

	function cycleQuant(dir:Int):Void
	{
		var i = QUANTS.indexOf(grid.quant);
		grid.quant = QUANTS[(i + dir + QUANTS.length) % QUANTS.length];
	}

	override public function destroy():Void
	{
		tabIndex = tabs != null ? tabs.index : 0;
		EdLock.locked = false;
		TextInput.current = null;
		FlxG.sound.muteKeys = savedMute;
		FlxG.sound.volumeUpKeys = savedUp;
		FlxG.sound.volumeDownKeys = savedDown;
		if (inst != null)
			inst.stop();
		if (voices != null)
			voices.stop();
		super.destroy();
	}
}
