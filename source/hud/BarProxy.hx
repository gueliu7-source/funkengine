package hud;

import flixel.FlxSprite;

/**
 * "healthBar" para scripts Psych: x, y, width, height, angle, alpha, visible, flipX e percent.
 * Mexe em todas as peças da barra (moldura + cores) juntas.
 */
@:keep
class BarProxy
{
	var hud:Hud;
	var baseX:Float;
	var baseY:Float;
	var w:Float;
	var h:Float;
	var dx:Float = 0;
	var dy:Float = 0;
	var rel:Array<Array<Float>> = []; // centro de cada peça em relação ao centro da barra (sem giro)
	public var custom:Bool = false; // girada ou espelhada: o Hud chama layout() todo frame

	public function new(hud:Hud, x:Float, y:Float, w:Float, h:Float)
	{
		this.hud = hud;
		baseX = x;
		baseY = y;
		this.w = w;
		this.h = h;
		for (p in hud.barParts)
			rel.push([p.x + p.width / 2 - (x + w / 2), p.y + p.height / 2 - (y + h / 2)]);
	}

	function put(p:FlxSprite, relx:Float, rely:Float):Void
	{
		var rad = _ang * Math.PI / 180;
		var c = Math.cos(rad);
		var sn = Math.sin(rad);
		p.origin.set(p.frameWidth / 2, p.frameHeight / 2);
		p.x = baseX + dx + w / 2 + relx * c - rely * sn - p.frameWidth / 2;
		p.y = baseY + dy + h / 2 + relx * sn + rely * c - p.frameHeight / 2;
		p.angle = _ang;
		p.flipX = _flip;
	}

	/** Posiciona as peças girando/espelhando a barra inteira; shown = parte do jogador (0..1). */
	public function layout(shown:Float):Void
	{
		var n = hud.barParts.length;
		for (i in 0...n - 2)
			put(hud.barParts[i], rel[i][0], rel[i][1]);
		put(hud.barOpp, rel[n - 2][0], rel[n - 2][1]);
		var side = w * (1 - shown) / 2;
		put(hud.barPlr, _flip ? -side : side, rel[n - 1][1]);
	}

	function refreshCustom():Void
	{
		var was = custom;
		custom = _ang != 0 || _flip;
		if (was && !custom)
		{
			// volta ao desenho normal do Hud
			var n = hud.barParts.length;
			for (i in 0...n)
			{
				var p = hud.barParts[i];
				p.angle = 0;
				p.flipX = false;
				p.x = baseX + dx + w / 2 + rel[i][0] - p.frameWidth / 2;
				p.y = baseY + dy + h / 2 + rel[i][1] - p.frameHeight / 2;
			}
			hud.barPlr.origin.set(hud.barPlr.frameWidth, 0);
		}
	}

	function each(f:FlxSprite->Void):Void
		for (p in hud.barParts)
			f(p);

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var width(get, never):Float;
	public var height(get, never):Float;
	public var percent(get, never):Float;
	public var alpha(get, set):Float;
	public var visible(get, set):Bool;
	public var angle(get, set):Float;
	public var flipX(get, set):Bool;

	function get_x():Float
		return baseX + dx;

	function set_x(v:Float):Float
	{
		var d = v - (baseX + dx);
		dx += d;
		each(function(p) p.x += d);
		return v;
	}

	function get_y():Float
		return baseY + dy;

	function set_y(v:Float):Float
	{
		var d = v - (baseY + dy);
		dy += d;
		each(function(p) p.y += d);
		return v;
	}

	function get_width():Float
		return w;

	function get_height():Float
		return h;

	function get_percent():Float
		return hud.healthPct() * 100;

	var _a:Float = 1;
	var _v:Bool = true;
	var _ang:Float = 0;
	var _flip:Bool = false;

	function get_alpha():Float
		return _a;

	function set_alpha(v:Float):Float
	{
		_a = v;
		each(function(p) p.alpha = v);
		return v;
	}

	function get_visible():Bool
		return _v;

	function set_visible(v:Bool):Bool
	{
		_v = v;
		each(function(p) p.visible = v);
		return v;
	}

	function get_angle():Float
		return _ang;

	function set_angle(v:Float):Float
	{
		_ang = v;
		refreshCustom();
		return v;
	}

	function get_flipX():Bool
		return _flip;

	function set_flipX(v:Bool):Bool
	{
		_flip = v;
		refreshCustom();
		return v;
	}
}
