-- texto.lua — Texto com fontes bitmap (PNG), sombra e caixa de diálogo 9-slice.

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- TEXTO COM FONTES BITMAP (PNG)
-- ============================================================
-- PNG com glifos em grade uniforme (largCelula × altCelula), ordem ASCII a partir de charInicio.
-- Exemplo: Tupi.texto.carregarFonte("assets/fonte.png", 8, 8, 16, 32)

local _quad_glifo        = ffi.new("float[16]")  -- buffer reutilizável
local _texto_fonte_padrao = nil

--- Carrega uma fonte bitmap a partir de um PNG com grade de glifos.
-- @param caminho     arquivo PNG
-- @param largCelula, altCelula  tamanho de cada glifo em pixels
-- @param colunas     número de colunas na grade (padrão 16)
-- @param charInicio  código ASCII do primeiro glifo (padrão 32 = ' ')
function M.carregarFonte(caminho, largCelula, altCelula, colunas, charInicio)
    assert(type(caminho)    == "string", "[TupiTexto] carregarFonte: caminho deve ser string")
    assert(type(largCelula) == "number", "[TupiTexto] carregarFonte: largCelula é obrigatória")
    assert(type(altCelula)  == "number", "[TupiTexto] carregarFonte: altCelula é obrigatória")

    local spr = C.tupi_sprite_carregar(caminho)
    if spr == nil then
        error("[TupiTexto] carregarFonte: falha ao carregar '" .. caminho .. "'")
    end

    local larg_img = tonumber(spr.largura)
    local alt_img  = tonumber(spr.altura)
    colunas    = colunas    or 16
    charInicio = charInicio or 32

    local linhas  = math.floor(alt_img / altCelula)
    local uv_px_x = largCelula / larg_img
    local uv_px_y = altCelula  / alt_img

    return {
        sprite     = spr,
        textura_id = tonumber(spr.textura),
        larg_cel   = largCelula,
        alt_cel    = altCelula,
        colunas    = colunas,
        linhas     = linhas,
        larg_img   = larg_img,
        alt_img    = alt_img,
        uv_px_x    = uv_px_x,
        uv_px_y    = uv_px_y,
        char_ini   = charInicio,
        espaco     = largCelula,
        _destruida = false,
    }
end

--- Destrói a fonte e libera a textura da GPU.
function M.destruirFonte(fonte)
    if not fonte or fonte._destruida then return end
    C.tupi_sprite_destruir(fonte.sprite)
    fonte._destruida = true
    if _texto_fonte_padrao == fonte then
        _texto_fonte_padrao = nil
    end
end

--- Define a fonte padrão para desenhar/desenharBorda.
function M.setFontePadrao(fonte)
    assert(fonte and not fonte._destruida,
        "[TupiTexto] setFontePadrao: fonte inválida ou destruída")
    _texto_fonte_padrao = fonte
end

--- Retorna a fonte padrão atual (ou nil).
function M.getFontePadrao()
    return _texto_fonte_padrao
end

-- Helper: calcula UV de um caractere
local function _texto_uv_char(fonte, codigo)
    local idx = codigo - fonte.char_ini
    if idx < 0 or idx >= (fonte.colunas * fonte.linhas) then
        idx = 0
    end
    local col = idx % fonte.colunas
    local lin = math.floor(idx / fonte.colunas)
    local u0  = col * fonte.uv_px_x
    local v0  = lin * fonte.uv_px_y
    return u0, v0, u0 + fonte.uv_px_x, v0 + fonte.uv_px_y
end

-- Helper: envia um único glifo ao batch
local function _texto_enviar_glifo(fonte, codigo, x, y, sw, sh, alpha, z)
    if codigo == 32 then return end  -- espaço: sem draw call

    local u0, v0, u1, v1 = _texto_uv_char(fonte, codigo)

    _quad_glifo[0]  = x;      _quad_glifo[1]  = y;      _quad_glifo[2]  = u0; _quad_glifo[3]  = v0
    _quad_glifo[4]  = x + sw; _quad_glifo[5]  = y;      _quad_glifo[6]  = u1; _quad_glifo[7]  = v0
    _quad_glifo[8]  = x;      _quad_glifo[9]  = y + sh; _quad_glifo[10] = u0; _quad_glifo[11] = v1
    _quad_glifo[12] = x + sw; _quad_glifo[13] = y + sh; _quad_glifo[14] = u1; _quad_glifo[15] = v1

    C.tupi_objeto_enviar_batch_raw(fonte.textura_id, _quad_glifo, alpha, z)
end

