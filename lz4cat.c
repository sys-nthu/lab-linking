// lz4cat.c — decompress an .lz4 frame file to stdout
// Usage: ./lz4cat <input.lz4>  > output.raw
// Notes: Writes binary to stdout; handles multi-frame streams.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <lz4frame.h>

#define IN_CHUNK   (1u << 16)  // 64 KiB
#define OUT_CHUNK  (1u << 18)  // 256 KiB

static void die_perror(const char* what) {
    fprintf(stderr, "error: %s: %s\n", what, strerror(errno));
    exit(1);
}
static void die_lz4(const char* what, size_t code) {
    fprintf(stderr, "error: %s: %s\n", what, LZ4F_getErrorName(code));
    exit(1);
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <input.lz4>\n", argv[0]);
        return 2;
    }
    const char* inpath = argv[1];
    FILE* fin = fopen(inpath, "rb");
    if (!fin) die_perror("fopen input");

    LZ4F_dctx* dctx = NULL;
    size_t r = LZ4F_createDecompressionContext(&dctx, LZ4F_VERSION);
    if (LZ4F_isError(r)) die_lz4("LZ4F_createDecompressionContext", r);

    unsigned char* inBuf  = (unsigned char*)malloc(IN_CHUNK);
    unsigned char* outBuf = (unsigned char*)malloc(OUT_CHUNK);
    if (!inBuf || !outBuf) die_perror("malloc");

    size_t inSize = 0, inPos = 0;
    int eof = 0;

    while (1) {
        if (inPos == inSize && !eof) {
            inSize = fread(inBuf, 1, IN_CHUNK, fin);
            inPos = 0;
            if (inSize == 0) {
                if (ferror(fin)) die_perror("fread");
                eof = 1;
            }
        }
        if (eof && inPos == inSize) break;

        size_t srcSize = inSize - inPos;
        size_t dstSize = OUT_CHUNK;
        r = LZ4F_decompress(dctx, outBuf, &dstSize, inBuf + inPos, &srcSize, NULL);
        if (LZ4F_isError(r)) die_lz4("LZ4F_decompress", r);

        inPos += srcSize;

        if (dstSize) {
            size_t nw = fwrite(outBuf, 1, dstSize, stdout);
            if (nw != dstSize) die_perror("fwrite stdout");
        }
        // r==0 => finished a frame; keep looping in case multiple frames follow
    }

    free(outBuf);
    free(inBuf);
    LZ4F_freeDecompressionContext(dctx);
    fclose(fin);

    // flush stdout to surface any errors (e.g., broken pipe)
    if (fflush(stdout) != 0) die_perror("fflush stdout");
    return 0;
}
