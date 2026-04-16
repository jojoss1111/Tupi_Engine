-- camera.lua — Câmera 2D como objeto + sistema de paralaxe.
--
-- USO BÁSICO:
--
--   local cam = Tupi.camera.criar(player.x, player.y)
--   -- player aparece no centro da janela
--
--   local cam = Tupi.camera.criar(player.x, player.y, 300, 400)
--   -- player aparece no pixel (300, 400) da tela
--
--   -- No loop:
--   Tupi.camera.seguir(cam, player.x, player.y, 0.1)
--   Tupi.camera.ativar(cam)   -- define como câmera do renderer
--
--   -- Ajustes em runtime:
--   Tupi.camera.zoom(cam, 2.0)
--   Tupi.camera.rotacao(cam, Tupi.rad(45))
--   Tupi.camera.ancora(cam, 200, 300)  -- reposiciona ponto de foco na tela

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- CÂMERA 2D (objeto)
-- ============================================================

M.camera = {}

--- Cria uma câmera 2D como objeto.
--
-- @param alvo_x   X do alvo no mundo (ex.: player.x)
-- @param alvo_y   Y do alvo no mundo (ex.: player.y)
-- @param ancora_x Pixel X da tela onde o alvo aparece (nil = centro)
-- @param ancora_y Pixel Y da tela onde o alvo aparece (nil = centro)
-- @return         tabela com o ponteiro da câmera e métodos OO (opcional)
--
-- Exemplos:
--   local cam = Tupi.camera.criar(0, 0)           -- alvo no centro da tela
--   local cam = Tupi.camera.criar(0, 0, 200, 300) -- alvo em (200,300) da tela
function M.camera.criar(alvo_x, alvo_y, ancora_x, ancora_y)
    alvo_x   = alvo_x   or 0
    alvo_y   = alvo_y   or 0
    ancora_x = ancora_x or -1  -- -1 → C usará centro da janela
    ancora_y = ancora_y or -1

    -- Aloca no heap para que o ponteiro seja estável
    local ptr = ffi.new("TupiCamera[1]")
    ptr[0] = C.tupi_camera_criar(alvo_x, alvo_y, ancora_x, ancora_y)

    -- Wrapper Lua com açúcar OO opcional
    local obj = { _ptr = ptr }

    -- Permite chamar cam:seguir(...) em vez de Tupi.camera.seguir(cam, ...)
    local mt = {}
    mt.__index = function(t, k)
        local fn = M.camera[k]
        if fn then
            return function(self, ...)
                return fn(self, ...)
            end
        end
    end
    setmetatable(obj, mt)

    return obj
end

--- Destrói a câmera e libera recursos.
function M.camera.destruir(cam)
    assert(cam and cam._ptr, "[Camera] destruir: câmera inválida")
    C.tupi_camera_destruir(cam._ptr)
end

--- Define esta câmera como a câmera ativa do renderer.
-- Deve ser chamado uma vez por frame, após atualizar o alvo.
function M.camera.ativar(cam)
    assert(cam and cam._ptr, "[Camera] ativar: câmera inválida")
    C.tupi_camera_ativar(cam._ptr)
end

--- Move o alvo instantaneamente para (x, y).
-- @param x, y  posição do alvo no mundo
function M.camera.pos(cam, x, y)
    assert(cam and cam._ptr, "[Camera] pos: câmera inválida")
    C.tupi_camera_pos(cam._ptr, x or 0, y or 0)
end

--- Desloca o alvo por (dx, dy).
function M.camera.mover(cam, dx, dy)
    assert(cam and cam._ptr, "[Camera] mover: câmera inválida")
    C.tupi_camera_mover(cam._ptr, dx or 0, dy or 0)
end

--- Define o zoom da câmera.
-- @param z  1.0 = normal | 2.0 = zoom in | 0.5 = zoom out
function M.camera.zoom(cam, z)
    assert(cam and cam._ptr, "[Camera] zoom: câmera inválida")
    C.tupi_camera_zoom(cam._ptr, z or 1)
end

