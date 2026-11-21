package hud;

import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import game.Judge;
import game.NoteSkin;

private class Popup
{
	public var spr:FlxSprite;
	public var life:Float = 0;

	public function new(spr:FlxSprite)
	{
		this.spr = spr;
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
	static inline var BAR_W:Int = 600;
	static inline var BAR_H:Int = 14;

	var judge:Judge;
	var down:Bool;

	var barBg:FlxSprite;
	var barOpp:FlxSprite;
	var barPlr:FlxSprite;
	var iconP1:HealthIcon;
	var iconP2:HealthIcon;
	var barX:Float;
	var barY:Float;
	var shownHealth:Float = 1; // vida "desenhada": desliza até a vida real (a barra e os ícones andam suave)
	var shownScore:Float = 0; // pontuação que sobe contando até o valor real

	var scoreText:FlxText;
	var counters:Array<FlxText> = [];
	var botplayText:FlxText;

	var progBg:FlxSprite;
	var progFill:FlxSprite;
	var songName:FlxText;
	var songTime:FlxText;
	var lastSecond:Int = -1;
	var songLength:Float = 1;

	var ratingPools:Map<String, Array<Popup>> = new Map();
	var digitPools:Array<Array<Popup>> = [];
	var live:Array<Popup> = [];
	var msText:FlxText;
	var msLife:Float = 0;

	public function new(judge:Judge, songTitle:String, p1Icon:String, p2Icon:String, p1Color:FlxColor, p2Color:FlxColor)
	{
		super();
		this.judge = judge;
		down = Settings.d.downscroll;

		barX = (FlxG.width - BAR_W) / 2;
		barY = down ? 76 : FlxG.height - 78;

		barBg = rect(barX - 4, barY - 4, BAR_W + 8, BAR_H + 8, 0xFF101018);
		barOpp = rect(barX, barY, BAR_W, BAR_H, p2Color);
		barPlr = rect(barX, barY, BAR_W, BAR_H, p1Color);
		barPlr.origin.set(BAR_W, 0); // a barra do jogador encolhe a partir da direita
		add(barBg);
		add(barOpp);
		add(barPlr);

		iconP1 = new HealthIcon(p1Icon, true);
		iconP2 = new HealthIcon(p2Icon, false);
		add(iconP1);
		add(iconP2);

		scoreText = text(0, down ? barY - 44 : barY + 28, FlxG.width, 20, FlxTextAlign.CENTER);
		add(scoreText);

		botplayText = text(0, down ? FlxG.height - 120 : 120, FlxG.width, 32, FlxTextAlign.CENTER);
		botplayText.text = "BOTPLAY";
		botplayText.visible = Settings.d.botplay;
		add(botplayText);

		// barra de progresso da música
		var progY = down ? FlxG.height - 22 : 14;
		progBg = rect((FlxG.width - 400) / 2, progY, 400, 8, 0xFF101018);
		progFill = rect((FlxG.width - 400) / 2, progY, 400, 8, 0xFFE8E8F0);
		progFill.origin.set(0, 0);
		progFill.scale.x = 0;
		songName = text(0, down ? progY - 26 : progY + 12, FlxG.width, 16, FlxTextAlign.CENTER);
		songName.text = songTitle;
		songTime = text(0, down ? progY - 26 : progY + 12, FlxG.width - 300, 14, FlxTextAlign.RIGHT);
		songTime.visible = false;
		if (Settings.d.hudSongBar)
		{
			add(progBg);
			add(progFill);
			add(songName);
		}

		// contador de julgamentos
		if (Settings.d.hudJudgementCounter)
		{
			var colors:Array<FlxColor> = [0xFF00D5FF, 0xFF6BFF6B, 0xFFFFB84D, 0xFFFF5A5A, 0xFFB01E1E];
			for (i in 0...5)
			{
				var t = text(18, 250 + i * 26, 220, 20, FlxTextAlign.LEFT);
				t.color = colors[i];
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
	}

	function buildPools():Void
	{
		var suffix = NoteSkin.pixel ? "-pixel" : "";
		var folder = NoteSkin.pixel ? "pixelUI/" : "";
		var zoom = NoteSkin.pixel ? NoteSkin.PIXEL_ZOOM * 0.7 : 0.7;
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
		var dz = NoteSkin.pixel ? NoteSkin.PIXEL_ZOOM * 0.5 : 0.5;
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

	// ---------------------------------------------------------------- API usada pelo PlayState

	public function setSongLength(ms:Float):Void
		songLength = ms <= 0 ? 1 : ms;

	public function setProgress(posMs:Float):Void
	{
		if (!Settings.d.hudSongBar)
			return;
		var p = posMs / songLength;
		progFill.scale.x = p < 0 ? 0 : (p > 1 ? 1 : p);
	}

	/** Reconstrói os textos. Chame depois de qualquer mudança de pontuação. */
	public function refresh():Void
	{
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
		iconP1.bump();
		iconP2.bump();
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

	function writeScore():Void
	{
		scoreText.text = "Score: " + Std.int(Math.round(shownScore)) + "  |  Combo: " + judge.combo + "  |  Misses: " + judge.misses
			+ "  |  Accuracy: " + fmt2(judge.accuracy) + "%  |  " + judge.rank;
		// cor por desempenho: sem erros = azul-claro, precisão baixa = rosado
		if (judge.totalPlayed == 0)
			scoreText.color = FlxColor.WHITE;
		else if (judge.misses == 0)
			scoreText.color = 0xFF9EF0FF;
		else if (judge.accuracy < 70)
			scoreText.color = 0xFFFFB0B0;
		else
			scoreText.color = FlxColor.WHITE;
	}

	public function popRating(rating:String, combo:Int, diffMs:Float):Void
	{
		if (rating == "sick" || rating == "good")
			iconP1.kick(1.1);

		var baseX = FlxG.width * 0.55;
		var baseY = FlxG.height * 0.42;

		var p = take(ratingPools.get(rating));
		if (p != null)
		{
			p.spr.setPosition(baseX - 40, baseY - 60);
			p.spr.acceleration.y = 550;
			p.spr.velocity.y = -FlxG.random.int(140, 175);
			p.spr.velocity.x = FlxG.random.int(-5, 5);
			show(p, 0.8);
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
				show(d, 0.8);
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
		iconP1.settle(elapsed);
		iconP2.settle(elapsed);

		var i = live.length;
		while (--i >= 0)
		{
			var p = live[i];
			p.life -= elapsed;
			if (p.life < 0.25)
				p.spr.alpha = p.life < 0 ? 0 : p.life / 0.25;
			if (p.life <= 0)
			{
				p.spr.visible = false;
				p.spr.active = false;
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
		writeScore();
	}

	/** Posiciona barra e ícones com a vida desenhada; o quadro do ícone usa a vida real. */
	function applyBar():Void
	{
		var shown = shownHealth / 2; // 0..1
		barPlr.scale.x = shown;
		var edge = barX + BAR_W * (1 - shown); // onde o jogador e o oponente se encontram
		iconP1.setPosition(edge - 26, barY + BAR_H / 2 - iconP1.height / 2);
		iconP2.setPosition(edge - (iconP2.width - 26), barY + BAR_H / 2 - iconP2.height / 2);

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
