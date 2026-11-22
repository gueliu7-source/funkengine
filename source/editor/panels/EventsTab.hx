package editor.panels;

import core.Chart.EventData;
import editor.EventRegistry;
import editor.ChartEditorState;
import editor.ui.EdUI;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Um parâmetro de evento: rótulo + caixa de texto OU escolha (conforme o tipo definido em data/events). */
private class ParamSlot extends FlxSpriteGroup
{
	public var label:FlxText;
	public var input:TextInput;
	public var choice:Selector;
	public var swatch:FlxSprite;

	public function new(x:Float, y:Float, w:Int, idx:Int, ed:ChartEditorState)
	{
		super();
		label = EdTheme.text(x, y, w, 12, "", EdTheme.DIM);
		add(label);
		var get = function():String {
			var e = ed.lane.sel;
			return e == null ? "" : (idx == 0 ? e.v1 : e.v2);
		};
		var set = function(v:String) {
			var e = ed.lane.sel;
			if (e != null)
				ed.doc.setEventFields(e, e.name, idx == 0 ? v : e.v1, idx == 1 ? v : e.v2);
		};
		input = new TextInput(x, y + 18, w - 34, get, set);
		add(input);
		choice = new Selector(x, y + 18, w, "", function() {
			var e = ed.lane.sel;
			if (e == null)
				return [];
			var d = EventRegistry.get(e.name);
			return idx < d.params.length ? d.params[idx].options : [];
		}, get, set, 0);
		add(choice);
		swatch = EdTheme.circle(x + w - 24, y + 20, 22);
		add(swatch);
	}

	public function apply(e:Null<EventData>, idx:Int):Void
	{
		var d = e == null ? null : EventRegistry.get(e.name);
		var p = (d != null && idx < d.params.length) ? d.params[idx] : null;
		visible = p != null;
		active = p != null;
		if (p == null)
			return;
		label.text = p.label.toUpperCase();
		var isChoice = p.kind == "choice" && p.options.length > 0;
		choice.visible = isChoice;
		choice.active = isChoice;
		input.visible = !isChoice;
		input.active = !isChoice;
		swatch.visible = p.kind == "color";
		if (swatch.visible)
			swatch.color = EventRegistry.parseColor(idx == 0 ? e.v1 : e.v2);
	}
}

/** Aba EVENTOS: tipo a colocar, edição do evento selecionado, lista da seção e avisos de conflito. */
class EventsTab extends FlxSpriteGroup
{
	var ed:ChartEditorState;
	var descText:FlxText;
	var hint:FlxText;
	var selGroup:FlxSpriteGroup;
	var selHead:FlxText;
	var slots:Array<ParamSlot> = [];
	var rows:Array<Btn> = [];
	var rowEvents:Array<EventData> = [];
	var moreText:FlxText;
	var warnText:FlxText;
	var secHead:FlxText;
	var last:String = "";
	var lastWarn:String = "";

