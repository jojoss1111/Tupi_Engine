// ColisoesAABB.c
// TupiEngine - Sistema de Colisões AABB
// Implementação das detecções de colisão

#include "ColisoesAABB.h"
#include <math.h>

// ============================================================
// RETÂNGULO vs RETÂNGULO
// ============================================================

int tupi_ret_ret(TupiRetCol a, TupiRetCol b) {
    // Sem sobreposição se um está completamente fora do outro
    if (a.x + a.largura <= b.x) return 0; // a está à esquerda de b
    if (b.x + b.largura <= a.x) return 0; // b está à esquerda de a
    if (a.y + a.altura  <= b.y) return 0; // a está acima de b
    if (b.y + b.altura  <= a.y) return 0; // b está acima de a
    return 1;
}

TupiColisao tupi_ret_ret_info(TupiRetCol a, TupiRetCol b) {
    TupiColisao resultado = { 0, 0.0f, 0.0f };

    if (!tupi_ret_ret(a, b)) return resultado;

    // Quanto cada lado se sobrepõe
    float esq   = (b.x + b.largura) - a.x;  // b empurrando a pra direita
    float dir   = (a.x + a.largura) - b.x;  // b empurrando a pra esquerda
    float cima  = (b.y + b.altura)  - a.y;  // b empurrando a pra baixo
    float baixo = (a.y + a.altura)  - b.y;  // b empurrando a pra cima

    // Pega o menor eixo de separação (caminho mais curto pra sair)
    float menor_x = (esq < dir)   ? esq  : dir;
    float menor_y = (cima < baixo) ? cima : baixo;

    resultado.colidindo = 1;

    if (menor_x < menor_y) {
        // Separar no eixo X
        resultado.dx = (esq < dir) ? -esq : dir;
    } else {
        // Separar no eixo Y
        resultado.dy = (cima < baixo) ? -cima : baixo;
    }

    return resultado;
}

// ============================================================
// CÍRCULO vs CÍRCULO
// ============================================================

int tupi_cir_cir(TupiCircCol a, TupiCircCol b) {
    float dx   = b.x - a.x;
    float dy   = b.y - a.y;
    float dist2 = dx*dx + dy*dy;                    // distância ao quadrado
    float soma  = a.raio + b.raio;
    return dist2 <= soma * soma;                    // evita sqrt desnecessário
}

TupiColisao tupi_cir_cir_info(TupiCircCol a, TupiCircCol b) {
    TupiColisao resultado = { 0, 0.0f, 0.0f };

    float dx   = b.x - a.x;
    float dy   = b.y - a.y;
    float dist = sqrtf(dx*dx + dy*dy);
    float soma = a.raio + b.raio;

    if (dist >= soma) return resultado;             // sem colisão

    resultado.colidindo = 1;

    if (dist == 0.0f) {
        // Círculos no mesmo ponto — empurra em direção arbitrária
        resultado.dx = soma;
        return resultado;
    }

    // Normaliza o vetor entre os centros e escala pela penetração
    float penetracao = soma - dist;
    resultado.dx = -(dx / dist) * penetracao;
    resultado.dy = -(dy / dist) * penetracao;

    return resultado;
}

// ============================================================
// RETÂNGULO vs CÍRCULO
// ============================================================

int tupi_ret_cir(TupiRetCol r, TupiCircCol c) {
    // Ponto mais próximo do centro do círculo dentro do retângulo
    float px = c.x;
    float py = c.y;

    if (px < r.x)            px = r.x;
    if (px > r.x + r.largura) px = r.x + r.largura;
    if (py < r.y)            py = r.y;
    if (py > r.y + r.altura)  py = r.y + r.altura;

    float dx = c.x - px;
    float dy = c.y - py;

    return (dx*dx + dy*dy) <= (c.raio * c.raio);
}

// ============================================================
// PONTO vs FORMA
// ============================================================

int tupi_ponto_ret(float px, float py, TupiRetCol r) {
    return px >= r.x && px <= r.x + r.largura &&
           py >= r.y && py <= r.y + r.altura;
}

int tupi_ponto_cir(float px, float py, TupiCircCol c) {
    float dx = px - c.x;
    float dy = py - c.y;
    return (dx*dx + dy*dy) <= (c.raio * c.raio);
}