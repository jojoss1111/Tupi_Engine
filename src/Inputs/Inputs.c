// Inputs.c
// TupiEngine - Sistema de Inputs
// Gerencia teclado, mouse (posição, botões, scroll) com estados por frame

#include "Inputs.h"
#include <string.h>

// ============================================================
// ESTADO INTERNO
// ============================================================

#define TUPI_MAX_TECLAS  512
#define TUPI_MAX_BOTOES  8

// Estado do teclado
// _agora  = estado atual reportado pelo GLFW
// _antes  = estado do frame anterior
// Assim conseguimos detectar "pressionou" e "soltou" num único frame

static int _tecla_agora[TUPI_MAX_TECLAS];
static int _tecla_antes[TUPI_MAX_TECLAS];

// Estado dos botões do mouse
static int _botao_agora[TUPI_MAX_BOTOES];
static int _botao_antes[TUPI_MAX_BOTOES];

// Posição do mouse
static double _mouse_x      = 0.0;
static double _mouse_y      = 0.0;
static double _mouse_x_ant  = 0.0;
static double _mouse_y_ant  = 0.0;

// Scroll acumulado no frame atual
static double _scroll_x = 0.0;
static double _scroll_y = 0.0;

// Scroll acumulado pendente (do callback, antes do atualizar)
static double _scroll_x_pend = 0.0;
static double _scroll_y_pend = 0.0;

// Referência da janela
static GLFWwindow* _janela_ref = NULL;

// ============================================================
// CALLBACKS GLFW
// ============================================================

static void _cb_teclado(GLFWwindow* janela, int tecla, int scancode, int acao, int mods) {
    (void)janela; (void)scancode; (void)mods;
    if (tecla < 0 || tecla >= TUPI_MAX_TECLAS) return;

    if (acao == GLFW_PRESS) {
        _tecla_agora[tecla] = 1;
    } else if (acao == GLFW_RELEASE) {
        _tecla_agora[tecla] = 0;
    }
    // GLFW_REPEAT ignoramos — usamos _segurando pra isso
}

static void _cb_mouse_botao(GLFWwindow* janela, int botao, int acao, int mods) {
    (void)janela; (void)mods;
    if (botao < 0 || botao >= TUPI_MAX_BOTOES) return;

    if (acao == GLFW_PRESS) {
        _botao_agora[botao] = 1;
    } else if (acao == GLFW_RELEASE) {
        _botao_agora[botao] = 0;
    }
}

static void _cb_scroll(GLFWwindow* janela, double dx, double dy) {
    (void)janela;
    _scroll_x_pend += dx;
    _scroll_y_pend += dy;
}

// ============================================================
// INICIALIZAÇÃO
// ============================================================

void tupi_input_iniciar(GLFWwindow* janela) {
    _janela_ref = janela;

    memset(_tecla_agora,  0, sizeof(_tecla_agora));
    memset(_tecla_antes,  0, sizeof(_tecla_antes));
    memset(_botao_agora,  0, sizeof(_botao_agora));
    memset(_botao_antes,  0, sizeof(_botao_antes));

    glfwSetKeyCallback(janela,         _cb_teclado);
    glfwSetMouseButtonCallback(janela, _cb_mouse_botao);
    glfwSetScrollCallback(janela,      _cb_scroll);
}

// ============================================================
// ATUALIZAÇÃO POR FRAME
// ============================================================

void tupi_input_salvar_estado(void) {
    memcpy(_tecla_antes, _tecla_agora, sizeof(_tecla_agora));
    memcpy(_botao_antes, _botao_agora, sizeof(_botao_agora));
    _mouse_x_ant = _mouse_x;
    _mouse_y_ant = _mouse_y;
    _scroll_x = _scroll_x_pend;
    _scroll_y = _scroll_y_pend;
    _scroll_x_pend = 0.0;
    _scroll_y_pend = 0.0;
}

void tupi_input_atualizar_mouse(void) {
    if (_janela_ref) {
        glfwGetCursorPos(_janela_ref, &_mouse_x, &_mouse_y);
    }
}

// ============================================================
// TECLADO
// ============================================================

// Pressionou: estava 0, agora é 1
int tupi_tecla_pressionou(int tecla) {
    if (tecla < 0 || tecla >= TUPI_MAX_TECLAS) return 0;
    return (_tecla_agora[tecla] == 1 && _tecla_antes[tecla] == 0);
}

// Segurando: está 1 agora (independente do frame anterior)
int tupi_tecla_segurando(int tecla) {
    if (tecla < 0 || tecla >= TUPI_MAX_TECLAS) return 0;
    return _tecla_agora[tecla] == 1;
}

// Soltou: estava 1, agora é 0
int tupi_tecla_soltou(int tecla) {
    if (tecla < 0 || tecla >= TUPI_MAX_TECLAS) return 0;
    return (_tecla_agora[tecla] == 0 && _tecla_antes[tecla] == 1);
}

// ============================================================
// MOUSE - POSIÇÃO
// ============================================================

double tupi_mouse_x(void)  { return _mouse_x; }
double tupi_mouse_y(void)  { return _mouse_y; }
double tupi_mouse_dx(void) { return _mouse_x - _mouse_x_ant; }
double tupi_mouse_dy(void) { return _mouse_y - _mouse_y_ant; }

// ============================================================
// MOUSE - BOTÕES
// ============================================================

int tupi_mouse_clicou(int botao) {
    if (botao < 0 || botao >= TUPI_MAX_BOTOES) return 0;
    return (_botao_agora[botao] == 1 && _botao_antes[botao] == 0);
}

int tupi_mouse_segurando(int botao) {
    if (botao < 0 || botao >= TUPI_MAX_BOTOES) return 0;
    return _botao_agora[botao] == 1;
}

int tupi_mouse_soltou(int botao) {
    if (botao < 0 || botao >= TUPI_MAX_BOTOES) return 0;
    return (_botao_agora[botao] == 0 && _botao_antes[botao] == 1);
}

// ============================================================
// SCROLL
// ============================================================

double tupi_scroll_x(void) { return _scroll_x; }
double tupi_scroll_y(void) { return _scroll_y; }