#include <jni.h>
#include <string>
#include <cstring>
#include <cstdint>
#include <cstdio>

static const unsigned char kKey = 0x5B;

static const unsigned char kPagesBase[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x3C,0x2D,0x32,0x35,0x3E,0x34,0x35,
    0x6E,0x6E,0x6B,0x76,0x38,0x34,0x3F,0x3E,0x29,0x75,0x3C,0x32,0x2F,0x33,0x2E,
    0x39,0x75,0x32,0x34,0x74,0x38,0x3D,0x3C,0x76,0x28,0x22,0x35,0x38,0x74
};

static const unsigned char kPlayTpl[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x29,0x2E,0x2F,0x2E,0x39,0x3E,0x75,
    0x29,0x2E,0x74,0x3A,0x2B,0x32,0x74,0x2B,0x37,0x3A,0x22,0x74,0x34,0x2B,0x2F,
    0x32,0x34,0x35,0x28,0x74,0x7E,0x28,0x74
};

static const char* kUaDesktop =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Safari/537.36";

static const char* kUaMobile =
    "Mozilla/5.0 (Linux; Android 13) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Mobile Safari/537.36";

static std::string decode(const unsigned char* data, size_t len) {
    std::string out;
    out.reserve(len);
    for (size_t i = 0; i < len; ++i) {
        out.push_back(static_cast<char>(data[i] ^ kKey));
    }
    return out;
}

static bool isTampered() {
    FILE* f = fopen("/proc/self/maps", "r");
    if (!f) return false;
    char line[512];
    bool bad = false;
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "frida") ||
            strstr(line, "magisk") ||
            strstr(line, "xposed") ||
            strstr(line, "substrate")) {
            bad = true;
            break;
        }
    }
    fclose(f);
    return bad;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_nova_sync_NativeStrings_nativeUrl(JNIEnv* env, jobject, jint idx) {
    if (idx == 0) {
        std::string s = decode(kPagesBase, sizeof(kPagesBase));
        return env->NewStringUTF(s.c_str());
    }
    if (idx == 1) {
        std::string s = decode(kPlayTpl, sizeof(kPlayTpl));
        return env->NewStringUTF(s.c_str());
    }
    return nullptr;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_nova_sync_NativeStrings_nativeUa(JNIEnv* env, jobject, jint idx) {
    if (idx == 0) return env->NewStringUTF(kUaDesktop);
    if (idx == 1) return env->NewStringUTF(kUaMobile);
    return nullptr;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_nova_sync_SignatureGuard_nativeIsTampered(JNIEnv*, jobject) {
    return isTampered() ? JNI_TRUE : JNI_FALSE;
}
