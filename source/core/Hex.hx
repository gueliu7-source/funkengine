package core;

/**
 * Cor a partir de texto hex ("RRGGBB", "#RRGGBB", "AARRGGBB").
 * Não usa Std.parseInt("0xFFxxxxxx"): no Windows ele satura em 0x7FFFFFFF (branco com metade da opacidade).
 */
class Hex
{
	public static function color(text:String, def:Int):Int
	{
		if (text == null)
			return def;
		var s = StringTools.trim(text);
		s = StringTools.replace(StringTools.replace(StringTools.replace(s, "#", ""), "0x", ""), "0X", "");
		if (s.length == 6)
			s = "FF" + s;
		if (s.length != 8 || !~/^[0-9a-fA-F]{8}$/.match(s))
			return def;
		var a = Std.parseInt("0x" + s.substr(0, 2));
		var r = Std.parseInt("0x" + s.substr(2, 2));
		var g = Std.parseInt("0x" + s.substr(4, 2));
		var b = Std.parseInt("0x" + s.substr(6, 2));
		return (a << 24) | (r << 16) | (g << 8) | b;
	}
}
