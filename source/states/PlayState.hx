package states;

import core.Chart;
import core.Chart.NoteData;
import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import game.Character;
import game.InputManager;
import game.Judge;
import game.NoteSplashes;
import game.NoteSkin;
import game.Receptor;
import game.Stage;
import game.Strumline;
import hud.Hud;
import scripting.ScriptManager;

/**
 * Orquestra a partida. A lógica pesada vive nos módulos (Conductor, Strumline, Judge,
 * InputManager, Hud, ScriptManager); este arquivo só liga as peças e decide o que acontece a cada frame.
 */
@:keep
class PlayState extends FlxState
{
	public static var instance:PlayState;
	public static var songId:String = "bopeebo";
	public static var difficulty:String = ""; // "", "-easy" ou "-hard"
	public static var week:Int = 1;

	/** Story Mode: músicas que ainda faltam tocar na semana. */
	public static var isStory:Bool = false;
	public static var fromEditor:Bool = false; // veio do Chart Editor: ao sair, volta para ele
	public static var storyPlaylist:Array<String> = [];

	/** Para onde voltar ao sair da partida (Story ou Freeplay). */
	public static function leave():FlxState
	{
		if (fromEditor)
		{
			fromEditor = false;
			return new editor.ChartEditorState();
		}
		if (isStory)
			return new StoryMenuState();
		return new FreeplayState();
	}

	public var chart:Chart;
	public var judge:Judge;
	public var hud:Hud;
	public var scripts:ScriptManager;
	public var input:InputManager;
	public var stage:Stage;

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera; // acima do HUD (câmera "other" dos scripts Psych)
	public var inst:FlxSound;
	public var voices:FlxSound;
	public var oppVoices:FlxSound; // vocais separados (Voices-Opponent.ogg); vazio quando a música tem uma voz só

	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;
	public var playerStrum:Strumline;
	public var splashes:NoteSplashes;
	public var opponentStrum:Strumline;

	public var defaultZoom:Float = 0.9;
	public var scrollSpeed:Float = 1;
	public var started:Bool = false;
	public var ended:Bool = false;
	public var tagged:Map<String, FlxSprite> = new Map();

	var camFollow:FlxObject;
	var errorText:FlxText;
	var errorTimer:Float = 0;
	var eventIdx:Int = 0;
	var dying:Bool = false;

	override public function create():Void
	{
		super.create();
		instance = this;
		FlxG.mouse.visible = false;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		chart = ChartLoader.load(songId, difficulty, week);
		if (chart == null)
		{
			FlxG.switchState(leave());
			return;
		}
		scrollSpeed = Settings.d.scrollSpeed > 0 ? Settings.d.scrollSpeed : chart.speed;
		NoteSkin.load(chart.noteStyle);

		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		camHUD.bgColor = 0x00000000;
		FlxG.cameras.add(camHUD, false);
		camOther = new FlxCamera();
		camOther.bgColor = 0x00000000;
		FlxG.cameras.add(camOther, false);
		for (i in 0...chart.notes.length)
			chart.notes[i].id = i;

		Conductor.clearSignals();
		Conductor.rate = 1;
		var startPos = -(60000 / chart.segments[0].bpm) * 5;
		Conductor.setup(chart.segments, chart.sectionStartBeats(), startPos);

		buildStage();
		buildHud();
		buildStrums();
		buildAudio();

		errorText = new FlxText(10, 4, FlxG.width - 20, "", 16);
		errorText.setFormat(Paths.FONT, 16, 0xFFFF6060, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.cameras = [camHUD];
		errorText.scrollFactor.set();
		errorText.alpha = 0;
		add(errorText);

		input = new InputManager();

		Conductor.beatHit.add(onBeat);
		Conductor.stepHit.add(onStep);
		Conductor.sectionHit.add(onSection);
		subStateClosed.add(onSubClosed);

		scripts = new ScriptManager(this);
		scripts.loadAll(chart);
		scripts.call("onCreate");

		focusCamera(chart.sections[0].mustHit ? "bf" : "dad");
		camGame.focusOn(camFollow.getPosition());
		scripts.call("onCreatePost");
	}

	// ------------------------------------------------------------------ montagem

	function buildStage():Void
	{
		stage = new Stage(chart.stage);
		defaultZoom = stage.def.zoom;
		camGame.zoom = defaultZoom;

		var gp = stage.positionFor("gf", chart.gf);
		var dp = stage.positionFor("dad", chart.player2);
		var bp = stage.positionFor("bf", chart.player1);

		gf = new Character(gp[0], gp[1], chart.gf);
		dad = new Character(dp[0], dp[1], chart.player2);
		boyfriend = new Character(bp[0], bp[1], chart.player1, true);
		if (chart.player2 == chart.gf) // gf como oponente: ocupa o lugar da gf
		{
			dad.setPosition(gp[0], gp[1]);
			gf.visible = false;
		}
		if (stage.def.hideGf == true)
			gf.visible = false;

		for (k in stage.objects.keys()) // scripts enxergam os objetos do cenário pelo id (ex.: "bg")
			tagged.set(k, stage.objects.get(k));

		add(stage.back);
		add(gf);
		add(stage.gfLayer);
		add(dad);
		add(stage.dadLayer);
		add(boyfriend);
		add(stage.front);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);
		camGame.follow(camFollow, LOCKON, 0.04);
	}

