// RendererDX11.c
// TupiEngine - Implementação do Sistema de Renderização Direct3D 11
// Windows — equivalente ao RendererGL.c
//
// Usa a mesma camada Rust (renderizador.rs) para:
//   - Asset Manager
//   - Batcher (TupiDrawCall / TupiFlushFn)
//   - Math Core (tupi_projecao_ortografica)
//
// O loop de janela usa Win32 puro (sem GLFW).
// Os shaders HLSL são compilados em runtime com D3DCompileFromMemory.

#include "RendererDX11.h"

// ============================================================
// SHADERS HLSL (formas 2D sem textura — equivalente ao GLSL)
// ============================================================

// Vertex Shader: recebe posição 2D, aplica projeção ortográfica
static const char* _vert_hlsl =
    "cbuffer CBFrame : register(b0) {\n"
    "    float4x4 uProjecao;\n"
    "};\n"
    "float4 VS(float2 pos : POSITION) : SV_Position {\n"
    "    return mul(uProjecao, float4(pos, 0.0f, 1.0f));\n"
    "}\n";

// Pixel Shader: cor sólida via constant buffer
static const char* _frag_hlsl =
    "cbuffer CBCor : register(b1) {\n"
    "    float4 uCor;\n"
    "};\n"
    "float4 PS() : SV_Target {\n"
    "    return uCor;\n"
    "}\n";

// ============================================================
// ESTADO INTERNO
// ============================================================

static HWND    _hwnd     = NULL;
static BOOL    _rodando  = FALSE;
static int     _largura  = 800;
static int     _altura   = 600;
static int     _logico_w = 800;
static int     _logico_h = 600;
static float   _escala_dpi = 1.0f;
static int     _flag_sem_borda = 0;

static float _fundo_r = 0.1f;
static float _fundo_g = 0.1f;
static float _fundo_b = 0.15f;

static float _cor_r = 1.0f;
static float _cor_g = 1.0f;
static float _cor_b = 1.0f;
static float _cor_a = 1.0f;

// ── Tempo ────────────────────────────────────────────────────
static LARGE_INTEGER _freq        = {0};
static LARGE_INTEGER _inicio      = {0};
static double        _delta       = 0.0;
static double        _tempo_prev  = 0.0;

// ── D3D11 ────────────────────────────────────────────────────
static ID3D11Device*           _device      = NULL;
static ID3D11DeviceContext*    _ctx         = NULL;
static IDXGISwapChain*         _swapchain   = NULL;
static ID3D11RenderTargetView* _rtv         = NULL;

static ID3D11VertexShader*     _vs          = NULL;
static ID3D11PixelShader*      _ps          = NULL;
static ID3D11InputLayout*      _layout      = NULL;
static ID3D11Buffer*           _vbo         = NULL;
static ID3D11Buffer*           _cb_frame    = NULL; // b0 — matriz projeção
static ID3D11Buffer*           _cb_cor      = NULL; // b1 — cor RGBA

static ID3D11RasterizerState*  _raster_fill = NULL;
static ID3D11RasterizerState*  _raster_wire = NULL;
static ID3D11BlendState*       _blend       = NULL;

// Matriz de projeção atual (atualizada a cada frame / resize)
static TupiMatriz _mat_proj = {0};

#define TUPI_MAX_VERTICES 1024

// ============================================================
// GETTERS INTERNOS — compatibilidade com Camera.c
// ============================================================

void tupi_dx11_atualizar_projecao(const TupiMatriz* mat) {
    if (!mat || !_ctx || !_cb_frame) return;
    _mat_proj = *mat;
    D3D11_MAPPED_SUBRESOURCE ms;
    if (SUCCEEDED(_ctx->lpVtbl->Map(_ctx, (ID3D11Resource*)_cb_frame, 0,
                                     D3D11_MAP_WRITE_DISCARD, 0, &ms))) {
        memcpy(ms.pData, mat->m, sizeof(mat->m));
        _ctx->lpVtbl->Unmap(_ctx, (ID3D11Resource*)_cb_frame, 0);
    }
}

// ============================================================
// WIN32 — Procedimento de Janela
// ============================================================

