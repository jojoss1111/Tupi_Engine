/* main_bytecode_loader.c — TupiEngine standalone
 * Carrega bytecodes embutidos (all_bytecodes.h) e executa main.lua.
 * Compile via: make dist-linux
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <GLFW/glfw3.h>

#if defined(__linux__) && !defined(TUPI_SEM_X11)
#  define GLFW_EXPOSE_NATIVE_X11
#  include <X11/Xlib.h>
#  include <X11/Xatom.h>
#  include <GLFW/glfw3native.h>
#endif

#include "all_bytecodes.h"

/* ── Imagem Rust ────────────────────────────────────────────── */

typedef struct {
    unsigned char *pixels;
    int            largura;
    int            altura;
    int            tamanho;
} TupiImagemRust;

extern TupiImagemRust *tupi_imagem_carregar_seguro(const char *caminho);
extern void            tupi_imagem_destruir(TupiImagemRust *img);

/* ── Log ────────────────────────────────────────────────────── */

static FILE *g_log = NULL;

static void log_abrir(void) {
    g_log = fopen("tupi_engine.log", "a");
    if (!g_log) return;
    time_t t = time(NULL);
    struct tm *tm = localtime(&t);
    char buf[32];
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", tm);
    fprintf(g_log, "\n=== TupiEngine %s ===\n", buf);
    fflush(g_log);
}

static void tupi_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt); vfprintf(stderr, fmt, ap); va_end(ap);
    if (!g_log) return;
    va_start(ap, fmt); vfprintf(g_log, fmt, ap);  va_end(ap);
    fflush(g_log);
}

static void log_fechar(void) {
    if (g_log) { fclose(g_log); g_log = NULL; }
}

/* ── Lua ────────────────────────────────────────────────────── */

static void lua_fatal(lua_State *L, const char *ctx) {
    const char *msg = lua_tostring(L, -1);
    tupi_log("[TupiEngine] ERRO em '%s': %s\n", ctx, msg ? msg : "?");
    log_fechar();
    lua_close(L);
    exit(EXIT_FAILURE);
}

static int modulo_loader(lua_State *L) {
    const TupiModule *m = (const TupiModule *)lua_touserdata(L, lua_upvalueindex(1));
    char chunk[256];
    snprintf(chunk, sizeof(chunk), "@%s", m->nome);
    int base = lua_gettop(L);
    if (luaL_loadbuffer(L, (const char *)m->bc, m->sz, chunk) != 0)
        return lua_error(L);
    lua_pushstring(L, m->nome);
    if (lua_pcall(L, 1, LUA_MULTRET, 0) != 0)
        return lua_error(L);
    return lua_gettop(L) - base;
}

static void registrar_modulos(lua_State *L) {
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    int n = 0;
    for (const TupiModule *m = TUPI_MODULES; m->nome; m++, n++) {
        lua_pushlightuserdata(L, (void *)m);
        lua_pushcclosure(L, modulo_loader, 1);
        lua_setfield(L, -2, m->nome);
    }
    lua_pop(L, 2);
    tupi_log("[TupiEngine] %d modulo(s) embutido(s)\n", n);
}

/* ── Ícone ──────────────────────────────────────────────────── */

#if defined(__linux__) && !defined(TUPI_SEM_X11)

/* Escala nearest-neighbor — gera tamanhos extras para _NET_WM_ICON */
static unsigned char *nn_scale(
    const unsigned char *src, int w, int h, int f, int *ow, int *oh)
{
    *ow = w * f; *oh = h * f;
    unsigned char *dst = malloc((size_t)(*ow * *oh * 4));
    if (!dst) return NULL;
    for (int y = 0; y < *oh; y++)
        for (int x = 0; x < *ow; x++) {
            const unsigned char *s = src + ((y / f) * w + (x / f)) * 4;
            unsigned char       *d = dst + (y * *ow + x) * 4;
            d[0]=s[0]; d[1]=s[1]; d[2]=s[2]; d[3]=s[3];
        }
    return dst;
}

/* Preenche um bloco EWMH (2 + w*h longs) e retorna quantos longs escreveu */
static int ewmh_bloco(long *d, const unsigned char *rgba, int w, int h) {
    d[0] = (long)w; d[1] = (long)h;
    for (int i = 0; i < w * h; i++) {
        unsigned long r=rgba[i*4], g=rgba[i*4+1], b=rgba[i*4+2], a=rgba[i*4+3];
        d[2 + i] = (long)((a << 24) | (r << 16) | (g << 8) | b);
    }
    return 2 + w * h;
}

