package editor;

import core.Paths;
import flixel.util.FlxColor;
import haxe.Json;

using StringTools;

typedef ParamDef =
{
	var label:String;
	var kind:String; // text | number | color | choice
	var def:String;
	var options:Array<String>;
}

typedef EventDef =
{
	var name:String;
	var desc:String;
	var color:FlxColor;
	var params:Array<ParamDef>; // até 2 (v1 e v2)
}

/**
 * Tipos de evento, lidos de data/events/*.json (do jogo e de cada mod). Para criar um evento novo basta
 * soltar um .json lá; o script do mod trata o nome em onEvent(nome, v1, v2).
 * {"name":"Camera Flash","description":"...","color":"#FFFFFF",
 *  "params":[{"label":"Cor","kind":"color","default":"FFFFFF"},{"label":"Duração (s)","kind":"number","default":"0.5"}]}
 */
class EventRegistry
{
	static var defs:Array<EventDef> = [];
	static var loaded:Bool = false;

	public static function reload():Void
	{
		defs = [];
		for (file in Paths.listAll("data/events"))
		{
			if (!file.endsWith(".json"))
				continue;
			try
			{
				var j:Dynamic = Json.parse(Paths.readFile(file));
				var name:String = Std.string(j.name);
				var ps:Array<ParamDef> = [];
				if (j.params != null)
					for (p in (j.params : Array<Dynamic>))
					{
						var opts:Array<String> = p.options != null ? [for (o in (p.options : Array<Dynamic>)) Std.string(o)] : [];
						ps.push({
							label: p.label != null ? Std.string(p.label) : "Valor",
							kind: p.kind != null ? Std.string(p.kind) : "text",
							def: Reflect.hasField(p, "default") ? Std.string(Reflect.field(p, "default")) : "",
							options: opts
						});
					}
				var d:EventDef = {
					name: name,
					desc: j.description != null ? Std.string(j.description) : "",
					color: parseColor(j.color != null ? Std.string(j.color) : "#AAAAAA"),
					params: ps
				};
				var replaced = false;
				for (i in 0...defs.length)
					if (defs[i].name == name)
					{
						defs[i] = d; // mod de maior prioridade vence
						replaced = true;
					}
				if (!replaced)
					defs.push(d);
			}
			catch (e:Dynamic)
				trace('[EventRegistry] $file inválido: $e');
		}
		loaded = true;
	}

	public static function all():Array<EventDef>
	{
		if (!loaded)
			reload();
		return defs;
	}

	public static function names():Array<String>
		return [for (d in all()) d.name];

	/** Definição do evento; para nomes desconhecidos (scripts próprios) devolve uma genérica. */
	public static function get(name:String):EventDef
	{
		for (d in all())
			if (d.name == name)
				return d;
		return {
			name: name,
			desc: "Evento sem definição em data/events/ (só scripts tratam).",
			color: 0xFF8A97A6,
			params: [{label: "Valor 1", kind: "text", def: "", options: []}, {label: "Valor 2", kind: "text", def: "", options: []}]
		};
	}

	public static function known(name:String):Bool
	{
		for (d in all())
			if (d.name == name)
				return true;
		return false;
	}

	public static function parseColor(s:String):FlxColor
	{
		var h = s.replace("#", "").replace("0x", "");
		var v = Std.parseInt("0xFF" + h);
		return v == null ? 0xFFAAAAAA : v;
	}

	public static function abbr(name:String):String
	{
		var out = "";
		for (w in name.split(" "))
			if (w.length > 0 && out.length < 3)
				out += w.charAt(0).toUpperCase();
		return out == "" ? "?" : out;
	}
}