static LRESULT CALLBACK _wnd_proc(HWND hwnd, UINT msg,
                                   WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_CLOSE:
        case WM_DESTROY:
            _rodando = FALSE;
            PostQuitMessage(0);
            return 0;

        case WM_SIZE: {
            int w = LOWORD(lp);
            int h = HIWORD(lp);
            if (w > 0 && h > 0 && _swapchain) {
                _largura  = w;
                _altura   = h;
                _logico_w = (int)(w / _escala_dpi);
                _logico_h = (int)(h / _escala_dpi);

                // Libera RTV antes do resize do swapchain
                if (_rtv) {
                    _ctx->lpVtbl->OMSetRenderTargets(_ctx, 0, NULL, NULL);
                    _rtv->lpVtbl->Release(_rtv);
                    _rtv = NULL;
                }

                _swapchain->lpVtbl->ResizeBuffers(_swapchain, 0,
                    (UINT)w, (UINT)h, DXGI_FORMAT_UNKNOWN, 0);

                // Recria RTV
                ID3D11Texture2D* back = NULL;
                _swapchain->lpVtbl->GetBuffer(_swapchain, 0,
                    &IID_ID3D11Texture2D, (void**)&back);
                _device->lpVtbl->CreateRenderTargetView(_device,
                    (ID3D11Resource*)back, NULL, &_rtv);
                back->lpVtbl->Release(back);
                _ctx->lpVtbl->OMSetRenderTargets(_ctx, 1, &_rtv, NULL);

                // Viewport físico
                D3D11_VIEWPORT vp = {
                    .TopLeftX = 0, .TopLeftY = 0,
                    .Width    = (float)w,
                    .Height   = (float)h,
                    .MinDepth = 0.0f, .MaxDepth = 1.0f
                };
                _ctx->lpVtbl->RSSetViewports(_ctx, 1, &vp);

                // Atualiza projeção com coordenadas lógicas
                TupiMatriz m = tupi_projecao_ortografica(_logico_w, _logico_h);
                tupi_dx11_atualizar_projecao(&m);
            }
            return 0;
        }

        default:
            return DefWindowProcA(hwnd, msg, wp, lp);
    }
}

// ============================================================
// HELPERS — Compilação de Shader HLSL em runtime
// ============================================================

static ID3DBlob* _compilar_shader_hlsl(const char* src,
                                        const char* entry,
                                        const char* perfil) {
    ID3DBlob* blob  = NULL;
    ID3DBlob* erros = NULL;
    HRESULT hr = D3DCompile(src, strlen(src), NULL, NULL, NULL,
                             entry, perfil,
                             D3DCOMPILE_ENABLE_STRICTNESS, 0,
                             &blob, &erros);
    if (FAILED(hr)) {
        if (erros) {
            fprintf(stderr, "[TupiEngine] Erro HLSL (%s): %s\n",
                    entry,
                    (const char*)erros->lpVtbl->GetBufferPointer(erros));
            erros->lpVtbl->Release(erros);
        }
        return NULL;
    }
    if (erros) erros->lpVtbl->Release(erros);
    return blob;
}

// ============================================================
// HELPER — Criação de Constant Buffer genérico
// ============================================================

static ID3D11Buffer* _criar_cb(UINT tamanho_bytes) {
    D3D11_BUFFER_DESC desc = {
        .ByteWidth      = tamanho_bytes,
        .Usage          = D3D11_USAGE_DYNAMIC,
        .BindFlags      = D3D11_BIND_CONSTANT_BUFFER,
        .CPUAccessFlags = D3D11_CPU_ACCESS_WRITE,
    };
    ID3D11Buffer* buf = NULL;
    _device->lpVtbl->CreateBuffer(_device, &desc, NULL, &buf);
    return buf;
}

// ============================================================
// BATCHER — Flush Callback (C recebe draw calls do Rust)
// ============================================================

// Topologias D3D11 por tipo de primitiva
static D3D11_PRIMITIVE_TOPOLOGY _topologia(TupiPrimitiva p, int n_verts) {
    switch (p) {
        case TUPI_RET: return D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP;
        case TUPI_TRI: return D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
        case TUPI_LIN: return D3D11_PRIMITIVE_TOPOLOGY_LINELIST;
        default:       return D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
    }
}

