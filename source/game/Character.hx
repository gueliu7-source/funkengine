package game;

import core.Conductor;
import core.Paths;
import core.Settings;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import haxe.Json;

using StringTools;

typedef AnimDef =
{
	var name:String;
	var prefix:String;
	@:optional var fps:Int;
	@:optional var loop:Bool;
	@:optional var indices:Array<Int>;
	@:optional var offsets:Array<Float>;
}

typedef CharDef =
{
	var name:String;
	var asset:String; // sem extensão, relativo a images/, ex.: "characters/BOYFRIEND"
	var animations:Array<AnimDef>;
	@:optional var packer:Bool; // atlas .txt em vez de .xml
	@:optional var barColor:String;
	@:optional var icon:String;
	@:optional var flipX:Bool;
	@:optional var swapSides:Bool; // inverte esquerda/direita quando é o jogador
	@:optional var scale:Float;
	@:optional var antialiasing:Bool;
	@:optional var singDuration:Float; // em steps
	@:optional var danceEvery:Int; // em beats
	@:optional var danceLR:Bool; // alterna danceLeft/danceRight em vez de idle
	@:optional var camOffset:Array<Float>;
	@:optional var psych:Bool; // veio de um personagem no formato do Psych Engine (flip e câmera funcionam como lá)
	@:optional var posOffset:Array<Float>; // Psych: "position", somado à posição do cenário
}

/** Personagem 100% guiado por data/characters/<id>.json (nada de personagem fixo no código). */
@:keep
class Character extends FlxSprite
{
	public static final DIRS:Array<String> = ["LEFT", "DOWN", "UP", "RIGHT"];

	public var id:String;
	public var def:CharDef;
	public var isPlayer:Bool;
	public var holdTimer:Float = 0;
	public var singDuration:Float = 4;
	public var danceEvery:Int = 2;
	public var danced:Bool = false;
	public var specialAnim:Bool = false;
	public var holdingKeys:Bool = false; // o PlayState marca isso para o jogador
	public var barColor:FlxColor = 0xFFA5004D;
	public var iconName:String = "face";
	public var camOffset:Array<Float>;

	public var offsets:Map<String, Array<Float>> = new Map(); // público: o Character Editor ajusta ao vivo

	/** fromDef: usa esta definição em vez de ler o arquivo (o Character Editor mostra o que ainda não foi salvo). */
	public function new(x:Float, y:Float, id:String, isPlayer:Bool = false, ?fromDef:CharDef)
	{
		super(x, y);
		this.id = id;
		this.isPlayer = isPlayer;
		moves = false;
		load(fromDef);
		dance();
	}

	/**
	 * Lê o JSON de um personagem. Aceita o formato do FunkForge e o do Psych Engine
	 * (image, animations[{anim, name, ...}], healthicon, position, camera_position...).
	 */
	public static function parseDef(text:String, id:String):CharDef
	{
		var j:Dynamic = Json.parse(text);
		if (Reflect.hasField(j, "image") && !Reflect.hasField(j, "asset"))
			return fromPsych(j, id);
		return j;
	}

	static function fromPsych(j:Dynamic, id:String):CharDef
	{
		var anims:Array<AnimDef> = [];
		var hasL = false;
		var hasR = false;
		var list:Array<Dynamic> = j.animations;
		if (list != null)
			for (a in list)
			{
				var d:AnimDef = {
					name: a.anim,
					prefix: a.name,
					fps: a.fps != null ? Std.int(a.fps) : 24,
					loop: a.loop == true
				};
				var ix:Array<Int> = a.indices;
				if (ix != null && ix.length > 0)
					d.indices = ix;
				var of:Array<Float> = a.offsets;
				d.offsets = (of != null && of.length >= 2) ? [of[0], of[1]] : [0.0, 0.0];
				anims.push(d);
				if (d.name == "danceLeft")
					hasL = true;
				if (d.name == "danceRight")
					hasR = true;
			}
		var bc:Array<Dynamic> = j.healthbar_colors;
		var def:CharDef = {
			name: id,
			asset: Std.string(j.image),
			animations: anims,
			psych: true,
			danceLR: hasL && hasR,
			scale: j.scale != null ? j.scale : 1,
			flipX: j.flip_x == true,
			antialiasing: j.no_antialiasing != true,
			singDuration: j.sing_duration != null ? j.sing_duration : 4,
			icon: j.healthicon != null ? Std.string(j.healthicon) : "face"
		};
		if (bc != null && bc.length >= 3)
			def.barColor = "#" + StringTools.hex(Std.int(bc[0]), 2) + StringTools.hex(Std.int(bc[1]), 2) + StringTools.hex(Std.int(bc[2]), 2);
		var p:Array<Float> = j.position;
		if (p != null && p.length >= 2)
			def.posOffset = [p[0], p[1]];
		var c:Array<Float> = j.camera_position;
		if (c != null && c.length >= 2)
			def.camOffset = [c[0], c[1]]; // por enquanto só o deslocamento do personagem; a base (150/-100) entra no load()
		return def;
	}

