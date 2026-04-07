-- TupiEngine.lua
-- TupiEngine - API principal em Lua
-- Interface que o programador usa para criar jogos

local ffi = require("ffi")
local C   = require("src.Engine.engineffi")

local Tupi = {}

-- ============================================================
-- JANELA
-- ============================================================

function Tupi.janela(largura, altura, titulo)
    largura = largura or 800
    altura  = altura  or 600
    titulo  = titulo  or "TupiEngine"
    if C.tupi_janela_criar(largura, altura, titulo) == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end
end

function Tupi.rodando()   return C.tupi_janela_aberta() == 1 end
function Tupi.limpar()    C.tupi_janela_limpar()             end
function Tupi.atualizar() C.tupi_janela_atualizar()          end
function Tupi.fechar()    C.tupi_janela_fechar()              end

function Tupi.tempo()   return tonumber(C.tupi_tempo())          end
function Tupi.dt()      return tonumber(C.tupi_delta_tempo())    end
function Tupi.largura() return tonumber(C.tupi_janela_largura()) end
function Tupi.altura()  return tonumber(C.tupi_janela_altura())  end

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
-- Todas aceitam uma tabela de cor opcional no último parâmetro:
--   Tupi.retangulo(x, y, 100, 50)                -> usa cor atual
--   Tupi.retangulo(x, y, 100, 50, Tupi.VERMELHO) -> vermelho só aqui
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

function Tupi.lerp(a, b, t)
    return a + (b - a) * t
end

function Tupi.aleatorio(minimo, maximo)
    return minimo + math.random() * (maximo - minimo)
end

function Tupi.rad(graus)
    return graus * math.pi / 180
end

function Tupi.graus(radianos)
    return radianos * 180 / math.pi
end

