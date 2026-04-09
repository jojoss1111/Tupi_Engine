// Sprites.h
// TupiEngine - Sistema de Sprites, Atlas e Batching
// OpenGL 3.3 — com segurança Rust nos 3 subsistemas

#ifndef SPRITES_H
#define SPRITES_H

#include <glad/glad.h>

// ============================================================
// ESTRUTURA DE SPRITE (imagem na GPU)
// ============================================================

typedef struct {
    GLuint textura;  // ID OpenGL da textura
    int    largura;  // largura total da imagem em pixels
    int    altura;   // altura total da imagem em pixels
} TupiSprite;

// ============================================================
// ESTRUTURA DE OBJETO (instância na tela)
// ============================================================

typedef struct {
    float       x, y;            // posição (canto superior esquerdo)
    float       largura, altura; // tamanho de cada célula do sprite sheet
    int         coluna, linha;   // célula do sprite sheet (0-indexado)
    float       transparencia;   // 0.0 invisível, 1.0 opaco
    float       escala;          // 1.0 = tamanho normal
    TupiSprite* imagem;          // sprite carregado
} TupiObjeto;

// ============================================================
// ESTRUTURA DE ATLAS (gerenciado pelo Rust — ponteiro opaco)
// ============================================================

typedef struct {
    void* _interno; // ponteiro opaco para TupiAtlasOpaco em Rust
} TupiAtlas;

// ============================================================
// FUNÇÕES — CICLO DE VIDA DO SISTEMA
// Chamadas automaticamente pelo RendererGL — não chamar manualmente
// ============================================================

void tupi_sprite_iniciar(void);
void tupi_sprite_encerrar(void);
void tupi_sprite_set_projecao(float* mat4);

// ============================================================
// FUNÇÕES — SPRITE (SISTEMA 1: decodificação segura via Rust)
// ============================================================

// Carrega PNG/JPEG/BMP usando Rust (validação segura, sem stb_image).
// Retorna NULL em caso de falha — nunca passa dados inválidos para a GPU.
TupiSprite* tupi_sprite_carregar(const char* caminho);

// Libera a textura da GPU e a memória.
void tupi_sprite_destruir(TupiSprite* sprite);

// ============================================================
// FUNÇÕES — OBJETO (modo imediato, sem batch)
// ============================================================

// Cria um TupiObjeto com os parâmetros dados.
TupiObjeto tupi_objeto_criar(
    float x, float y,
    float largura, float altura,
    int coluna, int linha,
    float transparencia,
    float escala,
    TupiSprite* imagem
);

// Desenha o objeto imediatamente (1 draw call por objeto).
// Para melhor performance, use o sistema de batch abaixo.
void tupi_objeto_desenhar(TupiObjeto* obj);

// ============================================================
// FUNÇÕES — ATLAS (SISTEMA 2: sprite sheets via Rust)
// ============================================================

// Cria um Atlas para gerenciar as animações de um sprite sheet.
TupiAtlas* tupi_atlas_criar_c(void);

// Destrói o Atlas e libera toda a memória (C + Rust).
void tupi_atlas_destruir_c(TupiAtlas* atlas);

// Registra uma animação no Atlas.
//   nome     → identificador da animação (ex: "andar", "pular")
//   linha    → linha do sprite sheet onde a animação está (0-indexado)
//   colunas  → quantidade de frames da animação
//   cel_larg → largura de cada célula em pixels
//   cel_alt  → altura de cada célula em pixels
//   img_larg → largura total da imagem em pixels
//   img_alt  → altura total da imagem em pixels
void tupi_atlas_registrar_animacao(
    TupiAtlas*   atlas,
    const char*  nome,
    unsigned int linha,
    unsigned int colunas,
    float cel_larg, float cel_alt,
    float img_larg, float img_alt
);

// Obtém as coordenadas UV de um frame de uma animação.
// Retorna 1 em sucesso, 0 se a animação não existir.
int tupi_atlas_obter_uv(
    TupiAtlas*   atlas,
    const char*  nome,
    unsigned int frame,
    float* u0, float* v0,
    float* u1, float* v1
);

// ============================================================
// FUNÇÕES — BATCH (SISTEMA 3: draw calls agrupados via Rust)
// ============================================================

// Envia um objeto para o batch usando UV calculado por célula (coluna/linha).
// Não faz nenhuma chamada OpenGL — apenas acumula no Rust.
//   z_index → profundidade (menor = atrás, maior = frente)
void tupi_objeto_enviar_batch(TupiObjeto* obj, int z_index);

// Envia um objeto para o batch usando UV calculado pelo Atlas Rust.
// O frame é validado automaticamente para não ultrapassar o limite da animação.
void tupi_objeto_enviar_batch_atlas(
    TupiObjeto*  obj,
    TupiAtlas*   atlas,
    const char*  animacao,
    unsigned int frame,
    int          z_index
);

// Executa o flush: Rust ordena por z_index + textura e o C faz
// as draw calls agrupadas. Chame uma vez por frame, no fim do desenhar().
void tupi_batch_desenhar(void);

#endif // SPRITES_H