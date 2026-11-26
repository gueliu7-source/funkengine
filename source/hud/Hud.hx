package hud;

import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import game.Judge;
import game.NoteSkin;
import hud.HudStyles;
import states.PlayState;

private class Popup
{
	public var spr:FlxSprite;
	public var life:Float = 0;
	public var age:Float = 0;
	public var base:Float = 1; // escala normal
	public var delay:Float = 0; // atraso para animar os dígitos em sequência
	public var wobble:Float = 0; // balanço lateral (rating ruim)

	public function new(spr:FlxSprite)
	{
		this.spr = spr;
		base = spr.scale.x;
		spr.visible = false;
		spr.active = false;
	}
}

/**
 * HUD novo. Tudo é desenhado/atualizado só quando muda:
 * - barra de vida em 3 retângulos (sem imagem), ícones que pulsam na batida;
 * - linha de status (score, erros, precisão, rank) reconstruída só quando um valor muda;
 * - barra de progresso da música, contador de julgamentos e popups de rating em pool.
 */
@:keep
class Hud extends FlxGroup
{
	var style:HudStyle;
	var judge:Judge;
	var songTitle:String;
	var diffName:String;
	var down:Bool;
	public var barParts:Array<FlxSprite> = []; // moldura + as duas cores da barra (scripts Psych: healthBar)
	public var bar:BarProxy;

	var barBg:FlxSprite;
	public var barOpp:FlxSprite;
	public var barPlr:FlxSprite;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	var fillX:Float; // área interna da barra (onde as cores aparecem)
	var fillY:Float;
	var fillW:Int;
	var fillH:Int;
	var frameBottom:Float;
	var shownHealth:Float = 1; // vida "desenhada": desliza até a vida real (a barra e os ícones andam suave)
	var shownScore:Float = 0; // pontuação que sobe contando até o valor real
	var lastScoreInt:Int = -1;
	var lowT:Float = 0; // relógio do aviso de vida baixa

	public var scoreText:FlxText;
	var scoreL:FlxText; // usados só no layout "codename" (esquerda / meio / direita)
	var scoreM:FlxText;
	var scoreR:FlxText;
	public var timeTxt:FlxText;
	var infoText:FlxText;
	var counters:Array<FlxText> = [];
	public var botplayText:FlxText;

	var progBg:FlxSprite;
	var progFill:FlxSprite;
	var timeLeftSec:Int = -1;
	var songLength:Float = 1;

	var ratingPools:Map<String, Array<Popup>> = new Map();
	var digitPools:Array<Array<Popup>> = [];
	var live:Array<Popup> = [];
	var msText:FlxText;
	var msLife:Float = 0;
	var goldPool:Array<Popup>;
	var goldBuilt:Bool = false;

