-- input.lua — Teclado, mouse, scroll e constantes de teclas.

local C = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- CONSTANTES DE TECLAS
-- ============================================================

M.TECLA_ESPACO    = 32;  M.TECLA_ENTER     = 257; M.TECLA_TAB       = 258
M.TECLA_BACKSPACE = 259; M.TECLA_ESC        = 256
M.TECLA_SHIFT_ESQ = 340; M.TECLA_SHIFT_DIR  = 344
M.TECLA_CTRL_ESQ  = 341; M.TECLA_CTRL_DIR   = 345
M.TECLA_ALT_ESQ   = 342; M.TECLA_ALT_DIR    = 346

M.TECLA_CIMA     = 265;  M.TECLA_BAIXO    = 264
M.TECLA_ESQUERDA = 263;  M.TECLA_DIREITA  = 262

M.TECLA_A=65;  M.TECLA_B=66;  M.TECLA_C=67;  M.TECLA_D=68
M.TECLA_E=69;  M.TECLA_F=70;  M.TECLA_G=71;  M.TECLA_H=72
M.TECLA_I=73;  M.TECLA_J=74;  M.TECLA_K=75;  M.TECLA_L=76
M.TECLA_M=77;  M.TECLA_N=78;  M.TECLA_O=79;  M.TECLA_P=80
M.TECLA_Q=81;  M.TECLA_R=82;  M.TECLA_S=83;  M.TECLA_T=84
M.TECLA_U=85;  M.TECLA_V=86;  M.TECLA_W=87;  M.TECLA_X=88
M.TECLA_Y=89;  M.TECLA_Z=90

M.TECLA_0=48; M.TECLA_1=49; M.TECLA_2=50; M.TECLA_3=51
M.TECLA_4=52; M.TECLA_5=53; M.TECLA_6=54; M.TECLA_7=55
M.TECLA_8=56; M.TECLA_9=57

M.TECLA_NUM0=320; M.TECLA_NUM1=321; M.TECLA_NUM2=322
M.TECLA_NUM3=323; M.TECLA_NUM4=324; M.TECLA_NUM5=325
M.TECLA_NUM6=326; M.TECLA_NUM7=327; M.TECLA_NUM8=328
M.TECLA_NUM9=329

M.TECLA_F1=290;  M.TECLA_F2=291;  M.TECLA_F3=292
M.TECLA_F4=293;  M.TECLA_F5=294;  M.TECLA_F6=295
M.TECLA_F7=296;  M.TECLA_F8=297;  M.TECLA_F9=298
M.TECLA_F10=299; M.TECLA_F11=300; M.TECLA_F12=301

M.MOUSE_ESQ=0; M.MOUSE_DIR=1; M.MOUSE_MEIO=2

-- ============================================================
-- TECLADO
-- ============================================================

-- Tempo mínimo (em segundos) que uma tecla precisa estar pressionada
-- para teclaSegurando() retornar true. Padrão: 0 (comportamento imediato).
local _tecla_tempo_min   = 0.0
local _tecla_tempo_atual = {}  -- { [keycode] = tempo_acumulado }

--- Define o tempo mínimo de hold para teclaSegurando() ativar.
-- @param segundos  número >= 0  (0 = sem delay, comportamento padrão)
function M.setTempoSegurando(segundos)
    _tecla_tempo_min = math.max(0, segundos or 0)
end

--- Retorna o tempo mínimo atual de hold configurado.
function M.getTempoSegurando()
    return _tecla_tempo_min
end

function M.teclaPressionou(t) return C.tupi_tecla_pressionou(t) == 1 end
function M.teclaSoltou(t)     return C.tupi_tecla_soltou(t)     == 1 end

--- Retorna true se a tecla está sendo segurada pelo tempo mínimo configurado.
-- Se setTempoSegurando(0) (padrão), comportamento é idêntico ao C puro.
function M.teclaSegurando(t)
    if C.tupi_tecla_segurando(t) ~= 1 then
        _tecla_tempo_atual[t] = nil
        return false
    end
    if _tecla_tempo_min <= 0 then
        return true
    end
    -- Depende de Tupi.dt() — injetado via M._getDt ao montar o TupiEngine
    local dt = M._getDt and M._getDt() or 0
    local acum = (_tecla_tempo_atual[t] or 0) + dt
    _tecla_tempo_atual[t] = acum
    return acum >= _tecla_tempo_min
end

-- ============================================================
-- MOUSE
-- ============================================================

-- Posição do mouse em coordenadas LÓGICAS (correto após resize da janela).
-- Use sempre estas para colisões, UI, etc.
function M.mouseX()   return tonumber(C.tupi_mouse_mundo_x())  end
function M.mouseY()   return tonumber(C.tupi_mouse_mundo_y())  end
function M.mouseDX()  return tonumber(C.tupi_mouse_mundo_dx()) end
function M.mouseDY()  return tonumber(C.tupi_mouse_mundo_dy()) end
function M.mousePos() return tonumber(C.tupi_mouse_mundo_x()), tonumber(C.tupi_mouse_mundo_y()) end

-- Posição do mouse em screen-coords físicos (raramente necessário).
function M.mouseXRaw()  return tonumber(C.tupi_mouse_x())  end
function M.mouseYRaw()  return tonumber(C.tupi_mouse_y())  end

function M.mouseClicou(b)    return C.tupi_mouse_clicou(b    or 0) == 1 end
function M.mouseSegurando(b) return C.tupi_mouse_segurando(b or 0) == 1 end
function M.mouseSoltou(b)    return C.tupi_mouse_soltou(b    or 0) == 1 end

function M.scrollX() return tonumber(C.tupi_scroll_x()) end
function M.scrollY() return tonumber(C.tupi_scroll_y()) end

return M
