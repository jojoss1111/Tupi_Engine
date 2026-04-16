-- sprite.lua — Sprites, objetos, animações, espelhamento, hitbox e posição.

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- SPRITES
-- ============================================================

--- Carrega uma imagem na GPU (PNG, JPEG, BMP). Lança erro se falhar.
function M.carregarSprite(caminho)
    assert(type(caminho) == "string", "[TupiEngine] carregarSprite: caminho deve ser string")
    local spr = C.tupi_sprite_carregar(caminho)
    if spr == nil then
        error("[TupiEngine] carregarSprite: não foi possível carregar '" .. caminho .. "'")
    end
    return spr
end

--- Libera um sprite da GPU.
function M.destruirSprite(spr)
    if spr ~= nil then C.tupi_sprite_destruir(spr) end
end

-- ============================================================
-- OBJETOS (sprites com Z-layer)
-- ============================================================

--- Cria um objeto para exibir um sprite/sheet na tela.
-- @param x, y          posição inicial (canto superior esquerdo)
-- @param z             camada de profundidade (-1000 a 1000, padrão 0)
-- @param largura, altura  tamanho de cada célula em pixels
-- @param wx, hy        (ignorado internamente; reservado)
-- @param transparencia 0.0–1.0 (padrão 1.0)
-- @param escala        fator de escala (padrão 1.0)
-- @param sprite        TupiSprite* de carregarSprite()
-- @return              tabela { obj=cdata, z=int }
function M.criarObjeto(x, y, z, largura, altura, wx, hy, transparencia, escala, sprite)
    assert(sprite ~= nil, "[TupiEngine] criarObjeto: sprite não pode ser nil")
    local obj = ffi.new("TupiObjeto[1]")
    obj[0] = C.tupi_objeto_criar(
        x or 0, y or 0,
        largura, altura,
        wx,
        hy,
        transparencia or 1.0,
        escala        or 1.0,
        sprite
    )
    return { obj = obj, z = z or 0 }
end

-- ============================================================
-- ESPELHAMENTO DE SPRITES
-- ============================================================

local _espelhos = {}  -- { [chave] = { h=bool, v=bool } }

local function _chaveEspelho(wrapper)
    return tostring(ffi.cast("void*", wrapper.obj))
end

local _quad_espelho = ffi.new("float[16]")  -- buffer reutilizável sem alocação por frame

local function _enviarComEspelho(wrapper, camada)
    local e = _espelhos[_chaveEspelho(wrapper)]

    if not e then
        C.tupi_objeto_enviar_batch(wrapper.obj, camada)
        return
    end

    local obj      = wrapper.obj[0]
    local spr      = obj.imagem
    local cel_w    = tonumber(obj.largura)
    local cel_h    = tonumber(obj.altura)
    local larg_spr = tonumber(spr.largura)
    local alt_spr  = tonumber(spr.altura)

    local u0 = (tonumber(obj.coluna) * cel_w) / larg_spr
    local v0 = (tonumber(obj.linha)  * cel_h) / alt_spr
    local u1 = u0 + cel_w / larg_spr
    local v1 = v0 + cel_h / alt_spr

    if e.h then u0, u1 = u1, u0 end
    if e.v then v0, v1 = v1, v0 end

    local sw = cel_w * tonumber(obj.escala)
    local sh = cel_h * tonumber(obj.escala)
    local x0 = tonumber(obj.x)
    local y0 = tonumber(obj.y)
    local x1 = x0 + sw
    local y1 = y0 + sh

    -- Quad (x,y,u,v) × 4 vértices — TRIANGLE_STRIP
    _quad_espelho[0]  = x0; _quad_espelho[1]  = y0; _quad_espelho[2]  = u0; _quad_espelho[3]  = v0
    _quad_espelho[4]  = x1; _quad_espelho[5]  = y0; _quad_espelho[6]  = u1; _quad_espelho[7]  = v0
    _quad_espelho[8]  = x0; _quad_espelho[9]  = y1; _quad_espelho[10] = u0; _quad_espelho[11] = v1
    _quad_espelho[12] = x1; _quad_espelho[13] = y1; _quad_espelho[14] = u1; _quad_espelho[15] = v1

    C.tupi_objeto_enviar_batch_raw(
        tonumber(spr.textura),
        _quad_espelho,
        tonumber(obj.transparencia),
        camada
    )
end

-- Expõe para uso em animações e destruição
M._enviarComEspelho = _enviarComEspelho
M._espelhos         = _espelhos
M._chaveEspelho     = _chaveEspelho

