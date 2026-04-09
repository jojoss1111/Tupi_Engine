// sprites.rs
// TupiEngine — Módulo de Sprites em Rust

use std::collections::HashMap;
use std::ffi::{CStr};
use std::os::raw::{c_char, c_float, c_int, c_uint};

// ============================================================
// SISTEMA 1 — DECODIFICAÇÃO SEGURA DE IMAGENS
// ============================================================
// Substitui stb_image no Sprites.c.
// O C passa o caminho do arquivo; o Rust carrega, valida e devolve
// um ponteiro para os pixels RGBA prontos para glTexImage2D.
// Nunca retorna dados inválidos para a GPU.
// ============================================================

/// Resultado da decodificação — devolvido para o C como ponteiro opaco
#[repr(C)]
pub struct TupiImagemRust {
    /// Ponteiro para os pixels RGBA (heap alocado pelo Rust)
    pub pixels:  *mut u8,
    /// Largura em pixels
    pub largura: c_int,
    /// Altura em pixels
    pub altura:  c_int,
    /// Quantidade de bytes no buffer de pixels (largura * altura * 4)
    pub tamanho: c_int,
}

/// Carrega e valida um arquivo de imagem (PNG, JPEG, BMP).
///
/// - Retorna ponteiro para `TupiImagemRust` se tudo correu bem.
/// - Retorna NULL se o arquivo não existir, estiver corrompido,
///   ou não for um formato de imagem reconhecido.
///
/// O C deve liberar a memória com `tupi_imagem_destruir` após uso.
///
/// # Safety
/// `caminho` deve ser um ponteiro válido para uma string C terminada em '\0'.
#[no_mangle]
pub extern "C" fn tupi_imagem_carregar_seguro(caminho: *const c_char) -> *mut TupiImagemRust {
    // Converte o ponteiro C para &str com segurança
    let caminho_str = unsafe {
        if caminho.is_null() {
            eprintln!("[TupiRust] tupi_imagem_carregar_seguro: caminho nulo");
            return std::ptr::null_mut();
        }
        match CStr::from_ptr(caminho).to_str() {
            Ok(s)  => s,
            Err(_) => {
                eprintln!("[TupiRust] tupi_imagem_carregar_seguro: caminho com caracteres inválidos");
                return std::ptr::null_mut();
            }
        }
    };

    // Tenta abrir e decodificar a imagem
    let img = match image::open(caminho_str) {
        Ok(i)  => i,
        Err(e) => {
            eprintln!("[TupiRust] Falha ao carregar '{}': {}", caminho_str, e);
            return std::ptr::null_mut();
        }
    };

    // Converte para RGBA8 — formato que o OpenGL quer (GL_RGBA, GL_UNSIGNED_BYTE)
    let rgba = img.to_rgba8();
    let largura  = rgba.width()  as c_int;
    let altura   = rgba.height() as c_int;
    let tamanho  = (largura * altura * 4) as c_int;

    // Move os pixels para um Vec e vaza o ponteiro para o C
    // O Vec nunca vai ser dropado por Rust — o C é responsável por chamar destruir
    let mut pixels_vec = rgba.into_raw();
    pixels_vec.shrink_to_fit();
    let pixels = pixels_vec.as_mut_ptr();
    std::mem::forget(pixels_vec); // Rust para de gerenciar esse buffer

    // Aloca a struct resultado e a vaza para o C também
    let resultado = Box::new(TupiImagemRust { pixels, largura, altura, tamanho });
    Box::into_raw(resultado)
}

/// Libera a memória de uma `TupiImagemRust` retornada por `tupi_imagem_carregar_seguro`.
///
/// # Safety
/// `img` deve ser um ponteiro válido retornado por `tupi_imagem_carregar_seguro`.
/// Não deve ser chamado duas vezes com o mesmo ponteiro.
#[no_mangle]
pub extern "C" fn tupi_imagem_destruir(img: *mut TupiImagemRust) {
    if img.is_null() { return; }

    unsafe {
        let img_ref = &*img;

        // Reconstrói o Vec para que o Rust possa liberar o buffer de pixels
        if !img_ref.pixels.is_null() && img_ref.tamanho > 0 {
            let tamanho = img_ref.tamanho as usize;
            Vec::from_raw_parts(img_ref.pixels, tamanho, tamanho);
            // O Vec é dropado aqui e libera a memória
        }

        // Reconstrói o Box para liberar a struct
        drop(Box::from_raw(img));
    }
}

// ============================================================
// SISTEMA 2 — ATLAS DE SPRITES (SPRITE SHEETS)
// ============================================================
// Gerencia os metadados de sprite sheets e animações.
// Em vez de calcular u0/v0/u1/v1 no C, o Rust mantém um HashMap
// com todas as animações registradas e devolve as coordenadas UV
// prontas para uso no shader.
// ============================================================

/// Coordenadas UV de uma célula no sprite sheet — devolvidas para o C
#[repr(C)]
pub struct TupiUV {
    pub u0: c_float,
    pub v0: c_float,
    pub u1: c_float,
    pub v1: c_float,
}

