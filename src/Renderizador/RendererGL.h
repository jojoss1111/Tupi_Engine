// RendererGL.h
// TupiEngine - Sistema de Renderização OpenGL
// Responsável por: janela, contexto OpenGL, e renderização de formas 2D

#ifndef RENDERERGL_H
#define RENDERERGL_H

#include <GLFW/glfw3.h>
#include <GL/gl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// ============================================================
// ESTRUTURAS
// ============================================================

typedef struct {
    float r, g, b, a;
} Cor;

typedef struct {
    float x, y;
} Vec2;

// ============================================================
// JANELA
// ============================================================

// Inicializa GLFW e cria a janela OpenGL
// Retorna 1 em sucesso, 0 em falha
int tupi_janela_criar(int largura, int altura, const char* titulo);

// Retorna 1 se a janela deve continuar aberta
int tupi_janela_aberta(void);

// Limpa a tela com a cor definida
void tupi_janela_limpar(void);

// Troca os buffers e processa eventos
void tupi_janela_atualizar(void);

// Fecha e libera a janela
void tupi_janela_fechar(void);

// Retorna o tempo atual em segundos (desde o início)
double tupi_tempo(void);

// Retorna o delta time (tempo entre frames)
double tupi_delta_tempo(void);

// ============================================================
// COR DE FUNDO
// ============================================================

void tupi_cor_fundo(float r, float g, float b);

// ============================================================
// FORMAS 2D
// ============================================================

// Define a cor de desenho atual (RGBA 0.0 a 1.0)
void tupi_cor(float r, float g, float b, float a);

// Desenha um retângulo preenchido
// x, y = canto superior esquerdo (em pixels)
void tupi_retangulo(float x, float y, float largura, float altura);

// Desenha um retângulo com borda apenas
void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura);

// Desenha um triângulo preenchido com 3 pontos
void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3);

// Desenha um círculo preenchido
// x, y = centro do círculo
void tupi_circulo(float x, float y, float raio, int segmentos);

// Desenha um círculo com borda apenas
void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura);

// Desenha uma linha entre dois pontos
void tupi_linha(float x1, float y1, float x2, float y2, float espessura);

// ============================================================
// JANELA INFO
// ============================================================

int tupi_janela_largura(void);
int tupi_janela_altura(void);

#endif // RENDERERGL_H