--- Desenha um objeto imediatamente respeitando espelhamento.
function M.desenharObjeto(wrapper)
    if wrapper._destruido then return end
    _enviarComEspelho(wrapper, wrapper.z or 0)
    C.tupi_batch_desenhar()
end

--- Define espelhamento do objeto.
-- @param wrapper    tabela de criarObjeto()
-- @param vertical   boolean
-- @param horizontal boolean
function M.espelhar(wrapper, vertical, horizontal)
    assert(wrapper and wrapper.obj, "[TupiEngine] espelhar: wrapper inválido")
    local chave = _chaveEspelho(wrapper)
    _espelhos[chave] = { v = vertical == true, h = horizontal == true }
end

--- Retorna o estado atual de espelhamento: horizontal (bool), vertical (bool).
function M.getEspelho(wrapper)
    local e = _espelhos[_chaveEspelho(wrapper)]
    if not e then return false, false end
    return e.h, e.v
end

--- Enfileira o objeto no batch com o Z definido em criarObjeto.
-- @param wrapper  tabela de criarObjeto()
-- @param z        (opcional) sobrescreve o Z para este frame
function M.enviarBatch(wrapper, z)
    if wrapper._destruido then return end
    _enviarComEspelho(wrapper, z or wrapper.z or 0)
end

--- Atalho: enfileira E desenha imediatamente (para objetos únicos sem ordenação por Z).
function M.desenhar(wrapper, z)
    if wrapper._destruido then return end
    _enviarComEspelho(wrapper, z or wrapper.z or 0)
    C.tupi_batch_desenhar()
end

-- ============================================================
-- ANIMAÇÕES (sprite sheet por coluna/linha)
-- ============================================================

local _animEstado   = {}
local _animContador = 0

local function _chaveAnim(anim, wrapper)
    return tostring(anim._id) .. ":" .. tostring(ffi.cast("void*", wrapper.obj))
end

local function _pegarEstado(anim, wrapper)
    local chave = _chaveAnim(anim, wrapper)
    if not _animEstado[chave] then
        _animEstado[chave] = { frame = 0, tempo = 0.0, terminado = false }
    end
    return _animEstado[chave]
end

