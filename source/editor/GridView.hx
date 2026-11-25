package editor;

import core.Chart.NoteData;
import editor.ui.EdUI.EdTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import game.NoteSkin;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

/**
 * A grade: 8 colunas (4 do oponente | 4 do jogador), 1 step por célula, tempo descendo.
 * Só desenha o que cabe na tela, com pools de sprites. A posição vertical vem do step atual (curStep),
 * então mudanças de BPM não alteram o espaçamento da grade.
 */
class GridView extends FlxGroup
{
	public static inline var CELL:Int = 44;
	public static inline var GX:Int = 472;
	public static inline var COLS:Int = 8;
	public static inline var PLAY_Y:Int = 280;
	static inline var H:Int = 720;

	public var doc:ChartDoc;
	public var quant:Int = 16; // 4, 8, 12, 16, 24, 32, 48, 64...
	public var sel:Null<NoteData>; // nota "principal" (a última clicada); os painéis usam esta
	public var sels:Array<NoteData> = []; // todas as selecionadas (SHIFT + clique / caixa)
	public var onMessage:String->Void;
	public var curStep:Float = 0;

	var tiles:Array<FlxSprite> = [];
	var dimTop:FlxSprite;
	var dimEnd:FlxSprite;
	var divider:FlxSprite;
	var lines:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var labelIds:Array<Int> = [];
	var heads:Array<Array<FlxSprite>> = [[], [], [], []];
	var tails:Array<FlxSprite> = [];
	var headsUsed:Array<Int> = [0, 0, 0, 0];
	var tailsUsed:Int = 0;
	var receptors:Array<FlxSprite> = [];
	var flash:Array<Float> = [for (i in 0...8) 0.0];
	var ghost:FlxSprite;
	var selBox:FlxSprite;
	var playhead:FlxSprite;
	var rowGlow:FlxSprite;
	var hoverBand:FlxSprite;
	var hoverLine:FlxSprite;
	var pulse:Float = 0;
	var lastBeatInt:Int = -1;
	public var playing:Bool = false;

	var dragNote:Null<NoteData>;
	var dragOld:Float = 0;

	var selBoxes:Array<FlxSprite> = [];
	var boxSpr:FlxSprite;
	var boxing:Bool = false;
	var boxC0:Float = 0;
	var boxS0:Float = 0;
	var moving:Bool = false;
	var moveC0:Int = 0;
	var moveB0:Float = 0;
	var moveDC:Int = 0;
	var moveDB:Float = 0;
	var lastVer:Int = -1;

