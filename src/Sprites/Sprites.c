// Sprites.c
// TupiEngine - Sistema de Sprites e Sprite Sheets
// OpenGL 3.3 — textura + UV coords calculadas por célula do sprite sheet

#define STB_IMAGE_IMPLEMENTATION
#include "../../include/stb_image.h"

#include "Sprites.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// ============================================================
// SHADERS DO SISTEMA DE SPRITES
// ============================================================

// Vertex: recebe posição + UV, passa UV pro fragment
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

// Fragment: amostra a textura e aplica transparência
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
// ESTADO INTERNO DO SISTEMA DE SPRITES
// ============================================================

static GLuint _shader_sprite  = 0;
static GLuint _vao_sprite     = 0;
static GLuint _vbo_sprite     = 0;

static GLint  _loc_projecao   = -1;
static GLint  _loc_textura    = -1;
static GLint  _loc_alpha      = -1;

// Última matriz de projeção enviada pelo RendererGL
static float  _projecao[16]   = {0};

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

    // VAO + VBO — cada vértice tem: x, y, u, v (4 floats)
    // Um quad = 4 vértices = 16 floats (TRIANGLE_STRIP)
    glGenVertexArrays(1, &_vao_sprite);
    glGenBuffers(1, &_vbo_sprite);

    glBindVertexArray(_vao_sprite);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo_sprite);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 4 * 4, NULL, GL_DYNAMIC_DRAW);

    // Atributo 0: vec2 aPos (x, y)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4, (void*)0);
    glEnableVertexAttribArray(0);

    // Atributo 1: vec2 aUV (u, v)
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 4, (void*)(sizeof(float) * 2));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
}

void tupi_sprite_encerrar(void) {
    if (_shader_sprite) { glDeleteProgram(_shader_sprite);      _shader_sprite = 0; }
    if (_vbo_sprite)    { glDeleteBuffers(1, &_vbo_sprite);     _vbo_sprite    = 0; }
    if (_vao_sprite)    { glDeleteVertexArrays(1, &_vao_sprite); _vao_sprite   = 0; }
}

// Recebe a matriz de projeção do RendererGL para manter sincronizado
void tupi_sprite_set_projecao(float* mat4) {
    for (int i = 0; i < 16; i++) _projecao[i] = mat4[i];
}

// ============================================================
// CARREGAR / DESTRUIR SPRITE
// ============================================================

TupiSprite* tupi_sprite_carregar(const char* caminho) {
    // stb_image carrega com y=0 no topo, que é o que queremos
    stbi_set_flip_vertically_on_load(0);

    int largura, altura, canais;
    unsigned char* pixels = stbi_load(caminho, &largura, &altura, &canais, 4); // força RGBA

    if (!pixels) {
        fprintf(stderr, "[TupiSprite] Falha ao carregar '%s': %s\n", caminho, stbi_failure_reason());
        return NULL;
    }

    // Cria textura OpenGL
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);

    // Sem filtragem — pixels nítidos (ideal para pixel art)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    // Corta na borda — não repete textura
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, largura, altura, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

    stbi_image_free(pixels);
    glBindTexture(GL_TEXTURE_2D, 0);

    TupiSprite* sprite = (TupiSprite*)malloc(sizeof(TupiSprite));
    sprite->textura = tex;
    sprite->largura = largura;
    sprite->altura  = altura;

    printf("[TupiSprite] '%s' carregado (%dx%d)\n", caminho, largura, altura);
    return sprite;
}

void tupi_sprite_destruir(TupiSprite* sprite) {
    if (!sprite) return;
    glDeleteTextures(1, &sprite->textura);
    free(sprite);
}

// ============================================================
// CRIAR OBJETO
// ============================================================

TupiObjeto tupi_objeto_criar(
    float x, float y,
    float largura, float altura,
    int coluna, int linha,
    float transparencia,
    float escala,
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

// ============================================================
// DESENHAR OBJETO
// ============================================================

void tupi_objeto_desenhar(TupiObjeto* obj) {
    if (!obj || !obj->imagem) return;

    TupiSprite* spr = obj->imagem;

    // ── Calcular UV da célula no sprite sheet ──────────────────
    // Cada célula tem tamanho (largura x altura) em pixels
    // UV vai de 0.0 a 1.0 em relação ao tamanho total da textura

    float u0 = (obj->coluna * obj->largura)  / (float)spr->largura;
    float v0 = (obj->linha  * obj->altura)   / (float)spr->altura;
    float u1 = u0 + obj->largura  / (float)spr->largura;
    float v1 = v0 + obj->altura   / (float)spr->altura;

    // ── Calcular tamanho na tela com escala ────────────────────
    float sw = obj->largura  * obj->escala;
    float sh = obj->altura   * obj->escala;

    float x0 = obj->x;
    float y0 = obj->y;
    float x1 = obj->x + sw;
    float y1 = obj->y + sh;

    // ── Montar quad (TRIANGLE_STRIP) ───────────────────────────
    // Formato: x, y, u, v  por vértice
    //   topo-esq → topo-dir → baixo-esq → baixo-dir
    float quad[16] = {
        x0, y0,  u0, v0,   // topo-esquerda
        x1, y0,  u1, v0,   // topo-direita
        x0, y1,  u0, v1,   // baixo-esquerda
        x1, y1,  u1, v1,   // baixo-direita
    };

    // ── Enviar para a GPU e desenhar ───────────────────────────
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