// RendererGL.c
// TupiEngine - Implementação do Sistema de Renderização OpenGL
// OpenGL 3.3 Core Profile — VAO/VBO + Shaders GLSL

#include "RendererGL.h"
#include "../Inputs/Inputs.h"
#include "../Sprites/Sprites.h"
#include "../Camera/Camera.h"

// ============================================================
// SHADERS GLSL (formas 2D sem textura)
// ============================================================

static const char* _vert_src =
    "#version 330 core\n"
    "layout(location = 0) in vec2 aPos;\n"
    "uniform mat4 uProjecao;\n"
    "void main() {\n"
    "    gl_Position = uProjecao * vec4(aPos, 0.0, 1.0);\n"
    "}\n";

static const char* _frag_src =
    "#version 330 core\n"
    "uniform vec4 uCor;\n"
    "out vec4 FragColor;\n"
    "void main() {\n"
    "    FragColor = uCor;\n"
    "}\n";

// ============================================================
// ESTADO INTERNO
// ============================================================

static GLFWwindow* _janela   = NULL;
static int         _largura  = 800;
static int         _altura   = 600;

// Resolução lógica (coordenadas do mundo) — usada pela câmera
// quando a janela tem escala DPI diferente da resolução lógica.
static int _logico_w = 800;
static int _logico_h = 600;

static float _fundo_r = 0.1f;
static float _fundo_g = 0.1f;
static float _fundo_b = 0.15f;

static float _cor_r = 1.0f;
static float _cor_g = 1.0f;
static float _cor_b = 1.0f;
static float _cor_a = 1.0f;

static double _tempo_anterior = 0.0;
static double _delta          = 0.0;

static GLuint _shader   = 0;
static GLuint _vao      = 0;
static GLuint _vbo      = 0;

static GLint _loc_projecao = -1;
static GLint _loc_cor      = -1;

#define TUPI_MAX_VERTICES 1024

// ============================================================
// GETTERS INTERNOS — usados por Camera.c via extern
// ============================================================

GLuint _tupi_shader_get(void)       { return _shader;       }
GLint  _tupi_loc_projecao_get(void) { return _loc_projecao; }

// ============================================================
// HELPERS DE SHADER
// ============================================================

static GLuint _compilar_shader(GLenum tipo, const char* src) {
    GLuint s = glCreateShader(tipo);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        fprintf(stderr, "[TupiEngine] Erro no shader: %s\n", log);
    }
    return s;
}

static GLuint _criar_programa(const char* vert, const char* frag) {
    GLuint vs = _compilar_shader(GL_VERTEX_SHADER,   vert);
    GLuint fs = _compilar_shader(GL_FRAGMENT_SHADER, frag);
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    GLint ok;
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetProgramInfoLog(prog, sizeof(log), NULL, log);
        fprintf(stderr, "[TupiEngine] Erro ao linkar programa: %s\n", log);
    }
    glDeleteShader(vs);
    glDeleteShader(fs);
    return prog;
}

// ============================================================
// PROJEÇÃO / CÂMERA — reconfigura MVP ao redimensionar
// ============================================================

static void _configurar_projecao(int largura, int altura) {
    glViewport(0, 0, largura, altura);
    // A câmera usa _logico_w/_logico_h como espaço de mundo.
    // O viewport físico (largura × altura) fica no glViewport acima.
    tupi_camera_frame(_logico_w, _logico_h);
}

static void _callback_resize(GLFWwindow* janela, int largura, int altura) {
    (void)janela;
    _largura = largura;
    _altura  = altura;
    _configurar_projecao(largura, altura);
}

static void _erro_glfw(int codigo, const char* descricao) {
    fprintf(stderr, "[TupiEngine] Erro GLFW %d: %s\n", codigo, descricao);
}

// Forward declaration
static void _desenhar(GLenum modo, float* verts, int n);

// ============================================================
// FLUSH CALLBACK
// ============================================================

static void _flush_batcher(const TupiDrawCall* calls, int n) {
    for (int i = 0; i < n; i++) {
        const TupiDrawCall* dc = &calls[i];
        _cor_r = dc->cor[0];
        _cor_g = dc->cor[1];
        _cor_b = dc->cor[2];
        _cor_a = dc->cor[3];
        switch (dc->primitiva) {
            case TUPI_RET: _desenhar(GL_TRIANGLE_STRIP, (float*)dc->verts, 4); break;
            case TUPI_TRI: _desenhar(GL_TRIANGLES,      (float*)dc->verts, 3); break;
            case TUPI_LIN: _desenhar(GL_LINES,          (float*)dc->verts, 2); break;
            default: break;
        }
    }
}

// ============================================================
// DRAW CALL GENÉRICO (formas 2D)
// ============================================================