	public function new(doc:ChartDoc)
	{
		super();
		this.doc = doc;

		var g0 = tileGraphic(0);
		var g1 = tileGraphic(1);
		for (i in 0...8)
		{
			var t = new FlxSprite(GX, 0);
			t.loadGraphic(i % 2 == 0 ? g0 : g1);
			t.moves = false;
			t.active = false;
			tiles.push(t);
			add(t);
		}

		dimTop = EdTheme.rect(GX, 0, CELL * COLS, H, 0xAA000000);
		dimEnd = EdTheme.rect(GX, 0, CELL * COLS, H, 0xAA000000);
		add(dimTop);
		add(dimEnd);

		divider = EdTheme.rect(GX + CELL * 4 - 1, 0, 2, H, EdTheme.ACCENT);
		divider.alpha = 0.55;
		add(divider);

		for (i in 0...8)
		{
			var l = EdTheme.rect(GX, 0, CELL * COLS, 2, EdTheme.ACCENT);
			l.visible = false;
			lines.push(l);
			add(l);
			var t = EdTheme.text(GX - CELL - 70, 0, 62, 14, "", EdTheme.ACCENT, FlxTextAlign.RIGHT);
			t.visible = false;
			labels.push(t);
			labelIds.push(-1);
			add(t);
		}

		for (col in 0...COLS)
		{
			var r = new FlxSprite(GX + col * CELL + 1, PLAY_Y + 1);
			NoteSkin.setupReceptor(r, col % 4);
			r.setGraphicSize(CELL - 2, CELL - 2);
			r.updateHitbox();
			r.alpha = 0.65;
			receptors.push(r);
			add(r);
		}

		ghost = EdTheme.rect(0, 0, CELL, CELL, 0xFFFFFFFF);
		ghost.alpha = 0.3;
		ghost.visible = false;
		add(ghost);

		selBox = new FlxSprite();
		selBox.makeGraphic(CELL + 2, CELL + 2, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(selBox, 1, 1, CELL, CELL, FlxColor.TRANSPARENT, {thickness: 2, color: FlxColor.WHITE});
		selBox.scrollFactor.set();
		selBox.visible = false;
		add(selBox);
		boxSpr = new FlxSprite();
		boxSpr.makeGraphic(1, 1, 0x44FFFFFF);
		boxSpr.scrollFactor.set();
		boxSpr.visible = false;
		boxSpr.origin.set(0, 0);
		add(boxSpr);

		rowGlow = EdTheme.rect(GX, PLAY_Y, CELL * COLS, CELL, EdTheme.CYAN);
		rowGlow.alpha = 0.07;
		add(rowGlow);
		hoverBand = EdTheme.rect(GX, 0, CELL, H, 0xFFFFFFFF);
		hoverBand.alpha = 0;
		add(hoverBand);
		hoverLine = EdTheme.rect(GX, 0, CELL * COLS, 1, 0xFFFFFFFF);
		hoverLine.alpha = 0;
		add(hoverLine);
		playhead = EdTheme.rect(GX - CELL - 14, PLAY_Y - 1, CELL * (COLS + 1) + 28, 2, EdTheme.CYAN);
		add(playhead);
	}

	/** Uma batida (4 steps) da grade: colunas alternadas + linhas de step. */
	static function tileGraphic(parity:Int):FlxGraphic
	{
		var bd = new BitmapData(CELL * COLS, CELL * 4, false, 0xFF10141B);
		for (c in 0...COLS)
			if (c % 2 == 1)
				bd.fillRect(new Rectangle(c * CELL, 0, CELL, CELL * 4), parity == 0 ? 0xFF131820 : 0xFF151A23);
			else if (parity == 1)
				bd.fillRect(new Rectangle(c * CELL, 0, CELL, CELL * 4), 0xFF11161D);
		for (k in 0...4)
			bd.fillRect(new Rectangle(0, k * CELL, CELL * COLS, k == 0 ? 2 : 1), k == 0 ? 0xFF2E3948 : 0xFF1A212C);
		for (c in 1...COLS)
			bd.fillRect(new Rectangle(c * CELL, 0, 1, CELL * 4), 0xFF171D27);
		var g = FlxGraphic.fromBitmapData(bd, false, "ed_tile" + parity);
		g.persist = true;
		return g;
	}

	public inline function stepY(step:Float):Float
		return PLAY_Y + (step - curStep) * CELL;

	public function flashColumn(col:Int):Void
	{
		if (col < 0 || col >= COLS)
			return;
		flash[col] = 0.12;
		receptors[col].animation.play("confirm", true);
		receptors[col].alpha = 1;
	}

	// ------------------------------------------------------------------ desenho

	public function sync(step:Float, elapsed:Float):Void
	{
		curStep = step;
		var total = doc.totalBeats();
		var bi = Math.floor(step / 4);
		if (bi != lastBeatInt)
		{
			lastBeatInt = bi;
			if (playing)
				pulse = 1;
		}
		pulse = EdTheme.lerpf(pulse, 0, elapsed, 9);
		rowGlow.alpha = 0.07 + 0.16 * pulse;

		// fundo (batidas)
		var firstBeat = Math.floor((step - PLAY_Y / CELL) / 4);
		for (t in tiles)
			t.visible = false;
		for (i in 0...6)
		{
			var b = firstBeat + i;
			var t = tiles[((b % 8) + 8) % 8];
			t.y = stepY(b * 4);
			t.visible = b >= 0 && b < total;
		}
		dimTop.y = stepY(0) - H;
		dimEnd.y = stepY(total * 4);

		// seções
		var winA = step - PLAY_Y / CELL - 1;
		var winB = step + (H - PLAY_Y) / CELL + 1;
		for (i in 0...lines.length)
		{
			lines[i].visible = false;
			labels[i].visible = false;
		}
		var si = doc.sectionIndexAtBeat(Math.max(0, winA / 4));
		var used = 0;
		while (si < doc.chart.sections.length && used < lines.length)
		{
			var s = doc.chart.sections[si];
			var st = s.startBeat * 4;
			if (st > winB)
				break;
			if (st >= winA)
			{
				var y = stepY(st);
				lines[used].y = y - 1;
				lines[used].visible = true;
				var lb = labels[used];
				if (labelIds[used] != si)
				{
					labelIds[used] = si;
					lb.text = "SEC " + si;
				}
				lb.y = y + 2;
				lb.visible = true;
				used++;
			}
			si++;
		}

		drawNotes(winA, winB);

		// receptores
		for (c in 0...COLS)
		{
			if (flash[c] > 0)
			{
				flash[c] -= elapsed;
				if (flash[c] <= 0)
				{
					receptors[c].animation.play("static", true);
					receptors[c].alpha = 0.65;
				}
			}
		}

		if (doc.version != lastVer)
		{
			lastVer = doc.version;
			var inChart = new haxe.ds.ObjectMap<NoteData, Bool>();
			for (n in doc.chart.notes)
				inChart.set(n, true);
			var alive = [for (n in sels) if (inChart.exists(n)) n];
			if (alive.length != sels.length)
			{
				sels = alive;
				if (sel != null && sels.indexOf(sel) < 0)
					sel = sels.length > 0 ? sels[sels.length - 1] : null;
			}
		}
		selBox.visible = false;
		var used = 0;
		var offS = moving ? moveDB * 4 : 0;
		var offC = moving ? moveDC : 0;
		for (n in sels)
		{
			var y = stepY(doc.beatOf(n) * 4 + offS);
			if (y > -CELL && y < H)
			{
				var bx = selBoxAt(used++);
				bx.visible = true;
				bx.setPosition(GX + (col(n) + offC) * CELL - 1, y - 1);
				bx.color = moving ? 0xFFFFE066 : 0xFFFFFFFF;
			}
		}
		for (k in used...selBoxes.length)
			selBoxes[k].visible = false;
	}

	function selBoxAt(i:Int):FlxSprite
	{
		while (selBoxes.length <= i)
		{
			var b = new FlxSprite();
			b.loadGraphicFromSprite(selBox);
			b.scrollFactor.set();
			add(b);
			selBoxes.push(b);
		}
		return selBoxes[i];
	}

	/** Troca a seleção. */
	public function setSelection(list:Array<NoteData>):Void
	{
		sels = list.copy();
		sel = sels.length > 0 ? sels[sels.length - 1] : null;
	}

	function say(s:String):Void
	{
		if (onMessage != null)
			onMessage(s);
	}

	inline function col(n:NoteData):Int
		return n.lane + (n.player ? 4 : 0);

	function head(lane:Int):FlxSprite
	{
		var pool = heads[lane];
		var idx = headsUsed[lane]++;
		if (idx >= pool.length)
		{
			var s = new FlxSprite();
			NoteSkin.setupNote(s, 0, lane);
			s.setGraphicSize(CELL - 2, CELL - 2);
			s.updateHitbox();
			s.moves = false;
			s.scrollFactor.set();
			insert(members.indexOf(ghost), s); // sempre por baixo do fantasma e da seleção
			pool.push(s);
		}
		return pool[idx];
	}

	function tail():FlxSprite
	{
		var idx = tailsUsed++;
		if (idx >= tails.length)
		{
			var s = EdTheme.rect(0, 0, 1, 1, 0xFFFFFFFF);
			s.origin.set(0, 0);
			s.alpha = 0.8;
			insert(members.indexOf(ghost), s);
			tails.push(s);
		}
		return tails[idx];
	}

	function drawNotes(winA:Float, winB:Float):Void
	{
		for (i in 0...4)
			headsUsed[i] = 0;
		tailsUsed = 0;

		var msA = doc.tempo.msAt(winA / 4);
		var msB = doc.tempo.msAt(winB / 4);
		var i = doc.lowerBound(msA - doc.maxSustainMs);
		var notes = doc.chart.notes;
		while (i < notes.length && notes[i].time <= msB)
		{
			var n = notes[i++];
			var b0 = doc.tempo.beatAt(n.time);
			var s0 = b0 * 4;
			var s1 = n.sustain > 0 ? doc.tempo.beatAt(n.time + n.sustain) * 4 : s0;
			if (s1 + 1 < winA)
				continue;
			var x = GX + col(n) * CELL;
			var passed = s0 < curStep - 0.001;
			if (n.sustain > 0)
			{
				var t = tail();
				var y0 = stepY(s0) + CELL / 2;
				var h = Math.max(1, (s1 - s0) * CELL);
				t.setPosition(x + CELL / 2 - 5, y0);
				t.scale.set(10, h);
				t.color = EdTheme.LANE[n.lane];
				t.alpha = passed ? 0.45 : 0.8;
				t.visible = true;
			}
			if (s0 >= winA && s0 <= winB)
			{
				var h = head(n.lane);
				h.setPosition(x + 1, stepY(s0) + 1);
				h.alpha = passed ? 0.5 : 1;
				h.visible = true;
			}
		}
		for (l in 0...4)
			for (k in headsUsed[l]...heads[l].length)
				heads[l][k].visible = false;
		for (k in tailsUsed...tails.length)
			tails[k].visible = false;
	}

	// ------------------------------------------------------------------ mouse

	public static function colAt(mx:Float):Int
		return Math.floor((mx - GX) / CELL);

	public inline function unit():Float
		return 4 / quant; // batidas por divisão

	/** Trata cliques na grade. Chame uma vez por frame. */
	public function mouse(allow:Bool = true):Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var c = colAt(mx);
		var over = allow && c >= 0 && c < COLS && my >= EdTheme.TOP_H && my < H;
		var mBeat = (curStep + (my - PLAY_Y) / CELL) / 4;
		var u = unit();
		var snapped = Math.floor(mBeat / u + 0.000001) * u;
		var total = doc.totalBeats();
		var inSong = mBeat >= 0 && mBeat < total;
		var shift = FlxG.keys.pressed.SHIFT;
		var ctrl = FlxG.keys.pressed.CONTROL;

		hoverBand.alpha = EdTheme.lerpf(hoverBand.alpha, over ? 0.045 : 0, FlxG.elapsed, 20);
		if (over)
			hoverBand.x = GX + c * CELL;
		hoverLine.visible = over && inSong;
		if (hoverLine.visible)
		{
			hoverLine.y = stepY(snapped * 4);
			hoverLine.alpha = 0.25;
		}
		ghost.visible = over && inSong && dragNote == null && !shift && !ctrl && !boxing && !moving;
		if (ghost.visible)
		{
			ghost.setPosition(GX + c * CELL, stepY(snapped * 4));
			ghost.scale.set(1, Math.max(4, u * 4 * CELL) / CELL);
			ghost.origin.set(0, 0);
			ghost.color = EdTheme.LANE[c % 4];
		}

		if (boxing)
		{
			updateBox(mx, my);
			return;
		}
		if (moving)
		{
			updateMove(c, snapped);
			return;
		}

		if (over && inSong)
		{
			var lane = c % 4;
			var player = c >= 4;
			if (FlxG.mouse.justPressed)
			{
				var ex = doc.noteCovering(mBeat, lane, player);
				if (shift)
				{
					if (ex != null)
						toggle(ex);
					else
					{
						boxing = true;
						boxC0 = (mx - GX) / CELL;
						boxS0 = curStep + (my - PLAY_Y) / CELL;
					}
				}
				else if (ctrl && ex != null)
				{
					if (sels.indexOf(ex) < 0)
						setSelection([ex]);
					moving = true;
					moveC0 = c;
					moveB0 = snapped;
					moveDC = 0;
					moveDB = 0;
				}
				else if (ex != null)
				{
					setSelection([ex]);
					if (mBeat < doc.beatOf(ex) + 0.25)
					{
						dragNote = ex;
						dragOld = ex.sustain;
					}
				}
				else
				{
					var n = doc.addNote(snapped, lane, player);
					setSelection([n]);
					dragNote = n;
					dragOld = 0;
				}
			}
			else if (FlxG.mouse.justPressedRight)
			{
				var ex = doc.noteCovering(mBeat, lane, player);
				if (ex != null)
				{
					if (sels.indexOf(ex) >= 0 && sels.length > 1)
						deleteSelected(); // botão direito numa nota selecionada apaga o grupo
					else
					{
						sels.remove(ex);
						if (sel == ex)
							sel = sels.length > 0 ? sels[sels.length - 1] : null;
						doc.removeNote(ex);
					}
				}
			}
		}

		if (dragNote != null)
		{
			if (FlxG.mouse.pressed)
			{
				var b0 = doc.beatOf(dragNote);
				var len = Math.floor((mBeat - b0) / u + 0.000001) * u;
				len = len < u ? 0 : len; // menos que 1 divisão = nota simples
				doc.setSustainLive(dragNote, len);
			}
			else
			{
				doc.commitSustain(dragNote, dragOld);
				dragNote = null;
			}
		}
	}

