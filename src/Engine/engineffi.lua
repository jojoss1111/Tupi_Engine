-- engineffi.lua
-- TupiEngine - Declarações FFI para o LuaJIT
-- Liga o Lua com as funções C do RendererGL, ColisoesAABB, Sprites, Câmera e Física

local ffi = require("ffi")

ffi.cdef[[
    /* ============================
       JANELA — criação
    ============================ */
    int    tupi_janela_criar(int largura, int altura, const char* titulo);
    int    tupi_janela_criar_ex(int largura, int altura, const char* titulo,
                                float escala, int sem_borda, int sem_texto);

    /* ============================
       JANELA — controle runtime
    ============================ */
    void   tupi_janela_set_titulo(const char* titulo);
    void   tupi_janela_set_decoracao(int ativo);
    void   tupi_janela_tela_cheia(int ativo);

    /* ============================
       JANELA — estado e tempo
    ============================ */
    int    tupi_janela_aberta(void);
    void   tupi_janela_limpar(void);
    void   tupi_janela_atualizar(void);
    void   tupi_janela_fechar(void);
    double tupi_tempo(void);
    double tupi_delta_tempo(void);
    int    tupi_janela_largura(void);
    int    tupi_janela_altura(void);
    int    tupi_janela_largura_px(void);
    int    tupi_janela_altura_px(void);
    float  tupi_janela_escala(void);

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

    /* ============================
       COLISÕES AABB
    ============================ */
    typedef struct { float x, y, largura, altura; } TupiRetCol;
    typedef struct { float x, y, raio;             } TupiCircCol;
    typedef struct { int colidindo; float dx, dy;  } TupiColisao;

    int         tupi_ret_ret     (TupiRetCol a, TupiRetCol b);
    TupiColisao tupi_ret_ret_info(TupiRetCol a, TupiRetCol b);
    int         tupi_cir_cir     (TupiCircCol a, TupiCircCol b);
    TupiColisao tupi_cir_cir_info(TupiCircCol a, TupiCircCol b);
    int         tupi_ret_cir     (TupiRetCol r, TupiCircCol c);
    int         tupi_ponto_ret   (float px, float py, TupiRetCol r);
    int         tupi_ponto_cir   (float px, float py, TupiCircCol c);

    /* ============================
       SPRITES
    ============================ */

    typedef struct {
        unsigned int textura;
        int largura;
        int altura;
    } TupiSprite;

    typedef struct {
        float x, y;
        float largura, altura;
        int   coluna, linha;
        float transparencia;
        float escala;
        TupiSprite* imagem;
    } TupiObjeto;

    TupiSprite* tupi_sprite_carregar(const char* caminho);
    void        tupi_sprite_destruir(TupiSprite* sprite);

    TupiObjeto tupi_objeto_criar(
        float x, float y,
        float largura, float altura,
        int coluna, int linha,
        float transparencia,
        float escala,
        TupiSprite* imagem
    );

    void tupi_objeto_desenhar(TupiObjeto* obj);

    /* ============================
       BATCH (draw calls agrupados)
    ============================ */

    void tupi_objeto_enviar_batch(TupiObjeto* obj, int z_index);
    void tupi_batch_desenhar(void);

    /* ============================
       CÂMERA 2D
    ============================ */
    void  tupi_camera_reset(void);
    void  tupi_camera_pos(float x, float y);
    void  tupi_camera_mover(float dx, float dy);
    void  tupi_camera_zoom(float z);
    void  tupi_camera_rotacao(float angulo);
    void  tupi_camera_seguir(float alvo_x, float alvo_y,
                              float lerp_fator, float dt);

    float tupi_camera_get_x(void);
    float tupi_camera_get_y(void);
    float tupi_camera_get_zoom(void);
    float tupi_camera_get_rotacao(void);

    void  tupi_camera_tela_mundo_lua(float sx, float sy, float* wx, float* wy);
    void  tupi_camera_mundo_tela_lua(float wx, float wy, float* sx, float* sy);

    /* ============================
       FÍSICA
       Espelha Fisica.h + ColisoesAABB.h
    ============================ */

    // TupiCorpo — corpo rígido 2D
    // massa == 0.0 → estático (paredes, chão, plataformas)
    typedef struct {
        float x, y;
        float velX, velY;
        float aceleracaoX, aceleracaoY;
        float massa;
        float elasticidade;   // 0.0 (inelástico) a 1.0 (perfeitamente elástico)
        float atrito;         // 0.0 (sem atrito) a 1.0 (para imediatamente)
    } TupiCorpo;

    // Construtores inline não são exportados pelo C — criamos aqui via ffi.new()
    // Veja Tupi.fisica.corpo() e Tupi.fisica.corpoEstatico() no TupiEngine.lua

    // Movimento
    void tupi_fisica_atualizar(TupiCorpo* c, float dt, float gravidade);
    void tupi_fisica_impulso  (TupiCorpo* c, float fx, float fy);

    // Helpers de forma — retornam o colisor centrado no corpo
    TupiRetCol  tupi_corpo_ret(TupiCorpo* c, float largura, float altura);
    TupiCircCol tupi_corpo_cir(TupiCorpo* c, float raio);

    // Resolução de colisão
    void tupi_resolver_colisao (TupiCorpo* a, TupiCorpo* b, TupiColisao info);
    void tupi_resolver_estatico(TupiCorpo* a, TupiColisao info);

    // Utilitários
    void tupi_aplicar_atrito      (TupiCorpo* c, float dt);
    void tupi_limitar_velocidade  (TupiCorpo* c, float maxVel);
]]

local tupiC = ffi.load("./libtupi.so")

return tupiC