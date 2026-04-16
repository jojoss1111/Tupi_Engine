-- mapas.lua — TupiEngine · Sistema de Tilemap (multi-mapa)


local ffi = require("ffi")
local bit = require("bit")
local C   = require("src.Engine.engineffi")

-- Registra as structs C (ignora se já foram registradas)
pcall(ffi.cdef, [[
    typedef struct {
        int      numero;
        uint8_t  flags;
        int      largura;
        int      altura;
        int      num_frames;
        struct { int coluna; int linha; } frames[32];
        float    fps;
        int      loop;
        float    alpha;
        float    escala;
        int      z_index;
    } TupiTileDef;

    typedef struct {
        uint8_t  def_id;
        uint8_t  _pad[3];
        float    tempo;
        int      frame;
    } TupiTile;

    typedef struct {
        unsigned int textura_id;
        int          atlas_larg;
        int          atlas_alt;
        int          colunas;
        int          linhas;
        TupiTile    *celulas;
        int          num_defs;
        TupiTileDef  defs[256];
        int          valido;
    } TupiMapa;

    typedef struct {
        int  ok;
        int  num_erros;
        char mensagem[512];
    } TupiMapaValidacao;

    typedef struct {
        float x, y, largura, altura;
        int   flags;
    } TupiTileHitbox;

    TupiMapa      *tupi_mapa_criar        (int colunas, int linhas);
    void           tupi_mapa_destruir     (TupiMapa *mapa);
    void           tupi_mapa_set_atlas    (TupiMapa *mapa, unsigned int tex_id, int larg, int alt);
    int tupi_mapa_registrar_def(TupiMapa *mapa, const TupiTileDef *def);
    void           tupi_mapa_set_grade    (TupiMapa *mapa, const uint8_t *ids, int n);
    void           tupi_mapa_atualizar    (TupiMapa *mapa, float dt);
    void           tupi_mapa_desenhar     (TupiMapa *mapa, int z_base);
    TupiTileHitbox tupi_mapa_hitbox_tile  (const TupiMapa *mapa, int col, int lin);
    int            tupi_mapa_tile_em_ponto(const TupiMapa *mapa, float px, float py);
    int            tupi_mapa_flags_tile   (const TupiMapa *mapa, int col, int lin);
    int            tupi_mapa_validar      (TupiMapa *mapa, TupiMapaValidacao *out);
]])

-- Flags (espelham Mapas.h)
local SOLIDO   = 0x01
local PASSAGEM = 0x02
local TRIGGER  = 0x04
local ANIMADO  = 0x08

-- ---------------------------------------------------------------------------
-- Construtor de instância
-- ---------------------------------------------------------------------------

local InstanciaMapaMeta = {}
InstanciaMapaMeta.__index = InstanciaMapaMeta

local function normalizarOpcoesTile(colide_ou_opts, z, alpha, escala)
    local opts = {}

    if type(colide_ou_opts) == "table" then
        opts.colide   = not not (colide_ou_opts.colide or colide_ou_opts.solido)
        opts.passagem = not not colide_ou_opts.passagem
        opts.trigger  = not not colide_ou_opts.trigger
        opts.z        = tonumber(colide_ou_opts.z) or 0
        opts.alpha    = tonumber(colide_ou_opts.alpha) or 1.0
        opts.escala   = tonumber(colide_ou_opts.escala) or 1.0
    else
        opts.colide   = not not colide_ou_opts
        opts.passagem = false
        opts.trigger  = false
        opts.z        = tonumber(z) or 0
        opts.alpha    = tonumber(alpha) or 1.0
        opts.escala   = tonumber(escala) or 1.0
    end

    if opts.alpha < 0 then opts.alpha = 0 end
    if opts.alpha > 1 then opts.alpha = 1 end
    if opts.escala <= 0 then opts.escala = 1.0 end

    return opts
end

