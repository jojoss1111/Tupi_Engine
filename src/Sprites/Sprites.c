// Sprites.c
// TupiEngine - Sistema de Sprites e Sprite Sheets
// OpenGL 3.3 — textura + UV via Atlas Rust + Batching Rust

#include "Sprites.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================
// DECLARAÇÕES FFI — FUNÇÕES RUST
// O linker resolve isso em tempo de compilação via libtupi_seguro.a
// ============================================================

// --- Sistema 1: Decodificação segura ---

typedef struct {
    unsigned char* pixels;
    int largura;
    int altura;
    int tamanho;
} TupiImagemRust;

extern TupiImagemRust* tupi_imagem_carregar_seguro(const char* caminho);
extern void            tupi_imagem_destruir(TupiImagemRust* img);

// --- Sistema 2: Atlas ---

typedef struct TupiAtlasOpaco TupiAtlasOpaco;

typedef struct {
    float u0, v0, u1, v1;
} TupiUV;

extern TupiAtlasOpaco* tupi_atlas_criar(void);
extern void            tupi_atlas_destruir(TupiAtlasOpaco* atlas);
extern void            tupi_atlas_registrar(
    TupiAtlasOpaco* atlas,
    const char* nome,
    unsigned int linha,
    unsigned int colunas,
    float cel_larg, float cel_alt,
    float img_larg, float img_alt
);
extern int tupi_atlas_uv(
    const TupiAtlasOpaco* atlas,
    const char* nome,
    unsigned int frame,
    TupiUV* uv_out
);

// --- Sistema 3: Batch ---

typedef struct TupiBatchOpaco TupiBatchOpaco;

typedef struct {
    unsigned int textura_id;
    float        quad[16];
    float        alpha;
    int          z_index;
} TupiItemBatch;

extern TupiBatchOpaco*      tupi_batch_criar(void);
extern void                 tupi_batch_destruir(TupiBatchOpaco* batch);
extern void                 tupi_batch_adicionar(
    TupiBatchOpaco* batch,
    unsigned int textura_id,
    const float* quad,
    float alpha,
    int z_index
);
extern const TupiItemBatch* tupi_batch_flush(TupiBatchOpaco* batch, int* contagem_out);
extern void                 tupi_batch_limpar(TupiBatchOpaco* batch);
extern int                  tupi_batch_contagem(const TupiBatchOpaco* batch);

// ============================================================
// SHADERS DO SISTEMA DE SPRITES
// ============================================================

static const char* _vert_sprite =
    "#version 330 core\n"
    "layout(location = 0) in vec2 aPos;\n"
    "layout(location = 1) in vec2 aUV;\n"
    "uniform mat4 uProjecao;\n"
    "out vec2 vUV;\n"
    "void main() {\n"
    "    gl_Position = uProjecao * vec4(aPos, 0.0, 1.0);\n"
    "    vUV = aUV;\n"
    "}\n";

static const char* _frag_sprite =
    "#version 330 core\n"
    "in vec2 vUV;\n"
    "uniform sampler2D uTextura;\n"
    "uniform float uAlpha;\n"
    "out vec4 FragColor;\n"
    "void main() {\n"
    "    vec4 cor = texture(uTextura, vUV);\n"
    "    FragColor = vec4(cor.rgb, cor.a * uAlpha);\n"
    "}\n";

// ============================================================
// ESTADO INTERNO
// ============================================================

static GLuint _shader_sprite = 0;
static GLuint _vao_sprite    = 0;
static GLuint _vbo_sprite    = 0;

static GLint _loc_projecao = -1;
static GLint _loc_textura  = -1;
static GLint _loc_alpha    = -1;

static float _projecao[16] = {0};

// Batch global — um por frame, gerenciado pelo Rust
static TupiBatchOpaco* _batch = NULL;

// ============================================================
// HELPERS DE SHADER
// ============================================================

static GLuint _compilar(GLenum tipo, const char* src) {
    GLuint s = glCreateShader(tipo);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        fprintf(stderr, "[TupiSprite] Erro no shader: %s\n", log);
    }
    return s;
}

static GLuint _linkar(const char* vert, const char* frag) {
    GLuint vs   = _compilar(GL_VERTEX_SHADER,   vert);
    GLuint fs   = _compilar(GL_FRAGMENT_SHADER, frag);
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    GLint ok;
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetProgramInfoLog(prog, sizeof(log), NULL, log);
        fprintf(stderr, "[TupiSprite] Erro ao linkar: %s\n", log);
    }
    glDeleteShader(vs);
    glDeleteShader(fs);
    return prog;
}

// ============================================================
// INICIALIZAÇÃO / ENCERRAMENTO
// ============================================================

