package game;

import core.Paths;
import core.Settings;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import game.StageTimeline;
import haxe.Json;

typedef StageObject =
{
	var id:String;
	var image:String; // relativo a images/, sem extensão
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var scale:Float;
	@:optional var scroll:Array<Float>;
	@:optional var antialiasing:Bool;
	@:optional var flipX:Bool;
	@:optional var layer:String; // "back" (padrão), "gf", "dad", "front" (na frente de tudo)
	@:optional var animated:Bool; // atlas Sparrow animado
	@:optional var idle:String; // prefixo da animação em loop
	@:optional var visible:Bool;
	@:optional var alpha:Float;
	@:optional var color:String; // tint em hex "RRGGBB"
	@:optional var angle:Float;
	@:optional var locked:Bool; // só do editor
}

typedef StageDef =
{
	var name:String;
	var zoom:Float;
	var bf:Array<Float>;
	var dad:Array<Float>;
	var gf:Array<Float>;
	@:optional var objects:Array<StageObject>;
	@:optional var psych:Bool; // veio de um stage no formato do Psych (as peças são criadas por script Lua)
	@:optional var hideGf:Bool;
	@:optional var camDad:Array<Float>;
	@:optional var camGf:Array<Float>;
	@:optional var camSpeed:Float;
	@:optional var camBf:Array<Float>; // deslocamento da câmera ao focar o jogador neste cenário
	@:optional var timeline:Array<Dynamic>; // eventos que mudam o cenário durante a música (ver StageTimeline)
	@:optional var charOffsets:Dynamic; // ex.: { "spooky": [100, 300] } substitui a posição por personagem
}

@:keep
/** Cenário guiado por data/stages/<nome>.json. Efeitos especiais ficam em scripts (.hx/.lua). */
class Stage
{
	public var def:StageDef;
	public var name:String;
	public var back:FlxGroup = new FlxGroup(); // atrás de tudo
	public var gfLayer:FlxGroup = new FlxGroup(); // depois da gf
	public var dadLayer:FlxGroup = new FlxGroup(); // depois do oponente
	public var front:FlxGroup = new FlxGroup(); // na frente dos personagens
	public var objects:Map<String, FlxSprite> = new Map();
	public var timeline:StageTimeline;
	var bases:Map<String, TlBase> = new Map();

	public function new(name:String)
	{
		this.name = name;
		var text = Paths.getText('data/stages/$name.json');
		if (text == null)
		{
			trace('[Stage] $name.json não encontrado, usando "stage"');
			this.name = "stage";
			text = Paths.getText("data/stages/stage.json");
		}
		def = parseDef(text, this.name);

		if (def.objects != null)
			for (o in def.objects)
				build(o);
		timeline = new StageTimeline(StageTimeline.parse(def.timeline));
	}

	/** Aceita o JSON do FunkForge e o do Psych (defaultZoom, boyfriend, girlfriend, opponent, camera_*...). */
	static function parseDef(text:String, name:String):StageDef
	{
		var j:Dynamic = Json.parse(text);
		if (!Reflect.hasField(j, "boyfriend") && !Reflect.hasField(j, "defaultZoom"))
			return j;
		function arr(k:String, d:Array<Float>):Array<Float>
		{
			var v:Array<Float> = Reflect.field(j, k);
			return (v != null && v.length >= 2) ? [v[0], v[1]] : d;
		}
		var def:StageDef = {
			name: name,
			zoom: j.defaultZoom != null ? j.defaultZoom : 0.9,
			bf: arr("boyfriend", [770.0, 100.0]),
			dad: arr("opponent", [100.0, 100.0]),
			gf: arr("girlfriend", [400.0, 130.0]),
			psych: true,
			hideGf: j.hide_girlfriend == true,
			camBf: arr("camera_boyfriend", [0.0, 0.0]),
			camDad: arr("camera_opponent", [0.0, 0.0]),
			camGf: arr("camera_girlfriend", [0.0, 0.0]),
			camSpeed: j.camera_speed != null ? j.camera_speed : 1
		};
		return def;
	}

	/** Chamado todo frame pelo PlayState com o beat decimal da música. */
	public function updateTimeline(beat:Float):Void
	{
		if (!timeline.empty)
			timeline.apply(beat, objects, function(id) return bases.get(id));
	}

	function build(o:StageObject):Void
	{
		var s = new FlxSprite(o.x != null ? o.x : 0, o.y != null ? o.y : 0);
		if (o.animated == true)
		{
			s.frames = Paths.sparrow("images/" + o.image);
			if (o.idle != null)
			{
				s.animation.addByPrefix("idle", o.idle, 24, true);
				s.animation.play("idle");
			}
		}
		else
		{
			var g = Paths.graphic("images/" + o.image + ".png");
			if (g == null)
				return;
			s.loadGraphic(g);
			s.active = false; // imagem estática não precisa de update (a timeline mexe direto no sprite)
		}
		if (o.scale != null && o.scale != 1)
		{
			s.scale.set(o.scale, o.scale);
			s.updateHitbox();
		}
		if (o.scroll != null && o.scroll.length >= 2)
			s.scrollFactor.set(o.scroll[0], o.scroll[1]);
		s.antialiasing = (o.antialiasing != false) && Settings.d.antialiasing;
		s.flipX = (o.flipX == true);
		s.visible = (o.visible != false);
		if (o.alpha != null)
			s.alpha = o.alpha;
		if (o.angle != null)
			s.angle = o.angle;
		if (o.color != null && o.color != "")
		{
			var tc = flixel.util.FlxColor.fromString("#" + o.color.split("#").join(""));
			if (tc != null)
				s.color = tc;
		}
		objects.set(o.id, s);
		bases.set(o.id, {
			x: s.x,
			y: s.y,
			scale: o.scale != null ? o.scale : 1,
			alpha: s.alpha,
			angle: s.angle,
			color: s.color,
			image: o.image
		});

		switch (o.layer)
		{
			case "gf":
				gfLayer.add(s);
			case "dad":
				dadLayer.add(s);
			case "front":
				front.add(s);
			default:
				back.add(s);
		}
	}

	/** Posição inicial de um personagem. slot: "bf", "dad" ou "gf". */
	public function positionFor(slot:String, charId:String):Array<Float>
	{
		if (def.charOffsets != null)
		{
			var o:Array<Float> = Reflect.field(def.charOffsets, charId);
			if (o != null && o.length >= 2)
				return o;
		}
		return switch (slot)
		{
			case "bf": def.bf;
			case "gf": def.gf;
			default: def.dad;
		}
	}
}
