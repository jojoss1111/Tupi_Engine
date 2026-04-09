# Makefile - TupiEngine (C + Rust + LuaJIT)
# ============================================================
# CONFIGURAÇÃO
# ============================================================

CC        = gcc
LUAJIT    = luajit
CARGO     = cargo

# Diretórios
SRC_DIR      = src/Renderizador
CAMERA_DIR   = src/Camera
RUST_DIR     = .
RUST_LIB_PATH = ./target/release

# Arquivos C
FONTES    = $(SRC_DIR)/RendererGL.c      \
            $(CAMERA_DIR)/Camera.c       \
            src/Inputs/Inputs.c          \
            src/Colisores/ColisoesAABB.c \
            src/Sprites/Sprites.c        \
            src/glad.c

LIB_NOME  = libtupi.so

# Flags de compilação
CFLAGS    = -O2 -Wall -Wextra -fPIC \
            -I$(SRC_DIR)            \
            -I$(CAMERA_DIR)         \
            -Iinclude               \
            -Isrc

# Bibliotecas e linkagem
LIBS      = -L$(RUST_LIB_PATH) -ltupi_seguro \
            -lglfw -lGL -lm -ldl -lpthread

# ============================================================
# REGRAS
# ============================================================

.PHONY: all compilar_rust $(LIB_NOME) rodar limpar instalar-deps ajuda

all: compilar_rust $(LIB_NOME)

compilar_rust:
	@echo "[TupiEngine] Compilando módulo de segurança em Rust..."
	cd $(RUST_DIR) && $(CARGO) build --release

$(LIB_NOME): $(FONTES)
	@echo "[TupiEngine] Compilando $(LIB_NOME) com suporte a Rust..."
	$(CC) $(CFLAGS) -shared -o $(LIB_NOME) $(FONTES) $(LIBS)
	@echo "[TupiEngine] Engine compilada com sucesso!"

rodar: all
	@echo "[TupiEngine] Iniciando jogo..."
	$(LUAJIT) main.lua

limpar:
	@echo "[TupiEngine] Limpando..."
	rm -f $(LIB_NOME)
	cd $(RUST_DIR) && $(CARGO) clean
	@echo "[TupiEngine] Limpo!"

instalar-deps:
	@echo "[TupiEngine] Instalando dependências (Arch Linux)..."
	sudo pacman -S --needed glfw-x11 mesa luajit base-devel rust
	@echo "[TupiEngine] Dependências instaladas!"

ajuda:
	@echo "Comandos disponíveis:"
	@echo "  make             - Compila Rust e a Engine C"
	@echo "  make rodar       - Compila e executa o jogo com LuaJIT"
	@echo "  make limpar      - Remove arquivos gerados (C e Rust)"
	@echo "  make instalar-deps - Instala bibliotecas necessárias via pacman"