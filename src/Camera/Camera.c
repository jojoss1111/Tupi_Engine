// Camera/Camera.c
// TupiEngine — Sistema de Câmera 2D

#include "Camera.h"
#include "../Renderizador/RendererGL.h"
#include <glad/glad.h>
#include <GLFW/glfw3.h>

// ============================================================
// FORWARD DECLARATIONS — funções externas que Camera.c usa
// ============================================================

// Getters do estado interno de RendererGL.c (definidos lá, não no .h público)
extern GLuint _tupi_shader_get(void);
extern GLint  _tupi_loc_projecao_get(void);

// Sprites.h — compartilha a MVP com o shader de sprites
// Declaramos diretamente aqui para não criar dependência circular de headers
extern void tupi_sprite_set_projecao(const float* mat4);

// ============================================================
// ESTADO INTERNO DA CÂMERA
// ============================================================

static TupiCamera _cam = { 0.0f, 0.0f, 1.0f, 0.0f };

// Dimensões atuais da janela — atualizadas em tupi_camera_frame()
static int _win_w = 800;
static int _win_h = 600;

// ============================================================
// VIEW MATRIX (4×4 column-major, OpenGL)
//
// Equivale a: translate(-cx, -cy) → rotate(-rot) → scale(zoom)
//
// [ zoom*cos   zoom*sin   0   tx ]
// [-zoom*sin   zoom*cos   0   ty ]
// [         0          0  1    0 ]
// [         0          0  0    1 ]
//
// onde tx = -(cx*co + cy*si)*zoom  e  ty = (cx*si - cy*co)*zoom
// ============================================================

static TupiMatriz _view_matrix(const TupiCamera* c) {
    float co = cosf(-c->rotacao) * c->zoom;
    float si = sinf(-c->rotacao) * c->zoom;
    float tx = -(c->x * co + c->y * si);
    float ty =  (c->x * si - c->y * co);

    TupiMatriz v = {{0}};
    v.m[0]  =  co;   v.m[4]  =  si;   v.m[8]  = 0.0f;  v.m[12] = tx;
    v.m[1]  = -si;   v.m[5]  =  co;   v.m[9]  = 0.0f;  v.m[13] = ty;
    v.m[2]  = 0.0f;  v.m[6]  = 0.0f;  v.m[10] = 1.0f;  v.m[14] = 0.0f;
    v.m[3]  = 0.0f;  v.m[7]  = 0.0f;  v.m[11] = 0.0f;  v.m[15] = 1.0f;
    return v;
}

// ============================================================
// PONTO DE INTEGRAÇÃO — chamado por RendererGL.c a cada frame
// ============================================================

void tupi_camera_frame(int largura, int altura) {
    _win_w = largura;
    _win_h = altura;

    TupiMatriz proj = tupi_projecao_ortografica(largura, altura);
    TupiMatriz view = _view_matrix(&_cam);
    TupiMatriz mvp  = tupi_mat4_multiplicar(&proj, &view);

    GLuint shader      = _tupi_shader_get();
    GLint  loc_projecao = _tupi_loc_projecao_get();

    glUseProgram(shader);
    glUniformMatrix4fv(loc_projecao, 1, GL_FALSE, mvp.m);

    tupi_sprite_set_projecao(mvp.m);
}

// ============================================================
// CONVERSÕES DE COORDENADAS
// ============================================================

void tupi_camera_tela_para_mundo(const TupiCamera* cam,
                                  int largura, int altura,
                                  float sx, float sy,
                                  float* wx, float* wy) {
    // Tela → NDC centrado na janela
    float cx = (sx - largura  * 0.5f);
    float cy = (sy - altura   * 0.5f) * -1.0f; // Y invertido (topo = positivo)

    // Inverte zoom e rotação da câmera
    float inv_zoom = 1.0f / cam->zoom;
    float co = cosf(cam->rotacao);
    float si = sinf(cam->rotacao);
    *wx = cam->x + (cx * co - cy * si) * inv_zoom;
    *wy = cam->y + (cx * si + cy * co) * inv_zoom;
}

void tupi_camera_mundo_para_tela(const TupiCamera* cam,
                                  int largura, int altura,
                                  float wx, float wy,
                                  float* sx, float* sy) {
    float dx = wx - cam->x;
    float dy = wy - cam->y;
    float co = cosf(-cam->rotacao) * cam->zoom;
    float si = sinf(-cam->rotacao) * cam->zoom;
    float cx =  dx * co + dy * si;
    float cy = -dx * si + dy * co;
    *sx =  cx + largura  * 0.5f;
    *sy = -cy + altura   * 0.5f;
}

// ============================================================
// API PÚBLICA
// ============================================================

void tupi_camera_reset(void) {
    _cam.x = 0.0f; _cam.y = 0.0f;
    _cam.zoom = 1.0f; _cam.rotacao = 0.0f;
}

void tupi_camera_pos(float x, float y) {
    if (!tupi_camera_validar(x, y, _cam.zoom, _cam.rotacao)) {
        fprintf(stderr, "[Camera] pos invalida (%.2f, %.2f)\n", x, y);
        return;
    }
    _cam.x = x; _cam.y = y;
}

void tupi_camera_mover(float dx, float dy) {
    tupi_camera_pos(_cam.x + dx, _cam.y + dy);
}

void tupi_camera_zoom(float z) {
    if (!tupi_camera_validar(_cam.x, _cam.y, z, _cam.rotacao)) {
        fprintf(stderr, "[Camera] zoom invalido (%.4f)\n", z);
        return;
    }
    _cam.zoom = z;
}

void tupi_camera_rotacao(float angulo) {
    if (!tupi_camera_validar(_cam.x, _cam.y, _cam.zoom, angulo)) {
        fprintf(stderr, "[Camera] rotacao invalida (%.4f)\n", angulo);
        return;
    }
    _cam.rotacao = angulo;
}

void tupi_camera_seguir(float alvo_x, float alvo_y,
                         float lerp_fator, float dt) {
    float fator = 1.0f - powf(1.0f - lerp_fator, dt * 60.0f);
    float nx = _cam.x + (alvo_x - _cam.x) * fator;
    float ny = _cam.y + (alvo_y - _cam.y) * fator;
    if (tupi_camera_validar(nx, ny, _cam.zoom, _cam.rotacao)) {
        _cam.x = nx; _cam.y = ny;
    }
}

float tupi_camera_get_x(void)       { return _cam.x;       }
float tupi_camera_get_y(void)       { return _cam.y;       }
float tupi_camera_get_zoom(void)    { return _cam.zoom;    }
float tupi_camera_get_rotacao(void) { return _cam.rotacao; }

// ============================================================
// WRAPPERS PARA FFI LUA
// ============================================================

void tupi_camera_tela_mundo_lua(float sx, float sy, float* wx, float* wy) {
    tupi_camera_tela_para_mundo(&_cam, _win_w, _win_h, sx, sy, wx, wy);
}

void tupi_camera_mundo_tela_lua(float wx, float wy, float* sx, float* sy) {
    tupi_camera_mundo_para_tela(&_cam, _win_w, _win_h, wx, wy, sx, sy);
}