/// Uma entrada de animação: qual linha do sheet e quantas colunas tem
#[derive(Clone)]
struct EntradaAnimacao {
    linha:    u32, // linha no sprite sheet (0-indexado)
    colunas:  u32, // quantos frames tem essa animação
    cel_larg: f32, // largura de cada célula em pixels
    cel_alt:  f32, // altura de cada célula em pixels
    img_larg: f32, // largura total da imagem (para calcular UV)
    img_alt:  f32, // altura total da imagem (para calcular UV)
}

/// Atlas: gerencia todas as animações de uma textura
pub struct TupiAtlas {
    animacoes: HashMap<String, EntradaAnimacao>,
}

impl TupiAtlas {
    fn novo() -> Self {
        TupiAtlas { animacoes: HashMap::new() }
    }

    fn registrar(&mut self, nome: &str, entrada: EntradaAnimacao) {
        self.animacoes.insert(nome.to_string(), entrada);
    }

    fn calcular_uv(&self, nome: &str, frame: u32) -> Option<TupiUV> {
        let anim = self.animacoes.get(nome)?;

        // Garante que o frame não ultrapassa o limite da animação
        let frame_seguro = frame % anim.colunas;

        let u0 = (frame_seguro as f32 * anim.cel_larg) / anim.img_larg;
        let v0 = (anim.linha    as f32 * anim.cel_alt)  / anim.img_alt;
        let u1 = u0 + anim.cel_larg / anim.img_larg;
        let v1 = v0 + anim.cel_alt  / anim.img_alt;

        Some(TupiUV { u0, v0, u1, v1 })
    }
}

/// Cria um novo Atlas e retorna o ponteiro opaco para o C.
#[no_mangle]
pub extern "C" fn tupi_atlas_criar() -> *mut TupiAtlas {
    Box::into_raw(Box::new(TupiAtlas::novo()))
}

/// Destrói o Atlas e libera toda a memória.
///
/// # Safety
/// `atlas` deve ser um ponteiro válido criado por `tupi_atlas_criar`.
#[no_mangle]
pub extern "C" fn tupi_atlas_destruir(atlas: *mut TupiAtlas) {
    if atlas.is_null() { return; }
    unsafe { drop(Box::from_raw(atlas)); }
}

/// Registra uma animação no Atlas.
///
/// - `nome`     → nome da animação (ex: "andar", "pular", "morrer")
/// - `linha`    → linha do sprite sheet onde essa animação está (0 = primeira)
/// - `colunas`  → número de frames da animação nessa linha
/// - `cel_larg` → largura de cada célula em pixels
/// - `cel_alt`  → altura de cada célula em pixels
/// - `img_larg` → largura total da imagem PNG em pixels
/// - `img_alt`  → altura total da imagem PNG em pixels
///
/// # Safety
/// Todos os ponteiros devem ser válidos.
#[no_mangle]
pub extern "C" fn tupi_atlas_registrar(
    atlas:    *mut TupiAtlas,
    nome:     *const c_char,
    linha:    c_uint,
    colunas:  c_uint,
    cel_larg: c_float,
    cel_alt:  c_float,
    img_larg: c_float,
    img_alt:  c_float,
) {
    if atlas.is_null() || nome.is_null() { return; }

    let nome_str = unsafe {
        match CStr::from_ptr(nome).to_str() {
            Ok(s)  => s,
            Err(_) => return,
        }
    };

    let entrada = EntradaAnimacao {
        linha:    linha,
        colunas:  colunas,
        cel_larg,
        cel_alt,
        img_larg,
        img_alt,
    };

    unsafe { (*atlas).registrar(nome_str, entrada); }
}

/// Calcula e retorna as coordenadas UV de um frame de uma animação.
///
/// Preenche `uv_out` com os valores calculados.
/// Retorna 1 em sucesso, 0 se a animação não existir.
///
/// # Safety
/// Todos os ponteiros devem ser válidos.
#[no_mangle]
pub extern "C" fn tupi_atlas_uv(
    atlas:  *const TupiAtlas,
    nome:   *const c_char,
    frame:  c_uint,
    uv_out: *mut TupiUV,
) -> c_int {
    if atlas.is_null() || nome.is_null() || uv_out.is_null() { return 0; }

    let nome_str = unsafe {
        match CStr::from_ptr(nome).to_str() {
            Ok(s)  => s,
            Err(_) => return 0,
        }
    };

    let resultado = unsafe { (*atlas).calcular_uv(nome_str, frame) };

    match resultado {
        Some(uv) => {
            unsafe { *uv_out = uv; }
            1
        }
        None => {
            eprintln!("[TupiRust] Atlas: animacao '{}' nao encontrada", nome_str);
            0
        }
    }
}

// ============================================================
// SISTEMA 3 — BATCHING DE DRAW CALLS
// ============================================================
// Acumula todos os sprites que usam a mesma textura numa lista.
// O C consulta o batch para saber quais objetos renderizar juntos,
// reduzindo as chamadas glBindTexture + glDrawArrays de N para 1.
//
// Cada objeto no batch tem:
//   - id da textura OpenGL
//   - quad com 16 floats (x,y,u,v por vértice)
//   - alpha (transparência)
//   - z_index (profundidade — objetos com z menor aparecem atrás)
// ============================================================

