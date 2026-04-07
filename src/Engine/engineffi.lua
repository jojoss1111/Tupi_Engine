-- engineffi.lua
-- TupiEngine - Declarações FFI para o LuaJIT
-- Liga o Lua com as funções C do RendererGL

local ffi = require("ffi")

ffi.cdef[[
    /* ============================
       JANELA
    ============================ */
    int    tupi_janela_criar(int largura, int altura, const char* titulo);
    int    tupi_janela_aberta(void);
    void   tupi_janela_limpar(void);
    void   tupi_janela_atualizar(void);
    void   tupi_janela_fechar(void);
    double tupi_tempo(void);
    double tupi_delta_tempo(void);
    int    tupi_janela_largura(void);
    int    tupi_janela_altura(void);

    /* ============================
       COR
    ============================ */
    void tupi_cor_fundo(float r, float g, float b);
    void tupi_cor(float r, float g, float b, float a);

    /* ============================
       FORMAS 2D
    ============================ */
    void tupi_retangulo(float x, float y, float largura, float altura);
    void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura);
    void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3);
    void tupi_circulo(float x, float y, float raio, int segmentos);
    void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura);
    void tupi_linha(float x1, float y1, float x2, float y2, float espessura);

    /* ============================
       TECLADO
    ============================ */
    int tupi_tecla_pressionou(int tecla);
    int tupi_tecla_segurando(int tecla);
    int tupi_tecla_soltou(int tecla);

    /* ============================
       MOUSE - POSIÇÃO
    ============================ */
    double tupi_mouse_x(void);
    double tupi_mouse_y(void);
    double tupi_mouse_dx(void);
    double tupi_mouse_dy(void);

    /* ============================
       MOUSE - BOTÕES
    ============================ */
    int tupi_mouse_clicou(int botao);
    int tupi_mouse_segurando(int botao);
    int tupi_mouse_soltou(int botao);

    /* ============================
       SCROLL
    ============================ */
    double tupi_scroll_x(void);
    double tupi_scroll_y(void);
]]

-- Carrega a biblioteca compartilhada compilada
local tupiC = ffi.load("./libtupi.so")

return tupiC