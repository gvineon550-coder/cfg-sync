#!/usr/bin/env bash
set -e

mkdir -p app/src/main/cpp

# ============ 1. sigcheck.cpp (RegisterNatives + динамический XOR) ============
cat > app/src/main/cpp/sigcheck.cpp << 'XEOF'
#include <jni.h>
#include <string>
#include <cstring>
#include <cstdint>
#include <cstdio>

// Pages URL "https://gvineon550-coder.github.io/cfg-sync/"
// XORed with dynamic per-position key (see keyForPos)
static const unsigned char kPagesBase[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x3C,0x2D,
    0x56,0x51,0x5A,0x50,0x51,0x0A,0x0A,0x0F,0x12,0x5C,
    0x18,0x13,0x12,0x05,0x59,0x10,0x1E,0x03,0x1F,0x02,
    0x4F,0x03,0x44,0x42,0x02,0x4E,0x4B,0x4A,0x00,0x5E,
    0x28,0x3F,0x32,0x7E
};

// play/options template "https://rutube.ru/api/play/options/%s/"
static const unsigned char kPlayTpl[] = {
    0x33,0x2F,0x2F,0x2B,0x28,0x61,0x74,0x74,0x29,0x2E,
    0x4B,0x4A,0x5D,0x5A,0x11,0x4D,0x4A,0x10,0x5E,0x4F,
    0x1E,0x58,0x07,0x1B,0x16,0x0E,0x58,0x18,0x07,0x03,
    0x44,0x42,0x43,0x5E,0x02,0x08,0x5E,0x02
};

static const char* kUaDesktop =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Safari/537.36";

static const char* kUaMobile =
    "Mozilla/5.0 (Linux; Android 13) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/122.0.0.0 Mobile Safari/537.36";

// Dynamic key: changes every 10 characters, cycles through 5 keys
static unsigned char keyForPos(size_t i) {
    static const unsigned char keys[] = {0x5B, 0x3F, 0x77, 0x2D, 0x51};
    return keys[(i / 10) % 5];
}

static std::string decode(const unsigned char* data, size_t len) {
    std::string out;
    out.reserve(len);
    for (size_t i = 0; i < len; ++i) {
        out.push_back(static_cast<char>(data[i] ^ keyForPos(i)));
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

// ---- Native implementations (arbitrary names, hidden via -fvisibility=hidden) ----

static jstring impl_url(JNIEnv* env, jobject, jint idx) {
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

static jstring impl_ua(JNIEnv* env, jobject, jint idx) {
    if (idx == 0) return env->NewStringUTF(kUaDesktop);
    if (idx == 1) return env->NewStringUTF(kUaMobile);
    return nullptr;
}

static jboolean impl_tampered(JNIEnv*, jobject) {
    return isTampered() ? JNI_TRUE : JNI_FALSE;
}

// ---- Dynamic JNI registration ----

static const JNINativeMethod kNativeStringsMethods[] = {
    {"nativeUrl", "(I)Ljava/lang/String;", reinterpret_cast<void*>(impl_url)},
    {"nativeUa",  "(I)Ljava/lang/String;", reinterpret_cast<void*>(impl_ua)},
};

static const JNINativeMethod kSignatureGuardMethods[] = {
    {"nativeIsTampered", "()Z", reinterpret_cast<void*>(impl_tampered)},
};

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    jclass clsNativeStrings = env->FindClass("com/nova/sync/NativeStrings");
    if (!clsNativeStrings) return JNI_ERR;
    if (env->RegisterNatives(
            clsNativeStrings,
            kNativeStringsMethods,
            sizeof(kNativeStringsMethods) / sizeof(kNativeStringsMethods[0])
        ) != JNI_OK) {
        return JNI_ERR;
    }

    jclass clsSignatureGuard = env->FindClass("com/nova/sync/SignatureGuard");
    if (!clsSignatureGuard) return JNI_ERR;
    if (env->RegisterNatives(
            clsSignatureGuard,
            kSignatureGuardMethods,
            sizeof(kSignatureGuardMethods) / sizeof(kSignatureGuardMethods[0])
        ) != JNI_OK) {
        return JNI_ERR;
    }

    return JNI_VERSION_1_6;
}
XEOF

# ============ 2. CMakeLists.txt (O3 + LTO + hidden visibility) ============
cat > app/src/main/cpp/CMakeLists.txt << 'XEOF'
cmake_minimum_required(VERSION 3.22.1)

project("sigcheck" CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(sigcheck SHARED sigcheck.cpp)

target_compile_options(sigcheck PRIVATE
    -O3
    -fvisibility=hidden
    -fvisibility-inlines-hidden
    -ffunction-sections
    -fdata-sections
    -fno-exceptions
    -fno-rtti
    -fno-unwind-tables
    -fno-asynchronous-unwind-tables
    -flto
)

target_link_options(sigcheck PRIVATE
    -Wl,--gc-sections
    -Wl,-s
    -flto
)

find_library(log-lib log)
target_link_libraries(sigcheck ${log-lib})
XEOF

echo "=== fix_harden applied ==="
ls -la app/src/main/cpp/
