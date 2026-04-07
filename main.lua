-- main.lua
-- TupiEngine - Exemplo de uso
-- Demonstra: janela, fundo, formas geométricas animadas

local Tupi = require("src.Engine.TupiEngine")

-- ============================================================
-- CONFIGURAÇÃO INICIAL
-- ============================================================

Tupi.janela(800, 600, "TupiEngine - Formas Geometricas")
Tupi.corFundo(0.08, 0.08, 0.12) -- fundo quase preto

-- Estado do jogo
local tempo = 0

-- ============================================================
-- LOOP PRINCIPAL
-- ============================================================

Tupi.rodar(

    -- INICIAR: roda uma vez
    function()
        print("Jogo iniciado!")
        math.randomseed(os.time())
    end,

    -- ATUALIZAR: lógica do jogo (recebe dt = delta time)
    function(dt)
        tempo = tempo + dt
    end,

    -- DESENHAR: renderização do frame
    function()
        local L = Tupi.largura()
        local A = Tupi.altura()

        -- ----------------------------------------
        -- Retângulo central pulsando
        -- ----------------------------------------
        local pulso = math.sin(tempo * 2) * 20
        Tupi.usarCor(Tupi.AZUL)
        Tupi.retangulo(
            L/2 - 100 - pulso/2,
            A/2 - 60  - pulso/2,
            200 + pulso,
            120 + pulso
        )

        -- ----------------------------------------
        -- Borda do retângulo em branco
        -- ----------------------------------------
        Tupi.usarCor(Tupi.BRANCO, 0.5)
        Tupi.retanguloBorda(
            L/2 - 100 - pulso/2,
            A/2 - 60  - pulso/2,
            200 + pulso,
            120 + pulso,
            2
        )

        -- ----------------------------------------
        -- Círculo girando ao redor do centro
        -- ----------------------------------------
        local angulo = tempo * 1.5
        local ox = math.cos(angulo) * 180
        local oy = math.sin(angulo) * 100

        Tupi.usarCor(Tupi.VERMELHO)
        Tupi.circulo(L/2 + ox, A/2 + oy, 30)

        -- Círculo menor na direção oposta
        Tupi.usarCor(Tupi.AMARELO)
        Tupi.circulo(L/2 - ox, A/2 - oy, 18)

        -- ----------------------------------------
        -- Triângulo no canto superior esquerdo
        -- ----------------------------------------
        local ty = math.sin(tempo * 3) * 15
        Tupi.usarCor(Tupi.VERDE)
        Tupi.triangulo(
            80,       50 + ty,   -- topo
            30,       130 + ty,  -- esquerda baixo
            130,      130 + ty   -- direita baixo
        )

        -- ----------------------------------------
        -- Círculo com borda no canto superior direito
        -- ----------------------------------------
        Tupi.usarCor(Tupi.ROXO)
        Tupi.circulo(L - 90, 90, 50)
        Tupi.usarCor(Tupi.ROSA)
        Tupi.circuloBorda(L - 90, 90, 55, 64, 2)

        -- ----------------------------------------
        -- Linhas cruzadas no canto inferior direito
        -- ----------------------------------------
        local lx = L - 120
        local ly = A - 100
        for i = 0, 4 do
            local c = i / 4
            Tupi.cor(c, 1 - c, 0.5, 0.9)
            Tupi.linha(lx, ly - 50 + i*20, lx + 80, ly - 50 + i*20, 2)
        end

        -- ----------------------------------------
        -- Triângulo laranja girando no canto inferior esquerdo
        -- ----------------------------------------
        local ga = tempo * 2
        local gr = 55
        Tupi.usarCor(Tupi.LARANJA)
        Tupi.triangulo(
            80 + math.cos(ga)          * gr,  A - 80 + math.sin(ga)          * gr,
            80 + math.cos(ga + 2.094)  * gr,  A - 80 + math.sin(ga + 2.094)  * gr,
            80 + math.cos(ga + 4.189)  * gr,  A - 80 + math.sin(ga + 4.189)  * gr
        )
    end
)