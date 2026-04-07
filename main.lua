-- main.lua
-- TupiEngine - Demonstração do sistema de Inputs
-- Move um quadrado com WASD ou setas, clique para spawnar círculos

local Tupi = require("src.Engine.TupiEngine")

local function main()
    local largura, altura = 800, 600
    local x, y = largura/2, altura/2
    local ox, oy = 30, 50
    local velocidade = 5
    Tupi.janela(largura, altura, "TupiEngine - Inputs")
    Tupi.corFundo(0.08, 0.08, 0.12)
    while Tupi.rodando() do
        Tupi.limpar()
        Tupi.retangulo(x, y, 50, 50, {0.2, 0.8, 0, 1})
        Tupi.retanguloBorda(ox, oy, 50, 50, 3, {0.2, 0.8, 0, 1})
        if Tupi.teclaSegurando(Tupi.TECLA_W) then
            y = y - velocidade
        elseif Tupi.teclaSegurando(Tupi.TECLA_S) then
            y = y + velocidade
        elseif Tupi.teclaSegurando(Tupi.TECLA_D) then
            x = x + velocidade
        elseif Tupi.teclaSegurando(Tupi.TECLA_A) then
            x = x - velocidade
        end
        local xm, ym = Tupi.mousePos()
        Tupi.circuloBorda(xm, ym, 10, 10, 3, {1, 0, 0, 1})
        if Tupi.mouseClicou(Tupi.MOUSE_ESQ) then
            print("fff")
            Tupi.circulo(xm, ym, 10, 5, {0.2, 0.8, 0, 1})  
        end
        
        Tupi.atualizar()
    end
    Tupi.fechar()
end

main()