	public function new(judge:Judge, songTitle:String, p1Icon:String, p2Icon:String, p1Color:FlxColor, p2Color:FlxColor)
	{
		super();
		this.judge = judge;
		this.songTitle = songTitle;
		style = HudStyles.get(Settings.d.hudStyle);
		down = Settings.d.downscroll;
		diffName = switch (PlayState.difficulty)
		{
			case "-easy": "Easy";
			case "-hard": "Hard";
			default: "Normal";
		}

		if (style.fixedColors)
		{
			p1Color = 0xFF66FF33;
			p2Color = 0xFFFF0000;
		}

		// --- barra de vida
		fillW = style.barW;
		fillH = style.barH;
		var inset = style.barImage ? 4 : style.border;
		var frameW = fillW + inset * 2;
		var frameH = fillH + inset * 2;
		var frameX = (FlxG.width - frameW) / 2;
		var frameY = down ? FlxG.height * 0.11 : FlxG.height * 0.89 - frameH / 2;
		fillX = frameX + inset;
		fillY = frameY + inset;
		frameBottom = frameY + frameH;

		if (style.barImage)
		{
			var g = Paths.graphic("images/healthBar.png");
			if (g != null)
			{
				var bgImg = new FlxSprite(frameX, frameY).loadGraphic(g);
				bgImg.scrollFactor.set();
				bgImg.moves = false;
				add(bgImg);
				barParts.push(bgImg);
			}
			else
			{
				var bgr = rect(frameX, frameY, frameW, frameH, 0xFF000000);
				add(bgr);
				barParts.push(bgr);
			}
		}
		else if (inset > 0)
		{
			var bgr = rect(frameX, frameY, frameW, frameH, 0xFF101018);
			add(bgr);
			barParts.push(bgr);
		}
		barOpp = rect(fillX, fillY, fillW, fillH, p2Color);
		barPlr = rect(fillX, fillY, fillW, fillH, p1Color);
		barPlr.origin.set(fillW, 0); // a barra do jogador encolhe a partir da direita
		add(barOpp);
		add(barPlr);
		barParts.push(barOpp);
		barParts.push(barPlr);
		bar = new BarProxy(this, fillX, fillY, fillW, fillH);

		iconP1 = new HealthIcon(p1Icon, true);
		iconP2 = new HealthIcon(p2Icon, false);
		add(iconP1);
		add(iconP2);

		// --- textos de pontuação
		var ty = frameBottom + style.scoreDy;
		if (style.score == "codename")
		{
			var w = frameW / 3;
			scoreL = text(frameX, ty, w, style.scoreSize, FlxTextAlign.LEFT);
			scoreM = text(frameX + w, ty, w, style.scoreSize, FlxTextAlign.CENTER);
			scoreR = text(frameX + w * 2, ty, w, style.scoreSize, FlxTextAlign.RIGHT);
			add(scoreL);
			add(scoreM);
			add(scoreR);
			scoreText = text(0, -100, 10, 8, FlxTextAlign.LEFT); // não usado, evita null
		}
		else
		{
			scoreText = text(0, ty, FlxG.width, style.scoreSize, FlxTextAlign.CENTER);
			add(scoreText);
		}

		botplayText = text(0, down ? FlxG.height - 120 : 120, FlxG.width, 32, FlxTextAlign.CENTER);
		botplayText.text = "BOTPLAY";
		botplayText.visible = Settings.d.botplay;
		add(botplayText);

		// --- tempo da música
		var showTime = Settings.d.hudSongBar && style.time != "none";
		if (showTime && (style.time == "top" || style.time == "bottom"))
		{
			var atTop = (style.time == "top") != down;
			var barH = style.timeInside ? 18 : 8;
			var progY:Float = atTop ? 14 : FlxG.height - 22;
			progBg = rect((FlxG.width - 400) / 2 - 2, progY - 2, 404, barH + 4, 0xFF000000);
			progFill = rect((FlxG.width - 400) / 2, progY, 400, barH, 0xFFE8E8F0);
			progFill.origin.set(0, 0);
			progFill.scale.x = 0;
			add(progBg);
			add(progFill);
			var ny:Float = style.timeInside ? progY - 3 : (atTop ? progY + 14 : progY - 26);
			timeTxt = text(0, ny, FlxG.width, style.timeInside ? 16 : 16, FlxTextAlign.CENTER);
			timeTxt.text = songTitle;
			add(timeTxt);
		}
		else if (showTime && style.time == "text")
		{
			timeTxt = text(0, down ? FlxG.height - 34 : 12, FlxG.width, 18, FlxTextAlign.CENTER);
			timeTxt.text = songTitle + " - " + diffName;
			add(timeTxt);
		}

		if (style.info)
		{
			infoText = text(8, FlxG.height - 28, 500, 16, FlxTextAlign.LEFT);
			infoText.text = songTitle + " - " + diffName;
			add(infoText);
		}

		// --- contador de julgamentos
		if (Settings.d.hudJudgementCounter && style.counters)
		{
			var colors:Array<FlxColor> = [0xFF00D5FF, 0xFF6BFF6B, 0xFFFFB84D, 0xFFFF5A5A, 0xFFB01E1E];
			for (i in 0...5)
			{
				var t = text(18, 270 + i * 21, 200, 14, FlxTextAlign.LEFT);
				t.color = colors[i];
				t.alpha = 0.75;
				t.borderSize = 1;
				counters.push(t);
				add(t);
			}
		}

		msText = text(0, 0, 160, 16, FlxTextAlign.CENTER);
		msText.visible = false;
		add(msText);

		buildPools();
		shownHealth = judge.health;
		refresh();
		applyBar();
		timeLeftSec = -1;
	}