	function buildHud():Void
	{
		judge = new Judge();
		hud = new Hud(judge, chart.name, boyfriend.iconName, dad.iconName, boyfriend.barColor, dad.barColor);
		hud.cameras = [camHUD];
		add(hud);
	}

	function buildStrums():Void
	{
		var plr:Array<NoteData> = [];
		var opp:Array<NoteData> = [];
		for (n in chart.notes)
			(n.player ? plr : opp).push(n);

		var down = Settings.d.downscroll;
		var y = down ? 615.0 : 105.0;
		var mid = Settings.d.middlescroll;

		opponentStrum = new Strumline(false, opp, 320, y, scrollSpeed, Conductor.rate, mid, camHUD);
		playerStrum = new Strumline(true, plr, mid ? 640 : 960, y, scrollSpeed, Conductor.rate, false, camHUD);
		opponentStrum.onSpawn = playerStrum.onSpawn = function(n:NoteData) {
			if (scripts != null && scripts.hasPsych)
			{
				scripts.curNote = n;
				scripts.call("onSpawnNote", [n.lane, n.type, n.sustain > 0]);
			}
		};
		add(opponentStrum);
		add(playerStrum);
		splashes = new NoteSplashes(camHUD);
		add(splashes);
	}

	function buildAudio():Void
	{
		inst = new FlxSound();
		var s = Paths.song(chart.id, "Inst");
		if (s != null)
			inst.loadEmbedded(s);
		inst.onComplete = endSong;
		FlxG.sound.list.add(inst);

		voices = new FlxSound();
		if (chart.needsVoices)
		{
			var v = Paths.song(chart.id, "Voices");
			if (v == null)
				v = Paths.song(chart.id, "Voices-Player"); // formato do Psych: vocais separados
			if (v != null)
				voices.loadEmbedded(v);
		}
		FlxG.sound.list.add(voices);
		oppVoices = new FlxSound();
		if (chart.needsVoices)
		{
			var o = Paths.song(chart.id, "Voices-Opponent");
			if (o != null)
				oppVoices.loadEmbedded(o);
		}
		FlxG.sound.list.add(oppVoices);
		hud.setSongLength(inst.length);
	}

	// ------------------------------------------------------------------ API para scripts

	public function receptor(i:Int):Receptor
		return i < 4 ? opponentStrum.receptors[i] : playerStrum.receptors[i - 4];

	public function addToLayer(obj:FlxBasic, layer:String):Void
	{
		switch (layer)
		{
			case "back":
				stage.back.add(obj);
			case "gf":
				stage.gfLayer.add(obj);
			case "dad":
				stage.dadLayer.add(obj);
			case "hud":
				obj.cameras = [camHUD];
				add(obj);
			case "other":
				obj.cameras = [camOther];
				add(obj);
			default:
				stage.front.add(obj);
		}
	}

