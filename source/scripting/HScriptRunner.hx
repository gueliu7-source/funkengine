package scripting;

import hscript.Interp;
import hscript.Parser;

/** Executa um script .hx (Haxe interpretado). Funções do script viram callbacks (onCreate, onUpdate...). */
class HScriptRunner extends ScriptRunner
{
	var interp:Interp;

	public function new(manager:ScriptManager, path:String, code:String)
	{
		super(manager, path);

		var parser = new Parser();
		parser.allowJSON = true;
		parser.allowTypes = true;
		parser.allowMetadata = true;

		interp = new Interp();
		for (k in manager.api.keys())
			interp.variables.set(k, manager.api.get(k));
		for (k in manager.classes.keys())
			interp.variables.set(k, manager.classes.get(k));
		interp.variables.set("game", manager.game);

		try
		{
			var expr = parser.parseString(code, path);
			interp.execute(expr);
		}
		catch (e:Dynamic)
		{
			fail("erro ao carregar", e);
			closed = true;
		}
	}

	override public function call(fn:String, args:Array<Dynamic>):Dynamic
	{
		if (closed)
			return null;
		var f = interp.variables.get(fn);
		if (f == null || !Reflect.isFunction(f))
			return null;
		try
		{
			return Reflect.callMethod(null, f, args);
		}
		catch (e:Dynamic)
		{
			fail('erro em $fn()', e);
			return null;
		}
	}

	override public function hasFn(fn:String):Bool
		return !closed && interp != null && interp.variables.exists(fn);

	override public function set(name:String, value:Dynamic):Void
		interp.variables.set(name, value);

	override public function destroy():Void
	{
		super.destroy();
		interp = null;
	}
}
