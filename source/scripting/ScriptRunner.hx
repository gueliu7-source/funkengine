package scripting;

/** Base comum de um script carregado (HScript ou Lua). */
class ScriptRunner
{
	public var path:String;
	public var manager:ScriptManager;
	public var closed:Bool = false;
	public var isLua:Bool = false;

	public function new(manager:ScriptManager, path:String)
	{
		this.manager = manager;
		this.path = path;
	}

	/** Chama uma função do script. Devolve o retorno, ou null se a função não existe. */
	public function call(fn:String, args:Array<Dynamic>):Dynamic
		return null;

	/** Falso se dá para saber que o script não define a função (evita alocar e chamar à toa todo frame). */
	public function hasFn(fn:String):Bool
		return true;

	public function set(name:String, value:Dynamic):Void
	{
	}

	public function destroy():Void
	{
		closed = true;
	}

	function fail(what:String, err:Dynamic):Void
	{
		var msg = '[$path] $what: ' + Std.string(err);
		trace(msg);
		manager.reportError(msg);
	}
}