	public function focusCamera(who:String):Void
	{
		if (camOverride)
			return;
		var c = (who == "gf") ? gf : ((who == "dad" || who == "opponent") ? dad : boyfriend);
		var mp = c.getMidpoint();
		var off = (c == boyfriend && stage.def.camBf != null) ? stage.def.camBf : c.camOffset;
		var ox = off[0];
		var oy = off[1];
		if (stage.def.psych == true) // Psych: deslocamento do personagem + deslocamento do cenário
		{
			var sc = (c == boyfriend) ? stage.def.camBf : (c == gf ? stage.def.camGf : stage.def.camDad);
			ox = c.camOffset[0] + (sc != null ? sc[0] : 0);
			oy = c.camOffset[1] + (sc != null ? sc[1] : 0);
		}
		camFollow.setPosition(mp.x + ox, mp.y + oy);
		mp.put();
	}

	public function showError(msg:String, ?color:FlxColor):Void
	{
		if (errorText == null)
			return;
		errorText.text = msg;
		errorText.color = (color == null) ? 0xFFFF6060 : color;
		errorText.alpha = 1;
		errorTimer = 5;
	}

	// ------------------------------------------------------------------ eventos do Conductor

	function onBeat(beat:Int):Void
	{
		if (beat < 0)
			countdownTick(beat + 4);

		hud.onBeat(beat);
		if (beat > 0 && beat % 4 == 0 && Settings.d.camBeatZoom)
		{
			camGame.zoom += 0.015;
			camHUD.zoom += 0.03;
		}
		if (beat % gf.danceEvery == 0 && !gf.isSinging())
			gf.dance();
		if (beat % boyfriend.danceEvery == 0 && !boyfriend.isSinging())
			boyfriend.dance();
		if (beat % dad.danceEvery == 0 && !dad.isSinging())
			dad.dance();

		scripts.call("onBeatHit", [beat]);
	}

	function onStep(step:Int):Void
	{
		if (started && voices.playing && Math.abs(voices.time - inst.time) > 40)
			voices.time = inst.time; // mantém a voz sincronizada
		if (started && oppVoices.playing && Math.abs(oppVoices.time - inst.time) > 40)
			oppVoices.time = inst.time;
		scripts.call("onStepHit", [step]);
	}

	function onSection(sec:Int):Void
	{
		if (sec < chart.sections.length)
			focusCamera(chart.sections[sec].mustHit ? "bf" : "dad");
		scripts.call("onSectionHit", [sec]);
	}

	function countdownTick(tick:Int):Void
	{
		var suffix = NoteSkin.pixel ? "-pixel" : "";
		var names = ["intro3", "intro2", "intro1", "introGo"];
		if (tick >= 0 && tick < 4)
		{
			var s = Paths.sound('sounds/${names[tick]}$suffix.ogg');
			if (s != null)
				FlxG.sound.play(s, 0.6);
		}
		if (tick >= 1 && tick <= 3)
			hud.countdown(tick - 1);
		scripts.call("onCountdown", [tick]);
	}

	function startSong():Void
	{
		started = true;
		inst.pitch = Conductor.rate;
		voices.pitch = Conductor.rate;
		oppVoices.pitch = Conductor.rate;
		inst.play();
		voices.play();
		oppVoices.play();
		inst.time = 0;
		voices.time = 0;
		oppVoices.time = 0;
		hud.setSongLength(inst.length);
		scripts.call("onSongStart");
	}

	// ------------------------------------------------------------------ loop principal

	override public function update(elapsed:Float):Void
	{
		if (chart == null || ended)
		{
			super.update(elapsed);
			return;
		}

		scripts.call("onUpdate", [elapsed]);
		Conductor.update(elapsed, started ? inst : null);
		if (!started && Conductor.songPosition >= 0)
			startSong();

		stage.updateTimeline(Conductor.curDecBeat);

		var pos = Conductor.songPosition - Settings.d.offsetMs;
		opponentStrum.updateNotes(pos);
		playerStrum.updateNotes(pos);

		processPresses();
		processOpponent(pos);
		processPlayer(pos, elapsed);
		processEvents(pos);

		boyfriend.holdingKeys = input.anyHeld() || Settings.d.botplay;

		var k = Math.exp(-elapsed * 3.2);
		camGame.zoom = defaultZoom + (camGame.zoom - defaultZoom) * k;
		camHUD.zoom = 1 + (camHUD.zoom - 1) * k;
		hud.setProgress(Conductor.songPosition);

		if (errorTimer > 0)
		{
			errorTimer -= elapsed;
			if (errorTimer < 1)
				errorText.alpha = Math.max(0, errorTimer);
		}

		if (FlxG.keys.justPressed.R)
			judge.health = 0;
		if (judge.health <= 0 && !Settings.d.botplay)
			die();
		else if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE)
			pause();