// Forward declaration
static void _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY topo,
                            float* verts, int n);

static void _flush_batcher(const TupiDrawCall* calls, int n) {
    for (int i = 0; i < n; i++) {
        const TupiDrawCall* dc = &calls[i];
        _cor_r = dc->cor[0];
        _cor_g = dc->cor[1];
        _cor_b = dc->cor[2];
        _cor_a = dc->cor[3];

        D3D11_PRIMITIVE_TOPOLOGY topo =
            _topologia(dc->primitiva, dc->n_verts);
        int n_verts = dc->n_verts / 2; // n_verts no DrawCall = floats; /2 = vértices XY

        _dx11_desenhar(topo, (float*)dc->verts, n_verts);
    }
}

// ============================================================
// DRAW CALL GENÉRICO (formas 2D)
// ============================================================

static void _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY topo,
                            float* verts, int n) {
    if (!_ctx || !_vbo || n <= 0) return;

    // Atualiza o VBO com os vértices atuais
    D3D11_MAPPED_SUBRESOURCE ms;
    if (FAILED(_ctx->lpVtbl->Map(_ctx, (ID3D11Resource*)_vbo, 0,
                                  D3D11_MAP_WRITE_DISCARD, 0, &ms))) return;
    memcpy(ms.pData, verts, sizeof(float) * 2 * n);
    _ctx->lpVtbl->Unmap(_ctx, (ID3D11Resource*)_vbo, 0);

    // Atualiza cor no CB b1
    if (_cb_cor) {
        float cor4[4] = { _cor_r, _cor_g, _cor_b, _cor_a };
        if (SUCCEEDED(_ctx->lpVtbl->Map(_ctx, (ID3D11Resource*)_cb_cor, 0,
                                         D3D11_MAP_WRITE_DISCARD, 0, &ms))) {
            memcpy(ms.pData, cor4, sizeof(cor4));
            _ctx->lpVtbl->Unmap(_ctx, (ID3D11Resource*)_cb_cor, 0);
        }
    }

    UINT stride = sizeof(float) * 2;
    UINT offset = 0;
    _ctx->lpVtbl->IASetVertexBuffers(_ctx, 0, 1, &_vbo, &stride, &offset);
    _ctx->lpVtbl->IASetPrimitiveTopology(_ctx, topo);
    _ctx->lpVtbl->Draw(_ctx, (UINT)n, 0);
}

// ============================================================
// CRIAÇÃO DE JANELA
// ============================================================

int tupi_janela_criar(int largura, int altura, const char* titulo) {
    return tupi_janela_criar_ex(largura, altura, titulo, 1.0f, 0, 0);
}

