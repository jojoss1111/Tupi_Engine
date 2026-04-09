-- TupiEngine.lua
-- TupiEngine - API principal em Lua
-- Interface que o programador usa para criar jogos
-- Edite apenas o main.lua — não mexa aqui.

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local Tupi = {}

-- ============================================================
-- JANELA
-- ============================================================

--- Cria a janela com configurações básicas.
-- @param largura  número (padrão 800)
-- @param altura   número (padrão 600)
-- @param titulo   string (padrão "TupiEngine")
function Tupi.janela(largura, altura, titulo)
    largura = largura or 800
    altura  = altura  or 600
    titulo  = titulo  or "TupiEngine"
    if C.tupi_janela_criar(largura, altura, titulo) == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end
end

--- Cria a janela com opções avançadas.
--
-- @param largura   número — largura em pixels
-- @param altura    número — altura em pixels
-- @param titulo    string — título na barra do OS
-- @param opcoes    tabela opcional com os campos:
--
--   escala    (número, padrão 1.0)
--             Fator de escala DPI. escala=2 faz o mundo ter
--             largura/2 × altura/2 — ideal para pixel art sem
--             filtro. Use 1.0 para comportamento normal.
--
--   semBorda  (boolean, padrão false)
--             Remove a decoração do sistema (barra de título,
--             botões de fechar/minimizar). Útil para splash
--             screen ou HUD em tela cheia.
--
--   semTitulo (boolean, padrão false)
--             Deixa a barra de título em branco no OS.
--             Só faz diferença quando semBorda = false.
--
-- Exemplo — pixel art 2× sem barra:
--   Tupi.janelaEx(800, 600, "MeuJogo", { escala=2, semBorda=true })
--
function Tupi.janelaEx(largura, altura, titulo, opcoes)
    largura = largura or 800
    altura  = altura  or 600
    titulo  = titulo  or "TupiEngine"
    opcoes  = opcoes  or {}

    local escala    = opcoes.escala    or 1.0
    local semBorda  = opcoes.semBorda  and 1 or 0
    local semTitulo = opcoes.semTitulo and 1 or 0

    if C.tupi_janela_criar_ex(largura, altura, titulo,
                               escala, semBorda, semTitulo) == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end
end

function Tupi.rodando()   return C.tupi_janela_aberta()   == 1 end
function Tupi.limpar()    C.tupi_janela_limpar()               end
function Tupi.atualizar() C.tupi_janela_atualizar()            end
function Tupi.fechar()    C.tupi_janela_fechar()               end

function Tupi.tempo()   return tonumber(C.tupi_tempo())             end
function Tupi.dt()      return tonumber(C.tupi_delta_tempo())       end

--- Tamanho em coordenadas lógicas (afetado pela escala DPI).
-- Use sempre este para posicionar objetos no mundo.
function Tupi.largura() return tonumber(C.tupi_janela_largura())    end
function Tupi.altura()  return tonumber(C.tupi_janela_altura())     end

--- Tamanho em pixels físicos reais da janela.
function Tupi.larguraPx() return tonumber(C.tupi_janela_largura_px()) end
function Tupi.alturaPx()  return tonumber(C.tupi_janela_altura_px())  end

--- Fator de escala configurado na criação.
function Tupi.escala() return tonumber(C.tupi_janela_escala()) end

--- Muda o texto da barra de título em tempo de execução.
-- @param titulo  string
function Tupi.setTitulo(titulo)
    C.tupi_janela_set_titulo(titulo or "")
end

--- Ativa ou remove a borda/decoração da janela em runtime.
-- @param ativo  boolean — true = com borda, false = sem borda
function Tupi.setDecoracao(ativo)
    C.tupi_janela_set_decoracao(ativo and 1 or 0)
end

--- Entra ou sai do modo tela cheia.
-- @param ativo  boolean
function Tupi.telaCheia(ativo)
    C.tupi_janela_tela_cheia(ativo and 1 or 0)
end

-- ============================================================
-- COR
-- ============================================================

function Tupi.corFundo(r, g, b)
    C.tupi_cor_fundo(r or 0, g or 0, b or 0)
end

function Tupi.cor(r, g, b, a)
    C.tupi_cor(r or 1, g or 1, b or 1, a or 1)
end

function Tupi.usarCor(tabCor, a)
    C.tupi_cor(tabCor[1], tabCor[2], tabCor[3], a or tabCor[4] or 1)
end

-- Cores prontas
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

-- ============================================================
-- HELPER INTERNO: cor temporária por chamada
-- ============================================================