	function buildPools():Void
	{
		var suffix = NoteSkin.pixel ? "-pixel" : "";
		var folder = NoteSkin.pixel ? "pixelUI/" : "";
		var zoom = NoteSkin.pixel ? NoteSkin.PIXEL_ZOOM * 0.7 : style.ratingScale;
		for (r in ["sick", "good", "bad", "shit"])
		{
			var list:Array<Popup> = [];
			var g = Paths.graphic('images/$folder$r$suffix.png');
			if (g == null)
				g = Paths.graphic('images/$r.png');
			for (i in 0...3)
			{
				var s = new FlxSprite();
				if (g != null)
					s.loadGraphic(g);
				s.scale.set(zoom, zoom);
				s.updateHitbox();
				s.scrollFactor.set();
				s.antialiasing = !NoteSkin.pixel && Settings.d.antialiasing;
				add(s);
				list.push(new Popup(s));
			}
			ratingPools.set(r, list);
		}
		var dz = NoteSkin.pixel ? NoteSkin.PIXEL_ZOOM * 0.5 : style.ratingScale * 0.7;
		for (d in 0...10)
		{
			var list:Array<Popup> = [];
			var g = Paths.graphic('images/$folder' + 'num$d$suffix.png');
			if (g == null)
				g = Paths.graphic('images/num$d.png');
			for (i in 0...3)
			{
				var s = new FlxSprite();
				if (g != null)
					s.loadGraphic(g);
				s.scale.set(dz, dz);
				s.updateHitbox();
				s.scrollFactor.set();
				s.antialiasing = !NoteSkin.pixel && Settings.d.antialiasing;
				add(s);
				list.push(new Popup(s));
			}
			digitPools.push(list);
		}
	}

	/** Sick dourado (estilo Forever): recolore o sick.png em tons de ouro, só na primeira vez que precisa. */
	function ensureGold():Void
	{
		if (goldBuilt)
			return;
		goldBuilt = true;
		var suffix = NoteSkin.pixel ? "-pixel" : "";
		var folder = NoteSkin.pixel ? "pixelUI/" : "";
		var g = Paths.graphic('images/$folder' + 'sick$suffix.png');
		if (g == null)
			g = Paths.graphic('images/sick.png');
		if (g == null)
			return;
		var bd = g.bitmap.clone();
		for (y in 0...bd.height)
			for (x in 0...bd.width)
			{
				var px:Int = bd.getPixel32(x, y);
				var a = (px >> 24) & 0xFF;
				if (a == 0)
					continue;
				var l = (0.3 * ((px >> 16) & 0xFF) + 0.59 * ((px >> 8) & 0xFF) + 0.11 * (px & 0xFF)) / 255;
				l = Math.min(1, l * 1.15);
				var r = Std.int(110 + (255 - 110) * l);
				var gg = Std.int(60 + (216 - 60) * l);
				var b = Std.int(0 + (90 - 0) * l * l);
				bd.setPixel32(x, y, (a << 24) | (r << 16) | (gg << 8) | b);
			}
		var gold = FlxGraphic.fromBitmapData(bd);
		var zoom = NoteSkin.pixel ? NoteSkin.PIXEL_ZOOM * 0.7 : style.ratingScale;
		goldPool = [];
		for (i in 0...3)
		{
			var s = new FlxSprite();
			s.loadGraphic(gold);
			s.scale.set(zoom, zoom);
			s.updateHitbox();
			s.scrollFactor.set();
			s.antialiasing = !NoteSkin.pixel && Settings.d.antialiasing;
			s.cameras = cameras;
			add(s);
			goldPool.push(new Popup(s));
		}
		ratingPools.set("gold", goldPool);
	}

