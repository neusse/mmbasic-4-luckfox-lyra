#define _XOPEN_SOURCE 700

#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define PICOCALC_W 320
#define PICOCALC_H 320
#define SURFACE_N 1
#define SURFACE_F 2
#define SURFACE_L 3

#define RGB_BLACK 0x00000000u
#define RGB_RED   0x00ff0000u
#define RGB_GREEN 0x0000ff00u
#define RGB_BLUE  0x000000ffu
#define RGB_WHITE 0x00ffffffu

typedef enum {
    BACKEND_NONE = 0,
    BACKEND_SDL = 1,
    BACKEND_FBDEV = 2,
} Backend;

typedef enum {
    PRESENT_MMAP_NOSYNC,
    PRESENT_MMAP_MSYNC,
    PRESENT_PWRITE,
} PresentMode;

typedef enum {
    PRESENT_FLUSHED,
    PRESENT_SKIPPED_BACKEND,
    PRESENT_SKIPPED_CLEAN,
    PRESENT_FAILED,
} PresentResult;

typedef struct {
    int fd;
    uint8_t *mem;
    size_t mem_len;
    int width;
    int height;
    int stride;
    int bpp;
    char path[128];
} Fbdev;

typedef struct {
    bool exists;
    bool dirty;
    int id;
    int width;
    int height;
    uint32_t *pixels;
} Surface;

static Backend graphics_backend = BACKEND_SDL;
static bool graphics_initialised = false;
static uint32_t visible_generation = 0;
static uint32_t presented_generation = 0;
static Surface surface_n = {0};
static Surface surface_f = {0};
static Surface surface_l = {0};
static Fbdev fbdev = {
    .fd = -1,
    .mem = NULL,
    .mem_len = 0,
    .width = 0,
    .height = 0,
    .stride = 0,
    .bpp = 0,
    .path = "",
};
static int failures = 0;
static int passes = 0;
static int observations = 0;

static const char *backend_name(Backend backend) {
    switch (backend) {
        case BACKEND_NONE: return "NONE";
        case BACKEND_SDL: return "SDL";
        case BACKEND_FBDEV: return "FBDEV";
        default: return "UNKNOWN";
    }
}

static const char *present_mode_name(PresentMode mode) {
    switch (mode) {
        case PRESENT_MMAP_NOSYNC: return "mmap-nosync";
        case PRESENT_MMAP_MSYNC: return "mmap-msync";
        case PRESENT_PWRITE: return "pwrite";
        default: return "unknown";
    }
}

static void sleep_ms(int ms) {
    if (ms <= 0) return;
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (long)(ms % 1000) * 1000000L;
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR) {
    }
}

static uint16_t rgb888_to_rgb565(uint32_t pixel) {
    uint8_t r = (uint8_t)((pixel >> 16) & 0xffu);
    uint8_t g = (uint8_t)((pixel >> 8) & 0xffu);
    uint8_t b = (uint8_t)(pixel & 0xffu);
    return (uint16_t)(((uint16_t)(r & 0xf8u) << 8) |
                      ((uint16_t)(g & 0xfcu) << 3) |
                      ((uint16_t)b >> 3));
}

static void record_pass(const char *name) {
    ++passes;
    printf("PASS %s\n", name);
}

static void record_fail(const char *name, const char *detail) {
    ++failures;
    printf("FAIL %s: %s\n", name, detail);
}

static void record_observation(const char *name, const char *detail) {
    ++observations;
    printf("OBSERVE %s: %s\n", name, detail);
}

static int open_fb_info(const char *path, struct fb_fix_screeninfo *fix,
                        struct fb_var_screeninfo *var) {
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s failed: %s\n", path, strerror(errno));
        return -1;
    }
    if (ioctl(fd, FBIOGET_FSCREENINFO, fix) != 0) {
        fprintf(stderr, "FBIOGET_FSCREENINFO failed: %s\n", strerror(errno));
        close(fd);
        return -1;
    }
    if (ioctl(fd, FBIOGET_VSCREENINFO, var) != 0) {
        fprintf(stderr, "FBIOGET_VSCREENINFO failed: %s\n", strerror(errno));
        close(fd);
        return -1;
    }
    return fd;
}

