"""
TupiEngine — Editor de Mapas (Python/Pygame)
============================================
Requisitos: pip install pygame
Uso:        python tupi_map_editor.py

Exporta arquivos .lua compatíveis com src/Engine/mapas.lua do TupiEngine atual.
"""

import os
import re
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

import pygame

# ---------------------------------------------------------------------------
# CONSTANTES
# ---------------------------------------------------------------------------
WIN_W, WIN_H = 1400, 860
PANEL_LEFT_W = 260
PANEL_RIGHT_W = 320
TOOLBAR_H = 44
STATUSBAR_H = 26
HEADER_H = 48
CANVAS_AREA_X = PANEL_LEFT_W

BG = (14, 15, 17)
BG2 = (22, 24, 25)
BG3 = (30, 32, 34)
BG4 = (37, 39, 41)
BORDER = (46, 48, 51)
BORDER2 = (58, 61, 65)
TEXT = (232, 233, 234)
TEXT2 = (155, 160, 166)
TEXT3 = (99, 104, 112)
ACCENT = (240, 165, 0)
ACCENT2 = (212, 137, 10)
ACCENT3 = (255, 209, 102)
GREEN = (76, 175, 125)
RED = (224, 92, 92)
BLUE = (91, 156, 246)
PURPLE = (155, 127, 212)

FLAG_SOLIDO = 0x01
FLAG_PASSAGEM = 0x02
FLAG_TRIGGER = 0x04
FLAG_ANIMADO = 0x08

TOOL_PAINT = "paint"
TOOL_ERASE = "erase"
TOOL_FILL = "fill"
TOOL_PICK = "pick"

DEFAULT_ATLAS_PATH = "png/tileset.png"
DEFAULT_COLS = 16
DEFAULT_ROWS = 16
DEFAULT_TILE_W = 8
DEFAULT_TILE_H = 8
TILE_ITEM_H = 42


# ---------------------------------------------------------------------------
# UTILIDADES
# ---------------------------------------------------------------------------
def clamp(value, min_value, max_value):
    return max(min_value, min(max_value, value))


def sanitize_lua_identifier(name: str) -> str:
    cleaned = re.sub(r"[^0-9A-Za-z_]", "_", name or "")
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")
    if not cleaned:
        cleaned = "mapa"
    if cleaned[0].isdigit():
        cleaned = f"mapa_{cleaned}"
    return cleaned


def to_project_relative(path: str) -> str:
    try:
        rel = os.path.relpath(path, os.getcwd())
    except ValueError:
        rel = path
    return rel.replace("\\", "/")


def format_float(value: float, decimals: int = 2) -> str:
    text = f"{value:.{decimals}f}"
    text = text.rstrip("0").rstrip(".")
    return text if text else "0"


def draw_rect_filled(surf, color, rect, radius=0):
    if radius > 0:
        pygame.draw.rect(surf, color, rect, border_radius=radius)
    else:
        pygame.draw.rect(surf, color, rect)


def draw_rect_border(surf, color, rect, width=1, radius=0):
    if radius > 0:
        pygame.draw.rect(surf, color, rect, width, border_radius=radius)
    else:
        pygame.draw.rect(surf, color, rect, width)


def draw_text(surf, text, font, color, x, y, align="left"):
    s = font.render(str(text), True, color)
    if align == "center":
        x -= s.get_width() // 2
    elif align == "right":
        x -= s.get_width()
    surf.blit(s, (x, y))
    return s.get_width()


def build_rows(values, cols):
    return [values[index:index + cols] for index in range(0, len(values), cols)]


# ---------------------------------------------------------------------------
# ESTADO GLOBAL
# ---------------------------------------------------------------------------
class EditorState:
    def __init__(self):
        self.cols = DEFAULT_COLS
        self.rows = DEFAULT_ROWS
        self.tile_w = DEFAULT_TILE_W
        self.tile_h = DEFAULT_TILE_H
        self.atlas_path = DEFAULT_ATLAS_PATH
        self.var_name = "mapa"

        self.tiles: dict[int, dict] = {}
        self.grid: list[int] = [0] * (self.cols * self.rows)

        self.selected_tile_id = None
        self.tool = TOOL_PAINT
        self.zoom = 3.0
        self.scroll_x = 0
        self.scroll_y = 0
        self.tile_list_scroll = 0

        self.atlas_img = None
        self.atlas_sel_col = 0
        self.atlas_sel_row = 0

        self.is_painting = False
        self.last_painted = (-1, -1)

    def init_grid(self, keep=False):
        old_cols = getattr(self, "_old_cols", self.cols)
        old_rows = getattr(self, "_old_rows", self.rows)
        old_grid = list(self.grid)
        new_grid = [0] * (self.cols * self.rows)
        if keep:
            for row in range(min(self.rows, old_rows)):
                for col in range(min(self.cols, old_cols)):
                    new_grid[row * self.cols + col] = old_grid[row * old_cols + col]
        self.grid = new_grid

    def tile_at(self, col, row):
        if 0 <= col < self.cols and 0 <= row < self.rows:
            return self.grid[row * self.cols + col]
        return 0

    def set_tile(self, col, row, val):
        if 0 <= col < self.cols and 0 <= row < self.rows:
            self.grid[row * self.cols + col] = val

    def next_tile_id(self):
        existing = set(self.tiles.keys())
        number = 1
        while number in existing:
            number += 1
        return number

    def get_selected_tile(self):
        if self.selected_tile_id is None:
            return None
        return self.tiles.get(self.selected_tile_id)

    def clear_canvas(self):
        self.grid = [0] * (self.cols * self.rows)

    def flood_fill(self, col, row, target, replacement):
        if target == replacement:
            return
        stack = [(col, row)]
        visited = set()
        while stack:
            current_col, current_row = stack.pop()
            if (current_col, current_row) in visited:
                continue
            if not (0 <= current_col < self.cols and 0 <= current_row < self.rows):
                continue
            if self.tile_at(current_col, current_row) != target:
                continue
            visited.add((current_col, current_row))
            self.set_tile(current_col, current_row, replacement)
            stack.extend(
                [
                    (current_col + 1, current_row),
                    (current_col - 1, current_row),
                    (current_col, current_row + 1),
                    (current_col, current_row - 1),
                ]
            )

    def new_tile_def(self, number, name, flags, col, row):
        self.tiles[number] = {
            "name": name,
            "flags": flags,
            "larg": self.tile_w,
            "alt": self.tile_h,
            "frames": [{"col": col, "row": row}],
            "fps": 0.0,
            "loop": True,
            "alpha": 1.0,
            "escala": 1.0,
            "z": 0,
            "parent_id": None,
        }

    def new_variant_def(self, number, name, parent_id, col, row):
        """Cria uma variante que herda flags/z/alpha/escala do pai."""
        parent = self.tiles[parent_id]
        self.tiles[number] = {
            "name": name,
            "flags": parent["flags"],
            "larg": self.tile_w,
            "alt": self.tile_h,
            "frames": [{"col": col, "row": row}],
            "fps": 0.0,
            "loop": True,
            "alpha": parent["alpha"],
            "escala": parent["escala"],
            "z": parent["z"],
            "parent_id": parent_id,
        }

    def is_variant(self, number):
        tile = self.tiles.get(number)
        return tile is not None and tile.get("parent_id") is not None

    def get_parent(self, number):
        tile = self.tiles.get(number)
        if tile is None:
            return None
        return tile.get("parent_id")

    def get_effective_tile(self, number):
        """Retorna o tile raiz (pai) se for variante, senão o próprio."""
        tile = self.tiles.get(number)
        if tile is None:
            return None
        pid = tile.get("parent_id")
        if pid is not None and pid in self.tiles:
            return self.tiles[pid]
        return tile

    def delete_tile(self, number):
        if number in self.tiles:
            # Ao deletar um pai, converte filhos em tiles independentes
            for tid, tile in list(self.tiles.items()):
                if tile.get("parent_id") == number:
                    tile["parent_id"] = None
            del self.tiles[number]
        self.grid = [0 if value == number else value for value in self.grid]
        if self.selected_tile_id == number:
            self.selected_tile_id = None

    def sync_variant_from_parent(self, parent_id):
        """Sincroniza flags/z/alpha/escala de todas as variantes de um pai."""
        parent = self.tiles.get(parent_id)
        if not parent:
            return
        for tile in self.tiles.values():
            if tile.get("parent_id") == parent_id:
                tile["flags"] = parent["flags"]
                tile["z"] = parent["z"]
                tile["alpha"] = parent["alpha"]
                tile["escala"] = parent["escala"]

    def toggle_flag(self, number, flag):
        tile = self.tiles.get(number)
        if not tile:
            return
        # Variantes não podem ter flags independentes — altera no pai
        pid = tile.get("parent_id")
        if pid is not None and pid in self.tiles:
            self.tiles[pid]["flags"] ^= flag
            self.sync_variant_from_parent(pid)
        else:
            tile["flags"] ^= flag
            self.sync_variant_from_parent(number)

    def update_animation_flag(self, number):
        tile = self.tiles.get(number)
        if not tile:
            return
        is_animated = len(tile["frames"]) > 1 and tile["fps"] > 0
        if is_animated:
            tile["flags"] |= FLAG_ANIMADO
        else:
            tile["flags"] &= ~FLAG_ANIMADO


