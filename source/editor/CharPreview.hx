package editor;

import core.Chart.EventData;
import core.Chart.NoteData;
import editor.ChartDoc.Cmd;
import editor.ui.EdUI;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import game.Character;
import game.Stage;

using StringTools;

/**
 * Preview de personagens dentro do editor. Desenha Stage + Character reais (os mesmos do jogo) numa câmera própria,
 * dentro do cartão da esquerda, sem encostar na grade.
 *
 *  - Reage ao chart: ao tocar, cada nota faz o personagem certo cantar (singLEFT/DOWN/UP/RIGHT, com -alt quando a nota
 *    usa alt), com dança no ritmo e os eventos da música (Play Animation, Hey!, Camera Flash/Shake/Zoom/Focus).
 *    Com a música parada, mover o cursor mostra a pose que o jogo teria naquele ponto.
 *  - Reage ao ChartTab: trocar Oponente, Jogador, GF ou Cenário atualiza na hora. Cada troca recria só o que mudou, e o
 *    Character é recriado com o isPlayer certo (flipX, singLEFT/RIGHT e posição vêm do próprio Character e do Stage).
 *  - Ferramentas de teste (aba PREVIEW): idle, direções, miss, hey e qualquer animação do personagem escolhido.
 */
class CharPreview extends FlxGroup
{
	public static inline var PX:Int = EdTheme.LEFT_X;
	public static inline var PY:Int = EdTheme.TOP_H + 12;
	public static inline var PW:Int = EdTheme.LEFT_W;
	public static inline var PH:Int = 236;

	// janela onde o mundo é desenhado
	public static inline var VX:Int = PX + 12;
	public static inline var VY:Int = PY + 34;
	public static inline var VW:Int = PW - 24;
	public static inline var VH:Int = PH - 70;

	// opções (valem enquanto o programa estiver aberto)
	public static var optStage:Bool = true; // mostrar o cenário
	public static var optFollow:Bool = true; // seguir o chart (notas e eventos)
	public static var optFraming:Int = 0; // 0 = cena toda, 1 = foco do chart, 2 = personagem selecionado
	public static var optSel:Int = 1; // 0 = oponente, 1 = jogador, 2 = GF
	public static var pickAnim:String = ""; // animação escolhida na aba

	var doc:ChartDoc;
	var toast:String->Bool->Void;
	var cam:FlxCamera;

	var world:FlxGroup = new FlxGroup();
	var wGf:FlxGroup = new FlxGroup();
	var wDad:FlxGroup = new FlxGroup();
	var wBf:FlxGroup = new FlxGroup();
	var stg:Stage;
	var dad:Character;
	var bf:Character;
	var gf:Character;
	var gfHidden:Bool = false;

	var kStage:String = "\u0000";
	var kP1:String = "\u0000";
	var kP2:String = "\u0000";
	var kGf:String = "\u0000";
	var kNames:String = "";
	var eP1:String = "bf";
	var eP2:String = "dad";
	var eGf:String = "gf";

	var nameL:FlxText;
	var nameC:FlxText;
	var nameR:FlxText;

	// por personagem: 0 = oponente, 1 = jogador, 2 = GF
	var hold:Array<Float> = [0, 0, 0]; // segundos até voltar ao idle
	var manual:Array<Bool> = [false, false, false]; // true = contando mesmo com a música parada
	var pose:Array<NoteData> = [null, null]; // nota que originou a pose do cursor

	var lastTime:Float = 0;
	var lastPlaying:Bool = false;
	var lastVersion:Int = -1;
	var lastBeat:Int = -1;
	var lastSection:Int = -1;
	var forcePose:Bool = true;
	var focusOver:String = "";
	var missLane:Int = 0;

	var cx:Float = 0;
	var cy:Float = 0;
	var cz:Float = 0.2;
	var tx:Float = 0;
	var ty:Float = 0;
	var tz:Float = 0.2;
	var zoomBump:Float = 0;
	var snap:Bool = true;

