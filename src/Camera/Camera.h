// Camera/Camera.h
// TupiEngine — Sistema de Câmera 2D
//
// Responsabilidades:
//   C    → geometria da view matrix, lerp, conversões de coordenada
//   Rust → validação de limites (NaN, infinito, zoom ≤ 0, posição absurda)

#ifndef CAMERA_H
#define CAMERA_H

#include <math.h>
#include <stdio.h>

// ============================================================
// ESTRUTURA PÚBLICA
// ============================================================

typedef struct {
    float x;        // posição do centro da câmera no mundo
    float y;
    float zoom;     // escala (1.0 = normal, >1 = aproximado, <1 = afastado)
    float rotacao;  // ângulo em radianos
} TupiCamera;

// ============================================================
// RUST — Validação de parâmetros (camera.rs → libtupi_seguro.a)
// ============================================================

int tupi_camera_validar(float x, float y, float zoom, float rotacao);

// ============================================================
// PONTO DE INTEGRAÇÃO COM RendererGL.c
// Chamada em tupi_janela_limpar() e _configurar_projecao().
// Monta MVP = projeção × view e envia para os shaders de forma e sprite.
// ============================================================

void tupi_camera_frame(int largura, int altura);

// ============================================================
// CONVERSÕES DE COORDENADAS
// ============================================================

void tupi_camera_tela_para_mundo(const TupiCamera* cam,int largura, int altura,float sx, float sy,float* wx, float* wy);

void tupi_camera_mundo_para_tela(const TupiCamera* cam,int largura, int altura,float wx, float wy,float* sx, float* sy);

// ============================================================
// API PÚBLICA — câmera global da engine
// ============================================================

void  tupi_camera_reset(void);
void  tupi_camera_pos(float x, float y);
void  tupi_camera_mover(float dx, float dy);
void  tupi_camera_zoom(float z);
void  tupi_camera_rotacao(float angulo);
void  tupi_camera_seguir(float alvo_x, float alvo_y, float lerp_fator, float dt);

float tupi_camera_get_x(void);
float tupi_camera_get_y(void);
float tupi_camera_get_zoom(void);
float tupi_camera_get_rotacao(void);

// Wrappers para FFI Lua (evitam ponteiro duplo no LuaJIT)
void  tupi_camera_tela_mundo_lua(float sx, float sy, float* wx, float* wy);
void  tupi_camera_mundo_tela_lua(float wx, float wy, float* sx, float* sy);

#endif // CAMERA_H