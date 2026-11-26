package core;

#if sys
import sys.io.File;
#end

/**
 * Registro de depuração: tudo que dá errado em scripts/mods (erros, imagens e vídeos que faltam...) vai para
 * "funkforge-log.txt" na pasta do jogo, recomeçando a cada música. Mande esse arquivo para achar o problema.
 */
class Log
{
	public static inline var FILE:String = "funkforge-log.txt";
	static var seen:Map<String, Int> = new Map();
	static var count:Int = 0;

	public static function begin(title:String):Void
	{
		seen = new Map();
		count = 0;
		#if sys
		try
			File.saveContent(FILE, "=== " + title + " (" + Date.now().toString() + ") ===\n")
		catch (e:Dynamic) {}
		#end
	}

	/** Uma linha no log. Mensagens repetidas só aparecem na primeira vez. */
	public static function add(msg:String):Void
	{
		trace(msg);
		var n = seen.get(msg);
		if (n != null)
		{
			seen.set(msg, n + 1);
			return;
		}
		seen.set(msg, 1);
		if (++count > 1500)
			return;
		#if sys
		try
		{
			var o = File.append(FILE, false);
			o.writeString(msg + "\n");
			o.close();
		}
		catch (e:Dynamic) {}
		#end
	}
}
