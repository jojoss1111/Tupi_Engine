# Makefile - TupiEngine (C + Rust + LuaJIT)
#
#   make               Menu interativo
#   make gl            OpenGL 3.3 + GLFW  (Linux, gera .so para dev)
#   make dx11          Direct3D 11 + Win32 (Windows / cross-compile)
#   make limpar        Remove artefatos

CC        = gcc
LUAJIT    = luajit
CARGO     = cargo
AR        = ar

# Cores — vermelho=erro, verde=ok, amarelo=aviso, ciano=progresso
RED     = \033[0;31m
GREEN   = \033[0;32m
YELLOW  = \033[0;33m
CYAN    = \033[0;36m
BOLD    = \033[1m
DIM     = \033[2m
RESET   = \033[0m

# Diretórios
SRC_DIR       = src/Renderizador
CAMERA_DIR    = src/Camera
RUST_DIR      = .
RUST_LIB_PATH = ./target/release

# --- Backend: OpenGL (Linux) ---

GL_LIB_NOME = libtupi.so

GL_FONTES = $(SRC_DIR)/RendererGL.c      \
            $(CAMERA_DIR)/Camera.c        \
            src/Colisores/Fisica.c        \
            src/Inputs/Inputs.c           \
            src/Colisores/ColisoesAABB.c  \
            src/Sprites/Sprites.c         \
            src/Mapas/Mapas.c             \
            src/glad.c

GL_CFLAGS = -O2 -Wall -Wextra -fPIC \
            -I$(SRC_DIR)             \
            -I$(CAMERA_DIR)          \
            -Iinclude                \
            -Isrc                    \
            -Isrc/Mapas

GL_LIBS   = -L$(RUST_LIB_PATH) -ltupi_seguro \
            -lglfw -lGL -lX11 -lm -ldl -lpthread

# Standalone Linux (usado pelo empacotar.py)
LOADER_SRC       = main_bytecode_loader.c
DIST_BIN_LINUX   = tupi_engine

DIST_LINUX_SRCS = $(LOADER_SRC) $(GL_FONTES)

DIST_LINUX_CFLAGS = -O2 -Wall                \
                    -I/usr/include/luajit-2.1 \
                    -I$(SRC_DIR)              \
                    -I$(CAMERA_DIR)           \
                    -Iinclude                 \
                    -Isrc                     \
                    -Isrc/Mapas

# --whole-archive: inclui toda a VM LuaJIT no binário.
# -Wl,-E: exporta símbolos do exe para ffi.load(nil) funcionar.
#
# GLFW e X11 são linkados estaticamente quando as libs .a estão
# disponíveis (distribui sem depender de pacotes no PC do jogador).
# Se as .a não existirem, cai automaticamente para linkagem dinâmica
# — o jogador precisará ter as libs instaladas, mas o build não falha.
# libGL NUNCA é estática: é fornecida pelo driver de vídeo de cada máquina.
#
# Para instalar as libs estáticas no Arch: sudo pacman -S glfw-x11 libx11
# Para instalar no Ubuntu/Debian: sudo apt install libglfw3-dev libx11-dev \
#   libxrandr-dev libxi-dev libxinerama-dev libxcursor-dev

_HAVE_STATIC_GLFW  := $(shell find /usr/lib /usr/local/lib 2>/dev/null -name "libglfw3.a"   | head -1)
_HAVE_STATIC_X11   := $(shell find /usr/lib /usr/local/lib 2>/dev/null -name "libX11.a"     | head -1)

ifeq ($(and $(_HAVE_STATIC_GLFW),$(_HAVE_STATIC_X11)),)
# ── Modo dinâmico (libs .a não encontradas) ──────────────────────────
$(info [TupiEngine] Libs estaticas nao encontradas — usando linkagem dinamica.)
$(info [TupiEngine] O executavel precisara das libs instaladas no sistema.)
DIST_LINUX_LIBS = -L$(RUST_LIB_PATH)          \
                  -Wl,--whole-archive          \
                  -lluajit-5.1                 \
                  -Wl,--no-whole-archive        \
                  -ltupi_seguro                \
                  -lglfw -lGL -lX11 -lXrandr   \
                  -lXi -lXinerama -lXcursor    \
                  -lm -ldl -lpthread           \
                  -Wl,-E
else
# ── Modo estático (libs .a encontradas) ──────────────────────────────
$(info [TupiEngine] Libs estaticas encontradas — linkando estaticamente GLFW e X11.)
DIST_LINUX_LIBS = -L$(RUST_LIB_PATH)                              \
                  -Wl,--whole-archive                              \
                  -lluajit-5.1                                     \
                  -Wl,--no-whole-archive                           \
                  -ltupi_seguro                                    \
                  -Wl,-Bstatic -lglfw3 -lX11 -lXrandr -lXi        \
                  -lXinerama -lXcursor                             \
                  -Wl,-Bdynamic                                    \
                  -lGL -lm -ldl -lpthread                          \
                  -static-libgcc                                   \
                  -Wl,-E
endif

# --- Backend: Direct3D 11 (Windows cross-compile) ---

CC_DX11       = x86_64-w64-mingw32-gcc
DX11_LIB_NOME = libtupi_dx11.dll

DX11_FONTES = $(SRC_DIR)/RendererDX11.c      \
              $(CAMERA_DIR)/Camera.c           \
              src/Colisores/Fisica.c           \
              src/Inputs/Inputsdx11.c          \
              src/Colisores/ColisoesAABB.c     \
              src/Sprites/Spritesdx11.c        \
              src/Mapas/Mapas.c

DX11_CFLAGS = -O2 -Wall -Wextra    \
              -I$(SRC_DIR)          \
              -I$(CAMERA_DIR)       \
              -Iinclude             \
              -Isrc                 \
              -Isrc/Mapas           \
              -DTUPI_BACKEND_DX11

DX11_LIBS   = -L$(RUST_LIB_PATH) -ltupi_seguro \
              -ld3d11 -ldxgi -ld3dcompiler -lm  \
              -static-libgcc

# --- Regras phony ---

.PHONY: all menu gl dx11 compilar_rust rodar limpar dist-linux \
        instalar-deps-linux instalar-deps-windows ajuda

all: menu

menu:
	@clear
	@printf "$(CYAN)$(BOLD)"
	@printf "╔══════════════════════════════════════════════════════╗\n"
	@printf "║             TupiEngine — Build System                ║\n"
	@printf "╚══════════════════════════════════════════════════════╝\n"
	@printf "$(RESET)\n"
	@printf "$(BOLD)  Selecione uma opcao:$(RESET)\n\n"
	@printf "  $(GREEN)$(BOLD)[1]$(RESET) Compilar OpenGL          $(DIM)(Linux — .so para dev)$(RESET)\n"
	@printf "  $(CYAN)$(BOLD)[2]$(RESET) Compilar Windows          $(DIM)(cross-compile no Linux)$(RESET)\n"
	@printf "  $(RED)$(BOLD)[3]$(RESET) Limpar artefatos\n"
	@printf "  $(YELLOW)$(BOLD)[4]$(RESET) Dependencias Linux\n"
	@printf "  $(YELLOW)$(BOLD)[5]$(RESET) Dependencias Windows\n"
	@printf "\n$(DIM)  ──────────────────────────────────────────────────────$(RESET)\n\n"
	@printf "  > Digite o numero e pressione Enter: " && \
	read OPCAO; \
	case $$OPCAO in \
		1) $(MAKE) _build_gl ;; \
		2) $(MAKE) _build_dx11 ;; \
		3) $(MAKE) _clean ;; \
		4) $(MAKE) _deps_linux ;; \
		5) $(MAKE) _deps_windows ;; \
		*) printf "$(RED)Opcao invalida.$(RESET)\n" ;; \
	esac

_build_gl:    gl
_build_dx11:  dx11
_clean:       limpar
_deps_linux:  instalar-deps-linux
_deps_windows: instalar-deps-windows

# --- OpenGL dev ---

gl: compilar_rust $(GL_LIB_NOME)

$(GL_LIB_NOME): $(GL_FONTES)
	@printf "\n$(CYAN)>  Compilando $(BOLD)$(GL_LIB_NOME)$(RESET)$(CYAN)...$(RESET)\n"
	@$(CC) $(GL_CFLAGS) -shared -o $(GL_LIB_NOME) $(GL_FONTES) $(GL_LIBS) \
		&& printf "$(GREEN)+  $(GL_LIB_NOME) compilada.$(RESET)\n\n" \
		|| { printf "$(RED)x  Falha na compilacao GL.$(RESET)\n\n"; exit 1; }

# --- DX11 ---

dx11: compilar_rust $(DX11_LIB_NOME)

$(DX11_LIB_NOME): $(DX11_FONTES)
	@printf "\n$(CYAN)>  Compilando $(BOLD)$(DX11_LIB_NOME)$(RESET)$(CYAN)...$(RESET)\n"
	@$(CC_DX11) $(DX11_CFLAGS) -shared -o $(DX11_LIB_NOME) $(DX11_FONTES) $(DX11_LIBS) \
		&& printf "$(GREEN)+  $(DX11_LIB_NOME) compilada.$(RESET)\n\n" \
		|| { printf "$(RED)x  Falha na compilacao DX11.$(RESET)\n\n"; exit 1; }

# --- Rust ---

compilar_rust:
	@printf "$(CYAN)>  Compilando Rust...$(RESET)\n"
	@cd $(RUST_DIR) && $(CARGO) build --release \
		&& printf "$(GREEN)+  Rust compilado.$(RESET)\n" \
		|| { printf "$(RED)x  Falha no build Rust.$(RESET)\n"; exit 1; }

# --- Standalone Linux (invocado pelo empacotar.py, não aparece no menu) ---

dist-linux: $(DIST_LINUX_SRCS)
	@printf "\n$(CYAN)$(BOLD)  Gerando binario standalone Linux...$(RESET)\n\n"
	@$(CC) $(DIST_LINUX_CFLAGS) \
		$(DIST_LINUX_SRCS) \
		$(DIST_LINUX_LIBS) \
		-o $(DIST_BIN_LINUX) \
		&& printf "$(GREEN)+  Pronto: $(BOLD)$(DIST_BIN_LINUX)$(RESET)\n\n" \
		|| { printf "$(RED)x  Falha na compilacao standalone Linux.$(RESET)\n\n"; exit 1; }

# --- Rodar ---

rodar: gl
	@printf "$(GREEN)>  Iniciando com LuaJIT...$(RESET)\n\n"
	@DISPLAY=:0 GDK_BACKEND=x11 $(LUAJIT) main.lua

# --- Limpeza ---

limpar:
	@printf "\n$(RED)  Limpando artefatos...$(RESET)\n"
	@rm -f $(GL_LIB_NOME) $(DX11_LIB_NOME) $(DIST_BIN_LINUX)
	@cd $(RUST_DIR) && $(CARGO) clean
	@printf "$(GREEN)+  Tudo limpo.$(RESET)\n\n"

# --- Deps Linux ---

instalar-deps-linux:
	@printf "\n$(CYAN)$(BOLD)  Dependencias — Linux (Arch)$(RESET)\n\n"
	@printf "  glfw-x11  libx11  libxrandr  libxi  libxinerama  libxcursor\n"
	@printf "  mesa  luajit  base-devel  rust  mingw-w64-gcc\n\n"
	@printf "  > Instalar agora? [s/N]: " && \
	read CONF; \
	if [ "$$CONF" = "s" ] || [ "$$CONF" = "S" ]; then \
		sudo pacman -S --needed glfw-x11 libx11 libxrandr libxi libxinerama libxcursor mesa luajit base-devel rust mingw-w64-gcc \
			&& printf "$(GREEN)+  Instalado.$(RESET)\n\n" \
			|| printf "$(RED)x  Falha.$(RESET)\n\n"; \
	else \
		printf "$(DIM)  Cancelado.$(RESET)\n\n"; \
	fi

# --- Deps Windows ---

instalar-deps-windows:
	@printf "\n$(CYAN)$(BOLD)  Dependencias — Windows (cross-compile)$(RESET)\n\n"
	@printf "  mingw-w64-gcc  mingw-w64-binutils  rust\n"
	@printf "  $(DIM)rustup target add x86_64-pc-windows-gnu$(RESET)\n\n"
	@printf "  LuaJIT Windows -> lib/win64/libluajit-5.1.a\n\n"
	@printf "  > Instalar cross-compile agora? [s/N]: " && \
	read CONF; \
	if [ "$$CONF" = "s" ] || [ "$$CONF" = "S" ]; then \
		sudo pacman -S --needed mingw-w64-gcc mingw-w64-binutils rust \
			&& rustup target add x86_64-pc-windows-gnu \
			&& printf "$(GREEN)+  Pronto.$(RESET)\n\n" \
			|| printf "$(RED)x  Falha.$(RESET)\n\n"; \
	else \
		printf "$(DIM)  Cancelado.$(RESET)\n\n"; \
	fi

# --- Ajuda ---

ajuda:
	@printf "\n$(CYAN)$(BOLD)  TupiEngine — comandos:$(RESET)\n\n"
	@printf "  $(GREEN)make$(RESET)               Menu interativo\n"
	@printf "  $(GREEN)make gl$(RESET)            -> $(GL_LIB_NOME) (dev)\n"
	@printf "  $(CYAN)make dx11$(RESET)          -> $(DX11_LIB_NOME)\n"
	@printf "  $(GREEN)make rodar$(RESET)         Compila GL e executa\n"
	@printf "  $(RED)make limpar$(RESET)        Remove tudo\n\n"