	// ---------------------------------------------------------------- API usada pelo PlayState

	public function setSongLength(ms:Float):Void
		songLength = ms <= 0 ? 1 : ms;

	public function setProgress(posMs:Float):Void
	{
		if (!Settings.d.hudSongBar)
			return;
		var p = posMs / songLength;
		if (progFill != null)
			progFill.scale.x = p < 0 ? 0 : (p > 1 ? 1 : p);
		if (timeTxt != null && style.time != "none")
		{
			var left = Std.int(Math.max(0, (songLength - posMs) / 1000));
			if (left != timeLeftSec)
			{
				timeLeftSec = left;
				var t = Std.int(left / 60) + ":" + (left % 60 < 10 ? "0" : "") + (left % 60);
				timeTxt.text = style.time == "text" ? songTitle + " - " + diffName + "   " + t : (style.timeInside ? songTitle + " (" + t + ")" : songTitle + "  " + t);
			}
		}
	}

	/** Reconstrói os textos. Chame depois de qualquer mudança de pontuação. */
	public function refresh():Void
	{
		lastScoreInt = Math.round(shownScore);
		writeScore();
		if (counters.length == 5)
		{
			counters[0].text = "Sick: " + judge.sicks;
			counters[1].text = "Good: " + judge.goods;
			counters[2].text = "Bad: " + judge.bads;
			counters[3].text = "Shit: " + judge.shits;
			counters[4].text = "Miss: " + judge.misses;
		}
	}

	public function onBeat(beat:Int):Void
	{
		iconP1.kick(style.bump);
		iconP2.kick(style.bump);
	}

	/** Errou uma nota: o ícone do jogador encolhe de leve e volta ao normal. */
	public function onMiss():Void
		iconP1.kick(0.82);

	/** Formata com 2 casas decimais (95.4 -> "95.40"). Só para valores >= 0. */
	static function fmt2(v:Float):String
	{
		var n = Math.round(v * 100);
		var whole = Std.int(n / 100);
		var frac = Std.int(n - whole * 100);
		return whole + "." + (frac < 10 ? "0" : "") + frac;
	}

	/** Nome de rating do Psych a partir da precisão. */
	static function psychRating(acc:Float):String
	{
		if (acc >= 100)
			return "Perfect!!";
		if (acc >= 90)
			return "Sick!";
		if (acc >= 80)
			return "Great";
		if (acc >= 70)
			return "Good";
		if (acc >= 69)
			return "Nice";
		if (acc >= 60)
			return "Meh";
		if (acc >= 50)
			return "Bruh";
		if (acc >= 40)
			return "Bad";
		if (acc >= 20)
			return "Shit";
		return "You Suck!";
	}

	static function pad(v:Int, n:Int):String
	{
		var s = Std.string(v);
		while (s.length < n)
			s = "0" + s;
		return s;
	}

