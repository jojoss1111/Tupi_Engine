-- TupiEngine.lua
-- TupiEngine - API Principal em Lua
-- Essa é a interface que o programador usa para criar jogos

local C = require("src.Engine.engineffi")

-- ============================================================
-- MÓDULO TUPI
-- ============================================================

local Tupi = {}

-- ============================================================
-- JANELA
-- ============================================================

--- Cria e abre a janela do jogo
--- @param largura number  Largura em pixels (padrão: 800)
--- @param altura  number  Altura em pixels  (padrão: 600)
--- @param titulo  string  Título da janela  (padrão: "TupiEngine")
function Tupi.janela(largura, altura, titulo)
    largura = largura or 800
    altura  = altura  or 600
    titulo  = titulo  or "TupiEngine"
    local ok = C.tupi_janela_criar(largura, altura, titulo)
    if ok == 0 then
        error("[TupiEngine] Falha ao criar janela!")
    end
end

--- Retorna true enquanto a janela estiver aberta
function Tupi.rodando()
    return C.tupi_janela_aberta() == 1
end

--- Limpa a tela (chamar no início de cada frame)
function Tupi.limpar()
    C.tupi_janela_limpar()
end

--- Atualiza a tela e processa eventos (chamar no fim de cada frame)
function Tupi.atualizar()
    C.tupi_janela_atualizar()
end

--- Fecha a janela e encerra o engine
function Tupi.fechar()
    C.tupi_janela_fechar()
end

--- Retorna o tempo em segundos desde o início
function Tupi.tempo()
    return tonumber(C.tupi_tempo())
end

--- Retorna o delta time (tempo entre o frame anterior e o atual)
function Tupi.dt()
    return tonumber(C.tupi_delta_tempo())
end

--- Retorna a largura atual da janela
function Tupi.largura()
    return C.tupi_janela_largura()
end

--- Retorna a altura atual da janela
function Tupi.altura()
    return C.tupi_janela_altura()
end

-- ============================================================
-- COR
-- ============================================================

--- Define a cor de fundo da tela
--- Valores de 0.0 a 1.0
function Tupi.corFundo(r, g, b)
    C.tupi_cor_fundo(r or 0, g or 0, b or 0)
end

--- Define a cor atual de desenho (afeta todas as formas seguintes)
--- Valores de 0.0 a 1.0 (a = transparência, padrão 1.0)
function Tupi.cor(r, g, b, a)
    C.tupi_cor(r or 1, g or 1, b or 1, a or 1)
end

-- Cores prontas para facilitar
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

--- Atalho para usar uma tabela de cor: Tupi.usarCor(Tupi.VERMELHO)
function Tupi.usarCor(tabCor, a)
    C.tupi_cor(tabCor[1], tabCor[2], tabCor[3], a or tabCor[4] or 1)
end

-- ============================================================
-- HELPER INTERNO DE COR
-- ============================================================
-- Aplica cor temporariamente se passada, e restaura a cor
-- padrão (branco) depois. Aceita:
--   tabela  → {r, g, b}  ou  {r, g, b, a}
--   nil     → não muda nada (usa a cor definida antes)
--
-- Uso interno: local restaurar = _aplicarCor(cor)  →  restaurar()

local function _aplicarCor(cor)
    if cor == nil then
        return function() end  -- não faz nada, sem overhead
    end
    C.tupi_cor(cor[1] or 1, cor[2] or 1, cor[3] or 1, cor[4] or 1)
    return function()
        -- Restaura para branco opaco (estado neutro padrão)
        C.tupi_cor(1, 1, 1, 1)
    end
end

-- ============================================================
-- FORMAS 2D
-- ============================================================
-- Todas as funções aceitam um parâmetro opcional `cor` no final.
-- `cor` pode ser uma tabela {r,g,b} ou {r,g,b,a}, ou nil.
--
-- Exemplos válidos:
--   Tupi.retangulo(x, y, 100, 50)                  → usa cor atual
--   Tupi.retangulo(x, y, 100, 50, Tupi.VERMELHO)   → vermelho só nessa forma
--   Tupi.retangulo(x, y, 100, 50, {0.2, 0.8, 1})   → cor customizada inline
--   Tupi.retangulo(x, y, 100, 50, {0, 1, 0, 0.5})  → verde semitransparente