	function load(fromDef:Null<CharDef>):Void
	{
		if (fromDef != null)
			def = fromDef;
		else
		{
			var text = Paths.getText('data/characters/$id.json');
			if (text == null)
			{
				trace('[Character] $id.json não encontrado, usando bf');
				text = Paths.getText("data/characters/bf.json");
			}
			def = parseDef(text, id);
		}

		frames = (def.packer == true) ? Paths.packer("images/" + def.asset) : Paths.sparrow("images/" + def.asset);

		for (a in def.animations)
		{
			var fps = (a.fps != null) ? a.fps : 24;
			var loop = (a.loop == true);
			if (a.indices != null && a.indices.length > 0)
				animation.addByIndices(a.name, a.prefix, a.indices, "", fps, loop);
			else
				animation.addByPrefix(a.name, a.prefix, fps, loop);
			offsets.set(a.name, (a.offsets != null && a.offsets.length >= 2) ? a.offsets : [0.0, 0.0]);
		}

		if (def.singDuration != null)
			singDuration = def.singDuration;
		if (def.danceEvery != null)
			danceEvery = def.danceEvery;
		if (def.barColor != null)
		{
			var c = FlxColor.fromString(def.barColor);
			if (c != null)
				barColor = c;
		}
		if (def.icon != null)
			iconName = def.icon;
		var baseCam = isPlayer ? [-100.0, -100.0] : [150.0, -100.0];
		if (def.psych == true) // Psych: câmera = meio do personagem + (150,-100) ou (-100,-100) + camera_position
			camOffset = def.camOffset != null ? [baseCam[0] + def.camOffset[0], baseCam[1] + def.camOffset[1]] : baseCam;
		else
			camOffset = def.camOffset != null ? def.camOffset : baseCam;

		antialiasing = (def.antialiasing != false) && Settings.d.antialiasing;
		flipX = (def.flipX == true);
		if (def.scale != null && def.scale != 1)
		{
			scale.set(def.scale, def.scale);
			updateHitbox();
		}

		if (def.psych == true)
		{
			// regra do Psych: espelha quando é o jogador; troca esquerda/direita quando o espelhamento difere do desenho original
			var orig = (def.flipX == true);
			flipX = isPlayer ? !orig : orig;
			if (isPlayer != orig)
			{
				swapAnims("singLEFT", "singRIGHT");
				swapAnims("singLEFTmiss", "singRIGHTmiss");
			}
		}
		else if (isPlayer)
		{
			flipX = !flipX;
			if (def.swapSides != false)
			{
				swapAnims("singLEFT", "singRIGHT");
				swapAnims("singLEFTmiss", "singRIGHTmiss");
			}
		}
		if (def.posOffset != null)
		{
			x += def.posOffset[0];
			y += def.posOffset[1];
		}
	}

	function swapAnims(a:String, b:String):Void
	{
		var x = animation.getByName(a);
		var y = animation.getByName(b);
		if (x == null || y == null)
			return;
		var tmp = x.frames;
		x.frames = y.frames;
		y.frames = tmp;
	}

	public function hasAnim(name:String):Bool
		return animation.getByName(name) != null;

	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if (!hasAnim(name))
		{
			// "singUP-alt" sem alt cai para "singUP"
			var dash = name.indexOf("-alt");
			if (dash > 0 && hasAnim(name.substr(0, dash)))
				name = name.substr(0, dash);
			else
				return;
		}
		animation.play(name, force, reversed, frame);
		var o = offsets.get(name);
		if (o != null)
			offset.set(o[0], o[1]);
		else
			offset.set(0, 0);

		if (name.startsWith("sing"))
			holdTimer = 0;

		if (def.danceLR == true)
		{
			if (name == "singLEFT")
				danced = true;
			else if (name == "singRIGHT")
				danced = false;
			else if (name == "singUP" || name == "singDOWN")
				danced = !danced;
		}
	}

	public function sing(lane:Int, alt:Bool = false, miss:Bool = false):Void
	{
		var n = "sing" + DIRS[lane] + (miss ? "miss" : "") + (alt ? "-alt" : "");
		playAnim(n, true);
	}

	public inline function isSinging():Bool
		return animation.curAnim != null && animation.curAnim.name.startsWith("sing");

	public function dance():Void
	{
		if (specialAnim)
			return;
		if (def.danceLR == true)
		{
			danced = !danced;
			playAnim(danced ? "danceRight" : "danceLeft");
		}
		else
			playAnim("idle");
	}

	override function update(elapsed:Float):Void
	{
		if (animation.curAnim != null)
		{
			if (specialAnim && animation.curAnim.finished)
			{
				specialAnim = false;
				dance();
			}
			if (isSinging())
			{
				holdTimer += elapsed;
				if (holdTimer >= Conductor.stepCrochet * singDuration * 0.001 && !holdingKeys)
				{
					dance();
					holdTimer = 0;
				}
			}
			else if (animation.curAnim.name == "idle" && animation.curAnim.finished && hasAnim("idleLoop"))
				playAnim("idleLoop");
		}
		super.update(elapsed);
	}
}