int tupi_janela_criar_ex(int largura, int altura, const char* titulo,
                          float escala, int sem_borda, int sem_texto) {

    QueryPerformanceFrequency(&_freq);
    QueryPerformanceCounter(&_inicio);

    // ── Registra classe de janela Win32 ──────────────────────
    WNDCLASSEXA wc = {
        .cbSize        = sizeof(wc),
        .style         = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc   = _wnd_proc,
        .hInstance     = GetModuleHandleA(NULL),
        .hCursor       = LoadCursor(NULL, IDC_ARROW),
        .lpszClassName = "TupiEngineWnd",
    };
    RegisterClassExA(&wc);

    DWORD estilo = sem_borda
        ? WS_POPUP
        : WS_OVERLAPPEDWINDOW;

    const char* titulo_real = (sem_texto || sem_borda) ? "" : titulo;

    // Ajusta rect para que a área cliente seja exatamente largura×altura
    RECT rect = { 0, 0, largura, altura };
    AdjustWindowRect(&rect, estilo, FALSE);

    _hwnd = CreateWindowExA(
        0,
        "TupiEngineWnd",
        titulo_real,
        estilo,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rect.right - rect.left,
        rect.bottom - rect.top,
        NULL, NULL,
        GetModuleHandleA(NULL),
        NULL
    );

    if (!_hwnd) {
        fprintf(stderr, "[TupiEngine] Falha ao criar janela Win32!\n");
        return 0;
    }

    _largura         = largura;
    _altura          = altura;
    _escala_dpi      = (escala > 0.0f) ? escala : 1.0f;
    _flag_sem_borda  = sem_borda;
    _logico_w        = (int)(largura  / _escala_dpi);
    _logico_h        = (int)(altura   / _escala_dpi);

    // ── D3D11: Device + SwapChain ─────────────────────────────
    DXGI_SWAP_CHAIN_DESC scd = {
        .BufferCount       = 2,
        .BufferDesc.Width  = (UINT)largura,
        .BufferDesc.Height = (UINT)altura,
        .BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM,
        .BufferDesc.RefreshRate.Numerator   = 60,
        .BufferDesc.RefreshRate.Denominator = 1,
        .BufferUsage       = DXGI_USAGE_RENDER_TARGET_OUTPUT,
        .OutputWindow      = _hwnd,
        .SampleDesc.Count  = 4,  // MSAA 4x (equivalente ao GLFW_SAMPLES 4)
        .SampleDesc.Quality= 0,
        .Windowed          = TRUE,
        .SwapEffect        = DXGI_SWAP_EFFECT_DISCARD,
        .Flags             = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH,
    };

    D3D_FEATURE_LEVEL niveis[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1 };
    D3D_FEATURE_LEVEL nivel_obtido;
    UINT flags = 0;
#ifdef _DEBUG
    flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    HRESULT hr = D3D11CreateDeviceAndSwapChain(
        NULL, D3D_DRIVER_TYPE_HARDWARE, NULL,
        flags, niveis, 2,
        D3D11_SDK_VERSION,
        &scd, &_swapchain,
        &_device, &nivel_obtido, &_ctx
    );

    if (FAILED(hr)) {
        fprintf(stderr, "[TupiEngine] Falha ao criar dispositivo D3D11! HRESULT=0x%08X\n", hr);
        DestroyWindow(_hwnd);
        return 0;
    }

    // ── Render Target View ────────────────────────────────────
    ID3D11Texture2D* back = NULL;
    _swapchain->lpVtbl->GetBuffer(_swapchain, 0,
        &IID_ID3D11Texture2D, (void**)&back);
    _device->lpVtbl->CreateRenderTargetView(_device,
        (ID3D11Resource*)back, NULL, &_rtv);
    back->lpVtbl->Release(back);

    _ctx->lpVtbl->OMSetRenderTargets(_ctx, 1, &_rtv, NULL);

    // ── Viewport ─────────────────────────────────────────────
    D3D11_VIEWPORT vp = {
        .TopLeftX = 0, .TopLeftY = 0,
        .Width    = (float)largura,
        .Height   = (float)altura,
        .MinDepth = 0.0f, .MaxDepth = 1.0f
    };
    _ctx->lpVtbl->RSSetViewports(_ctx, 1, &vp);

    // ── Compila Shaders HLSL ──────────────────────────────────
    ID3DBlob* vs_blob = _compilar_shader_hlsl(_vert_hlsl, "VS", "vs_4_0");
    ID3DBlob* ps_blob = _compilar_shader_hlsl(_frag_hlsl, "PS", "ps_4_0");
    if (!vs_blob || !ps_blob) {
        fprintf(stderr, "[TupiEngine] Falha ao compilar shaders HLSL!\n");
        return 0;
    }

    _device->lpVtbl->CreateVertexShader(_device,
        vs_blob->lpVtbl->GetBufferPointer(vs_blob),
        vs_blob->lpVtbl->GetBufferSize(vs_blob),
        NULL, &_vs);

    _device->lpVtbl->CreatePixelShader(_device,
        ps_blob->lpVtbl->GetBufferPointer(ps_blob),
        ps_blob->lpVtbl->GetBufferSize(ps_blob),
        NULL, &_ps);

    // ── Input Layout: POSITION = float2 ──────────────────────
    D3D11_INPUT_ELEMENT_DESC layout_desc[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 0,
          D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    _device->lpVtbl->CreateInputLayout(_device,
        layout_desc, 1,
        vs_blob->lpVtbl->GetBufferPointer(vs_blob),
        vs_blob->lpVtbl->GetBufferSize(vs_blob),
        &_layout);

    vs_blob->lpVtbl->Release(vs_blob);
    ps_blob->lpVtbl->Release(ps_blob);

    // ── VBO dinâmico ─────────────────────────────────────────
    D3D11_BUFFER_DESC vbd = {
        .ByteWidth      = sizeof(float) * 2 * TUPI_MAX_VERTICES,
        .Usage          = D3D11_USAGE_DYNAMIC,
        .BindFlags      = D3D11_BIND_VERTEX_BUFFER,
        .CPUAccessFlags = D3D11_CPU_ACCESS_WRITE,
    };
    _device->lpVtbl->CreateBuffer(_device, &vbd, NULL, &_vbo);

    // ── Constant Buffers ──────────────────────────────────────
    // b0: matriz projeção (16 floats = 64 bytes)
    _cb_frame = _criar_cb(64);
    // b1: cor RGBA (4 floats = 16 bytes)
    _cb_cor   = _criar_cb(16);

    _ctx->lpVtbl->VSSetConstantBuffers(_ctx, 0, 1, &_cb_frame);
    _ctx->lpVtbl->PSSetConstantBuffers(_ctx, 1, 1, &_cb_cor);

    // ── Rasterizer: fill e wire ───────────────────────────────
    D3D11_RASTERIZER_DESC rd_fill = {
        .FillMode              = D3D11_FILL_SOLID,
        .CullMode              = D3D11_CULL_NONE,
        .ScissorEnable         = FALSE,
        .MultisampleEnable     = TRUE,
        .AntialiasedLineEnable = TRUE,
    };
    D3D11_RASTERIZER_DESC rd_wire = rd_fill;
    rd_wire.FillMode = D3D11_FILL_WIREFRAME;

    _device->lpVtbl->CreateRasterizerState(_device, &rd_fill, &_raster_fill);
    _device->lpVtbl->CreateRasterizerState(_device, &rd_wire, &_raster_wire);
    _ctx->lpVtbl->RSSetState(_ctx, _raster_fill);

    // ── Alpha Blend (equivalente ao glBlendFunc OpenGL) ───────
    D3D11_BLEND_DESC blend_desc = {0};
    blend_desc.RenderTarget[0] = (D3D11_RENDER_TARGET_BLEND_DESC){
        .BlendEnable           = TRUE,
        .SrcBlend              = D3D11_BLEND_SRC_ALPHA,
        .DestBlend             = D3D11_BLEND_INV_SRC_ALPHA,
        .BlendOp               = D3D11_BLEND_OP_ADD,
        .SrcBlendAlpha         = D3D11_BLEND_ONE,
        .DestBlendAlpha        = D3D11_BLEND_ZERO,
        .BlendOpAlpha          = D3D11_BLEND_OP_ADD,
        .RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL,
    };
    _device->lpVtbl->CreateBlendState(_device, &blend_desc, &_blend);
    float blend_factor[4] = {0,0,0,0};
    _ctx->lpVtbl->OMSetBlendState(_ctx, _blend, blend_factor, 0xFFFFFFFF);

    // ── Bind shaders e layout ─────────────────────────────────
    _ctx->lpVtbl->IASetInputLayout(_ctx, _layout);
    _ctx->lpVtbl->VSSetShader(_ctx, _vs, NULL, 0);
    _ctx->lpVtbl->PSSetShader(_ctx, _ps, NULL, 0);

    // ── Projeção inicial ──────────────────────────────────────
    TupiMatriz m = tupi_projecao_ortografica(_logico_w, _logico_h);
    tupi_dx11_atualizar_projecao(&m);

    // ── Batcher (Rust) ────────────────────────────────────────
    tupi_batcher_registrar_flush(_flush_batcher);

    ShowWindow(_hwnd, SW_SHOWDEFAULT);
    UpdateWindow(_hwnd);
    _rodando = TRUE;

    _tempo_prev = tupi_tempo();

    printf("[TupiEngine] Direct3D 11 inicializado (feature level 0x%04X)\n",
           (unsigned)nivel_obtido);
    printf("[TupiEngine] Janela criada: %dx%d (logico: %dx%d, escala: %.1f) - '%s'\n",
           largura, altura, _logico_w, _logico_h, _escala_dpi,
           titulo);
    printf("[TupiEngine] Bem-vindo a TupiEngine! Versao 0.3 (DX11 backend)\n");

    return 1;
}

// ============================================================
// LOOP PRINCIPAL
// ============================================================

int tupi_janela_aberta(void) {
    MSG msg = {0};
    while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
        if (msg.message == WM_QUIT) _rodando = FALSE;
    }
    return _rodando;
}