#endif /* __linux__ */

static void aplicar_icone_na_janela(GLFWwindow *win, TupiImagemRust *img) {
    int aplicado = 0;

#if defined(__linux__) && !defined(TUPI_SEM_X11)
    Display *dpy = glfwGetX11Display();
    Window   xw  = glfwGetX11Window(win);
    if (dpy && xw) {
        int w2, h2, w3, h3;
        unsigned char *px2 = nn_scale(img->pixels, img->largura, img->altura, 2, &w2, &h2);
        unsigned char *px3 = nn_scale(img->pixels, img->largura, img->altura, 3, &w3, &h3);

        int ntot = (2 + img->largura * img->altura)
                 + (px2 ? 2 + w2 * h2 : 0)
                 + (px3 ? 2 + w3 * h3 : 0);
        long *data = malloc(sizeof(long) * (size_t)ntot);
        if (data) {
            int off = 0;
            off += ewmh_bloco(data + off, img->pixels, img->largura, img->altura);
            if (px2) off += ewmh_bloco(data + off, px2, w2, h2);
            if (px3) off += ewmh_bloco(data + off, px3, w3, h3);
            Atom prop = XInternAtom(dpy, "_NET_WM_ICON", False);
            XChangeProperty(dpy, xw, prop, XA_CARDINAL, 32,
                            PropModeReplace, (unsigned char *)data, ntot);
            XFlush(dpy);   /* XFlush é suficiente aqui — XSync bloqueia desnecessariamente */
            free(data);
            aplicado = 1;
        }
        free(px2);
        free(px3);
    }
#endif

    if (!aplicado) {
        GLFWimage gi = { img->largura, img->altura, img->pixels };
        glfwSetWindowIcon(win, 1, &gi);
    }

    /* Força o WM a reler _NET_WM_ICON */
    glfwHideWindow(win);
    glfwShowWindow(win);
}

/* Chamada pelo engineffi.lua via global Lua "tupi_c_aplicar_icone" */
static int l_aplicar_icone(lua_State *L) {
    const char *caminho = luaL_optstring(L, 1, ".engine/icon.png");
    TupiImagemRust *img = tupi_imagem_carregar_seguro(caminho);
    if (!img) { lua_pushboolean(L, 0); return 1; }
    GLFWwindow *win = glfwGetCurrentContext();
    if (win) aplicar_icone_na_janela(win, img);
    tupi_imagem_destruir(img);
    lua_pushboolean(L, win != NULL);
    return 1;
}

/* Fallback pós-pcall: aplica o ícone se a janela ainda existir */
static void icone_fallback(void) {
    GLFWwindow *win = glfwGetCurrentContext();
    if (!win) return;
    TupiImagemRust *img = tupi_imagem_carregar_seguro(".engine/icon.png");
    if (!img) return;
    aplicar_icone_na_janela(win, img);
    tupi_imagem_destruir(img);
}

/* ── Main ───────────────────────────────────────────────────── */

int main(void) {
    log_abrir();

    lua_State *L = luaL_newstate();
    if (!L) {
        tupi_log("[TupiEngine] Falha ao criar estado Lua\n");
        log_fechar();
        return EXIT_FAILURE;
    }

    luaL_openlibs(L);

    /* Sinaliza ao engineffi.lua para usar ffi.load(nil) */
    lua_pushboolean(L, 1);
    lua_setglobal(L, "TUPI_STANDALONE");

    /* Expõe o caminho do ícone se o arquivo existir */
    {
        FILE *f = fopen(".engine/icon.png", "rb");
        if (f) {
            fclose(f);
            lua_pushstring(L, ".engine/icon.png");
            lua_setglobal(L, "TUPI_ICON_PATH");
        }
    }

    registrar_modulos(L);

    lua_pushcfunction(L, l_aplicar_icone);
    lua_setglobal(L, "tupi_c_aplicar_icone");

    if (luaL_loadbuffer(L, (const char *)tupi_bc_main, tupi_bc_main_SIZE, "@main") != 0)
        lua_fatal(L, "loadbuffer main");

    if (lua_pcall(L, 0, LUA_MULTRET, 0) != 0)
        lua_fatal(L, "pcall main");

    icone_fallback();

    lua_close(L);
    log_fechar();
    return EXIT_SUCCESS;
}