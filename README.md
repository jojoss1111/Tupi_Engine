# 🪶 Tupi Engine

> **Uma game engine 100% brasileira — rápida, segura e feita para a próxima geração de desenvolvedores.**

---

## O que é a Tupi Engine?

A Tupi Engine é uma game engine de código aberto desenvolvida inteiramente no Brasil, pensada para jovens programadores que desejam criar jogos 2D com alto desempenho sem abrir mão da simplicidade. O núcleo da engine é escrito em **C** e **Rust**, combinando a velocidade bruta do C com as garantias de segurança de memória que o Rust oferece nativamente — uma arquitetura que elimina categorias inteiras de bugs antes mesmo da execução.

A lógica dos jogos é escrita em **Lua** (via LuaJIT 2.1), uma linguagem leve, expressiva e amplamente utilizada na indústria de jogos. Isso significa que você escreve código simples e legível, enquanto a engine cuida do trabalho pesado por baixo.

---

## Por que Tupi Engine?

| Característica              | Detalhe                                                                 |
|-----------------------------|-------------------------------------------------------------------------|
| ⚡ **Desempenho nativo**    | Núcleo em C com otimização `-O2`; sem camadas desnecessárias            |
| 🛡️ **Segurança de memória** | Subsistema de imagem e recursos gerenciado em Rust                      |
| 🖊️ **Scripts em Lua**       | Código de jogo simples, rápido de aprender e fácil de iterar            |
| 🖼️ **Dois backends gráficos**| OpenGL 3.3 (Linux e Windows) e Direct3D 11 (Windows nativo)            |
| 📦 **Build standalone**     | Gera um único executável, sem dependências externas para o jogador final |
| 🇧🇷 **Feita no Brasil**      | Documentação, nomes de variáveis e mensagens em português               |

---

## Arquitetura

```
┌─────────────────────────────────────────────────┐
│                   Jogo (Lua)                    │  ← Você │escreve aqui
├─────────────────────────────────────────────────┤
│              LuaJIT 2.1 (VM)                    │  ← Executa │os scripts
├──────────────────────┬──────────────────────────┤
│   Backend OpenGL 3.3 │  Backend Direct3D 11     │  ← │Renderização
│   (Linux / Windows)  │  (Windows nativo)        │
├──────────────────────┴──────────────────────────┤
│         Núcleo C  +  Subsistema Rust            │  ← Motor │principal
│  Física · Câmera · Sprites · Colisões · Input   │
└─────────────────────────────────────────────────┘
```

O código Lua é compilado para **bytecode** pelo `empacotar.py` e embutido diretamente no executável final via `all_bytecodes.h`. O jogador não precisa ter LuaJIT instalado para rodar o jogo.

---

## Requisitos do sistema

### Para desenvolver (Linux — recomendado)

| Ferramenta         | Versão mínima | Finalidade                        |
|--------------------|---------------|-----------------------------------|
| `gcc`              | 12+           | Compilar o núcleo C               |
| `rustup` / `cargo` | 1.70+         | Compilar o subsistema Rust        |
| `luajit`           | 2.1+          | Compilar e executar scripts Lua   |
| `make`             | 4.0+          | Sistema de build                  |
| `python3`          | 3.8+          | Empacotador de projetos           |
| `libglfw3`         | 3.3+          | Janela e contexto OpenGL          |
| `libGL` / `mesa`   | Qualquer      | Driver OpenGL (fornecido pelo SO) |
| `libX11` e extras  | Qualquer      | Integração com o ambiente gráfico |

### Para desenvolver no Windows (cross-compile a partir do Linux)

| Ferramenta                      | Finalidade                        |
|---------------------------------|-----------------------------------|
| `mingw-w64-gcc`                 | Cross-compilar para Windows       |
| `mingw-w64-binutils`            | Utilitários de linkagem           |
| `rustup target x86_64-pc-windows-gnu` | Build Rust para Windows     |
| LuaJIT (`.a` para Windows)      | Disponível em `lib/win64/`        |

### Para jogar (usuário final)

Nenhuma dependência adicional. O executável gerado pelo empacotador é **standalone**: LuaJIT, GLFW e X11 ficam embutidos estaticamente no binário. Apenas o driver de vídeo (`libGL`) é exigido, pois ele é fornecido pela própria placa de vídeo da máquina.

---

## Instalando as dependências

### Linux (Arch Linux / Manjaro)

Execute o menu interativo e escolha a opção **Dependências Linux**:

```bash
make
# Escolha [4] Dependencias Linux
```

Ou instale manualmente:

```bash
sudo pacman -S --needed \
    glfw-x11 libx11 libxrandr libxi libxinerama libxcursor \
    mesa luajit base-devel rust mingw-w64-gcc
```

### Linux (Ubuntu / Debian)

```bash
sudo apt install -y \
    gcc make python3 cargo rustup \
    libglfw3-dev libgl1-mesa-dev \
    libx11-dev libxrandr-dev libxi-dev \
    libxinerama-dev libxcursor-dev \
    luajit
```

### Windows (cross-compile via Linux)

```bash
make
# Escolha [5] Dependencias Windows
```

