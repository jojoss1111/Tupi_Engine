// RendererGL.rs
// TupiEngine - Camada de Segurança Rust para o RendererGL.c
//
// Este arquivo NÃO chama OpenGL diretamente.
// Ele valida, organiza e entrega dados limpos para o C.
//
// Três sistemas:
//   1. AssetManager  — carrega arquivos com Result, nunca entrega ponteiro nulo
//   2. Batcher       — agrupa draw calls e faz flush automático antes de estourar
//   3. MatrizProj    — calcula a projeção ortográfica com validação de NaN/zero
//
// O C chama as funções exportadas com #[no_mangle] / extern "C".

use std::ffi::{c_float, c_int, CStr};
use std::os::raw::c_char;

// ============================================================
// 1. ASSET MANAGER
// ============================================================
// Lê um arquivo binário (PNG, shader GLSL, etc.) do disco.
// Valida que o arquivo existe, não está vazio e retorna os
// bytes em um buffer alocado — junto com o tamanho exato.
//
// O C recebe: (*mut u8, usize) — ponteiro + tamanho.
// Nunca recebe NULL. Se algo der errado, o Rust loga e retorna
// um TupiAsset com ptr=null + tamanho=0 (o C checa o tamanho).
// ============================================================

/// Resultado de um carregamento de asset
#[repr(C)]
pub struct TupiAsset {
    /// Ponteiro para os bytes do arquivo (alocado pelo Rust, libere com tupi_asset_liberar)
    pub ptr:    *mut u8,
    /// Tamanho em bytes — 0 indica falha
    pub tamanho: usize,
}

impl TupiAsset {
    fn vazio() -> Self {
        TupiAsset { ptr: std::ptr::null_mut(), tamanho: 0 }
    }
}

/// Carrega um arquivo do disco e retorna os bytes brutos.
/// O C verifica `asset.tamanho > 0` antes de usar `asset.ptr`.
///
/// # Segurança
/// - Nunca retorna ponteiro nulo com tamanho > 0
/// - Loga o erro no stderr antes de retornar vazio
#[no_mangle]
pub extern "C" fn tupi_asset_carregar(caminho: *const c_char) -> TupiAsset {
    // Converte o *const c_char para &str com segurança
    let path_str = match unsafe { CStr::from_ptr(caminho) }.to_str() {
        Ok(s)  => s,
        Err(e) => {
            eprintln!("[TupiAsset] Caminho inválido (UTF-8): {e}");
            return TupiAsset::vazio();
        }
    };

    // Lê o arquivo — erros de I/O viram log, nunca panic
    let bytes = match std::fs::read(path_str) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("[TupiAsset] Falha ao ler '{path_str}': {e}");
            return TupiAsset::vazio();
        }
    };

    if bytes.is_empty() {
        eprintln!("[TupiAsset] Arquivo vazio: '{path_str}'");
        return TupiAsset::vazio();
    }

    // Detecta cabeçalho PNG (89 50 4E 47) se a extensão for .png
    if path_str.ends_with(".png") {
        if bytes.len() < 4 || &bytes[0..4] != b"\x89PNG" {
            eprintln!("[TupiAsset] '{path_str}' não é um PNG válido (cabeçalho incorreto)");
            return TupiAsset::vazio();
        }
    }

    let tamanho = bytes.len();

    // Transforma o Vec em um buffer gerenciado manualmente
    // (o C precisa de um ponteiro estável — Vec pode realocar)
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed); // Rust não libera — o C chama tupi_asset_liberar

    println!("[TupiAsset] '{path_str}' carregado ({tamanho} bytes)");
    TupiAsset { ptr, tamanho }
}

/// Libera a memória alocada por tupi_asset_carregar.
/// Deve ser chamada pelo C após o dado ser enviado para a GPU.
#[no_mangle]
pub extern "C" fn tupi_asset_liberar(asset: TupiAsset) {
    if asset.ptr.is_null() || asset.tamanho == 0 {
        return;
    }
    // Reconstrói o Box<[u8]> e deixa o Rust liberar
    unsafe {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(asset.ptr, asset.tamanho));
    }
}

// ============================================================
// 2. BATCHER
// ============================================================
// Recebe intenções de desenho (retângulos, círculos, linhas)
// e as acumula em um buffer interno.
//
// Quando o buffer está cheio (ou tupi_batcher_flush é chamado),
// o Rust envia tudo de uma vez para o C via callback — o C
// então chama glBufferSubData uma única vez por flush.
//
// Isso garante que TUPI_MAX_VERTICES (1024) nunca seja estourado.
// ============================================================

const MAX_VERTICES: usize = 1024; // deve bater com o C

/// Tipo de primitiva a desenhar
#[repr(C)]
#[derive(Clone, Copy, PartialEq)]
pub enum TupiPrimitiva {
    Retangulo  = 0,
    Circulo    = 1,
    Linha      = 2,
    Triangulo  = 3,
}