	function toggle(n:NoteData):Void
	{
		if (sels.indexOf(n) >= 0)
		{
			sels.remove(n);
			if (sel == n)
				sel = sels.length > 0 ? sels[sels.length - 1] : null;
		}
		else
		{
			sels.push(n);
			sel = n;
		}
		say(sels.length + (sels.length == 1 ? " nota selecionada" : " notas selecionadas"));
	}

	function updateBox(mx:Float, my:Float):Void
	{
		var c1 = (mx - GX) / CELL;
		var s1 = curStep + (my - PLAY_Y) / CELL;
		var minC = Math.min(boxC0, c1);
		var maxC = Math.max(boxC0, c1);
		var minS = Math.min(boxS0, s1);
		var maxS = Math.max(boxS0, s1);
		boxSpr.visible = true;
		boxSpr.setPosition(GX + minC * CELL, stepY(minS));
		boxSpr.scale.set(Math.max(1, (maxC - minC) * CELL), Math.max(1, (maxS - minS) * CELL));
		if (FlxG.mouse.pressed)
			return;
		boxing = false;
		boxSpr.visible = false;
		var hits:Array<NoteData> = [];
		var a = doc.lowerBound(doc.tempo.msAt(minS / 4) - 1);
		var notes = doc.chart.notes;
		var endMs = doc.tempo.msAt(maxS / 4);
		while (a < notes.length && notes[a].time <= endMs)
		{
			var n = notes[a++];
			var cc = col(n) + 0.5;
			var ss = doc.beatOf(n) * 4 + 0.5;
			if (cc >= minC && cc <= maxC && ss >= minS && ss <= maxS)
				hits.push(n);
		}
		if (FlxG.keys.pressed.CONTROL)
			for (n in sels)
				if (hits.indexOf(n) < 0)
					hits.push(n);
		setSelection(hits);
		say(hits.length + (hits.length == 1 ? " nota selecionada" : " notas selecionadas") + (hits.length > 0 ? " - CTRL + arrastar move, DEL apaga" : ""));
	}

	function updateMove(c:Int, snapped:Float):Void
	{
		moveDC = Std.int(Math.max(0, Math.min(COLS - 1, c))) - moveC0;
		moveDB = snapped - moveB0;
		if (FlxG.mouse.pressed)
			return;
		moving = false;
		var dc = moveDC;
		var db = moveDB;
		moveDC = 0;
		moveDB = 0;
		if (doc.moveNotes(sels, db, dc))
			say(sels.length == 1 ? "Nota movida." : sels.length + " notas movidas.");
	}

	/** Seleciona todas as notas do chart. */
	public function selectAll():Void
	{
		setSelection(doc.chart.notes.copy());
		say(sels.length + " notas selecionadas");
	}

	public function deleteSelected():Void
	{
		if (sels.length == 0 && sel != null)
			sels = [sel];
		if (sels.length == 0)
			return;
		doc.removeNotes(sels);
		sels = [];
		sel = null;
	}
}
