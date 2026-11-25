package editor.ui;

import editor.ui.EdUI.EdLock;
import editor.ui.EdUI.EdTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

typedef MenuEntry =
{
	var label:String;
	@:optional var hint:String;
	@:optional var fn:Void->Void;
	@:optional var enabled:Void->Bool;
	@:optional var sep:Bool; // linha separadora acima desta entrada
}

typedef MenuDef =
{
	var title:String;
	var entries:Array<MenuEntry>;
}

private typedef Row =
{
	var e:MenuEntry;
	var y:Float;
	var bg:FlxSprite;
	var label:FlxText;
}

/**
 * Barra de menus dos editores (ARQUIVO, EDITAR, VER, EDITORES...). Clique abre; passar o mouse troca de menu;
 * clicar fora ou ESC fecha. Enquanto aberta, bloqueia o mouse dos widgets de baixo (EdLock).
 */
class MenuBar extends FlxSpriteGroup
{
	public static var opened:Bool = false;

	static inline var ROW_H:Int = 28;
	static inline var DD_W:Int = 280;

	var defs:Array<MenuDef>;
	var x0:Float;
	var y0:Float;
	var hw:Int;
	var hh:Int;
	var heads:Array<FlxSprite> = [];
	var openIdx:Int = -1;
	var dd:FlxSpriteGroup = new FlxSpriteGroup();
	var rows:Array<Row> = [];
	var pendingUnlock:Bool = false;
	var ownsLock:Bool = false;

	public static inline function isOpen():Bool
		return opened;

	public function new(x:Float, y:Float, headW:Int, headH:Int, defs:Array<MenuDef>)
	{
		super();
		this.defs = defs;
		x0 = x;
		y0 = y;
		hw = headW;
		hh = headH;
		for (i in 0...defs.length)
		{
			var bg = EdTheme.rect(x + i * headW, y, headW - 4, headH, EdTheme.HOVER);
			bg.alpha = 0;
			bg.active = false;
			heads.push(bg);
			add(bg);
			add(EdTheme.text(x + i * headW, y + (headH - 13) / 2 - 1, headW - 4, 13, defs[i].title, EdTheme.TEXT, FlxTextAlign.CENTER));
		}
		add(dd);
	}

	function overHead(mx:Float, my:Float):Int
	{
		if (my < y0 || my > y0 + hh)
			return -1;
		var i = Math.floor((mx - x0) / hw);
		return (mx >= x0 && i >= 0 && i < defs.length) ? i : -1;
	}

	function openMenu(i:Int):Void
	{
		closeDropdown();
		openIdx = i;
		opened = true;
		ownsLock = true;
		pendingUnlock = false;
		EdLock.locked = true;
		var d = defs[i];
		var px = x0 + i * hw;
		var py = y0 + hh + 2;
		var h = d.entries.length * ROW_H + 8;
		for (e in d.entries)
			if (e.sep == true)
				h += 8;
		var frame = EdTheme.rect(px - 1, py - 1, DD_W + 2, h + 2, EdTheme.LINE);
		frame.active = false;
		dd.add(frame);
		var panel = EdTheme.rect(px, py, DD_W, h, EdTheme.SURFACE2);
		panel.active = false;
		dd.add(panel);
		var y = py + 4;
		for (e in d.entries)
		{
			if (e.sep == true)
			{
				var line = EdTheme.rect(px + 8, y + 3, DD_W - 16, 1, EdTheme.LINE);
				line.active = false;
				dd.add(line);
				y += 8;
			}
			var bg = EdTheme.rect(px + 4, y, DD_W - 8, ROW_H, EdTheme.HOVER);
			bg.alpha = 0;
			bg.active = false;
			dd.add(bg);
			var label = EdTheme.text(px + 14, y + (ROW_H - 13) / 2 - 1, DD_W - 28, 13, e.label, EdTheme.TEXT);
			dd.add(label);
			if (e.hint != null)
				dd.add(EdTheme.text(px + 14, y + (ROW_H - 12) / 2 - 1, DD_W - 28, 12, e.hint, EdTheme.DIM, FlxTextAlign.RIGHT));
			rows.push({e: e, y: y, bg: bg, label: label});
			y += ROW_H;
		}
	}

	function closeDropdown():Void
	{
		for (m in dd.members.copy())
		{
			dd.remove(m, true);
			m.destroy();
		}
		rows = [];
	}

	function closeMenu():Void
	{
		closeDropdown();
		openIdx = -1;
		pendingUnlock = true; // solta o bloqueio só no próximo quadro (o clique/ESC não vaza para a tela)
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (pendingUnlock)
		{
			pendingUnlock = false;
			opened = false;
			if (ownsLock)
				EdLock.locked = false;
			ownsLock = false;
		}
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var hi = overHead(mx, my);
		for (i in 0...heads.length)
			heads[i].alpha = (i == openIdx) ? 1 : (hi == i && (EdLock.free() || openIdx >= 0) ? 0.7 : 0);

		if (openIdx < 0)
		{
			if (hi >= 0 && FlxG.mouse.justPressed && EdLock.free())
				openMenu(hi);
			return;
		}

		var px = x0 + openIdx * hw;
		var over:Null<Row> = null;
		for (r in rows)
		{
			var enabled = r.e.enabled == null || r.e.enabled();
			var on = mx >= px + 4 && mx <= px + DD_W - 4 && my >= r.y && my < r.y + ROW_H;
			r.bg.alpha = on && enabled ? 1 : 0;
			r.label.color = enabled ? EdTheme.TEXT : EdTheme.DIM;
			if (on)
				over = r;
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			closeMenu();
			return;
		}
		if (hi >= 0 && hi != openIdx)
		{
			openMenu(hi);
			return;
		}
		if (FlxG.mouse.justPressed)
		{
			if (over != null)
			{
				var enabled = over.e.enabled == null || over.e.enabled();
				if (!enabled)
					return;
				var fn = over.e.fn;
				closeMenu();
				if (fn != null)
					fn();
			}
			else
				closeMenu();
		}
	}

	override public function destroy():Void
	{
		if (opened && ownsLock)
		{
			EdLock.locked = false;
			opened = false;
		}
		super.destroy();
	}
}