		super.update(elapsed);
		scripts.call("onUpdatePost", [elapsed]);
	}

	// ------------------------------------------------------------------ input do jogador

	function processPresses():Void
	{
		var n = input.pressLane.length;
		for (k in 0...n)
			pressLane(input.pressLane[k], input.pressTime[k] - Settings.d.offsetMs);
		input.clearQueue();

		if (!Settings.d.botplay)
			for (lane in 0...4)
			{
				var r = playerStrum.receptors[lane];
				if (!input.held[lane] && r.animation.name != "static")
					r.play("static");
			}
	}

	function pressLane(lane:Int, t:Float):Void
	{
		scripts.call("onKeyPress", [lane]);
		if (Settings.d.botplay)
			return;
		var win = Settings.d.shitMs;
		var best:NoteData = null;
		for (n in playerStrum.activeNotes)
		{
			if (n.lane != lane || n.hit || n.missed)
				continue;
			var d = n.time - t;
			if (d > win)
				break; // lista ordenada por tempo: o resto está mais longe
			if (d < -win)
				continue;
			best = n;
			break;
		}

		var r = playerStrum.receptors[lane];
		if (best != null)
			hitPlayer(best, best.time - t);
		else
		{
			r.play("pressed");
			if (!Settings.d.ghostTapping)
			{
				judge.registerWrongKey();
				voices.volume = 0;
				boyfriend.sing(lane, false, true);
				missSound();
				hud.onMiss();
				hud.refresh();
				scripts.call("noteMiss", [lane, ""]);
			}
		}
	}

	function hitPlayer(n:NoteData, diff:Float):Void
	{
		var rating = judge.registerHit(diff);
		n.hit = true;
		voices.volume = 1;
		if (n.type != "No Animation" && !n.noAnim)
			boyfriend.sing(n.lane, n.alt);
		var r = playerStrum.receptors[n.lane];
		if (Settings.d.botplay)
			r.flash(0.12);
		else
			r.play("confirm");

		if (n.sustain > 0)
		{
			n.holding = true;
			playerStrum.releaseHead(n);
		}
		else
			n.done = true;

		if (rating == "sick" && Settings.d.noteSplashes)
			splashes.spawn(n.lane, r.cx, r.cy);
		hud.popRating(rating, judge.combo, diff);
		hud.refresh();
		scripts.curNote = n;
		scripts.call("goodNoteHit", [n.lane, rating, n.sustain > 0, n.type]);
	}

	function missNote(n:NoteData):Void
	{
		n.missed = true;
		if (n.sustain > 0)
			n.dropped = true;
		judge.registerMiss(Judge.MISS_HEALTH);
		voices.volume = 0;
		boyfriend.sing(n.lane, false, true);
		missSound();
		hud.onMiss();
		hud.refresh();
		scripts.curNote = n;
		scripts.call("noteMiss", [n.lane, n.type]);
	}

	function missSound():Void
	{
		var s = Paths.sound('sounds/missnote${FlxG.random.int(1, 3)}.ogg');
		if (s != null)
			FlxG.sound.play(s, FlxG.random.float(0.1, 0.2));
	}

	function processPlayer(pos:Float, elapsed:Float):Void
	{
		var win = Settings.d.shitMs;
		var bot = Settings.d.botplay;
		for (n in playerStrum.activeNotes)
		{
			if (n.done)
				continue;
			if (n.time > pos + win)
				break;

			if (!n.hit)
			{
				if (bot)
				{
					if (n.time <= pos)
						hitPlayer(n, 0);
				}
				else if (!n.missed && n.time < pos - win)
					missNote(n);
			}
			else if (n.holding)
			{
				var end = n.time + n.sustain;
				var r = playerStrum.receptors[n.lane];
				if (pos >= end)
				{
					n.holding = false;
					n.done = true;
					if (!input.held[n.lane])
						r.play("static");
				}
				else if (bot || input.held[n.lane])
				{
					boyfriend.holdTimer = 0; // mantém a pose enquanto segura
					judge.addHealth(0.004 * elapsed * 1000 / Conductor.stepCrochet);
					if (bot)
						r.glowTimer = 0.1;
				}
				else if (pos >= end - 100)
				{
					// soltou no finalzinho: conta como completo
					n.holding = false;
					n.done = true;
				}
				else
				{
					// soltou cedo: perde o sustain
					n.holding = false;
					n.dropped = true;
					judge.addHealth(-Judge.DROP_HOLD_HEALTH);
					voices.volume = 0;
				}
			}
		}
	}

	// ------------------------------------------------------------------ oponente e eventos

	function processOpponent(pos:Float):Void
	{
		for (n in opponentStrum.activeNotes)
		{
			if (n.done)
				continue;
			if (n.time > pos)
				break;

			if (!n.hit)
			{
				n.hit = true;
				if (n.type != "No Animation" && !n.noAnim) // tipo do Psych: a nota é acertada mas o personagem não canta
				{
					dad.sing(n.lane, n.alt);
					dad.holdTimer = 0;
				}
				voices.volume = 1;
				opponentStrum.receptors[n.lane].flash(0.15);
				if (n.sustain > 0)
				{
					n.holding = true;
					opponentStrum.releaseHead(n);
				}
				else
					n.done = true;
				scripts.curNote = n;
				scripts.call("opponentNoteHit", [n.lane, n.sustain > 0, n.type]);
			}
			else if (n.holding)
			{
				if (pos >= n.time + n.sustain)
				{
					n.holding = false;
					n.done = true;
				}
				else
				{
					dad.holdTimer = 0;
					opponentStrum.receptors[n.lane].glowTimer = 0.1;
				}
			}
		}
	}

	function processEvents(pos:Float):Void
	{
		while (eventIdx < chart.events.length && chart.events[eventIdx].time <= pos)
		{
			var e = chart.events[eventIdx++];
			runEvent(e.name, e.v1, e.v2);
		}
	}

	static function hexColor(s:String, def:FlxColor):FlxColor
	{
		var h = StringTools.replace(StringTools.replace(StringTools.trim(s), "#", ""), "0x", "");
		var v = Std.parseInt("0xFF" + h);
		return v == null ? def : v;
	}

	static function num(s:String, def:Float):Float
	{
		var f = Std.parseFloat(s);
		return Math.isNaN(f) ? def : f;
	}

	function characterByName(n:String):Null<Character>
		return switch (StringTools.trim(n).toLowerCase())
		{
			case "bf", "boyfriend", "player", "1": boyfriend;
			case "dad", "opponent", "0": dad;
			case "gf", "girlfriend", "2": gf;
			default: null;
		}

	/** Eventos que vêm com a engine (definidos em data/events/*.json). Os outros ficam por conta dos scripts. */
	/** Dispara um evento: o que vem com a engine e depois o onEvent dos scripts (também usado por triggerEvent). */
	public function runEvent(name:String, v1:String, v2:String):Void
	{
		builtinEvent(name, v1, v2);
		scripts.call("onEvent", [name, v1, v2]);
	}

	function builtinEvent(name:String, v1:String, v2:String):Void
	{
		switch (name)
		{
			case "Camera Flash":
				camHUD.flash(hexColor(v1, FlxColor.WHITE), num(v2, 0.5));
			case "Screen Shake":
				if (v1.indexOf(",") >= 0 || v2.indexOf(",") >= 0) // formato do Psych: "duração, intensidade" para a câmera do jogo e do HUD
				{
					psychShake(camGame, v1);
					psychShake(camHUD, v2);
				}
				else
					camGame.shake(num(v1, 0.01), num(v2, 0.4));
			case "Add Camera Zoom": // Psych
				if (camGame.zoom < 1.35)
				{
					camGame.zoom += num(v1, 0.015);
					camHUD.zoom += num(v2, 0.03);
				}
			case "Change Scroll Speed": // Psych: v1 = multiplicador da velocidade do chart, v2 = duração da transição (s)
				var target = chart.speed * num(v1, 1);
				var dur = num(v2, 0);
				if (Settings.d.scrollSpeed <= 0)
				{
					if (dur <= 0)
						applyScrollSpeed(target);
					else
					{
						var from = scrollSpeed;
						flixel.tweens.FlxTween.num(from, target, dur, {ease: flixel.tweens.FlxEase.linear}, applyScrollSpeed);
					}
				}
			case "Camera Follow Pos": // Psych: v1 = x, v2 = y (vazio volta ao normal)
				if (v1 == "" && v2 == "")
					camOverride = false;
				else
				{
					camOverride = true;
					camFollow.setPosition(num(v1, camFollow.x), num(v2, camFollow.y));
				}
			case "Set GF Speed":
				gf.danceEvery = Std.int(Math.max(1, num(v1, 1)));
			case "Camera Zoom":
				camGame.zoom += num(v1, 0.03);
				camHUD.zoom += num(v2, 0.05);
			case "Play Animation":
				var c = characterByName(v2);
				if (c != null && v1 != "")
				{
					c.playAnim(v1, true);
					c.specialAnim = (c.animation.curAnim != null && !c.animation.curAnim.looped);
				}
			case "Camera Focus":
				focusCamera(StringTools.trim(v1).toLowerCase());
			case "Change Character":
				changeCharacter(v1, v2);
			case "Hey!":
				var who = StringTools.trim(v1).toLowerCase();
				if (who == "both" || who == "ambos" || who == "")
					who = "ambos";
				for (c in [who == "gf" || who == "ambos" ? gf : null, who == "bf" || who == "ambos" ? boyfriend : null])
					if (c != null)
					{
						c.playAnim("hey", true);
						c.specialAnim = true;
					}
			default:
		}
	}

	var camOverride:Bool = false; // "Camera Follow Pos" ativo: a câmera ignora o foco automático

	function psychShake(c:FlxCamera, v:String):Void
	{
		var p = v.split(",");
		if (p.length >= 2 && num(p[0], 0) > 0)
			c.shake(num(p[1], 0.03), num(p[0], 0.5));
	}

	function applyScrollSpeed(v:Float):Void
	{
		scrollSpeed = v;
		opponentStrum.setSpeed(v, Conductor.rate);
		playerStrum.setSpeed(v, Conductor.rate);
	}

	/** Evento "Change Character": recria o personagem de um slot na posição do cenário. */
	function changeCharacter(slotName:String, newId:String):Void
	{
		var id = StringTools.trim(newId);
		var old = characterByName(slotName);
		if (old == null || id == "" || id == old.id)
			return;
		var slot = (old == boyfriend) ? "bf" : (old == gf ? "gf" : "dad");
		var p = stage.positionFor(slot, id);
		var nc = new Character(p[0], p[1], id, old == boyfriend);
		var i = members.indexOf(old);
		if (i >= 0)
			members[i] = nc;
		else
			add(nc);
		if (old == boyfriend)
			boyfriend = nc;
		else if (old == gf)
			gf = nc;
		else
			dad = nc;
		old.destroy();
	}

	// ------------------------------------------------------------------ pausa, morte, fim

	function pause():Void
	{
		if (dying || ended)
			return;
		scripts.call("onPause");
		persistentUpdate = false;
		if (started)
		{
			inst.pause();
			voices.pause();
			oppVoices.pause();
		}
		input.releaseAll();
		openSubState(new PauseSubState());
	}

	function onSubClosed(_:FlxSubState):Void
	{
		if (dying || ended)
			return;
		persistentUpdate = true;
		if (started)
		{
			inst.resume();
			voices.resume();
			oppVoices.resume();
		}
		Conductor.touch();
		scripts.call("onResume");
	}

	function die():Void
	{
		if (dying || ended)
			return;
		if (scripts.call("onGameOver"))
			return; // um script devolveu "stop"
		dying = true;
		inst.stop();
		voices.stop();
		oppVoices.stop();
		input.enabled = false;
		persistentUpdate = false;
		persistentDraw = false;
		openSubState(new GameOverSubState(boyfriend.x, boyfriend.y, camHUD));
	}

	public function endSong():Void
	{
		if (ended)
			return;
		ended = true;
		scripts.call("onSongEnd");
		inst.stop();
		voices.stop();
		oppVoices.stop();
		if (isStory && storyPlaylist.length > 0)
		{
			songId = storyPlaylist.shift(); // próxima música da semana
			FlxG.switchState(new PlayState());
		}
		else
			FlxG.switchState(leave());
	}

	override public function destroy():Void
	{
		if (input != null)
			input.destroy();
		if (scripts != null)
			scripts.destroy();
		Conductor.clearSignals();
		instance = null;
		super.destroy();
		Paths.clearCache();
	}
}