state = EditorState()


# ---------------------------------------------------------------------------
# FONTES
# ---------------------------------------------------------------------------
pygame.init()

FONT_SM = pygame.font.SysFont("monospace", 11)
FONT_MD = pygame.font.SysFont("monospace", 12)
FONT_LG = pygame.font.SysFont("monospace", 14)
FONT_BOLD = pygame.font.SysFont("monospace", 12, bold=True)


# ---------------------------------------------------------------------------
# BOTÃO SIMPLES
# ---------------------------------------------------------------------------
class Button:
    def __init__(self, rect, label, font=None, active=False):
        self.rect = pygame.Rect(rect)
        self.label = label
        self.font = font or FONT_MD
        self.active = active
        self.hovered = False

    def draw(self, surf):
        bg = BG4 if self.active else (BG3 if self.hovered else BG2)
        bc = ACCENT if self.active else (BORDER2 if self.hovered else BORDER)
        draw_rect_filled(surf, bg, self.rect, 5)
        draw_rect_border(surf, bc, self.rect, 1, 5)
        tc = ACCENT if self.active else (TEXT if self.hovered else TEXT2)
        s = self.font.render(self.label, True, tc)
        surf.blit(
            s,
            (
                self.rect.centerx - s.get_width() // 2,
                self.rect.centery - s.get_height() // 2,
            ),
        )

    def handle_event(self, event):
        if event.type == pygame.MOUSEMOTION:
            self.hovered = self.rect.collidepoint(event.pos)
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(event.pos):
                return True
        return False


# ---------------------------------------------------------------------------
# DIÁLOGOS
# ---------------------------------------------------------------------------
def run_resize_dialog(current_cols, current_rows, current_tw, current_th):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)

    try:
        cols_s = simpledialog.askstring(
            "Redimensionar Mapa",
            f"Colunas (atual: {current_cols})\nMínimo: 1 | Máximo: 256",
            initialvalue=str(current_cols),
            parent=root,
        )
        if cols_s is None:
            return None
        cols = clamp(int(cols_s), 1, 256)

        rows_s = simpledialog.askstring(
            "Redimensionar Mapa",
            f"Linhas (atual: {current_rows})\nMínimo: 1 | Máximo: 256",
            initialvalue=str(current_rows),
            parent=root,
        )
        if rows_s is None:
            return None
        rows = clamp(int(rows_s), 1, 256)

        tw_s = simpledialog.askstring(
            "Tamanho do Tile",
            f"Largura do tile em px (atual: {current_tw})",
            initialvalue=str(current_tw),
            parent=root,
        )
        if tw_s is None:
            return None
        tile_w = clamp(int(tw_s), 1, 512)

        th_s = simpledialog.askstring(
            "Tamanho do Tile",
            f"Altura do tile em px (atual: {current_th})",
            initialvalue=str(current_th),
            parent=root,
        )
        if th_s is None:
            return None
        tile_h = clamp(int(th_s), 1, 512)

        return cols, rows, tile_w, tile_h
    except (ValueError, TypeError):
        messagebox.showerror("Erro", "Valor inválido inserido.")
        return None
    finally:
        root.destroy()


def open_atlas_dialog():
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.askopenfilename(
        title="Abrir Atlas",
        filetypes=[("Imagens", "*.png *.jpg *.bmp *.gif"), ("Todos", "*.*")],
        parent=root,
    )
    root.destroy()
    return path or None


def ask_new_tile(current_state: EditorState):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        suggested = current_state.next_tile_id()
        num_s = simpledialog.askstring(
            "Novo Tile",
            f"Número do tile (sugerido: {suggested}, máx 255)",
            initialvalue=str(suggested),
            parent=root,
        )
        if num_s is None:
            return None
        number = int(num_s)
        if number < 1 or number > 255:
            messagebox.showerror("Erro", "Número deve estar entre 1 e 255.")
            return None
        if number in current_state.tiles:
            messagebox.showerror("Erro", f"Tile #{number} já existe.")
            return None
        name = simpledialog.askstring(
            "Novo Tile",
            "Nome do tile:",
            initialvalue=f"tile_{number}",
            parent=root,
        )
        if name is None:
            return None
        return number, name.strip() or f"tile_{number}"
    except (ValueError, TypeError):
        messagebox.showerror("Erro", "Valor inválido.")
        return None
    finally:
        root.destroy()


def ask_new_variant(current_state: EditorState):
    """Pergunta id/nome da variante e qual tile é o pai."""
    # Só tiles que não são variantes podem ser pai
    possible_parents = {
        tid: tile for tid, tile in current_state.tiles.items()
        if tile.get("parent_id") is None
    }
    if not possible_parents:
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        try:
            messagebox.showerror("Nova Variante", "Nenhum tile pai disponível.\nCrie um tile normal primeiro.", parent=root)
        finally:
            root.destroy()
        return None

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        # Lista de pais disponíveis
        parent_options = "\n".join(f"  #{tid} - {tile['name']}" for tid, tile in sorted(possible_parents.items()))
        parent_s = simpledialog.askstring(
            "Nova Variante — Tile Pai",
            f"Tiles disponíveis como pai:\n{parent_options}\n\nDigite o número do tile pai:",
            parent=root,
        )
        if parent_s is None:
            return None
        parent_id = int(parent_s)
        if parent_id not in possible_parents:
            messagebox.showerror("Erro", f"Tile #{parent_id} não existe ou é variante.", parent=root)
            return None

        suggested = current_state.next_tile_id()
        num_s = simpledialog.askstring(
            "Nova Variante — Número",
            f"Número da variante (sugerido: {suggested}, máx 255)\nHerdará: flags, z, alpha, escala do pai #{parent_id}",
            initialvalue=str(suggested),
            parent=root,
        )
        if num_s is None:
            return None
        number = int(num_s)
        if number < 1 or number > 255:
            messagebox.showerror("Erro", "Número deve estar entre 1 e 255.", parent=root)
            return None
        if number in current_state.tiles:
            messagebox.showerror("Erro", f"Tile #{number} já existe.", parent=root)
            return None

        parent_name = possible_parents[parent_id]["name"]
        name = simpledialog.askstring(
            "Nova Variante — Nome",
            "Nome da variante:",
            initialvalue=f"{parent_name}_v{number}",
            parent=root,
        )
        if name is None:
            return None
        return number, name.strip() or f"variante_{number}", parent_id
    except (ValueError, TypeError):
        messagebox.showerror("Erro", "Valor inválido.", parent=root)
        return None
    finally:
        root.destroy()


def ask_rename_tile(current_name):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        name = simpledialog.askstring(
            "Renomear Tile",
            "Novo nome do tile:",
            initialvalue=current_name,
            parent=root,
        )
        if name is None:
            return None
        return name.strip() or current_name
    finally:
        root.destroy()


def ask_export_path(var_name):
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.asksaveasfilename(
        title="Exportar .lua",
        defaultextension=".lua",
        initialfile=f"{var_name}.lua",
        filetypes=[("Lua", "*.lua"), ("Todos", "*.*")],
        parent=root,
    )
    root.destroy()
    return path or None


def ask_import_path():
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    path = filedialog.askopenfilename(
        title="Importar .lua",
        filetypes=[("Lua", "*.lua"), ("Todos", "*.*")],
    )
    root.destroy()
    return path or None


def confirm_clear_map():
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        return messagebox.askyesno(
            "Limpar mapa",
            "Deseja apagar toda a grade atual?",
            parent=root,
        )
    finally:
        root.destroy()


