#!/usr/bin/env python3
# empacotar.py — TupiEngine  (Linux · Windows · macOS)
# Requer: Python 3.8+, luajit, cargo, gcc (Linux/macOS) ou cl/mingw (Windows)

import sys
import os
import shutil
import struct
import zlib
import subprocess
import tempfile
import platform
import datetime
import argparse

IS_WIN = platform.system() == "Windows"

def _ansi(code, text):
    if IS_WIN:
        return text
    return f"\033[{code}m{text}\033[0m"

def ok(msg):   print(_ansi("32",   "+ ") + msg)           # verde  — sucesso
def info(msg): print(_ansi("36",   "> ") + msg)           # ciano  — progresso
def warn(msg): print(_ansi("33",   "! ") + msg)           # amarelo — aviso
def err(msg):  print(_ansi("31",   "x ") + msg, file=sys.stderr)  # vermelho — erro
def sep():     print(_ansi("2",    "-" * 44))
def bold(t):   return _ansi("1", t)
def dim(t):    return _ansi("2", t)

def header():
    os.system("cls" if IS_WIN else "clear")
    c = "\033[36m\033[1m" if not IS_WIN else ""
    r = "\033[0m"         if not IS_WIN else ""
    print(f"{c}╔══════════════════════════════════════════════════════╗")
    print(f"║         TupiEngine — Empacotador de Projeto          ║")
    print(f"╚══════════════════════════════════════════════════════╝{r}\n")

# --- PNG puro (sem Pillow) ---