	function writeScore():Void
	{
		var sc = Std.string(Std.int(Math.round(shownScore)));
		var acc = fmt2(judge.accuracy);
		var none = judge.totalPlayed == 0;
		switch (style.score)
		{
			case "clean":
				// Score (0000) - Accuracy (00%) - Misses (0)   [+ " - FC" só quando o jogador está sem erros]
				var fcTag = (judge.fc == "MFC" || judge.fc == "GFC" || judge.fc == "FC") ? " - FC" : "";
				scoreText.text = "Score (" + pad(Std.int(Math.round(shownScore)), 4) + ") - Accuracy (" + pad(none ? 0 : Std.int(judge.accuracy), 2) + "%) - Misses ("
					+ judge.misses + ")" + fcTag;
				scoreText.color = none ? FlxColor.WHITE : (judge.misses == 0 ? 0xFF9EF0FF : (judge.accuracy < 70 ? 0xFFFFB0B0 : FlxColor.WHITE));
			case "funk":
				// Score - Misses - Accuracy - Ranking - FC
				var fcName = judge.fc == "" ? "-" : judge.fc;
				scoreText.text = "Score: " + sc + "  -  Misses: " + judge.misses + "  -  Accuracy: " + (none ? "0.00" : acc) + "%  -  Ranking: "
					+ (none ? "N/A" : psychRating(judge.accuracy)) + "  -  FC: " + fcName;
				scoreText.color = none ? FlxColor.WHITE : (judge.accuracy >= 99.995 ? 0xFFFFD84A : (judge.misses == 0 ? 0xFF9EF0FF : (judge.accuracy < 70 ? 0xFFFFB0B0 : FlxColor.WHITE)));
			case "kade":
				scoreText.text = "Score:" + sc + " | Combo Breaks:" + judge.misses + " | Accuracy:" + (none ? "0" : acc) + "% | " + judge.rank;
			case "psych":
				var fc = switch (judge.fc)
				{
					case "MFC": " - SFC";
					case "GFC": " - GFC";
					case "FC": " - FC";
					case "SDCB": " - SDCB";
					default: "";
				}
				scoreText.text = "Score: " + sc + " | Misses: " + judge.misses + " | Rating: "
					+ (none ? "?" : psychRating(judge.accuracy) + " (" + acc + "%)" + fc);
			case "codename":
				scoreL.text = "Score: " + sc;
				scoreM.text = "Misses: " + judge.misses;
				scoreR.text = "Accuracy: " + (none ? "-" : acc + "%");
			case "leather":
				scoreText.text = "Score: " + sc + " ~ Misses: " + judge.misses + " ~ Accuracy: " + (none ? "0" : acc) + "% ~ " + judge.rank;
			case "neon":
				scoreText.text = sc + "   //   " + (none ? "--" : acc + "%") + "   //   x" + judge.combo + "   //   " + judge.misses + " miss"
					+ (judge.fc != "" ? "   //   " + judge.fc : "");
				scoreText.color = none ? FlxColor.WHITE : (judge.misses == 0 ? 0xFF7DF9FF : (judge.accuracy < 70 ? 0xFFFF8FA3 : FlxColor.WHITE));
			case "forever":
				scoreText.text = "Score: " + sc + " - Accuracy: " + (none ? "0" : acc) + "%" + (judge.fc != "" ? " [" + judge.fc + "]" : "") + " - Combo Breaks: "
					+ judge.misses;
			default:
				scoreText.text = "Score: " + sc + "  |  Combo: " + judge.combo + "  |  Misses: " + judge.misses + "  |  Accuracy: " + acc + "%  |  " + judge.rank;
				// cor por desempenho: sem erros = azul-claro, precisão baixa = rosado
				if (none)
					scoreText.color = FlxColor.WHITE;
				else if (judge.misses == 0)
					scoreText.color = 0xFF9EF0FF;
				else if (judge.accuracy < 70)
					scoreText.color = 0xFFFFB0B0;
				else
					scoreText.color = FlxColor.WHITE;
		}
	}

