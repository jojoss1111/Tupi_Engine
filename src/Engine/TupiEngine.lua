-- TupiEngine.lua — API principal. Edite apenas o main.lua.
-- Os subsistemas ficam em src/Engine/ — este arquivo apenas os compõe.

local Janela  = require("src.Engine.janela")
local Render  = require("src.Engine.render")
local Input   = require("src.Engine.input")
local Colisao = require("src.Engine.colisao")
local Sprite  = require("src.Engine.sprite")
local Camera  = require("src.Engine.camera")
local Fisica  = require("src.Engine.fisica")
local Texto   = require("src.Engine.texto")
local Cenas   = require("src.Engine.cenas")
local Mapa    = require("src.Engine.mapas")

-- ============================================================
-- INJEÇÃO DE DEPENDÊNCIAS CRUZADAS
-- ============================================================

local function _getDt()        return Janela.dt()     end
local function _getLargura()   return Janela.largura() end
local function _getMouse()     return Input.mouseX(), Input.mouseY() end
local function _getDimensoes() return Janela.largura(), Janela.altura() end

Input._getDt          = _getDt
Colisao._getMouse     = _getMouse
Sprite._getDt         = _getDt
Sprite._aplicarCor    = Render._aplicarCor
Sprite._retRet        = Colisao.retRet
Sprite._retRetInfo    = Colisao.retRetInfo
Camera._getDt         = _getDt
Camera._getMouse      = _getMouse
Camera._getLargura    = _getLargura
Fisica._getDt         = _getDt
Cenas._getDt          = _getDt
Cenas._getDimensoes   = _getDimensoes

-- ============================================================
-- TABELA PÚBLICA — Tupi
-- ============================================================

local Tupi = {}

-- Janela & loop
Tupi.janela       = Janela.janela
Tupi.rodando      = Janela.rodando
Tupi.limpar       = Janela.limpar
Tupi.atualizar    = Janela.atualizar
Tupi.apresentar   = Janela.atualizar
Tupi.fechar       = Janela.fechar
Tupi.tempo        = Janela.tempo
Tupi.dt           = Janela.dt
Tupi.largura      = Janela.largura
Tupi.altura       = Janela.altura
Tupi.larguraPx    = Janela.larguraPx
Tupi.alturaPx     = Janela.alturaPx
Tupi.escala       = Janela.escala
Tupi.setTitulo    = Janela.setTitulo
Tupi.setDecoracao = Janela.setDecoracao

Tupi.telaCheia            = Janela.telaCheia

Tupi.telaCheia_letterbox  = Janela.telaCheia_letterbox

--- Retorna true se o modo letterbox estiver ativo.
Tupi.letterboxAtivo       = Janela.letterboxAtivo

-- Utilitários
Tupi.lerp      = Janela.lerp
Tupi.aleatorio = Janela.aleatorio
Tupi.rad       = Janela.rad
Tupi.graus     = Janela.graus
Tupi.distancia = Janela.distancia

-- Render
Tupi.corFundo         = Render.corFundo
Tupi.cor              = Render.cor
Tupi.usarCor          = Render.usarCor
Tupi.retangulo        = Render.retangulo
Tupi.retanguloBorda   = Render.retanguloBorda
Tupi.triangulo        = Render.triangulo
Tupi.circulo          = Render.circulo
Tupi.circuloBorda     = Render.circuloBorda
Tupi.linha            = Render.linha
Tupi.batchDesenhar    = Render.batchDesenhar

-- Cores prontas
Tupi.BRANCO   = Render.BRANCO;   Tupi.PRETO    = Render.PRETO
Tupi.VERMELHO = Render.VERMELHO; Tupi.VERDE    = Render.VERDE
Tupi.AZUL     = Render.AZUL;     Tupi.AMARELO  = Render.AMARELO
Tupi.ROXO     = Render.ROXO;     Tupi.LARANJA  = Render.LARANJA
Tupi.CIANO    = Render.CIANO;    Tupi.CINZA    = Render.CINZA
Tupi.ROSA     = Render.ROSA

