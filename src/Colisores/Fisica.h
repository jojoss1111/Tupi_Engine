// Fisica.h
// TupiEngine - Sistema de Física

#ifndef TUPI_FISICA_H
#define TUPI_FISICA_H

#include "ColisoesAABB.h"

// massa == 0.0 = estático (paredes, chão)
typedef struct {
    float x, y;
    float velX, velY;
    float aceleracaoX, aceleracaoY;
    float massa;
    float elasticidade; // 0.0 a 1.0
    float atrito;       // 0.0 a 1.0
} TupiCorpo;

// --- Construtores ---

static inline TupiCorpo tupi_corpo(float x, float y, float massa, float elasticidade, float atrito) {
    TupiCorpo c = { x, y, 0, 0, 0, 0, massa, elasticidade, atrito };
    return c;
}

static inline TupiCorpo tupi_corpo_estatico(float x, float y) {
    return tupi_corpo(x, y, 0.0f, 0.0f, 1.0f);
}

// --- Movimento ---
void tupi_fisica_atualizar(TupiCorpo* c, float dt, float gravidade);
void tupi_fisica_impulso(TupiCorpo* c, float fx, float fy);

// --- Helpers de forma ---
TupiRetCol  tupi_corpo_ret(TupiCorpo* c, float largura, float altura);
TupiCircCol tupi_corpo_cir(TupiCorpo* c, float raio);

// --- Resolução ---
void tupi_resolver_colisao(TupiCorpo* a, TupiCorpo* b, TupiColisao info); // dinâmico vs dinâmico
void tupi_resolver_estatico(TupiCorpo* a, TupiColisao info);               // dinâmico vs estático

// --- Utilitários ---
void tupi_aplicar_atrito(TupiCorpo* c, float dt);
void tupi_limitar_velocidade(TupiCorpo* c, float maxVel);

#endif // TUPI_FISICA_H