void tupi_sprite_iniciar(void) {
    _shader_sprite = _linkar(_vert_sprite, _frag_sprite);

    _loc_projecao = glGetUniformLocation(_shader_sprite, "uProjecao");
    _loc_textura  = glGetUniformLocation(_shader_sprite, "uTextura");
    _loc_alpha    = glGetUniformLocation(_shader_sprite, "uAlpha");

    // VAO + VBO — cada vértice: x, y, u, v (4 floats)
    // VBO alocado para 512 quads (pode crescer se necessário)
    glGenVertexArrays(1, &_vao_sprite);
    glGenBuffers(1, &_vbo_sprite);

    glBindVertexArray(_vao_sprite);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo_sprite);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 4 * 4 * 512, NULL, GL_DYNAMIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4, (void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4, (void*)(sizeof(float) * 2));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);

    // Cria o batch global via Rust
    _batch = tupi_batch_criar();

    printf("[TupiSprite] Sistema iniciado com Rust (imagem segura + atlas + batch)\n");
}

void tupi_sprite_encerrar(void) {
    // Libera o batch Rust antes de destruir o contexto OpenGL
    if (_batch) {
        tupi_batch_destruir(_batch);
        _batch = NULL;
    }
    if (_shader_sprite) { glDeleteProgram(_shader_sprite);       _shader_sprite = 0; }
    if (_vbo_sprite)    { glDeleteBuffers(1, &_vbo_sprite);      _vbo_sprite    = 0; }
    if (_vao_sprite)    { glDeleteVertexArrays(1, &_vao_sprite); _vao_sprite    = 0; }
}

void tupi_sprite_set_projecao(float* mat4) {
    for (int i = 0; i < 16; i++) _projecao[i] = mat4[i];
}

// ============================================================
// SISTEMA 1 — CARREGAR / DESTRUIR SPRITE (via Rust)
// ============================================================

TupiSprite* tupi_sprite_carregar(const char* caminho) {
    // Rust decodifica e valida a imagem de forma segura
    TupiImagemRust* img = tupi_imagem_carregar_seguro(caminho);
    if (!img) {
        fprintf(stderr, "[TupiSprite] Falha ao carregar '%s'\n", caminho);
        return NULL;
    }

    // Envia os pixels já validados para a GPU
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                 img->largura, img->altura,
                 0, GL_RGBA, GL_UNSIGNED_BYTE,
                 img->pixels);

    glBindTexture(GL_TEXTURE_2D, 0);

    // Salva dimensões antes de destruir img (Rust libera a memória)
    int img_largura = img->largura;
    int img_altura  = img->altura;
    tupi_imagem_destruir(img); // Rust libera pixels — a GPU já tem a cópia

    TupiSprite* sprite = (TupiSprite*)malloc(sizeof(TupiSprite));
    sprite->textura = tex;
    sprite->largura = img_largura;
    sprite->altura  = img_altura;

    printf("[TupiSprite] '%s' carregado via Rust (%dx%d)\n",
           caminho, img_largura, img_altura);
    return sprite;
}

void tupi_sprite_destruir(TupiSprite* sprite) {
    if (!sprite) return;
    glDeleteTextures(1, &sprite->textura);
    free(sprite);
}

// ============================================================
// SISTEMA 2 — ATLAS DE ANIMAÇÕES
// ============================================================

TupiAtlas* tupi_atlas_criar_c(void) {
    // Cria um wrapper C que segura o ponteiro opaco do Rust
    TupiAtlas* a = (TupiAtlas*)malloc(sizeof(TupiAtlas));
    a->_interno = tupi_atlas_criar();
    return a;
}

void tupi_atlas_destruir_c(TupiAtlas* atlas) {
    if (!atlas) return;
    tupi_atlas_destruir(atlas->_interno);
    free(atlas);
}

void tupi_atlas_registrar_animacao(
    TupiAtlas*   atlas,
    const char*  nome,
    unsigned int linha,
    unsigned int colunas,
    float cel_larg, float cel_alt,
    float img_larg, float img_alt
) {
    if (!atlas || !atlas->_interno) return;
    tupi_atlas_registrar(atlas->_interno, nome, linha, colunas,
                         cel_larg, cel_alt, img_larg, img_alt);
}

int tupi_atlas_obter_uv(
    TupiAtlas*   atlas,
    const char*  nome,
    unsigned int frame,
    float* u0, float* v0,
    float* u1, float* v1
) {
    if (!atlas || !atlas->_interno) return 0;
    TupiUV uv = {0};
    int ok = tupi_atlas_uv(atlas->_interno, nome, frame, &uv);
    if (ok) {
        *u0 = uv.u0; *v0 = uv.v0;
        *u1 = uv.u1; *v1 = uv.v1;
    }
    return ok;
}

// ============================================================
// SISTEMA 3 — BATCH DE DRAW CALLS
// ============================================================