function Tupi.distancia(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================
-- CONSTANTES DE TECLAS
-- ============================================================

-- Teclas especiais
Tupi.TECLA_ESPACO    = 32
Tupi.TECLA_ENTER     = 257
Tupi.TECLA_TAB       = 258
Tupi.TECLA_BACKSPACE = 259
Tupi.TECLA_ESC       = 256
Tupi.TECLA_SHIFT_ESQ = 340
Tupi.TECLA_SHIFT_DIR = 344
Tupi.TECLA_CTRL_ESQ  = 341
Tupi.TECLA_CTRL_DIR  = 345
Tupi.TECLA_ALT_ESQ   = 342
Tupi.TECLA_ALT_DIR   = 346

-- Setas direcionais
Tupi.TECLA_CIMA     = 265
Tupi.TECLA_BAIXO    = 264
Tupi.TECLA_ESQUERDA = 263
Tupi.TECLA_DIREITA  = 262

-- Letras
Tupi.TECLA_A = 65  Tupi.TECLA_B = 66  Tupi.TECLA_C = 67  Tupi.TECLA_D = 68
Tupi.TECLA_E = 69  Tupi.TECLA_F = 70  Tupi.TECLA_G = 71  Tupi.TECLA_H = 72
Tupi.TECLA_I = 73  Tupi.TECLA_J = 74  Tupi.TECLA_K = 75  Tupi.TECLA_L = 76
Tupi.TECLA_M = 77  Tupi.TECLA_N = 78  Tupi.TECLA_O = 79  Tupi.TECLA_P = 80
Tupi.TECLA_Q = 81  Tupi.TECLA_R = 82  Tupi.TECLA_S = 83  Tupi.TECLA_T = 84
Tupi.TECLA_U = 85  Tupi.TECLA_V = 86  Tupi.TECLA_W = 87  Tupi.TECLA_X = 88
Tupi.TECLA_Y = 89  Tupi.TECLA_Z = 90

-- Números da linha de cima
Tupi.TECLA_0 = 48  Tupi.TECLA_1 = 49  Tupi.TECLA_2 = 50  Tupi.TECLA_3 = 51
Tupi.TECLA_4 = 52  Tupi.TECLA_5 = 53  Tupi.TECLA_6 = 54  Tupi.TECLA_7 = 55
Tupi.TECLA_8 = 56  Tupi.TECLA_9 = 57

-- Numpad
Tupi.TECLA_NUM0 = 320  Tupi.TECLA_NUM1 = 321  Tupi.TECLA_NUM2 = 322
Tupi.TECLA_NUM3 = 323  Tupi.TECLA_NUM4 = 324  Tupi.TECLA_NUM5 = 325
Tupi.TECLA_NUM6 = 326  Tupi.TECLA_NUM7 = 327  Tupi.TECLA_NUM8 = 328
Tupi.TECLA_NUM9 = 329

-- F-Keys
Tupi.TECLA_F1  = 290  Tupi.TECLA_F2  = 291  Tupi.TECLA_F3  = 292
Tupi.TECLA_F4  = 293  Tupi.TECLA_F5  = 294  Tupi.TECLA_F6  = 295
Tupi.TECLA_F7  = 296  Tupi.TECLA_F8  = 297  Tupi.TECLA_F9  = 298
Tupi.TECLA_F10 = 299  Tupi.TECLA_F11 = 300  Tupi.TECLA_F12 = 301

-- Botões do mouse
Tupi.MOUSE_ESQ  = 0
Tupi.MOUSE_DIR  = 1
Tupi.MOUSE_MEIO = 2

-- ============================================================
-- TECLADO
-- ============================================================

function Tupi.teclaPressionou(tecla) return C.tupi_tecla_pressionou(tecla) == 1 end
function Tupi.teclaSegurando(tecla)  return C.tupi_tecla_segurando(tecla)  == 1 end
function Tupi.teclaSoltou(tecla)     return C.tupi_tecla_soltou(tecla)     == 1 end

-- ============================================================
-- MOUSE
-- ============================================================

function Tupi.mouseX()  return tonumber(C.tupi_mouse_x())  end
function Tupi.mouseY()  return tonumber(C.tupi_mouse_y())  end
function Tupi.mouseDX() return tonumber(C.tupi_mouse_dx()) end
function Tupi.mouseDY() return tonumber(C.tupi_mouse_dy()) end

function Tupi.mousePos()
    return tonumber(C.tupi_mouse_x()), tonumber(C.tupi_mouse_y())
end

function Tupi.mouseClicou(botao)    return C.tupi_mouse_clicou(botao    or 0) == 1 end
function Tupi.mouseSegurando(botao) return C.tupi_mouse_segurando(botao  or 0) == 1 end
function Tupi.mouseSoltou(botao)    return C.tupi_mouse_soltou(botao    or 0) == 1 end

function Tupi.scrollX() return tonumber(C.tupi_scroll_x()) end
function Tupi.scrollY() return tonumber(C.tupi_scroll_y()) end

-- ============================================================
-- COLISÕES AABB
-- ============================================================
-- Retangulo: { x, y, largura, altura }
-- Circulo:   { x, y, raio }
--
-- Uso:
--   if Tupi.col.retRet(jogador, parede) then ... end
--
--   local info = Tupi.col.retRetInfo(jogador, parede)
--   if info.colidindo then
--       jogador.x = jogador.x + info.dx
--       jogador.y = jogador.y + info.dy
--   end
-- ============================================================

Tupi.col = {}

local function _ret(t)
    return ffi.new("TupiRetCol", t.x, t.y, t.largura, t.altura)
end

local function _cir(t)
    return ffi.new("TupiCircCol", t.x, t.y, t.raio)
end

local function _info(c)
    return { colidindo = c.colidindo == 1, dx = tonumber(c.dx), dy = tonumber(c.dy) }
end

-- Retangulo vs Retangulo
function Tupi.col.retRet(a, b)     return C.tupi_ret_ret(_ret(a), _ret(b)) == 1        end
function Tupi.col.retRetInfo(a, b) return _info(C.tupi_ret_ret_info(_ret(a), _ret(b))) end

-- Circulo vs Circulo
function Tupi.col.cirCir(a, b)     return C.tupi_cir_cir(_cir(a), _cir(b)) == 1        end
function Tupi.col.cirCirInfo(a, b) return _info(C.tupi_cir_cir_info(_cir(a), _cir(b))) end

-- Retangulo vs Circulo
function Tupi.col.retCir(r, c) return C.tupi_ret_cir(_ret(r), _cir(c)) == 1 end

-- Ponto vs Forma
function Tupi.col.pontoRet(px, py, r) return C.tupi_ponto_ret(px, py, _ret(r)) == 1 end
function Tupi.col.pontoCir(px, py, c) return C.tupi_ponto_cir(px, py, _cir(c)) == 1 end

-- Mouse vs Forma
function Tupi.col.mouseNoRet(r) return Tupi.col.pontoRet(Tupi.mouseX(), Tupi.mouseY(), r) end
function Tupi.col.mouseNoCir(c) return Tupi.col.pontoCir(Tupi.mouseX(), Tupi.mouseY(), c) end

-- ============================================================
-- SPRITES
-- ============================================================
-- Uso basico:
--   local sheet  = Tupi.carregarSprite("assets/player.png")
--   local player = Tupi.criarObjeto(100, 200, 16, 16, 0, 0, 1.0, 3.0, sheet)
--
--   -- No loop:
--   player[0].coluna = 2
--   Tupi.desenharObjeto(player)
--
--   -- Ao sair:
--   Tupi.destruirSprite(sheet)
-- ============================================================

function Tupi.carregarSprite(caminho)
    local spr = C.tupi_sprite_carregar(caminho)
    if spr == nil then
        error("[TupiEngine] Falha ao carregar sprite: " .. caminho)
    end
    return spr
end

function Tupi.destruirSprite(sprite)
    C.tupi_sprite_destruir(sprite)
end

function Tupi.criarObjeto(x, y, largura, altura, coluna, linha, transparencia, escala, imagem)
    local obj = ffi.new("TupiObjeto[1]")
    obj[0] = C.tupi_objeto_criar(
        x, y,
        largura, altura,
        coluna, linha,
        transparencia or 1.0,
        escala        or 1.0,
        imagem
    )
    return obj
end

function Tupi.desenharObjeto(objeto)
    C.tupi_objeto_desenhar(objeto)
end

-- ============================================================
-- POSIÇÃO DE OBJETOS
-- ============================================================
-- Funciona com TupiObjeto (cdata FFI) e tabelas Lua com .x e .y
--
-- Uso tipico com rollback de colisao:
--   Tupi.salvarPosicao(jogador[0])
--   Tupi.mover(velX * dt, velY * dt, jogador[0])
--   if Tupi.col.retRet(jogador[0], parede) then
--       Tupi.voltarPosicao(jogador[0])
--   end
-- ============================================================

local _posicoes_salvas = setmetatable({}, { __mode = "k" })

-- Move o objeto somando ao x/y atual
function Tupi.mover(dx, dy, objeto)
    objeto.x = objeto.x + (dx or 0)
    objeto.y = objeto.y + (dy or 0)
end

-- Teleporta para coordenada absoluta
function Tupi.teleportar(x, y, objeto)
    objeto.x = x or objeto.x
    objeto.y = y or objeto.y
end

-- Salva a posicao atual para poder recuperar depois
function Tupi.salvarPosicao(objeto)
    local id = tostring(ffi.cast("void*", objeto))
    _posicoes_salvas[id] = { x = tonumber(objeto.x), y = tonumber(objeto.y) }
end

-- Retorna x, y da posicao atual
function Tupi.posicaoAtual(objeto)
    return tonumber(objeto.x), tonumber(objeto.y)
end

-- Retorna x, y da ultima posicao salva (nil, nil se nunca salvo)
function Tupi.ultimaPosicao(objeto)
    local p = _posicoes_salvas[objeto]
    if not p then return nil, nil end
    return p.x, p.y
end

-- Volta ao estado salvo com salvarPosicao()
function Tupi.voltarPosicao(objeto)
    local id = tostring(ffi.cast("void*", objeto))
    local p = _posicoes_salvas[id]
    if not p then return end
    objeto.x = p.x
    objeto.y = p.y
end

-- Distancia entre dois objetos
function Tupi.distanciaObjetos(a, b)
    local dx = tonumber(b.x) - tonumber(a.x)
    local dy = tonumber(b.y) - tonumber(a.y)
    return math.sqrt(dx * dx + dy * dy)
end

-- Move suavemente em direcao a um ponto (lerp) — bom para camera
function Tupi.moverParaAlvo(tx, ty, fator, objeto)
    fator = fator or 0.1
    objeto.x = objeto.x + (tx - objeto.x) * fator
    objeto.y = objeto.y + (ty - objeto.y) * fator
end

-- Move em direcao a outro objeto a velocidade fixa — bom para IA
function Tupi.perseguir(alvo, vel, objeto)
    local dx   = tonumber(alvo.x) - tonumber(objeto.x)
    local dy   = tonumber(alvo.y) - tonumber(objeto.y)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then return end
    objeto.x = objeto.x + (dx / dist) * vel
    objeto.y = objeto.y + (dy / dist) * vel
end

return Tupi