	public function popRating(rating:String, combo:Int, diffMs:Float):Void
	{
		if (rating == "sick" || rating == "good")
			iconP1.kick(1.1);

		var baseX = FlxG.width * style.ratingX;
		var baseY = FlxG.height * style.ratingY;

		var gold = rating == "sick" && judge.misses == 0 && judge.accuracy >= 99.995;
		if (gold)
			ensureGold();
		var p = take(ratingPools.get(gold ? "gold" : rating));
		if (p != null)
		{
			p.spr.setPosition(baseX - 40, baseY - 60);
			p.spr.acceleration.y = 550;
			p.spr.velocity.y = -FlxG.random.int(140, 175);
			p.spr.velocity.x = FlxG.random.int(-5, 5);
			p.wobble = (rating == "bad" || rating == "shit") ? 1 : 0;
			show(p, gold ? 1.0 : 0.8);
			if (gold)
				p.spr.angle = 0;
		}

		if (combo >= 10)
		{
			var hundreds = Std.int(combo / 100) % 10;
			var tens = Std.int(combo / 10) % 10;
			var ones = combo % 10;
			var digits = combo >= 100 ? [hundreds, tens, ones] : [tens, ones];
			for (i in 0...digits.length)
			{
				var d = take(digitPools[digits[i]]);
				if (d == null)
					continue;
				d.spr.setPosition(baseX + 43 * i - 90, baseY + 40);
				d.spr.acceleration.y = FlxG.random.int(200, 300);
				d.spr.velocity.y = -FlxG.random.int(140, 160);
				d.spr.velocity.x = FlxG.random.float(-5, 5);
				d.wobble = 0;
				show(d, 0.8);
				d.delay = i * 0.045; // os números entram um depois do outro
				d.spr.visible = false;
			}
		}

		if (Settings.d.hudMsDisplay)
		{
			msText.visible = true;
			msText.alpha = 1;
			msLife = 0.6;
			msText.text = (diffMs > 0 ? "-" : "+") + Std.int(Math.abs(diffMs)) + "ms";
			msText.color = switch (rating)
			{
				case "sick": 0xFF00D5FF;
				case "good": 0xFF6BFF6B;
				case "bad": 0xFFFFB84D;
				default: 0xFFFF5A5A;
			};
			msText.setPosition(baseX - 80, baseY + 4);
		}
	}

	/** tick 0 = "ready", 1 = "set", 2 = "go" */
	public function countdown(tick:Int):Void
	{
		var names = ["ready", "set", "go"];
		if (tick < 0 || tick > 2)
			return;
		var suffix = NoteSkin.pixel ? "-pixel" : "";
		var folder = NoteSkin.pixel ? "pixelUI/" : "";
		var g = Paths.graphic('images/$folder${names[tick]}$suffix.png');
		if (g == null)
			g = Paths.graphic('images/${names[tick]}.png');
		if (g == null)
			return;
		var s = new FlxSprite().loadGraphic(g);
		s.scrollFactor.set();
		if (NoteSkin.pixel)
		{
			s.scale.set(NoteSkin.PIXEL_ZOOM * 0.7, NoteSkin.PIXEL_ZOOM * 0.7);
			s.updateHitbox();
			s.antialiasing = false;
		}
		s.screenCenter();
		s.cameras = cameras; // sprites criados depois precisam herdar a câmera do HUD
		add(s);
		FlxTween.tween(s, {alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(_) {
				remove(s, true);
				s.destroy();
			}
		});
	}

	public function setCharacters(p1Icon:String, p2Icon:String):Void
	{
		// reservado para troca de personagem em scripts
	}

	// ---------------------------------------------------------------- interno

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		tickHealth(elapsed);
		tickScore(elapsed);
		if (judge.health < 0.5) // vida baixa: a barra do jogador pulsa
		{
			lowT += elapsed;
			barPlr.alpha = 0.78 + 0.22 * Math.sin(lowT * 9);
		}
		else if (barPlr.alpha != 1)
			barPlr.alpha = 1;
		iconP1.settle(elapsed);
		iconP2.settle(elapsed);