	public function new(doc:ChartDoc, toast:String->Bool->Void)
	{
		super();
		this.doc = doc;
		this.toast = toast;

		add(new Card(PX, PY, PW, PH, "Preview"));
		add(new Btn(PX + PW - 100, PY + 6, 88, 22, "INVERTER", swapChars, 2));

		add(EdTheme.text(PX + 14, PY + PH - 34, 120, 12, "OPONENTE", EdTheme.DIM));
		add(EdTheme.text(PX + PW / 2 - 40, PY + PH - 34, 80, 12, "GF", EdTheme.DIM, FlxTextAlign.CENTER));
		add(EdTheme.text(PX + PW - 134, PY + PH - 34, 120, 12, "JOGADOR", EdTheme.DIM, FlxTextAlign.RIGHT));
		nameL = EdTheme.text(PX + 14, PY + PH - 21, 140, 12, "", EdTheme.TEXT);
		nameC = EdTheme.text(PX + PW / 2 - 50, PY + PH - 21, 100, 12, "", EdTheme.TEXT, FlxTextAlign.CENTER);
		nameR = EdTheme.text(PX + PW - 154, PY + PH - 21, 140, 12, "", EdTheme.TEXT, FlxTextAlign.RIGHT);
		add(nameL);
		add(nameC);
		add(nameR);

		// câmera própria: só o que está em `world` aparece nela
		cam = new FlxCamera(VX, VY, VW, VH);
		cam.bgColor = 0xFF0E1218;
		FlxG.cameras.add(cam, false);
		world.cameras = [cam];
		add(world);
	}

	// ------------------------------------------------------------------ montagem

	/** Quem ocupa cada slot no instante t: o chart, mais os eventos "Change Character" já passados. */
	function resolveIds(t:Float):Void
	{
		var c = doc.chart;
		eP1 = c.player1;
		eP2 = c.player2;
		eGf = c.gf;
		for (e in c.events)
		{
			if (e.time > t)
				break;
			if (e.name != "Change Character" || e.v2 == null || e.v2.trim() == "")
				continue;
			var id = e.v2.trim();
			switch (e.v1.trim().toLowerCase())
			{
				case "bf", "boyfriend", "player":
					eP1 = id;
				case "dad", "opponent":
					eP2 = id;
				case "gf", "girlfriend":
					eGf = id;
				default:
			}
		}
	}

	function refreshWorld(t:Float):Void
	{
		var c = doc.chart;
		resolveIds(t);
		var stageChanged = c.stage != kStage;
		if (stageChanged)
		{
			kStage = c.stage;
			buildStage();
		}
		if (stg == null)
			return;
		var dadChanged = stageChanged || eP2 != kP2 || eGf != kGf;
		var bfChanged = stageChanged || eP1 != kP1;
		if (dadChanged)
		{
			kP2 = eP2;
			kGf = eGf;
			buildDadGf();
		}
		if (bfChanged)
		{
			kP1 = eP1;
			buildBf();
		}
		if (dadChanged || bfChanged)
		{
			forcePose = true;
			snap = true;
		}
	}

	function disposeChar(c:Character, w:FlxGroup):Void
	{
		if (c == null)
			return;
		w.remove(c, true);
		c.destroy();
	}

	function buildStage():Void
	{
		disposeChar(dad, wDad);
		disposeChar(bf, wBf);
		disposeChar(gf, wGf);
		dad = null;
		bf = null;
		gf = null;
		if (stg != null)
		{
			for (g in [stg.back, stg.gfLayer, stg.dadLayer, stg.front])
				g.destroy();
			stg = null;
		}
		world.clear();
		wGf.clear();
		wDad.clear();
		wBf.clear();
		try
		{
			stg = new Stage(doc.chart.stage);
		}
		catch (e:Dynamic)
		{
			trace('[CharPreview] cenário "${doc.chart.stage}" falhou: $e');
			return;
		}
		// mesma ordem de desenho do PlayState
		world.add(stg.back);
		world.add(wGf);
		world.add(stg.gfLayer);
		world.add(wDad);
		world.add(stg.dadLayer);
		world.add(wBf);
		world.add(stg.front);
		applyStageVisibility();
	}

