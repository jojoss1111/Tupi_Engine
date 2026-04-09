// src/camera.rs
// TupiEngine — Validação de parâmetros da Câmera 2D

const POSICAO_MAX: f32 = 1_000_000.0; // limite razoável de mundo
const ZOOM_MIN:    f32 = 0.001;        // evita divisão por zero
const ZOOM_MAX:    f32 = 1_000.0;
const ROT_MAX:     f32 = std::f32::consts::TAU * 100.0; // ±100 voltas

/// Valida os parâmetros antes de qualquer operação de câmera.
///
/// Retorna 1 (válido) ou 0 (inválido).
#[no_mangle]
pub extern "C" fn tupi_camera_validar(
    x:       f32,
    y:       f32,
    zoom:    f32,
    rotacao: f32,
) -> i32 {
    // Rejeita NaN e infinito em qualquer campo
    if !x.is_finite() || !y.is_finite() || !zoom.is_finite() || !rotacao.is_finite() {
        return 0;
    }

    // Limites de posição
    if x.abs() > POSICAO_MAX || y.abs() > POSICAO_MAX {
        return 0;
    }

    // Zoom: deve ser positivo e dentro dos limites
    if zoom < ZOOM_MIN || zoom > ZOOM_MAX {
        return 0;
    }

    // Rotação: aceita qualquer valor finito razoável
    if rotacao.abs() > ROT_MAX {
        return 0;
    }

    1
}