--- Cria um descritor de animação para um sprite sheet.
-- @param sprite   TupiSprite*
-- @param largura, altura  tamanho de cada frame em pixels
-- @param colunas  tabela de índices de coluna (ex: {0,1,2,3})
-- @param linhas   tabela de índices de linha  (ex: {0})
-- @param fps      frames por segundo (padrão 8)
-- @param loop     repete ao terminar? (padrão true)
function M.criarAnim(sprite, largura, altura, colunas, linhas, fps, loop)
    assert(sprite  ~= nil,                              "[Anim] sprite não pode ser nil")
    assert(type(largura)  == "number",                  "[Anim] largura é obrigatória")
    assert(type(altura)   == "number",                  "[Anim] altura é obrigatória")
    assert(type(colunas)  == "table" and #colunas > 0,  "[Anim] colunas deve ter ao menos 1 elemento")
    assert(type(linhas)   == "table" and #linhas  > 0,  "[Anim] linhas deve ter ao menos 1 elemento")

    _animContador = _animContador + 1

    local pares = {}
    for _, lin in ipairs(linhas) do
        for _, col in ipairs(colunas) do
            table.insert(pares, { col = col, linha = lin })
        end
    end

    return {
        _id     = _animContador,
        _sprite = sprite,
        _larg   = largura,
        _alt    = altura,
        _pares  = pares,
        _fps    = fps  or 8,
        _loop   = (loop == nil) and true or loop,
    }
end

--- Toca uma animação no objeto, avançando o frame pelo dt.
-- @param anim     descritor de criarAnim()
-- @param wrapper  tabela de criarObjeto()
-- @param z        (opcional) sobrescreve o Z para este frame
function M.tocarAnim(anim, wrapper, z)
    assert(anim and anim._pares, "[Anim] tocarAnim: anim inválida")

    local estado = _pegarEstado(anim, wrapper)
    local total  = #anim._pares
    -- Depende de Tupi.dt() — injetado via M._getDt ao montar o TupiEngine
    local dt = M._getDt and M._getDt() or 0

    if not estado.terminado then
        estado.tempo = estado.tempo + dt
        local durFrame   = 1.0 / anim._fps
        local frameAtual = math.floor(estado.tempo / durFrame)

        if frameAtual >= total then
            if anim._loop then
                estado.tempo = estado.tempo % (durFrame * total)
                estado.frame = math.floor(estado.tempo / durFrame)
            else
                estado.terminado = true
                estado.frame     = total - 1
            end
        else
            estado.frame = frameAtual
        end
    end

    local par = anim._pares[estado.frame + 1]
    wrapper.obj[0].coluna = par.col
    wrapper.obj[0].linha  = par.linha
    _enviarComEspelho(wrapper, z or wrapper.z or 0)
end

--- Para a animação e fixa no frame indicado.
-- @param frame  número (índice 0-based dentro dos pares da anim)
--            OU tabela {coluna, linha} para fixar diretamente na célula do sheet
-- @param z      (opcional) sobrescreve o Z para este frame
function M.pararAnim(anim, wrapper, frame, z)
    assert(anim and anim._pares, "[Anim] pararAnim: anim inválida")
    local chave = _chaveAnim(anim, wrapper)
    _animEstado[chave] = nil
    if type(frame) == "table" then
        wrapper.obj[0].coluna = frame[1] or 0
        wrapper.obj[0].linha  = frame[2] or 0
    else
        local idx = math.min(frame or 0, #anim._pares - 1)
        local par = anim._pares[idx + 1]
        wrapper.obj[0].coluna = par.col
        wrapper.obj[0].linha  = par.linha
    end
    _enviarComEspelho(wrapper, z or wrapper.z or 0)
end

--- Retorna true se a animação (não-loop) chegou ao último frame.
function M.animTerminou(anim, wrapper)
    local estado = _animEstado[_chaveAnim(anim, wrapper)]
    return estado ~= nil and estado.terminado
end

--- Reinicia a animação do início.
function M.animReiniciar(anim, wrapper)
    _animEstado[_chaveAnim(anim, wrapper)] = nil
end

--- Remove todos os estados de animação associados a um objeto.
function M.animLimparObjeto(wrapper)
    local sufixo = ":" .. tostring(ffi.cast("void*", wrapper.obj))
    for chave in pairs(_animEstado) do
        if chave:sub(-#sufixo) == sufixo then
            _animEstado[chave] = nil
        end
    end
end

-- ============================================================
-- POSIÇÃO DE OBJETOS
-- ============================================================

local _posicoes_salvas = {}

--- Move o objeto relativamente (dx, dy em pixels).
function M.mover(dx, dy, wrapper)
    wrapper.obj[0].x = wrapper.obj[0].x + (dx or 0)
    wrapper.obj[0].y = wrapper.obj[0].y + (dy or 0)
end

--- Teleporta o objeto para uma posição absoluta.
function M.teleportar(x, y, wrapper)
    wrapper.obj[0].x = x or wrapper.obj[0].x
    wrapper.obj[0].y = y or wrapper.obj[0].y
end

--- Salva a posição atual do objeto.
function M.salvarPosicao(wrapper)
    local id = tostring(ffi.cast("void*", wrapper.obj))
    _posicoes_salvas[id] = { x = tonumber(wrapper.obj[0].x), y = tonumber(wrapper.obj[0].y) }
end

--- Retorna a posição atual (x, y) do objeto.
function M.posicaoAtual(wrapper)
    return tonumber(wrapper.obj[0].x), tonumber(wrapper.obj[0].y)
end

--- Retorna a última posição salva (x, y), ou nil, nil.
function M.ultimaPosicao(wrapper)
    local p = _posicoes_salvas[tostring(ffi.cast("void*", wrapper.obj))]
    if not p then return nil, nil end
    return p.x, p.y
end

--- Restaura a última posição salva.
function M.voltarPosicao(wrapper)
    local p = _posicoes_salvas[tostring(ffi.cast("void*", wrapper.obj))]
    if not p then return end
    wrapper.obj[0].x = p.x
    wrapper.obj[0].y = p.y
end

--- Distância entre dois objetos.
function M.distanciaObjetos(a, b)
    local dx = tonumber(b.obj[0].x) - tonumber(a.obj[0].x)
    local dy = tonumber(b.obj[0].y) - tonumber(a.obj[0].y)
    return math.sqrt(dx * dx + dy * dy)
end

--- Move suavemente o objeto em direção a um alvo (lerp).
function M.moverParaAlvo(tx, ty, fator, wrapper)
    fator            = fator or 0.1
    wrapper.obj[0].x = wrapper.obj[0].x + (tx - wrapper.obj[0].x) * fator
    wrapper.obj[0].y = wrapper.obj[0].y + (ty - wrapper.obj[0].y) * fator
end

--- Faz o objeto perseguir outro em linha reta com velocidade fixa.
function M.perseguir(alvo, vel, wrapper)
    local dx   = tonumber(alvo.obj[0].x) - tonumber(wrapper.obj[0].x)
    local dy   = tonumber(alvo.obj[0].y) - tonumber(wrapper.obj[0].y)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then return end
    wrapper.obj[0].x = wrapper.obj[0].x + (dx / dist) * vel
    wrapper.obj[0].y = wrapper.obj[0].y + (dy / dist) * vel
end

-- ============================================================
-- HITBOX
-- ============================================================

--- Retorna hitbox relativa ao objeto, respeitando a escala.
-- @param x, y, w, h  offset e tamanho (não-escalado)
-- @param escalar     aplica escala do objeto? (padrão true)
function M.hitbox(wrapper, x, y, w, h, escalar)
    if wrapper._destruido then return { x=0, y=0, largura=0, altura=0 } end
    local ox    = tonumber(wrapper.obj[0].x)
    local oy    = tonumber(wrapper.obj[0].y)
    local fator = 1.0
    if escalar ~= false then
        local ok, e = pcall(function() return tonumber(wrapper.obj[0].escala) end)
        if ok and e and e > 0 then fator = e end
    end
    return { x = ox + x * fator, y = oy + y * fator,
             largura = w * fator, altura = h * fator }
end

--- Hitbox sem escala aplicada.
function M.hitboxFixa(wrapper, x, y, w, h)
    return M.hitbox(wrapper, x, y, w, h, false)
end

--- Desenha a hitbox na tela (debug).
function M.hitboxDesenhar(hb, cor, espessura)
    cor = cor or {0, 1, 0, 0.6}
    -- Depende de render._aplicarCor — injetado via M._aplicarCor
    local restaurar = M._aplicarCor and M._aplicarCor(cor) or function() end
    C.tupi_retangulo_borda(hb.x, hb.y, hb.largura, hb.altura, espessura or 1.0)
    restaurar()
end

--- Move o objeto em X e desfaz se colidir com hbB.
local function _moverX(dx, wrapperA, offX, offY, w, h, hbB)
    if dx == 0 then return false end
    wrapperA.obj[0].x = wrapperA.obj[0].x + dx
    local hbA = M.hitbox(wrapperA, offX, offY, w, h)
    -- Depende de colisao.retRet — injetado via M._retRet
    if M._retRet and M._retRet(hbA, hbB) then
        wrapperA.obj[0].x = wrapperA.obj[0].x - dx
        return true
    end
    return false
end

--- Move o objeto em Y e desfaz se colidir com hbB.
local function _moverY(dy, wrapperA, offX, offY, w, h, hbB)
    if dy == 0 then return false end
    wrapperA.obj[0].y = wrapperA.obj[0].y + dy
    local hbA = M.hitbox(wrapperA, offX, offY, w, h)
    if M._retRet and M._retRet(hbA, hbB) then
        wrapperA.obj[0].y = wrapperA.obj[0].y - dy
        return true
    end
    return false
end

--- Resolve colisão sólida eixo a eixo.
-- @param dx, dy        quanto o player moveu neste frame (em pixels)
-- @param wrapperA      wrapper do player
-- @param offX,offY,w,h offset e tamanho da hitbox
-- @param hbB           hitbox do obstáculo
-- @return colidiu_x (bool), colidiu_y (bool)
function M.moverComColisao(dx, dy, wrapperA, offX, offY, w, h, hbB)
    local cx = _moverX(dx, wrapperA, offX, offY, w, h, hbB)
    local cy = _moverY(dy, wrapperA, offX, offY, w, h, hbB)
    return cx, cy
end

--- Versão legada — mantida para compatibilidade.
-- Preferir M.moverComColisao() para casos novos.
function M.resolverColisaoSolida(hbA, hbB, wrapperA)
    -- Depende de colisao.retRetInfo — injetado via M._retRetInfo
    local info = M._retRetInfo and M._retRetInfo(hbA, hbB) or { colidindo = false }
    if not info.colidindo then return info end
    wrapperA.obj[0].x = wrapperA.obj[0].x + info.dx
    wrapperA.obj[0].y = wrapperA.obj[0].y + info.dy
    return info
end

-- ============================================================
-- DESTRUIÇÃO
-- ============================================================

function M.destruir(wrapper, liberarSprite)
    if wrapper == nil or wrapper._destruido then return end
    wrapper._destruido = true

    local chave = tostring(ffi.cast("void*", wrapper.obj))
    for k in pairs(_animEstado) do
        if k:find(chave, 1, true) then _animEstado[k] = nil end
    end

    _espelhos[chave] = nil

    if liberarSprite and wrapper.obj[0].imagem ~= nil then
        C.tupi_sprite_destruir(wrapper.obj[0].imagem)
        wrapper.obj[0].imagem = nil
    end
end

--- Retorna true se o objeto foi destruído.
function M.destruido(wrapper)
    return wrapper == nil or wrapper._destruido == true
end

return M
