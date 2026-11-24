package game;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import openfl.display.BlendMode;

private class Burst
{
	public static inline var SPARKS:Int = 10;

	public var ring:FlxSprite;
	public var sparks:Array<FlxSprite> = [];
	public var angles:Array<Float> = [];
	public var reach:Array<Float> = [];
	public var t:Float = -1; // < 0 = livre
	public var cx:Float = 0;
	public var cy:Float = 0;

	public function new(g:FlxGroup, cam:FlxCamera)
	{
		ring = new FlxSprite();
		ring.makeGraphic(128, 128, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(ring, 64, 64, 58, FlxColor.TRANSPARENT, {thickness: 8, color: FlxColor.WHITE});
		prep(ring, g, cam);
		for (_ in 0...SPARKS)
		{
			var s = new FlxSprite();
			s.makeGraphic(18, 5, FlxColor.WHITE);
			prep(s, g, cam);
			sparks.push(s);
			angles.push(0);
			reach.push(0);
		}
	}

	function prep(s:FlxSprite, g:FlxGroup, cam:FlxCamera):Void
	{
		s.scrollFactor.set();
		s.moves = false;
		s.active = false;
		s.visible = false;
		s.blend = BlendMode.ADD; // brilho somado ao fundo
		s.cameras = [cam];
		g.add(s);
	}
}

/**
 * Splashes de nota: explosão de brilho (anel + faíscas) na cor da lane quando o jogador acerta um Sick.
 * Desenhado por código, sem imagem; poucas instâncias reaproveitadas (pool), então não pesa nem gera lixo.
 */
@:keep
class NoteSplashes extends FlxGroup
{
	static inline var LIFE:Float = 0.38;
	static final POOL:Int = 10;

	var bursts:Array<Burst> = [];

	public function new(cam:FlxCamera)
	{
		super();
		for (_ in 0...POOL)
			bursts.push(new Burst(this, cam));
	}

	public function spawn(lane:Int, cx:Float, cy:Float):Void
	{
		var b:Null<Burst> = null;
		var oldest:Burst = bursts[0];
		for (x in bursts)
		{
			if (x.t < 0)
			{
				b = x;
				break;
			}
			if (x.t > oldest.t)
				oldest = x;
		}
		if (b == null)
			b = oldest; // todos em uso: reaproveita o mais antigo
		var c:FlxColor = NoteSkin.pixel ? FlxColor.WHITE : FlxColor.fromRGB(255, 255, 255);
		var tint = lane == 0 ? 0xFFC24B99 : (lane == 1 ? 0xFF00FFFF : (lane == 2 ? 0xFF12FA05 : 0xFFF9393F));
		b.t = 0;
		b.cx = cx;
		b.cy = cy;
		b.ring.color = tint;
		b.ring.visible = true;
		var base = Math.random() * Math.PI;
		for (i in 0...Burst.SPARKS)
		{
			b.angles[i] = base + i * (Math.PI * 2 / Burst.SPARKS) + (Math.random() - 0.5) * 0.35;
			b.reach[i] = 70 + Math.random() * 55;
			var s = b.sparks[i];
			s.color = i % 2 == 0 ? tint : c;
			s.angle = b.angles[i] * 180 / Math.PI;
			s.visible = true;
		}
		step(b, 0);
	}

	function step(b:Burst, t:Float):Void
	{
		var k = t / LIFE; // 0..1
		var out = 1 - (1 - k) * (1 - k); // desacelera
		var ringScale = 0.45 + out * 1.0;
		b.ring.scale.set(ringScale, ringScale);
		b.ring.setPosition(b.cx - b.ring.frameWidth / 2, b.cy - b.ring.frameHeight / 2);
		b.ring.alpha = 1 - k;
		for (i in 0...Burst.SPARKS)
		{
			var s = b.sparks[i];
			var d = 22 + out * b.reach[i];
			s.setPosition(b.cx + Math.cos(b.angles[i]) * d - s.frameWidth / 2, b.cy + Math.sin(b.angles[i]) * d - s.frameHeight / 2);
			var sc = 1 - k * 0.8;
			s.scale.set(sc, sc);
			s.alpha = 1 - k * k;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		for (b in bursts)
		{
			if (b.t < 0)
				continue;
			b.t += elapsed;
			if (b.t >= LIFE)
			{
				b.t = -1;
				b.ring.visible = false;
				for (s in b.sparks)
					s.visible = false;
			}
			else
				step(b, b.t);
		}
	}
}