	public function applyStageVisibility():Void
	{
		if (stg == null)
			return;
		stg.back.visible = optStage;
		stg.gfLayer.visible = optStage;
		stg.dadLayer.visible = optStage;
		stg.front.visible = optStage;
	}

	function make(slot:String, id:String, isPlayer:Bool):Null<Character>
	{
		try
		{
			var p = stg.positionFor(slot, id);
			var c = new Character(p[0], p[1], id, isPlayer);
			c.holdingKeys = true; // quem decide quando voltar ao idle é o preview, não o Conductor
			return c;
		}
		catch (e:Dynamic)
		{
			trace('[CharPreview] personagem "$id" falhou: $e');
			return null;
		}
	}

	function buildDadGf():Void
	{
		disposeChar(dad, wDad);
		disposeChar(gf, wGf);
		var c = doc.chart;
		gf = make("gf", eGf, false);
		dad = make("dad", eP2, false);
		gfHidden = eP2 == eGf;
		if (gfHidden && dad != null) // gf como oponente: ocupa o lugar da gf (igual ao PlayState)
		{
			var gp = stg.positionFor("gf", eGf);
			dad.setPosition(gp[0], gp[1]);
			if (gf != null)
				gf.visible = false;
		}
		if (gf != null)
			wGf.add(gf);
		if (dad != null)
			wDad.add(dad);
		hold[0] = hold[2] = 0;
		manual[0] = manual[2] = false;
		pose[0] = null;
	}

	function buildBf():Void
	{
		disposeChar(bf, wBf);
		bf = make("bf", eP1, true);
		if (bf != null)
			wBf.add(bf);
		hold[1] = 0;
		manual[1] = false;
		pose[1] = null;
	}

	inline function charAt(i:Int):Null<Character>
		return i == 0 ? dad : (i == 1 ? bf : gf);

	public function selected():Null<Character>
		return charAt(optSel);

	// ------------------------------------------------------------------ chart -> personagens

	/** Chame todo frame. t = posição da música (ms); section = seção atual; bpm = BPM da seção. */
	public function sync(t:Float, playing:Bool, section:Int, bpm:Float, dt:Float):Void
	{
		cam.visible = EdLock.free(); // a ajuda (F1) cobre a tela inteira
		refreshWorld(t);
		if (stg == null)
			return;

		if (section != lastSection)
		{
			lastSection = section;
			focusOver = "";
		}
		var stepSec = 60 / Math.max(1, bpm) / 4;

		if (playing)
		{
			var d = t - lastTime;
			if (lastPlaying && d >= 0 && d < 300)
			{
				if (optFollow)
				{
					processNotes(lastTime, t, stepSec);
					processEvents(lastTime, t);
				}
				var beat = Math.floor(doc.tempo.beatAt(t));
				if (beat != lastBeat)
				{
					lastBeat = beat;
					danceOnBeat(beat);
				}
			}
			else
			{
				// começou a tocar, ou pulou na música: mostra a pose do ponto atual
				if (optFollow)
					poseAt(t, stepSec);
				lastBeat = Math.floor(doc.tempo.beatAt(t));
			}
		}
		else
		{
			lastBeat = Math.floor(doc.tempo.beatAt(t));
			if (optFollow && (forcePose || t != lastTime || doc.version != lastVersion))
				poseAt(t, stepSec);
		}
		forcePose = false;
		lastTime = t;
		lastPlaying = playing;
		lastVersion = doc.version;

		// volta ao idle depois do tempo de canto
		for (i in 0...3)
		{
			var c = charAt(i);
			if (c == null || hold[i] <= 0 || !(playing || manual[i]))
				continue;
			hold[i] -= dt;
			if (hold[i] <= 0)
			{
				manual[i] = false;
				if (c.isSinging())
					c.dance();
			}
		}

		pick();
		updateCamera(dt, section);
		updateNames();
	}

