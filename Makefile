# Makefile - TupiEngine
# Compila o C em uma .so e executa com LuaJIT

# ============================================================
# CONFIGURAÇÃO
# ============================================================

CC        = gcc
LUAJIT    = luajit

# Diretórios
SRC_DIR   = src/Renderizador
OUT_DIR   = .

# Arquivos C — inclui o glad.c agora
FONTES    = $(SRC_DIR)/RendererGL.c \
            src/Inputs/Inputs.c     \
            src/glad.c

# Biblioteca de saída
LIB       = libtupi.so

# Flags de compilação
# -Iinclude  → para encontrar glad/glad.h e KHR/khrplatform.h
# -Isrc      → para os headers internos da engine
CFLAGS    = -O2 -Wall -Wextra -fPIC \
            -I$(SRC_DIR)            \
            -Iinclude               \
            -Isrc

# Bibliotecas externas
# -ldl é necessário para o GLAD carregar as funções OpenGL dinamicamente
# Linux: sudo apt install libglfw3-dev libgl-dev
LIBS      = -lglfw -lGL -lm -ldl

# ============================================================
# REGRAS
# ============================================================

.PHONY: all rodar limpar instalar-deps ajuda

## Compila a biblioteca compartilhada (.so)
all: $(LIB)

$(LIB): $(FONTES)
	@echo "[TupiEngine] Compilando $(LIB)..."
	$(CC) $(CFLAGS) -shared -o $(LIB) $(FONTES) $(LIBS)
	@echo "[TupiEngine] $(LIB) compilado com sucesso!"

## Compila e executa o jogo
rodar: all
	@echo "[TupiEngine] Iniciando jogo..."
	$(LUAJIT) main.lua

## Remove arquivos compilados
limpar:
	@echo "[TupiEngine] Limpando..."
	rm -f $(LIB)
	@echo "[TupiEngine] Limpo!"

## Instala as dependências no Ubuntu/Debian
instalar-deps:
	@echo "[TupiEngine] Instalando dependências..."
	sudo apt-get update
	sudo apt-get install -y \
		libglfw3-dev \
		libgl-dev    \
		luajit       \
		build-essential
	@echo "[TupiEngine] Dependências instaladas!"

## Mostra a ajuda
ajuda:
	@echo ""
	@echo "  TupiEngine - Makefile"
	@echo ""
	@echo "  make               -> Compila a engine"
	@echo "  make rodar         -> Compila e roda o jogo"
	@echo "  make limpar        -> Remove arquivos compilados"
	@echo "  make instalar-deps -> Instala dependências (Ubuntu/Debian)"
	@echo "  make ajuda         -> Esta mensagem"
	@echo ""