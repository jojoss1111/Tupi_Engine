# Makefile - TupiEngine (C + Rust + LuaJIT)
# ============================================================
# BACKENDS DISPONÍVEIS
#   make gl    → OpenGL 3.3 + GLFW  (Linux)
#   make dx11  → Direct3D 11 + Win32 (Windows / cross-compile)
#
# Atalhos herdados (usam backend padrão = gl):
#   make / make all / make rodar / make limpar
# ============================================================

CC        = gcc
LUAJIT    = luajit
CARGO     = cargo

# ── Diretórios ───────────────────────────────────────────────
SRC_DIR      = src/Renderizador
CAMERA_DIR   = src/Camera
RUST_DIR     = .
RUST_LIB_PATH = ./target/release

# ============================================================
# BACKEND: OpenGL (Linux)
# ============================================================

GL_LIB_NOME = libtupi.so

GL_FONTES = $(SRC_DIR)/RendererGL.c      \
            $(CAMERA_DIR)/Camera.c        \
            src/Colisores/Fisica.c        \
            src/Inputs/Inputs.c           \
            src/Colisores/ColisoesAABB.c  \
            src/Sprites/Sprites.c         \
            src/glad.c

GL_CFLAGS = -O2 -Wall -Wextra -fPIC \
            -I$(SRC_DIR)             \
            -I$(CAMERA_DIR)          \
            -Iinclude                \
            -Isrc

GL_LIBS   = -L$(RUST_LIB_PATH) -ltupi_seguro \
            -lglfw -lGL -lm -ldl -lpthread

# ============================================================
# BACKEND: Direct3D 11 (Windows)
#
# Compilador padrão: x86_64-w64-mingw32-gcc (cross-compile no Linux)
# Em uma máquina Windows com MSVC ou clang-cl, troque CC_DX11
# pelo compilador desejado e ajuste DX11_LIBS conforme necessário.
# ============================================================

CC_DX11      = x86_64-w64-mingw32-gcc
DX11_LIB_NOME = libtupi_dx11.dll

DX11_FONTES = $(SRC_DIR)/RendererDX11.c      \
              $(CAMERA_DIR)/Camera.c           \
              src/Colisores/Fisica.c           \
              src/Inputs/Inputsdx11.c          \
              src/Colisores/ColisoesAABB.c     \
              src/Sprites/Spritesdx11.c

DX11_CFLAGS = -O2 -Wall -Wextra               \
              -I$(SRC_DIR)                     \
              -I$(CAMERA_DIR)                  \
              -Iinclude                         \
              -Isrc                             \
              -DTUPI_BACKEND_DX11

# mingw já inclui d3d11/dxgi nos sysroots; em MSVC use #pragma comment
DX11_LIBS   = -L$(RUST_LIB_PATH) -ltupi_seguro \
              -ld3d11 -ldxgi -ld3dcompiler -lm  \
              -static-libgcc

# ============================================================
# REGRAS PHONY
# ============================================================

.PHONY: all gl dx11 compilar_rust rodar limpar instalar-deps ajuda

# ── Default → GL (Linux) ─────────────────────────────────────
all: gl

# ── Backend OpenGL ────────────────────────────────────────────
gl: compilar_rust $(GL_LIB_NOME)

$(GL_LIB_NOME): $(GL_FONTES)
	@echo "[TupiEngine] Compilando $(GL_LIB_NOME) (OpenGL / Linux)..."
	$(CC) $(GL_CFLAGS) -shared -o $(GL_LIB_NOME) $(GL_FONTES) $(GL_LIBS)
	@echo "[TupiEngine] $(GL_LIB_NOME) compilada com sucesso!"

# ── Backend Direct3D 11 ───────────────────────────────────────
dx11: compilar_rust $(DX11_LIB_NOME)

$(DX11_LIB_NOME): $(DX11_FONTES)
	@echo "[TupiEngine] Compilando $(DX11_LIB_NOME) (Direct3D 11 / Windows)..."
	$(CC_DX11) $(DX11_CFLAGS) -shared -o $(DX11_LIB_NOME) $(DX11_FONTES) $(DX11_LIBS)
	@echo "[TupiEngine] $(DX11_LIB_NOME) compilada com sucesso!"

# ── Rust (compartilhado entre os dois backends) ───────────────
compilar_rust:
	@echo "[TupiEngine] Compilando módulo Rust..."
	cd $(RUST_DIR) && $(CARGO) build --release

# ── Rodar (usa backend GL por padrão) ────────────────────────
rodar: gl
	@echo "[TupiEngine] Iniciando jogo..."
	$(LUAJIT) main.lua

# ── Limpeza ───────────────────────────────────────────────────
limpar:
	@echo "[TupiEngine] Limpando..."
	rm -f $(GL_LIB_NOME) $(DX11_LIB_NOME)
	cd $(RUST_DIR) && $(CARGO) clean
	@echo "[TupiEngine] Limpo!"

# ── Dependências (Linux / Arch) ───────────────────────────────
instalar-deps:
	@echo "[TupiEngine] Instalando dependências (Arch Linux)..."
	sudo pacman -S --needed glfw-x11 mesa luajit base-devel rust \
	    mingw-w64-gcc
	@echo "[TupiEngine] Dependências instaladas!"

# ── Ajuda ─────────────────────────────────────────────────────
ajuda:
	@echo ""
	@echo "TupiEngine — comandos disponíveis:"
	@echo ""
	@echo "  make / make gl      Compila o backend OpenGL  → $(GL_LIB_NOME)  (Linux)"
	@echo "  make dx11           Compila o backend DX11    → $(DX11_LIB_NOME) (Windows)"
	@echo "  make rodar          Compila (GL) e executa com LuaJIT"
	@echo "  make limpar         Remove os artefatos gerados (C e Rust)"
	@echo "  make instalar-deps  Instala libs via pacman (Arch Linux)"
	@echo ""
	@echo "  Cross-compile DX11 no Linux requer: x86_64-w64-mingw32-gcc"
	@echo "  No Windows com MSVC, troque CC_DX11 e DX11_LIBS no Makefile."
	@echo ""
