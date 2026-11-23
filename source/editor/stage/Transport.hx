package editor.stage;

import editor.StageEditorState;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Barra de transporte do Stage Editor: play/pause, seção/beat, loop de trecho e barra de progresso clicável. */
class Transport extends FlxSpriteGroup
{
	static inline var MAX_TICKS:Int = 160;

	var ed:StageEditorState;
	var song:StageSong;
	var x0:Float;
	var by:Float; // y da barra de progresso
	var playBtn:Btn;
	var timeText:FlxText;
	var shownTime:String = "";
	var track:FlxSprite;
	var fill:FlxSprite;
	var loopRange:FlxSprite;
	var head:FlxSprite;
	var ticks:Array<FlxSprite> = [];
	var dragging:Bool = false;
	var hot:Float = 0;
	var tickFor:Int = -1;

	public function new(ed:StageEditorState, x:Float, y:Float)
	{
		super();
		this.ed = ed;
		this.song = ed.song;
		x0 = x;
		by = y + 40;

		var bx = x;
		add(new Btn(bx, y, 74, 30, "< SEÇÃO", function() song.gotoSection(song.sectionIndex() - 1), 2, ready, 12));
		add(new Btn(bx + 80, y, 58, 30, "< BEAT", function() song.stepBeats(-1), 2, ready, 12));
		playBtn = new Btn(bx + 144, y, 96, 30, "PLAY", function() song.toggle(), 1, ready);
		add(playBtn);
		add(new Btn(bx + 246, y, 58, 30, "BEAT >", function() song.stepBeats(1), 2, ready, 12));
		add(new Btn(bx + 310, y, 74, 30, "SEÇÃO >", function() song.gotoSection(song.sectionIndex() + 1), 2, ready, 12));
		timeText = EdTheme.text(bx + 398, y + 8, 220, 13, "", EdTheme.CYAN);
		add(timeText);

		var lx = bx + 560;
		add(new Toggle(lx, y + 4, 72, "Loop", function() return song.loopOn, function(v) song.setLoop(v)));
		add(new Btn(lx + 96, y, 34, 30, "A", function() {
			song.loopA = song.ms;
			if (song.loopB <= song.loopA)
				song.loopB = Math.min(song.lengthMs, song.loopA + 8000);
		}, 2, ready));
		add(new Btn(lx + 134, y, 34, 30, "B", function() {
			song.loopB = Math.max(song.ms, song.loopA + 100);
		}, 2, ready));
		add(new Btn(lx + 172, y, 62, 30, "SEÇÃO", function() song.loopSection(), 2, ready, 12));

		track = bar(EdTheme.SURFACE2, 1);
		loopRange = bar(EdTheme.CYAN, 0.35);
		fill = bar(EdTheme.ACCENT, 0.9);
		for (_ in 0...MAX_TICKS)
		{
			var t = bar(0xFFFFFFFF, 0.22);
			t.visible = false;
			ticks.push(t);
		}
		head = bar(0xFFFFFFFF, 1);
	}

	function ready():Bool
		return song.loaded;

	function bar(color:Int, alpha:Float):FlxSprite
	{
		var s = new FlxSprite(x0, by);
		s.makeGraphic(1, 1, 0xFFFFFFFF);
		s.origin.set(0, 0);
		s.color = color;
		s.alpha = alpha;
		add(s);
		return s;
	}

	static function clock(ms:Float):String
	{
		var t = Math.max(0, ms);
		var m = Std.int(t / 60000);
		var s = Std.int(t / 1000) % 60;
		var c = Std.int(t) % 1000;
		return m + ":" + (s < 10 ? "0" : "") + s + "." + (c < 100 ? (c < 10 ? "00" : "0") : "") + c;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var w = ed.viewWidth();
		var h = 10.0;
		var len = Math.max(1, song.lengthMs);

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var over = song.loaded && mx >= x0 && mx <= x0 + w && my >= by - 6 && my <= by + h + 6;
		hot = EdTheme.lerpf(hot, (over || dragging) ? 1 : 0, elapsed, 16);
		h = 8 + 4 * hot;

		if (!EdLock.locked && !TextInput.typing())
		{
			if (over && FlxG.mouse.justPressed)
				dragging = true;
			if (dragging)
			{
				if (FlxG.mouse.pressed)
					song.seek((mx - x0) / w * len);
				else
					dragging = false;
			}
		}
		else
			dragging = false;

		track.y = by;
		track.scale.set(w, h);
		fill.y = by;
		fill.scale.set(w * song.ms / len, h);
		var showLoop = song.loaded && song.loopOn && song.loopB > song.loopA;
		loopRange.visible = showLoop;
		if (showLoop)
		{
			loopRange.x = x0 + w * song.loopA / len;
			loopRange.y = by - 3;
			loopRange.scale.set(w * (song.loopB - song.loopA) / len, h + 6);
		}
		// marcas de seção (recriadas só quando a quantidade muda)
		var n = song.loaded ? Std.int(Math.min(MAX_TICKS, song.doc.chart.sections.length)) : 0;
		for (i in 0...MAX_TICKS)
		{
			var t = ticks[i];
			t.visible = i < n && i > 0;
			if (t.visible)
			{
				t.x = x0 + w * song.doc.chart.sections[i].startMs / len;
				t.y = by;
				t.scale.set(1, h);
			}
		}
		head.visible = song.loaded;
		head.x = x0 + w * song.ms / len - 1;
		head.y = by - 2;
		head.scale.set(3, h + 4);

		playBtn.setText(song.playing ? "PAUSAR" : "PLAY");
		var t = song.loaded ? clock(song.ms) + " / " + clock(song.lengthMs) + "   seção " + song.sectionIndex() : "nenhuma música (aba MÚSICA)";
		if (t != shownTime)
		{
			shownTime = t;
			timeText.text = t;
		}
	}
}