-- Input — teclado
Tupi.setTempoSegurando = Input.setTempoSegurando
Tupi.getTempoSegurando = Input.getTempoSegurando
Tupi.teclaPressionou   = Input.teclaPressionou
Tupi.teclaSoltou       = Input.teclaSoltou
Tupi.teclaSegurando    = Input.teclaSegurando

-- Input — mouse
Tupi.mouseX         = Input.mouseX;    Tupi.mouseY         = Input.mouseY
Tupi.mouseDX        = Input.mouseDX;   Tupi.mouseDY        = Input.mouseDY
Tupi.mousePos       = Input.mousePos
Tupi.mouseXRaw      = Input.mouseXRaw; Tupi.mouseYRaw      = Input.mouseYRaw
Tupi.mouseClicou    = Input.mouseClicou
Tupi.mouseSegurando = Input.mouseSegurando
Tupi.mouseSoltou    = Input.mouseSoltou
Tupi.scrollX        = Input.scrollX;   Tupi.scrollY        = Input.scrollY

for k, v in pairs(Input) do
    if type(v) == "number" then Tupi[k] = v end
end

-- Colisão
Tupi.col = Colisao

-- Sprites & objetos
Tupi.carregarSprite       = Sprite.carregarSprite
Tupi.destruirSprite       = Sprite.destruirSprite
Tupi.criarObjeto          = Sprite.criarObjeto
Tupi.desenharObjeto       = Sprite.desenharObjeto
Tupi.desenhar             = Sprite.desenhar
Tupi.espelhar             = Sprite.espelhar
Tupi.getEspelho           = Sprite.getEspelho
Tupi.enviarBatch          = Sprite.enviarBatch

-- Animações
Tupi.criarAnim        = Sprite.criarAnim
Tupi.tocarAnim        = Sprite.tocarAnim
Tupi.pararAnim        = Sprite.pararAnim
Tupi.animTerminou     = Sprite.animTerminou
Tupi.animReiniciar    = Sprite.animReiniciar
Tupi.animLimparObjeto = Sprite.animLimparObjeto

-- Posição
Tupi.mover            = Sprite.mover
Tupi.teleportar       = Sprite.teleportar
Tupi.salvarPosicao    = Sprite.salvarPosicao
Tupi.posicaoAtual     = Sprite.posicaoAtual
Tupi.ultimaPosicao    = Sprite.ultimaPosicao
Tupi.voltarPosicao    = Sprite.voltarPosicao
Tupi.distanciaObjetos = Sprite.distanciaObjetos
Tupi.moverParaAlvo    = Sprite.moverParaAlvo
Tupi.perseguir        = Sprite.perseguir

-- Hitbox
Tupi.hitbox                = Sprite.hitbox
Tupi.hitboxFixa            = Sprite.hitboxFixa
Tupi.hitboxDesenhar        = Sprite.hitboxDesenhar
Tupi.moverComColisao       = Sprite.moverComColisao
Tupi.resolverColisaoSolida = Sprite.resolverColisaoSolida

-- Destruição
Tupi.destruir  = Sprite.destruir
Tupi.destruido = Sprite.destruido

-- ============================================================
-- CÂMERA 2D — sub-tabela completa + aliases flat
-- ============================================================

-- Sub-tabela (acesso OO: Tupi.camera.criar, Tupi.camera.seguir, ...)
Tupi.camera = Camera.camera
Tupi.paralax = Camera.paralax

-- Aliases flat para a câmera — ciclo de vida
Tupi.cameraCriar    = Camera.camera.criar
Tupi.cameraDestruir = Camera.camera.destruir
Tupi.cameraAtivar   = Camera.camera.ativar

-- Aliases flat — movimentação
Tupi.cameraPos      = Camera.camera.pos
Tupi.cameraMover    = Camera.camera.mover
Tupi.cameraZoom     = Camera.camera.zoom
Tupi.cameraRotacao  = Camera.camera.rotacao
Tupi.cameraAncora   = Camera.camera.ancora
Tupi.cameraSeguir   = Camera.camera.seguir