void tupi_objeto_enviar_batch(TupiObjeto* obj, int z_index) {
    if (!obj || !obj->imagem || !_batch) return;

    TupiSprite* spr = obj->imagem;

    // UV calculado diretamente (sem atlas) — cálculo simples e seguro
    float u0 = (obj->coluna * obj->largura) / (float)spr->largura;
    float v0 = (obj->linha  * obj->altura)  / (float)spr->altura;
    float u1 = u0 + obj->largura / (float)spr->largura;
    float v1 = v0 + obj->altura  / (float)spr->altura;

    float sw = obj->largura * obj->escala;
    float sh = obj->altura  * obj->escala;

    float x0 = obj->x,      y0 = obj->y;
    float x1 = obj->x + sw, y1 = obj->y + sh;

    float quad[16] = {
        x0, y0,  u0, v0,
        x1, y0,  u1, v0,
        x0, y1,  u0, v1,
        x1, y1,  u1, v1,
    };

    // Rust acumula o item — sem nenhuma chamada OpenGL aqui
    tupi_batch_adicionar(_batch, spr->textura, quad, obj->transparencia, z_index);
}

void tupi_objeto_enviar_batch_atlas(
    TupiObjeto* obj,
    TupiAtlas*  atlas,
    const char* animacao,
    unsigned int frame,
    int z_index
) {
    if (!obj || !obj->imagem || !atlas || !_batch) return;

    TupiSprite* spr = obj->imagem;

    // UV calculado pelo Rust via Atlas — com validação de frame e bounds
    TupiUV uv = {0};
    if (!tupi_atlas_uv(atlas->_interno, animacao, frame, &uv)) {
        fprintf(stderr, "[TupiSprite] Atlas: animacao '%s' nao encontrada\n", animacao);
        return;
    }

    float sw = obj->largura * obj->escala;
    float sh = obj->altura  * obj->escala;
    float x0 = obj->x,      y0 = obj->y;
    float x1 = obj->x + sw, y1 = obj->y + sh;

    float quad[16] = {
        x0, y0,  uv.u0, uv.v0,
        x1, y0,  uv.u1, uv.v0,
        x0, y1,  uv.u0, uv.v1,
        x1, y1,  uv.u1, uv.v1,
    };

    tupi_batch_adicionar(_batch, spr->textura, quad, obj->transparencia, z_index);
}

// Flush: o Rust ordena tudo e o C faz as draw calls agrupadas por textura
void tupi_batch_desenhar(void) {
    if (!_batch) return;

    int contagem = 0;
    const TupiItemBatch* itens = tupi_batch_flush(_batch, &contagem);

    if (contagem <= 0 || !itens) {
        tupi_batch_limpar(_batch);
        return;
    }

    glBindVertexArray(_vao_sprite);
    glUseProgram(_shader_sprite);
    glUniformMatrix4fv(_loc_projecao, 1, GL_FALSE, _projecao);
    glUniform1i(_loc_textura, 0);
    glActiveTexture(GL_TEXTURE0);

    GLuint textura_atual = 0;

    for (int i = 0; i < contagem; i++) {
        const TupiItemBatch* item = &itens[i];

        // Só troca de textura se for diferente — minimiza bind calls
        if (item->textura_id != textura_atual) {
            glBindTexture(GL_TEXTURE_2D, item->textura_id);
            textura_atual = item->textura_id;
        }

        glUniform1f(_loc_alpha, item->alpha);

        glBindBuffer(GL_ARRAY_BUFFER, _vbo_sprite);
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * 16, item->quad);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);

    // Limpa o batch via Rust para o próximo frame
    tupi_batch_limpar(_batch);
}

// ============================================================
// COMPATIBILIDADE — tupi_objeto_desenhar (modo imediato, sem batch)
// ============================================================
// Mantido para quem não quiser usar o batch.
// Para melhor performance, use tupi_objeto_enviar_batch + tupi_batch_desenhar.

TupiObjeto tupi_objeto_criar(
    float x, float y,
    float largura, float altura,
    int coluna, int linha,
    float transparencia, float escala,
    TupiSprite* imagem
) {
    TupiObjeto obj;
    obj.x            = x;
    obj.y            = y;
    obj.largura      = largura;
    obj.altura       = altura;
    obj.coluna       = coluna;
    obj.linha        = linha;
    obj.transparencia = transparencia;
    obj.escala       = escala;
    obj.imagem       = imagem;
    return obj;
}

void tupi_objeto_desenhar(TupiObjeto* obj) {
    if (!obj || !obj->imagem) return;

    TupiSprite* spr = obj->imagem;

    float u0 = (obj->coluna * obj->largura) / (float)spr->largura;
    float v0 = (obj->linha  * obj->altura)  / (float)spr->altura;
    float u1 = u0 + obj->largura / (float)spr->largura;
    float v1 = v0 + obj->altura  / (float)spr->altura;

    float sw = obj->largura * obj->escala;
    float sh = obj->altura  * obj->escala;

    float quad[16] = {
        obj->x,      obj->y,       u0, v0,
        obj->x + sw, obj->y,       u1, v0,
        obj->x,      obj->y + sh,  u0, v1,
        obj->x + sw, obj->y + sh,  u1, v1,
    };

    glBindVertexArray(_vao_sprite);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo_sprite);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(quad), quad);

    glUseProgram(_shader_sprite);
    glUniformMatrix4fv(_loc_projecao, 1, GL_FALSE, _projecao);
    glUniform1i(_loc_textura, 0);
    glUniform1f(_loc_alpha, obj->transparencia);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, spr->textura);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}