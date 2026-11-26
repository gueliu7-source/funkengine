package scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import ui.MenuUtil;

/** Botão clicável para scripts de menu: fundo + texto, destaque ao passar o mouse, callback no clique. */
@:keep
class MenuButton
{
	public var bg:FlxSprite;
	public var label:FlxText;
	public var onClick:Void->Void;
	public var enabled:Bool = true;

	var baseColor:FlxColor;
	var hoverColor:FlxColor;
	var wasOver:Bool = false;

	public function new(x:Float, y:Float, w:Int, h:Int, text:String, onClick:Void->Void, color:FlxColor)
	{
		this.onClick = onClick;
		baseColor = color;
		hoverColor = FlxColor.interpolate(color, FlxColor.WHITE, 0.3);
		bg = new FlxSprite(x, y);
		bg.makeGraphic(w, h, FlxColor.WHITE);
		bg.color = color;
		bg.scrollFactor.set();
		var size = Std.int(Math.max(12, h * 0.5));
		label = MenuUtil.text(x, y + (h - size * 1.25) / 2, w, size, FlxTextAlign.CENTER, text);
		label.scrollFactor.set();
	}

	public function setPosition(x:Float, y:Float):Void
	{
		label.x = x;
		label.y = y + (bg.height - label.height) / 2;
		bg.setPosition(x, y);
	}

	public function setText(t:String):Void
		label.text = t;

	/** Chamado pela MenuScripts todo frame. */
	public function update():Void
	{
		if (!bg.visible || !enabled)
		{
			bg.color = FlxColor.interpolate(baseColor, FlxColor.BLACK, 0.5);
			return;
		}
		var over = FlxG.mouse.overlaps(bg);
		if (over != wasOver)
		{
			wasOver = over;
			bg.color = over ? hoverColor : baseColor;
			if (over)
				MenuUtil.sfx("scrollMenu", 0.4);
		}
		if (over && FlxG.mouse.justPressed && onClick != null)
		{
			MenuUtil.sfx("confirmMenu", 0.6);
			onClick();
		}
	}
}

/** Lista vertical selecionável (↑↓ / W S / mouse / ENTER) para scripts de menu. */
@:keep
class MenuList
{
	public var items:Array<FlxText> = [];
	public var index:Int = 0;
	public var onPick:Int->String->Void;
	public var onChange:Int->String->Void;
	public var labels:Array<String>;

	var activeColor:FlxColor = 0xFFFFE066;

	public function new(x:Float, y:Float, w:Float, labels:Array<String>, size:Int, onPick:Int->String->Void)
	{
		this.labels = labels;
		this.onPick = onPick;
		for (i in 0...labels.length)
		{
			var t = MenuUtil.text(x, y + i * (size * 1.5), w, size, FlxTextAlign.LEFT, labels[i]);
			t.scrollFactor.set();
			items.push(t);
		}
		paint();
	}

	public function selected():String
		return labels.length > 0 ? labels[index] : "";

	public function setIndex(i:Int):Void
	{
		if (labels.length == 0)
			return;
		index = (i + labels.length) % labels.length;
		paint();
		if (onChange != null)
			onChange(index, labels[index]);
	}

	function paint():Void
	{
		for (i in 0...items.length)
		{
			items[i].color = i == index ? activeColor : FlxColor.WHITE;
			items[i].alpha = i == index ? 1 : 0.6;
		}
	}

	public function update():Void
	{
		if (labels.length == 0)
			return;
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			MenuUtil.sfx("scrollMenu");
			setIndex(index - 1);
		}
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			MenuUtil.sfx("scrollMenu");
			setIndex(index + 1);
		}
		if (FlxG.mouse.visible)
		{
			for (i in 0...items.length)
				if (items[i].visible && FlxG.mouse.overlaps(items[i]))
				{
					if (FlxG.mouse.justMoved && i != index)
					{
						MenuUtil.sfx("scrollMenu");
						setIndex(i);
					}
					if (FlxG.mouse.justPressed && i == index && onPick != null)
					{
						MenuUtil.sfx("confirmMenu", 0.6);
						onPick(index, labels[index]);
					}
				}
		}
		if (FlxG.keys.justPressed.ENTER && onPick != null)
		{
			MenuUtil.sfx("confirmMenu", 0.6);
			onPick(index, labels[index]);
		}
	}
}