	function danceOnBeat(beat:Int):Void
	{
		for (c in [gfHidden ? null : gf, dad, bf])
			if (c != null && beat % c.danceEvery == 0 && !c.isSinging())
				c.dance();
	}

	function processNotes(a:Float, b:Float, stepSec:Float):Void
	{
		var notes = doc.chart.notes;
		var i = doc.lowerBound(a);
		while (i < notes.length && notes[i].time <= b)
		{
			var n = notes[i++];
			if (n.time > a)
				singNote(n, stepSec);
		}
	}

	function singNote(n:NoteData, stepSec:Float):Void
	{
		var idx = n.player ? 1 : 0;
		var c = charAt(idx);
		if (c == null)
			return;
		c.specialAnim = false;
		c.sing(n.lane, n.alt); // sem a variação -alt, o próprio Character cai para a animação normal
		hold[idx] = Math.max(n.sustain / 1000, c.singDuration * stepSec);
		manual[idx] = false;
		pose[idx] = null;
	}

	/** Pose que o jogo teria no instante t (com a música parada, ao mover o cursor). */
	function poseAt(t:Float, stepSec:Float):Void
	{
		var notes = doc.chart.notes;
		for (idx in 0...2)
		{
			var c = charAt(idx);
			if (c == null)
				continue;
			var found:NoteData = null;
			var i = doc.lowerBound(t + 0.5) - 1; // última nota até t
			var scanned = 0;
			while (i >= 0 && scanned < 96)
			{
				if (notes[i].player == (idx == 1))
				{
					found = notes[i];
					break;
				}
				i--;
				scanned++;
			}
			var target:NoteData = null;
			if (found != null && t < found.time + Math.max(found.sustain, c.singDuration * stepSec * 1000))
				target = found;
			if (target != pose[idx] || forcePose)
			{
				pose[idx] = target;
				hold[idx] = 0;
				manual[idx] = false;
				c.specialAnim = false;
				if (target != null)
					c.sing(target.lane, target.alt);
				else
					c.dance();
			}
		}
	}

	// ------------------------------------------------------------------ eventos

	function processEvents(a:Float, b:Float):Void
	{
		for (e in doc.chart.events)
			if (e.time > a && e.time <= b)
				applyEvent(e);
	}

	function byName(n:String):Null<Character>
		return switch (n.trim().toLowerCase())
		{
			case "bf", "boyfriend", "player": bf;
			case "dad", "opponent": dad;
			case "gf", "girlfriend": gf;
			default: null;
		}

	static function hexColor(s:String, def:FlxColor):FlxColor
	{
		var h = s.trim().replace("#", "").replace("0x", "");
		var v = Std.parseInt("0xFF" + h);
		return v == null ? def : v;
	}

	static function num(s:String, def:Float):Float
	{
		var f = Std.parseFloat(s);
		return Math.isNaN(f) ? def : f;
	}

	/** Mesmos eventos embutidos do PlayState (builtinEvent), mais o foco de câmera. */
	function applyEvent(e:EventData):Void
	{
		var v1 = e.v1 == null ? "" : e.v1;
		var v2 = e.v2 == null ? "" : e.v2;
		switch (e.name)
		{
			case "Camera Flash":
				cam.flash(hexColor(v1, FlxColor.WHITE), num(v2, 0.5));
			case "Screen Shake":
				cam.shake(num(v1, 0.01), num(v2, 0.4));
			case "Camera Zoom":
				zoomBump = Math.min(0.5, zoomBump + num(v1, 0.03) / Math.max(0.1, stg.def.zoom));
			case "Play Animation":
				var c = byName(v2);
				if (c != null && v1 != "")
				{
					c.playAnim(v1, true);
					c.specialAnim = (c.animation.curAnim != null && !c.animation.curAnim.looped);
				}
			case "Hey!":
				var who = v1.trim().toLowerCase();
				for (c in [who == "gf" || who == "ambos" ? gf : null, who == "bf" || who == "ambos" ? bf : null])
					if (c != null)
					{
						c.playAnim("hey", true);
						c.specialAnim = true;
					}
			case "Camera Focus":
				focusOver = v1.trim().toLowerCase();
			default:
		}
	}

