-- colisao.lua — Detecção de colisão AABB, círculo e ponto.

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- HELPERS INTERNOS
-- ============================================================

local function _ret(t) return ffi.new("TupiRetCol",  t.x, t.y, t.largura, t.altura) end
local function _cir(t) return ffi.new("TupiCircCol", t.x, t.y, t.raio)              end
local function _info(c)
    return { colidindo = c.colidindo == 1, dx = tonumber(c.dx), dy = tonumber(c.dy) }
end

-- ============================================================
-- COLISÕES
-- ============================================================

function M.retRet(a, b)        return C.tupi_ret_ret(_ret(a), _ret(b)) == 1             end
function M.retRetInfo(a, b)    return _info(C.tupi_ret_ret_info(_ret(a), _ret(b)))       end
function M.cirCir(a, b)        return C.tupi_cir_cir(_cir(a), _cir(b)) == 1             end
function M.cirCirInfo(a, b)    return _info(C.tupi_cir_cir_info(_cir(a), _cir(b)))       end
function M.retCir(r, c)        return C.tupi_ret_cir(_ret(r), _cir(c)) == 1             end
function M.pontoRet(px, py, r) return C.tupi_ponto_ret(px, py, _ret(r)) == 1            end
function M.pontoCir(px, py, c) return C.tupi_ponto_cir(px, py, _cir(c)) == 1            end

--- Retorna true se o mouse está dentro do retângulo r.
-- Depende de input.mouseX/Y — injetado via M._getMouse ao montar o TupiEngine.
function M.mouseNoRet(r)
    local mx, my = M._getMouse and M._getMouse() or 0, 0
    return M.pontoRet(mx, my, r)
end

function M.mouseNoCir(c)
    local mx, my = M._getMouse and M._getMouse() or 0, 0
    return M.pontoCir(mx, my, c)
end

return M