local function _aplicarCor(cor)
    if cor == nil then return function() end end
    C.tupi_cor(cor[1] or 1, cor[2] or 1, cor[3] or 1, cor[4] or 1)
    return function() C.tupi_cor(1, 1, 1, 1) end
end

-- ============================================================
-- FORMAS 2D
-- ============================================================

function Tupi.retangulo(x, y, largura, altura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_retangulo(x, y, largura, altura)
    restaurar()
end

function Tupi.retanguloBorda(x, y, largura, altura, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_retangulo_borda(x, y, largura, altura, espessura or 1)
    restaurar()
end

function Tupi.triangulo(x1, y1, x2, y2, x3, y3, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_triangulo(x1, y1, x2, y2, x3, y3)
    restaurar()
end

function Tupi.circulo(x, y, raio, segmentos, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_circulo(x, y, raio, segmentos or 64)
    restaurar()
end

function Tupi.circuloBorda(x, y, raio, segmentos, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_circulo_borda(x, y, raio, segmentos or 64, espessura or 1)
    restaurar()
end

function Tupi.linha(x1, y1, x2, y2, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_linha(x1, y1, x2, y2, espessura or 1)
    restaurar()
end

-- ============================================================
-- UTILITÁRIOS MATEMÁTICOS
-- ============================================================

function Tupi.lerp(a, b, t)       return a + (b - a) * t                  end
function Tupi.aleatorio(min, max) return min + math.random() * (max - min) end
function Tupi.rad(graus)          return graus * math.pi / 180             end
function Tupi.graus(rad)          return rad * 180 / math.pi               end
function Tupi.distancia(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================
-- CONSTANTES DE TECLAS
-- ============================================================

Tupi.TECLA_ESPACO    = 32;  Tupi.TECLA_ENTER     = 257; Tupi.TECLA_TAB       = 258
Tupi.TECLA_BACKSPACE = 259; Tupi.TECLA_ESC        = 256
Tupi.TECLA_SHIFT_ESQ = 340; Tupi.TECLA_SHIFT_DIR  = 344
Tupi.TECLA_CTRL_ESQ  = 341; Tupi.TECLA_CTRL_DIR   = 345
Tupi.TECLA_ALT_ESQ   = 342; Tupi.TECLA_ALT_DIR    = 346

Tupi.TECLA_CIMA     = 265;  Tupi.TECLA_BAIXO    = 264
Tupi.TECLA_ESQUERDA = 263;  Tupi.TECLA_DIREITA  = 262

Tupi.TECLA_A=65;  Tupi.TECLA_B=66;  Tupi.TECLA_C=67;  Tupi.TECLA_D=68
Tupi.TECLA_E=69;  Tupi.TECLA_F=70;  Tupi.TECLA_G=71;  Tupi.TECLA_H=72
Tupi.TECLA_I=73;  Tupi.TECLA_J=74;  Tupi.TECLA_K=75;  Tupi.TECLA_L=76
Tupi.TECLA_M=77;  Tupi.TECLA_N=78;  Tupi.TECLA_O=79;  Tupi.TECLA_P=80
Tupi.TECLA_Q=81;  Tupi.TECLA_R=82;  Tupi.TECLA_S=83;  Tupi.TECLA_T=84
Tupi.TECLA_U=85;  Tupi.TECLA_V=86;  Tupi.TECLA_W=87;  Tupi.TECLA_X=88
Tupi.TECLA_Y=89;  Tupi.TECLA_Z=90

Tupi.TECLA_0=48; Tupi.TECLA_1=49; Tupi.TECLA_2=50; Tupi.TECLA_3=51
Tupi.TECLA_4=52; Tupi.TECLA_5=53; Tupi.TECLA_6=54; Tupi.TECLA_7=55
Tupi.TECLA_8=56; Tupi.TECLA_9=57

Tupi.TECLA_NUM0=320; Tupi.TECLA_NUM1=321; Tupi.TECLA_NUM2=322
Tupi.TECLA_NUM3=323; Tupi.TECLA_NUM4=324; Tupi.TECLA_NUM5=325
Tupi.TECLA_NUM6=326; Tupi.TECLA_NUM7=327; Tupi.TECLA_NUM8=328
Tupi.TECLA_NUM9=329

Tupi.TECLA_F1=290;  Tupi.TECLA_F2=291;  Tupi.TECLA_F3=292
Tupi.TECLA_F4=293;  Tupi.TECLA_F5=294;  Tupi.TECLA_F6=295
Tupi.TECLA_F7=296;  Tupi.TECLA_F8=297;  Tupi.TECLA_F9=298
Tupi.TECLA_F10=299; Tupi.TECLA_F11=300; Tupi.TECLA_F12=301

Tupi.MOUSE_ESQ=0; Tupi.MOUSE_DIR=1; Tupi.MOUSE_MEIO=2

-- ============================================================
-- TECLADO / MOUSE
-- ============================================================

function Tupi.teclaPressionou(t) return C.tupi_tecla_pressionou(t) == 1 end
function Tupi.teclaSegurando(t)  return C.tupi_tecla_segurando(t)  == 1 end
function Tupi.teclaSoltou(t)     return C.tupi_tecla_soltou(t)     == 1 end

function Tupi.mouseX()   return tonumber(C.tupi_mouse_x())  end
function Tupi.mouseY()   return tonumber(C.tupi_mouse_y())  end
function Tupi.mouseDX()  return tonumber(C.tupi_mouse_dx()) end
function Tupi.mouseDY()  return tonumber(C.tupi_mouse_dy()) end
function Tupi.mousePos() return tonumber(C.tupi_mouse_x()), tonumber(C.tupi_mouse_y()) end

function Tupi.mouseClicou(b)    return C.tupi_mouse_clicou(b    or 0) == 1 end
function Tupi.mouseSegurando(b) return C.tupi_mouse_segurando(b or 0) == 1 end
function Tupi.mouseSoltou(b)    return C.tupi_mouse_soltou(b    or 0) == 1 end

function Tupi.scrollX() return tonumber(C.tupi_scroll_x()) end
function Tupi.scrollY() return tonumber(C.tupi_scroll_y()) end

-- ============================================================
-- COLISÕES AABB
-- ============================================================

Tupi.col = {}

local function _ret(t) return ffi.new("TupiRetCol",  t.x, t.y, t.largura, t.altura) end
local function _cir(t) return ffi.new("TupiCircCol", t.x, t.y, t.raio)              end
local function _info(c)
    return { colidindo = c.colidindo == 1, dx = tonumber(c.dx), dy = tonumber(c.dy) }
end

function Tupi.col.retRet(a, b)        return C.tupi_ret_ret(_ret(a), _ret(b)) == 1             end
function Tupi.col.retRetInfo(a, b)    return _info(C.tupi_ret_ret_info(_ret(a), _ret(b)))       end
function Tupi.col.cirCir(a, b)        return C.tupi_cir_cir(_cir(a), _cir(b)) == 1             end
function Tupi.col.cirCirInfo(a, b)    return _info(C.tupi_cir_cir_info(_cir(a), _cir(b)))       end
function Tupi.col.retCir(r, c)        return C.tupi_ret_cir(_ret(r), _cir(c)) == 1             end
function Tupi.col.pontoRet(px, py, r) return C.tupi_ponto_ret(px, py, _ret(r)) == 1            end
function Tupi.col.pontoCir(px, py, c) return C.tupi_ponto_cir(px, py, _cir(c)) == 1            end
function Tupi.col.mouseNoRet(r)       return Tupi.col.pontoRet(Tupi.mouseX(), Tupi.mouseY(), r) end
function Tupi.col.mouseNoCir(c)       return Tupi.col.pontoCir(Tupi.mouseX(), Tupi.mouseY(), c) end

-- ============================================================
-- SPRITES
-- ============================================================

--- Carrega uma imagem na GPU. Lança erro se falhar.
-- @param caminho  string — caminho do arquivo (PNG, JPEG, BMP)
-- @return         ponteiro TupiSprite*
function Tupi.carregarSprite(caminho)
    assert(type(caminho) == "string", "[TupiEngine] carregarSprite: caminho deve ser string")
    local spr = C.tupi_sprite_carregar(caminho)
    if spr == nil then
        error("[TupiEngine] carregarSprite: não foi possível carregar '" .. caminho .. "'")
    end
    return spr
end

--- Libera um sprite da GPU.
function Tupi.destruirSprite(spr)
    if spr ~= nil then C.tupi_sprite_destruir(spr) end
end

--- Cria um objeto para exibir um sprite ou sprite sheet na tela.
--
-- @param x             posição X inicial (pixels, canto superior esquerdo)
-- @param y             posição Y inicial (pixels, canto superior esquerdo)
-- @param largura       largura de cada célula do sprite sheet em pixels
-- @param altura        altura de cada célula em pixels
-- @param sprite        ponteiro TupiSprite* retornado por carregarSprite()
-- @param transparencia (opcional) 0.0 invisível … 1.0 opaco — padrão 1.0
-- @param escala        (opcional) fator de escala — padrão 1.0
-- @return              cdata TupiObjeto[1]
--
-- Exemplo:
--   local player = Tupi.criarObjeto(100, 200, 32, 32, sprite)
--   local boss   = Tupi.criarObjeto(400, 100, 64, 64, sprite, 0.9, 2.0)
function Tupi.criarObjeto(x, y, largura, altura, wx, hy, transparencia, escala, sprite)
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
    return obj
end

--- Desenha um objeto imediatamente (sem batch).
function Tupi.desenharObjeto(obj)
    C.tupi_objeto_desenhar(obj)
end

--- Enfileira o objeto no batch (use batchDesenhar() ao final do frame).
function Tupi.enviarBatch(obj, z)
    C.tupi_objeto_enviar_batch(obj, z or 0)
end

--- Dispara todos os draw calls acumulados no batch.
function Tupi.batchDesenhar()
    C.tupi_batch_desenhar()
end

-- ============================================================
-- ANIMAÇÕES (sprite sheet por coluna/linha)
-- ============================================================

local _animEstado   = {}
local _animContador = 0

local function _chaveAnim(anim, objeto)
    return tostring(anim._id) .. ":" .. tostring(ffi.cast("void*", objeto))
end

local function _pegarEstado(anim, objeto)
    local chave = _chaveAnim(anim, objeto)
    if not _animEstado[chave] then
        _animEstado[chave] = { frame = 0, tempo = 0.0, terminado = false }
    end
    return _animEstado[chave]
end

function Tupi.criarAnim(sprite, largura, altura, colunas, linhas, fps, loop)
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

function Tupi.tocarAnim(anim, objeto)
    assert(anim and anim._pares, "[Anim] tocarAnim: anim inválida")

    local estado = _pegarEstado(anim, objeto)
    local total  = #anim._pares

    if not estado.terminado then
        estado.tempo = estado.tempo + Tupi.dt()
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
    objeto[0].coluna = par.col
    objeto[0].linha  = par.linha
    C.tupi_objeto_enviar_batch(objeto, 0)
end

function Tupi.pararAnim(anim, objeto, frame)
    assert(anim and anim._pares, "[Anim] pararAnim: anim inválida")
    local chave = _chaveAnim(anim, objeto)
    _animEstado[chave] = nil
    local idx = math.min(frame or 0, #anim._pares - 1)
    local par = anim._pares[idx + 1]
    objeto[0].coluna = par.col
    objeto[0].linha  = par.linha
    C.tupi_objeto_enviar_batch(objeto, 0)
end

function Tupi.animTerminou(anim, objeto)
    local estado = _animEstado[_chaveAnim(anim, objeto)]
    return estado ~= nil and estado.terminado
end

function Tupi.animReiniciar(anim, objeto)
    _animEstado[_chaveAnim(anim, objeto)] = nil
end

function Tupi.animLimparObjeto(objeto)
    local sufixo = ":" .. tostring(ffi.cast("void*", objeto))
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

function Tupi.mover(dx, dy, objeto)
    objeto[0].x = objeto[0].x + (dx or 0)
    objeto[0].y = objeto[0].y + (dy or 0)
end

function Tupi.teleportar(x, y, objeto)
    objeto[0].x = x or objeto[0].x
    objeto[0].y = y or objeto[0].y
end

function Tupi.salvarPosicao(objeto)
    local id = tostring(ffi.cast("void*", objeto))
    _posicoes_salvas[id] = { x = tonumber(objeto[0].x), y = tonumber(objeto[0].y) }
end

function Tupi.posicaoAtual(objeto)
    return tonumber(objeto[0].x), tonumber(objeto[0].y)
end

function Tupi.ultimaPosicao(objeto)
    local p = _posicoes_salvas[tostring(ffi.cast("void*", objeto))]
    if not p then return nil, nil end
    return p.x, p.y
end

function Tupi.voltarPosicao(objeto)
    local p = _posicoes_salvas[tostring(ffi.cast("void*", objeto))]
    if not p then return end
    objeto[0].x = p.x
    objeto[0].y = p.y
end

function Tupi.distanciaObjetos(a, b)
    local dx = tonumber(b[0].x) - tonumber(a[0].x)
    local dy = tonumber(b[0].y) - tonumber(a[0].y)
    return math.sqrt(dx * dx + dy * dy)
end

function Tupi.moverParaAlvo(tx, ty, fator, objeto)
    fator       = fator or 0.1
    objeto[0].x = objeto[0].x + (tx - objeto[0].x) * fator
    objeto[0].y = objeto[0].y + (ty - objeto[0].y) * fator
end

function Tupi.perseguir(alvo, vel, objeto)
    local dx   = tonumber(alvo[0].x) - tonumber(objeto[0].x)
    local dy   = tonumber(alvo[0].y) - tonumber(objeto[0].y)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then return end
    objeto[0].x = objeto[0].x + (dx / dist) * vel
    objeto[0].y = objeto[0].y + (dy / dist) * vel
end

-- ============================================================
-- HITBOX
-- ============================================================

function Tupi.hitbox(objeto, x, y, w, h, escalar)
    local ox    = tonumber(objeto[0].x)
    local oy    = tonumber(objeto[0].y)
    local fator = 1.0
    if escalar ~= false then
        local ok, e = pcall(function() return tonumber(objeto[0].escala) end)
        if ok and e and e > 0 then fator = e end
    end
    return { x = ox + x * fator, y = oy + y * fator,
             largura = w * fator, altura = h * fator }
end

function Tupi.hitboxFixa(objeto, x, y, w, h)
    return Tupi.hitbox(objeto, x, y, w, h, false)
end

function Tupi.hitboxDesenhar(hb, cor, espessura)
    cor = cor or {0, 1, 0, 0.6}
    local restaurar = _aplicarCor(cor)
    C.tupi_retangulo_borda(hb.x, hb.y, hb.largura, hb.altura, espessura or 1.0)
    restaurar()
end

-- ============================================================
-- CÂMERA 2D
-- ============================================================

Tupi.camera = {}

--- Reposiciona a câmera para o estado inicial (centro 0,0 | zoom 1 | sem rotação).
function Tupi.camera.reset()
    C.tupi_camera_reset()
end

--- Define a posição do centro da câmera no espaço do mundo.
-- @param x  número — coordenada horizontal
-- @param y  número — coordenada vertical
function Tupi.camera.pos(x, y)
    C.tupi_camera_pos(x or 0, y or 0)
end

--- Move a câmera relativamente à posição atual.
function Tupi.camera.mover(dx, dy)
    C.tupi_camera_mover(dx or 0, dy or 0)
end

--- Define o fator de zoom (1.0 = normal | 2.0 = 2× aproximado | 0.5 = afastado).
function Tupi.camera.zoom(z)
    C.tupi_camera_zoom(z or 1)
end

--- Define a rotação em radianos. Use Tupi.rad() para converter de graus.
function Tupi.camera.rotacao(angulo)
    C.tupi_camera_rotacao(angulo or 0)
end

--- Faz a câmera seguir suavemente um ponto (lerp exponencial).
-- @param x, y       alvo no mundo
-- @param velocidade fator 0–1 (padrão 0.1 — suave; 1.0 = imediato)
function Tupi.camera.seguir(x, y, velocidade)
    C.tupi_camera_seguir(x or 0, y or 0, velocidade or 0.1, Tupi.dt())
end

--- Retorna a posição atual da câmera (x, y).
function Tupi.camera.posAtual()
    return tonumber(C.tupi_camera_get_x()),
           tonumber(C.tupi_camera_get_y())
end

--- Retorna o zoom atual.
function Tupi.camera.zoomAtual()
    return tonumber(C.tupi_camera_get_zoom())
end

--- Retorna a rotação atual em radianos.
function Tupi.camera.rotacaoAtual()
    return tonumber(C.tupi_camera_get_rotacao())
end

--- Converte posição de tela (pixels) → coordenada no mundo.
-- Útil para saber onde o mouse está no espaço do jogo.
function Tupi.camera.telaMundo(sx, sy)
    local wx = ffi.new("float[1]")
    local wy = ffi.new("float[1]")
    C.tupi_camera_tela_mundo_lua(sx, sy, wx, wy)
    return tonumber(wx[0]), tonumber(wy[0])
end

--- Converte coordenada do mundo → posição na tela (pixels).
function Tupi.camera.mundoTela(wx, wy)
    local sx = ffi.new("float[1]")
    local sy = ffi.new("float[1]")
    C.tupi_camera_mundo_tela_lua(wx, wy, sx, sy)
    return tonumber(sx[0]), tonumber(sy[0])
end

--- Posição do mouse em coordenadas do mundo.
function Tupi.camera.mouseMundo()
    return Tupi.camera.telaMundo(Tupi.mouseX(), Tupi.mouseY())
end

return Tupi