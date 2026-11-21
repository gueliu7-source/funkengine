package hud;

typedef HudStyle =
{
	var id:String;
	var name:String;
	var barW:Int; // largura do preenchimento da barra de vida
	var barH:Int;
	var barImage:Bool; // usa images/healthBar.png (601x19) como moldura
	var border:Int; // moldura plana em px quando barImage é falso (0 = sem moldura)
	var fixedColors:Bool; // true = vermelho/verde fixos (Kade); false = cor de cada personagem
	var bump:Float; // escala do pulso dos ícones na batida
	var score:String; // layout do texto: funkforge | kade | psych | codename | leather | forever
	var scoreSize:Int;
	var scoreDy:Float; // espaço entre a barra e o texto
	var time:String; // top (barra no topo) | bottom (barra embaixo) | text (só texto) | none
	var timeInside:Bool; // texto dentro da barra de tempo (Psych)
	var counters:Bool; // contador de Sick/Good/Bad/Shit/Miss à esquerda
	var info:Bool; // "Música - dificuldade" no canto inferior esquerdo
	var ratingX:Float; // posição do popup de rating (fração da tela)
	var ratingY:Float;
	var ratingScale:Float;
}

/** Os estilos de HUD, inspirados em cada engine. Escolha em Opções > Estilo do HUD. */
class HudStyles
{
	public static final ALL:Array<HudStyle> = [
		{
			id: "funkforge", name: "FunkForge", barW: 600, barH: 14, barImage: false, border: 4, fixedColors: false, bump: 1.2, score: "funkforge",
			scoreSize: 20, scoreDy: 10, time: "top", timeInside: false, counters: true, info: false, ratingX: 0.55, ratingY: 0.42, ratingScale: 0.7
		},
		{
			id: "kade", name: "Kade Engine", barW: 593, barH: 11, barImage: true, border: 0, fixedColors: true, bump: 1.2, score: "kade", scoreSize: 16,
			scoreDy: 30, time: "top", timeInside: false, counters: true, info: true, ratingX: 0.55, ratingY: 0.42, ratingScale: 0.7
		},
		{
			id: "psych", name: "Psych Engine", barW: 593, barH: 11, barImage: true, border: 0, fixedColors: false, bump: 1.2, score: "psych", scoreSize: 20,
			scoreDy: 14, time: "top", timeInside: true, counters: false, info: false, ratingX: 0.35, ratingY: 0.45, ratingScale: 0.7
		},
		{
			id: "codename", name: "Codename Engine", barW: 520, barH: 8, barImage: false, border: 0, fixedColors: false, bump: 1.15, score: "codename",
			scoreSize: 16, scoreDy: 14, time: "none", timeInside: false, counters: false, info: false, ratingX: 0.5, ratingY: 0.42, ratingScale: 0.6
		},
		{
			id: "leather", name: "Leather Engine", barW: 560, barH: 16, barImage: false, border: 3, fixedColors: false, bump: 1.3, score: "leather",
			scoreSize: 18, scoreDy: 12, time: "bottom", timeInside: false, counters: false, info: true, ratingX: 0.6, ratingY: 0.4, ratingScale: 0.75
		},
		{
			id: "forever", name: "Forever Engine", barW: 400, barH: 10, barImage: false, border: 2, fixedColors: false, bump: 1.1, score: "forever",
			scoreSize: 18, scoreDy: 14, time: "text", timeInside: false, counters: true, info: false, ratingX: 0.5, ratingY: 0.4, ratingScale: 0.8
		}
	];

	public static function get(id:String):HudStyle
	{
		for (s in ALL)
			if (s.id == id)
				return s;
		return ALL[0];
	}

	public static function next(id:String, dir:Int):String
	{
		var i = 0;
		for (k in 0...ALL.length)
			if (ALL[k].id == id)
				i = k;
		return ALL[(i + dir + ALL.length) % ALL.length].id;
	}
}
