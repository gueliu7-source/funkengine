// Tela de exemplo feita só com script: abra com go("mod:demo") (ou um item "state":"mod:demo" no mainmenu.json).
// Mostra button, list, tween, timer e saveData. ESC volta ao menu.
var titulo;
var contador;
var lista;

function onCreate() {
    add(makeSprite().makeGraphic(FlxG.width, FlxG.height, color("#202030")));
    titulo = makeText(0, 40, FlxG.width, "Tela feita por mod", 48);
    titulo.alignment = "center";
    add(titulo);
    tween(titulo, {y: 60}, 0.6, "quadOut");

    contador = loadData("cliques", 0);
    var info = makeText(0, 130, FlxG.width, "Cliques salvos: " + contador, 24);
    info.alignment = "center";
    add(info);

    button(FlxG.width / 2 - 120, 200, 240, 56, "Clique aqui", function() {
        contador++;
        saveData("cliques", contador);
        info.text = "Cliques salvos: " + contador;
        tween(titulo, {angle: 360}, 0.5, "cubeOut", function() { titulo.angle = 0; });
    });

    lista = list(FlxG.width / 2 - 120, 300, 300, ["Freeplay", "Opções", "Menu"], function(i, nome) {
        if (nome == "Freeplay") go("freeplay");
        else if (nome == "Opções") go("options");
        else go("mainmenu");
    });
}
