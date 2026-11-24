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

	public function new(hud:Hud, x:Float, y:Float, w:Float, h:Float)
	{
		this.hud = hud;
		baseX = x;
		baseY = y;
		this.w = w;
		this.h = h;
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
		each(function(p) p.angle = v);
		return v;
	}

	function get_flipX():Bool
		return _flip;

	function set_flipX(v:Bool):Bool
	{
		_flip = v; // a barra já é desenhada pelas cores; o lado só importa para o preenchimento (não alterado)
		return v;
	}
}