--- Enfileira uma string no batch para ser desenhada no próximo batchDesenhar().
-- @param x, y          posição (canto superior esquerdo)
-- @param z             camada (padrão 0)
-- @param w, h          ignorados (mantidos para API uniforme)
-- @param texto         string a exibir
-- @param escala        fator de escala (padrão 1.0)
-- @param transparencia 0.0–1.0 (padrão 1.0)
-- @param fonte         tabela de carregarFonte() (padrão: fonte padrão)
function M.desenhar(x, y, z, texto, escala, transparencia, fonte)
    fonte         = fonte or _texto_fonte_padrao
    assert(fonte and not fonte._destruida,
        "[TupiTexto] desenhar: nenhuma fonte definida — chame Tupi.texto.setFontePadrao()")
    assert(type(texto) == "string", "[TupiTexto] desenhar: 'texto' deve ser string")

    z             = z             or 0
    escala        = escala        or 1.0
    transparencia = transparencia or 1.0

    local sw = fonte.larg_cel * escala
    local sh = fonte.alt_cel  * escala
    local cx = x

    for i = 1, #texto do
        local codigo = string.byte(texto, i)
        if codigo == 10 then
            cx = x
            y  = y + sh
        else
            _texto_enviar_glifo(fonte, codigo, cx, y, sw, sh, transparencia, z)
            cx = cx + sw
        end
    end
end

--- Enfileira string com outline de sombra nas 4 diagonais.
function M.desenharSombra(x, y, camada, deslocX, deslocY, texto,
                           escala, transparencia,
                           escalaSombra, transparenciaSombra,
                           fonte, fonteSombra)
    fonte               = fonte or _texto_fonte_padrao
    fonteSombra         = fonteSombra or fonte
    assert(fonte and not fonte._destruida,
        "[TupiTexto] desenharSombra: nenhuma fonte definida")
    assert(fonteSombra and not fonteSombra._destruida,
        "[TupiTexto] desenharSombra: fonteSombra inválida ou destruída")
    assert(type(texto) == "string", "[TupiTexto] desenharSombra: 'texto' deve ser string")

    camada              = camada              or 0
    deslocX             = deslocX             or 1
    deslocY             = deslocY             or 1
    escala              = escala              or 1.0
    transparencia       = transparencia       or 1.0
    escalaSombra        = escalaSombra        or escala
    transparenciaSombra = transparenciaSombra or (transparencia * 0.6)

    local camadaSombra = camada - 1
    local lw = fonte.larg_cel       * escala
    local lh = fonte.alt_cel        * escala
    local sw = fonteSombra.larg_cel * escalaSombra
    local sh = fonteSombra.alt_cel  * escalaSombra

    local direcoes = {
        {  deslocX,  deslocY }, { -deslocX,  deslocY },
        {  deslocX, -deslocY }, { -deslocX, -deslocY },
    }

    for _, dir in ipairs(direcoes) do
        local ox, oy = dir[1], dir[2]
        local cx, cy = x, y
        for i = 1, #texto do
            local cod = string.byte(texto, i)
            if cod == 10 then cx = x; cy = cy + sh
            else
                _texto_enviar_glifo(fonteSombra, cod, cx + ox, cy + oy,
                    sw, sh, transparenciaSombra, camadaSombra)
                cx = cx + sw
            end
        end
    end

    local cx, cy = x, y
    for i = 1, #texto do
        local cod = string.byte(texto, i)
        if cod == 10 then cx = x; cy = cy + lh
        else
            _texto_enviar_glifo(fonte, cod, cx, cy, lw, lh, transparencia, camada)
            cx = cx + lw
        end
    end
end

-- Alias do nome antigo para não quebrar código existente
M.desenharBorda = M.desenharSombra

