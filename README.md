# Tupi Engine

Uma engine de jogos 2D brasileira, desenvolvida em C com scripting em Lua, focada em simplicidade, performance e acessibilidade para desenvolvedores independentes.

---

## Sumário

- [Sobre o Projeto](#sobre-o-projeto)
- [Arquitetura](#arquitetura)
- [Dependências](#dependências)
- [Instalação](#instalação)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Como Usar](#como-usar)
- [API de Referência](#api-de-referência)
- [Exemplos](#exemplos)
- [Licença](#licença)

---

## Sobre o Projeto

A **Tupi Engine** é um motor gráfico 2D de código aberto desenvolvido integralmente por um programador brasileiro. O projeto tem como objetivo oferecer uma base sólida para desenvolvimento de jogos utilizando tecnologias acessíveis e bem documentadas, com ênfase em desempenho e clareza de código.

A engine utiliza **Lua** como linguagem de scripting, uma linguagem de propósito geral criada no Brasil pelo PUC-Rio, amplamente reconhecida na indústria de jogos por sua leveza e facilidade de integração com código nativo em C.

---

## Arquitetura

O núcleo da engine é escrito em **C**, comunicando-se com o código de jogo escrito em Lua por meio de uma camada FFI (Foreign Function Interface) via **LuaJIT**. Isso permite chamadas de alto desempenho diretamente às funções C sem overhead significativo.

A renderização utiliza **OpenGL 3.3 Core Profile** com VAO/VBO e shaders GLSL, garantindo um pipeline moderno e compatível com a grande maioria do hardware atual. As funções OpenGL são carregadas em tempo de execução pelo **GLAD**.

```
main.lua
   └── TupiEngine.lua       (API Lua de alto nível)
         └── engineffi.lua  (Declarações FFI / ponte Lua-C)
               └── libtupi.so
                     ├── glad.c           (carregamento das funções OpenGL)
                     ├── RendererGL.c     (janela, shaders, VAO/VBO, formas 2D)
                     └── Inputs.c         (teclado, mouse, scroll)
```

O loop principal de um jogo segue o fluxo padrão:

```
Limpar tela → Lógica do jogo → Desenho → Atualizar (swap + poll de eventos)
```

O pipeline de renderização por frame funciona assim:

```
glClear → _desenhar(forma) → glBufferSubData → glDrawArrays → glfwSwapBuffers
```

---

## Dependências

| Biblioteca | Função |
|------------|--------|
| **GLFW 3** | Criação de janela, contexto OpenGL e captura de eventos |
| **GLAD** | Carregamento das funções do OpenGL 3.3 em tempo de execução |
| **OpenGL 3.3** | Renderização 2D via Core Profile (VAO/VBO + shaders GLSL) |
| **LuaJIT** | Execução de scripts Lua e ponte FFI com o C |
| **C Standard Library** | Base do núcleo da engine |

### Instalação das dependências (Ubuntu/Debian)

```bash
sudo apt install libglfw3-dev libgl-dev luajit build-essential
```

O GLAD já está incluso no repositório em `src/glad.c` e `include/glad/`, não requer instalação separada.

---

## Instalação

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/tupi-engine.git
cd tupi-engine

# Compile a biblioteca compartilhada
make

# Execute o jogo de exemplo
luajit main.lua
```

O `Makefile` compila `RendererGL.c`, `Inputs.c` e `glad.c` juntos, gerando `libtupi.so`, que é carregado dinamicamente pelo LuaJIT em tempo de execução.

---

## Estrutura do Projeto

```
tupi-engine/
├── main.lua                      # Ponto de entrada do jogo
├── Makefile                      # Script de compilação
├── libtupi.so                    # Biblioteca compilada (gerada pelo make)
├── include/
│   ├── glad/
│   │   └── glad.h                # Header do GLAD (OpenGL 3.3)
│   └── KHR/
│       └── khrplatform.h         # Tipos da plataforma Khronos
└── src/
    ├── glad.c                    # Implementação do GLAD
    ├── Engine/
    │   ├── TupiEngine.lua        # API principal em Lua
    │   └── engineffi.lua         # Declarações FFI
    ├── Renderizador/
    │   ├── RendererGL.c          # Renderizador OpenGL 3.3
    │   └── RendererGL.h
    └── Inputs/
        ├── Inputs.c              # Sistema de entrada
        └── Inputs.h
```

---

## Como Usar

Todo o código do jogo é escrito em `main.lua`. A engine é importada com uma única linha:

```lua
local Tupi = require("src.Engine.TupiEngine")
```

### Loop Manual

```lua
local Tupi = require("src.Engine.TupiEngine")

Tupi.janela(800, 600, "Meu Jogo")
Tupi.corFundo(0.1, 0.1, 0.15)

while Tupi.rodando() do
    Tupi.limpar()

    -- lógica e desenho aqui

    Tupi.atualizar()
end

Tupi.fechar()
```

### Loop Automático

A engine oferece uma alternativa mais concisa com `Tupi.rodar`:

```lua
Tupi.rodar(
    function()        -- iniciar (executado uma vez)
        -- setup
    end,
    function(dt)      -- atualizar (executado todo frame)
        -- lógica
    end,
    function()        -- desenhar (executado todo frame)
        -- renderização
    end
)
```

---

## API de Referência

### Janela

| Função | Descrição |
|--------|-----------|
| `Tupi.janela(largura, altura, titulo)` | Cria a janela do jogo |
| `Tupi.rodando()` | Retorna `true` enquanto a janela estiver aberta |
| `Tupi.limpar()` | Limpa a tela (início do frame) |
| `Tupi.atualizar()` | Atualiza a tela e processa eventos (fim do frame) |
| `Tupi.fechar()` | Fecha a janela e libera todos os recursos |
| `Tupi.tempo()` | Tempo em segundos desde o início |
| `Tupi.dt()` | Delta time (duração do frame anterior) |
| `Tupi.largura()` | Largura atual da janela em pixels |
| `Tupi.altura()` | Altura atual da janela em pixels |

### Cor e Desenho

| Função | Descrição |
|--------|-----------|
| `Tupi.corFundo(r, g, b)` | Define a cor de fundo da tela |
| `Tupi.cor(r, g, b, a)` | Define a cor de desenho atual |
| `Tupi.usarCor(tabela)` | Define a cor a partir de uma tabela `{r,g,b,a}` |

Todas as funções de forma aceitam um parâmetro opcional `cor` no final (`{r, g, b}` ou `{r, g, b, a}`). Se omitido, usa a cor definida por `Tupi.cor()`.

| Função | Descrição |
|--------|-----------|
| `Tupi.retangulo(x, y, l, a, cor?)` | Retângulo preenchido |
| `Tupi.retanguloBorda(x, y, l, a, esp, cor?)` | Borda de retângulo |
| `Tupi.circulo(x, y, raio, seg, cor?)` | Círculo preenchido |
| `Tupi.circuloBorda(x, y, raio, seg, esp, cor?)` | Borda de círculo |
| `Tupi.triangulo(x1,y1, x2,y2, x3,y3, cor?)` | Triângulo preenchido |
| `Tupi.linha(x1, y1, x2, y2, esp, cor?)` | Linha entre dois pontos |

Cores predefinidas disponíveis: `Tupi.BRANCO`, `Tupi.PRETO`, `Tupi.VERMELHO`, `Tupi.VERDE`, `Tupi.AZUL`, `Tupi.AMARELO`, `Tupi.ROXO`, `Tupi.LARANJA`, `Tupi.CIANO`, `Tupi.CINZA`, `Tupi.ROSA`.

### Teclado

| Função | Descrição |
|--------|-----------|
| `Tupi.teclaPressionou(tecla)` | `true` apenas no frame em que a tecla foi pressionada |
| `Tupi.teclaSegurando(tecla)` | `true` enquanto a tecla estiver pressionada |
| `Tupi.teclaSoltou(tecla)` | `true` apenas no frame em que a tecla foi solta |

Constantes disponíveis: `Tupi.TECLA_W`, `Tupi.TECLA_ESC`, `Tupi.TECLA_ESPACO`, `Tupi.TECLA_ENTER`, setas direcionais (`TECLA_CIMA`, `TECLA_BAIXO`, `TECLA_ESQUERDA`, `TECLA_DIREITA`), letras A–Z, números 0–9, numpad e F1–F12.

### Mouse

| Função | Descrição |
|--------|-----------|
| `Tupi.mouseX()` | Posição X do cursor em pixels |
| `Tupi.mouseY()` | Posição Y do cursor em pixels |
| `Tupi.mousePos()` | Retorna `x, y` ao mesmo tempo |
| `Tupi.mouseDX()` | Deslocamento X desde o último frame |
| `Tupi.mouseDY()` | Deslocamento Y desde o último frame |
| `Tupi.mouseClicou(botao)` | `true` apenas no frame do clique |
| `Tupi.mouseSegurando(botao)` | `true` enquanto o botão estiver pressionado |
| `Tupi.mouseSoltou(botao)` | `true` apenas no frame em que o botão foi solto |
| `Tupi.scrollX()` | Scroll horizontal acumulado no frame atual |
| `Tupi.scrollY()` | Scroll vertical acumulado no frame atual |

Constantes de botão: `Tupi.MOUSE_ESQ` (0), `Tupi.MOUSE_DIR` (1), `Tupi.MOUSE_MEIO` (2).

### Utilitários Matemáticos

| Função | Descrição |
|--------|-----------|
| `Tupi.lerp(a, b, t)` | Interpolação linear |
| `Tupi.aleatorio(min, max)` | Número aleatório no intervalo |
| `Tupi.rad(graus)` | Converte graus para radianos |
| `Tupi.graus(rad)` | Converte radianos para graus |
| `Tupi.distancia(x1,y1,x2,y2)` | Distância entre dois pontos |

---

## Exemplos

### Mover um quadrado com WASD

```lua
local Tupi = require("src.Engine.TupiEngine")

local x, y = 400, 300
local vel  = 200

Tupi.janela(800, 600, "Movimento")
Tupi.corFundo(0.08, 0.08, 0.12)

while Tupi.rodando() do
    local dt = Tupi.dt()
    Tupi.limpar()

    if Tupi.teclaSegurando(Tupi.TECLA_W) then y = y - vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_S) then y = y + vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_A) then x = x - vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_D) then x = x + vel * dt end

    Tupi.retangulo(x, y, 50, 50, Tupi.VERDE)

    Tupi.atualizar()
end

Tupi.fechar()
```

### Desenhar no clique do mouse

```lua
local Tupi = require("src.Engine.TupiEngine")
local pontos = {}

Tupi.janela(800, 600, "Pintura")
Tupi.corFundo(0.05, 0.05, 0.1)

while Tupi.rodando() do
    Tupi.limpar()

    if Tupi.mouseClicou(Tupi.MOUSE_ESQ) then
        local x, y = Tupi.mousePos()
        table.insert(pontos, {x = x, y = y})
    end

    for _, p in ipairs(pontos) do
        Tupi.circulo(p.x, p.y, 8, 16, Tupi.CIANO)
    end

    Tupi.atualizar()
end

Tupi.fechar()
```

---

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---

Desenvolvido com dedicação por um programador brasileiro.