static void _desenhar(GLenum modo, float* verts, int n) {
    glBindVertexArray(_vao);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float) * 2 * n, verts);
    glUseProgram(_shader);
    glUniform4f(_loc_cor, _cor_r, _cor_g, _cor_b, _cor_a);
    glDrawArrays(modo, 0, n);
    glBindVertexArray(0);
}

// ============================================================
// JANELA
// ============================================================

// Flags de criação (preenchidas por tupi_janela_criar_ex antes de criar)
static int _flag_sem_borda    = 0;
static int _flag_sem_titulo   = 0;  // decoração mínima sem texto
static float _escala_dpi      = 1.0f;

// ----------------------------------------------------------
// tupi_janela_criar — API original (compatibilidade total)
// ----------------------------------------------------------
int tupi_janela_criar(int largura, int altura, const char* titulo) {
    return tupi_janela_criar_ex(largura, altura, titulo, 1.0f, 0, 0);
}

int tupi_janela_criar_ex(int largura, int altura, const char* titulo,float escala, int sem_borda, int sem_texto) {
    glfwSetErrorCallback(_erro_glfw);

    if (!glfwInit()) {
        fprintf(stderr, "[TupiEngine] Falha ao inicializar GLFW!\n");
        return 0;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_SAMPLES, 4);
    glfwWindowHint(GLFW_DECORATED, sem_borda ? GLFW_FALSE : GLFW_TRUE);

#ifdef __APPLE__
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

    const char* titulo_real = (sem_texto || sem_borda) ? "" : titulo;
    _janela = glfwCreateWindow(largura, altura, titulo_real, NULL, NULL);
    if (!_janela) {
        fprintf(stderr, "[TupiEngine] Falha ao criar janela!\n");
        glfwTerminate();
        return 0;
    }

    _largura      = largura;
    _altura       = altura;
    _flag_sem_borda  = sem_borda;
    _flag_sem_titulo = sem_texto;
    _escala_dpi      = (escala > 0.0f) ? escala : 1.0f;

    // Resolução lógica = pixels físicos / escala
    // Ex: janela 800×600 com escala 2.0 → mundo de 400×300
    _logico_w = (int)(largura  / _escala_dpi);
    _logico_h = (int)(altura   / _escala_dpi);

    glfwMakeContextCurrent(_janela);
    glfwSwapInterval(1);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        fprintf(stderr, "[TupiEngine] Falha ao inicializar GLAD!\n");
        glfwTerminate();
        return 0;
    }

    printf("[TupiEngine] OpenGL %s\n", glGetString(GL_VERSION));

    glfwSetFramebufferSizeCallback(_janela, _callback_resize);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_MULTISAMPLE);

    _shader       = _criar_programa(_vert_src, _frag_src);
    _loc_projecao = glGetUniformLocation(_shader, "uProjecao");
    _loc_cor      = glGetUniformLocation(_shader, "uCor");

    glGenVertexArrays(1, &_vao);
    glGenBuffers(1, &_vbo);
    glBindVertexArray(_vao);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 2 * TUPI_MAX_VERTICES, NULL, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, (void*)0);
    glEnableVertexAttribArray(0);
    glBindVertexArray(0);

    tupi_sprite_iniciar();
    tupi_batcher_registrar_flush(_flush_batcher);
    _configurar_projecao(largura, altura);

    _tempo_anterior = glfwGetTime();
    tupi_input_iniciar(_janela);

    printf("[TupiEngine] Janela criada: %dx%d (logico: %dx%d, escala: %.1f) - '%s'\n",
           largura, altura, _logico_w, _logico_h, _escala_dpi,
           (sem_borda || sem_texto) ? titulo : titulo_real);
    printf("[TupiEngine] Bem-vindo a TupiEngine! Versao 0.3\n");

    return 1;
}

int tupi_janela_aberta(void) {
    if (!_janela) return 0;
    return !glfwWindowShouldClose(_janela);
}