--- Desenha uma caixa de diálogo com borda PNG (9-slice) e texto dentro.
--
-- O sprite de frame deve ser um PNG dividido em 3×3 tiles iguais:
--   ┌──┬──┬──┐
--   │TL│TC│TR│   TL=canto sup-esq  TC=borda sup  TR=canto sup-dir
--   ├──┼──┼──┤   ML=borda esq     MC=fundo       MR=borda dir
--   │ML│MC│MR│   BL=canto inf-esq  BC=borda inf  BR=canto inf-dir
--   ├──┼──┼──┤
--   │BL│BC│BR│
--   └──┴──┴──┘
function M.desenharCaixa(x, y, camada, largura, altura, texto,
                          escala, transparencia,
                          fonte, frame,
                          tamTile, escalaBorda, transparenciaBorda, recuo)
    fonte               = fonte or _texto_fonte_padrao
    assert(fonte and not fonte._destruida, "[TupiTexto] desenharCaixa: fonte inválida")
    assert(frame ~= nil,                  "[TupiTexto] desenharCaixa: frame (TupiSprite*) não pode ser nil")
    assert(type(texto) == "string",       "[TupiTexto] desenharCaixa: 'texto' deve ser string")

    camada              = camada              or 0
    escala              = escala              or 1.0
    transparencia       = transparencia       or 1.0
    escalaBorda         = escalaBorda         or 1.0
    transparenciaBorda  = transparenciaBorda  or 1.0

    local tamTileSrc = tamTile or math.floor(tonumber(frame.largura) / 3)
    local tamTileDst = tamTileSrc * escalaBorda

    recuo = recuo or tamTileDst

    local lT = M.largura(fonte, texto, escala)
    local aT = M.altura (fonte, texto, escala)
    if not largura or largura == 0 then largura = lT + recuo * 2 end
    if not altura  or altura  == 0 then altura  = aT + recuo * 2 end

    local texId  = tonumber(frame.textura)
    local imgW   = tonumber(frame.largura)
    local imgH   = tonumber(frame.altura)
    local uvTW   = tamTileSrc / imgW
    local uvTH   = tamTileSrc / imgH

    local q = ffi.new("float[16]")
    local function _quad(px, py, pw, ph, u0, v0, u1, v1)
        q[0]  = px;      q[1]  = py;      q[2]  = u0; q[3]  = v0
        q[4]  = px + pw; q[5]  = py;      q[6]  = u1; q[7]  = v0
        q[8]  = px;      q[9]  = py + ph; q[10] = u0; q[11] = v1
        q[12] = px + pw; q[13] = py + ph; q[14] = u1; q[15] = v1
        C.tupi_objeto_enviar_batch_raw(texId, q, transparenciaBorda, camada)
    end

    local function uv(col, lin)
        local u0 = col * uvTW
        local v0 = lin * uvTH
        return u0, v0, u0 + uvTW, v0 + uvTH
    end

    local x2 = x + largura
    local y2 = y + altura
    local iw = largura - tamTileDst * 2
    local ih = altura  - tamTileDst * 2

    -- cantos
    _quad(x,             y,             tamTileDst, tamTileDst, uv(0,0))
    _quad(x2-tamTileDst, y,             tamTileDst, tamTileDst, uv(2,0))
    _quad(x,             y2-tamTileDst, tamTileDst, tamTileDst, uv(0,2))
    _quad(x2-tamTileDst, y2-tamTileDst, tamTileDst, tamTileDst, uv(2,2))

    -- bordas esticadas
    if iw > 0 then
        _quad(x+tamTileDst, y,             iw, tamTileDst, uv(1,0))
        _quad(x+tamTileDst, y2-tamTileDst, iw, tamTileDst, uv(1,2))
    end
    if ih > 0 then
        _quad(x,             y+tamTileDst, tamTileDst, ih, uv(0,1))
        _quad(x2-tamTileDst, y+tamTileDst, tamTileDst, ih, uv(2,1))
    end

    -- fundo centro
    if iw > 0 and ih > 0 then
        _quad(x+tamTileDst, y+tamTileDst, iw, ih, uv(1,1))
    end

    -- texto (camada+1 para ficar acima da caixa)
    local tx = x + recuo
    local ty = y + recuo
    local sw = fonte.larg_cel * escala
    local sh = fonte.alt_cel  * escala
    local cx, cy = tx, ty
    for i = 1, #texto do
        local cod = string.byte(texto, i)
        if cod == 10 then
            cx = tx
            cy = cy + sh
        else
            _texto_enviar_glifo(fonte, cod, cx, cy, sw, sh, transparencia, camada + 1)
            cx = cx + sw
        end
    end
end

--- Retorna a largura em pixels de um texto (útil para centralizar).
function M.largura(fonte, texto, escala)
    fonte  = fonte or _texto_fonte_padrao
    escala = escala or 1.0
    assert(fonte,                   "[TupiTexto] largura: fonte não definida")
    assert(type(texto) == "string", "[TupiTexto] largura: 'texto' deve ser string")

    local maior, atual = 0, 0
    for i = 1, #texto do
        if string.byte(texto, i) == 10 then
            if atual > maior then maior = atual end
            atual = 0
        else
            atual = atual + 1
        end
    end
    if atual > maior then maior = atual end

    return maior * fonte.larg_cel * escala
end

--- Retorna a altura em pixels de um texto (suporta \n).
function M.altura(fonte, texto, escala)
    fonte  = fonte or _texto_fonte_padrao
    escala = escala or 1.0
    assert(fonte,                   "[TupiTexto] altura: fonte não definida")
    assert(type(texto) == "string", "[TupiTexto] altura: 'texto' deve ser string")

    local linhas = 1
    for i = 1, #texto do
        if string.byte(texto, i) == 10 then linhas = linhas + 1 end
    end

    return linhas * fonte.alt_cel * escala
end

--- Retorna largura e altura de um texto de uma só vez.
function M.dimensoes(fonte, texto, escala)
    return M.largura(fonte, texto, escala),
           M.altura(fonte, texto, escala)
end

return M