void tupi_janela_limpar(void) {
    double agora = tupi_tempo();
    _delta      = agora - _tempo_prev;
    _tempo_prev = agora;

    float bg[4] = { _fundo_r, _fundo_g, _fundo_b, 1.0f };
    _ctx->lpVtbl->ClearRenderTargetView(_ctx, _rtv, bg);

    // Atualiza câmera (Camera.c pode recalcular a projeção aqui)
    // tupi_camera_frame(_logico_w, _logico_h); // descomente quando Camera.c for portado
}

void tupi_janela_atualizar(void) {
    tupi_batcher_flush();
    _swapchain->lpVtbl->Present(_swapchain, 1, 0); // VSync ativo (1)
    // tupi_input_salvar_estado();   // descomente quando Inputs.c for portado para Win32
    // tupi_input_atualizar_mouse();
}

void tupi_janela_fechar(void) {
    // Libera recursos D3D11 em ordem inversa de criação
    if (_blend)       { _blend->lpVtbl->Release(_blend);             _blend       = NULL; }
    if (_raster_wire) { _raster_wire->lpVtbl->Release(_raster_wire); _raster_wire = NULL; }
    if (_raster_fill) { _raster_fill->lpVtbl->Release(_raster_fill); _raster_fill = NULL; }
    if (_cb_cor)      { _cb_cor->lpVtbl->Release(_cb_cor);           _cb_cor      = NULL; }
    if (_cb_frame)    { _cb_frame->lpVtbl->Release(_cb_frame);       _cb_frame    = NULL; }
    if (_vbo)         { _vbo->lpVtbl->Release(_vbo);                 _vbo         = NULL; }
    if (_layout)      { _layout->lpVtbl->Release(_layout);           _layout      = NULL; }
    if (_ps)          { _ps->lpVtbl->Release(_ps);                   _ps          = NULL; }
    if (_vs)          { _vs->lpVtbl->Release(_vs);                   _vs          = NULL; }
    if (_rtv)         { _rtv->lpVtbl->Release(_rtv);                 _rtv         = NULL; }
    if (_swapchain)   { _swapchain->lpVtbl->Release(_swapchain);     _swapchain   = NULL; }
    if (_ctx)         { _ctx->lpVtbl->Release(_ctx);                 _ctx         = NULL; }
    if (_device)      { _device->lpVtbl->Release(_device);           _device      = NULL; }
    if (_hwnd)        { DestroyWindow(_hwnd);                        _hwnd        = NULL; }
    printf("[TupiEngine] Janela fechada. Ate mais!\n");
}

