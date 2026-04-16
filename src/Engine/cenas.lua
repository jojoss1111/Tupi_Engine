-- cenas.lua — Gerenciador de cenas com pilha, fade, hooks e DSL fluente.
--
-- USO RÁPIDO:
--
--   local Cenas = require("src.Engine.cenas")
--
--   -- Definir cena inline (forma mais simples)
--   Cenas.nova("menu")
--     :init(function() ... end)
--     :update(function() ... end)
--     :draw(function() ... end)
--     :sair(function() ... end)
--
--   -- Ou registrar tabela existente
--   Cenas.registrar("jogo", MinhaTabela)
--
--   -- Iniciar
--   Cenas.trocar("menu")
--
--   -- No loop principal
--   Cenas.update()
--   Cenas.draw()

local C = require("src.Engine.engineffi")

local M = {}

-- ============================================================
-- ESTADO INTERNO
-- ============================================================

local _lista   = {}   -- { [nome] = tabela_de_cena }
local _atual   = nil
local _pilha   = {}
local _fade    = nil

-- ============================================================
-- BUILDER — define cenas de forma fluente
-- ============================================================

--[[
   Exemplo:
     Cenas.nova("gameplay")
       :init(function(nivel) carregarNivel(nivel) end)
       :update(function() player:update() end)
       :draw(function() mapa:draw() end)
       :sair(function() salvarProgresso() end)
]]

local Builder = {}
Builder.__index = Builder

function Builder:init(fn)   self._cena.init   = fn; return self end
function Builder:update(fn) self._cena.update = fn; return self end
function Builder:draw(fn)   self._cena.draw   = fn; return self end
function Builder:sair(fn)   self._cena.sair   = fn; return self end

--- Registra a cena criada com nova().
-- Opcional: encadeie no builder. A cena já fica registrada automaticamente.
function Builder:registrar() return self end

-- ============================================================
-- REGISTRO E CONSULTA
-- ============================================================

--- Cria e registra uma cena com interface fluente (builder).
-- @param nome  string identificadora da cena
-- @return      builder com métodos :init :update :draw :sair
--
-- Exemplo:
--   Cenas.nova("pause")
--     :draw(function() desenharPausa() end)
function M.nova(nome)
    assert(type(nome) == "string", "[Cenas] nova: 'nome' deve ser string")
    local cena = {}
    _lista[nome] = cena
    return setmetatable({ _cena = cena }, Builder)
end

--- Registra uma cena a partir de uma tabela existente.
-- A tabela pode ter: init, update, draw, sair (todos opcionais).
function M.registrar(nome, tabela)
    assert(type(nome)   == "string", "[Cenas] registrar: 'nome' deve ser string")
    assert(type(tabela) == "table",  "[Cenas] registrar: 'tabela' deve ser table")
    _lista[nome] = tabela
end

--- Retorna a tabela da cena ativa (ou nil).
function M.atual()      return _atual end

--- Retorna o nome da cena ativa (ou nil).
function M.nomeAtual()
    for nome, cena in pairs(_lista) do
        if cena == _atual then return nome end
    end
end

--- Retorna true se a cena está registrada.
function M.existe(nome)  return _lista[nome] ~= nil end

--- Retorna a profundidade da pilha (0 = nenhuma cena empurrada).
function M.profundidade() return #_pilha end

-- ============================================================
-- INTERNOS
-- ============================================================

local function _chamar(cena, metodo, ...)
    if cena and cena[metodo] then
        local ok, err = pcall(cena[metodo], ...)
        if not ok then
            error(("[Cenas] Erro em %s(): %s"):format(metodo, tostring(err)), 2)
        end
    end
end

local function _sair_atual()
    _chamar(_atual, "sair")
end

local function _entrar(nome, ...)
    local cena = _lista[nome]
    if not cena then
        error(("[Cenas] Cena não encontrada: '%s'"):format(nome))
    end
    _atual = cena
    _chamar(_atual, "init", ...)
end

-- ============================================================
-- TROCA DE CENAS
-- ============================================================

--- Troca imediatamente para outra cena.
-- Limpa a pilha e chama sair() na atual, depois init() na nova.
-- @param nome   nome da cena de destino
-- @param ...    argumentos extras passados para init()
--
-- Exemplo:
--   Cenas.trocar("gameplay", 1)   -- passa nível 1 para init()
function M.trocar(nome, ...)
    assert(type(nome) == "string", "[Cenas] trocar: 'nome' deve ser string")
    _pilha = {}
    _sair_atual()
    _entrar(nome, ...)
