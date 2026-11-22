package editor;

import core.Chart.EventData;
import editor.ui.EdUI.EdTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;

/**
 * Coluna de eventos ao lado da grade. Clique num espaço vazio cria o evento do tipo escolhido na aba Eventos,
 * clique num evento seleciona, arrastar move, botão direito apaga. Eventos com conflito ganham contorno vermelho.
 */
class EventLane extends FlxGroup
{
	public static inline var EX:Int = GridView.GX - GridView.CELL;
	static inline var CHIP_H:Int = 24;

	public var doc:ChartDoc;
	public var grid:GridView;
	public var sel:Null<EventData>;
	public var placeType:String = "Camera Flash";
	public var onSelect:Null<EventData->Void>;
	public var hoverName:String = "";

	var back:FlxSprite;
	var chips:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var outline:FlxSprite;
	var warn:FlxSprite;
	var used:Int = 0;
	var dragEv:Null<EventData>;
	var dragOld:Float = 0;
	var hit:Array<{ev:EventData, y:Float}> = [];

	public function new(doc:ChartDoc, grid:GridView)
	{
		super();
		this.doc = doc;
		this.grid = grid;
		back = EdTheme.rect(EX, 0, GridView.CELL, 720, 0xFFFFFFFF);
		back.alpha = 0.035;
		add(back);

		outline = new FlxSprite();
		outline.makeGraphic(GridView.CELL, CHIP_H + 4, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(outline, 1, 1, GridView.CELL - 2, CHIP_H + 2, 8, 8, FlxColor.TRANSPARENT, {thickness: 2, color: FlxColor.WHITE});
		outline.scrollFactor.set();
		outline.visible = false;
		warn = new FlxSprite();
		warn.makeGraphic(GridView.CELL, CHIP_H + 4, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(warn, 1, 1, GridView.CELL - 2, CHIP_H + 2, 8, 8, FlxColor.TRANSPARENT, {thickness: 2, color: EdTheme.BAD});
		warn.scrollFactor.set();
		warn.visible = false;
	}

	function chip(i:Int):FlxSprite
	{
		while (chips.length <= i)
		{
			var c = EdTheme.round(EX + 2, 0, GridView.CELL - 4, CHIP_H, 7);
			chips.push(c);
			add(c);
			var t = EdTheme.text(EX + 2, 0, GridView.CELL - 4, 12, "", 0xFF101010, FlxTextAlign.CENTER);
			labels.push(t);
			add(t);
		}
		return chips[i];
	}

	public function sync():Void
	{
		used = 0;
		hit = [];
		var step = grid.curStep;
		var winA = step - GridView.PLAY_Y / GridView.CELL - 1;
		var winB = step + (720 - GridView.PLAY_Y) / GridView.CELL + 1;
		var evs = doc.chart.events;
		var msA = doc.tempo.msAt(Math.max(0, winA / 4));
		var msB = doc.tempo.msAt(winB / 4);
		var stack:Map<Int, Int> = new Map();
		for (e in evs)
		{
			if (e.time < msA || e.time > msB)
				continue;
			var s = doc.eventBeat(e) * 4;
			var key = Math.round(s * 4);
			var n = stack.exists(key) ? stack.get(key) : 0;
			stack.set(key, n + 1);
			var y = grid.stepY(s) + 2 + n * 4;
			var c = chip(used);
			c.setPosition(EX + 2, y);
			c.color = EventRegistry.get(e.name).color;
			c.visible = true;
			var lb = labels[used];
			lb.text = EventRegistry.abbr(e.name);
			lb.setPosition(EX + 2, y + 5);
			lb.visible = true;
			hit.push({ev: e, y: y});
			used++;
		}
		for (k in used...chips.length)
		{
			chips[k].visible = false;
			labels[k].visible = false;
		}
		// contorno de seleção / conflito
		outline.visible = false;
		if (sel != null && doc.chart.events.indexOf(sel) >= 0)
			for (h in hit)
				if (h.ev == sel)
				{
					outline.setPosition(EX + 1, h.y - 2);
					outline.visible = true;
				}
		warn.visible = false;
	}

	override public function draw():Void
	{
		super.draw();
		for (h in hit)
			if (doc.inConflict(h.ev))
			{
				warn.setPosition(EX + 1, h.y - 2);
				warn.draw();
			}
		if (outline.visible)
			outline.draw();
	}

	function hitAt(my:Float):Null<EventData>
	{
		var i = hit.length - 1;
		while (i >= 0)
		{
			if (my >= hit[i].y - 2 && my <= hit[i].y + CHIP_H + 2)
				return hit[i].ev;
			i--;
		}
		return null;
	}

	public function mouse(allow:Bool):Void
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var over = allow && mx >= EX && mx < EX + GridView.CELL && my >= EdTheme.TOP_H && my < 720;
		var mBeat = (grid.curStep + (my - GridView.PLAY_Y) / GridView.CELL) / 4;
		var u = grid.unit();
		var snapped = Math.floor(mBeat / u + 0.000001) * u;
		var inSong = mBeat >= 0 && mBeat < doc.totalBeats();
		var under = over ? hitAt(my) : null;
		hoverName = under != null ? under.name : "";

		if (over && FlxG.mouse.justPressed)
		{
			if (under != null)
			{
				sel = under;
				dragEv = under;
				dragOld = under.time;
				if (onSelect != null)
					onSelect(under);
			}
			else if (inSong)
			{
				var d = EventRegistry.get(placeType);
				var e = doc.addEvent(snapped, placeType, d.params.length > 0 ? d.params[0].def : "", d.params.length > 1 ? d.params[1].def : "");
				sel = e;
				if (onSelect != null)
					onSelect(e);
			}
		}
		else if (over && FlxG.mouse.justPressedRight && under != null)
		{
			if (sel == under)
				sel = null;
			doc.removeEvent(under);
		}

		if (dragEv != null)
		{
			if (FlxG.mouse.pressed)
				doc.moveEventLive(dragEv, Math.floor(mBeat / u + 0.000001) * u);
			else
			{
				doc.commitEventMove(dragEv, dragOld);
				dragEv = null;
			}
		}
	}

	public function deleteSelected():Void
	{
		if (sel == null)
			return;
		doc.removeEvent(sel);
		sel = null;
		if (onSelect != null)
			onSelect(null);
	}
}