/// Um objeto pronto para ser desenhado no batch
#[repr(C)]
#[derive(Clone)]
pub struct TupiItemBatch {
    /// ID da textura OpenGL (para agrupar por textura)
    pub textura_id: c_uint,
    /// Os 16 floats do quad: (x,y,u,v) × 4 vértices
    pub quad:       [c_float; 16],
    /// Transparência 0.0 a 1.0
    pub alpha:      c_float,
    /// Profundidade — menor z fica atrás
    pub z_index:    c_int,
}

/// O Batch — lista de itens acumulados até o flush
pub struct TupiBatch {
    itens: Vec<TupiItemBatch>,
}

impl TupiBatch {
    fn novo() -> Self {
        TupiBatch { itens: Vec::with_capacity(512) }
    }

    fn adicionar(&mut self, item: TupiItemBatch) {
        self.itens.push(item);
    }

    /// Ordena por z_index (atrás para frente) e depois por textura
    /// para minimizar trocas de textura entre draw calls
    fn ordenar(&mut self) {
        self.itens.sort_by(|a, b| {
            a.z_index.cmp(&b.z_index)
                .then(a.textura_id.cmp(&b.textura_id))
        });
    }

    fn limpar(&mut self) {
        self.itens.clear();
    }
}

/// Cria um novo Batch e retorna o ponteiro para o C.
#[no_mangle]
pub extern "C" fn tupi_batch_criar() -> *mut TupiBatch {
    Box::into_raw(Box::new(TupiBatch::novo()))
}

/// Destrói o Batch e libera a memória.
///
/// # Safety
/// `batch` deve ser um ponteiro válido criado por `tupi_batch_criar`.
#[no_mangle]
pub extern "C" fn tupi_batch_destruir(batch: *mut TupiBatch) {
    if batch.is_null() { return; }
    unsafe { drop(Box::from_raw(batch)); }
}

/// Adiciona um item ao batch para ser desenhado no próximo flush.
///
/// - `textura_id` → ID da textura OpenGL (de glGenTextures)
/// - `quad`       → array de 16 floats: (x,y,u,v) × 4 vértices
/// - `alpha`      → transparência 0.0 a 1.0
/// - `z_index`    → profundidade (menor = atrás, maior = frente)
///
/// # Safety
/// `batch` e `quad` devem ser ponteiros válidos.
#[no_mangle]
pub extern "C" fn tupi_batch_adicionar(
    batch:      *mut TupiBatch,
    textura_id: c_uint,
    quad:       *const c_float,
    alpha:      c_float,
    z_index:    c_int,
) {
    if batch.is_null() || quad.is_null() { return; }

    let quad_arr: [c_float; 16] = unsafe {
        std::slice::from_raw_parts(quad, 16)
            .try_into()
            .unwrap_or([0.0; 16])
    };

    let item = TupiItemBatch { textura_id, quad: quad_arr, alpha, z_index };
    unsafe { (*batch).adicionar(item); }
}

/// Ordena o batch (z-index + textura) e devolve o ponteiro para o array
/// de itens ordenados para o C iterar e renderizar.
///
/// O C deve iterar de 0 até `contagem_out` e chamar glDrawArrays para cada
/// grupo de itens com a mesma `textura_id`.
///
/// Retorna ponteiro para o primeiro `TupiItemBatch` do array interno.
/// O ponteiro é válido apenas até a próxima chamada a `tupi_batch_adicionar`
/// ou `tupi_batch_limpar`.
///
/// # Safety
/// `batch` e `contagem_out` devem ser ponteiros válidos.
#[no_mangle]
pub extern "C" fn tupi_batch_flush(
    batch:        *mut TupiBatch,
    contagem_out: *mut c_int,
) -> *const TupiItemBatch {
    if batch.is_null() || contagem_out.is_null() {
        if !contagem_out.is_null() {
            unsafe { *contagem_out = 0; }
        }
        return std::ptr::null();
    }

    let b = unsafe { &mut *batch };
    b.ordenar();

    unsafe { *contagem_out = b.itens.len() as c_int; }

    if b.itens.is_empty() {
        return std::ptr::null();
    }

    b.itens.as_ptr()
}

/// Limpa todos os itens do batch após o flush.
/// Chame isso no fim de cada frame, depois de renderizar.
///
/// # Safety
/// `batch` deve ser um ponteiro válido.
#[no_mangle]
pub extern "C" fn tupi_batch_limpar(batch: *mut TupiBatch) {
    if batch.is_null() { return; }
    unsafe { (*batch).limpar(); }
}

/// Retorna quantos itens estão acumulados no batch no momento.
///
/// # Safety
/// `batch` deve ser um ponteiro válido.
#[no_mangle]
pub extern "C" fn tupi_batch_contagem(batch: *const TupiBatch) -> c_int {
    if batch.is_null() { return 0; }
    unsafe { (*batch).itens.len() as c_int }
}