/// Uma intenção de desenho ainda não enviada à GPU
#[repr(C)]
#[derive(Clone, Copy)]
pub struct TupiDrawCall {
    pub primitiva: TupiPrimitiva,
    /// Vértices do draw call (máximo 8 floats por primitiva simples)
    pub verts:    [c_float; 8],
    /// Quantos floats de `verts` são válidos
    pub n_verts:  c_int,
    /// Cor RGBA
    pub cor:      [c_float; 4],
}

/// O batcher acumula draw calls e avisa o C quando deve fazer flush
pub struct Batcher {
    fila:         Vec<TupiDrawCall>,
    verts_usados: usize,
}

impl Batcher {
    pub fn novo() -> Self {
        Batcher { fila: Vec::with_capacity(256), verts_usados: 0 }
    }

    /// Quantos vértices esse draw call vai consumir no VBO
    fn tamanho_em_verts(dc: &TupiDrawCall) -> usize {
        (dc.n_verts as usize) / 2 // cada vértice = (x, y)
    }

    /// Adiciona um draw call. Retorna true se fez flush automático.
    pub fn adicionar(&mut self, dc: TupiDrawCall, flush_fn: impl Fn(&[TupiDrawCall])) -> bool {
        let verts_novos = Self::tamanho_em_verts(&dc);

        // Se não couber, faz flush antes de adicionar
        if self.verts_usados + verts_novos > MAX_VERTICES {
            eprintln!(
                "[TupiBatcher] Buffer cheio ({}/{MAX_VERTICES} verts) — flush automático",
                self.verts_usados
            );
            flush_fn(&self.fila);
            self.fila.clear();
            self.verts_usados = 0;

            return true; // flush aconteceu
        }

        self.fila.push(dc);
        self.verts_usados += verts_novos;
        false
    }

    /// Envia tudo que está na fila e limpa
    pub fn flush(&mut self, flush_fn: impl Fn(&[TupiDrawCall])) {
        if !self.fila.is_empty() {
            flush_fn(&self.fila);
            self.fila.clear();
            self.verts_usados = 0;
        }
    }

    pub fn tamanho(&self) -> usize { self.fila.len() }
}

// ── API C do Batcher ─────────────────────────────────────────
// O Rust mantém um Batcher global (thread_local para segurança).
// O C chama tupi_batcher_* para enfileirar e fazer flush.

use std::cell::RefCell;

thread_local! {
    static BATCHER: RefCell<Batcher> = RefCell::new(Batcher::novo());
}

/// Callback que o C deve registrar — recebe o slice de draw calls prontos
/// Assinatura C: void meu_flush(const TupiDrawCall* calls, int n);
type FlushFn = unsafe extern "C" fn(calls: *const TupiDrawCall, n: c_int);

thread_local! {
    static FLUSH_CB: RefCell<Option<FlushFn>> = RefCell::new(None);
}

/// Registra a função de flush do C (chame uma vez na inicialização)
#[no_mangle]
pub extern "C" fn tupi_batcher_registrar_flush(cb: FlushFn) {
    FLUSH_CB.with(|f| *f.borrow_mut() = Some(cb));
}

/// Enfileira um draw call. Faz flush automático se o buffer estiver cheio.
#[no_mangle]
pub extern "C" fn tupi_batcher_adicionar(dc: TupiDrawCall) {
    FLUSH_CB.with(|cb_cell| {
        let cb_opt = cb_cell.borrow();
        if let Some(cb) = *cb_opt {
            BATCHER.with(|b| {
                b.borrow_mut().adicionar(dc, |fila| unsafe {
                    cb(fila.as_ptr(), fila.len() as c_int);
                });
            });
        } else {
            eprintln!("[TupiBatcher] Flush não registrado! Chame tupi_batcher_registrar_flush primeiro.");
        }
    });
}

/// Força o envio de tudo que está na fila (chame no fim de cada frame)
#[no_mangle]
pub extern "C" fn tupi_batcher_flush() {
    FLUSH_CB.with(|cb_cell| {
        let cb_opt = cb_cell.borrow();
        if let Some(cb) = *cb_opt {
            BATCHER.with(|b| {
                b.borrow_mut().flush(|fila| unsafe {
                    cb(fila.as_ptr(), fila.len() as c_int);
                });
            });
        }
    });
}

/// Retorna quantos draw calls estão na fila (útil para debug)
#[no_mangle]
pub extern "C" fn tupi_batcher_tamanho() -> c_int {
    BATCHER.with(|b| b.borrow().tamanho() as c_int)
}

// ============================================================
// 3. MATH CORE — Matriz de Projeção Ortográfica
// ============================================================
// Calcula a matriz uProjecao que o RendererGL.c envia ao shader.
// Valida os parâmetros antes de calcular:
//   - largura e altura devem ser > 0 (evita divisão por zero)
//   - nenhum elemento do resultado pode ser NaN ou infinito
//
// Se a validação falhar, retorna a identidade e loga o erro.
// O C recebe um float[16] sempre válido.
// ============================================================

/// Resultado da projeção — sempre 16 floats válidos
#[repr(C)]
pub struct TupiMatriz {
    pub m: [c_float; 16],
}

impl TupiMatriz {
    /// Matriz identidade (fallback seguro)
    fn identidade() -> Self {
        TupiMatriz { m: [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        ]}
    }
}

