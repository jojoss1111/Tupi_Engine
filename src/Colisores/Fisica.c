// Fisica.c
// TupiEngine - Sistema de Física

#include "Fisica.h"
#include <math.h>

// ============================================================
// MOVIMENTO
// ============================================================

void tupi_fisica_atualizar(TupiCorpo* c, float dt, float gravidade) {
    if (c->massa == 0.0f) return;

    c->aceleracaoY += gravidade;

    c->velX += c->aceleracaoX * dt;
    c->velY += c->aceleracaoY * dt;

    c->x += c->velX * dt;
    c->y += c->velY * dt;

    c->aceleracaoX = 0.0f;
    c->aceleracaoY = 0.0f;
}

void tupi_fisica_impulso(TupiCorpo* c, float fx, float fy) {
    if (c->massa == 0.0f) return;
    c->velX += fx / c->massa;
    c->velY += fy / c->massa;
}

// ============================================================
// HELPERS DE FORMA
// ============================================================

TupiRetCol tupi_corpo_ret(TupiCorpo* c, float largura, float altura) {
    return tupi_ret(c->x, c->y, largura, altura);
}

TupiCircCol tupi_corpo_cir(TupiCorpo* c, float raio) {
    return tupi_cir(c->x, c->y, raio);
}

// ============================================================
// RESOLUÇÃO DE COLISÃO
// ============================================================

void tupi_resolver_colisao(TupiCorpo* a, TupiCorpo* b, TupiColisao info) {
    if (!info.colidindo) return;

    // Separa proporcionalmente às massas
    float massaTotal = a->massa + b->massa;
    float ratioA = (b->massa > 0.0f) ? b->massa / massaTotal : 1.0f;
    float ratioB = (a->massa > 0.0f) ? a->massa / massaTotal : 1.0f;

    if (a->massa > 0.0f) {
        a->x += info.dx * ratioA;
        a->y += info.dy * ratioA;
    }
    if (b->massa > 0.0f) {
        b->x -= info.dx * ratioB;
        b->y -= info.dy * ratioB;
    }

    // Resposta de velocidade com elasticidade média
    float e = (a->elasticidade + b->elasticidade) * 0.5f;

    if (info.dy != 0.0f) {
        float velRelY = a->velY - b->velY;
        float impulso = -(1.0f + e) * velRelY / (1.0f/a->massa + 1.0f/b->massa);
        if (a->massa > 0.0f) a->velY += impulso / a->massa;
        if (b->massa > 0.0f) b->velY -= impulso / b->massa;
    }
    if (info.dx != 0.0f) {
        float velRelX = a->velX - b->velX;
        float impulso = -(1.0f + e) * velRelX / (1.0f/a->massa + 1.0f/b->massa);
        if (a->massa > 0.0f) a->velX += impulso / a->massa;
        if (b->massa > 0.0f) b->velX -= impulso / b->massa;
    }
}

void tupi_resolver_estatico(TupiCorpo* a, TupiColisao info) {
    if (!info.colidindo || a->massa == 0.0f) return;

    a->x += info.dx;
    a->y += info.dy;

    if (info.dy != 0.0f) a->velY = -a->velY * a->elasticidade;
    if (info.dx != 0.0f) a->velX = -a->velX * a->elasticidade;
}

// ============================================================
// UTILITÁRIOS
// ============================================================

void tupi_aplicar_atrito(TupiCorpo* c, float dt) {
    if (c->massa == 0.0f) return;
    float fator = 1.0f - c->atrito * dt;
    if (fator < 0.0f) fator = 0.0f;
    c->velX *= fator;
    c->velY *= fator;
}

void tupi_limitar_velocidade(TupiCorpo* c, float maxVel) {
    float mag2 = c->velX * c->velX + c->velY * c->velY;
    if (mag2 > maxVel * maxVel) {
        float escala = maxVel / sqrtf(mag2);
        c->velX *= escala;
        c->velY *= escala;
    }
}