--- Desenha um retângulo preenchido
--- @param x      number  Canto superior esquerdo X
--- @param y      number  Canto superior esquerdo Y
--- @param largura number Largura em pixels
--- @param altura  number Altura em pixels
--- @param cor    table?  {r,g,b} ou {r,g,b,a} — opcional
function Tupi.retangulo(x, y, largura, altura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_retangulo(x, y, largura, altura)
    restaurar()
end

--- Desenha apenas a borda de um retângulo
--- @param espessura number? Espessura da borda (padrão: 1)
--- @param cor       table?  {r,g,b} ou {r,g,b,a} — opcional
function Tupi.retanguloBorda(x, y, largura, altura, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_retangulo_borda(x, y, largura, altura, espessura or 1)
    restaurar()
end

--- Desenha um triângulo preenchido com 3 vértices
--- @param cor table? {r,g,b} ou {r,g,b,a} — opcional
function Tupi.triangulo(x1, y1, x2, y2, x3, y3, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_triangulo(x1, y1, x2, y2, x3, y3)
    restaurar()
end

--- Desenha um círculo preenchido
--- @param x         number  Centro X
--- @param y         number  Centro Y
--- @param raio      number  Raio em pixels
--- @param segmentos number? Suavidade (padrão: 64)
--- @param cor       table?  {r,g,b} ou {r,g,b,a} — opcional
function Tupi.circulo(x, y, raio, segmentos, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_circulo(x, y, raio, segmentos or 64)
    restaurar()
end

--- Desenha apenas a borda de um círculo
--- @param segmentos number? Suavidade (padrão: 64)
--- @param espessura number? Espessura da borda (padrão: 1)
--- @param cor       table?  {r,g,b} ou {r,g,b,a} — opcional
function Tupi.circuloBorda(x, y, raio, segmentos, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_circulo_borda(x, y, raio, segmentos or 64, espessura or 1)
    restaurar()
end

--- Desenha uma linha entre dois pontos
--- @param espessura number? Espessura (padrão: 1)
--- @param cor       table?  {r,g,b} ou {r,g,b,a} — opcional
function Tupi.linha(x1, y1, x2, y2, espessura, cor)
    local restaurar = _aplicarCor(cor)
    C.tupi_linha(x1, y1, x2, y2, espessura or 1)
    restaurar()
end

-- ============================================================
-- UTILITÁRIOS MATEMÁTICOS
-- ============================================================

--- Interpolação linear entre dois valores
function Tupi.lerp(a, b, t)
    return a + (b - a) * t
end

--- Retorna um número aleatório entre min e max
function Tupi.aleatorio(min, max)
    return min + math.random() * (max - min)
end

--- Converte graus para radianos
function Tupi.rad(graus)
    return graus * math.pi / 180
end

--- Converte radianos para graus
function Tupi.graus(rad)
    return rad * 180 / math.pi
end

--- Distância entre dois pontos
function Tupi.distancia(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)
end

-- ============================================================
-- CONSTANTES DE TECLAS (mesmo valor do GLFW / Inputs.h)
-- ============================================================

local T = Tupi

-- Teclas especiais
T.TECLA_ESPACO      = 32
T.TECLA_ENTER       = 257
T.TECLA_TAB         = 258
T.TECLA_BACKSPACE   = 259
T.TECLA_ESC         = 256
T.TECLA_SHIFT_ESQ   = 340
T.TECLA_SHIFT_DIR   = 344
T.TECLA_CTRL_ESQ    = 341
T.TECLA_CTRL_DIR    = 345
T.TECLA_ALT_ESQ     = 342
T.TECLA_ALT_DIR     = 346

-- Setas
T.TECLA_CIMA        = 265
T.TECLA_BAIXO       = 264
T.TECLA_ESQUERDA    = 263
T.TECLA_DIREITA     = 262

-- Letras
T.TECLA_A=65  T.TECLA_B=66  T.TECLA_C=67  T.TECLA_D=68  T.TECLA_E=69
T.TECLA_F=70  T.TECLA_G=71  T.TECLA_H=72  T.TECLA_I=73  T.TECLA_J=74
T.TECLA_K=75  T.TECLA_L=76  T.TECLA_M=77  T.TECLA_N=78  T.TECLA_O=79
T.TECLA_P=80  T.TECLA_Q=81  T.TECLA_R=82  T.TECLA_S=83  T.TECLA_T=84
T.TECLA_U=85  T.TECLA_V=86  T.TECLA_W=87  T.TECLA_X=88  T.TECLA_Y=89
T.TECLA_Z=90

-- Números
T.TECLA_0=48 T.TECLA_1=49 T.TECLA_2=50 T.TECLA_3=51 T.TECLA_4=52
T.TECLA_5=53 T.TECLA_6=54 T.TECLA_7=55 T.TECLA_8=56 T.TECLA_9=57

-- Numpad
T.TECLA_NUM0=320 T.TECLA_NUM1=321 T.TECLA_NUM2=322 T.TECLA_NUM3=323
T.TECLA_NUM4=324 T.TECLA_NUM5=325 T.TECLA_NUM6=326 T.TECLA_NUM7=327
T.TECLA_NUM8=328 T.TECLA_NUM9=329

-- F-Keys
T.TECLA_F1=290  T.TECLA_F2=291  T.TECLA_F3=292  T.TECLA_F4=293
T.TECLA_F5=294  T.TECLA_F6=295  T.TECLA_F7=296  T.TECLA_F8=297
T.TECLA_F9=298  T.TECLA_F10=299 T.TECLA_F11=300 T.TECLA_F12=301

-- Botões do mouse
T.MOUSE_ESQ  = 0
T.MOUSE_DIR  = 1
T.MOUSE_MEIO = 2

-- ============================================================
-- TECLADO
-- ============================================================

--- Retorna true se a tecla foi pressionada NESSE frame (uma vez só)
function Tupi.teclaPressionou(tecla)
    return C.tupi_tecla_pressionou(tecla) == 1
end

--- Retorna true enquanto a tecla estiver sendo segurada
function Tupi.teclaSegurando(tecla)
    return C.tupi_tecla_segurando(tecla) == 1
end

--- Retorna true se a tecla foi solta NESSE frame (uma vez só)
function Tupi.teclaSoltou(tecla)
    return C.tupi_tecla_soltou(tecla) == 1
end

-- ============================================================
-- MOUSE - POSIÇÃO
-- ============================================================

--- Posição X do cursor em pixels
function Tupi.mouseX()
    return tonumber(C.tupi_mouse_x())
end

--- Posição Y do cursor em pixels
function Tupi.mouseY()
    return tonumber(C.tupi_mouse_y())
end

--- Variação X do mouse desde o último frame
function Tupi.mouseDX()
    return tonumber(C.tupi_mouse_dx())
end

--- Variação Y do mouse desde o último frame
function Tupi.mouseDY()
    return tonumber(C.tupi_mouse_dy())
end

--- Retorna posição x, y do mouse de uma vez: local x, y = Tupi.mousePos()
function Tupi.mousePos()
    return tonumber(C.tupi_mouse_x()), tonumber(C.tupi_mouse_y())
end

-- ============================================================
-- MOUSE - BOTÕES
-- ============================================================

--- Retorna true se o botão foi clicado NESSE frame
--- botao: Tupi.MOUSE_ESQ | Tupi.MOUSE_DIR | Tupi.MOUSE_MEIO
function Tupi.mouseClicou(botao)
    return C.tupi_mouse_clicou(botao or 0) == 1
end

--- Retorna true enquanto o botão estiver pressionado
function Tupi.mouseSegurando(botao)
    return C.tupi_mouse_segurando(botao or 0) == 1
end

--- Retorna true se o botão foi solto NESSE frame
function Tupi.mouseSoltou(botao)
    return C.tupi_mouse_soltou(botao or 0) == 1
end

-- ============================================================
-- SCROLL
-- ============================================================

--- Scroll horizontal desse frame (+direita, -esquerda)
function Tupi.scrollX()
    return tonumber(C.tupi_scroll_x())
end

--- Scroll vertical desse frame (+cima, -baixo)
function Tupi.scrollY()
    return tonumber(C.tupi_scroll_y())
end

-- ============================================================
-- LOOP PRINCIPAL (opcional - alternativa ao loop manual)
-- ============================================================

--- Executa o loop principal do jogo automaticamente
--- @param iniciar  function  Chamada uma vez no início
--- @param atualizar function Chamada todo frame com (dt)
--- @param desenhar  function Chamada todo frame para renderizar
function Tupi.rodar(iniciar, atualizar, desenhar)
    if iniciar then iniciar() end

    while Tupi.rodando() do
        local dt = Tupi.dt()

        Tupi.limpar()

        if atualizar then atualizar(dt) end
        if desenhar  then desenhar()    end

        Tupi.atualizar()
    end

    Tupi.fechar()
end

-- ============================================================

return Tupi