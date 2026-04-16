-- main.lua
local Tupi   = require("src.Engine.TupiEngine")
local Jogador = require("progeto.jogador")
local Menu = require("progeto.menus")

local function main()
    Tupi.janela(160, 144, "test", 5.0)
    Tupi.telaCheia_letterbox(false)
    local mapas = Tupi.carregarMapa("test")
    local MAPA_W = 24 * 8
    local MAPA_H = 24 * 8
    local player = Jogador.new(Tupi, 80, 72, "png/tileset.png", MAPA_W, MAPA_H, 160, 144)
    local menu   = Menu.new(Tupi, "png/ascii.png", "png/frame.png")
    while Tupi.rodando() do
        local dt = Tupi.dt()
        Tupi.limpar()
        if Tupi.teclaPressionou(Tupi.TECLA_ESC) then break end
        if Tupi.teclaPressionou(Tupi.TECLA_F11) then
            Tupi.telaCheia_letterbox(not Tupi.letterboxAtivo())
        end
        --menu:inicial(80, 72, 50, 20)
        player:movimentacao(dt, mapas.test)
        player:atualizarCamera(dt)
        Tupi.desenharMapa(mapas.test)
        player:desenharJogador()
        Tupi.atualizar()
    end
end
main()