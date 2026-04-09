# Tupi Engine

Uma engine de jogos 2D brasileira, desenvolvida em C com scripting em Lua, focada em simplicidade, performance e acessibilidade para desenvolvedores independentes.

---

## Sumário

- [Sobre o Projeto](#sobre-o-projeto)
- [Arquitetura](#arquitetura)
- [Performance e Eficiência](#performance-e-eficiência)
- [Dependências](#dependências)
- [Instalação](#instalação)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Como Usar](#como-usar)
- [API de Referência](#api-de-referência)
  - [Janela](#janela)
  - [Cor e Desenho](#cor-e-desenho)
  - [Formas 2D](#formas-2d)
  - [Teclado](#teclado)
  - [Mouse e Scroll](#mouse-e-scroll)
  - [Colisões AABB](#colisões-aabb)
  - [Sprites e Objetos](#sprites-e-objetos)
  - [Animações](#animações)
  - [Posição e Movimento de Objetos](#posição-e-movimento-de-objetos)
  - [Hitbox](#hitbox)
  - [Câmera 2D](#câmera-2d)
  - [Utilitários Matemáticos](#utilitários-matemáticos)
- [Constantes](#constantes)
- [Exemplos Completos](#exemplos-completos)
- [Licença](#licença)

---

## Sobre o Projeto

A **Tupi Engine** é um motor gráfico 2D de código aberto desenvolvido integralmente por um programador brasileiro. O projeto tem como objetivo oferecer uma base sólida para desenvolvimento de jogos utilizando tecnologias acessíveis e bem documentadas, com ênfase em desempenho e clareza de código.

A engine utiliza **Lua** como linguagem de scripting — linguagem criada no Brasil pelo PUC-Rio, amplamente reconhecida na indústria de jogos por sua leveza e facilidade de integração com código nativo em C.

---

## Arquitetura

O núcleo da engine é escrito em **C**, comunicando-se com o código de jogo escrito em Lua por meio de uma camada FFI (Foreign Function Interface) via **LuaJIT**. Isso permite chamadas de alto desempenho diretamente às funções C sem overhead significativo.

A renderização utiliza **OpenGL 3.3 Core Profile** com VAO/VBO e shaders GLSL, garantindo um pipeline moderno e compatível com a grande maioria do hardware atual. As funções OpenGL são carregadas em tempo de execução pelo **GLAD**.

Partes críticas da engine, como validação de limites e sistema de batch, são implementadas em **Rust** e compiladas como biblioteca estática (`libtupi_seguro.a`), garantindo segurança de memória sem custo em tempo de execução.

```
main.lua
   └── TupiEngine.lua          (API Lua de alto nível)
         └── engineffi.lua     (Declarações FFI / ponte Lua-C)
               └── libtupi.so
                     ├── glad.c              (carregamento das funções OpenGL)
                     ├── RendererGL.c        (janela, shaders, VAO/VBO, formas 2D)
                     ├── Inputs.c            (teclado, mouse, scroll)
                     ├── Sprites.c           (textura, objeto, batch)
                     ├── Camera.c            (câmera 2D com lerp)
                     └── libtupi_seguro.a    (Rust: validação, batcher, math)
```

O loop principal de um jogo segue o fluxo padrão:

```
Limpar tela → Lógica do jogo → Desenho → Atualizar (swap + poll de eventos)
```

O pipeline de renderização por frame:

```
glClear → _desenhar(forma) → glBufferSubData → glDrawArrays → glfwSwapBuffers
```

---

## Performance e Eficiência

A Tupi Engine foi projetada para ser leve e rápida em hardware modesto. A seguir estão as principais decisões arquiteturais que garantem esse desempenho.

**FFI direto ao C via LuaJIT.** Todas as chamadas da API Lua invocam funções C diretamente através do LuaJIT FFI, sem overhead de binding tradicional. Isso elimina a camada de marshalling presente em engines que usam a API padrão `lua_push*` / `lua_call`.

**VAO/VBO persistente com `glBufferSubData`.** O renderer não recria buffers a cada frame. Um único VAO/VBO é alocado na inicialização e atualizado com `glBufferSubData` apenas com os vértices do frame atual, evitando realocações na GPU.

**Sistema de batch para sprites.** Múltiplos objetos com a mesma textura são agrupados em um único draw call por frame. O sistema de batch, gerenciado pelo Rust, ordena os objetos por `z_index` e textura antes de executar o flush, reduzindo drasticamente o número de chamadas OpenGL.

**Núcleo de segurança em Rust sem overhead.** A validação de parâmetros (NaN, zoom inválido, ponteiros nulos) é feita em Rust e compilada como biblioteca estática. O custo é apenas o de uma chamada de função, sem alocações dinâmicas no caminho crítico.

**Projeção ortográfica pré-calculada.** A matriz MVP (Model-View-Projection) é recalculada apenas quando a câmera muda, não a cada draw call. O resultado é enviado diretamente ao shader via `glUniformMatrix4fv`.

**Delta time real.** O sistema de tempo usa `glfwGetTime()` com precisão de ponto flutuante de 64 bits, garantindo movimento independente de taxa de quadros.

---

## Dependências

| Biblioteca | Função |
|---|---|
| **GLFW 3** | Criação de janela, contexto OpenGL e captura de eventos |
| **GLAD** | Carregamento das funções do OpenGL 3.3 em tempo de execução |
| **OpenGL 3.3** | Renderização 2D via Core Profile (VAO/VBO + shaders GLSL) |
| **LuaJIT** | Execução de scripts Lua e ponte FFI com o C |
| **Rust (libtupi_seguro.a)** | Validação de parâmetros, batcher e matemática |
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

O `Makefile` compila todos os arquivos C e linka com `libtupi_seguro.a` (Rust), gerando `libtupi.so`, que é carregado dinamicamente pelo LuaJIT em tempo de execução.

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
    │   ├── RendererGL.c
    │   └── RendererGL.h
    ├── Inputs/
    │   ├── Inputs.c
    │   └── Inputs.h
    ├── Sprites/
    │   ├── Sprites.c
    │   └── Sprites.h
    ├── Camera/
    │   ├── Camera.c
    │   └── Camera.h
    └── Colisores/
        ├── ColisoesAABB.c
        └── ColisoesAABB.h
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

## API de Referência


### Janela

Funções para criar e controlar a janela do jogo.

---

#### `Tupi.janela(largura, altura, titulo)`

Cria a janela principal do jogo com configurações básicas. Deve ser chamada uma única vez antes do loop principal.

- `largura` — número de pixels de largura (padrão: `800`)
- `altura` — número de pixels de altura (padrão: `600`)
- `titulo` — texto exibido na barra de título do sistema operacional (padrão: `"TupiEngine"`)

```lua
Tupi.janela(1280, 720, "Meu Jogo")
```

---

#### `Tupi.janelaEx(largura, altura, titulo, opcoes)`

Versão estendida de `Tupi.janela` com opções avançadas de criação.

- `opcoes.escala` — fator de escala DPI. Com `escala = 2`, o espaço lógico é metade do tamanho físico, ideal para pixel art com pixels grandes e sem filtro de interpolação.
- `opcoes.semBorda` — se `true`, remove a barra de título e os botões do sistema operacional.
- `opcoes.semTitulo` — se `true`, deixa a barra de título em branco (só tem efeito quando `semBorda` é `false`).

```lua
-- Pixel art 2× sem borda de sistema operacional
Tupi.janelaEx(800, 600, "Pixel Art", { escala = 2, semBorda = true })
```

---

#### `Tupi.rodando()`

Retorna `true` enquanto a janela estiver aberta. Deve ser usado como condição do loop principal.

```lua
while Tupi.rodando() do
    -- ...
end
```

---

#### `Tupi.limpar()`

Limpa a tela com a cor de fundo definida por `Tupi.corFundo`. Deve ser chamada no início de cada frame.

```lua
Tupi.limpar()
```

---

#### `Tupi.atualizar()`

Apresenta o frame renderizado na tela (swap de buffers) e processa eventos do sistema operacional. Deve ser chamada no final de cada frame.

```lua
Tupi.atualizar()
```

---

#### `Tupi.fechar()`

Fecha a janela e libera todos os recursos alocados (texturas, shaders, buffers da GPU).

```lua
Tupi.fechar()
```

---

#### `Tupi.tempo()`

Retorna o tempo em segundos desde o início da execução, com precisão de ponto flutuante de 64 bits.

```lua
local t = Tupi.tempo()
local x = math.sin(t) * 100 + 400  -- movimento senoidal
```

---

#### `Tupi.dt()`

Retorna o delta time — a duração em segundos do frame anterior. Use para multiplicar velocidades e garantir movimento independente da taxa de quadros.

```lua
local dt = Tupi.dt()
x = x + velocidade * dt
```

---

#### `Tupi.largura()` / `Tupi.altura()`

Retornam as dimensões lógicas da janela em coordenadas do mundo. Estas são as coordenadas usadas para posicionar objetos. Com `escala = 2`, uma janela de 800×600 pixels terá largura lógica de 400 e altura lógica de 300.

```lua
-- Centralizar um retângulo na tela
local cx = Tupi.largura()  / 2
local cy = Tupi.altura() / 2
Tupi.retangulo(cx - 25, cy - 25, 50, 50)
```

---

#### `Tupi.larguraPx()` / `Tupi.alturaPx()`

Retornam as dimensões físicas em pixels reais da janela, independente da escala.

---

#### `Tupi.escala()`

Retorna o fator de escala configurado na criação da janela.

---

#### `Tupi.setTitulo(titulo)`

Altera o texto da barra de título em tempo de execução.

```lua
Tupi.setTitulo("Pontuação: " .. pontos)
```

---

#### `Tupi.setDecoracao(ativo)`

Ativa (`true`) ou remove (`false`) a borda e decoração da janela em tempo de execução.

```lua
Tupi.setDecoracao(false)  -- janela sem borda
```

---

#### `Tupi.telaCheia(ativo)`

Entra ou sai do modo tela cheia.

```lua
if Tupi.teclaPressionou(Tupi.TECLA_F11) then
    Tupi.telaCheia(true)
end
```

---

### Cor e Desenho

---

#### `Tupi.corFundo(r, g, b)`

Define a cor usada por `Tupi.limpar()` para preencher o fundo da tela. Os valores são números de `0.0` a `1.0`.

```lua
Tupi.corFundo(0.08, 0.08, 0.12)  -- fundo quase preto com tom azulado
```

---

#### `Tupi.cor(r, g, b, a)`

Define a cor de desenho atual para todas as formas desenhadas a seguir. O quarto parâmetro `a` é a transparência (0.0 = invisível, 1.0 = opaco).

```lua
Tupi.cor(1, 0.5, 0, 1)   -- laranja sólido
Tupi.retangulo(100, 100, 50, 50)
```

---

#### `Tupi.usarCor(tabela)`

Define a cor a partir de uma tabela `{r, g, b}` ou `{r, g, b, a}`. Conveniente para usar com as cores predefinidas.

```lua
Tupi.usarCor(Tupi.CIANO)
Tupi.circulo(200, 200, 30, 32)
```

---

#### Cores predefinidas

Tabelas de cor prontas para uso em qualquer função de forma.

| Constante | Cor |
|---|---|
| `Tupi.BRANCO` | Branco |
| `Tupi.PRETO` | Preto |
| `Tupi.VERMELHO` | Vermelho |
| `Tupi.VERDE` | Verde |
| `Tupi.AZUL` | Azul |
| `Tupi.AMARELO` | Amarelo |
| `Tupi.ROXO` | Roxo |
| `Tupi.LARANJA` | Laranja |
| `Tupi.CIANO` | Ciano |
| `Tupi.CINZA` | Cinza |
| `Tupi.ROSA` | Rosa |

```lua
Tupi.retangulo(100, 100, 50, 50, Tupi.VERDE)
Tupi.circulo(200, 200, 25, 32, Tupi.VERMELHO)
```

---

### Formas 2D

Todas as funções de forma aceitam um parâmetro opcional `cor` no final, que pode ser uma tabela `{r, g, b}` ou `{r, g, b, a}`. Se omitido, usa a cor definida por `Tupi.cor()`.

---

#### `Tupi.retangulo(x, y, largura, altura, cor?)`

Desenha um retângulo preenchido. O ponto `(x, y)` é o canto superior esquerdo.

```lua
Tupi.retangulo(50, 50, 200, 100, Tupi.AZUL)
```

---

#### `Tupi.retanguloBorda(x, y, largura, altura, espessura, cor?)`

Desenha apenas a borda de um retângulo, sem preenchimento.

- `espessura` — espessura da linha em pixels (padrão: `1`)

```lua
Tupi.retanguloBorda(50, 50, 200, 100, 2, Tupi.BRANCO)
```

---

#### `Tupi.circulo(x, y, raio, segmentos, cor?)`

Desenha um círculo preenchido. Mais segmentos resultam em uma curva mais suave, com custo computacional maior.

- `segmentos` — quantidade de triângulos usados para aproximar o círculo (padrão: `64`)

```lua
Tupi.circulo(400, 300, 50, 32, Tupi.AMARELO)
```

---

#### `Tupi.circuloBorda(x, y, raio, segmentos, espessura, cor?)`

Desenha apenas a borda de um círculo.

```lua
Tupi.circuloBorda(400, 300, 50, 32, 2, Tupi.CIANO)
```

---

#### `Tupi.triangulo(x1, y1, x2, y2, x3, y3, cor?)`

Desenha um triângulo preenchido com os três vértices fornecidos.

```lua
Tupi.triangulo(400, 100, 300, 300, 500, 300, Tupi.ROXO)
```

---

#### `Tupi.linha(x1, y1, x2, y2, espessura, cor?)`

Desenha uma linha entre dois pontos.

- `espessura` — espessura da linha em pixels (padrão: `1`)

```lua
Tupi.linha(0, 0, 800, 600, 3, Tupi.BRANCO)
```

---

### Teclado

O sistema de teclado diferencia três estados por frame: o frame em que a tecla foi pressionada, os frames em que está sendo mantida, e o frame em que foi solta.

---

#### `Tupi.teclaPressionou(tecla)`

Retorna `true` **apenas no frame** em que a tecla foi pressionada. Ideal para ações únicas como pular ou disparar.

```lua
if Tupi.teclaPressionou(Tupi.TECLA_ESPACO) then
    jogador:pular()
end
```

---

#### `Tupi.teclaSegurando(tecla)`

Retorna `true` em **todos os frames** enquanto a tecla estiver pressionada. Ideal para movimento contínuo.

```lua
if Tupi.teclaSegurando(Tupi.TECLA_D) then
    x = x + velocidade * Tupi.dt()
end
```

---

#### `Tupi.teclaSoltou(tecla)`

Retorna `true` **apenas no frame** em que a tecla foi solta.

```lua
if Tupi.teclaSoltou(Tupi.TECLA_SHIFT_ESQ) then
    jogador:pararCorrida()
end
```

---

### Mouse e Scroll

---

#### `Tupi.mouseX()` / `Tupi.mouseY()`

Retornam a posição X e Y do cursor em pixels na tela.

---

#### `Tupi.mousePos()`

Retorna a posição X e Y do cursor ao mesmo tempo (dois valores de retorno).

```lua
local mx, my = Tupi.mousePos()
```

---

#### `Tupi.mouseDX()` / `Tupi.mouseDY()`

Retornam o deslocamento do cursor desde o último frame. Útil para implementar câmera com arrastar ou mira relativa.

```lua
cameraX = cameraX + Tupi.mouseDX() * sensibilidade
```

---

#### `Tupi.mouseClicou(botao)`

Retorna `true` apenas no frame em que o botão foi clicado.

```lua
if Tupi.mouseClicou(Tupi.MOUSE_ESQ) then
    local mx, my = Tupi.mousePos()
    atirar(mx, my)
end
```

---

#### `Tupi.mouseSegurando(botao)`

Retorna `true` em todos os frames enquanto o botão estiver pressionado.

---

#### `Tupi.mouseSoltou(botao)`

Retorna `true` apenas no frame em que o botão foi solto.

---

#### `Tupi.scrollX()` / `Tupi.scrollY()`

Retornam o scroll acumulado neste frame. Scroll para cima retorna valor positivo em `scrollY`.

```lua
zoom = zoom + Tupi.scrollY() * 0.1
```

---

### Colisões AABB

O módulo `Tupi.col` oferece detecção de colisão entre retângulos, círculos e pontos usando o algoritmo AABB (Axis-Aligned Bounding Box). Retângulos e círculos são descritos como tabelas Lua simples.

**Formato de retângulo:** `{ x, y, largura, altura }` — onde `(x, y)` é o canto superior esquerdo.

**Formato de círculo:** `{ x, y, raio }` — onde `(x, y)` é o centro.

---

#### `Tupi.col.retRet(a, b)`

Retorna `true` se dois retângulos estão sobrepostos.

```lua
local jogador = { x = 100, y = 100, largura = 32, altura = 32 }
local parede  = { x = 120, y = 100, largura = 64, altura = 64 }

if Tupi.col.retRet(jogador, parede) then
    print("Colidiu com a parede!")
end
```

---

#### `Tupi.col.retRetInfo(a, b)`

Retorna uma tabela com detalhes da colisão: `{ colidindo, dx, dy }`. Os campos `dx` e `dy` formam o vetor de separação mínima, que indica quanto e em qual direção mover o objeto para sair da sobreposição.

```lua
local info = Tupi.col.retRetInfo(jogador, parede)
if info.colidindo then
    jogador.x = jogador.x + info.dx
    jogador.y = jogador.y + info.dy
end
```

---

#### `Tupi.col.cirCir(a, b)`

Retorna `true` se dois círculos estão sobrepostos.

```lua
local bola1 = { x = 200, y = 200, raio = 20 }
local bola2 = { x = 215, y = 200, raio = 20 }

if Tupi.col.cirCir(bola1, bola2) then
    print("Bolas colidindo!")
end
```

---

#### `Tupi.col.cirCirInfo(a, b)`

Retorna `{ colidindo, dx, dy }` com o vetor de separação para dois círculos.

---

#### `Tupi.col.retCir(r, c)`

Retorna `true` se um retângulo e um círculo estão sobrepostos.

```lua
local caixa = { x = 100, y = 100, largura = 50, altura = 50 }
local bola  = { x = 140, y = 130, raio = 15 }

if Tupi.col.retCir(caixa, bola) then
    print("Retângulo e círculo colidindo!")
end
```

---

#### `Tupi.col.pontoRet(px, py, r)`

Retorna `true` se o ponto `(px, py)` está dentro do retângulo.

---

#### `Tupi.col.pontoCir(px, py, c)`

Retorna `true` se o ponto `(px, py)` está dentro do círculo.

---

#### `Tupi.col.mouseNoRet(r)` / `Tupi.col.mouseNoCir(c)`

Atalhos que verificam se o cursor do mouse está sobre um retângulo ou círculo.

```lua
if Tupi.col.mouseNoRet(botao) and Tupi.mouseClicou(Tupi.MOUSE_ESQ) then
    print("Botão clicado!")
end
```

---

### Sprites e Objetos

---

#### `Tupi.carregarSprite(caminho)`

Carrega uma imagem da GPU a partir do caminho fornecido. Suporta PNG, JPEG e BMP. Lança erro se o arquivo não for encontrado.

```lua
local sprite = Tupi.carregarSprite("assets/jogador.png")
```

---

#### `Tupi.destruirSprite(sprite)`

Libera a textura da GPU. Deve ser chamada ao final do jogo ou quando o sprite não for mais necessário.

```lua
Tupi.destruirSprite(sprite)
```

---

#### `Tupi.criarObjeto(x, y, largura, altura, coluna, linha, transparencia, escala, sprite)`

Cria uma instância de objeto para exibir um sprite ou uma célula de sprite sheet na tela.

- `x, y` — posição inicial do canto superior esquerdo
- `largura, altura` — tamanho de cada célula do sprite sheet em pixels
- `coluna, linha` — índice da célula a exibir (base 0)
- `transparencia` — opacidade de `0.0` a `1.0` (padrão: `1.0`)
- `escala` — fator de escala de exibição (padrão: `1.0`)
- `sprite` — ponteiro retornado por `carregarSprite`

```lua
local spr    = Tupi.carregarSprite("assets/jogador.png")
local objeto = Tupi.criarObjeto(100, 200, 32, 32, 0, 0, 1.0, 1.0, spr)
```

---

#### `Tupi.desenharObjeto(objeto)`

Desenha o objeto imediatamente com um draw call individual. Para exibir muitos objetos por frame, prefira o sistema de batch.

```lua
Tupi.desenharObjeto(objeto)
```

---

#### `Tupi.enviarBatch(objeto, z_index?)`

Enfileira o objeto no sistema de batch sem executar nenhuma chamada OpenGL imediatamente.

- `z_index` — profundidade de renderização. Objetos com `z_index` menor são desenhados atrás (padrão: `0`).

```lua
Tupi.enviarBatch(fundo, -1)
Tupi.enviarBatch(jogador, 0)
Tupi.enviarBatch(projetil, 1)
```

---

#### `Tupi.batchDesenhar()`

Executa todos os draw calls acumulados no batch. O Rust ordena os objetos por `z_index` e textura antes de enviar para o OpenGL, minimizando mudanças de estado. Deve ser chamada uma vez por frame, no final da fase de desenho.

```lua
Tupi.batchDesenhar()
```

---

### Animações

O sistema de animação de alto nível gerencia automaticamente o avanço de frames com base no tempo, suportando animações em loop e animações únicas (one-shot).

---

#### `Tupi.criarAnim(sprite, largura, altura, colunas, linhas, fps, loop)`

Cria uma definição de animação a partir de um sprite sheet.

- `colunas` — tabela com os índices de coluna dos frames (ex: `{0, 1, 2, 3}`)
- `linhas` — tabela com os índices de linha correspondentes (ex: `{0, 0, 0, 0}`)
- `fps` — velocidade da animação em frames por segundo (padrão: `8`)
- `loop` — se `true`, a animação reinicia ao terminar (padrão: `true`)

```lua
local sprite = Tupi.carregarSprite("assets/jogador.png")

-- Animação de andar: 4 frames na linha 0, 10fps em loop
local animAndar = Tupi.criarAnim(sprite, 32, 32, {0,1,2,3}, {0,0,0,0}, 10, true)

-- Animação de morrer: 3 frames na linha 2, 6fps sem loop
local animMorrer = Tupi.criarAnim(sprite, 32, 32, {0,1,2}, {2,2,2}, 6, false)
```

---

#### `Tupi.tocarAnim(anim, objeto)`

Avança a animação com base no delta time e envia o frame correto para o batch. Deve ser chamada todo frame durante a fase de desenho.

```lua
Tupi.tocarAnim(animAndar, objeto)
```

---

#### `Tupi.pararAnim(anim, objeto, frame?)`

Para a animação e fixa o objeto em um frame específico (padrão: frame 0).

```lua
Tupi.pararAnim(animAndar, objeto, 0)
```

---

#### `Tupi.animTerminou(anim, objeto)`

Retorna `true` se uma animação one-shot (sem loop) chegou ao último frame.

```lua
if Tupi.animTerminou(animMorrer, objeto) then
    -- remover objeto do jogo
end
```

---

#### `Tupi.animReiniciar(anim, objeto)`

Reinicia o estado da animação do objeto para o frame 0.

```lua
Tupi.animReiniciar(animAndar, objeto)
```

---

#### `Tupi.animLimparObjeto(objeto)`

Remove todos os estados de animação associados a um objeto. Útil ao destruir entidades.

---

### Posição e Movimento de Objetos

Funções de alto nível para manipular a posição de objetos sem acessar a struct diretamente.

---

#### `Tupi.mover(dx, dy, objeto)`

Move o objeto relativamente à posição atual.

```lua
Tupi.mover(velocidade * Tupi.dt(), 0, objeto)
```

---

#### `Tupi.teleportar(x, y, objeto)`

Define a posição absoluta do objeto.

```lua
Tupi.teleportar(400, 300, objeto)
```

---

#### `Tupi.posicaoAtual(objeto)`

Retorna a posição atual `x, y` do objeto.

```lua
local ox, oy = Tupi.posicaoAtual(objeto)
```

---

#### `Tupi.salvarPosicao(objeto)` / `Tupi.ultimaPosicao(objeto)` / `Tupi.voltarPosicao(objeto)`

Salva a posição atual para uso posterior. Útil para reverter movimento após uma colisão.

```lua
Tupi.salvarPosicao(jogador)
Tupi.mover(dx, dy, jogador)

if Tupi.col.retRet(hitboxJogador, parede) then
    Tupi.voltarPosicao(jogador)
end
```

---

#### `Tupi.distanciaObjetos(a, b)`

Retorna a distância em pixels entre dois objetos.

```lua
if Tupi.distanciaObjetos(jogador, inimigo) < 100 then
    print("Inimigo próximo!")
end
```

---

#### `Tupi.moverParaAlvo(tx, ty, fator, objeto)`

Move o objeto suavemente em direção a um ponto usando interpolação linear. O `fator` controla a velocidade (valores menores = mais suave).

```lua
-- Objeto segue o mouse suavemente
Tupi.moverParaAlvo(Tupi.mouseX(), Tupi.mouseY(), 0.1, objeto)
```

---

#### `Tupi.perseguir(alvo, velocidade, objeto)`

Move o objeto na direção de outro objeto com velocidade constante em pixels por frame.

```lua
Tupi.perseguir(jogador, 2, inimigo)
```

---

### Hitbox

---

#### `Tupi.hitbox(objeto, x, y, largura, altura, escalar?)`

Retorna uma tabela de retângulo `{ x, y, largura, altura }` posicionada relativa ao objeto, com suporte ao fator de escala. Use para definir áreas de colisão menores que o sprite visual.

- `x, y` — deslocamento relativo ao canto superior esquerdo do objeto
- `largura, altura` — tamanho da hitbox
- `escalar` — se `false`, ignora a escala do objeto (padrão: `true`)

```lua
-- Hitbox centralizada de 24×28 dentro de um sprite de 32×32
local hb = Tupi.hitbox(jogador, 4, 2, 24, 28)

if Tupi.col.retRet(hb, hitboxInimigo) then
    print("Acertou!")
end
```

---

#### `Tupi.hitboxFixa(objeto, x, y, largura, altura)`

Igual a `hitbox` com `escalar = false`. A hitbox não é afetada pela escala do objeto.

---

#### `Tupi.hitboxDesenhar(hb, cor?, espessura?)`

Desenha a hitbox na tela como um retângulo de borda. Útil para depurar colisões.

```lua
Tupi.hitboxDesenhar(hb, {0, 1, 0, 0.8}, 1)
```

---

### Câmera 2D

O módulo `Tupi.camera` controla uma câmera 2D global que transforma o espaço de renderização. A câmera suporta posição, zoom e rotação.

---

#### `Tupi.camera.reset()`

Reposiciona a câmera para o estado inicial: centro em `(0, 0)`, zoom `1.0`, sem rotação.

---

#### `Tupi.camera.pos(x, y)`

Define a posição do centro da câmera no espaço do mundo.

```lua
Tupi.camera.pos(jogador.x, jogador.y)
```

---

#### `Tupi.camera.mover(dx, dy)`

Move a câmera relativamente à posição atual.

```lua
if Tupi.teclaSegurando(Tupi.TECLA_DIREITA) then
    Tupi.camera.mover(200 * Tupi.dt(), 0)
end
```

---

#### `Tupi.camera.zoom(z)`

Define o fator de zoom. `1.0` é o normal, `2.0` aproxima duas vezes, `0.5` afasta.

```lua
Tupi.camera.zoom(1.5)
```

---

#### `Tupi.camera.rotacao(angulo)`

Define a rotação da câmera em radianos.

```lua
Tupi.camera.rotacao(Tupi.rad(15))  -- inclina 15 graus
```

---

#### `Tupi.camera.seguir(x, y, velocidade?)`

Faz a câmera seguir suavemente um ponto no mundo usando lerp exponencial. O parâmetro `velocidade` controla o fator de suavização (padrão: `0.1`). Use `1.0` para seguimento imediato.

```lua
local px, py = Tupi.posicaoAtual(jogador)
Tupi.camera.seguir(px, py, 0.08)
```

---

#### `Tupi.camera.posAtual()`

Retorna `x, y` da posição atual da câmera.

---

#### `Tupi.camera.zoomAtual()` / `Tupi.camera.rotacaoAtual()`

Retornam o zoom e a rotação atuais da câmera.

---

#### `Tupi.camera.telaMundo(sx, sy)`

Converte uma posição em pixels de tela para coordenadas no espaço do mundo, levando em conta o zoom, rotação e posição da câmera. Essencial para interações com o mouse quando a câmera está ativa.

```lua
local mx, my = Tupi.camera.telaMundo(Tupi.mouseX(), Tupi.mouseY())
-- mx, my agora estão no espaço do mundo
```

---

#### `Tupi.camera.mundoTela(wx, wy)`

Converte coordenadas do mundo para pixels de tela. Útil para posicionar elementos de HUD sobre objetos do jogo.

---

#### `Tupi.camera.mouseMundo()`

Atalho que retorna a posição do mouse diretamente em coordenadas do mundo.

```lua
local mx, my = Tupi.camera.mouseMundo()
```

---

### Utilitários Matemáticos

---

#### `Tupi.lerp(a, b, t)`

Interpolação linear entre `a` e `b`. Com `t = 0` retorna `a`, com `t = 1` retorna `b`.

```lua
local x = Tupi.lerp(0, 800, 0.5)  -- resultado: 400
```

---

#### `Tupi.aleatorio(min, max)`

Retorna um número aleatório de ponto flutuante no intervalo `[min, max]`.

```lua
local x = Tupi.aleatorio(0, 800)
local y = Tupi.aleatorio(0, 600)
```

---

#### `Tupi.rad(graus)`

Converte um ângulo de graus para radianos.

```lua
local angulo = Tupi.rad(90)  -- π/2
```

---

#### `Tupi.graus(rad)`

Converte um ângulo de radianos para graus.

---

#### `Tupi.distancia(x1, y1, x2, y2)`

Retorna a distância euclidiana entre dois pontos.

```lua
local d = Tupi.distancia(0, 0, 300, 400)  -- resultado: 500
```

---

## Constantes

### Teclas especiais

| Constante | Tecla |
|---|---|
| `Tupi.TECLA_ESPACO` | Barra de espaço |
| `Tupi.TECLA_ENTER` | Enter |
| `Tupi.TECLA_ESC` | Escape |
| `Tupi.TECLA_TAB` | Tab |
| `Tupi.TECLA_BACKSPACE` | Backspace |
| `Tupi.TECLA_SHIFT_ESQ` | Shift esquerdo |
| `Tupi.TECLA_SHIFT_DIR` | Shift direito |
| `Tupi.TECLA_CTRL_ESQ` | Ctrl esquerdo |
| `Tupi.TECLA_CTRL_DIR` | Ctrl direito |
| `Tupi.TECLA_ALT_ESQ` | Alt esquerdo |
| `Tupi.TECLA_ALT_DIR` | Alt direito |

### Setas direcionais

`Tupi.TECLA_CIMA` · `Tupi.TECLA_BAIXO` · `Tupi.TECLA_ESQUERDA` · `Tupi.TECLA_DIREITA`

### Letras e números

`Tupi.TECLA_A` a `Tupi.TECLA_Z` · `Tupi.TECLA_0` a `Tupi.TECLA_9`

### Numpad e teclas de função

`Tupi.TECLA_NUM0` a `Tupi.TECLA_NUM9` · `Tupi.TECLA_F1` a `Tupi.TECLA_F12`

### Botões do mouse

| Constante | Botão |
|---|---|
| `Tupi.MOUSE_ESQ` | Botão esquerdo (0) |
| `Tupi.MOUSE_DIR` | Botão direito (1) |
| `Tupi.MOUSE_MEIO` | Botão do meio (2) |

---

## Exemplos Completos

### Mover um quadrado com WASD

```lua
local Tupi = require("src.Engine.TupiEngine")

local x, y  = 400, 300
local vel   = 200

Tupi.janela(800, 600, "Movimento WASD")
Tupi.corFundo(0.08, 0.08, 0.12)

while Tupi.rodando() do
    local dt = Tupi.dt()
    Tupi.limpar()

    if Tupi.teclaSegurando(Tupi.TECLA_W) then y = y - vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_S) then y = y + vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_A) then x = x - vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_D) then x = x + vel * dt end

    Tupi.retangulo(x - 25, y - 25, 50, 50, Tupi.VERDE)

    Tupi.atualizar()
end

Tupi.fechar()
```

---

### Sprite com animação e câmera

```lua
local Tupi = require("src.Engine.TupiEngine")

Tupi.janela(800, 600, "Sprite Animado")
Tupi.corFundo(0.1, 0.1, 0.15)

local spr       = Tupi.carregarSprite("assets/jogador.png")
local objeto    = Tupi.criarObjeto(400, 300, 32, 32, 0, 0, 1.0, 2.0, spr)
local animAndar = Tupi.criarAnim(spr, 32, 32, {0,1,2,3}, {0,0,0,0}, 10, true)
local animParar = Tupi.criarAnim(spr, 32, 32, {0},       {0},       1,  true)

while Tupi.rodando() do
    local dt = Tupi.dt()
    Tupi.limpar()

    local movendo = false

    if Tupi.teclaSegurando(Tupi.TECLA_D) then
        Tupi.mover(150 * dt, 0, objeto)
        movendo = true
    end
    if Tupi.teclaSegurando(Tupi.TECLA_A) then
        Tupi.mover(-150 * dt, 0, objeto)
        movendo = true
    end

    local ox, oy = Tupi.posicaoAtual(objeto)
    Tupi.camera.seguir(ox, oy, 0.1)

    if movendo then
        Tupi.tocarAnim(animAndar, objeto)
    else
        Tupi.tocarAnim(animParar, objeto)
    end

    Tupi.batchDesenhar()
    Tupi.atualizar()
end

Tupi.destruirSprite(spr)
Tupi.fechar()
```

---

### Colisão com separação física

```lua
local Tupi = require("src.Engine.TupiEngine")

Tupi.janela(800, 600, "Colisão AABB")
Tupi.corFundo(0.05, 0.05, 0.1)

local jogador = { x = 100, y = 300, largura = 40, altura = 40 }
local parede  = { x = 350, y = 250, largura = 20, altura = 120 }
local vel     = 180

while Tupi.rodando() do
    local dt = Tupi.dt()
    Tupi.limpar()

    -- Salva posição antes de mover
    local px, py = jogador.x, jogador.y

    if Tupi.teclaSegurando(Tupi.TECLA_D) then jogador.x = jogador.x + vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_A) then jogador.x = jogador.x - vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_S) then jogador.y = jogador.y + vel * dt end
    if Tupi.teclaSegurando(Tupi.TECLA_W) then jogador.y = jogador.y - vel * dt end

    -- Separação por vetor mínimo
    local info = Tupi.col.retRetInfo(jogador, parede)
    if info.colidindo then
        jogador.x = jogador.x + info.dx
        jogador.y = jogador.y + info.dy
    end

    Tupi.retangulo(jogador.x, jogador.y, jogador.largura, jogador.altura, Tupi.AZUL)
    Tupi.retangulo(parede.x,  parede.y,  parede.largura,  parede.altura,  Tupi.VERMELHO)

    Tupi.atualizar()
end

Tupi.fechar()
```

---

### Pintura com clique do mouse

```lua
local Tupi = require("src.Engine.TupiEngine")
local pontos = {}

Tupi.janela(800, 600, "Pintura")
Tupi.corFundo(0.05, 0.05, 0.1)

while Tupi.rodando() do
    Tupi.limpar()

    if Tupi.mouseSegurando(Tupi.MOUSE_ESQ) then
        local x, y = Tupi.mousePos()
        table.insert(pontos, { x = x, y = y })
    end

    if Tupi.teclaPressionou(Tupi.TECLA_C) then
        pontos = {}  -- limpa a tela
    end

    for _, p in ipairs(pontos) do
        Tupi.circulo(p.x, p.y, 6, 16, Tupi.CIANO)
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