# ---------------------------------------------------------------------------
# ATLAS
# ---------------------------------------------------------------------------
def load_atlas(current_state: EditorState, path: str):
    image = pygame.image.load(path).convert_alpha()
    current_state.atlas_img = image
    current_state.atlas_path = to_project_relative(path)
    max_col = max(0, image.get_width() // current_state.tile_w - 1)
    max_row = max(0, image.get_height() // current_state.tile_h - 1)
    current_state.atlas_sel_col = clamp(current_state.atlas_sel_col, 0, max_col)
    current_state.atlas_sel_row = clamp(current_state.atlas_sel_row, 0, max_row)


def try_load_default_atlas(current_state: EditorState):
    if not os.path.exists(current_state.atlas_path):
        return
    try:
        load_atlas(current_state, current_state.atlas_path)
    except Exception:
        current_state.atlas_img = None


def get_atlas_scaled(atlas_img, max_size=260):
    if atlas_img is None:
        return None, 1.0
    image_w, image_h = atlas_img.get_size()
    scale = min(max_size / image_w, max_size / image_h, 2.0)
    scaled_w = max(1, int(image_w * scale))
    scaled_h = max(1, int(image_h * scale))
    scaled = pygame.transform.scale(atlas_img, (scaled_w, scaled_h))
    return scaled, scale


def draw_atlas_panel(surf, current_state: EditorState, x, y, w):
    if current_state.atlas_img is None:
        draw_rect_filled(surf, BG3, (x, y, w, 80), 4)
        draw_text(surf, "Sem atlas carregado", FONT_SM, TEXT3, x + w // 2, y + 32, "center")
        return y + 84, None, 1.0

    atlas_scaled, scale = get_atlas_scaled(current_state.atlas_img, max_size=w)
    atlas_w, atlas_h = atlas_scaled.get_size()
    frame_rect = pygame.Rect(x, y, atlas_w + 2, atlas_h + 2)
    draw_rect_filled(surf, BG3, frame_rect, 3)
    surf.blit(atlas_scaled, (x + 1, y + 1))

    tile_w = current_state.tile_w * scale
    tile_h = current_state.tile_h * scale
    atlas_cols = max(1, current_state.atlas_img.get_width() // current_state.tile_w)
    atlas_rows = max(1, current_state.atlas_img.get_height() // current_state.tile_h)

    for col in range(atlas_cols + 1):
        px = int(x + 1 + col * tile_w)
        pygame.draw.line(surf, BORDER, (px, y + 1), (px, y + 1 + atlas_h), 1)
    for row in range(atlas_rows + 1):
        py = int(y + 1 + row * tile_h)
        pygame.draw.line(surf, BORDER, (x + 1, py), (x + 1 + atlas_w, py), 1)

    sel_x = int(x + 1 + current_state.atlas_sel_col * tile_w)
    sel_y = int(y + 1 + current_state.atlas_sel_row * tile_h)
    sel_rect = pygame.Rect(sel_x, sel_y, max(1, int(tile_w)), max(1, int(tile_h)))
    highlight = pygame.Surface((sel_rect.w, sel_rect.h), pygame.SRCALPHA)
    highlight.fill((240, 165, 0, 50))
    surf.blit(highlight, (sel_rect.x, sel_rect.y))
    pygame.draw.rect(surf, ACCENT, sel_rect, 2)

    return y + atlas_h + 6, (x, y + 1, atlas_w, atlas_h), scale


# ---------------------------------------------------------------------------
# IMPORTAÇÃO LUA
# ---------------------------------------------------------------------------
def _parse_lua_bool(value: str) -> bool:
    return value.strip().lower() == "true"


def _parse_options_lua(options_str: str) -> dict:
    """Extrai chave=valor de uma string de opções Lua: { colide=true, passagem=false, ... }"""
    opts = {}
    for match in re.finditer(r"(\w+)\s*=\s*([^\s,}]+)", options_str):
        key, val = match.group(1), match.group(2)
        if val in ("true", "false"):
            opts[key] = _parse_lua_bool(val)
        else:
            try:
                opts[key] = int(val)
            except ValueError:
                try:
                    opts[key] = float(val)
                except ValueError:
                    opts[key] = val
    return opts


def import_lua(path: str, current_state: EditorState) -> str | None:
    """
    Lê um .lua gerado pelo editor e reconstrói o estado.
    Retorna uma mensagem de erro se falhar, None se sucesso.
    """
    try:
        with open(path, "r", encoding="utf-8") as handle:
            source = handle.read()
    except OSError as exc:
        return f"Não foi possível abrir o arquivo:\n{exc}"

    # --- nome da variável do mapa ---
    # local <nome> = Mapa.novo()
    var_match = re.search(r"local\s+(\w+)\s*=\s*Mapa\.novo\(\)", source)
    if not var_match:
        return "Arquivo não parece ser um mapa TupiEngine válido\n(não encontrou 'Mapa.novo()')."
    var_name = var_match.group(1)

    # --- criarMapa(cols, rows, tw, th) ---
    criar_match = re.search(
        rf"{re.escape(var_name)}:criarMapa\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)",
        source,
    )
    if not criar_match:
        return "Não encontrou 'criarMapa(...)' no arquivo."
    cols, rows, tile_w, tile_h = (int(g) for g in criar_match.groups())

    # --- atlas ---
    atlas_match = re.search(rf'{re.escape(var_name)}:atlas\("([^"]+)"\)', source)
    atlas_path = atlas_match.group(1) if atlas_match else DEFAULT_ATLAS_PATH

    # --- tiles: criarTile(id, col, row, { opções }) ---
    tile_pattern = re.compile(
        r"^--\s*(.+?)\s*\(#(\d+)\)\s*\n"
        r"\s*local\s+tile_\d+\s*=\s*"
        + re.escape(var_name)
        + r":criarTile\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\{[^}]*\})\s*\)",
        re.MULTILINE,
    )

    tiles: dict[int, dict] = {}
    for match in tile_pattern.finditer(source):
        name = match.group(1).strip()
        tile_id = int(match.group(3))
        col = int(match.group(4))
        row = int(match.group(5))
        opts = _parse_options_lua(match.group(6))

        flags = 0
        if opts.get("colide", False):
            flags |= FLAG_SOLIDO
        if opts.get("passagem", False):
            flags |= FLAG_PASSAGEM
        if opts.get("trigger", False):
            flags |= FLAG_TRIGGER

        tiles[tile_id] = {
            "name": name,
            "flags": flags,
            "larg": tile_w,
            "alt": tile_h,
            "frames": [{"col": col, "row": row}],
            "fps": 0.0,
            "loop": True,
            "alpha": float(opts.get("alpha", 1.0)),
            "escala": float(opts.get("escala", 1.0)),
            "z": int(opts.get("z", 0)),
            "parent_id": None,
        }

    # --- frames extras de animação ---
    # tile_X._frames = { { coluna = N, linha = N }, ... }
    frames_pattern = re.compile(
        r"tile_(\d+)\._frames\s*=\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}",
        re.DOTALL,
    )
    for match in frames_pattern.finditer(source):
        tile_id = int(match.group(1))
        if tile_id not in tiles:
            continue
        frame_entries = re.findall(
            r"\{\s*coluna\s*=\s*(\d+)\s*,\s*linha\s*=\s*(\d+)\s*\}",
            match.group(2),
        )
        if frame_entries:
            tiles[tile_id]["frames"] = [
                {"col": int(c), "row": int(r)} for c, r in frame_entries
            ]

    # fps e loop de animação
    fps_pattern = re.compile(r"tile_(\d+)\._fps\s*=\s*([\d.]+)")
    for match in fps_pattern.finditer(source):
        tile_id = int(match.group(1))
        if tile_id in tiles:
            tiles[tile_id]["fps"] = float(match.group(2))
            tiles[tile_id]["flags"] |= FLAG_ANIMADO

    loop_pattern = re.compile(r"tile_(\d+)\._loop\s*=\s*(true|false)")
    for match in loop_pattern.finditer(source):
        tile_id = int(match.group(1))
        if tile_id in tiles:
            tiles[tile_id]["loop"] = _parse_lua_bool(match.group(2))

    # --- variantes: varianteTile(alias, pai, col, row) ---
    variant_pattern = re.compile(
        r"^--\s*(.+?)\s*\(#(\d+)\)\s*\n"
        r"\s*local\s+tile_\d+\s*=\s*"
        + re.escape(var_name)
        + r":varianteTile\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)",
        re.MULTILINE,
    )
    for match in variant_pattern.finditer(source):
        name = match.group(1).strip()
        alias_id = int(match.group(3))
        parent_id = int(match.group(4))
        col = int(match.group(5))
        row = int(match.group(6))
        parent = tiles.get(parent_id, {})
        tiles[alias_id] = {
            "name": name,
            "flags": parent.get("flags", 0),
            "larg": tile_w,
            "alt": tile_h,
            "frames": [{"col": col, "row": row}],
            "fps": 0.0,
            "loop": True,
            "alpha": parent.get("alpha", 1.0),
            "escala": parent.get("escala", 1.0),
            "z": parent.get("z", 0),
            "parent_id": parent_id,
        }

    # --- variantes animadas: varianteTileAnim(alias, pai, {cols}, {rows}, fps, loop) ---
    variant_anim_pattern = re.compile(
        r"^--\s*(.+?)\s*\(#(\d+)\)\s*\n"
        r"\s*local\s+tile_\d+\s*=\s*"
        + re.escape(var_name)
        + r":varianteTileAnim\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\{[^}]*\})\s*,\s*(\{[^}]*\})\s*,\s*([\d.]+)\s*,\s*(true|false)\s*\)",
        re.MULTILINE,
    )
    for match in variant_anim_pattern.finditer(source):
        name = match.group(1).strip()
        alias_id = int(match.group(3))
        parent_id = int(match.group(4))
        cols_str = match.group(5)
        rows_str = match.group(6)
        fps_val = float(match.group(7))
        loop_val = _parse_lua_bool(match.group(8))
        parent = tiles.get(parent_id, {})
        frame_cols = [int(v) for v in re.findall(r"\d+", cols_str)]
        frame_rows = [int(v) for v in re.findall(r"\d+", rows_str)]
        frames_anim = [{"col": c, "row": r} for r in frame_rows for c in frame_cols]
        flags = parent.get("flags", 0) | FLAG_ANIMADO
        tiles[alias_id] = {
            "name": name,
            "flags": flags,
            "larg": tile_w,
            "alt": tile_h,
            "frames": frames_anim if frames_anim else [{"col": 0, "row": 0}],
            "fps": fps_val,
            "loop": loop_val,
            "alpha": parent.get("alpha", 1.0),
            "escala": parent.get("escala", 1.0),
            "z": parent.get("z", 0),
            "parent_id": parent_id,
        }

    # --- grade: carregarArray({ ... }) ---
    array_match = re.search(
        rf"{re.escape(var_name)}:carregarArray\(\{{(.*?)\}}\)",
        source,
        re.DOTALL,
    )
    grid: list[int] = [0] * (cols * rows)
    if array_match:
        numbers = re.findall(r"\d+", array_match.group(1))
        for index, num in enumerate(numbers[: cols * rows]):
            grid[index] = int(num)

    # --- aplica ao estado ---
    current_state._old_cols = current_state.cols
    current_state._old_rows = current_state.rows
    current_state.cols = cols
    current_state.rows = rows
    current_state.tile_w = tile_w
    current_state.tile_h = tile_h
    current_state.atlas_path = atlas_path
    current_state.var_name = sanitize_lua_identifier(var_name)
    current_state.tiles = tiles
    current_state.grid = grid
    current_state.selected_tile_id = None
    current_state.scroll_x = 0
    current_state.scroll_y = 0
    current_state.tile_list_scroll = 0

    # tenta carregar atlas relativo ao arquivo importado
    base_dir = os.path.dirname(os.path.abspath(path))
    candidate = os.path.join(base_dir, atlas_path)
    if os.path.isfile(candidate):
        try:
            load_atlas(current_state, candidate)
        except Exception:
            current_state.atlas_img = None
    else:
        try:
            load_atlas(current_state, atlas_path)
        except Exception:
            current_state.atlas_img = None

    return None  # sucesso


def import_map_from_file(current_state: EditorState):
    """Abre diálogo, lê o .lua e atualiza o estado. Exibe erros se necessário."""
    path = ask_import_path()
    if not path:
        return

    error = import_lua(path, current_state)
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        if error:
            messagebox.showerror("Importar .lua", error, parent=root)
        else:
            tile_count = len(current_state.tiles)
            messagebox.showinfo(
                "Importado",
                f"Mapa carregado com sucesso!\n"
                f"{current_state.cols}x{current_state.rows} tiles  |  {tile_count} tipo(s) de tile",
                parent=root,
            )
    finally:
        root.destroy()


# ---------------------------------------------------------------------------
# EXPORTAÇÃO LUA
# ---------------------------------------------------------------------------
def tile_options_lua(tile):
    return (
        "{ "
        f"colide={'true' if bool(tile['flags'] & FLAG_SOLIDO) else 'false'}, "
        f"passagem={'true' if bool(tile['flags'] & FLAG_PASSAGEM) else 'false'}, "
        f"trigger={'true' if bool(tile['flags'] & FLAG_TRIGGER) else 'false'}, "
        f"z={tile['z']}, "
        f"alpha={format_float(tile['alpha'], 3)}, "
        f"escala={format_float(tile['escala'], 3)} "
        "}"
    )


def export_lua(current_state: EditorState) -> str:
    ids = sorted(current_state.tiles.keys())
    module_name = sanitize_lua_identifier(current_state.var_name)
    atlas_path = current_state.atlas_path.replace("\\", "/")
    uses_animated_patch = any(
        len(tile["frames"]) > 1 and tile["fps"] > 0
        and tile.get("parent_id") is None
        for tile in current_state.tiles.values()
    )

    lines = [
        "-- Gerado pelo TupiEngine Map Editor (Python)",
        f"-- Arquivo: {module_name}.lua",
        "",
        'local Mapa = require("src.Engine.mapas")',
    ]

    if uses_animated_patch:
        lines.append('local bit = require("bit")')

    lines += [
        "",
        f"local {module_name} = Mapa.novo()",
        "",
        "-- Dimensoes",
        f"{module_name}:criarMapa({current_state.cols}, {current_state.rows}, {current_state.tile_w}, {current_state.tile_h})",
        f'{module_name}:atlas("{atlas_path}")',
        "",
    ]

    # Pais primeiro, depois variantes (garante que o pai existe quando varianteTile for chamado)
    parent_ids = [tid for tid in ids if current_state.tiles[tid].get("parent_id") is None]
    variant_ids = [tid for tid in ids if current_state.tiles[tid].get("parent_id") is not None]
    ordered_ids = parent_ids + variant_ids

    for tile_id in ordered_ids:
        tile = current_state.tiles[tile_id]
        frames = tile["frames"]
        first_frame = frames[0] if frames else {"col": 0, "row": 0}
        local_ref = f"tile_{tile_id}"
        is_animated = len(frames) > 1 and tile["fps"] > 0
        parent_id = tile.get("parent_id")

        lines.append(f"-- {tile['name']} (#{tile_id})")

        if parent_id is not None:
            # É uma variante — usa varianteTile ou varianteTileAnim
            if is_animated:
                unique_cols = []
                unique_rows = []
                seen_cols, seen_rows = set(), set()
                for fr in frames:
                    if fr["col"] not in seen_cols:
                        unique_cols.append(fr["col"])
                        seen_cols.add(fr["col"])
                    if fr["row"] not in seen_rows:
                        unique_rows.append(fr["row"])
                        seen_rows.add(fr["row"])
                cols_lua = "{" + ", ".join(str(c) for c in unique_cols) + "}"
                rows_lua = "{" + ", ".join(str(r) for r in unique_rows) + "}"
                loop_lua = "true" if tile["loop"] else "false"
                lines.append(
                    f"local {local_ref} = {module_name}:varianteTileAnim("
                    f"{tile_id}, {parent_id}, {cols_lua}, {rows_lua}, "
                    f"{format_float(tile['fps'], 3)}, {loop_lua})"
                )
            else:
                lines.append(
                    f"local {local_ref} = {module_name}:varianteTile("
                    f"{tile_id}, {parent_id}, {first_frame['col']}, {first_frame['row']})"
                )
        else:
            # Tile normal / pai
            options_lua = tile_options_lua(tile)
            lines.append(
                f"local {local_ref} = {module_name}:criarTile("
                f"{tile_id}, {first_frame['col']}, {first_frame['row']}, {options_lua})"
            )

            if is_animated:
                lines.append(
                    f"-- Mantem a ordem exata dos frames definida no editor."
                )
                lines.append(f"{local_ref}._flags = bit.bor({local_ref}._flags, 0x08)")
                lines.append(f"{local_ref}._fps = {format_float(tile['fps'], 3)}")
                lines.append(f"{local_ref}._loop = {'true' if tile['loop'] else 'false'}")
                lines.append(f"{local_ref}._frames = {{")
                for frame in frames:
                    lines.append(
                        f"    {{ coluna = {frame['col']}, linha = {frame['row']} }},"
                    )
                lines.append("}")
        lines.append("")

    lines.append(f"-- Grade do mapa ({current_state.cols}x{current_state.rows})")
    lines.append(f"{module_name}:carregarArray({{")
    for row_values in build_rows(current_state.grid, current_state.cols):
        lines.append("    " + ", ".join(str(value) for value in row_values) + ",")
    lines.append("})")
    lines.append("")
    lines.append(f"{module_name}:build()")
    lines.append("")
    lines.append(f"return {{ {module_name} = {module_name} }}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# DESENHO DE UI
# ---------------------------------------------------------------------------
def _draw_button(surf, rect, label, color=BG3, border_color=BORDER2, text_color=TEXT2, font=None):
    font = font or FONT_SM
    draw_rect_filled(surf, color, rect, 4)
    draw_rect_border(surf, border_color, rect, 1, 4)
    s = font.render(label, True, text_color)
    surf.blit(s, (rect.centerx - s.get_width() // 2, rect.centery - s.get_height() // 2))


def _draw_toggle_button(surf, rect, label, active, active_color, inactive_color=BG3):
    color = active_color if active else inactive_color
    border = active_color if active else BORDER2
    text_color = (17, 17, 17) if active else TEXT2
    _draw_button(surf, rect, label, color=color, border_color=border, text_color=text_color)


def _draw_adjuster(surf, x, y, width, label, value_text):
    draw_text(surf, label, FONT_SM, TEXT3, x, y + 4)
    minus_rect = pygame.Rect(x + 92, y, 26, 22)
    value_rect = pygame.Rect(x + 122, y, width - 152, 22)
    plus_rect = pygame.Rect(x + width - 26, y, 26, 22)

    _draw_button(surf, minus_rect, "-", color=BG4)
    draw_rect_filled(surf, BG3, value_rect, 4)
    draw_rect_border(surf, BORDER, value_rect, 1, 4)
    draw_text(surf, value_text, FONT_SM, TEXT, value_rect.centerx, value_rect.top + 5, "center")
    _draw_button(surf, plus_rect, "+", color=BG4)

    return minus_rect, plus_rect


def draw_right_panel(screen, current_state: EditorState, ww, wh):
    right_panel_x = ww - PANEL_RIGHT_W
    draw_rect_filled(screen, BG2, (right_panel_x, HEADER_H, PANEL_RIGHT_W, wh - HEADER_H))
    pygame.draw.line(screen, BORDER, (right_panel_x, HEADER_H), (right_panel_x, wh), 1)

    ui = {}
    py = HEADER_H + 8
    button_w = PANEL_RIGHT_W - 16

    ui["atlas_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(screen, ui["atlas_btn"], "Carregar Atlas")
    py += 32

    ui["resize_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(
        screen,
        ui["resize_btn"],
        f"Redimensionar ({current_state.cols}x{current_state.rows})",
        color=ACCENT2,
        text_color=(17, 17, 17),
    )
    py += 32

    ui["add_frame_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(screen, ui["add_frame_btn"], "+ Frame da seleção")
    py += 32

    ui["add_variant_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(screen, ui["add_variant_btn"], "+ Nova Variante", color=(20, 28, 50), border_color=BLUE, text_color=BLUE)
    py += 32

    ui["clear_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(
        screen,
        ui["clear_btn"],
        "Limpar grade",
        color=(42, 32, 18),
        border_color=ACCENT2,
        text_color=ACCENT3,
    )
    py += 32

    ui["delete_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 26)
    _draw_button(
        screen,
        ui["delete_btn"],
        "Deletar tile selecionado",
        color=(60, 25, 25),
        border_color=RED,
        text_color=RED,
    )
    py += 34

    pygame.draw.line(screen, BORDER, (right_panel_x + 8, py), (right_panel_x + PANEL_RIGHT_W - 8, py), 1)
    py += 8
    draw_text(screen, "TILE SELECIONADO", FONT_SM, TEXT3, right_panel_x + 10, py)
    py += 18

    tile = current_state.get_selected_tile()
    if tile:
        is_variant = tile.get("parent_id") is not None
        pid = tile.get("parent_id")

        header_color = BLUE if is_variant else TEXT
        draw_text(screen, f"#{current_state.selected_tile_id} - {tile['name']}", FONT_MD, header_color, right_panel_x + 10, py)
        ui["rename_btn"] = pygame.Rect(right_panel_x + PANEL_RIGHT_W - 92, py - 4, 82, 22)
        _draw_button(screen, ui["rename_btn"], "Renomear", color=BG4)
        py += 24

        # Badge de variante
        if is_variant:
            parent_tile = current_state.tiles.get(pid, {})
            pname = parent_tile.get("name", f"#{pid}")
            draw_text(screen, f"VARIANTE  ↳ pai: #{pid} {pname}", FONT_SM, BLUE, right_panel_x + 10, py)
            py += 16
            draw_text(screen, "(flags herdadas do pai)", FONT_SM, TEXT3, right_panel_x + 10, py)
            py += 20
        else:
            # Mostrar se tem variantes filhas
            children = [tid for tid, t in current_state.tiles.items() if t.get("parent_id") == current_state.selected_tile_id]
            if children:
                draw_text(screen, f"PAI  ↳ {len(children)} variante(s): {', '.join(f'#{c}' for c in sorted(children))}", FONT_SM, ACCENT3, right_panel_x + 10, py)
                py += 20

        flags_text = []
        if tile["flags"] & FLAG_SOLIDO:
            flags_text.append("solido")
        if tile["flags"] & FLAG_PASSAGEM:
            flags_text.append("passagem")
        if tile["flags"] & FLAG_TRIGGER:
            flags_text.append("trigger")
        if tile["flags"] & FLAG_ANIMADO:
            flags_text.append("animado")
        draw_text(
            screen,
            ", ".join(flags_text) if flags_text else "sem flags",
            FONT_SM,
            TEXT2,
            right_panel_x + 10,
            py,
        )
        py += 22

        flags_label = "FLAGS  (edita o pai também)" if is_variant else "FLAGS"
        draw_text(screen, flags_label, FONT_SM, TEXT3, right_panel_x + 10, py)
        py += 16

        flag_w = (button_w - 8) // 3
        ui["flag_solido"] = pygame.Rect(right_panel_x + 8, py, flag_w, 24)
        ui["flag_passagem"] = pygame.Rect(right_panel_x + 12 + flag_w, py, flag_w, 24)
        ui["flag_trigger"] = pygame.Rect(right_panel_x + 16 + flag_w * 2, py, flag_w, 24)
        _draw_toggle_button(screen, ui["flag_solido"], "Solido", bool(tile["flags"] & FLAG_SOLIDO), RED)
        _draw_toggle_button(screen, ui["flag_passagem"], "Passagem", bool(tile["flags"] & FLAG_PASSAGEM), BLUE)
        _draw_toggle_button(screen, ui["flag_trigger"], "Trigger", bool(tile["flags"] & FLAG_TRIGGER), PURPLE)
        py += 32

        ui["fps_minus"], ui["fps_plus"] = _draw_adjuster(
            screen,
            right_panel_x + 8,
            py,
            button_w,
            "FPS",
            format_float(tile["fps"], 2),
        )
        py += 28

        ui["z_minus"], ui["z_plus"] = _draw_adjuster(
            screen,
            right_panel_x + 8,
            py,
            button_w,
            "Z",
            str(tile["z"]),
        )
        py += 28

        ui["alpha_minus"], ui["alpha_plus"] = _draw_adjuster(
            screen,
            right_panel_x + 8,
            py,
            button_w,
            "Alpha",
            format_float(tile["alpha"], 2),
        )
        py += 28

        ui["scale_minus"], ui["scale_plus"] = _draw_adjuster(
            screen,
            right_panel_x + 8,
            py,
            button_w,
            "Escala",
            format_float(tile["escala"], 2),
        )
        py += 30

        ui["loop_btn"] = pygame.Rect(right_panel_x + 8, py, button_w, 24)
        loop_active = bool(tile["loop"])
        _draw_toggle_button(screen, ui["loop_btn"], f"Loop: {'Ligado' if loop_active else 'Desligado'}", loop_active, GREEN)
        py += 30

        draw_text(
            screen,
            f"Frames: {len(tile['frames'])}  Atlas: ({current_state.atlas_sel_col}, {current_state.atlas_sel_row})",
            FONT_SM,
            TEXT2,
            right_panel_x + 10,
            py,
        )
        py += 18
        draw_text(
            screen,
            "Atalhos: 1/2/3 flags, [ ] fps, Del apaga tile",
            FONT_SM,
            TEXT3,
            right_panel_x + 10,
            py,
        )
        py += 26
    else:
        draw_text(screen, "Nenhum tile selecionado.", FONT_SM, TEXT3, right_panel_x + 10, py)
        py += 20
        draw_text(screen, "Crie um tile no + da esquerda.", FONT_SM, TEXT3, right_panel_x + 10, py)
        py += 28

    pygame.draw.line(screen, BORDER, (right_panel_x + 8, py), (right_panel_x + PANEL_RIGHT_W - 8, py), 1)
    py += 6
    draw_text(screen, "ATLAS", FONT_SM, TEXT3, right_panel_x + 10, py)
    py += 18

    atlas_draw_x = right_panel_x + 10
    max_atlas_w = PANEL_RIGHT_W - 20
    next_py, atlas_rect, atlas_scale = draw_atlas_panel(screen, current_state, atlas_draw_x, py, max_atlas_w)
    py = next_py

    if current_state.atlas_img:
        image_w, image_h = current_state.atlas_img.get_size()
        draw_text(
            screen,
            f"{image_w}x{image_h}px - sel: col={current_state.atlas_sel_col} lin={current_state.atlas_sel_row}",
            FONT_SM,
            TEXT3,
            right_panel_x + 10,
            py,
        )

    ui["atlas_panel_rect"] = atlas_rect
    ui["atlas_scale"] = atlas_scale
    return ui


# ---------------------------------------------------------------------------
# RENDER DE TILE
# ---------------------------------------------------------------------------
def _draw_tile_fallback(surf, tile_id, rx, ry, tw, th):
    colors = [
        (58, 123, 213),
        (231, 76, 60),
        (46, 204, 113),
        (230, 126, 34),
        (155, 89, 182),
        (26, 188, 156),
        (241, 196, 15),
    ]
    color = (*colors[tile_id % len(colors)], 140)
    sample = pygame.Surface((tw, th), pygame.SRCALPHA)
    sample.fill(color)
    surf.blit(sample, (rx, ry))
    label = FONT_SM.render(str(tile_id), True, TEXT)
    surf.blit(label, (rx + tw // 2 - label.get_width() // 2, ry + th // 2 - label.get_height() // 2))


def _draw_tile_at(surf, current_state: EditorState, tile_id, rx, ry, tw, th):
    tile = current_state.tiles.get(tile_id)
    if not tile or not tile["frames"]:
        return

    frame = tile["frames"][0]
    if current_state.atlas_img:
        src = pygame.Rect(frame["col"] * current_state.tile_w, frame["row"] * current_state.tile_h, current_state.tile_w, current_state.tile_h)
        try:
            sub = current_state.atlas_img.subsurface(src)
            scaled = pygame.transform.scale(sub, (tw, th))
            scaled.set_alpha(int(tile.get("alpha", 1.0) * 255))
            surf.blit(scaled, (rx, ry))
        except Exception:
            _draw_tile_fallback(surf, tile_id, rx, ry, tw, th)
    else:
        _draw_tile_fallback(surf, tile_id, rx, ry, tw, th)

    if tile["flags"] & FLAG_SOLIDO:
        pygame.draw.rect(surf, (*RED, 130), (rx, ry, 4, 4))
    if tile["flags"] & FLAG_TRIGGER:
        pygame.draw.rect(surf, (*PURPLE, 130), (rx + tw - 4, ry, 4, 4))
    if tile["flags"] & FLAG_PASSAGEM:
        pygame.draw.rect(surf, (*BLUE, 130), (rx, ry + th - 4, 4, 4))


# ---------------------------------------------------------------------------
# AÇÕES DE EDIÇÃO
# ---------------------------------------------------------------------------
def _paint(current_state: EditorState, col, row):
    if current_state.tool == TOOL_PAINT:
        if current_state.selected_tile_id:
            current_state.set_tile(col, row, current_state.selected_tile_id)
    elif current_state.tool == TOOL_ERASE:
        current_state.set_tile(col, row, 0)
    elif current_state.tool == TOOL_PICK:
        tile_id = current_state.tile_at(col, row)
        if tile_id != 0 and tile_id in current_state.tiles:
            current_state.selected_tile_id = tile_id
            current_state.tool = TOOL_PAINT
    elif current_state.tool == TOOL_FILL:
        target = current_state.tile_at(col, row)
        replacement = current_state.selected_tile_id or 0
        current_state.flood_fill(col, row, target, replacement)


def adjust_selected_tile_value(current_state: EditorState, field: str, delta: float):
    tile = current_state.get_selected_tile()
    if not tile:
        return

    # Se for variante, ajusta no pai e sincroniza
    pid = tile.get("parent_id")
    target = current_state.tiles[pid] if pid and pid in current_state.tiles else tile
    target_id = pid if pid else current_state.selected_tile_id

    if field == "fps":
        # FPS é próprio de cada tile (variante pode ter animação diferente)
        tile["fps"] = clamp(tile["fps"] + delta, 0.0, 60.0)
        if tile["fps"] < 0.01:
            tile["fps"] = 0.0
        current_state.update_animation_flag(current_state.selected_tile_id)
    elif field == "z":
        target["z"] = clamp(int(target["z"] + delta), -128, 128)
        current_state.sync_variant_from_parent(target_id)
    elif field == "alpha":
        target["alpha"] = clamp(target["alpha"] + delta, 0.0, 1.0)
        current_state.sync_variant_from_parent(target_id)
    elif field == "escala":
        target["escala"] = clamp(target["escala"] + delta, 0.25, 4.0)
        current_state.sync_variant_from_parent(target_id)


def add_frame_to_selected(current_state: EditorState):
    tile = current_state.get_selected_tile()
    if not tile:
        return
    if len(tile["frames"]) >= 32:
        return
    tile["frames"].append({"col": current_state.atlas_sel_col, "row": current_state.atlas_sel_row})
    current_state.update_animation_flag(current_state.selected_tile_id)


def handle_right_panel_action(current_state: EditorState, ui_rects):
    if not ui_rects:
        return

    mouse_pos = pygame.mouse.get_pos()

    if ui_rects["atlas_btn"].collidepoint(mouse_pos):
        path = open_atlas_dialog()
        if path:
            try:
                load_atlas(current_state, path)
            except Exception as exc:
                print(f"[Atlas] Erro: {exc}")
        return

    if ui_rects["resize_btn"].collidepoint(mouse_pos):
        result = run_resize_dialog(current_state.cols, current_state.rows, current_state.tile_w, current_state.tile_h)
        if result:
            cols, rows, tile_w, tile_h = result
            current_state._old_cols = current_state.cols
            current_state._old_rows = current_state.rows
            current_state.cols = cols
            current_state.rows = rows
            current_state.tile_w = tile_w
            current_state.tile_h = tile_h
            current_state.init_grid(keep=True)
            for tile in current_state.tiles.values():
                tile["larg"] = tile_w
                tile["alt"] = tile_h
            if current_state.atlas_img:
                max_col = max(0, current_state.atlas_img.get_width() // current_state.tile_w - 1)
                max_row = max(0, current_state.atlas_img.get_height() // current_state.tile_h - 1)
                current_state.atlas_sel_col = clamp(current_state.atlas_sel_col, 0, max_col)
                current_state.atlas_sel_row = clamp(current_state.atlas_sel_row, 0, max_row)
        return

    if ui_rects["add_variant_btn"].collidepoint(mouse_pos):
        result = ask_new_variant(current_state)
        if result:
            number, name, parent_id = result
            current_state.new_variant_def(number, name, parent_id, current_state.atlas_sel_col, current_state.atlas_sel_row)
            current_state.selected_tile_id = number
        return

    if ui_rects["add_frame_btn"].collidepoint(mouse_pos):
        add_frame_to_selected(current_state)
        return

    if ui_rects["clear_btn"].collidepoint(mouse_pos):
        if confirm_clear_map():
            current_state.clear_canvas()
        return

    if ui_rects["delete_btn"].collidepoint(mouse_pos) and current_state.selected_tile_id:
        current_state.delete_tile(current_state.selected_tile_id)
        return

    tile = current_state.get_selected_tile()
    if not tile:
        return

    if "rename_btn" in ui_rects and ui_rects["rename_btn"].collidepoint(mouse_pos):
        new_name = ask_rename_tile(tile["name"])
        if new_name:
            tile["name"] = new_name
        return

    flag_map = {
        "flag_solido": FLAG_SOLIDO,
        "flag_passagem": FLAG_PASSAGEM,
        "flag_trigger": FLAG_TRIGGER,
    }
    for key, flag in flag_map.items():
        rect = ui_rects.get(key)
        if rect and rect.collidepoint(mouse_pos):
            current_state.toggle_flag(current_state.selected_tile_id, flag)
            return

    action_map = {
        "fps_minus": ("fps", -0.5),
        "fps_plus": ("fps", 0.5),
        "z_minus": ("z", -1),
        "z_plus": ("z", 1),
        "alpha_minus": ("alpha", -0.05),
        "alpha_plus": ("alpha", 0.05),
        "scale_minus": ("escala", -0.05),
        "scale_plus": ("escala", 0.05),
    }
    for key, (field, delta) in action_map.items():
        rect = ui_rects.get(key)
        if rect and rect.collidepoint(mouse_pos):
            adjust_selected_tile_value(current_state, field, delta)
            return

    loop_rect = ui_rects.get("loop_btn")
    if loop_rect and loop_rect.collidepoint(mouse_pos):
        tile["loop"] = not tile["loop"]
        return


def export_current_map(current_state: EditorState):
    if not current_state.tiles:
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        try:
            messagebox.showerror("Exportar", "Crie ao menos um tile antes de exportar.", parent=root)
        finally:
            root.destroy()
        return

    path = ask_export_path(current_state.var_name)
    if not path:
        return

    current_state.var_name = sanitize_lua_identifier(os.path.splitext(os.path.basename(path))[0])
    lua_text = export_lua(current_state)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(lua_text)

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        messagebox.showinfo("Exportado", f"Arquivo salvo em:\n{path}", parent=root)
    finally:
        root.destroy()


# ---------------------------------------------------------------------------
# JANELA PRINCIPAL
# ---------------------------------------------------------------------------
def main():
    screen = pygame.display.set_mode((WIN_W, WIN_H), pygame.RESIZABLE)
    pygame.display.set_caption("TupiEngine — Editor de Mapas")
    clock = pygame.time.Clock()

    try_load_default_atlas(state)

    tools = [TOOL_PAINT, TOOL_ERASE, TOOL_FILL, TOOL_PICK]
    tool_labels = {
        "paint": "Pintar",
        "erase": "Apagar",
        "fill": "Preencher",
        "pick": "Pegar tile",
    }
    tool_btns: dict[str, Button] = {}
    right_panel_ui = {}

    running = True
    while running:
        ww, wh = screen.get_size()

        canvas_area_x = PANEL_LEFT_W
        canvas_area_w = ww - PANEL_LEFT_W - PANEL_RIGHT_W
        canvas_area_y = HEADER_H + TOOLBAR_H
        canvas_area_h = wh - canvas_area_y - STATUSBAR_H
        right_panel_x = ww - PANEL_RIGHT_W

        total_canvas_w = int(state.cols * state.tile_w * state.zoom)
        total_canvas_h = int(state.rows * state.tile_h * state.zoom)
        max_scroll_x = max(0, total_canvas_w - canvas_area_w + 40)
        max_scroll_y = max(0, total_canvas_h - canvas_area_h + 40)
        state.scroll_x = clamp(state.scroll_x, 0, max_scroll_x)
        state.scroll_y = clamp(state.scroll_y, 0, max_scroll_y)

        visible_list_h = wh - (HEADER_H + 32) - STATUSBAR_H
        max_tile_list_scroll = max(0, len(state.tiles) * TILE_ITEM_H - visible_list_h)
        state.tile_list_scroll = clamp(state.tile_list_scroll, 0, max_tile_list_scroll)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            for tool_name, btn in tool_btns.items():
                if btn.handle_event(event):
                    state.tool = tool_name
                    for button in tool_btns.values():
                        button.active = False
                    tool_btns[tool_name].active = True

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_p:
                    state.tool = TOOL_PAINT
                if event.key == pygame.K_e:
                    state.tool = TOOL_ERASE
                if event.key == pygame.K_f:
                    state.tool = TOOL_FILL
                if event.key == pygame.K_i:
                    state.tool = TOOL_PICK

                if event.key in (pygame.K_EQUALS, pygame.K_PLUS):
                    state.zoom = min(state.zoom * 1.4, 12)
                if event.key == pygame.K_MINUS:
                    state.zoom = max(state.zoom / 1.4, 0.25)
                if event.key == pygame.K_0:
                    state.zoom = 3.0

                if event.key == pygame.K_LEFT:
                    state.scroll_x = max(0, state.scroll_x - 24)
                if event.key == pygame.K_RIGHT:
                    state.scroll_x += 24
                if event.key == pygame.K_UP:
                    state.scroll_y = max(0, state.scroll_y - 24)
                if event.key == pygame.K_DOWN:
                    state.scroll_y += 24

                if event.key == pygame.K_1 and state.selected_tile_id:
                    state.toggle_flag(state.selected_tile_id, FLAG_SOLIDO)
                if event.key == pygame.K_2 and state.selected_tile_id:
                    state.toggle_flag(state.selected_tile_id, FLAG_PASSAGEM)
                if event.key == pygame.K_3 and state.selected_tile_id:
                    state.toggle_flag(state.selected_tile_id, FLAG_TRIGGER)
                if event.key == pygame.K_LEFTBRACKET:
                    adjust_selected_tile_value(state, "fps", -0.5)
                if event.key == pygame.K_RIGHTBRACKET:
                    adjust_selected_tile_value(state, "fps", 0.5)
                if event.key == pygame.K_DELETE and state.selected_tile_id:
                    state.delete_tile(state.selected_tile_id)
                if event.key == pygame.K_RETURN and pygame.key.get_mods() & pygame.KMOD_CTRL:
                    export_current_map(state)
                if event.key == pygame.K_o and pygame.key.get_mods() & pygame.KMOD_CTRL:
                    import_map_from_file(state)

            if event.type == pygame.MOUSEWHEEL:
                mouse_x, mouse_y = pygame.mouse.get_pos()
                if canvas_area_x < mouse_x < canvas_area_x + canvas_area_w:
                    if pygame.key.get_mods() & pygame.KMOD_CTRL:
                        if event.y > 0:
                            state.zoom = min(state.zoom * 1.15, 12)
                        else:
                            state.zoom = max(state.zoom / 1.15, 0.25)
                    else:
                        state.scroll_y -= event.y * 24
                        state.scroll_x -= event.x * 24
                elif mouse_x <= PANEL_LEFT_W:
                    state.tile_list_scroll -= event.y * 16

            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                mouse_x, mouse_y = event.pos

                export_rect = pygame.Rect(ww - 116, 11, 106, 28)
                if export_rect.collidepoint(mouse_x, mouse_y):
                    export_current_map(state)
                    continue

                import_rect = pygame.Rect(ww - 236, 11, 106, 28)
                if import_rect.collidepoint(mouse_x, mouse_y):
                    import_map_from_file(state)
                    continue

                if right_panel_x <= mouse_x <= ww:
                    handle_right_panel_action(state, right_panel_ui)
                    atlas_rect = right_panel_ui.get("atlas_panel_rect")
                    atlas_scale = right_panel_ui.get("atlas_scale", 1.0)
                    if atlas_rect and state.atlas_img:
                        ax, ay, aw_px, ah_px = atlas_rect
                        if ax <= mouse_x <= ax + aw_px and ay <= mouse_y <= ay + ah_px:
                            tile_w_scaled = state.tile_w * atlas_scale
                            tile_h_scaled = state.tile_h * atlas_scale
                            max_col = max(0, state.atlas_img.get_width() // state.tile_w - 1)
                            max_row = max(0, state.atlas_img.get_height() // state.tile_h - 1)
                            state.atlas_sel_col = clamp(int((mouse_x - ax) / tile_w_scaled), 0, max_col)
                            state.atlas_sel_row = clamp(int((mouse_y - ay) / tile_h_scaled), 0, max_row)
                    continue

                if 0 <= mouse_x <= PANEL_LEFT_W:
                    plus_btn = pygame.Rect(PANEL_LEFT_W - 26, HEADER_H + 6, 20, 20)
                    if plus_btn.collidepoint(mouse_x, mouse_y):
                        result = ask_new_tile(state)
                        if result:
                            number, name = result
                            state.new_tile_def(number, name, 0, state.atlas_sel_col, state.atlas_sel_row)
                            state.selected_tile_id = number
                        continue

                    list_y0 = HEADER_H + 32
                    list_y1 = wh - STATUSBAR_H
                    if list_y0 <= mouse_y <= list_y1:
                        tile_ids = sorted(state.tiles.keys())
                        index = int((mouse_y - list_y0 + state.tile_list_scroll) / TILE_ITEM_H)
                        if 0 <= index < len(tile_ids):
                            state.selected_tile_id = tile_ids[index]
                        continue

                if canvas_area_x <= mouse_x < canvas_area_x + canvas_area_w and canvas_area_y <= mouse_y < canvas_area_y + canvas_area_h:
                    state.is_painting = True
                    tile_w_scaled = state.tile_w * state.zoom
                    tile_h_scaled = state.tile_h * state.zoom
                    col = int((mouse_x - canvas_area_x + state.scroll_x) / tile_w_scaled)
                    row = int((mouse_y - canvas_area_y + state.scroll_y) / tile_h_scaled)
                    _paint(state, col, row)
                    state.last_painted = (col, row)

            if event.type == pygame.MOUSEBUTTONUP and event.button == 1:
                state.is_painting = False
                state.last_painted = (-1, -1)

            if event.type == pygame.MOUSEMOTION and state.is_painting:
                mouse_x, mouse_y = event.pos
                tile_w_scaled = state.tile_w * state.zoom
                tile_h_scaled = state.tile_h * state.zoom
                col = int((mouse_x - canvas_area_x + state.scroll_x) / tile_w_scaled)
                row = int((mouse_y - canvas_area_y + state.scroll_y) / tile_h_scaled)
                if (col, row) != state.last_painted:
                    _paint(state, col, row)
                    state.last_painted = (col, row)

        screen.fill(BG)

        draw_rect_filled(screen, BG2, (0, 0, ww, HEADER_H))
        pygame.draw.line(screen, BORDER, (0, HEADER_H), (ww, HEADER_H), 1)
        draw_text(screen, "TupiEngine - Map Editor", FONT_BOLD, ACCENT, 16, 14)
        draw_text(screen, f"Atlas: {state.atlas_path}", FONT_SM, TEXT3, 246, 15)
        pygame.draw.line(screen, BORDER, (236, 10), (236, HEADER_H - 10), 1)

        export_rect = pygame.Rect(ww - 116, 11, 106, 28)
        draw_rect_filled(screen, ACCENT, export_rect, 5)
        draw_text(screen, "Exportar .lua", FONT_BOLD, (17, 17, 17), export_rect.centerx, export_rect.top + 8, "center")

        import_rect = pygame.Rect(ww - 236, 11, 106, 28)
        draw_rect_filled(screen, BG3, import_rect, 5)
        draw_rect_border(screen, BORDER2, import_rect, 1, 5)
        draw_text(screen, "Importar .lua", FONT_BOLD, TEXT2, import_rect.centerx, import_rect.top + 8, "center")

        toolbar_y = HEADER_H
        draw_rect_filled(screen, BG2, (canvas_area_x, toolbar_y, canvas_area_w, TOOLBAR_H))
        pygame.draw.line(
            screen,
            BORDER,
            (canvas_area_x, toolbar_y + TOOLBAR_H),
            (canvas_area_x + canvas_area_w, toolbar_y + TOOLBAR_H),
            1,
        )

        button_x = canvas_area_x + 8
        tool_btns.clear()
        for tool_name in tools:
            btn = Button((button_x, toolbar_y + 8, 92, 28), tool_labels[tool_name], FONT_SM, active=(state.tool == tool_name))
            btn.draw(screen)
            tool_btns[tool_name] = btn
            button_x += 98

        draw_text(
            screen,
            f"Zoom: {int(state.zoom * 100)}%",
            FONT_SM,
            TEXT3,
            canvas_area_x + canvas_area_w - 92,
            toolbar_y + 14,
        )

        clip_rect = pygame.Rect(canvas_area_x, canvas_area_y, canvas_area_w, canvas_area_h)
        screen.set_clip(clip_rect)

        tile_w_scaled = state.tile_w * state.zoom
        tile_h_scaled = state.tile_h * state.zoom
        origin_x = canvas_area_x - state.scroll_x
        origin_y = canvas_area_y - state.scroll_y

        for row in range(state.rows):
            for col in range(state.cols):
                rx = int(origin_x + col * tile_w_scaled)
                ry = int(origin_y + row * tile_h_scaled)
                if rx + tile_w_scaled < canvas_area_x or rx > canvas_area_x + canvas_area_w:
                    continue
                if ry + tile_h_scaled < canvas_area_y or ry > canvas_area_y + canvas_area_h:
                    continue
                color = BG3 if (row + col) % 2 == 0 else (18, 19, 22)
                pygame.draw.rect(screen, color, (rx, ry, int(tile_w_scaled) + 1, int(tile_h_scaled) + 1))

        for row in range(state.rows):
            for col in range(state.cols):
                tile_id = state.tile_at(col, row)
                if tile_id == 0:
                    continue
                rx = int(origin_x + col * tile_w_scaled)
                ry = int(origin_y + row * tile_h_scaled)
                if rx + tile_w_scaled < canvas_area_x or rx > canvas_area_x + canvas_area_w:
                    continue
                if ry + tile_h_scaled < canvas_area_y or ry > canvas_area_y + canvas_area_h:
                    continue
                _draw_tile_at(screen, state, tile_id, rx, ry, int(tile_w_scaled), int(tile_h_scaled))

        if state.zoom >= 1.0:
            for col in range(state.cols + 1):
                px = int(origin_x + col * tile_w_scaled)
                if canvas_area_x <= px <= canvas_area_x + canvas_area_w:
                    pygame.draw.line(screen, BORDER, (px, canvas_area_y), (px, canvas_area_y + canvas_area_h), 1)
            for row in range(state.rows + 1):
                py = int(origin_y + row * tile_h_scaled)
                if canvas_area_y <= py <= canvas_area_y + canvas_area_h:
                    pygame.draw.line(screen, BORDER, (canvas_area_x, py), (canvas_area_x + canvas_area_w, py), 1)

        if state.selected_tile_id and state.tool == TOOL_PAINT:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            if canvas_area_x <= mouse_x < canvas_area_x + canvas_area_w and canvas_area_y <= mouse_y < canvas_area_y + canvas_area_h:
                hover_col = int((mouse_x - canvas_area_x + state.scroll_x) / tile_w_scaled)
                hover_row = int((mouse_y - canvas_area_y + state.scroll_y) / tile_h_scaled)
                if 0 <= hover_col < state.cols and 0 <= hover_row < state.rows:
                    hx = int(origin_x + hover_col * tile_w_scaled)
                    hy = int(origin_y + hover_row * tile_h_scaled)
                    pygame.draw.rect(screen, ACCENT, (hx, hy, int(tile_w_scaled), int(tile_h_scaled)), 2)

        screen.set_clip(None)

        draw_rect_filled(screen, BG2, (0, HEADER_H, PANEL_LEFT_W, wh - HEADER_H))
        pygame.draw.line(screen, BORDER, (PANEL_LEFT_W, HEADER_H), (PANEL_LEFT_W, wh), 1)

        draw_text(screen, "TILES", FONT_SM, TEXT3, 14, HEADER_H + 10)
        plus_btn = pygame.Rect(PANEL_LEFT_W - 26, HEADER_H + 6, 20, 20)
        draw_rect_border(screen, BORDER2, plus_btn, 1, 4)
        draw_text(screen, "+", FONT_MD, ACCENT, plus_btn.centerx, plus_btn.top + 3, "center")
        pygame.draw.line(screen, BORDER, (0, HEADER_H + 30), (PANEL_LEFT_W, HEADER_H + 30), 1)

        tile_ids = sorted(state.tiles.keys())
        list_y0 = HEADER_H + 32
        screen.set_clip(pygame.Rect(0, list_y0, PANEL_LEFT_W, wh - list_y0 - STATUSBAR_H))

        for index, tile_id in enumerate(tile_ids):
            item_y = list_y0 + index * TILE_ITEM_H - state.tile_list_scroll
            if item_y + TILE_ITEM_H < list_y0 or item_y > wh:
                continue

            tile = state.tiles[tile_id]
            is_selected = state.selected_tile_id == tile_id
            is_variant = tile.get("parent_id") is not None
            bg_color = BG4 if is_selected else BG2
            draw_rect_filled(screen, bg_color, (0, item_y, PANEL_LEFT_W, TILE_ITEM_H))
            if is_selected:
                accent = BLUE if is_variant else ACCENT
                pygame.draw.rect(screen, accent, (0, item_y, 3, TILE_ITEM_H))

            indent = 18 if is_variant else 0
            preview_rect = pygame.Rect(10 + indent, item_y + 7, 28, 28)

            # Linha de conexão pai→filho
            if is_variant:
                pygame.draw.line(screen, BORDER2, (8, item_y + 4), (8, item_y + TILE_ITEM_H // 2), 1)
                pygame.draw.line(screen, BORDER2, (8, item_y + TILE_ITEM_H // 2), (14, item_y + TILE_ITEM_H // 2), 1)

            draw_rect_filled(screen, BG3, preview_rect, 3)
            if state.atlas_img and tile["frames"]:
                frame = tile["frames"][0]
                src = pygame.Rect(frame["col"] * state.tile_w, frame["row"] * state.tile_h, state.tile_w, state.tile_h)
                try:
                    sub = state.atlas_img.subsurface(src)
                    small = pygame.transform.scale(sub, (28, 28))
                    screen.blit(small, preview_rect)
                except Exception:
                    pass
            else:
                _draw_tile_fallback(screen, tile_id, preview_rect.x, preview_rect.y, 28, 28)

            # Borda colorida no preview de variante
            if is_variant:
                pygame.draw.rect(screen, BLUE, preview_rect, 1)

            name_x = 46 + indent
            draw_text(screen, tile["name"], FONT_MD, TEXT if not is_variant else TEXT2, name_x, item_y + 8)
            if is_variant:
                pid = tile["parent_id"]
                pname = state.tiles.get(pid, {}).get("name", f"#{pid}")
                draw_text(screen, f"↳ {pname}", FONT_SM, TEXT3, name_x, item_y + 24)
            else:
                meta = [f"{len(tile['frames'])} frame(s)"]
                if tile["fps"] > 0:
                    meta.append(f"{format_float(tile['fps'], 2)} fps")
                draw_text(screen, " · ".join(meta), FONT_SM, TEXT3, name_x, item_y + 24)

            flag_x = PANEL_LEFT_W - 44
            if tile["flags"] & FLAG_SOLIDO:
                draw_text(screen, "S", FONT_SM, RED, flag_x, item_y + 8)
            if tile["flags"] & FLAG_PASSAGEM:
                draw_text(screen, "P", FONT_SM, BLUE, flag_x + 10, item_y + 8)
            if tile["flags"] & FLAG_TRIGGER:
                draw_text(screen, "T", FONT_SM, PURPLE, flag_x + 20, item_y + 8)
            if tile["flags"] & FLAG_ANIMADO:
                draw_text(screen, "A", FONT_SM, GREEN, flag_x, item_y + 22)

            draw_text(screen, f"#{tile_id}", FONT_SM, TEXT3, PANEL_LEFT_W - 8, item_y + 15, "right")

        screen.set_clip(None)

        if not tile_ids:
            draw_text(screen, "Nenhum tile.", FONT_SM, TEXT3, PANEL_LEFT_W // 2, list_y0 + 20, "center")
            draw_text(screen, "Clique em + para", FONT_SM, TEXT3, PANEL_LEFT_W // 2, list_y0 + 38, "center")
            draw_text(screen, "adicionar.", FONT_SM, TEXT3, PANEL_LEFT_W // 2, list_y0 + 54, "center")

        right_panel_ui = draw_right_panel(screen, state, ww, wh)

        draw_rect_filled(screen, BG2, (0, wh - STATUSBAR_H, ww, STATUSBAR_H))
        pygame.draw.line(screen, BORDER, (0, wh - STATUSBAR_H), (ww, wh - STATUSBAR_H), 1)
        status_x = 12
        status_x += draw_text(screen, "Mapa: ", FONT_SM, TEXT3, status_x, wh - 18) + 2
        status_x += draw_text(screen, f"{state.cols}x{state.rows} ({state.tile_w}x{state.tile_h}px)", FONT_SM, TEXT2, status_x, wh - 18) + 16
        status_x += draw_text(screen, "Tile: ", FONT_SM, TEXT3, status_x, wh - 18) + 2
        selected_label = (
            f"#{state.selected_tile_id} {state.tiles.get(state.selected_tile_id, {}).get('name', '')}"
            if state.selected_tile_id
            else "nenhum"
        )
        status_x += draw_text(screen, selected_label, FONT_SM, TEXT2, status_x, wh - 18) + 16
        status_x += draw_text(screen, "Ferramenta: ", FONT_SM, TEXT3, status_x, wh - 18) + 2
        draw_text(screen, state.tool, FONT_SM, ACCENT, status_x, wh - 18)

        draw_text(
            screen,
            "[P]intar [E]apagar [F]preencher [I]pegar  [Ctrl+Scroll] Zoom  [Ctrl+O] Importar  [Ctrl+Enter] Exportar",
            FONT_SM,
            TEXT3,
            ww - 520,
            wh - 18,
        )

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()
    sys.exit()


# ---------------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    main()