Ou manualmente:

```bash
sudo pacman -S --needed mingw-w64-gcc mingw-w64-binutils rust
rustup target add x86_64-pc-windows-gnu
```

---

## Compilando a engine

O sistema de build é controlado por um `Makefile` interativo. Execute na raiz do projeto:

```bash
make
```

Você verá o menu:

```
╔══════════════════════════════════════════════════════╗
║             TupiEngine — Build System                ║
╚══════════════════════════════════════════════════════╝

  [1] Compilar OpenGL          (Linux — .so para dev)
  [2] Compilar Windows          (cross-compile no Linux)
  [3] Limpar artefatos
  [4] Dependencias Linux
  [5] Dependencias Windows
```

| Comando          | O que faz                                              |
|------------------|--------------------------------------------------------|
| `make gl`        | Compila `libtupi.so` com backend OpenGL (dev)          |
| `make dx11`      | Cross-compila `libtupi_dx11.dll` para Windows          |
| `make rodar`     | Compila e executa o projeto com LuaJIT                 |
| `make limpar`    | Remove todos os artefatos de build                     |
| `make dist-linux`| Gera o binário standalone `tupi_engine` (Linux)        |

---

## Estrutura de um projeto Tupi Engine

```
meu-jogo/
├── main.lua             ← Ponto de entrada do jogo
├── Makefile             ← Build system
├── Cargo.toml           ← Dependências Rust
├── src/
│   ├── Renderizador/    ← Backend gráfico (C)
│   ├── Camera/          ← Sistema de câmera (C)
│   ├── Sprites/         ← Gerenciamento de sprites (C)
│   ├── Colisores/       ← Física e colisões AABB (C)
│   ├── Inputs/          ← Sistema de entrada (C)
│   └── Engine/          ← Módulos Lua da engine
├── assets/              ← Imagens, sons e outros recursos
└── empacotar.py         ← Empacotador de projeto
```

---

## Escrevendo seu primeiro jogo

Todo o código de jogo é escrito em `main.lua`. A engine expõe suas funcionalidades via módulos Lua pré-carregados. Um exemplo mínimo:

```lua
-- main.lua

local engine = require("Engine.engineffi")

engine.janela.criar({ titulo = "Meu Jogo", largura = 800, altura = 600 })

while not engine.janela.deve_fechar() do
    engine.limpar_tela(0.1, 0.1, 0.2)

    -- Lógica e renderização aqui

    engine.janela.atualizar()
end
```

---

## Empacotando seu projeto

Para gerar a versão final do jogo, utilize o empacotador:

```bash
python3 empacotar.py
```

O empacotador oferece dois modos:

**Standalone** — gera um único executável com tudo embutido (LuaJIT, módulos Lua compilados para bytecode, GLFW e X11 linkados estaticamente). Ideal para distribuição.

**Dev/Lib** — gera um pacote com `libtupi.so` e os scripts Lua separados. Ideal para desenvolvimento e testes rápidos.

Ao final, o projeto empacotado é salvo em na pasta que você escolheu com o seguinte conteúdo:

```
NomeDoJogo/
├── NomeDoJogo           ← Launcher executável
├── NomeDoJogo.desktop   ← Atalho para o menu do sistema (Linux)
├── rodar.sh             ← Script de execução via terminal
└── .engine/
    ├── tupi_engine      ← Binário principal standalone
    └── icon.png         ← Ícone do jogo
```

---

## Backends gráficos

### OpenGL 3.3
Backend padrão para Linux, com suporte completo a Windows. Utiliza GLFW para gerenciamento de janela e contexto. Ícone de janela é aplicado via protocolo EWMH (`_NET_WM_ICON`) no X11, com geração automática de múltiplas resoluções por escala nearest-neighbor.

### Direct3D 11
Backend nativo para Windows, compilado via cross-compile com MinGW-w64. Utiliza a API Win32 diretamente, sem dependência de GLFW. Ideal para distribuição na Microsoft Store ou ambientes corporativos Windows.

---

## Recursos da engine

- **Renderização de sprites** com suporte a transformações (posição, rotação, escala)
- **Sistema de câmera** 2D com seguimento de entidade
- **Colisões AABB** para física básica
- **Sistema de input** para teclado, mouse e gamepad
- **Carregamento de imagens PNG** via subsistema Rust (sem dependências externas)
- **Sistema de ícone** com suporte a múltiplas resoluções e integração com o ambiente gráfico
- **Log persistente** em `tupi_engine.log` para depuração

---

## Contribuindo

A Tupi Engine é um projeto aberto e em constante desenvolvimento. Contribuições são bem-vindas — desde correções de bugs e melhorias de desempenho até novos sistemas e documentação.

Reporte problemas, sugira funcionalidades e envie pull requests. Juntos, vamos construir a maior game engine brasileira de todos os tempos.

---

## Licença

Distribuída sob os termos da licença MIT. Consulte o arquivo `LICENSE` para mais informações.

---

<div align="center">

**Tupi Engine** — Feita no Brasil 🇧🇷, para o mundo.
*"De jovens programadores, para jovens programadores."*

</div>