	// ------------------------------------------------------------------ ferramentas de teste

	/** Troca Oponente <-> Jogador (desfazível com Ctrl+Z). A seleção acompanha o personagem. */
	public function swapChars():Void
	{
		var c = doc.chart;
		var a = c.player1;
		var b = c.player2;
		if (a == b)
		{
			toast("Os dois lados já são o mesmo personagem.", false);
			return;
		}
		doc.run(new Cmd("inverter lados", function() {
			c.player1 = b;
			c.player2 = a;
		}, function() {
			c.player1 = a;
			c.player2 = b;
		}));
		if (optSel == 0)
			optSel = 1;
		else if (optSel == 1)
			optSel = 0;
	}

	/** Força o personagem a refazer a pose do ponto atual (ao religar "Seguir o chart"). */
	public function repose():Void
		forcePose = true;

	function stepSecNow():Float
		return 60 / Math.max(1, doc.tempo.bpmAt(doc.tempo.beatAt(lastTime))) / 4;

	public function manualIdle():Void
	{
		var c = selected();
		if (c == null)
			return;
		hold[optSel] = 0;
		manual[optSel] = false;
		c.specialAnim = false;
		c.dance();
	}

	public function manualSing(lane:Int, miss:Bool = false):Void
	{
		var c = selected();
		if (c == null)
			return;
		var name = "sing" + Character.DIRS[lane] + (miss ? "miss" : "");
		if (!c.hasAnim(name))
		{
			toast(c.id + " não tem a animação " + name + ".", false);
			return;
		}
		c.specialAnim = false;
		c.sing(lane, false, miss);
		hold[optSel] = Math.max(0.45, c.singDuration * stepSecNow());
		manual[optSel] = true;
		if (optSel < 2)
			pose[optSel] = null;
	}

	/** MISS: a cada clique toca o miss de uma direção (esquerda, baixo, cima, direita). */
	public function manualMiss():Void
	{
		manualSing(missLane, true);
		missLane = (missLane + 1) % 4;
	}

	public function manualHey():Void
		playNamed("hey");

	public function animList():Array<String>
	{
		var c = selected();
		if (c == null || c.def == null || c.def.animations == null)
			return [];
		return [for (a in c.def.animations) a.name];
	}

	/** Toca qualquer animação do personagem selecionado (para conferir offsets). */
	public function playNamed(name:String):Void
	{
		var c = selected();
		if (c == null || name == "")
			return;
		if (!c.hasAnim(name))
		{
			toast(c.id + " não tem a animação " + name + ".", false);
			return;
		}
		c.specialAnim = false;
		c.playAnim(name, true);
		if (name.startsWith("sing"))
		{
			hold[optSel] = Math.max(0.45, c.singDuration * stepSecNow());
			manual[optSel] = true;
		}
		else if (c.animation.curAnim != null && !c.animation.curAnim.looped)
			c.specialAnim = true; // volta ao idle quando terminar
	}

	/** Texto de apoio da aba PREVIEW. */
	public function infoLine():String
	{
		var c = selected();
		if (c == null)
			return "(personagem não carregou)";
		var a = c.animation.curAnim;
		var an = a != null ? a.name + "   quadro " + (a.curFrame + 1) + "/" + a.frames.length : "-";
		return c.id + "   " + an + "\noffset [" + Math.round(c.offset.x) + ", " + Math.round(c.offset.y) + "]   posição [" + Math.round(c.x) + ", "
			+ Math.round(c.y) + "]" + (c.flipX ? "   flipX" : "");
	}

