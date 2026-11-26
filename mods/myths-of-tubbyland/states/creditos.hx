// Tela de créditos do port (feita só com script de mod). ESC volta ao menu.
var lista;
var detalhe;

var textos = [
    "Nocturnal Protocol\nMúsica original de Sanco The Fox.\nMod de fãs para o Psych Engine, portado para o FunkForge.",
    "Morning Patrol\nTema da patrulha da manhã do mod Myths of Tubbyland.",
    "The Lion's Mouth\nTema do confronto com Dipsy no mod Myths of Tubbyland."
];

function onCreate() {
    var fundo = makeSprite();
    fundo.makeGraphic(FlxG.width, FlxG.height, color("#1A0F24"));
    add(fundo);

    var titulo = makeText(0, 36, FlxG.width, "Myths of Tubbyland", 52);
    titulo.alignment = "center";
    titulo.alpha = 0;
    add(titulo);
    tween(titulo, {alpha: 1, y: 52}, 0.6, "quadOut");

    detalhe = makeText(380, 220, FlxG.width - 440, textos[0], 26);
    add(detalhe);

    lista = list(60, 220, 300, ["Nocturnal Protocol", "Morning Patrol", "The Lion's Mouth"], function(i, nome) {
        go("freeplay");
    }, 30);
    lista.onChange = function(i, nome) {
        detalhe.text = textos[i];
        detalhe.alpha = 0;
        tween(detalhe, {alpha: 1}, 0.25, "quadOut");
    };

    button(60, FlxG.height - 100, 240, 52, "Voltar", function() { go("mainmenu"); });
}