// ============================================================
// CONTROLES DE JANELA EM TEMPO DE EXECUÇÃO
// ============================================================

void tupi_janela_set_titulo(const char* titulo) {
    if (_hwnd && titulo) SetWindowTextA(_hwnd, titulo);
}

void tupi_janela_set_decoracao(int ativo) {
    if (!_hwnd) return;
    DWORD estilo = ativo ? WS_OVERLAPPEDWINDOW : WS_POPUP;
    SetWindowLongA(_hwnd, GWL_STYLE, (LONG)estilo);
    SetWindowPos(_hwnd, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    _flag_sem_borda = !ativo;
}

void tupi_janela_tela_cheia(int ativo) {
    if (!_hwnd || !_swapchain) return;
    if (ativo) {
        // Modo exclusivo fullscreen via DXGI
        IDXGIOutput* output = NULL;
        _swapchain->lpVtbl->SetFullscreenState(_swapchain, TRUE, output);
    } else {
        _swapchain->lpVtbl->SetFullscreenState(_swapchain, FALSE, NULL);
    }
}

// ============================================================
// TEMPO
// ============================================================

double tupi_tempo(void) {
    LARGE_INTEGER agora;
    QueryPerformanceCounter(&agora);
    return (double)(agora.QuadPart - _inicio.QuadPart) / (double)_freq.QuadPart;
}

double tupi_delta_tempo(void) { return _delta; }

// ============================================================
// DIMENSÕES
// ============================================================

int   tupi_janela_largura(void)    { return _logico_w;  }
int   tupi_janela_altura(void)     { return _logico_h;  }
int   tupi_janela_largura_px(void) { return _largura;   }
int   tupi_janela_altura_px(void)  { return _altura;    }
float tupi_janela_escala(void)     { return _escala_dpi; }

// ============================================================
// COR
// ============================================================

void tupi_cor_fundo(float r, float g, float b) {
    _fundo_r = r; _fundo_g = g; _fundo_b = b;
}

void tupi_cor(float r, float g, float b, float a) {
    _cor_r = r; _cor_g = g; _cor_b = b; _cor_a = a;
}

// ============================================================
// FORMAS 2D — mesma API do RendererGL.c
// ============================================================

void tupi_retangulo(float x, float y, float largura, float altura) {
    float ts[8] = {
        x,           y,
        x + largura, y,
        x,           y + altura,
        x + largura, y + altura,
    };
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP, ts, 4);
}