	public function new(ed:ChartEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;
		var half = Std.int((w - 8) / 2);

		add(EdTheme.text(x, 124, w, 12, "COLOCAR NA COLUNA DE EVENTOS", EdTheme.DIM));
		add(new Selector(x, 146, w, "Tipo", function() return EventRegistry.names(), function() return ed.lane.placeType, function(v) ed.lane.placeType = v, 50));
		descText = EdTheme.text(x, 180, w, 13, "", EdTheme.DIM);
		add(descText);

		hint = EdTheme.text(x, 248, w, 13, "Clique num evento da coluna (à esquerda da grade) para editá-lo.", EdTheme.DIM);
		add(hint);

		selGroup = new FlxSpriteGroup();
		selGroup.add(EdTheme.rect(x, 232, w, 1, EdTheme.LINE));
		selHead = EdTheme.text(x, 244, w, 12, "EVENTO SELECIONADO", EdTheme.DIM);
		selGroup.add(selHead);
		selGroup.add(new Selector(x, 266, w, "Evento", function() return EventRegistry.names(), function() {
			var e = ed.lane.sel;
			return e == null ? "" : e.name;
		}, function(v) {
			var e = ed.lane.sel;
			if (e == null)
				return;
			var d = EventRegistry.get(v);
			ed.doc.setEventFields(e, v, d.params.length > 0 ? d.params[0].def : "", d.params.length > 1 ? d.params[1].def : "");
		}, 70));
		for (i in 0...2)
		{
			var s = new ParamSlot(x, 306 + i * 56, w, i, ed);
			slots.push(s);
			selGroup.add(s);
		}
		selGroup.add(new Btn(x, 420, half, 30, "DUPLICAR", duplicate));
		selGroup.add(new Btn(x + half + 8, 420, half, 30, "APAGAR", function() ed.lane.deleteSelected()));
		add(selGroup);

		secHead = EdTheme.text(x, 470, w, 12, "", EdTheme.DIM);
		add(secHead);
		for (i in 0...4)
		{
			var idx = i;
			var b = new Btn(x, 492 + i * 30, w, 26, "", function() pick(idx), 2);
			rows.push(b);
			add(b);
		}
		moreText = EdTheme.text(x, 614, w, 12, "", EdTheme.DIM);
		add(moreText);
		warnText = EdTheme.text(x, 636, w, 13, "", EdTheme.BAD);
		add(warnText);
	}

	function duplicate():Void
	{
		var e = ed.lane.sel;
		if (e == null)
			return;
		var n = ed.doc.addEvent(ed.doc.eventBeat(e) + ed.grid.unit(), e.name, e.v1, e.v2);
		ed.lane.sel = n;
	}

	function pick(i:Int):Void
	{
		if (i >= rowEvents.length)
			return;
		ed.lane.sel = rowEvents[i];
		ed.seek(rowEvents[i].time);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var d = EventRegistry.get(ed.lane.placeType);
		if (descText.text != d.desc)
			descText.text = d.desc;

		var e = ed.lane.sel;
		if (e != null && ed.doc.chart.events.indexOf(e) < 0)
		{
			ed.lane.sel = null;
			e = null;
		}
		selGroup.visible = e != null;
		selGroup.active = e != null;
		hint.visible = e == null;
		for (i in 0...slots.length)
			slots[i].apply(e, i);
		if (e != null)
		{
			var h = "EVENTO SELECIONADO   beat " + Math.round(ed.doc.eventBeat(e) * 1000) / 1000;
			if (selHead.text != h)
				selHead.text = h;
		}

		// eventos desta seção
		var s = ed.doc.chart.sections[ed.curSection];
		rowEvents = ed.doc.eventsIn(s.startBeat, ed.doc.sectionEndBeat(ed.curSection));
		var key = ed.curSection + ":" + rowEvents.length + ":" + ed.doc.version;
		if (key != last)
		{
			last = key;
			secHead.text = "NESTA SEÇÃO (" + ed.curSection + ")   " + rowEvents.length + " evento(s)";
			for (i in 0...rows.length)
			{
				var on = i < rowEvents.length;
				rows[i].visible = on;
				rows[i].active = on;
				if (on)
					rows[i].setText(Math.round(ed.doc.eventBeat(rowEvents[i]) * 100) / 100 + "   " + rowEvents[i].name);
			}
			moreText.text = rowEvents.length > rows.length ? "+ " + (rowEvents.length - rows.length) + " na seção (use a coluna)" : "";
		}

		// conflitos
		var cs = ed.doc.conflicts();
		var w = "";
		if (cs.length > 0)
		{
			w = "ALERTA: " + cs.length + " conflito(s) - ";
			var c = cs[0];
			w += c.a.name + " em " + Math.round(ed.doc.eventBeat(c.a) * 100) / 100 + " (" + c.reason + ")";
		}
		if (w != lastWarn)
		{
			lastWarn = w;
			warnText.text = w;
		}
	}
}