--- Cria uma nova instância de mapa, independente das demais.
local function novaInstancia()
    return setmetatable({
        _larg_tile  = 0,
        _alt_tile   = 0,
        _colunas    = 0,
        _linhas     = 0,
        _atlas_path = nil,
        _atlas_spr  = nil,
        _mapa_c     = nil,
        _valido     = false,
        _array      = nil,
        _tiles      = {},
        -- _aliases[numero_alias] = numero_pai
        -- Aliases herdam flags/colisão/z/alpha/escala do tile pai.
        -- Apenas o sprite (coluna, linha, frames) é diferente.
        _aliases    = {},
    }, InstanciaMapaMeta)
end

-- ---------------------------------------------------------------------------
-- Configuração
-- ---------------------------------------------------------------------------

--- Define as dimensões do mapa e de cada tile.
-- @param larg_mapa  colunas (tiles)
-- @param alt_mapa   linhas (tiles)
-- @param larg_tile  largura do tile em px
-- @param alt_tile   altura do tile em px
function InstanciaMapaMeta:criarMapa(larg_mapa, alt_mapa, larg_tile, alt_tile)
    assert(larg_mapa > 0 and alt_mapa > 0, "[Mapa] criarMapa: dimensões devem ser > 0")
    assert(larg_tile > 0 and alt_tile > 0, "[Mapa] criarMapa: tamanho do tile deve ser > 0")
    self._colunas   = larg_mapa
    self._linhas    = alt_mapa
    self._larg_tile = larg_tile
    self._alt_tile  = alt_tile
    self._tiles     = {}
    self._aliases   = {}
    self._valido    = false
    self._mapa_c    = nil
end

--- Define o atlas (spritesheet PNG com todos os tiles).
-- @param caminho  ex: "assets/tiles.png"
function InstanciaMapaMeta:atlas(caminho)
    assert(type(caminho) == "string", "[Mapa] atlas: caminho deve ser string")
    self._atlas_path = caminho
end

-- ---------------------------------------------------------------------------
-- Definição de tiles
-- ---------------------------------------------------------------------------

--- Tile estático.
-- @param numero  id usado no array (> 0)
-- @param coluna  coluna do tile no atlas (0-based)
-- @param linha   linha do tile no atlas (0-based)
-- @param colide  true = sólido; também aceita tabela:
--                { colide=true, passagem=false, trigger=false, z=0, alpha=1.0, escala=1.0 }
-- @param z       profundidade (padrão 0)
-- @param alpha   0.0–1.0 (padrão 1.0)
-- @param escala  escala (padrão 1.0)
function InstanciaMapaMeta:criarTile(numero, coluna, linha, colide, z, alpha, escala)
    assert(type(numero) == "number" and numero > 0, "[Mapa] criarTile: numero deve ser inteiro > 0")
    assert(type(coluna) == "number",                "[Mapa] criarTile: coluna deve ser número")
    assert(type(linha)  == "number",                "[Mapa] criarTile: linha deve ser número")

    local opts = normalizarOpcoesTile(colide, z, alpha, escala)
    local flags = 0
    if opts.colide   then flags = bit.bor(flags, SOLIDO) end
    if opts.passagem then flags = bit.bor(flags, PASSAGEM) end
    if opts.trigger  then flags = bit.bor(flags, TRIGGER) end

    local def = {
        _numero  = numero,
        _flags   = flags,
        _larg    = self._larg_tile,
        _alt     = self._alt_tile,
        _frames  = { { coluna = coluna, linha = linha } },
        _fps     = 0,
        _loop    = false,
        _z       = opts.z,
        _alpha   = opts.alpha,
        _escala  = opts.escala,
        _id_c    = nil,
    }
    self._tiles[numero] = def
    return def
end