void tupi_retangulo_borda(float x, float y, float largura, float altura, float espessura) {
    // Wireframe temporário via rasterizer swap
    _ctx->lpVtbl->RSSetState(_ctx, _raster_wire);
    float v[8] = { x, y,  x+largura, y,  x+largura, y+altura,  x, y+altura };
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP, v, 4);
    _ctx->lpVtbl->RSSetState(_ctx, _raster_fill);
    (void)espessura; // D3D11 não suporta line width > 1 — deixamos como nota
}

void tupi_triangulo(float x1, float y1, float x2, float y2, float x3, float y3) {
    float v[6] = { x1, y1, x2, y2, x3, y3 };
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST, v, 3);
}

void tupi_circulo(float x, float y, float raio, int segmentos) {
    if (segmentos > TUPI_MAX_VERTICES - 2)
        segmentos = TUPI_MAX_VERTICES - 2;

    // TRIANGLE_FAN não existe em D3D11 — triangulamos manualmente
    // (centro + dois pontos consecutivos = triângulo)
    float verts[TUPI_MAX_VERTICES * 2];
    int n = 0;
    for (int i = 0; i < segmentos; i++) {
        float a0 = (float)i       / (float)segmentos * 2.0f * (float)M_PI;
        float a1 = (float)(i + 1) / (float)segmentos * 2.0f * (float)M_PI;
        verts[n++] = x;
        verts[n++] = y;
        verts[n++] = x + cosf(a0) * raio;
        verts[n++] = y + sinf(a0) * raio;
        verts[n++] = x + cosf(a1) * raio;
        verts[n++] = y + sinf(a1) * raio;
    }
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST, verts, segmentos * 3);
}

void tupi_circulo_borda(float x, float y, float raio, int segmentos, float espessura) {
    if (segmentos > TUPI_MAX_VERTICES) segmentos = TUPI_MAX_VERTICES;
    float verts[TUPI_MAX_VERTICES * 2];
    int n = 0;
    for (int i = 0; i < segmentos; i++) {
        float a = (float)i / (float)segmentos * 2.0f * (float)M_PI;
        verts[n++] = x + cosf(a) * raio;
        verts[n++] = y + sinf(a) * raio;
    }
    // Fecha o loop adicionando o primeiro ponto novamente
    verts[n++] = verts[0];
    verts[n++] = verts[1];
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP, verts, segmentos + 1);
    (void)espessura;
}

void tupi_linha(float x1, float y1, float x2, float y2, float espessura) {
    float v[4] = { x1, y1, x2, y2 };
    _dx11_desenhar(D3D11_PRIMITIVE_TOPOLOGY_LINELIST, v, 2);
    (void)espessura;
}