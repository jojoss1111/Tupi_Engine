-- TupiEngine.lua
-- TupiEngine - API Principal em Lua
-- Essa é a interface que o programador usa para criar jogos

local C = require("src.Engine.engineffi")

-- ============================================================
-- MÓDULO TUPI
-- ============================================================

local Tupi = {}

-- ============================================================
-- JANELA
-- ============================================================

--- Cria e abre a janela do jogo
--- @param largura number  Largura em pixels (padrão: 800)
--- @param altura  number  Altura em pixels  (padrão: 600)
--- @param titulo  string  Título da janela  (padrão: "TupiEngine")
function Tupi.janela(largura, altura, titulo)
    largura = largura or 800
    altura  = altura  or 600
    titulo  = titulo  or "TupiEngine"
    local ok = C.tupi_janela_criar(largura, altura, titulo)
    if ok == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end
end

--- Retorna true enquanto a janela estiver aberta
function Tupi.rodando()
    return C.tupi_janela_aberta() == 1
end

--- Limpa a tela (chamar no início de cada frame)
function Tupi.limpar()
    C.tupi_janela_limpar()
end

--- Atualiza a tela e processa eventos (chamar no fim de cada frame)
function Tupi.atualizar()
    C.tupi_janela_atualizar()
end

--- Fecha a janela e encerra o engine
function Tupi.fechar()
    C.tupi_janela_fechar()
end

--- Retorna o tempo em segundos desde o início
function Tupi.tempo()
    return tonumber(C.tupi_tempo())
end

--- Retorna o delta time (tempo entre o frame anterior e o atual)
function Tupi.dt()
    return tonumber(C.tupi_delta_tempo())
end

--- Retorna a largura atual da janela
function Tupi.largura()
    return C.tupi_janela_largura()
end

--- Retorna a altura atual da janela
function Tupi.altura()
    return C.tupi_janela_altura()
end

-- ============================================================
-- COR
-- ============================================================

--- Define a cor de fundo da tela
--- Valores de 0.0 a 1.0
function Tupi.corFundo(r, g, b)
    C.tupi_cor_fundo(r or 0, g or 0, b or 0)
end

--- Define a cor atual de desenho (afeta todas as formas seguintes)
--- Valores de 0.0 a 1.0 (a = transparência, padrão 1.0)
function Tupi.cor(r, g, b, a)
    C.tupi_cor(r or 1, g or 1, b or 1, a or 1)
end

-- Cores prontas para facilitar
Tupi.BRANCO   = {1,   1,   1,   1}
Tupi.PRETO    = {0,   0,   0,   1}
Tupi.VERMELHO = {1,   0,   0,   1}
Tupi.VERDE    = {0,   1,   0,   1}
Tupi.AZUL     = {0,   0,   1,   1}
Tupi.AMARELO  = {1,   1,   0,   1}
Tupi.ROXO     = {0.6, 0,   1,   1}
Tupi.LARANJA  = {1,   0.5, 0,   1}
Tupi.CIANO    = {0,   1,   1,   1}
Tupi.CINZA    = {0.5, 0.5, 0.5, 1}
Tupi.ROSA     = {1,   0.4, 0.7, 1}

--- Atalho para usar uma tabela de cor: Tupi.usarCor(Tupi.VERMELHO)
function Tupi.usarCor(tabCor, a)
    C.tupi_cor(tabCor[1], tabCor[2], tabCor[3], a or tabCor[4] or 1)
end

-- ============================================================
-- FORMAS 2D
-- ============================================================

--- Desenha um retângulo preenchido
--- x, y = canto superior esquerdo em pixels
function Tupi.retangulo(x, y, largura, altura)
    C.tupi_retangulo(x, y, largura, altura)
end

--- Desenha apenas a borda de um retângulo
function Tupi.retanguloBorda(x, y, largura, altura, espessura)
    C.tupi_retangulo_borda(x, y, largura, altura, espessura or 1)
end

--- Desenha um triângulo preenchido com 3 vértices
function Tupi.triangulo(x1, y1, x2, y2, x3, y3)
    C.tupi_triangulo(x1, y1, x2, y2, x3, y3)
end

--- Desenha um círculo preenchido
--- x, y = centro; segmentos = suavidade (padrão 64)
function Tupi.circulo(x, y, raio, segmentos)
    C.tupi_circulo(x, y, raio, segmentos or 64)
end

--- Desenha apenas a borda de um círculo
function Tupi.circuloBorda(x, y, raio, segmentos, espessura)
    C.tupi_circulo_borda(x, y, raio, segmentos or 64, espessura or 1)
end

--- Desenha uma linha entre dois pontos
function Tupi.linha(x1, y1, x2, y2, espessura)
    C.tupi_linha(x1, y1, x2, y2, espessura or 1)
end

-- ============================================================
-- UTILITÁRIOS MATEMÁTICOS
-- ============================================================

--- Interpolação linear entre dois valores
function Tupi.lerp(a, b, t)
    return a + (b - a) * t
end

--- Retorna um número aleatório entre min e max
function Tupi.aleatorio(min, max)
    return min + math.random() * (max - min)
end

--- Converte graus para radianos
function Tupi.rad(graus)
    return graus * math.pi / 180
end

--- Converte radianos para graus
function Tupi.graus(rad)
    return rad * 180 / math.pi
end

--- Distância entre dois pontos
function Tupi.distancia(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

-- ============================================================
-- LOOP PRINCIPAL (opcional - alternativa ao loop manual)
-- ============================================================

--- Executa o loop principal do jogo automaticamente
--- @param iniciar  function  Chamada uma vez no início
--- @param atualizar function Chamada todo frame com (dt)
--- @param desenhar  function Chamada todo frame para renderizar
function Tupi.rodar(iniciar, atualizar, desenhar)
    if iniciar then iniciar() end

    while Tupi.rodando() do
        local dt = Tupi.dt()

        Tupi.limpar()

        if atualizar then atualizar(dt) end
        if desenhar  then desenhar()    end

        Tupi.atualizar()
    end

    Tupi.fechar()
end

-- ============================================================

return Tupi