--- Define a rotação da câmera.
-- @param angulo  em radianos (use Tupi.rad() para converter graus)
function M.camera.rotacao(cam, angulo)
    assert(cam and cam._ptr, "[Camera] rotacao: câmera inválida")
    C.tupi_camera_rotacao(cam._ptr, angulo or 0)
end

--- Define o ponto de ancoragem na tela em pixels.
-- É onde o alvo (ex.: player) aparece na tela.
-- @param ax, ay  pixels; nil ou -1 = centro da janela
function M.camera.ancora(cam, ax, ay)
    assert(cam and cam._ptr, "[Camera] ancora: câmera inválida")
    C.tupi_camera_ancora(cam._ptr, ax or -1, ay or -1)
end

--- Segue suavemente um alvo (lerp exponencial, frame-rate independente).
-- @param x, y        posição do alvo no mundo
-- @param velocidade  0–1 (padrão 0.1 = suave; 1.0 = imediato)
function M.camera.seguir(cam, x, y, velocidade)
    assert(cam and cam._ptr, "[Camera] seguir: câmera inválida")
    local dt = M._getDt and M._getDt() or 0
    C.tupi_camera_seguir(cam._ptr, x or 0, y or 0, velocidade or 0.1, dt)
end

--- Retorna a posição real da câmera no mundo (não a do alvo).
function M.camera.posAtual(cam)
    assert(cam and cam._ptr, "[Camera] posAtual: câmera inválida")
    return tonumber(C.tupi_camera_get_x(cam._ptr)),
           tonumber(C.tupi_camera_get_y(cam._ptr))
end

--- Retorna o alvo atual (alvo_x, alvo_y).
function M.camera.alvoAtual(cam)
    assert(cam and cam._ptr, "[Camera] alvoAtual: câmera inválida")
    return tonumber(cam._ptr[0].alvo_x),
           tonumber(cam._ptr[0].alvo_y)
end

function M.camera.zoomAtual(cam)
    assert(cam and cam._ptr, "[Camera] zoomAtual: câmera inválida")
    return tonumber(C.tupi_camera_get_zoom(cam._ptr))
end

function M.camera.rotacaoAtual(cam)
    assert(cam and cam._ptr, "[Camera] rotacaoAtual: câmera inválida")
    return tonumber(C.tupi_camera_get_rotacao(cam._ptr))
end

--- Converte posição de tela (pixels) → coordenada no mundo.
-- Usa a câmera fornecida, não necessariamente a ativa.
function M.camera.telaMundo(cam, sx, sy)
    assert(cam and cam._ptr, "[Camera] telaMundo: câmera inválida")
    local wx = ffi.new("float[1]")
    local wy = ffi.new("float[1]")
    C.tupi_camera_tela_mundo_lua(sx, sy, wx, wy)
    return tonumber(wx[0]), tonumber(wy[0])
end

--- Converte coordenada do mundo → posição na tela (pixels).
function M.camera.mundoTela(cam, wxv, wyv)
    assert(cam and cam._ptr, "[Camera] mundoTela: câmera inválida")
    local sx = ffi.new("float[1]")
    local sy = ffi.new("float[1]")
    C.tupi_camera_mundo_tela_lua(wxv, wyv, sx, sy)
    return tonumber(sx[0]), tonumber(sy[0])
end

--- Posição do mouse em coordenadas do mundo (usa câmera ativa).
function M.camera.mouseMundo(cam)
    local mx, my = M._getMouse and M._getMouse() or 0, 0
    return M.camera.telaMundo(cam, mx, my)
end

-- ============================================================
-- PARALAXE 2D
-- ============================================================

M.paralax = {}

--- Registra uma camada de paralaxe.
-- @param fatorX, fatorY  [0.0–1.0] quanto a camada acompanha a câmera
-- @param z               camada de renderização (-1000 a 1000)
-- @param larguraLoop     largura do tile para wrap horizontal (0 = sem repeat)
-- @param alturaLoop      altura do tile para wrap vertical   (0 = sem repeat)
-- @return                ID da camada
function M.paralax.registrar(fatorX, fatorY, z, larguraLoop, alturaLoop)
    assert(type(fatorX) == "number", "[Paralax] registrar: fatorX deve ser número")
    assert(type(fatorY) == "number", "[Paralax] registrar: fatorY deve ser número")
    local id = C.tupi_paralax_registrar(
        fatorX,
        fatorY,
        z            or 0,
        larguraLoop  or 0.0,
        alturaLoop   or 0.0
    )
    if id < 0 then
        error("[TupiEngine] Paralax: limite de camadas atingido!")
    end
    return id