-- Aliases flat — leitura de estado
Tupi.cameraPosAtual     = Camera.camera.posAtual
Tupi.cameraAlvoAtual    = Camera.camera.alvoAtual
Tupi.cameraZoomAtual    = Camera.camera.zoomAtual
Tupi.cameraRotacaoAtual = Camera.camera.rotacaoAtual

-- Aliases flat — conversão de coordenadas
Tupi.cameraTelaMundo = Camera.camera.telaMundo
Tupi.cameraMundoTela = Camera.camera.mundoTela
Tupi.cameraMouseMundo = Camera.camera.mouseMundo

-- ============================================================
-- PARALAXE 2D — sub-tabela completa + aliases flat
-- ============================================================

-- Aliases flat — ciclo de vida e controle
Tupi.paralaxRegistrar     = Camera.paralax.registrar
Tupi.paralaxRemover       = Camera.paralax.remover
Tupi.paralaxAtualizar     = Camera.paralax.atualizar
Tupi.paralaxOffset        = Camera.paralax.offset
Tupi.paralaxDesenhar      = Camera.paralax.desenhar
Tupi.paralaxDesenharTile  = Camera.paralax.desenharTile
Tupi.paralaxResetar       = Camera.paralax.resetar

-- Aliases flat — novos métodos do camera.lua atual
Tupi.paralaxResetarCamada = Camera.paralax.resetarCamada
Tupi.paralaxSetFator      = Camera.paralax.setFator
Tupi.paralaxTotalAtivas   = Camera.paralax.totalAtivas

-- Física
Tupi.fisica = Fisica

-- Texto
Tupi.texto = Texto

-- Cenas
Tupi.cenas = Cenas

-- ============================================================
-- TILEMAP — API multi-mapa
-- ============================================================

Tupi.carregarMapa = Mapa.carregar

--- Avança as animações de uma instância de mapa.
-- @param inst  instância retornada por carregarMapa
-- @param dt    delta time (padrão: Tupi.dt())
function Tupi.atualizarMapa(inst, dt)
    assert(inst and inst.atualizar, "[Tupi] atualizarMapa: instância inválida")
    inst:atualizar(dt or Janela.dt())
end

--- Desenha uma instância de mapa.
-- @param inst  instância retornada por carregarMapa
-- @param z     camada de profundidade (padrão 0)
function Tupi.desenharMapa(inst, z)
    assert(inst and inst.desenhar, "[Tupi] desenharMapa: instância inválida")
    inst:desenhar(z or 0)
end

--- Libera os recursos nativos de uma instância de mapa.
-- @param inst  instância retornada por carregarMapa
function Tupi.destruirMapa(inst)
    if inst and inst.destruir then inst:destruir() end
end

-- Consultas de colisão por instância -----------------------------------------

--- Hitbox do tile em (col, lin) no espaço do mundo.
function Tupi.hitboxTile(inst, col, lin)
    assert(inst and inst.hitboxTile, "[Tupi] hitboxTile: instância inválida")
    return inst:hitboxTile(col, lin)
end

--- Retorna true se o tile em (col, lin) é sólido.
function Tupi.isSolido(inst, col, lin)
    assert(inst and inst.isSolido, "[Tupi] isSolido: instância inválida")
    return inst:isSolido(col, lin)
end

--- Retorna true se o tile em (col, lin) é trigger.
function Tupi.isTrigger(inst, col, lin)
    assert(inst and inst.isTrigger, "[Tupi] isTrigger: instância inválida")
    return inst:isTrigger(col, lin)
end

--- Retorna o def_id do tile que cobre o ponto (px, py) no mundo. 0 = vazio.
function Tupi.tileEmPonto(inst, px, py)
    assert(inst and inst.tileEmPonto, "[Tupi] tileEmPonto: instância inválida")
    return inst:tileEmPonto(px, py)
end

return Tupi