	// ------------------------------------------------------------------ seleção, câmera e nomes

	/** Clique num personagem da prévia para selecioná-lo. */
	function pick():Void
	{
		if (!FlxG.mouse.justPressed || !EdLock.free())
			return;
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		if (mx < VX || my < VY || mx >= VX + VW || my >= VY + VH)
			return;
		var wp = FlxG.mouse.getWorldPosition(cam);
		for (i in [1, 0, 2]) // de frente para trás
		{
			var c = charAt(i);
			if (c == null || !c.visible)
				continue;
			if (wp.x >= c.x && wp.x <= c.x + c.width && wp.y >= c.y && wp.y <= c.y + c.height)
			{
				optSel = i;
				break;
			}
		}
		wp.put();
	}

	function focusChar(section:Int):Null<Character>
	{
		var who = focusOver != "" ? focusOver : (doc.chart.sections[section].mustHit ? "bf" : "dad");
		var c = byName(who);
		return c != null ? c : bf;
	}

	function computeTarget(section:Int):Void
	{
		var list:Array<Character> = [];
		var margin = 70.0;
		if (optFraming == 2)
		{
			var c = selected();
			if (c != null)
				list.push(c);
			margin = 110;
		}
		else if (optFraming == 1)
		{
			var c = focusChar(section);
			if (c != null)
				list.push(c);
			margin = 130;
		}
		else
			for (c in [dad, bf, gf])
				if (c != null && c.visible)
					list.push(c);
		if (list.length == 0)
			return;

		var x1 = Math.POSITIVE_INFINITY;
		var y1 = Math.POSITIVE_INFINITY;
		var x2 = Math.NEGATIVE_INFINITY;
		var y2 = Math.NEGATIVE_INFINITY;
		for (c in list) // usa a posição-base (sem offset de animação) para a câmera não tremer ao cantar
		{
			x1 = Math.min(x1, c.x);
			y1 = Math.min(y1, c.y);
			x2 = Math.max(x2, c.x + c.width);
			y2 = Math.max(y2, c.y + c.height);
		}
		var bw = x2 - x1 + margin * 2;
		var bh = y2 - y1 + margin * 2;
		tx = (x1 + x2) / 2;
		ty = (y1 + y2) / 2;
		tz = Math.max(0.04, Math.min(0.9, Math.min(VW / bw, VH / bh)));
	}

	function updateCamera(dt:Float, section:Int):Void
	{
		computeTarget(section);
		if (snap)
		{
			cx = tx;
			cy = ty;
			cz = tz;
			snap = false;
		}
		else
		{
			cx = EdTheme.lerpf(cx, tx, dt, 7);
			cy = EdTheme.lerpf(cy, ty, dt, 7);
			cz = EdTheme.lerpf(cz, tz, dt, 7);
		}
		zoomBump = EdTheme.lerpf(zoomBump, 0, dt, 5);
		cam.zoom = cz * (1 + zoomBump);
		var p = FlxPoint.get(cx, cy);
		cam.focusOn(p);
		p.put();
	}

	function updateNames():Void
	{
		var c = doc.chart;
		var k = eP2 + "|" + eGf + "|" + eP1 + "|" + optSel;
		if (k == kNames)
			return;
		kNames = k;
		nameL.text = eP2;
		nameC.text = eGf;
		nameR.text = eP1;
		nameL.color = optSel == 0 ? EdTheme.ACCENT : EdTheme.TEXT;
		nameC.color = optSel == 2 ? EdTheme.ACCENT : EdTheme.TEXT;
		nameR.color = optSel == 1 ? EdTheme.ACCENT : EdTheme.TEXT;
	}
}
