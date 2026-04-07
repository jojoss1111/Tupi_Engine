// Sprites.h
// TupiEngine - Sistema de Sprites e Sprite Sheets
// Carrega PNG e desenha células de sprite sheets na tela

#ifndef SPRITES_H
#define SPRITES_H

#include <glad/glad.h>

// ============================================================
// ESTRUTURA DE SPRITE (imagem carregada)
// ============================================================

// Representa uma imagem PNG carregada na GPU como textura OpenGL
typedef struct {
    GLuint  textura;     // ID da textura OpenGL
    int     largura;     // largura da imagem em pixels
    int     altura;      // altura da imagem em pixels
} TupiSprite;

// ============================================================
// ESTRUTURA DE OBJETO (instância de sprite na tela)
// ============================================================

// Representa um objeto na tela com posição, célula do sprite sheet e escala
typedef struct {
    float x, y;             // posição na tela (canto superior esquerdo)
    float largura, altura;  // tamanho de cada célula do sprite sheet
    int   coluna, linha;    // qual célula do sprite sheet usar (0-indexado)
    float transparencia;    // 0.0 invisível, 1.0 opaco
    float escala;           // 1.0 = tamanho normal, 2.0 = dobro, etc
    TupiSprite* imagem;     // ponteiro para o sprite carregado
} TupiObjeto;

// ============================================================
// FUNÇÕES
// ============================================================

// Inicializa os shaders e VAO do sistema de sprites
// Chamado automaticamente por tupi_janela_criar — não precisa chamar manualmente
void tupi_sprite_iniciar(void);

// Libera os recursos do sistema de sprites
// Chamado automaticamente por tupi_janela_fechar
void tupi_sprite_encerrar(void);

// Carrega um PNG do disco e envia para a GPU como textura
// Retorna um TupiSprite alocado no heap — libere com tupi_sprite_destruir
// Retorna NULL em caso de falha
TupiSprite* tupi_sprite_carregar(const char* caminho);

// Libera a textura da GPU e a memória do TupiSprite
void tupi_sprite_destruir(TupiSprite* sprite);

// Cria um TupiObjeto com os parâmetros fornecidos
TupiObjeto tupi_objeto_criar(
    float x, float y,
    float largura, float altura,
    int coluna, int linha,
    float transparencia,
    float escala,
    TupiSprite* imagem
);

// Desenha o objeto na tela usando a célula (coluna, linha) do sprite sheet
void tupi_objeto_desenhar(TupiObjeto* obj);

// ============================================================
// PONTEIROS INTERNOS — usados pelo RendererGL para injetar o shader de projeção
// Não use diretamente
// ============================================================
void tupi_sprite_set_projecao(float* mat4);

#endif // SPRITES_H