end

--- Remove uma camada pelo ID.
function M.paralax.remover(id)
    assert(type(id) == "number", "[Paralax] remover: id deve ser número")
    C.tupi_paralax_remover(id)
end

--- Atualiza offsets de todas as camadas. Chame uma vez por frame.
-- Sem parâmetros usa a câmera ativa automaticamente.
function M.paralax.atualizar(cam, camX, camY)
    if camX == nil then
        if cam and cam._ptr then
            camX, camY = M.camera.posAtual(cam)
        else
            camX, camY = 0, 0
        end
    end
    C.tupi_paralax_atualizar(camX, camY or 0)
end

--- Retorna o offset (ox, oy, z) de uma camada.
function M.paralax.offset(id)
    assert(type(id) == "number", "[Paralax] offset: id deve ser número")
    local r = C.tupi_paralax_offset(id)
    assert(r.valido == 1, "[TupiEngine] Paralax: ID " .. id .. " inválido")
    return tonumber(r.offset_x), tonumber(r.offset_y), tonumber(r.z_layer)
end

--- Desenha o objeto deslocado pelo offset da camada.
function M.paralax.desenhar(id, wrapper)
    assert(type(id) == "number", "[Paralax] desenhar: id deve ser número")
    local r = C.tupi_paralax_offset(id)
    if r.valido == 0 then
        io.stderr:write("[TupiEngine] Paralax.desenhar: ID " .. id .. " inválido\n")
        return
    end

    local ox = tonumber(wrapper.obj[0].x)
    local oy = tonumber(wrapper.obj[0].y)
    wrapper.obj[0].x = ox + tonumber(r.offset_x)
    wrapper.obj[0].y = oy + tonumber(r.offset_y)
    C.tupi_objeto_enviar_batch(wrapper.obj, r.z_layer)
    wrapper.obj[0].x = ox
    wrapper.obj[0].y = oy
end

--- Desenha camada com tile horizontal (wrap automático).
function M.paralax.desenharTile(id, wrapper, largTela)
    assert(type(id) == "number", "[Paralax] desenharTile: id deve ser número")
    local r = C.tupi_paralax_offset(id)
    if r.valido == 0 then
        io.stderr:write("[TupiEngine] Paralax.desenharTile: ID " .. id .. " inválido\n")
        return
    end

    local ox   = tonumber(wrapper.obj[0].x)
    local oy   = tonumber(wrapper.obj[0].y)
    local offX = tonumber(r.offset_x)
    local offY = tonumber(r.offset_y)
    local larg = tonumber(wrapper.obj[0].largura)
    local z    = r.z_layer
    largTela   = largTela or (M._getLargura and M._getLargura() or 800)

    local copias = math.ceil(largTela / larg) + 1
    for i = 0, copias do
        wrapper.obj[0].x = ox + offX + i * larg
        wrapper.obj[0].y = oy + offY
        C.tupi_objeto_enviar_batch(wrapper.obj, z)
    end

    wrapper.obj[0].x = ox
    wrapper.obj[0].y = oy
end

--- Reseta o estado de câmera do paralaxe (use ao trocar de cena).
function M.paralax.resetar()
    C.tupi_paralax_resetar()
end

--- Reseta o offset de uma camada sem removê-la.
function M.paralax.resetarCamada(id)
    assert(type(id) == "number", "[Paralax] resetarCamada: id deve ser número")
    C.tupi_paralax_resetar_camada(id)
end

--- Muda o fator de uma camada em runtime.
function M.paralax.setFator(id, fatorX, fatorY)
    assert(type(id) == "number", "[Paralax] setFator: id deve ser número")
    C.tupi_paralax_set_fator(id, fatorX or 0.0, fatorY or 0.0)
end

--- Retorna o total de camadas ativas (debug).
function M.paralax.totalAtivas()
    return tonumber(C.tupi_paralax_total_ativas())
end

return M