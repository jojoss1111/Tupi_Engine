// fisica.rs
// TupiEngine - Bindings FFI para o sistema de física C

use std::ffi::c_float;

// ============================================================
// TIPOS ESPELHADOS DO C
// ============================================================

// Espelha TupiRetCol de ColisoesAABB.h
#[repr(C)]
pub struct TupiRetCol {
    pub x: c_float, pub y: c_float,
    pub largura: c_float, pub altura: c_float,
}

// Espelha TupiCircCol de ColisoesAABB.h
#[repr(C)]
pub struct TupiCircCol {
    pub x: c_float, pub y: c_float,
    pub raio: c_float,
}

// Espelha TupiColisao de ColisoesAABB.h
#[repr(C)]
pub struct TupiColisao {
    pub colidindo: i32,
    pub dx: c_float,
    pub dy: c_float,
}

// Espelha TupiCorpo de Fisica.h
// ATENÇÃO: campos em snake_case aqui, mas #[repr(C)] garante layout idêntico
#[repr(C)]
pub struct TupiCorpo {
    pub x: c_float,
    pub y: c_float,
    pub vel_x: c_float,       // velX no C
    pub vel_y: c_float,       // velY no C
    pub acel_x: c_float,      // aceleracaoX no C
    pub acel_y: c_float,      // aceleracaoY no C
    pub massa: c_float,
    pub elasticidade: c_float,
    pub atrito: c_float,
}

// ============================================================
// FFI — declarações externas sem #[link]
//
// NÃO usamos #[link(name = "tupi_fisica")] aqui porque isso
// criaria uma dependência circular: o Rust precisaria da lib C
// antes de gerar a staticlib, mas o GCC só gera a lib C depois
// de ter a staticlib do Rust.
//
// Os símbolos são resolvidos pelo GCC no passo final de link,
// quando ele une libtupi_seguro.a + os .o do C numa só .so.
// ============================================================

unsafe extern "C" {
    pub fn tupi_fisica_atualizar(c: *mut TupiCorpo, dt: c_float, gravidade: c_float);
    pub fn tupi_fisica_impulso(c: *mut TupiCorpo, fx: c_float, fy: c_float);
    pub fn tupi_corpo_ret(c: *mut TupiCorpo, largura: c_float, altura: c_float) -> TupiRetCol;
    pub fn tupi_corpo_cir(c: *mut TupiCorpo, raio: c_float) -> TupiCircCol;
    pub fn tupi_resolver_colisao(a: *mut TupiCorpo, b: *mut TupiCorpo, info: TupiColisao);
    pub fn tupi_resolver_estatico(a: *mut TupiCorpo, info: TupiColisao);
    pub fn tupi_aplicar_atrito(c: *mut TupiCorpo, dt: c_float);
    pub fn tupi_limitar_velocidade(c: *mut TupiCorpo, max_vel: c_float);
}

// ============================================================
// WRAPPER SEGURO
// ============================================================

/// Corpo físico gerenciado pelo Rust. Envolve TupiCorpo com uma
/// API segura — todo unsafe fica aqui, fora do código do jogo.
pub struct Corpo(pub TupiCorpo);

impl Corpo {
    /// Cria um corpo dinâmico com posição, massa, elasticidade e atrito.
    pub fn novo(x: f32, y: f32, massa: f32, elasticidade: f32, atrito: f32) -> Self {
        Corpo(TupiCorpo {
            x, y,
            vel_x: 0.0, vel_y: 0.0,
            acel_x: 0.0, acel_y: 0.0,
            massa, elasticidade, atrito,
        })
    }

    /// Cria um corpo estático (paredes, chão) — massa 0, nunca se move.
    pub fn estatico(x: f32, y: f32) -> Self {
        Self::novo(x, y, 0.0, 0.0, 1.0)
    }

    /// Avança a simulação por `dt` segundos com a gravidade dada.
    pub fn atualizar(&mut self, dt: f32, gravidade: f32) {
        unsafe { tupi_fisica_atualizar(&mut self.0, dt, gravidade); }
    }

    /// Aplica um impulso instantâneo (força / massa → Δvelocidade).
    pub fn impulso(&mut self, fx: f32, fy: f32) {
        unsafe { tupi_fisica_impulso(&mut self.0, fx, fy); }
    }

    /// Resolve colisão contra um objeto estático (parede, chão).
    pub fn resolver_estatico(&mut self, info: TupiColisao) {
        unsafe { tupi_resolver_estatico(&mut self.0, info); }
    }

    /// Aplica atrito proporcional ao dt (reduz velocidade gradualmente).
    pub fn aplicar_atrito(&mut self, dt: f32) {
        unsafe { tupi_aplicar_atrito(&mut self.0, dt); }
    }

    /// Limita a magnitude da velocidade ao valor máximo dado.
    pub fn limitar_velocidade(&mut self, max: f32) {
        unsafe { tupi_limitar_velocidade(&mut self.0, max); }
    }

    // ── Acesso direto aos campos ─────────────────────────────

    pub fn x(&self)     -> f32 { self.0.x }
    pub fn y(&self)     -> f32 { self.0.y }
    pub fn vel_x(&self) -> f32 { self.0.vel_x }
    pub fn vel_y(&self) -> f32 { self.0.vel_y }
}