static bool clear_fbdev_file(const char *path, uint16_t colour) {
    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    int fd = open_fb_info(path, &fix, &var);
    if (fd < 0) return false;

    if (var.xres != PICOCALC_W || var.yres != PICOCALC_H || var.bits_per_pixel != 16) {
        fprintf(stderr, "unexpected fbdev geometry %ux%u %u-bpp\n",
                var.xres, var.yres, var.bits_per_pixel);
        close(fd);
        return false;
    }

    uint8_t *row = calloc(1u, fix.line_length);
    if (!row) {
        fprintf(stderr, "calloc row failed\n");
        close(fd);
        return false;
    }
    for (int x = 0; x < PICOCALC_W; ++x) {
        row[x * 2] = (uint8_t)(colour & 0xffu);
        row[x * 2 + 1] = (uint8_t)(colour >> 8);
    }
    bool ok = true;
    for (int y = 0; y < PICOCALC_H; ++y) {
        off_t offset = (off_t)y * (off_t)fix.line_length;
        ssize_t written = pwrite(fd, row, fix.line_length, offset);
        if (written != (ssize_t)fix.line_length) {
            fprintf(stderr, "clear pwrite failed at row %d: %s\n", y, strerror(errno));
            ok = false;
            break;
        }
    }
    free(row);
    close(fd);
    return ok;
}

