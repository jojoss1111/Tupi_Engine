// ColisoesAABB.h
// TupiEngine - Sistema de Colisões AABB (Axis-Aligned Bounding Box)
// Colisões entre retângulos, círculos, ponto-retângulo e ponto-círculo

#ifndef COLISOES_AABB_H
#define COLISOES_AABB_H

// ============================================================
// ESTRUTURAS
// ============================================================

// Retângulo de colisão — canto superior esquerdo + tamanho
typedef struct {
    float x, y;
    float largura, altura;
} TupiRetCol;

// Círculo de colisão — centro + raio
typedef struct {
    float x, y;
    float raio;
} TupiCircCol;

// Resultado de uma colisão com info de separação
typedef struct {
    int   colidindo;   // 1 = colidindo, 0 = não
    float dx, dy;      // vetor de separação mínima (empurra objeto pra fora)
} TupiColisao;

// ============================================================
// RETÂNGULO vs RETÂNGULO
// ============================================================

// Retorna 1 se os dois retângulos estão sobrepostos
int tupi_ret_ret(TupiRetCol a, TupiRetCol b);

// Retorna colisão com vetor de separação (útil para física)
TupiColisao tupi_ret_ret_info(TupiRetCol a, TupiRetCol b);

// ============================================================
// CÍRCULO vs CÍRCULO
// ============================================================

// Retorna 1 se os dois círculos estão sobrepostos
int tupi_cir_cir(TupiCircCol a, TupiCircCol b);

// Retorna colisão com vetor de separação
TupiColisao tupi_cir_cir_info(TupiCircCol a, TupiCircCol b);

// ============================================================
// RETÂNGULO vs CÍRCULO
// ============================================================

// Retorna 1 se o retângulo e o círculo estão sobrepostos
int tupi_ret_cir(TupiRetCol r, TupiCircCol c);

// ============================================================
// PONTO vs FORMA
// ============================================================

// Retorna 1 se o ponto (px, py) está dentro do retângulo
int tupi_ponto_ret(float px, float py, TupiRetCol r);

// Retorna 1 se o ponto (px, py) está dentro do círculo
int tupi_ponto_cir(float px, float py, TupiCircCol c);

// ============================================================
// CONSTRUTORES RÁPIDOS
// Evita inicializar struct na mão toda hora
// ============================================================

// Cria um TupiRetCol inline
static inline TupiRetCol tupi_ret(float x, float y, float l, float a) {
    TupiRetCol r = { x, y, l, a };
    return r;
}

// Cria um TupiCircCol inline
static inline TupiCircCol tupi_cir(float x, float y, float raio) {
    TupiCircCol c = { x, y, raio };
    return c;
}

#endif // COLISOES_AABB_H