		var i = live.length;
		while (--i >= 0)
		{
			var p = live[i];
			if (p.delay > 0)
			{
				p.delay -= elapsed;
				if (p.delay > 0)
					continue;
				p.spr.visible = true;
			}
			p.age += elapsed;
			p.life -= elapsed;
			// "pop": começa maior e assenta rápido (≈0,2 s); rating ruim balança de leve
			var k = 1 + 0.5 * Math.exp(-p.age * 18);
			p.spr.scale.set(p.base * k, p.base * k);
			if (p.wobble > 0)
				p.spr.angle = Math.sin(p.age * 38) * 7 * Math.exp(-p.age * 6);
			if (p.life < 0.25)
				p.spr.alpha = p.life < 0 ? 0 : p.life / 0.25;
			if (p.life <= 0)
			{
				p.spr.visible = false;
				p.spr.active = false;
				p.spr.angle = 0;
				p.spr.velocity.set(0, 0);
				p.spr.acceleration.set(0, 0);
				live.splice(i, 1);
			}
		}
		if (msLife > 0)
		{
			msLife -= elapsed;
			if (msLife <= 0)
				msText.visible = false;
		}
		botplayText.visible = Settings.d.botplay;
	}

	/** A vida desenhada desliza até a real (≈0,15 s), então barra e ícones nunca "pulam". */
	function tickHealth(elapsed:Float):Void
	{
		var d = judge.health - shownHealth;
		if (d == 0)
			return;
		if (Math.abs(d) < 0.0005)
			shownHealth = judge.health;
		else
			shownHealth += d * (1 - Math.exp(-elapsed * 14));
		applyBar();
	}

	/** A pontuação sobe contando até o valor real, em vez de trocar de uma vez. */
	function tickScore(elapsed:Float):Void
	{
		var target:Float = judge.score;
		if (shownScore == target)
			return;
		var d = target - shownScore;
		if (Math.abs(d) < 1)
			shownScore = target;
		else
		{
			var step = d * (1 - Math.exp(-elapsed * 16));
			shownScore += Math.abs(step) < 1 ? (d > 0 ? 1.0 : -1.0) : step;
		}
		var shownInt = Math.round(shownScore);
		if (shownInt == lastScoreInt)
			return; // o número na tela não mudou: não reconstrói o texto
		lastScoreInt = shownInt;
		writeScore();
	}

	/** Parte da barra que é do jogador (0..1). */
	public function healthPct():Float
		return judge.health / 2;

	/** Posiciona barra e ícones com a vida desenhada; o quadro do ícone usa a vida real. */
	function applyBar():Void
	{
		var shown = shownHealth / 2; // 0..1
		barPlr.scale.x = shown;
		var edge = fillX + fillW * (1 - shown); // onde o jogador e o oponente se encontram
		if (bar != null && bar.custom)
			bar.layout(shown);
		iconP1.setPosition(edge - 26, fillY + fillH / 2 - iconP1.height / 2);
		iconP2.setPosition(edge - (iconP2.width - 26), fillY + fillH / 2 - iconP2.height / 2);

		var pct = judge.health / 2;
		iconP1.setState(pct < 0.2 ? 1 : (pct > 0.8 ? 2 : 0));
		iconP2.setState(pct > 0.8 ? 1 : (pct < 0.2 ? 2 : 0));
	}

	function take(list:Array<Popup>):Null<Popup>
	{
		if (list == null)
			return null;
		for (p in list)
			if (p.life <= 0)
				return p;
		return list[0]; // todos em uso: reaproveita o mais antigo
	}

	function show(p:Popup, life:Float):Void
	{
		p.life = life;
		p.age = 0;
		p.delay = 0;
		p.spr.alpha = 1;
		p.spr.visible = true;
		p.spr.active = true;
		p.spr.moves = true;
		if (live.indexOf(p) < 0)
			live.push(p);
	}

	function rect(x:Float, y:Float, w:Int, h:Int, c:FlxColor):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(w, h, c);
		s.scrollFactor.set();
		s.moves = false;
		return s;
	}

	function text(x:Float, y:Float, w:Float, size:Int, align:FlxTextAlign):FlxText
	{
		var t = new FlxText(x, y, w, "", size);
		t.setFormat(Paths.FONT, size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 1.5;
		t.scrollFactor.set();
		t.antialiasing = Settings.d.antialiasing;
		return t;
	}
}
