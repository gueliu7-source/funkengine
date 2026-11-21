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
	public static inline var CELL:Int = 40;
	public static inline var GX:Int = 370;
	public static inline var COLS:Int = 8;
	public static inline var PLAY_Y:Int = 240;
	static inline var H:Int = 720;

	public var doc:ChartDoc;
	public var quant:Int = 16; // 4, 8, 12, 16, 24, 32, 48, 64...
	public var sel:Null<NoteData>;
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

	var dragNote:Null<NoteData>;
	var dragOld:Float = 0;

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
			var t = EdTheme.text(GX - 74, 0, 68, 14, "", EdTheme.ACCENT, FlxTextAlign.RIGHT);
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

		playhead = EdTheme.rect(GX - 12, PLAY_Y - 1, CELL * COLS + 24, 2, EdTheme.CYAN);
		add(playhead);
	}

	/** Uma batida (4 steps) da grade: colunas alternadas + linhas de step. */
	static function tileGraphic(parity:Int):FlxGraphic
	{
		var bd = new BitmapData(CELL * COLS, CELL * 4, false, 0xFF161B23);
		for (c in 0...COLS)
			if (c % 2 == 1)
				bd.fillRect(new Rectangle(c * CELL, 0, CELL, CELL * 4), parity == 0 ? 0xFF1A202A : 0xFF1D2430);
			else if (parity == 1)
				bd.fillRect(new Rectangle(c * CELL, 0, CELL, CELL * 4), 0xFF181E27);
		for (k in 0...4)
			bd.fillRect(new Rectangle(0, k * CELL, CELL * COLS, k == 0 ? 2 : 1), k == 0 ? 0xFF3A465A : 0xFF232C3A);
		for (c in 1...COLS)
			bd.fillRect(new Rectangle(c * CELL, 0, 1, CELL * 4), 0xFF1E2632);
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

		if (sel != null)
		{
			var y = stepY(doc.beatOf(sel) * 4);
			selBox.visible = doc.chart.notes.indexOf(sel) >= 0 && y > -CELL && y < H;
			selBox.setPosition(GX + col(sel) * CELL - 1, y - 1);
		}
		else
			selBox.visible = false;
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
	public function mouse():Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var c = colAt(mx);
		var over = c >= 0 && c < COLS && my >= 0 && my < H;
		var mBeat = (curStep + (my - PLAY_Y) / CELL) / 4;
		var u = unit();
		var snapped = Math.floor(mBeat / u + 0.000001) * u;
		var total = doc.totalBeats();
		var inSong = mBeat >= 0 && mBeat < total;

		ghost.visible = over && inSong && dragNote == null;
		if (ghost.visible)
		{
			ghost.setPosition(GX + c * CELL, stepY(snapped * 4));
			ghost.scale.set(1, Math.max(4, u * 4 * CELL) / CELL);
			ghost.origin.set(0, 0);
			ghost.color = EdTheme.LANE[c % 4];
		}

		if (over && inSong)
		{
			var lane = c % 4;
			var player = c >= 4;
			if (FlxG.mouse.justPressed)
			{
				var ex = doc.noteCovering(mBeat, lane, player);
				if (ex != null)
				{
					sel = ex;
					if (mBeat < doc.beatOf(ex) + 0.25)
					{
						dragNote = ex;
						dragOld = ex.sustain;
					}
				}
				else
				{
					var n = doc.addNote(snapped, lane, player);
					sel = n;
					dragNote = n;
					dragOld = 0;
				}
			}
			else if (FlxG.mouse.justPressedRight)
			{
				var ex = doc.noteCovering(mBeat, lane, player);
				if (ex != null)
				{
					if (sel == ex)
						sel = null;
					doc.removeNote(ex);
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

	public function deleteSelected():Void
	{
		if (sel == null)
			return;
		doc.removeNote(sel);
		sel = null;
	}
}