end

--- Troca de cena com efeito de fade (escurece → troca → clareia).
-- Seguro chamar de dentro de update() ou draw().
-- @param nome     nome da cena de destino
-- @param duracao  duração total em segundos (padrão: 0.4)
-- @param ...      argumentos extras passados para init()
--
-- Exemplo:
--   Cenas.trocarComFade("creditos", 0.6)
function M.trocarComFade(nome, duracao, ...)
    assert(type(nome) == "string", "[Cenas] trocarComFade: 'nome' deve ser string")
    if _fade then return end   -- ignora se já tem fade em andamento
    _fade = {
        duracao = duracao or 0.4,
        tempo   = 0.0,
        fase    = "saindo",
        proximo = nome,
        args    = { ... },
    }
end

--- Empurra uma nova cena na pilha sem sair da atual.
-- Útil para menus de pausa, popups, overlays, etc.
-- A cena anterior é suspensa (sem chamar sair()).
-- @param nome  nome da cena a empurrar
-- @param ...   argumentos extras passados para init()
--
-- Exemplo:
--   Cenas.empurrar("pause")
--   -- depois:
--   Cenas.desempilhar()   -- retorna para o jogo
function M.empurrar(nome, ...)
    assert(type(nome) == "string",   "[Cenas] empurrar: 'nome' deve ser string")
    assert(_lista[nome],             "[Cenas] empurrar: cena não encontrada: '" .. nome .. "'")
    table.insert(_pilha, _atual)
    _atual = nil
    _entrar(nome, ...)
end

--- Remove a cena do topo da pilha e retoma a anterior.
-- Chama sair() na cena atual mas NÃO chama init() na cena retomada.
function M.desempilhar()
    assert(#_pilha > 0, "[Cenas] desempilhar: pilha vazia")
    _sair_atual()
    _atual = table.remove(_pilha)
end

--- Substitui a cena no topo sem alterar o restante da pilha.
-- Equivale a desempilhar + empurrar, mas sem acionar sair/init desnecessários.
-- @param nome  nome da nova cena de topo
-- @param ...   argumentos extras passados para init()
function M.substituirTopo(nome, ...)
    assert(type(nome) == "string", "[Cenas] substituirTopo: 'nome' deve ser string")
    assert(_lista[nome],           "[Cenas] substituirTopo: cena não encontrada: '" .. nome .. "'")
    _sair_atual()
    _atual = nil
    _entrar(nome, ...)
end

-- ============================================================
-- LOOP — coloque no loop principal do main.lua
-- ============================================================

--- Atualiza a cena atual e gerencia o fade.
-- Deve ser chamado uma vez por frame, antes de draw().
function M.update()
    local dt = M._getDt and M._getDt() or 0

    -- Gerencia fade
    if _fade then
        local f = _fade
        f.tempo = f.tempo + dt

        if f.fase == "saindo" then
            if f.tempo >= f.duracao * 0.5 then
                _pilha = {}
                _sair_atual()
                _entrar(f.proximo, table.unpack(f.args))
                f.fase  = "entrando"
                f.tempo = 0.0
            end
        elseif f.fase == "entrando" then
            if f.tempo >= f.duracao * 0.5 then
                _fade = nil
            end
        end
    end

    -- Atualiza cena
    _chamar(_atual, "update")
end

--- Desenha a cena atual e o overlay de fade.
-- Deve ser chamado uma vez por frame, após update().
function M.draw()
    _chamar(_atual, "draw")

    -- Overlay de fade
    if _fade then
        local f      = _fade
        local metade = f.duracao * 0.5
        local alpha

        if f.fase == "saindo" then
            alpha = math.min(f.tempo / metade, 1.0)
        else
            alpha = math.max(1.0 - (f.tempo / metade), 0.0)
        end

        local larg, alt = M._getDimensoes and M._getDimensoes() or 800, 600
        C.tupi_cor(0, 0, 0, alpha)
        C.tupi_retangulo(0, 0, larg, alt)
        C.tupi_cor(1, 1, 1, 1)
    end
end

return M