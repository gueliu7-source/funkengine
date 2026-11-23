package editor.stage;

import core.ModManager;
import core.Paths;
import core.Settings;
import haxe.Json;
#if sys
import sys.io.File;
#end

using StringTools;

/** Uma peça do cenário. group: "back", "gf", "dad" ou "front" (mesmos grupos do jogo). */
typedef SObj =
{
	var id:String;
	var image:String;
	var x:Float;
	var y:Float;
	var scale:Float;
	var sx:Float; // scrollFactor
	var sy:Float;
	var flipX:Bool;
	var aa:Bool;
	var group:String;
	var animated:Bool;
	var idle:String;
	var visible:Bool;
	var alpha:Float;
	var color:String; // hex "RRGGBB" ou ""
	var angle:Float;
	var locked:Bool; // só do editor: impede selecionar no palco
}

private typedef Snap =
{
	var before:String;
	var after:String;
	var name:String;
}

/**
 * Documento do stage: dados + desfazer/refazer. Nenhuma tela mexe nos campos "do nada": use edit() (ação única)
 * ou begin()/end() (arrastar, onde muitos frames viram uma ação só). Salva sempre em mods/<mod ativo>/.
 */
class StageDoc
{
	public static final CHARS:Array<String> = ["@gf", "@dad", "@bf"];

	public var name:String;
	public var zoom:Float = 0.9;
	public var bf:Array<Float> = [770, 450];
	public var dad:Array<Float> = [100, 100];
	public var gf:Array<Float> = [400, 130];
	public var camBf:Null<Array<Float>>;
	public var charOffsets:Dynamic = {};
	public var objs:Array<SObj> = [];
	public var version:Int = 0;
	public var dirty:Bool = false;

	var raw:Dynamic = {};
	var undoS:Array<Snap> = [];
	var redoS:Array<Snap> = [];
	var pending:Null<String>;

	public var canUndo(get, never):Bool;
	public var canRedo(get, never):Bool;

	function get_canUndo():Bool
		return undoS.length > 0;

	function get_canRedo():Bool
		return redoS.length > 0;

	public function new(name:String)
	{
		this.name = name;
	}

	// ------------------------------------------------------------------ carregar / salvar

	public static function load(name:String):StageDoc
	{
		var d = new StageDoc(name);
		var text = Paths.getText('data/stages/$name.json');
		if (text == null)
		{
			d.dirty = true;
			d.objs = [];
			return d;
		}
		var j:Dynamic = Json.parse(text);
		d.raw = j;
		d.zoom = j.zoom != null ? j.zoom : 0.9;
		d.bf = arr(j.bf, [770, 450]);
		d.dad = arr(j.dad, [100, 100]);
		d.gf = arr(j.gf, [400, 130]);
		d.camBf = j.camBf != null ? arr(j.camBf, [0, 0]) : null;
		d.charOffsets = j.charOffsets != null ? j.charOffsets : {};
		var list:Array<Dynamic> = j.objects;
		if (list != null)
			for (o in list)
				d.objs.push(fromJson(o));
		return d;
	}

	static function arr(a:Dynamic, def:Array<Float>):Array<Float>
	{
		var s:Array<Dynamic> = a;
		if (s == null || s.length < 2)
			return def.copy();
		return [Std.parseFloat(Std.string(s[0])), Std.parseFloat(Std.string(s[1]))];
	}

	static function fromJson(o:Dynamic):SObj
	{
		var sc:Array<Dynamic> = o.scroll;
		return {
			id: o.id != null ? o.id : "obj",
			image: o.image != null ? o.image : "",
			x: o.x != null ? o.x : 0,
			y: o.y != null ? o.y : 0,
			scale: o.scale != null ? o.scale : 1,
			sx: sc != null && sc.length >= 2 ? sc[0] : 1,
			sy: sc != null && sc.length >= 2 ? sc[1] : 1,
			flipX: o.flipX == true,
			aa: o.antialiasing != false,
			group: o.layer != null ? o.layer : "back",
			animated: o.animated == true,
			idle: o.idle != null ? o.idle : "",
			visible: o.visible != false,
			alpha: o.alpha != null ? o.alpha : 1,
			color: o.color != null ? o.color : "",
			angle: o.angle != null ? o.angle : 0,
			locked: o.locked == true
		};
	}

	static function round(v:Float):Float
		return Math.round(v * 100) / 100;