/// Calcula a projeção ortográfica com origem no canto superior esquerdo.
/// Y cresce para baixo (compatível com o RendererGL.c atual).
///
/// Equivalente ao glOrtho(0, largura, altura, 0, -1, 1) do OpenGL.
///
/// Retorna identidade se largura <= 0 ou altura <= 0.
#[no_mangle]
pub extern "C" fn tupi_projecao_ortografica(largura: c_int, altura: c_int) -> TupiMatriz {
    if largura <= 0 || altura <= 0 {
        eprintln!("[TupiMath] Dimensões inválidas para projeção: {largura}x{altura}");
        return TupiMatriz::identidade();
    }

    let l: f32 = 0.0;
    let r: f32 = largura as f32;
    let t: f32 = 0.0;       // topo = 0 (origem no canto superior esquerdo)
    let b: f32 = altura as f32;
    let n: f32 = -1.0;
    let f: f32 = 1.0;

    // Projeção ortográfica column-major (formato OpenGL)
    let m = [
        2.0/(r-l),     0.0,           0.0,          0.0,
        0.0,           2.0/(t-b),     0.0,          0.0,
        0.0,           0.0,          -2.0/(f-n),    0.0,
        -(r+l)/(r-l), -(t+b)/(t-b), -(f+n)/(f-n),  1.0_f32,
    ];

    // Valida cada elemento — NaN ou infinito não devem chegar ao shader
    for (i, v) in m.iter().enumerate() {
        if !v.is_finite() {
            eprintln!("[TupiMath] Elemento [{i}] da matriz é NaN/infinito para {largura}x{altura}");
            return TupiMatriz::identidade();
        }
    }

    TupiMatriz { m }
}

/// Multiplica duas matrizes 4x4 column-major (útil para transformações futuras)
/// Resultado: C = A * B
#[no_mangle]
pub extern "C" fn tupi_mat4_multiplicar(a: *const TupiMatriz, b: *const TupiMatriz) -> TupiMatriz {
    if a.is_null() || b.is_null() {
        eprintln!("[TupiMath] tupi_mat4_multiplicar: ponteiro nulo");
        return TupiMatriz::identidade();
    }

    let a = unsafe { &(*a).m };
    let b = unsafe { &(*b).m };
    let mut c = [0.0_f32; 16];

    // Multiplicação column-major: C[col*4 + row] = sum(A[k*4+row] * B[col*4+k])
    for col in 0..4 {
        for row in 0..4 {
            let mut soma = 0.0_f32;
            for k in 0..4 {
                soma += a[k * 4 + row] * b[col * 4 + k];
            }
            c[col * 4 + row] = soma;
        }
    }

    TupiMatriz { m: c }
}

// ============================================================
// TESTES
// ============================================================

#[cfg(test)]
mod testes {
    use super::*;

    // -- AssetManager --

    #[test]
    fn asset_arquivo_inexistente_retorna_vazio() {
        use std::ffi::CString;
        let caminho = CString::new("nao_existe.png").unwrap();
        let asset = tupi_asset_carregar(caminho.as_ptr());
        assert_eq!(asset.tamanho, 0);
        assert!(asset.ptr.is_null());
    }

    #[test]
    fn asset_liberar_vazio_nao_crasha() {
        tupi_asset_liberar(TupiAsset::vazio());
    }

    // -- Batcher --

    #[test]
    fn batcher_flush_automatico_ao_estourar() {
        let mut b = Batcher::novo();
        let mut flushes = 0usize;

        let dc = TupiDrawCall {
            primitiva: TupiPrimitiva::Retangulo,
            verts:     [0.0, 0.0, 100.0, 0.0, 0.0, 50.0, 100.0, 50.0],
            n_verts:   8, // 4 vértices x,y
            cor:       [1.0, 0.0, 0.0, 1.0],
        };

        // Cada retângulo usa 4 vértices — 1024/4 = 256 retângulos por flush
        for _ in 0..=256 {
            let flushou = b.adicionar(dc, |_| flushes += 1);
            let _ = flushou;
        }

        assert!(flushes >= 1, "Deveria ter feito pelo menos um flush automático");
    }

    // -- MatrizProj --

    #[test]
    fn projecao_dimensoes_validas() {
        let mat = tupi_projecao_ortografica(800, 600);
        for v in mat.m.iter() {
            assert!(v.is_finite(), "Elemento da matriz não é finito: {v}");
        }
    }

    #[test]
    fn projecao_dimensoes_zero_retorna_identidade() {
        let mat = tupi_projecao_ortografica(0, 600);
        // Identidade: diagonal principal = 1
        assert_eq!(mat.m[0],  1.0);
        assert_eq!(mat.m[5],  1.0);
        assert_eq!(mat.m[10], 1.0);
        assert_eq!(mat.m[15], 1.0);
    }

    #[test]
    fn mat4_multiplicar_identidade() {
        let i = TupiMatriz::identidade();
        let resultado = tupi_mat4_multiplicar(&i, &i);
        for (a, b) in i.m.iter().zip(resultado.m.iter()) {
            assert!((a - b).abs() < 1e-6, "I*I != I em algum elemento");
        }
    }
}