def png_read_rgba(path):
    """Lê qualquer PNG (RGB ou RGBA, 8 bits) e retorna (w, h, list[(r,g,b,a)])."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"Não é um PNG válido: {path}")
    pos = 8
    chunks = {}
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        ctype  = data[pos+4:pos+8]
        cdata  = data[pos+8:pos+8+length]
        chunks.setdefault(ctype, []).append(cdata)
        pos += 12 + length
    ihdr     = chunks[b'IHDR'][0]
    w, h     = struct.unpack(">II", ihdr[:8])
    bd, ct   = ihdr[8], ihdr[9]
    if bd != 8 or ct not in (2, 6):
        raise ValueError(f"PNG não suportado (bit_depth={bd} color_type={ct}). Use RGB ou RGBA 8-bit.")
    channels = 3 if ct == 2 else 4
    raw      = zlib.decompress(b''.join(chunks[b'IDAT']))
    stride   = w * channels + 1
    pixels   = []
    prev     = bytes(w * channels)
    for y in range(h):
        ft  = raw[y * stride]
        row = bytearray(raw[y * stride + 1:(y + 1) * stride])
        dec = bytearray(w * channels)
        for i in range(w * channels):
            a  = row[i]
            b  = prev[i]               if ft in (2, 3, 4) else 0
            cl = dec[i - channels]     if (ft in (1, 3, 4) and i >= channels) else 0
            cu = prev[i - channels]    if (ft == 4 and i >= channels) else 0
            if   ft == 0: v = a
            elif ft == 1: v = (a + cl) & 0xFF
            elif ft == 2: v = (a + b)  & 0xFF
            elif ft == 3: v = (a + (cl + b) // 2) & 0xFF
            else:
                pa = abs(b - cu); pb = abs(cl - cu); pc = abs(cl + b - 2 * cu)
                pr = b if (pb < pa and pb <= pc) else (cu if pc < pa else cl)
                v  = (a + pr) & 0xFF
            dec[i] = v
        prev = bytes(dec)
        for x in range(w):
            r2 = dec[x * channels];     g2 = dec[x * channels + 1]
            b2 = dec[x * channels + 2]; a2 = dec[x * channels + 3] if channels == 4 else 255
            pixels.append((r2, g2, b2, a2))
    return w, h, pixels

def png_write_rgba(path, w, h, pixels):
    """Escreve pixels RGBA em PNG sem dependências externas."""
    def chunk(t, d):
        crc = zlib.crc32(t + d) & 0xFFFFFFFF
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", crc)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    raw  = b''
    for y in range(h):
        raw += b'\x00'
        for x in range(w):
            r2, g2, b2, a2 = pixels[y * w + x]
            raw += bytes([r2, g2, b2, a2])
    idat = zlib.compress(raw, 6)
    with open(path, "wb") as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', idat))
        f.write(chunk(b'IEND', b''))

def png_resize_nn(src, dst, size):
    """Redimensiona PNG para size×size. Tenta ImageMagick, ffmpeg ou Python puro."""
    if shutil.which("convert"):
        r = subprocess.run(["convert", src, "-resize", f"{size}x{size}!", dst], capture_output=True)
        if r.returncode == 0:
            return
    if shutil.which("ffmpeg"):
        r = subprocess.run(["ffmpeg", "-y", "-i", src, "-vf", f"scale={size}:{size}", dst], capture_output=True)
        if r.returncode == 0:
            return
    try:
        sw, sh, px = png_read_rgba(src)
        out = []
        for y in range(size):
            sy = int(y * sh / size)
            for x in range(size):
                sx = int(x * sw / size)
                out.append(px[sy * sw + sx])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        png_write_rgba(dst, size, size, out)
    except Exception as e:
        warn(f"Redimensionamento falhou ({e}), copiando original.")
        shutil.copy(src, dst)

# --- Bytecode Lua ---

def bytes_para_c_array(data: bytes, simbolo: str) -> str:
    hex_vals = ", ".join(f"0x{b:02x}" for b in data)
    return (
        f"static const unsigned char {simbolo}[] = {{\n"
        f"    {hex_vals}\n"
        f"}};\n"
        f"static const unsigned int {simbolo}_SIZE = {len(data)};\n\n"
    )

def compilar_lua_bytecode(lua_file: str, tmpdir: str):
    out = os.path.join(tmpdir, os.path.basename(lua_file) + ".bc")
    r = subprocess.run(["luajit", "-b", lua_file, out], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    with open(out, "rb") as f:
        return f.read()

def gerar_all_bytecodes(lua_extras: list[str]) -> bool:
    header_path = "all_bytecodes.h"
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        "/*",
        " * all_bytecodes.h — gerado por empacotar.py, nao edite.",
        f" * {now}",
        " */\n",
        "#ifndef ALL_BYTECODES_H",
        "#define ALL_BYTECODES_H\n",
    ]

    print(f"\n{bold('Compilando modulos Lua para bytecode...')}\n")

    modulos  = []
    simbolos = []
    erros    = 0

    with tempfile.TemporaryDirectory(prefix="tupi_bc_") as tmpdir:
        for lua_file in lua_extras:
            if not os.path.isfile(lua_file):
                warn(f"Não encontrado: {lua_file} — pulando")
                continue
            modulo  = lua_file.removesuffix(".lua").replace(os.sep, ".").replace("/", ".")
            sym     = modulo.replace(".", "_").replace("-", "_")
            simbolo = f"tupi_bc_{sym}"
            info(f"Compilando: {lua_file}  ->  \"{modulo}\"")
            try:
                bc = compilar_lua_bytecode(lua_file, tmpdir)
                lines.append(f'/* modulo: "{modulo}"  <- {lua_file} */')
                lines.append(bytes_para_c_array(bc, simbolo))
                modulos.append(modulo)
                simbolos.append(simbolo)
                ok(f"  {simbolo}  ({len(bc)} bytes)")
            except Exception as e:
                err(f"  Falha: {lua_file} — {e}")
                erros += 1

        lines += [
            "typedef struct {",
            "    const char          *nome;",
            "    const unsigned char *bc;",
            "    unsigned int         sz;",
            "} TupiModule;\n",
            "static const TupiModule TUPI_MODULES[] = {",
        ]
        for m, s in zip(modulos, simbolos):
            lines.append(f'    {{ "{m}", {s}, {s}_SIZE }},')
        lines += ["    { NULL, NULL, 0 }", "};\n"]

        print()
        info("Compilando: main.lua  ->  tupi_bc_main")
        try:
            bc_main = compilar_lua_bytecode("main.lua", tmpdir)
            lines.append("/* main.lua — ponto de entrada */")
            lines.append(bytes_para_c_array(bc_main, "tupi_bc_main"))
            ok(f"  tupi_bc_main  ({len(bc_main)} bytes)")
        except Exception as e:
            err(f"Falha ao compilar main.lua: {e}")
            return False

    lines.append("#endif /* ALL_BYTECODES_H */")
    with open(header_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    if erros:
        warn(f"{erros} módulo(s) falharam — verifique acima.")
    ok(f"all_bytecodes.h: {len(modulos)} módulo(s) + main")
    if modulos:
        print(dim("  Módulos embutidos:"))
        for m in modulos:
            print(dim(f"    -> {m}"))
    sep()
    return True

# --- Instalação de ícone (Linux) ---

def purgar_icone_linux(nome_safe: str):
    """Remove TODOS os rastros do ícone antigo do hicolor e apaga caches binários.
    Deve ser chamado ANTES de instalar o novo ícone."""
    icons_base = os.path.expanduser("~/.local/share/icons/hicolor")
    if not os.path.isdir(icons_base):
        return

    # Apaga o PNG em cada tamanho possível (não só os 4 que usamos)
    for entrada in os.listdir(icons_base):
        apps_dir = os.path.join(icons_base, entrada, "apps")
        alvo = os.path.join(apps_dir, f"{nome_safe}.png")
        if os.path.isfile(alvo):
            os.remove(alvo)

        # Apaga o cache binário desse tamanho para forçar reindexação
        for cache_nome in ("icon-theme.cache", "index.theme"):
            cache = os.path.join(icons_base, entrada, cache_nome)
            if os.path.isfile(cache):
                try:
                    os.remove(cache)
                except OSError:
                    pass

    # Apaga o cache raiz do hicolor
    for cache_nome in ("icon-theme.cache", "index.theme"):
        cache = os.path.join(icons_base, cache_nome)
        if os.path.isfile(cache):
            try:
                os.remove(cache)
            except OSError:
                pass

    # Remove também o .desktop antigo do sistema (evita entrada zumbi)
    apps_dir = os.path.expanduser("~/.local/share/applications")
    desktop_antigo = os.path.join(apps_dir, f"{nome_safe}.desktop")
    if os.path.isfile(desktop_antigo):
        os.remove(desktop_antigo)


def instalar_icone_linux(src_png: str, nome_safe: str) -> str:
    """Instala o ícone em ~/.local/share/icons/hicolor e atualiza caches.
    Retorna o nome para o campo Icon= do .desktop."""
    icons_base = os.path.expanduser("~/.local/share/icons/hicolor")

    # Purga completa antes de instalar — garante substituição limpa
    purgar_icone_linux(nome_safe)

    for size in (32, 48, 128, 256):
        dst_dir = os.path.join(icons_base, f"{size}x{size}", "apps")
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, f"{nome_safe}.png")
        png_resize_nn(src_png, dst, size)
        ok(f"  Icone {size}x{size} -> {dst}")

    if shutil.which("gtk-update-icon-cache"):
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", icons_base], capture_output=True)
    if shutil.which("xdg-icon-resource"):
        subprocess.run(["xdg-icon-resource", "forceupdate"], capture_output=True)
    if shutil.which("update-desktop-database"):
        apps_dir = os.path.expanduser("~/.local/share/applications")
        subprocess.run(["update-desktop-database", apps_dir], capture_output=True)
    if shutil.which("busctl"):
        subprocess.run(
            ["busctl", "--user", "call",
             "org.gnome.Shell", "/org/gnome/Shell",
             "org.gnome.Shell", "Eval", "s", "Main.reloadTheme()"],
            capture_output=True)
    for kbs in ("kbuildsycoca6", "kbuildsycoca5"):
        if shutil.which(kbs):
            subprocess.run([kbs, "--noincremental"], capture_output=True)
            break

    ok(f"Icone instalado em {icons_base}/{{32,48,128,256}}x.../apps/{nome_safe}.png")
    return nome_safe

# --- Launchers C ---

_LAUNCHER_STANDALONE_C = r"""
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>