void tupi_janela_limpar(void) {
    double agora = glfwGetTime();
    _delta = agora - _tempo_anterior;
    _tempo_anterior = agora;
    glClearColor(_fundo_r, _fundo_g, _fundo_b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    tupi_camera_frame(_logico_w, _logico_h);
}

void tupi_janela_atualizar(void) {
    tupi_batcher_flush();
    glfwSwapBuffers(_janela);
    tupi_input_salvar_estado();
    glfwPollEvents();
    tupi_input_atualizar_mouse();
}

void tupi_janela_fechar(void) {
    tupi_sprite_encerrar();
    if (_shader) { glDeleteProgram(_shader);        _shader = 0; }
    if (_vbo)    { glDeleteBuffers(1, &_vbo);       _vbo    = 0; }
    if (_vao)    { glDeleteVertexArrays(1, &_vao);  _vao    = 0; }
    if (_janela) { glfwDestroyWindow(_janela);      _janela = NULL; }
    glfwTerminate();
    printf("[TupiEngine] Janela fechada. Ate mais!\n");
}

// ============================================================
// CONTROLES DE JANELA EM TEMPO DE EXECUÇÃO
// ============================================================

// Muda o texto da barra de título em runtime
void tupi_janela_set_titulo(const char* titulo) {
    if (_janela && titulo) glfwSetWindowTitle(_janela, titulo);
}

// Ativa ou remove a decoração da janela em runtime (0 = sem borda, 1 = com borda)
// Nota: nem todos os sistemas operacionais respeitam a mudança em runtime.
void tupi_janela_set_decoracao(int ativo) {
    if (!_janela) return;
    glfwSetWindowAttrib(_janela, GLFW_DECORATED, ativo ? GLFW_TRUE : GLFW_FALSE);
    _flag_sem_borda = !ativo;
}

// Alterna tela cheia / janela
void tupi_janela_tela_cheia(int ativo) {
    if (!_janela) return;
    if (ativo) {
        GLFWmonitor* monitor = glfwGetPrimaryMonitor();
        const GLFWvidmode* modo = glfwGetVideoMode(monitor);
        glfwSetWindowMonitor(_janela, monitor, 0, 0,
                             modo->width, modo->height, modo->refreshRate);
    } else {
        glfwSetWindowMonitor(_janela, NULL,
                             100, 100, _largura, _altura, 0);
    }
}

// Retorna a escala DPI configurada na criação
float tupi_janela_escala(void)   { return _escala_dpi; }

double tupi_tempo(void)          { return glfwGetTime(); }
double tupi_delta_tempo(void)    { return _delta;        }
int    tupi_janela_largura(void) { return _logico_w;     } // coordenadas lógicas
int    tupi_janela_altura(void)  { return _logico_h;     }
int    tupi_janela_largura_px(void) { return _largura;   } // pixels físicos
int    tupi_janela_altura_px(void)  { return _altura;    }

// ============================================================
// COR
// ============================================================

void tupi_cor_fundo(float r, float g, float b) {
    _fundo_r = r; _fundo_g = g; _fundo_b = b;
}

void tupi_cor(float r, float g, float b, float a) {
    _cor_r = r; _cor_g = g; _cor_b = b; _cor_a = a;
}

// ============================================================
// FORMAS 2D
// ============================================================

void tupi_retangulo(float x, float y, float largura, float altura) {
    float ts[8] = {
        x,          y,
        x + largura, y,
        x,           y + altura,
        x + largura, y + altura,
    };
    _desenhar(GL_TRIANGLE_STRIP, ts, 4);
}

void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura) {
    glLineWidth(espessura);
    float v[8] = { x, y, x+largura, y, x+largura, y+altura, x, y+altura };
    _desenhar(GL_LINE_LOOP, v, 4);
    glLineWidth(1.0f);
}

void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3) {
    float v[6] = { x1, y1, x2, y2, x3, y3 };
    _desenhar(GL_TRIANGLES, v, 3);
}

void tupi_circulo(float x, float y, float raio, int segmentos) {
    if (segmentos > TUPI_MAX_VERTICES - 2) segmentos = TUPI_MAX_VERTICES - 2;
    float verts[TUPI_MAX_VERTICES * 2];
    int n = 0;
    verts[n++] = x; verts[n++] = y;
    for (int i = 0; i <= segmentos; i++) {
        float a = (float)i / (float)segmentos * 2.0f * (float)M_PI;
        verts[n++] = x + cosf(a) * raio;
        verts[n++] = y + sinf(a) * raio;
    }
    _desenhar(GL_TRIANGLE_FAN, verts, segmentos + 2);
}

void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura) {
    if (segmentos > TUPI_MAX_VERTICES) segmentos = TUPI_MAX_VERTICES;
    float verts[TUPI_MAX_VERTICES * 2];
    int n = 0;
    for (int i = 0; i < segmentos; i++) {
        float a = (float)i / (float)segmentos * 2.0f * (float)M_PI;
        verts[n++] = x + cosf(a) * raio;
        verts[n++] = y + sinf(a) * raio;
    }
    glLineWidth(espessura);
    _desenhar(GL_LINE_LOOP, verts, segmentos);
    glLineWidth(1.0f);
}

void tupi_linha(float x1, float y1, float x2, float y2, float espessura) {
    float v[4] = { x1, y1, x2, y2 };
    glLineWidth(espessura);
    _desenhar(GL_LINES, v, 2);
    glLineWidth(1.0f);
}