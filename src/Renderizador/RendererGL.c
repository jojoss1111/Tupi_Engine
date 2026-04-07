// RendererGL.c
// TupiEngine - Implementação do Sistema de Renderização OpenGL
// Usa OpenGL legado (imediato) para compatibilidade máxima com LuaJIT FFI

#include "RendererGL.h"

// ============================================================
// ESTADO INTERNO
// ============================================================

static GLFWwindow* _janela = NULL;
static int _largura = 800;
static int _altura  = 600;

static float _fundo_r = 0.1f;
static float _fundo_g = 0.1f;
static float _fundo_b = 0.15f;

static float _cor_r = 1.0f;
static float _cor_g = 1.0f;
static float _cor_b = 1.0f;
static float _cor_a = 1.0f;

static double _tempo_anterior = 0.0;
static double _delta = 0.0;

// ============================================================
// CALLBACK DE ERRO DO GLFW
// ============================================================

static void _erro_glfw(int codigo, const char* descricao) {
    fprintf(stderr, "[TupiEngine] Erro GLFW %d: %s\n", codigo, descricao);
}

// ============================================================
// PROJEÇÃO ORTOGRÁFICA (pixels = coordenadas de tela)
// ============================================================

static void _configurar_projecao(int largura, int altura) {
    glViewport(0, 0, largura, altura);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    // Origem no canto superior esquerdo, Y cresce para baixo (padrão de tela)
    glOrtho(0.0, (double)largura, (double)altura, 0.0, -1.0, 1.0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

static void _callback_resize(GLFWwindow* janela, int largura, int altura) {
    (void)janela;
    _largura = largura;
    _altura  = altura;
    _configurar_projecao(largura, altura);
}

// ============================================================
// JANELA
// ============================================================

int tupi_janela_criar(int largura, int altura, const char* titulo) {
    glfwSetErrorCallback(_erro_glfw);

    if (!glfwInit()) {
        fprintf(stderr, "[TupiEngine] Falha ao inicializar GLFW!\n");
        return 0;
    }

    // Janela compatível com OpenGL 2.1 (legado, funciona com glBegin/glEnd)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    glfwWindowHint(GLFW_SAMPLES, 4); // Anti-aliasing 4x

    _janela = glfwCreateWindow(largura, altura, titulo, NULL, NULL);
    if (!_janela) {
        fprintf(stderr, "[TupiEngine] Falha ao criar janela!\n");
        glfwTerminate();
        return 0;
    }

    _largura = largura;
    _altura  = altura;

    glfwMakeContextCurrent(_janela);
    glfwSwapInterval(1); // VSync ligado

    glfwSetFramebufferSizeCallback(_janela, _callback_resize);

    // Habilitar blending (transparência)
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Anti-aliasing para linhas e pontos
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);

    // Configurar projeção ortográfica inicial
    _configurar_projecao(largura, altura);

    _tempo_anterior = glfwGetTime();

    printf("[TupiEngine] Janela criada: %dx%d - '%s'\n", largura, altura, titulo);
    printf("[TupiEngine] Bem-vindo a TupiEngine! Versao 0.1\n");

    return 1;
}

int tupi_janela_aberta(void) {
    if (!_janela) return 0;
    return !glfwWindowShouldClose(_janela);
}

void tupi_janela_limpar(void) {
    // Calcular delta time
    double agora = glfwGetTime();
    _delta = agora - _tempo_anterior;
    _tempo_anterior = agora;

    glClearColor(_fundo_r, _fundo_g, _fundo_b, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glLoadIdentity();
}

void tupi_janela_atualizar(void) {
    glfwSwapBuffers(_janela);
    glfwPollEvents();
}

void tupi_janela_fechar(void) {
    if (_janela) {
        glfwDestroyWindow(_janela);
        _janela = NULL;
    }
    glfwTerminate();
    printf("[TupiEngine] Janela fechada. Ate mais!\n");
}

double tupi_tempo(void) {
    return glfwGetTime();
}

double tupi_delta_tempo(void) {
    return _delta;
}

int tupi_janela_largura(void) { return _largura; }
int tupi_janela_altura(void)  { return _altura;  }

// ============================================================
// COR
// ============================================================

void tupi_cor_fundo(float r, float g, float b) {
    _fundo_r = r;
    _fundo_g = g;
    _fundo_b = b;
}

void tupi_cor(float r, float g, float b, float a) {
    _cor_r = r;
    _cor_g = g;
    _cor_b = b;
    _cor_a = a;
    glColor4f(r, g, b, a);
}

// ============================================================
// FORMAS 2D
// ============================================================

void tupi_retangulo(float x, float y, float largura, float altura) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glBegin(GL_QUADS);
        glVertex2f(x,          y);
        glVertex2f(x + largura, y);
        glVertex2f(x + largura, y + altura);
        glVertex2f(x,          y + altura);
    glEnd();
}

void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glLineWidth(espessura);
    glBegin(GL_LINE_LOOP);
        glVertex2f(x,           y);
        glVertex2f(x + largura,  y);
        glVertex2f(x + largura,  y + altura);
        glVertex2f(x,            y + altura);
    glEnd();
    glLineWidth(1.0f);
}

void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glBegin(GL_TRIANGLES);
        glVertex2f(x1, y1);
        glVertex2f(x2, y2);
        glVertex2f(x3, y3);
    glEnd();
}

void tupi_circulo(float x, float y, float raio, int segmentos) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glBegin(GL_TRIANGLE_FAN);
        glVertex2f(x, y); // Centro
        for (int i = 0; i <= segmentos; i++) {
            float angulo = (float)i / (float)segmentos * 2.0f * (float)M_PI;
            glVertex2f(x + cosf(angulo) * raio, y + sinf(angulo) * raio);
        }
    glEnd();
}

void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glLineWidth(espessura);
    glBegin(GL_LINE_LOOP);
        for (int i = 0; i < segmentos; i++) {
            float angulo = (float)i / (float)segmentos * 2.0f * (float)M_PI;
            glVertex2f(x + cosf(angulo) * raio, y + sinf(angulo) * raio);
        }
    glEnd();
    glLineWidth(1.0f);
}

void tupi_linha(float x1, float y1, float x2, float y2, float espessura) {
    glColor4f(_cor_r, _cor_g, _cor_b, _cor_a);
    glLineWidth(espessura);
    glBegin(GL_LINES);
        glVertex2f(x1, y1);
        glVertex2f(x2, y2);
    glEnd();
    glLineWidth(1.0f);
}