--- Tile animado.
-- @param numero    id no array (> 0)
-- @param colunas_t tabela com colunas dos frames ex: {0, 1, 2}
-- @param linhas_t  tabela com linhas dos frames ex: {0}
-- @param fps       frames por segundo (> 0)
-- @param loop      true = repete (padrão true)
-- @param colide    true = sólido; também aceita tabela:
--                  { colide=true, passagem=false, trigger=false, z=0, alpha=1.0, escala=1.0 }
-- @param z         profundidade (padrão 0)
-- @param alpha     0.0–1.0 (padrão 1.0)
-- @param escala    escala (padrão 1.0)
function InstanciaMapaMeta:criarTileAnim(numero, colunas_t, linhas_t, fps, loop, colide, z, alpha, escala)
    assert(type(numero)    == "number" and numero > 0,     "[Mapa] criarTileAnim: numero deve ser > 0")
    assert(type(colunas_t) == "table"  and #colunas_t > 0, "[Mapa] criarTileAnim: colunas deve ser tabela não vazia")
    assert(type(linhas_t)  == "table"  and #linhas_t  > 0, "[Mapa] criarTileAnim: linhas deve ser tabela não vazia")
    assert(type(fps)       == "number" and fps > 0,         "[Mapa] criarTileAnim: fps deve ser > 0")

    local frames = {}
    for _, lin in ipairs(linhas_t) do
        for _, col in ipairs(colunas_t) do
            table.insert(frames, { coluna = col, linha = lin })
        end
    end

    local opts = normalizarOpcoesTile(colide, z, alpha, escala)
    local flags = ANIMADO
    if opts.colide   then flags = bit.bor(flags, SOLIDO) end
    if opts.passagem then flags = bit.bor(flags, PASSAGEM) end
    if opts.trigger  then flags = bit.bor(flags, TRIGGER) end

    local def = {
        _numero  = numero,
        _flags   = flags,
        _larg    = self._larg_tile,
        _alt     = self._alt_tile,
        _frames  = frames,
        _fps     = fps,
        _loop    = (loop == nil) and true or loop,
        _z       = opts.z,
        _alpha   = opts.alpha,
        _escala  = opts.escala,
        _id_c    = nil,
    }
    self._tiles[numero] = def
    return def
end

-- ---------------------------------------------------------------------------
-- Variantes de tile (mesmo numero logico, sprite diferente)
-- ---------------------------------------------------------------------------

--- Cria uma variante estatica de um tile ja existente.
--
-- O alias tera um numero unico na grade, mas herdara automaticamente todas as
-- propriedades de comportamento do tile pai: flags (colide, passagem, trigger),
-- z, alpha e escala. Apenas o visual (coluna/linha no atlas) e diferente.
--
-- Exemplo de uso: muros em 4 direcoes, todos solidos, cada um com sprite diferente.
--   local muro = mapa:criarTile(1, 0, 0, { colide=true })
--   mapa:varianteTile(2, 1, 1, 0)  -- direcao direita
--   mapa:varianteTile(3, 1, 2, 0)  -- direcao baixo
--   mapa:varianteTile(4, 1, 3, 0)  -- direcao esquerda
--
-- @param numero_alias  id unico para esta variante (> 0, diferente do pai)
-- @param numero_pai    id do tile cujas flags/colisao serao herdadas
-- @param coluna        coluna do sprite no atlas (0-based)
-- @param linha         linha do sprite no atlas (0-based)
-- @return              a definicao criada
function InstanciaMapaMeta:varianteTile(numero_alias, numero_pai, coluna, linha)
    assert(type(numero_alias) == "number" and numero_alias > 0,
        "[Mapa] varianteTile: numero_alias deve ser inteiro > 0")
    assert(type(numero_pai) == "number" and numero_pai > 0,
        "[Mapa] varianteTile: numero_pai deve ser inteiro > 0")
    assert(type(coluna) == "number", "[Mapa] varianteTile: coluna deve ser numero")
    assert(type(linha)  == "number", "[Mapa] varianteTile: linha deve ser numero")
    assert(numero_alias ~= numero_pai,
        "[Mapa] varianteTile: numero_alias e numero_pai nao podem ser iguais")

    local pai = self._tiles[numero_pai]
    assert(pai, string.format(
        "[Mapa] varianteTile: tile pai #%d nao encontrado — crie-o com :criarTile() antes",
        numero_pai))

    -- Herda tudo do pai, apenas troca os frames visuais
    local def = {
        _numero  = numero_alias,
        _flags   = pai._flags,   -- herda colide/passagem/trigger
        _larg    = pai._larg,
        _alt     = pai._alt,
        _frames  = { { coluna = coluna, linha = linha } },
        _fps     = 0,
        _loop    = false,
        _z       = pai._z,
        _alpha   = pai._alpha,
        _escala  = pai._escala,
        _id_c    = nil,
        _pai     = numero_pai,   -- referencia para debug/editor
    }
    self._tiles[numero_alias]   = def
    self._aliases[numero_alias] = numero_pai
    return def
end

--- Cria uma variante animada de um tile ja existente.
--
-- Igual a varianteTile, mas com multiplos frames de animacao.
-- Herda flags/colisao/z/alpha/escala do pai; fps e loop sao proprios desta variante.
--
-- @param numero_alias  id unico para esta variante (> 0)
-- @param numero_pai    id do tile cujas flags/colisao serao herdadas
-- @param colunas_t     tabela de colunas dos frames, ex: {0, 1, 2}
-- @param linhas_t      tabela de linhas dos frames, ex: {3}
-- @param fps           frames por segundo (> 0)
-- @param loop          true = repete (padrao true)
-- @return              a definicao criada
function InstanciaMapaMeta:varianteTileAnim(numero_alias, numero_pai, colunas_t, linhas_t, fps, loop)
    assert(type(numero_alias) == "number" and numero_alias > 0,
        "[Mapa] varianteTileAnim: numero_alias deve ser inteiro > 0")
    assert(type(numero_pai) == "number" and numero_pai > 0,
        "[Mapa] varianteTileAnim: numero_pai deve ser inteiro > 0")
    assert(numero_alias ~= numero_pai,
        "[Mapa] varianteTileAnim: numero_alias e numero_pai nao podem ser iguais")
    assert(type(colunas_t) == "table" and #colunas_t > 0,
        "[Mapa] varianteTileAnim: colunas_t deve ser tabela nao vazia")
    assert(type(linhas_t)  == "table" and #linhas_t  > 0,
        "[Mapa] varianteTileAnim: linhas_t deve ser tabela nao vazia")
    assert(type(fps) == "number" and fps > 0,
        "[Mapa] varianteTileAnim: fps deve ser > 0")

    local pai = self._tiles[numero_pai]
    assert(pai, string.format(
        "[Mapa] varianteTileAnim: tile pai #%d nao encontrado — crie-o com :criarTile() antes",
        numero_pai))

    local frames = {}
    for _, lin in ipairs(linhas_t) do
        for _, col in ipairs(colunas_t) do
            table.insert(frames, { coluna = col, linha = lin })
        end
    end

    -- Herda flags do pai e adiciona ANIMADO
    local flags = bit.bor(pai._flags, ANIMADO)

    local def = {
        _numero  = numero_alias,
        _flags   = flags,
        _larg    = pai._larg,
        _alt     = pai._alt,
        _frames  = frames,
        _fps     = fps,
        _loop    = (loop == nil) and true or loop,
        _z       = pai._z,
        _alpha   = pai._alpha,
        _escala  = pai._escala,
        _id_c    = nil,
        _pai     = numero_pai,
    }
    self._tiles[numero_alias]   = def
    self._aliases[numero_alias] = numero_pai
    return def
end

--- Retorna o numero_pai de um alias, ou nil se nao for alias.
-- @param numero  id do tile
-- @return        id do pai, ou nil
function InstanciaMapaMeta:getPai(numero)
    return self._aliases[numero]
end

--- Retorna true se o numero dado e uma variante (alias) de outro tile.
function InstanciaMapaMeta:isVariante(numero)
    return self._aliases[numero] ~= nil
end

--- Define o array de tile-ids (linha a linha, esquerda→direita).
-- Use 0 para células vazias.
-- @param arr  tabela Lua com os ids
function InstanciaMapaMeta:carregarArray(arr)
    assert(type(arr) == "table" and #arr > 0, "[Mapa] carregarArray: array inválido")
    self._array = arr
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

--- Finaliza o mapa, valida via Rust e prepara para renderização.
-- Lança erro se qualquer etapa falhar.
function InstanciaMapaMeta:build()
    assert(self._colunas > 0, "[Mapa] build: chame :criarMapa() primeiro")
    assert(self._atlas_path,  "[Mapa] build: chame :atlas() primeiro")
    assert(self._array,       "[Mapa] build: chame :carregarArray() primeiro")
    assert(next(self._tiles), "[Mapa] build: crie ao menos um tile com :criarTile()")

    local total = #self._array
    assert(total == self._colunas * self._linhas,
        string.format("[Mapa] build: array tem %d células, esperava %d (%dx%d)",
            total, self._colunas * self._linhas, self._colunas, self._linhas))

    -- Atlas
    self._atlas_spr = C.tupi_sprite_carregar(self._atlas_path)
    assert(self._atlas_spr ~= nil,
        "[Mapa] build: não foi possível carregar o atlas '" .. self._atlas_path .. "'")

    -- Mapa C
    self._mapa_c = C.tupi_mapa_criar(self._colunas, self._linhas)
    assert(self._mapa_c ~= nil, "[Mapa] build: falha ao criar o mapa (grade muito grande?)")

    C.tupi_mapa_set_atlas(self._mapa_c,
        tonumber(self._atlas_spr.textura),
        tonumber(self._atlas_spr.largura),
        tonumber(self._atlas_spr.altura))

    -- Registra as definições de tile
    local numeros = {}
    for numero in pairs(self._tiles) do
        table.insert(numeros, numero)
    end
    table.sort(numeros)

    for _, numero in ipairs(numeros) do
        local def = self._tiles[numero]
        local cdef = ffi.new("TupiTileDef")
        cdef.numero     = def._numero
        cdef.flags      = def._flags
        cdef.largura    = def._larg
        cdef.altura     = def._alt
        cdef.num_frames = math.min(#def._frames, 32)
        cdef.fps        = def._fps
        cdef.loop       = def._loop and 1 or 0
        cdef.alpha      = def._alpha
        cdef.escala     = def._escala
        cdef.z_index    = def._z

        for i, fr in ipairs(def._frames) do
            if i > 32 then break end
            cdef.frames[i - 1].coluna = fr.coluna
            cdef.frames[i - 1].linha  = fr.linha
        end

        local id_c = C.tupi_mapa_registrar_def(self._mapa_c, cdef)
        assert(id_c >= 0, "[Mapa] build: limite de 255 tipos de tile atingido")
        def._id_c = id_c + 1  -- 0 = vazio na grade; def_id começa em 1
    end

    -- Monta grade de ids para o C
    local ids = ffi.new("uint8_t[?]", total)
    for i, numero in ipairs(self._array) do
        if numero == 0 or numero == nil then
            ids[i - 1] = 0
        else
            local def = self._tiles[numero]
            assert(def, string.format(
                "[Mapa] build: tile id %d no array não foi definido com :criarTile()", numero))
            ids[i - 1] = def._id_c
        end
    end

    C.tupi_mapa_set_grade(self._mapa_c, ids, total)

    -- Validação Rust
    local validacao = ffi.new("TupiMapaValidacao")
    local ok = C.tupi_mapa_validar(self._mapa_c, validacao)
    if ok == 0 then
        C.tupi_mapa_destruir(self._mapa_c)
        self._mapa_c = nil
        error("[Mapa] Validação falhou:\n" .. ffi.string(validacao.mensagem))
    end

    self._valido = true
end

-- ---------------------------------------------------------------------------
-- Runtime
-- ---------------------------------------------------------------------------

--- Avança animações. Chame uma vez por frame.
-- @param dt  delta time
function InstanciaMapaMeta:atualizar(dt)
    if not self._valido then return end
    C.tupi_mapa_atualizar(self._mapa_c, dt or 0)
end

--- Desenha todos os tiles.
-- @param z  camada de profundidade (padrão 0)
function InstanciaMapaMeta:desenhar(z)
    if not self._valido then return end
    C.tupi_mapa_desenhar(self._mapa_c, z or 0)
end

-- ---------------------------------------------------------------------------
-- Colisão e consultas
-- ---------------------------------------------------------------------------

--- Retorna a hitbox do tile em (col, lin) no espaço do mundo, ou nil.
function InstanciaMapaMeta:hitboxTile(col, lin)
    if not self._valido then return nil end
    local hb = C.tupi_mapa_hitbox_tile(self._mapa_c, col, lin)
    return {
        x       = tonumber(hb.x),
        y       = tonumber(hb.y),
        largura = tonumber(hb.largura),
        altura  = tonumber(hb.altura),
        flags   = tonumber(hb.flags),
        solido  = bit.band(hb.flags, SOLIDO)  ~= 0,
        trigger = bit.band(hb.flags, TRIGGER) ~= 0,
    }
end

--- Retorna true se o tile em (col, lin) é sólido.
function InstanciaMapaMeta:isSolido(col, lin)
    if not self._valido then return false end
    return bit.band(C.tupi_mapa_flags_tile(self._mapa_c, col, lin), SOLIDO) ~= 0
end

--- Retorna true se o tile em (col, lin) é trigger.
function InstanciaMapaMeta:isTrigger(col, lin)
    if not self._valido then return false end
    return bit.band(C.tupi_mapa_flags_tile(self._mapa_c, col, lin), TRIGGER) ~= 0
end

--- Retorna o def_id do tile no ponto (px, py) do mundo. 0 = vazio.
function InstanciaMapaMeta:tileEmPonto(px, py)
    if not self._valido then return 0 end
    return tonumber(C.tupi_mapa_tile_em_ponto(self._mapa_c, px, py))
end

--- Libera os recursos nativos desta instância.
function InstanciaMapaMeta:destruir()
    if self._mapa_c then
        C.tupi_mapa_destruir(self._mapa_c)
        self._mapa_c = nil
    end
    if self._atlas_spr then
        C.tupi_sprite_destruir(self._atlas_spr)
        self._atlas_spr = nil
    end
    self._valido = false
end

-- ---------------------------------------------------------------------------
-- Módulo público
-- ---------------------------------------------------------------------------

local Mapa = {}

--- Cria uma nova instância de mapa independente.
-- @return  instância com os métodos :criarMapa, :atlas, :criarTile, etc.
function Mapa.novo()
    return novaInstancia()
end

--- Carrega um arquivo de mapa Lua e retorna a tabela que ele devolve.
-- O arquivo deve retornar uma tabela com as instâncias de mapa, ex:
--   return { fundo = fundo, solido = solido }
-- @param modulo  caminho Lua com pontos, ex: "src.fases.fase1"
-- @return        tabela de instâncias { nome = instancia, ... }
function Mapa.carregar(modulo)
    assert(type(modulo) == "string" and modulo ~= "", "[Mapa] carregar: caminho inválido")
    local resultado = require(modulo)
    assert(type(resultado) == "table",
        "[Mapa] carregar: o arquivo '" .. modulo .. "' deve retornar uma tabela de mapas")
    return resultado
end

return Mapa