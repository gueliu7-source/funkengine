package scripting;

#if FEATURE_LUA
import llua.Convert;
import llua.Lua;
import llua.LuaL;
import llua.State;

/**
 * Executa um script .lua (LuaJIT via linc_luajit). Cada script tem o próprio estado Lua,
 * então um script com erro não derruba os outros. A API é a mesma do HScript (ScriptApi).
 */
class LuaRunner extends ScriptRunner
{
	var lua:State;

	var fnCache:Map<String, Bool> = new Map();

	public function new(manager:ScriptManager, path:String, psych:Bool = false)
	{
		super(manager, path);
		isLua = true;
		this.psych = psych;

		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		// registra a API antes de rodar o arquivo, para o código no topo do script já poder usá-la
		for (k in manager.api.keys())
			Lua_helper.add_callback(lua, k, manager.api.get(k));
		if (psych) // a API do Psych sobrescreve as funções de mesmo nome
		{
			var pa = manager.psychApi();
			for (k in pa.keys())
				Lua_helper.add_callback(lua, k, pa.get(k));
			var gl = PsychLua.globals();
			for (k in gl.keys())
			{
				Convert.toLua(lua, gl.get(k));
				Lua.setglobal(lua, k);
			}
		}

		var status:Int = LuaL.dofile(lua, path);
		if (status != 0)
		{
			fail("erro ao carregar", Lua.tostring(lua, -1));
			pop();
			closed = true;
		}
	}

	inline function pop():Void
		Lua.settop(lua, -2);

	override public function hasFn(fn:String):Bool
	{
		if (!psych)
			return true;
		var c = fnCache.get(fn);
		if (c == null)
		{
			Lua.getglobal(lua, fn);
			c = Lua.type(lua, -1) == 6; // LUA_TFUNCTION
			pop();
			fnCache.set(fn, c);
		}
		return c;
	}

	override public function call(fn:String, args:Array<Dynamic>):Dynamic
	{
		if (closed)
			return null;
		Lua.getglobal(lua, fn);
		for (a in args)
			Convert.toLua(lua, a);
		var status:Int = Lua.pcall(lua, args.length, 1, 0);
		if (status != 0)
		{
			var err:String = Lua.tostring(lua, -1);
			pop();
			// função não definida no script: normal, só ignora
			if (err != null && err.indexOf("attempt to call a nil value") >= 0)
				return null;
			fail('erro em $fn()', err);
			return null;
		}
		var ret:Dynamic = Convert.fromLua(lua, -1);
		pop();
		return ret;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (closed)
			return;
		Convert.toLua(lua, value);
		Lua.setglobal(lua, name);
	}

	override public function destroy():Void
	{
		super.destroy();
		if (lua != null)
		{
			Lua.close(lua);
			lua = null;
		}
	}
}
#end