int main(int argc, char *argv[]) {
    char path[4096], dir[4096], target[4096];
#ifdef __APPLE__
    uint32_t sz = sizeof(path);
    if (_NSGetExecutablePath(path, &sz) != 0) { perror("_NSGetExecutablePath"); return 1; }
#else
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path)-1);
    if (len < 0) { perror("readlink"); return 1; }
    path[len] = 0;
#endif
    strncpy(dir, path, sizeof(dir)); dir[sizeof(dir)-1] = 0;
    char *d = dirname(dir);
    if (chdir(d) != 0) { perror("chdir"); return 1; }
    snprintf(target, sizeof(target), "%s/{GAME_BIN}", d);
    char **av = malloc((argc+1)*sizeof(char*));
    if (!av) { perror("malloc"); return 1; }
    av[0] = target;
    for (int i=1;i<argc;i++) av[i]=argv[i];
    av[argc]=NULL;
    execv(target, av); perror("execv"); free(av); return 1;
}
"""

_LAUNCHER_DEV_C = r"""
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>

int main(int argc, char *argv[]) {
    char path[4096], dir[4096], ldpath[8192];
#ifdef __APPLE__
    uint32_t sz = sizeof(path);
    if (_NSGetExecutablePath(path, &sz) != 0) { perror("_NSGetExecutablePath"); return 1; }
#else
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path)-1);
    if (len < 0) { perror("readlink"); return 1; }
    path[len] = 0;
