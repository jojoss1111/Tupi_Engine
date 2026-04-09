// RendererDX11.h
// TupiEngine - Sistema de Renderização Direct3D 11 (Windows)
// D3D11 + DXGI + HLSL — equivalente ao RendererGL.h (OpenGL 3.3)

#ifndef RENDERERDX11_H
#define RENDERERDX11_H

// ── Windows e DirectX ────────────────────────────────────────
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Link automático (MSVC / clang-cl)
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dxgi.lib")

// ============================================================
// ESTRUTURAS (idênticas ao RendererGL.h — compartilhadas)
// ============================================================

typedef struct { float r, g, b, a; } Cor;
typedef struct { float x, y;       } Vec2;

// ── Rust bridge (libtupi_seguro.a) ──────────────────────────

typedef struct {
    unsigned char* ptr;
    size_t         tamanho;
} TupiAsset;

typedef enum {
    TUPI_RET = 0,
    TUPI_CIR = 1,
    TUPI_LIN = 2,
    TUPI_TRI = 3,
} TupiPrimitiva;

typedef struct {
    TupiPrimitiva primitiva;
    float         verts[8];
    int           n_verts;
    float         cor[4];
} TupiDrawCall;

typedef struct {
    float m[16];
} TupiMatriz;

// -- Asset Manager (Rust) --
TupiAsset  tupi_asset_carregar(const char* caminho);
void       tupi_asset_liberar(TupiAsset asset);

// -- Batcher (Rust) --
typedef void (*TupiFlushFn)(const TupiDrawCall* calls, int n);
void       tupi_batcher_registrar_flush(TupiFlushFn cb);
void       tupi_batcher_adicionar(TupiDrawCall dc);
void       tupi_batcher_flush(void);
int        tupi_batcher_tamanho(void);

// -- Math Core (Rust) --
TupiMatriz tupi_projecao_ortografica(int largura, int altura);
TupiMatriz tupi_mat4_multiplicar(const TupiMatriz* a, const TupiMatriz* b);

// ============================================================
// JANELA — criação
// ============================================================

// API original — comportamento idêntico ao RendererGL
int  tupi_janela_criar(int largura, int altura, const char* titulo);

// API estendida (escala DPI, borda, título)
int  tupi_janela_criar_ex(int largura, int altura, const char* titulo,
                           float escala, int sem_borda, int sem_texto);

// ============================================================
// JANELA — controle em runtime
// ============================================================

void  tupi_janela_set_titulo(const char* titulo);
void  tupi_janela_set_decoracao(int ativo);   // 0 = sem borda, 1 = com borda
void  tupi_janela_tela_cheia(int ativo);

// ============================================================
// JANELA — estado e tempo
// ============================================================

int    tupi_janela_aberta(void);
void   tupi_janela_limpar(void);
void   tupi_janela_atualizar(void);
void   tupi_janela_fechar(void);
double tupi_tempo(void);
double tupi_delta_tempo(void);

int    tupi_janela_largura(void);         // coordenadas lógicas (afetadas por escala)
int    tupi_janela_altura(void);
int    tupi_janela_largura_px(void);      // pixels físicos reais
int    tupi_janela_altura_px(void);
float  tupi_janela_escala(void);

// ============================================================
// COR
// ============================================================

void tupi_cor_fundo(float r, float g, float b);
void tupi_cor(float r, float g, float b, float a);

// ============================================================
// FORMAS 2D (API idêntica ao RendererGL)
// ============================================================

void tupi_retangulo(float x, float y, float largura, float altura);
void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura);
void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3);
void tupi_circulo(float x, float y, float raio, int segmentos);
void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura);
void tupi_linha(float x1, float y1, float x2, float y2, float espessura);

// ============================================================
// GETTERS INTERNOS — usados por Camera.c via extern
// (mantidos para compatibilidade de link com o resto da engine)
// ============================================================

// Não há shader handle exposto no DX11 — Camera.c deve usar
// tupi_dx11_atualizar_projecao() abaixo para atualizar o MVP.
void tupi_dx11_atualizar_projecao(const TupiMatriz* mat);

#endif // RENDERERDX11_H