	static function toJson(o:SObj):Dynamic
	{
		var j:Dynamic = {id: o.id, image: o.image, x: round(o.x), y: round(o.y)};
		if (o.scale != 1)
			j.scale = round(o.scale);
		if (o.sx != 1 || o.sy != 1)
			j.scroll = [round(o.sx), round(o.sy)];
		if (!o.aa)
			j.antialiasing = false;
		if (o.flipX)
			j.flipX = true;
		if (o.group != "back")
			j.layer = o.group;
		if (o.animated)
			j.animated = true;
		if (o.idle != "")
			j.idle = o.idle;
		if (!o.visible)
			j.visible = false;
		if (o.alpha != 1)
			j.alpha = round(o.alpha);
		if (o.color != "")
			j.color = o.color;
		if (o.angle != 0)
			j.angle = round(o.angle);
		if (o.locked)
			j.locked = true;
		return j;
	}

	public function savePath():String
		return ModManager.saveRoot() + '/data/stages/$name.json';

	function toJsonDoc():Dynamic
	{
		var out:Dynamic = {};
		for (f in Reflect.fields(raw)) // preserva campos que o editor não conhece (timeline, etc.)
			Reflect.setField(out, f, Reflect.field(raw, f));
		out.name = name;
		out.zoom = round(zoom);
		out.bf = [round(bf[0]), round(bf[1])];
		out.dad = [round(dad[0]), round(dad[1])];
		out.gf = [round(gf[0]), round(gf[1])];
		if (camBf != null)
			out.camBf = camBf;
		if (Reflect.fields(charOffsets).length > 0)
			out.charOffsets = charOffsets;
		else
			Reflect.deleteField(out, "charOffsets");
		// a ordem do array é a ordem de desenho dentro de cada grupo
		out.objects = [for (id in flat()) if (!id.startsWith("@")) toJson(byId(id))];
		return out;
	}

	/** Caminho salvo, ou null em erro. */
	public function save():Null<String>
	{
		#if sys
		try
		{
			var path = savePath();
			ModManager.mkdirs(path.substr(0, path.lastIndexOf("/")));
			var j = toJsonDoc();
			File.saveContent(path, Json.stringify(j, null, "  "));
			raw = j;
			Paths.rebuild(Settings.d.enabledMods);
			dirty = false;
			return path;
		}
		catch (e:Dynamic)
		{
			trace('[StageDoc] erro ao salvar: $e');
			return null;
		}
		#else
		return null;
		#end
	}

	// ------------------------------------------------------------------ desfazer

	function snapshot():String
		return Json.stringify({
			objs: objs,
			zoom: zoom,
			bf: bf,
			dad: dad,
			gf: gf,
			camBf: camBf,
			charOffsets: charOffsets
		});

	function restore(s:String):Void
	{
		var j:Dynamic = Json.parse(s);
		var list:Array<Dynamic> = j.objs;
		objs = [for (o in list) (cast o : SObj)];
		zoom = j.zoom;
		bf = arr(j.bf, bf);
		dad = arr(j.dad, dad);
		gf = arr(j.gf, gf);
		camBf = j.camBf != null ? arr(j.camBf, [0, 0]) : null;
		charOffsets = j.charOffsets != null ? j.charOffsets : {};
		version++;
		dirty = true;
	}

	public function begin():Void
	{
		if (pending == null)
			pending = snapshot();
	}

	public function end(label:String):Void
	{
		if (pending == null)
			return;
		var after = snapshot();
		if (after != pending)
		{
			undoS.push({before: pending, after: after, name: label});
			redoS = [];
			dirty = true;
			version++;
		}
		pending = null;
	}

	public var editing(get, never):Bool;

	function get_editing():Bool
		return pending != null;

	public function edit(label:String, fn:Void->Void):Void
	{
		begin();
		fn();
		end(label);
	}

	public function undo():Null<String>
	{
		if (undoS.length == 0)
			return null;
		var s = undoS.pop();
		restore(s.before);
		redoS.push(s);
		return s.name;
	}

	public function redo():Null<String>
	{
		if (redoS.length == 0)
			return null;
		var s = redoS.pop();
		restore(s.after);
		undoS.push(s);
		return s.name;
	}

	// ------------------------------------------------------------------ camadas

	public function byId(id:String):Null<SObj>
	{
		for (o in objs)
			if (o.id == id)
				return o;
		return null;
	}