#endif
    strncpy(dir, path, sizeof(dir)); dir[sizeof(dir)-1] = 0;
    char *d = dirname(dir);
    if (chdir(d) != 0) { perror("chdir"); return 1; }
    const char *ex = getenv("LD_LIBRARY_PATH");
    if (ex && ex[0]) snprintf(ldpath,sizeof(ldpath),"%s/lib:%s",d,ex);
    else             snprintf(ldpath,sizeof(ldpath),"%s/lib",d);
    setenv("LD_LIBRARY_PATH",ldpath,1);
    char **av = malloc((argc+2)*sizeof(char*));
    if (!av) { perror("malloc"); return 1; }
    av[0]="luajit"; av[1]="main.lua";
    for (int i=1;i<argc;i++) av[i+1]=argv[i];
    av[argc+1]=NULL;
    execvp("luajit",av); perror("execvp"); free(av); return 1;
}
"""

def compilar_launcher(src_c: str, out_path: str, extra_flags=None):
    compiler = shutil.which("gcc") or shutil.which("cc")
    if not compiler:
        raise RuntimeError("gcc/cc não encontrado no PATH.")
    cmd = [compiler, "-O2", "-x", "c", "-", "-o", out_path]
    if extra_flags:
        cmd += extra_flags
    r = subprocess.run(cmd, input=src_c.encode(), capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.decode())
    os.chmod(out_path, 0o755)

# --- Menus interativos ---

def encontrar_arquivos(extensao: str, ignorar: list[str]) -> list[str]:
    resultado = []
    for raiz, dirs, arquivos in os.walk("."):
        dirs[:] = [d for d in dirs if d not in ignorar and not d.startswith(".")]
        for arq in sorted(arquivos):
            if arq.endswith(extensao):
                caminho = os.path.relpath(os.path.join(raiz, arq), ".").replace("\\", "/")
                resultado.append(caminho)
    return sorted(resultado)

# --- Seletores GUI ---

def _gui_disponivel() -> bool:
    """Retorna True se há um display gráfico acessível."""
    if IS_WIN:
        return True
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))

def _gui_abrir_arquivo(titulo: str, filtros: list[tuple]) -> str:
    """
    Abre um seletor de arquivo gráfico.
    filtros: lista de (label, "*.ext *.ext2")  ex: [("PNG", "*.png")]
    Retorna caminho selecionado ou "" se cancelado.
    Tenta na ordem: tkinter → zenity → kdialog → yad
    """
    if not _gui_disponivel():
        return ""

    # ── tkinter (Python stdlib — sem dependência extra) ──────────────
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        caminho = filedialog.askopenfilename(
            title=titulo,
            filetypes=filtros + [("Todos os arquivos", "*.*")],
        )
        root.destroy()
        return caminho or ""
    except Exception:
        pass

    # ── zenity (GTK — comum no GNOME/XFCE) ───────────────────────────
    if shutil.which("zenity"):
        filtro_arg = []
        for label, pat in filtros:
            filtro_arg += ["--file-filter", f"{label} | {pat}"]
        try:
            r = subprocess.run(
                ["zenity", "--file-selection", f"--title={titulo}"] + filtro_arg,
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    # ── kdialog (Qt — comum no KDE) ──────────────────────────────────
    if shutil.which("kdialog"):
        ext = " ".join(pat for _, pat in filtros)
        try:
            r = subprocess.run(
                ["kdialog", "--getopenfilename", os.path.expanduser("~"), ext,
                 "--title", titulo],
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    # ── yad (GTK — alternativa leve) ─────────────────────────────────
    if shutil.which("yad"):
        filtro_arg = []
        for _, pat in filtros:
            filtro_arg += ["--file-filter", pat]
        try:
            r = subprocess.run(
                ["yad", "--file-selection", f"--title={titulo}"] + filtro_arg,
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    return ""  # nenhum backend gráfico disponível


def _gui_abrir_pasta(titulo: str) -> str:
    """
    Abre um seletor de PASTA gráfico.
    Retorna caminho selecionado ou "" se cancelado.
    Tenta na ordem: tkinter → zenity → kdialog → yad
    """
    if not _gui_disponivel():
        return ""

    # ── tkinter ──────────────────────────────────────────────────────
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        caminho = filedialog.askdirectory(title=titulo)
        root.destroy()
        return caminho or ""
    except Exception:
        pass

    # ── zenity ───────────────────────────────────────────────────────
    if shutil.which("zenity"):
        try:
            r = subprocess.run(
                ["zenity", "--file-selection", "--directory", f"--title={titulo}"],
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    # ── kdialog ──────────────────────────────────────────────────────
    if shutil.which("kdialog"):
        try:
            r = subprocess.run(
                ["kdialog", "--getexistingdirectory",
                 os.path.expanduser("~"), "--title", titulo],
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    # ── yad ──────────────────────────────────────────────────────────
    if shutil.which("yad"):
        try:
            r = subprocess.run(
                ["yad", "--file-selection", "--directory", f"--title={titulo}"],
                capture_output=True, text=True
            )
            return r.stdout.strip() if r.returncode == 0 else ""
        except Exception:
            pass

    return ""


def menu_selecionar_icone() -> str:
    print(f"\n{bold('Seletor de Icone')}")
    print(dim("  PNG quadrado, minimo 32x32, ideal 256x256.\n"))

    # Tenta abrir seletor gráfico que permite navegar em qualquer pasta
    if _gui_disponivel():
        print(dim("  Abrindo seletor grafico de arquivo...\n"))
        caminho_gui = _gui_abrir_arquivo(
            "Selecione o ícone do jogo (PNG)",
            [("Imagens PNG", "*.png")]
        )
        if caminho_gui and os.path.isfile(caminho_gui):
            ok(f"Icone: {caminho_gui}")
            sep()
            return caminho_gui
        if caminho_gui == "":
            # Usuário cancelou ou não tem GUI — cai para menu terminal
            warn("Seletor grafico nao disponivel ou cancelado — usando lista do terminal.")
        print()

    # Fallback: lista os PNGs do projeto no terminal
    pngs = encontrar_arquivos(".png", ignorar=["target", ".git", ".engine"])
    if not pngs:
        warn("Nenhum PNG encontrado no projeto — sem ícone.")
        sep()
        return ""
    print(f"  {dim('[ 0]')} Sem icone")
    for i, p in enumerate(pngs, 1):
        print(f"  {dim(f'[{i:2d}]')} {p}")
    print()
    while True:
        try:
            entrada = input(dim("  Numero (0 = sem icone): ")).strip()
            n = int(entrada)
            if n == 0:
                warn("Sem ícone selecionado.")
                sep()
                return ""
            if 1 <= n <= len(pngs):
                ok(f"Icone: {pngs[n-1]}")
                sep()
                return pngs[n-1]
        except (ValueError, EOFError):
            pass
        print(f"  {_ansi('31','Numero invalido. Tente novamente.')}")

def menu_selecionar_lua_extras() -> list[str]:
    print(f"\n{bold('Seletor de Modulos Lua')}")
    print(dim("  Todos os .lua encontrados (exceto main.lua) serao incluidos."))
    print(dim("  Desmarque os que NAO devem ir para o executavel.\n"))
    itens = [f for f in encontrar_arquivos(".lua", ignorar=["target", ".git"])
             if f != "main.lua"]
    if not itens:
        warn("Nenhum módulo .lua encontrado além do main.lua.")
        return []

    selecionado = [True] * len(itens)

    def modulo_nome(f):
        return f.removesuffix(".lua").replace("/", ".").replace("\\", ".")

    def exibir():
        print(f"  {bold('Modulos Lua encontrados:')}\n")
        for i, f in enumerate(itens):
            m = modulo_nome(f)
            marca = _ansi("32;1", "[x]") if selecionado[i] else _ansi("31", "[ ]")
            print(f"  {marca} {i+1:2d}) {m:<40s} {dim(f'<- {f}')}")
        print(f"\n  {dim('Numero para toggle, a=tudo, n=nenhum, ok=confirmar: ')}", end="", flush=True)

    exibir()
    while True:
        try:
            entrada = input().strip().lower()
        except EOFError:
            break
        if entrada in ("ok", ""):
            break
        elif entrada == "a":
            selecionado[:] = [True]  * len(itens)
        elif entrada == "n":
            selecionado[:] = [False] * len(itens)
        else:
            for tok in entrada.replace(",", " ").split():
                try:
                    idx = int(tok) - 1
                    if 0 <= idx < len(itens):
                        selecionado[idx] = not selecionado[idx]
                    else:
                        warn(f"Número {tok} fora do range.")
                except ValueError:
                    warn(f"Entrada inválida: '{tok}'")
        linhas = len(itens) + 4
        print(f"\033[{linhas}A\033[J", end="") if not IS_WIN else None
        exibir()

    resultado = [f for f, s in zip(itens, selecionado) if s]
    print()
    if not resultado:
        warn("Nenhum módulo Lua selecionado — apenas main.lua será embutido.")
    else:
        ok(f"{len(resultado)} módulo(s) selecionado(s):")
        for f in resultado:
            print(dim(f"     -> {modulo_nome(f):<40s} ({f})"))
    sep()
    return resultado

def menu_selecionar_destino(nome_safe: str) -> str:
    """Abre seletor gráfico de pasta quando disponível; fallback para menu terminal."""
    print(f"\n{bold('Destino do pacote')}")
    print(dim("  Escolha onde a pasta do jogo sera criada.\n"))

    # ── Tenta seletor gráfico ────────────────────────────────────────
    if _gui_disponivel():
        print(dim("  Abrindo seletor grafico de pasta...\n"))
        pasta_gui = _gui_abrir_pasta("Escolha a pasta onde o jogo será salvo")
        if pasta_gui and os.path.isdir(pasta_gui):
            destino = os.path.join(pasta_gui, nome_safe)
            ok(f"Destino: {destino}")
            sep()
            return destino
        if pasta_gui != "":
            warn("Pasta invalida — usando menu terminal.")
        else:
            warn("Seletor grafico cancelado ou indisponivel — usando menu terminal.")
        print()

    # ── Fallback terminal ────────────────────────────────────────────
    home = os.path.expanduser("~")
    candidatos_nomes = (
        ("Documents",        os.path.join(home, "Documents")),
        ("Documentos",       os.path.join(home, "Documentos")),
        ("Desktop",          os.path.join(home, "Desktop")),
        ("Área de Trabalho", os.path.join(home, "Área de Trabalho")),
        ("Área_de_Trabalho", os.path.join(home, "Área_de_Trabalho")),
        ("Downloads",        os.path.join(home, "Downloads")),
        ("Jogos",            os.path.join(home, "Jogos")),
        ("Games",            os.path.join(home, "Games")),
    )
    vistos = set()
    opcoes = []
    for label, caminho in candidatos_nomes:
        real = os.path.realpath(caminho)
        if os.path.isdir(caminho) and real not in vistos:
            vistos.add(real)
            opcoes.append((label, caminho))

    projeto_dir = os.path.join(os.getcwd(), "dist")
    opcoes.append(("dist/  (subpasta do projeto)", projeto_dir))
    OPCAO_CUSTOM = len(opcoes) + 1

    print(dim("  Pastas disponiveis:\n"))
    for i, (label, caminho) in enumerate(opcoes, 1):
        print(f"  {dim(f'[{i:2d}]')} {label:<28s} {dim(os.path.join(caminho, nome_safe))}")
    print(f"  {dim(f'[{OPCAO_CUSTOM:2d}]')} Caminho personalizado (digitar manualmente)")
    print()

    while True:
        try:
            entrada = input(dim(f"  Numero [1-{OPCAO_CUSTOM}]: ")).strip()
            n = int(entrada)
        except (ValueError, EOFError):
            print(f"  {_ansi('31', 'Numero invalido. Tente novamente.')}"); continue

        if 1 <= n <= len(opcoes):
            destino = os.path.join(opcoes[n - 1][1], nome_safe)
            ok(f"Destino: {destino}"); sep(); return destino

        if n == OPCAO_CUSTOM:
            print(dim("  Ex: /home/usuario/meus-jogos  ou  ~/projetos"))
            try:
                raw = input(dim("  Caminho: ")).strip()
            except EOFError:
                raw = ""
            if not raw:
                warn("Caminho vazio — tente novamente."); continue
            destino = os.path.join(os.path.abspath(os.path.expanduser(raw)), nome_safe)
            ok(f"Destino: {destino}"); sep(); return destino

        print(f"  {_ansi('31', 'Numero invalido. Tente novamente.')}")


def menu_selecionar_assets() -> list[str]:
    print(f"\n{bold('Seletor de Assets')}")
    print(dim("  Escolha o que sera incluido na pasta raiz do pacote.\n"))

    IGNORAR_NOMES = {
        "Makefile", "Cargo.toml", "Cargo.lock", "empacotar.py", "empacotar.sh",
        "main.lua", "main_bytecode.h", "all_bytecodes.h", "main_bytecode_loader.c",
        "libtupi.so", "tupi_engine", ".git", ".gitignore", "target", "src",
        "Engine", "include", "__pycache__",
    }
    IGNORAR_EXT = {".rs", ".toml", ".lock", ".py", ".sh", ".c", ".h",
                   ".o", ".a", ".lua", ".bc"}

    itens = []
    tipos = []
    raiz  = "."
    for nome in sorted(os.listdir(raiz)):
        if nome in IGNORAR_NOMES or nome.startswith("."):
            continue
        caminho = os.path.join(raiz, nome)
        if os.path.isdir(caminho):
            itens.append(nome); tipos.append("d")
        elif os.path.isfile(caminho):
            if os.path.splitext(nome)[1] not in IGNORAR_EXT:
                itens.append(nome); tipos.append("f")

    if not itens:
        warn("Nenhum asset encontrado na raiz do projeto.")
        return []

    selecionado = [False] * len(itens)

    def exibir():
        print(f"  {bold('Itens disponíveis:')}\n")
        for i, (nome, tipo) in enumerate(zip(itens, tipos)):
            marca    = _ansi("32;1", "[x]") if selecionado[i] else dim("[ ]")
            tipo_str = dim("[pasta]") if tipo == "d" else dim("[arq] ")
            print(f"  {marca} {i+1:2d}) {nome} {tipo_str}")
        print(f"\n  {dim('Numero para toggle, a=tudo, n=nenhum, ok=confirmar: ')}", end="", flush=True)

    exibir()
    while True:
        try:
            entrada = input().strip().lower()
        except EOFError:
            break
        if entrada in ("ok", ""):
            break
        elif entrada == "a":
            selecionado[:] = [True]  * len(itens)
        elif entrada == "n":
            selecionado[:] = [False] * len(itens)
        else:
            for tok in entrada.replace(",", " ").split():
                try:
                    idx = int(tok) - 1
                    if 0 <= idx < len(itens):
                        selecionado[idx] = not selecionado[idx]
                    else:
                        warn(f"Número {tok} fora do range.")
                except ValueError:
                    warn(f"Entrada inválida: '{tok}'")
        linhas = len(itens) + 4
        print(f"\033[{linhas}A\033[J", end="") if not IS_WIN else None
        exibir()

    resultado = [n for n, s in zip(itens, selecionado) if s]
    print()
    if not resultado:
        warn("Nenhum asset selecionado.")
    else:
        ok(f"{len(resultado)} item(ns) selecionado(s):")
        for a in resultado:
            print(dim(f"     -> {a}"))
    sep()
    return resultado

# --- Cópia de assets ---

def copiar_assets(assets: list[str], destino_raiz: str):
    if not assets:
        warn("Sem assets para copiar.")
        return
    print(f"\n{info('Copiando assets...')}\n")
    for item in assets:
        if os.path.isdir(item):
            shutil.copytree(item, os.path.join(destino_raiz, os.path.basename(item)), dirs_exist_ok=True)
            ok(f"{item}/ -> /")
        elif os.path.isfile(item):
            shutil.copy2(item, os.path.join(destino_raiz, os.path.basename(item)))
            ok(f"{item} -> /")
        else:
            warn(f"{item} não encontrado — pulando")

# --- Modo STANDALONE ---

def modo_standalone(nome_jogo: str, nome_safe: str, destino: str,
                    icone: str, lua_extras: list[str], assets: list[str]):
    print(f"\n{bold('Compilando standalone...')}\n")

    if not gerar_all_bytecodes(lua_extras):
        sys.exit(1)

    info("Compilando Rust ...")
    r = subprocess.run(["cargo", "build", "--release"])
    if r.returncode != 0:
        err("Falha no Rust."); sys.exit(1)
    ok("Rust OK")

    info("Compilando executável (make dist-linux) ...")
    r = subprocess.run(["make", "dist-linux"])
    if r.returncode != 0:
        err("Falha no make dist-linux."); sys.exit(1)
    if not os.path.isfile("tupi_engine"):
        err("tupi_engine não encontrado."); sys.exit(1)
    ok("tupi_engine gerado")

    print(f"\n{_ansi('36', f'Montando pacote em {destino} ...')}\n")
    if platform.system() == "Linux":
        purgar_icone_linux(nome_safe)
    if os.path.exists(destino):
        shutil.rmtree(destino)
    engine_dir = os.path.join(destino, ".engine")
    os.makedirs(engine_dir)

    shutil.copy2("tupi_engine", os.path.join(engine_dir, "tupi_engine"))
    os.chmod(os.path.join(engine_dir, "tupi_engine"), 0o755)
    ok("tupi_engine -> .engine/")

    if os.path.isfile("main_bytecode_loader.c"):
        shutil.copy2("main_bytecode_loader.c", engine_dir)
        ok("main_bytecode_loader.c -> .engine/")

    icon_dst = os.path.join(engine_dir, "icon.png")
    if icone and os.path.isfile(icone):
        shutil.copy2(icone, icon_dst)
        ok(f"Icone -> .engine/icon.png  (origem: {icone})")

    copiar_assets(assets, destino)

    launcher_out = os.path.join(destino, nome_safe)
    info(f"Compilando launcher: {nome_safe} ...")
    src_c = _LAUNCHER_STANDALONE_C.replace("{GAME_BIN}", ".engine/tupi_engine")
    try:
        compilar_launcher(src_c, launcher_out)
        ok(f"Launcher: {nome_safe}")
    except Exception as e:
        err(f"Falha ao compilar launcher: {e}"); sys.exit(1)

    if not IS_WIN:
        rodar = os.path.join(destino, "rodar.sh")
        with open(rodar, "w") as f:
            f.write('#!/usr/bin/env bash\n'
                    'SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"\n'
                    'cd "$SCRIPT_DIR"\n'
                    'exec "$SCRIPT_DIR/.engine/tupi_engine" "$@"\n')
        os.chmod(rodar, 0o755)

    desktop_icon_field = ""
    system = platform.system()
    if system == "Linux" and os.path.isfile(icon_dst):
        desktop_icon_field = instalar_icone_linux(icon_dst, nome_safe)

    if system == "Linux":
        desktop_path = os.path.join(destino, f"{nome_safe}.desktop")
        exec_line    = f"env WAYLAND_APP_ID={nome_safe} {os.path.abspath(launcher_out)}"
        icon_line    = f"Icon={desktop_icon_field}" if desktop_icon_field else ""
        desktop_txt  = (
            "[Desktop Entry]\n"
            "Type=Application\n"
            f"Name={nome_jogo}\n"
            "Comment=Jogo feito com TupiEngine\n"
            f"Exec={exec_line}\n"
            f"Path={destino}\n"
            "Terminal=false\n"
            "Categories=Game;\n"
            f"StartupWMClass={nome_safe}\n"
            f"{icon_line}\n"
        )
        with open(desktop_path, "w") as f:
            f.write(desktop_txt)
        os.chmod(desktop_path, 0o755)
        ok(f".desktop criado: {nome_safe}.desktop")

        apps_dir = os.path.expanduser("~/.local/share/applications")
        os.makedirs(apps_dir, exist_ok=True)
        shutil.copy2(desktop_path, os.path.join(apps_dir, f"{nome_safe}.desktop"))
        if shutil.which("update-desktop-database"):
            subprocess.run(["update-desktop-database", apps_dir], capture_output=True)
        ok(f".desktop instalado em: {apps_dir}/")

    data_hora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    assets_md = "".join(f"    ├── {a}/\n" for a in assets)
    icone_md  = "\n    ├── icon.png" if icone else ""
    readme = (
        f"# {nome_jogo}\n\n"
        f"## Como rodar\n"
        f"- Clique duas vezes em **{nome_safe}** (launcher)\n"
        f"- Ou clique duas vezes em **{nome_safe}.desktop**\n"
        f"- Ou pelo terminal: `cd \"{destino}\" && ./{nome_safe}`\n\n"
        f"## Estrutura\n"
        f"    ├── {nome_safe}\n"
        f"    ├── {nome_safe}.desktop\n"
        f"    ├── rodar.sh\n"
        f"    ├── .engine/{icone_md}\n"
        f"{assets_md}"
        f"Módulos Lua estão embutidos no executável.\n\n"
        f"Empacotado em: {data_hora}\n"
    )
    with open(os.path.join(destino, "README.md"), "w") as f:
        f.write(readme)

# --- Modo DEV ---

def modo_dev(nome_jogo: str, nome_safe: str, destino: str, assets: list[str]):
    print(f"\n{bold('Compilando libtupi.so ...')}\n")
    r = subprocess.run(["make", "gl"])
    if r.returncode != 0:
        err("Falha no make gl."); sys.exit(1)
    if not os.path.isfile("libtupi.so"):
        err("libtupi.so não encontrada."); sys.exit(1)
    ok("libtupi.so compilada")

    print(f"\n{_ansi('36', f'Montando pacote em {destino} ...')}\n")
    if os.path.exists(destino):
        shutil.rmtree(destino)
    lib_dir = os.path.join(destino, "lib")
    os.makedirs(lib_dir)

    shutil.copy2("libtupi.so", os.path.join(lib_dir, "libtupi.so"))
    ok("libtupi.so -> lib/")

    for arq in ("main.lua", "Makefile", "Cargo.toml"):
        if os.path.isfile(arq):
            shutil.copy2(arq, destino); ok(f"{arq} copiado")

    for pasta in ("src", "Engine"):
        if os.path.isdir(pasta):
            shutil.copytree(pasta, os.path.join(destino, pasta)); ok(f"{pasta}/ copiado")

    for arq in os.listdir("."):
        if arq.endswith(".lua") and arq != "main.lua" and os.path.isfile(arq):
            shutil.copy2(arq, destino); ok(f"{arq} copiado")

    copiar_assets(assets, destino)

    launcher_out = os.path.join(destino, nome_safe)
    info(f"Compilando launcher dev: {nome_safe} ...")
    try:
        compilar_launcher(_LAUNCHER_DEV_C, launcher_out)
        ok(f"Launcher dev: {nome_safe}")
    except Exception as e:
        err(f"Falha ao compilar launcher: {e}"); sys.exit(1)

    if not IS_WIN:
        rodar = os.path.join(destino, "rodar.sh")
        with open(rodar, "w") as f:
            f.write('#!/usr/bin/env bash\n'
                    'SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"\n'
                    'cd "$SCRIPT_DIR"\n'
                    'export LD_LIBRARY_PATH="$SCRIPT_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
                    'exec luajit main.lua "$@"\n')
        os.chmod(rodar, 0o755)

    data_hora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    assets_md = "".join(f"        └── {a}\n" for a in assets)
    readme = (
        f"# {nome_jogo} — Dev\n\n"
        f"## Como rodar\n"
        f"    cd \"{destino}\" && ./{nome_safe}\n"
        f"Requer: LuaJIT 2.1+, libGL, libglfw3\n\n"
        f"{assets_md}"
        f"Empacotado em: {data_hora}\n"
    )
    with open(os.path.join(destino, "README.md"), "w") as f:
        f.write(readme)

# --- Ponto de entrada ---

def main():
    header()

    if not os.path.isfile("Makefile") or not os.path.isfile("main.lua"):
        err("Execute na raiz do projeto (onde estão Makefile e main.lua).")
        sys.exit(1)

    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("nome",  nargs="?", default="")
    parser.add_argument("--standalone", action="store_true")
    parser.add_argument("--dev",        action="store_true")
    args, _ = parser.parse_known_args()

    nome_jogo = args.nome
    if not nome_jogo:
        nome_jogo = input(bold("  Nome do jogo (ex: MeuJogo): ")).strip()
    if not nome_jogo:
        err("Nome não pode ser vazio."); sys.exit(1)

    nome_safe = nome_jogo.replace(" ", "_")
    destino   = menu_selecionar_destino(nome_safe)

    sep()
    info(f"Projeto : {os.getcwd()}")
    info(f"Destino : {destino}")
    sep()

    if args.standalone:
        modo = "standalone"
    elif args.dev:
        modo = "dev"
    else:
        print(f"\n{bold('  Como deseja empacotar?')}\n")
        print(f"  {_ansi('32;1','[1]')} Standalone  (executavel unico, sem LuaJIT externo)")
        print(f"  {_ansi('36;1','[2]')} Dev/Lib     (libtupi.so + main.lua, requer LuaJIT)\n")
        escolha = input("  Escolha [1/2]: ").strip()
        modo = "dev" if escolha == "2" else "standalone"

    info(f"Modo    : {modo}")
    sep()

    icone      = menu_selecionar_icone()
    lua_extras = menu_selecionar_lua_extras() if modo == "standalone" else []
    assets     = menu_selecionar_assets()

    if modo == "standalone":
        modo_standalone(nome_jogo, nome_safe, destino, icone, lua_extras, assets)
    else:
        modo_dev(nome_jogo, nome_safe, destino, assets)

    sep()
    print(f"\n{_ansi('32;1', 'Empacotado com sucesso!')}\n")
    print(f"  {bold(destino)}\n")
    if shutil.which("tree"):
        subprocess.run(["tree", "-L", "3", "-a", destino])
    else:
        for entry in sorted(os.listdir(destino)):
            print(f"  {entry}")
    print(f"\n{_ansi('32', '  Para rodar:')}")
    print(f"    Clique duplo em {bold(nome_safe)} ou em {bold(nome_safe + '.desktop')}")
    print(f"    ou: cd \"{destino}\" && ./{nome_safe}\n")

if __name__ == "__main__":
    main()