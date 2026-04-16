-- render.lua — Cor de fundo, formas 2D e batch de sprites.

local C = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- COR
-- ============================================================

function M.corFundo(r, g, b)
    C.tupi_cor_fundo(r or 0, g or 0, b or 0)
end

function M.cor(r, g, b, a)
    C.tupi_cor(r or 1, g or 1, b or 1, a or 1)
end

function M.usarCor(tabCor, a)
    C.tupi_cor(tabCor[1], tabCor[2], tabCor[3], a or tabCor[4] or 1)
end

-- Cores prontas
M.BRANCO   = {1,   1,   1,   1}
M.PRETO    = {0,   0,   0,   1}
M.VERMELHO = {1,   0,   0,   1}
M.VERDE    = {0,   1,   0,   1}
M.AZUL     = {0,   0,   1,   1}
M.AMARELO  = {1,   1,   0,   1}
M.ROXO     = {0.6, 0,   1,   1}
M.LARANJA  = {1,   0.5, 0,   1}
M.CIANO    = {0,   1,   1,   1}
M.CINZA    = {0.5, 0.5, 0.5, 1}
M.ROSA     = {1,   0.4, 0.7, 1}

-- Helper: aplica cor temporária e retorna função para restaurar
function M._aplicarCor(cor)
    if cor == nil then return function() end end
    C.tupi_cor(cor[1] or 1, cor[2] or 1, cor[3] or 1, cor[4] or 1)
    return function() C.tupi_cor(1, 1, 1, 1) end
end

-- ============================================================
-- FORMAS 2D
-- ============================================================

function M.retangulo(x, y, largura, altura, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_retangulo(x, y, largura, altura)
    restaurar()
end

function M.retanguloBorda(x, y, largura, altura, espessura, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_retangulo_borda(x, y, largura, altura, espessura or 1)
    restaurar()
end

function M.triangulo(x1, y1, x2, y2, x3, y3, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_triangulo(x1, y1, x2, y2, x3, y3)
    restaurar()
end

function M.circulo(x, y, raio, segmentos, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_circulo(x, y, raio, segmentos or 64)
    restaurar()
end

function M.circuloBorda(x, y, raio, segmentos, espessura, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_circulo_borda(x, y, raio, segmentos or 64, espessura or 1)
    restaurar()
end

function M.linha(x1, y1, x2, y2, espessura, cor)
    local restaurar = M._aplicarCor(cor)
    C.tupi_linha(x1, y1, x2, y2, espessura or 1)
    restaurar()
end

-- ============================================================
-- BATCH
-- ============================================================

--- Dispara todos os draw calls do batch manualmente (ordenados por Z).
-- Normalmente NÃO é necessário — Tupi.atualizar() já faz flush automático.
-- Use apenas se precisar forçar a ordem de renderização no meio de um frame.
function M.batchDesenhar()
    C.tupi_batch_desenhar()
end

return M