	/** Ordem de desenho, do fundo para a frente, com os personagens como "@gf", "@dad", "@bf". */
	public function flat():Array<String>
	{
		var out:Array<String> = [];
		function grp(g:String):Void
		{
			for (o in objs)
				if (o.group == g || (g == "back" && o.group != "gf" && o.group != "dad" && o.group != "front"))
					out.push(o.id);
		}
		grp("back");
		out.push("@gf");
		grp("gf");
		out.push("@dad");
		grp("dad");
		out.push("@bf");
		grp("front");
		return out;
	}

	/** Reaplica grupo e ordem a partir de uma lista flat (a posição em relação aos marcadores define o grupo). */
	function applyFlat(list:Array<String>):Void
	{
		var group = "back";
		var next:Array<SObj> = [];
		for (id in list)
		{
			switch (id)
			{
				case "@gf":
					group = "gf";
				case "@dad":
					group = "dad";
				case "@bf":
					group = "front";
				default:
					var o = byId(id);
					if (o != null)
					{
						o.group = group;
						next.push(o);
					}
			}
		}
		objs = next;
	}

	/** dir = +1 traz para frente, -1 manda para trás (cruza os personagens trocando o grupo). */
	public function move(id:String, dir:Int):Bool
	{
		var f = flat();
		var i = f.indexOf(id);
		var j = i + dir;
		if (i < 0 || j < 0 || j >= f.length)
			return false;
		edit(dir > 0 ? "trazer para frente" : "mandar para trás", function() {
			f[i] = f[j];
			f[j] = id;
			applyFlat(f);
		});
		return true;
	}

	public function uniqueId(base:String):String
	{
		var b = base.replace(" ", "_");
		if (b == "" || b.startsWith("@"))
			b = "obj";
		if (byId(b) == null)
			return b;
		var n = 2;
		while (byId(b + n) != null)
			n++;
		return b + n;
	}

	public function add(image:String, animated:Bool, x:Float, y:Float, group:String = "dad"):SObj
	{
		var base = image.substr(image.lastIndexOf("/") + 1);
		var o:SObj = {
			id: uniqueId(base),
			image: image,
			x: x,
			y: y,
			scale: 1,
			sx: 1,
			sy: 1,
			flipX: false,
			aa: true,
			group: group,
			animated: animated,
			idle: "",
			visible: true,
			alpha: 1,
			color: "",
			angle: 0,
			locked: false
		};
		edit("adicionar camada", function() objs.push(o));
		return o;
	}

	public function duplicate(id:String):Null<SObj>
	{
		var o = byId(id);
		if (o == null)
			return null;
		var c:SObj = cast Json.parse(Json.stringify(o));
		c.id = uniqueId(o.id);
		c.x += 30;
		c.y += 30;
		edit("duplicar camada", function() objs.insert(objs.indexOf(o) + 1, c));
		return c;
	}

	public function remove(id:String):Void
	{
		var o = byId(id);
		if (o != null)
			edit("excluir camada", function() objs.remove(o));
	}

	// ------------------------------------------------------------------ personagens

	public function hasOverride(charId:String):Bool
		return Reflect.hasField(charOffsets, charId);

	public function positionOf(slot:String, charId:String):Array<Float>
	{
		if (hasOverride(charId))
		{
			var o:Array<Float> = Reflect.field(charOffsets, charId);
			if (o != null && o.length >= 2)
				return [o[0], o[1]];
		}
		return switch (slot)
		{
			case "bf": bf.copy();
			case "gf": gf.copy();
			default: dad.copy();
		}
	}

	/** Grava a posição na posição própria do personagem (se houver) ou no slot. Não cria entrada de desfazer sozinha. */
	public function setPosition(slot:String, charId:String, x:Float, y:Float):Void
	{
		if (hasOverride(charId))
			Reflect.setField(charOffsets, charId, [x, y]);
		else
		{
			var a = switch (slot)
			{
				case "bf": bf;
				case "gf": gf;
				default: dad;
			}
			a[0] = x;
			a[1] = y;
		}
	}

	public function setOverride(slot:String, charId:String, on:Bool):Void
	{
		edit(on ? "posição própria" : "remover posição própria", function() {
			if (on)
			{
				var p = positionOf(slot, charId);
				Reflect.setField(charOffsets, charId, p);
			}
			else
				Reflect.deleteField(charOffsets, charId);
		});
	}
}
