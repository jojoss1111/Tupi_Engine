// RendererGL.h
// TupiEngine - Sistema de Renderização OpenGL
// OpenGL 3.3 Core Profile — VAO/VBO + Shaders

#ifndef RENDERERGL_H
#define RENDERERGL_H

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// ============================================================
// ESTRUTURAS
// ============================================================

typedef struct { float r, g, b, a; } Cor;
typedef struct { float x, y;       } Vec2;

// ============================================================
// RUST — Camada de Segurança (libtupi_seguro.a)
// ============================================================

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

// -- Asset Manager --
TupiAsset  tupi_asset_carregar(const char* caminho);
void       tupi_asset_liberar(TupiAsset asset);

// -- Batcher --
typedef void (*TupiFlushFn)(const TupiDrawCall* calls, int n);
void       tupi_batcher_registrar_flush(TupiFlushFn cb);
void       tupi_batcher_adicionar(TupiDrawCall dc);
void       tupi_batcher_flush(void);
int        tupi_batcher_tamanho(void);

// -- Math Core --
TupiMatriz tupi_projecao_ortografica(int largura, int altura);
TupiMatriz tupi_mat4_multiplicar(const TupiMatriz* a, const TupiMatriz* b);

// ============================================================
// JANELA — criação
// ============================================================

// API original — comportamento idêntico ao anterior
int  tupi_janela_criar(int largura, int altura, const char* titulo);

// API estendida
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

int    tupi_janela_largura(void);      // coordenadas lógicas (afetadas por escala)
int    tupi_janela_altura(void);
int    tupi_janela_largura_px(void);   // pixels físicos reais
int    tupi_janela_altura_px(void);
float  tupi_janela_escala(void);

// ============================================================
// COR
// ============================================================

void tupi_cor_fundo(float r, float g, float b);
void tupi_cor(float r, float g, float b, float a);

// ============================================================
// FORMAS 2D
// ============================================================

void tupi_retangulo(float x, float y, float largura, float altura);
void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura);
void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3);
void tupi_circulo(float x, float y, float raio, int segmentos);
void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura);
void tupi_linha(float x1, float y1, float x2, float y2, float espessura);

#endif // RENDERERGL_H