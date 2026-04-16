-- fisica.lua — Física 2D (corpos dinâmicos, impulsos, resolução de colisão).

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- FÍSICA 2D
-- ============================================================

--- Cria um corpo físico dinâmico (afetado pela gravidade).
-- @param x, y          posição inicial
-- @param massa         valores típicos: 1.0–100.0
-- @param elasticidade  0.0 (para) a 1.0 (ricochete perfeito)
-- @param atrito        0.0 (desliza) a 1.0 (para rápido)
-- @return              cdata TupiCorpo[1]
function M.corpo(x, y, massa, elasticidade, atrito)
    local c = ffi.new("TupiCorpo[1]")
    c[0].x            = x            or 0
    c[0].y            = y            or 0
    c[0].velX         = 0
    c[0].velY         = 0
    c[0].aceleracaoX  = 0
    c[0].aceleracaoY  = 0
    c[0].massa        = massa        or 1.0
    c[0].elasticidade = elasticidade or 0.3
    c[0].atrito       = atrito       or 0.1
    return c
end

--- Cria um corpo estático (massa=0, nunca se move).
function M.corpoEstatico(x, y)
    local c = ffi.new("TupiCorpo[1]")
    c[0].x            = x or 0
    c[0].y            = y or 0
    c[0].velX         = 0
    c[0].velY         = 0
    c[0].aceleracaoX  = 0
    c[0].aceleracaoY  = 0
    c[0].massa        = 0.0
    c[0].elasticidade = 0.0
    c[0].atrito       = 1.0
    return c
end

--- Avança a simulação do corpo por um passo de tempo.
-- @param gravidade  aceleração em px/s² (padrão 500.0)
function M.atualizar(corpo, gravidade)
    -- Depende de Tupi.dt() — injetado via M._getDt ao montar o TupiEngine
    local dt = M._getDt and M._getDt() or 0
    C.tupi_fisica_atualizar(corpo, dt, gravidade or 500.0)
end

--- Aplica impulso instantâneo (pulo, explosão, knockback).
function M.impulso(corpo, fx, fy)
    C.tupi_fisica_impulso(corpo, fx or 0, fy or 0)
end

--- Retorna o retângulo de colisão centrado no corpo.
function M.retCol(corpo, largura, altura)
    local r = C.tupi_corpo_ret(corpo, largura or 0, altura or 0)
    return { x = tonumber(r.x), y = tonumber(r.y),
             largura = tonumber(r.largura), altura = tonumber(r.altura) }
end

--- Retorna o círculo de colisão centrado no corpo.
function M.cirCol(corpo, raio)
    local c = C.tupi_corpo_cir(corpo, raio or 0)
    return { x = tonumber(c.x), y = tonumber(c.y), raio = tonumber(c.raio) }
end

--- Resolve colisão entre dois corpos dinâmicos.
function M.resolverColisao(a, b, info)
    local c = ffi.new("TupiColisao",
        info.colidindo and 1 or 0,
        info.dx or 0,
        info.dy or 0)
    C.tupi_resolver_colisao(a, b, c)
end

--- Resolve colisão entre um corpo dinâmico e um obstáculo estático.
function M.resolverEstatico(corpo, info)
    local c = ffi.new("TupiColisao",
        info.colidindo and 1 or 0,
        info.dx or 0,
        info.dy or 0)
    C.tupi_resolver_estatico(corpo, c)
end

function M.atrito(corpo)
    local dt = M._getDt and M._getDt() or 0
    C.tupi_aplicar_atrito(corpo, dt)
end
function M.limitarVel(corpo, maxVel) C.tupi_limitar_velocidade(corpo, maxVel or 800.0) end
function M.pos(corpo)  return tonumber(corpo[0].x),    tonumber(corpo[0].y)    end
function M.vel(corpo)  return tonumber(corpo[0].velX), tonumber(corpo[0].velY) end

function M.setPosicao(corpo, x, y)
    corpo[0].x = x or corpo[0].x
    corpo[0].y = y or corpo[0].y
end

function M.setVel(corpo, vx, vy)
    corpo[0].velX = vx or 0
    corpo[0].velY = vy or 0
end

--- Sincroniza a posição de um wrapper com seu TupiCorpo.
function M.sincronizar(wrapper, corpo)
    wrapper.obj[0].x = corpo[0].x
    wrapper.obj[0].y = corpo[0].y
end

return M