static void blank_cycle_fbdev(const char *path) {
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;
    if (!name || !*name) name = "fb0";

    char blank_path[160];
    snprintf(blank_path, sizeof(blank_path), "/sys/class/graphics/%s/blank", name);

    int fd = open(blank_path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;

    (void)write(fd, "1\n", 2);
    close(fd);
    sleep_ms(200);

    fd = open(blank_path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    (void)write(fd, "0\n", 2);
    close(fd);
}

static void fbdev_close(void) {
    if (fbdev.mem && fbdev.mem != MAP_FAILED) {
        munmap(fbdev.mem, fbdev.mem_len);
    }
    fbdev.mem = NULL;
    fbdev.mem_len = 0;
    if (fbdev.fd >= 0) close(fbdev.fd);
    fbdev.fd = -1;
}

static bool fbdev_open(const char *path) {
    if (fbdev.fd >= 0) return true;

    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    int fd = open_fb_info(path, &fix, &var);
    if (fd < 0) return false;

    if (var.xres != PICOCALC_W || var.yres != PICOCALC_H || var.bits_per_pixel != 16) {
        fprintf(stderr, "unexpected fbdev geometry %ux%u %u-bpp\n",
                var.xres, var.yres, var.bits_per_pixel);
        close(fd);
        return false;
    }
    if (fix.line_length < PICOCALC_W * 2) {
        fprintf(stderr, "fbdev stride too small: %u\n", fix.line_length);
        close(fd);
        return false;
    }

    size_t mem_len = (size_t)fix.smem_len;
    uint8_t *mem = mmap(NULL, mem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mem == MAP_FAILED) {
        fprintf(stderr, "mmap fbdev failed: %s\n", strerror(errno));
        close(fd);
        return false;
    }

    fbdev.fd = fd;
    fbdev.mem = mem;
    fbdev.mem_len = mem_len;
    fbdev.width = (int)var.xres;
    fbdev.height = (int)var.yres;
    fbdev.stride = (int)fix.line_length;
    fbdev.bpp = (int)var.bits_per_pixel;
    snprintf(fbdev.path, sizeof(fbdev.path), "%s", path);
    return true;
}

static bool surface_create(int id, int width, int height) {
    if (!graphics_initialised) {
        graphics_backend = BACKEND_SDL;
        graphics_initialised = true;
        printf("  graphics_init: backend reset to %s\n", backend_name(graphics_backend));
    }
    Surface *surface = NULL;
    if (id == SURFACE_N) surface = &surface_n;
    else if (id == SURFACE_F) surface = &surface_f;
    else if (id == SURFACE_L) surface = &surface_l;
    else return false;

    if (width != PICOCALC_W || height != PICOCALC_H) return false;
    if (!surface->pixels) {
        surface->pixels = calloc((size_t)width * (size_t)height, sizeof(uint32_t));
        if (!surface->pixels) return false;
    }
    surface->exists = true;
    surface->dirty = false;
    surface->id = id;
    surface->width = width;
    surface->height = height;
    return true;
}

static void reset_graphics_state(void) {
    fbdev_close();
    free(surface_n.pixels);
    free(surface_f.pixels);
    free(surface_l.pixels);
    memset(&surface_n, 0, sizeof(surface_n));
    memset(&surface_f, 0, sizeof(surface_f));
    memset(&surface_l, 0, sizeof(surface_l));
    graphics_backend = BACKEND_SDL;
    graphics_initialised = false;
    visible_generation = 0;
    presented_generation = 0;
}

static bool ensure_display_buggy_order(const char *path) {
    if (!fbdev_open(path)) return false;
    graphics_backend = BACKEND_FBDEV;
    printf("  ensure_buggy: backend set to %s before surface_create\n",
           backend_name(graphics_backend));
    if (!surface_create(SURFACE_N, PICOCALC_W, PICOCALC_H)) return false;
    return true;
}

static bool ensure_display_fixed_order(const char *path) {
    if (!graphics_initialised) {
        graphics_backend = BACKEND_SDL;
        graphics_initialised = true;
        printf("  ensure_fixed: graphics_init completed before fbdev selection\n");
    }
    if (!surface_create(SURFACE_N, PICOCALC_W, PICOCALC_H)) return false;
    if (!fbdev_open(path)) return false;
    graphics_backend = BACKEND_FBDEV;
    printf("  ensure_fixed: backend set to %s after surface_create\n",
           backend_name(graphics_backend));
    return true;
}

static void draw_quadrants(void) {
    for (int y = 0; y < surface_n.height; ++y) {
        for (int x = 0; x < surface_n.width; ++x) {
            uint32_t colour;
            if (x < 160 && y < 160) colour = RGB_RED;
            else if (x >= 160 && y < 160) colour = RGB_GREEN;
            else if (x < 160) colour = RGB_BLUE;
            else colour = RGB_WHITE;
            surface_n.pixels[(size_t)y * (size_t)surface_n.width + (size_t)x] = colour;
        }
    }
    surface_n.dirty = true;
    ++visible_generation;
}

static void surface_fill(Surface *surface, uint32_t colour) {
    for (int y = 0; y < surface->height; ++y) {
        for (int x = 0; x < surface->width; ++x) {
            surface->pixels[(size_t)y * (size_t)surface->width + (size_t)x] = colour;
        }
    }
    surface->dirty = true;
    if (surface->id == SURFACE_N) ++visible_generation;
}

static void surface_box(Surface *surface, int x1, int y1, int w, int h, uint32_t colour) {
    for (int y = y1; y < y1 + h; ++y) {
        for (int x = x1; x < x1 + w; ++x) {
            if (x >= 0 && y >= 0 && x < surface->width && y < surface->height) {
                surface->pixels[(size_t)y * (size_t)surface->width + (size_t)x] = colour;
            }
        }
    }
    surface->dirty = true;
    if (surface->id == SURFACE_N) ++visible_generation;
}

static void draw_text_marker(Surface *surface, int x, int y, int glyphs, uint32_t colour) {
    for (int g = 0; g < glyphs; ++g) {
        int gx = x + g * 8;
        surface_box(surface, gx + 1, y, 1, 7, colour);
        surface_box(surface, gx + 2, y, 4, 1, colour);
        surface_box(surface, gx + 2, y + 3, 4, 1, colour);
        surface_box(surface, gx + 2, y + 6, 4, 1, colour);
        surface_box(surface, gx + 6, y, 1, 7, colour);
    }
}

static void surface_copy(Surface *src, Surface *dst) {
    memcpy(dst->pixels, src->pixels, (size_t)src->width * (size_t)src->height * sizeof(uint32_t));
    dst->dirty = true;
    if (dst->id == SURFACE_N) ++visible_generation;
}

static void surface_merge_transparent(Surface *base, Surface *layer, Surface *dst,
                                      uint32_t transparent) {
    surface_copy(base, dst);
    for (int y = 0; y < dst->height; ++y) {
        for (int x = 0; x < dst->width; ++x) {
            uint32_t pixel = layer->pixels[(size_t)y * (size_t)layer->width + (size_t)x];
            if (pixel != transparent) {
                dst->pixels[(size_t)y * (size_t)dst->width + (size_t)x] = pixel;
            }
        }
    }
    dst->dirty = true;
    if (dst->id == SURFACE_N) ++visible_generation;
}

static int count_colour(Surface *surface, int x1, int y1, int x2, int y2, uint32_t colour) {
    int count = 0;
    for (int y = y1; y <= y2; ++y) {
        for (int x = x1; x <= x2; ++x) {
            if (x >= 0 && y >= 0 && x < surface->width && y < surface->height &&
                    surface->pixels[(size_t)y * (size_t)surface->width + (size_t)x] == colour) {
                ++count;
            }
        }
    }
    return count;
}

static bool surface_pixel_equals(Surface *surface, const char *label, int x, int y,
                                 uint32_t expected) {
    if (!surface || !surface->pixels || x < 0 || y < 0 ||
            x >= surface->width || y >= surface->height) {
        printf("  surface %-14s (%3d,%3d) invalid\n", label, x, y);
        return false;
    }
    uint32_t actual = surface->pixels[(size_t)y * (size_t)surface->width + (size_t)x];
    printf("  surface %-14s (%3d,%3d) actual=%06x expected=%06x\n",
           label, x, y, (unsigned)(actual & 0xffffffu), (unsigned)(expected & 0xffffffu));
    return actual == expected;
}

static bool present_pwrite(void) {
    uint8_t *row = calloc(1u, (size_t)fbdev.stride);
    if (!row) return false;
    bool ok = true;
    for (int y = 0; y < surface_n.height; ++y) {
        for (int x = 0; x < surface_n.width; ++x) {
            uint16_t pixel = rgb888_to_rgb565(
                    surface_n.pixels[(size_t)y * (size_t)surface_n.width + (size_t)x]);
            row[x * 2] = (uint8_t)(pixel & 0xffu);
            row[x * 2 + 1] = (uint8_t)(pixel >> 8);
        }
        off_t offset = (off_t)y * (off_t)fbdev.stride;
        ssize_t written = pwrite(fbdev.fd, row, (size_t)fbdev.stride, offset);
        if (written != fbdev.stride) {
            ok = false;
            break;
        }
    }
    free(row);
    return ok;
}

static bool present_mmap(bool do_msync) {
    for (int y = 0; y < surface_n.height; ++y) {
        uint16_t *dst = (uint16_t *)(fbdev.mem + (size_t)y * (size_t)fbdev.stride);
        const uint32_t *src = surface_n.pixels + (size_t)y * (size_t)surface_n.width;
        for (int x = 0; x < surface_n.width; ++x) {
            dst[x] = rgb888_to_rgb565(src[x]);
        }
    }
    if (do_msync && msync(fbdev.mem, fbdev.mem_len, MS_SYNC) != 0) {
        fprintf(stderr, "msync failed: %s\n", strerror(errno));
        return false;
    }
    return true;
}

static PresentResult present_if_needed(PresentMode mode) {
    printf("  present enter backend=%s open=%d visible=%u presented=%u dirty=%d\n",
           backend_name(graphics_backend),
           fbdev.fd >= 0,
           visible_generation,
           presented_generation,
           surface_n.dirty);
    if (graphics_backend != BACKEND_FBDEV) return PRESENT_SKIPPED_BACKEND;
    if (fbdev.fd < 0 || !surface_n.exists || !surface_n.pixels) return PRESENT_FAILED;
    if (presented_generation == visible_generation) return PRESENT_SKIPPED_CLEAN;

    bool ok;
    if (mode == PRESENT_PWRITE) ok = present_pwrite();
    else ok = present_mmap(mode == PRESENT_MMAP_MSYNC);
    if (!ok) return PRESENT_FAILED;

    surface_n.dirty = false;
    presented_generation = visible_generation;
    return PRESENT_FLUSHED;
}

static bool read_sample(const char *path, int x, int y, uint16_t *out) {
    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    int fd = open_fb_info(path, &fix, &var);
    if (fd < 0) return false;
    uint8_t bytes[2];
    off_t offset = (off_t)y * (off_t)fix.line_length + (off_t)x * 2;
    ssize_t got = pread(fd, bytes, sizeof(bytes), offset);
    close(fd);
    if (got != (ssize_t)sizeof(bytes)) return false;
    *out = (uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8);
    return true;
}

static bool sample_equals(const char *path, const char *label, int x, int y, uint16_t expected) {
    uint16_t actual = 0;
    if (!read_sample(path, x, y, &actual)) {
        printf("  sample %-8s read failed\n", label);
        return false;
    }
    printf("  sample %-8s (%3d,%3d) actual=%04x expected=%04x\n",
           label, x, y, (unsigned)actual, (unsigned)expected);
    return actual == expected;
}

static bool check_black_samples(const char *path) {
    bool ok = true;
    ok = sample_equals(path, "red", 40, 40, 0x0000u) && ok;
    ok = sample_equals(path, "green", 240, 40, 0x0000u) && ok;
    ok = sample_equals(path, "blue", 40, 240, 0x0000u) && ok;
    ok = sample_equals(path, "white", 240, 240, 0x0000u) && ok;
    return ok;
}

static bool check_quadrant_samples(const char *path) {
    bool ok = true;
    ok = sample_equals(path, "red", 40, 40, 0xf800u) && ok;
    ok = sample_equals(path, "green", 240, 40, 0x07e0u) && ok;
    ok = sample_equals(path, "blue", 40, 240, 0x001fu) && ok;
    ok = sample_equals(path, "white", 240, 240, 0xffffu) && ok;
    return ok;
}

static bool validate_direct_text_model(void) {
    bool ok = true;
    int text_white = count_colour(&surface_n, 16, 16, 60, 24, RGB_WHITE);
    int text_red = count_colour(&surface_n, 16, 16, 112, 48, RGB_RED);
    int print_white = count_colour(&surface_n, 16, 64, 60, 72, RGB_WHITE);
    int print_blue = count_colour(&surface_n, 16, 64, 112, 96, RGB_BLUE);
    printf("  model direct-text white=%d red=%d print-white=%d blue=%d\n",
           text_white, text_red, print_white, print_blue);
    ok = (text_white > 0) && ok;
    ok = (text_red > 0) && ok;
    ok = (print_white > 0) && ok;
    ok = (print_blue > 0) && ok;
    ok = surface_pixel_equals(&surface_n, "TEXT white", 17, 16, RGB_WHITE) && ok;
    ok = surface_pixel_equals(&surface_n, "TEXT red bg", 80, 24, RGB_RED) && ok;
    ok = surface_pixel_equals(&surface_n, "PRINT white", 17, 64, RGB_WHITE) && ok;
    ok = surface_pixel_equals(&surface_n, "PRINT blue bg", 80, 72, RGB_BLUE) && ok;
    return ok;
}

static bool validate_direct_text_fbdev(const char *path) {
    bool ok = true;
    ok = sample_equals(path, "TEXT", 17, 16, 0xffffu) && ok;
    ok = sample_equals(path, "TEXT-bg", 80, 24, 0xf800u) && ok;
    ok = sample_equals(path, "PRINT", 17, 64, 0xffffu) && ok;
    ok = sample_equals(path, "PRINT-bg", 80, 72, 0x001fu) && ok;
    return ok;
}

static bool validate_layer_model_before_merge(void) {
    bool ok = true;
    int n_white = count_colour(&surface_n, 16, 128, 60, 136, RGB_WHITE);
    int f_green = count_colour(&surface_f, 0, 0, PICOCALC_W - 1, PICOCALC_H - 1,
                               RGB_GREEN);
    int l_white = count_colour(&surface_l, 16, 128, 60, 136, RGB_WHITE);
    printf("  model layer-before-merge n-white=%d f-green=%d l-white=%d\n",
           n_white, f_green, l_white);
    ok = (n_white == 0) && ok;
    ok = (f_green == PICOCALC_W * PICOCALC_H) && ok;
    ok = (l_white > 0) && ok;
    ok = surface_pixel_equals(&surface_n, "N before merge", 17, 128, RGB_BLACK) && ok;
    ok = surface_pixel_equals(&surface_f, "F background", 80, 144, RGB_GREEN) && ok;
    ok = surface_pixel_equals(&surface_l, "L text", 17, 128, RGB_WHITE) && ok;
    return ok;
}

static bool validate_layer_model_after_merge(void) {
    bool ok = true;
    int n_white = count_colour(&surface_n, 16, 128, 60, 136, RGB_WHITE);
    int n_green = count_colour(&surface_n, 0, 0, PICOCALC_W - 1, PICOCALC_H - 1,
                               RGB_GREEN);
    printf("  model layer-after-merge n-white=%d n-green=%d\n", n_white, n_green);
    ok = (n_white > 0) && ok;
    ok = (n_green > 0) && ok;
    ok = surface_pixel_equals(&surface_n, "merged text", 17, 128, RGB_WHITE) && ok;
    ok = surface_pixel_equals(&surface_n, "merged bg", 80, 144, RGB_GREEN) && ok;
    return ok;
}

static bool validate_layer_fbdev(const char *path) {
    bool ok = true;
    ok = sample_equals(path, "L-text", 17, 128, 0xffffu) && ok;
    ok = sample_equals(path, "L-bg", 80, 144, 0x07e0u) && ok;
    return ok;
}

static void run_buggy_order(const char *path, int hold_ms) {
    const char *name = "buggy-order";
    printf("\nCASE %s\n", name);
    clear_fbdev_file(path, 0x0000u);
    reset_graphics_state();
    if (!ensure_display_buggy_order(path)) {
        record_fail(name, "could not initialize buggy-order display");
        reset_graphics_state();
        return;
    }
    draw_quadrants();
    PresentResult result = present_if_needed(PRESENT_MMAP_MSYNC);
    sleep_ms(hold_ms);
    bool stayed_black = check_black_samples(path);
    if (result == PRESENT_SKIPPED_BACKEND && stayed_black) {
        record_pass(name);
    } else {
        record_fail(name, "expected backend reset to skip presentation and leave fbdev black");
    }
    reset_graphics_state();
}

static void run_fixed_expected(const char *path, PresentMode mode, int hold_ms) {
    char name[64];
    snprintf(name, sizeof(name), "fixed-%s", present_mode_name(mode));
    printf("\nCASE %s\n", name);
    clear_fbdev_file(path, 0x0000u);
    reset_graphics_state();
    if (!ensure_display_fixed_order(path)) {
        record_fail(name, "could not initialize fixed-order display");
        reset_graphics_state();
        return;
    }
    draw_quadrants();
    PresentResult result = present_if_needed(mode);
    sleep_ms(hold_ms);
    bool visible = check_quadrant_samples(path);
    if (result == PRESENT_FLUSHED && visible) record_pass(name);
    else record_fail(name, "expected four-quadrant pattern in /dev/fb0");
    reset_graphics_state();
}

static void run_fixed_observed(const char *path, PresentMode mode, int hold_ms) {
    char detail[128];
    printf("\nCASE fixed-%s-observe\n", present_mode_name(mode));
    clear_fbdev_file(path, 0x0000u);
    reset_graphics_state();
    if (!ensure_display_fixed_order(path)) {
        record_fail("fixed-observe", "could not initialize fixed-order display");
        reset_graphics_state();
        return;
    }
    draw_quadrants();
    PresentResult result = present_if_needed(mode);
    sleep_ms(hold_ms);
    bool visible = check_quadrant_samples(path);
    snprintf(detail, sizeof(detail), "present_result=%d pattern_visible=%d",
             result, visible ? 1 : 0);
    record_observation("fixed-mmap-nosync", detail);
    reset_graphics_state();
}

static void run_text_layering(const char *path, int hold_ms) {
    const char *name = "text-layering";
    printf("\nCASE %s\n", name);
    clear_fbdev_file(path, 0x0000u);
    reset_graphics_state();
    if (!ensure_display_fixed_order(path)) {
        record_fail(name, "could not initialize fixed-order display");
        reset_graphics_state();
        return;
    }

    surface_fill(&surface_n, RGB_BLACK);
    surface_box(&surface_n, 16, 16, 96, 32, RGB_RED);
    draw_text_marker(&surface_n, 16, 16, 5, RGB_WHITE);
    surface_box(&surface_n, 16, 64, 96, 32, RGB_BLUE);
    draw_text_marker(&surface_n, 16, 64, 5, RGB_WHITE);

    bool direct_model = validate_direct_text_model();
    PresentResult direct_result = present_if_needed(PRESENT_MMAP_MSYNC);
    sleep_ms(hold_ms);
    bool direct_visible = validate_direct_text_fbdev(path);

    surface_fill(&surface_n, RGB_BLACK);
    if (!surface_create(SURFACE_F, PICOCALC_W, PICOCALC_H) ||
            !surface_create(SURFACE_L, PICOCALC_W, PICOCALC_H)) {
        record_fail(name, "could not create F/L surfaces");
        reset_graphics_state();
        return;
    }
    surface_fill(&surface_f, RGB_GREEN);
    surface_fill(&surface_l, RGB_BLACK);
    draw_text_marker(&surface_l, 16, 128, 5, RGB_WHITE);

    bool before_merge = validate_layer_model_before_merge();
    surface_merge_transparent(&surface_f, &surface_l, &surface_n, RGB_BLACK);
    bool after_merge = validate_layer_model_after_merge();
    PresentResult layer_result = present_if_needed(PRESENT_MMAP_MSYNC);
    sleep_ms(hold_ms);
    bool layer_visible = validate_layer_fbdev(path);

    if (direct_model && direct_result == PRESENT_FLUSHED && direct_visible &&
            before_merge && after_merge && layer_result == PRESENT_FLUSHED &&
            layer_visible) {
        record_pass(name);
    } else {
        record_fail(name, "expected text over graphics and F/L merge to be visible on fbdev");
    }
    reset_graphics_state();
}

static bool print_fb_info(const char *path) {
    struct fb_fix_screeninfo fix;
    struct fb_var_screeninfo var;
    int fd = open_fb_info(path, &fix, &var);
    if (fd < 0) return false;
    printf("fbdev path=%s id=%s size=%ux%u virtual=%ux%u stride=%u bpp=%u smem_len=%u\n",
           path,
           fix.id,
           var.xres,
           var.yres,
           var.xres_virtual,
           var.yres_virtual,
           fix.line_length,
           var.bits_per_pixel,
           fix.smem_len);
    close(fd);
    return true;
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "Usage: %s [--fb /dev/fb0] [--case all|buggy-order|fixed-nosync|fixed-msync|fixed-pwrite|text-layering] [--hold-ms N]\n",
            argv0);
}

int main(int argc, char **argv) {
    const char *fb_path = "/dev/fb0";
    const char *case_name = "all";
    int hold_ms = 750;

    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--fb") == 0 && i + 1 < argc) {
            fb_path = argv[++i];
        } else if (strcmp(argv[i], "--case") == 0 && i + 1 < argc) {
            case_name = argv[++i];
        } else if (strcmp(argv[i], "--hold-ms") == 0 && i + 1 < argc) {
            hold_ms = atoi(argv[++i]);
            if (hold_ms < 0) hold_ms = 0;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            usage(argv[0]);
            return 2;
        }
    }

    if (!print_fb_info(fb_path)) return 1;

    if (strcmp(case_name, "all") == 0) {
        run_buggy_order(fb_path, hold_ms);
        run_fixed_observed(fb_path, PRESENT_MMAP_NOSYNC, hold_ms);
        run_fixed_expected(fb_path, PRESENT_MMAP_MSYNC, hold_ms);
        run_fixed_expected(fb_path, PRESENT_PWRITE, hold_ms);
        run_text_layering(fb_path, hold_ms);
    } else if (strcmp(case_name, "buggy-order") == 0) {
        run_buggy_order(fb_path, hold_ms);
    } else if (strcmp(case_name, "fixed-nosync") == 0) {
        run_fixed_observed(fb_path, PRESENT_MMAP_NOSYNC, hold_ms);
    } else if (strcmp(case_name, "fixed-msync") == 0) {
        run_fixed_expected(fb_path, PRESENT_MMAP_MSYNC, hold_ms);
    } else if (strcmp(case_name, "fixed-pwrite") == 0) {
        run_fixed_expected(fb_path, PRESENT_PWRITE, hold_ms);
    } else if (strcmp(case_name, "text-layering") == 0) {
        run_text_layering(fb_path, hold_ms);
    } else {
        usage(argv[0]);
        return 2;
    }

    clear_fbdev_file(fb_path, 0x0000u);
    blank_cycle_fbdev(fb_path);
    printf("\nSUMMARY pass=%d fail=%d observe=%d\n", passes, failures, observations);
    return failures ? 1 : 0;
}
