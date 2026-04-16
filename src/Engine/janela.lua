-- janela.lua — Janela, loop principal, tempo e utilitários matemáticos.

local C = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- JANELA
-- ============================================================

--- Cria a janela.
-- @param largura   número (padrão 800)
-- @param altura    número (padrão 600)
-- @param titulo    string (padrão "TupiEngine")
-- @param escala    número — multiplicador de tamanho (padrão 1.0)
-- @param semBorda  boolean — true = sem decoração do OS (padrão false)
-- @param imagem    string — caminho para o ícone (PNG/BMP/JPG)
function M.janela(largura, altura, titulo, escala, semBorda, imagem)
    largura  = largura  or 800
    altura   = altura   or 600
    titulo   = titulo   or "TupiEngine"
    escala   = escala   or 1.0
    semBorda = semBorda and 1 or 0
    imagem   = imagem   or ""

    if C.tupi_janela_criar(largura, altura, titulo, escala, semBorda, imagem) == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end

    ---@diagnostic disable-next-line: undefined-global
    if type(tupi_c_aplicar_icone) == "function" then
        ---@diagnostic disable-next-line: undefined-global
        local icon_path = type(TUPI_ICON_PATH) == "string" and TUPI_ICON_PATH or ".engine/icon.png"
        ---@diagnostic disable-next-line: undefined-global
        tupi_c_aplicar_icone(icon_path)
    end
end

function M.rodando()   return C.tupi_janela_aberta()   == 1 end
function M.limpar()    C.tupi_janela_limpar()               end

--- Apresenta o frame na tela. Faz automaticamente:
--   • flush do batch de sprites (texturas, ordenados por Z)
--   • flush do batcher de formas 2D
--   • swap de buffers
--   • poll de eventos e atualização de input
-- NÃO é necessário chamar batchDesenhar() antes disto.
function M.atualizar() C.tupi_janela_atualizar()            end

--- Alias de M.atualizar() — mesmo comportamento, nome mais intuitivo.
M.apresentar = M.atualizar

function M.fechar()    C.tupi_janela_fechar()               end

function M.tempo()   return tonumber(C.tupi_tempo())             end
function M.dt()      return tonumber(C.tupi_delta_tempo())       end

-- Tamanho em coordenadas lógicas (use para posicionar objetos)
function M.largura() return tonumber(C.tupi_janela_largura())    end
function M.altura()  return tonumber(C.tupi_janela_altura())     end

-- Tamanho em pixels físicos
function M.larguraPx() return tonumber(C.tupi_janela_largura_px()) end
function M.alturaPx()  return tonumber(C.tupi_janela_altura_px())  end

function M.escala() return tonumber(C.tupi_janela_escala()) end

--- Muda o título da janela em runtime.
function M.setTitulo(titulo)
    C.tupi_janela_set_titulo(titulo or "")
end

--- Ativa/remove a decoração da janela em runtime.
function M.setDecoracao(ativo)
    C.tupi_janela_set_decoracao(ativo and 1 or 0)
end

--- Entra/sai do modo tela cheia (estica para a resolução do monitor).
-- Para preservar o aspect ratio, prefira M.telaCheia(ativo, true).
function M.telaCheia(ativo, letterbox)
    if letterbox then
        C.tupi_janela_tela_cheia_letterbox(ativo and 1 or 0)
    else
        C.tupi_janela_tela_cheia(ativo and 1 or 0)
    end
end

function M.telaCheia_letterbox(ativo)
    C.tupi_janela_tela_cheia_letterbox(ativo and 1 or 0)
end

--- Retorna true se o modo letterbox estiver ativo.
function M.letterboxAtivo()
    return C.tupi_janela_letterbox_ativo() == 1
end

-- ============================================================
-- UTILITÁRIOS MATEMÁTICOS
-- ============================================================

function M.lerp(a, b, t)       return a + (b - a) * t                  end
function M.aleatorio(min, max) return min + math.random() * (max - min) end
function M.rad(graus)          return graus * math.pi / 180             end
function M.graus(rad)          return rad * 180 / math.pi               end
function M.distancia(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

return M