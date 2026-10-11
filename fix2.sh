#!/usr/bin/env bash
set -e

mkdir -p app/src/main/cpp
mkdir -p app/src/main/java/com/nova/sync/data
mkdir -p app/src/main/java/com/nova/sync/ui
mkdir -p scripts

# ============ 1. sigcheck.cpp ============
cat > app/src/main/cpp/sigcheck.cpp << 'XEOF'
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
XEOF

# ============ 2. NativeStrings.kt ============
cat > app/src/main/java/com/nova/sync/NativeStrings.kt << 'XEOF'
package com.nova.sync

object NativeStrings {
    private val loaded: Boolean = try {
        System.loadLibrary("sigcheck")
        true
    } catch (_: Throwable) {
        false
    }

    private external fun nativeUrl(idx: Int): String?
    private external fun nativeUa(idx: Int): String?

    private const val FALLBACK_DESKTOP =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    private const val FALLBACK_MOBILE =
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"

    val pagesBase: String
        get() = if (loaded) (nativeUrl(0) ?: "") else ""
    val playOptionsTemplate: String
        get() = if (loaded) (nativeUrl(1) ?: "") else ""
    val uaDesktop: String
        get() = if (loaded) (nativeUa(0) ?: FALLBACK_DESKTOP) else FALLBACK_DESKTOP
    val uaMobile: String
        get() = if (loaded) (nativeUa(1) ?: FALLBACK_MOBILE) else FALLBACK_MOBILE
}
XEOF

# ============ 3. Resolver.kt ============
cat > app/src/main/java/com/nova/sync/data/Resolver.kt << 'XEOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Resolver {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun resolveStream(channelId: String): String? = withContext(Dispatchers.IO) {
        runCatching {
            val tpl = NativeStrings.playOptionsTemplate
            if (tpl.isEmpty()) return@runCatching null
            val url = tpl.replace("%s", channelId)
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Referer", "https://rutube.ru/")
                .header("Origin", "https://rutube.ru")
                .header("Accept", "*/*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val obj = json.parseToJsonElement(body).jsonObject
                val live = obj["live_streams"]?.jsonObject ?: return@runCatching null
                val hls = live["hls"]?.jsonArray ?: return@runCatching null
                val first = hls.firstOrNull()?.jsonObject ?: return@runCatching null
                first["url"]?.jsonPrimitive?.content
            }
        }.getOrNull()
    }
}
XEOF

# ============ 4. Repository.kt ============
cat > app/src/main/java/com/nova/sync/data/Repository.kt << 'XEOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object Repository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun loadCatalog(): Result<Catalog> = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "c.json"
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Accept", "application/json, text/plain, */*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                json.decodeFromString<Catalog>(body)
            }
        }
    }
}
XEOF

# ============ 5. TrustedDeviceStore.kt ============
cat > app/src/main/java/com/nova/sync/data/TrustedDeviceStore.kt << 'XEOF'
package com.nova.sync.data

import com.nova.sync.NativeStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

object TrustedDeviceStore {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Volatile private var cache: Set<String>? = null

    suspend fun refresh() = withContext(Dispatchers.IO) {
        runCatching {
            val url = NativeStrings.pagesBase + "trusted_devices.json"
            val req = Request.Builder()
                .url(url)
                .header("User-Agent", NativeStrings.uaMobile)
                .header("Accept", "application/json, text/plain, */*")
                .header("Accept-Language", "ru-RU,ru;q=0.9,en;q=0.8")
                .build()
            client.newCall(req).execute().use { resp ->
                require(resp.isSuccessful) { "HTTP ${resp.code}" }
                val body = resp.body?.string().orEmpty()
                val td = json.decodeFromString<TrustedDevices>(body)
                cache = td.devices.toSet()
            }
        }
    }

    fun isTrusted(id: String): Boolean = cache?.contains(id) == true
    fun cached(): Set<String> = cache ?: emptySet()
}
XEOF

# ============ 6. PlayerScreen.kt ============
cat > app/src/main/java/com/nova/sync/ui/PlayerScreen.kt << 'XEOF'
package com.nova.sync.ui

import android.view.ViewGroup
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import com.nova.sync.NativeStrings
import com.nova.sync.data.HistoryStore
import com.nova.sync.data.Resolver
import com.nova.sync.player.PlayerHolder
import kotlinx.coroutines.delay

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val channel = PlayerHolder.current
    if (channel == null) {
        LaunchedEffect(Unit) { onBack() }
        return
    }

    var resolvedUrl by remember { mutableStateOf(channel.streamUrl) }
    var resolveError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(channel.id) {
        if (resolvedUrl.isNullOrBlank() && !channel.blocked) {
            val u = Resolver.resolveStream(channel.id)
            if (u.isNullOrBlank()) resolveError = "Поток недоступен"
            resolvedUrl = u
        }
    }

    val player: ExoPlayer? = remember(channel.id, resolvedUrl) {
        val url = resolvedUrl
        if (url.isNullOrBlank()) null
        else {
            val httpFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(NativeStrings.uaMobile)
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(15_000)
                .setReadTimeoutMs(20_000)
            ExoPlayer.Builder(ctx)
                .setMediaSourceFactory(DefaultMediaSourceFactory(httpFactory))
                .build()
                .apply {
                    setMediaItem(MediaItem.fromUri(url))
                    prepare()
                    playWhenReady = true
                }
        }
    }

    DisposableEffect(player) {
        HistoryStore.push(channel.id)
        onDispose { player?.release() }
    }

    var showOsd by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }
    LaunchedEffect(showOsd, isPlaying) {
        if (showOsd) { delay(4000); showOsd = false }
    }

    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(focus)
            .focusable()
            .onPreviewKeyEvent { e ->
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (e.key) {
                    Key.DirectionLeft -> {
                        player?.let { it.seekTo((it.currentPosition - 10_000).coerceAtLeast(0)) }
                        showOsd = true; true
                    }
                    Key.DirectionRight -> {
                        player?.let { it.seekTo(it.currentPosition + 10_000) }
                        showOsd = true; true
                    }
                    Key.DirectionCenter, Key.Enter, Key.Spacebar -> {
                        isPlaying = !isPlaying
                        player?.playWhenReady = isPlaying
                        showOsd = true; true
                    }
                    Key.Back -> { onBack(); true }
                    Key.MediaPlayPause -> {
                        isPlaying = !isPlaying
                        player?.playWhenReady = isPlaying
                        true
                    }
                    else -> false
                }
            }
    ) {
        if (player != null) {
            AndroidView(
                factory = { c ->
                    PlayerView(c).apply {
                        useController = false
                        keepScreenOn = true
                        layoutParams = ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        )
                    }
                },
                update = { view -> view.player = player },
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Text(resolveError ?: "Загрузка...", color = Color.White,
                    style = MaterialTheme.typography.titleLarge)
            }
        }

        if (showOsd) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(Color(0xCC000000))
                    .padding(24.dp)
            ) {
                Column {
                    Text(channel.title.ifBlank { channel.id }, color = Color.White,
                        style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(
                        if (isPlaying) "OK — пауза / ← → — ±10 сек / Back — выход"
                        else "OK — продолжить",
                        color = Color(0xFFB8C4D8)
                    )
                }
            }
        }
    }
}
XEOF

# ============ 7. sync.py ============
cat > scripts/sync.py << 'XEOF'
#!/usr/bin/env python3
"""Data sync script. Runs on GitHub Actions schedule."""
import json, time, sys
from datetime import datetime, timezone
try:
    import requests
except ImportError:
    print("ERROR: requests not installed"); sys.exit(1)

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
      "AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/122.0.0.0 Safari/537.36")
BASE = "https://rutube.ru"
HEADERS = {
    "User-Agent": UA,
    "Referer": "https://rutube.ru/",
    "Origin": "https://rutube.ru",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-origin",
}
TITLE_PREFIX = "Прямой эфир"
CATEGORY_RENAMES = {"Все прямые эфиры": "Прямые эфиры", "Новости и СМИ": "Новости"}
MAX_RETRIES = 3
CHANNEL_DELAY = 0.15
RETRY_DELAY_BASE = 0.5
PERMANENT_ERRORS = {400, 401, 403, 404, 410, 422}
STATS = {"ok": 0, "404": 0, "403": 0, "5xx": 0, "timeout": 0, "other": 0}
OUT = "docs/c.json"

def http_get(url, params=None, timeout=15):
    last_ex = None
    for attempt in range(MAX_RETRIES):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=timeout)
            if r.status_code in PERMANENT_ERRORS:
                raise requests.HTTPError(f"{r.status_code} {r.reason}", response=r)
            r.raise_for_status()
            return r
        except requests.HTTPError as e:
            status = e.response.status_code if e.response is not None else 0
            if status in PERMANENT_ERRORS: raise
            last_ex = e
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY_BASE * (attempt + 1))
        except (requests.Timeout, requests.ConnectionError) as e:
            last_ex = e
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY_BASE * (attempt + 1))
        except Exception as e:
            last_ex = e; break
    raise last_ex

def clean_title(s):
    s = s.strip()
    if s.startswith(TITLE_PREFIX):
        rest = s[len(TITLE_PREFIX):].lstrip(" :;,-\u2013\u2014")
        if rest: return rest
    return s

def clean_category(s):
    return CATEGORY_RENAMES.get(s.strip(), s.strip())

def category_text(v):
    if v is None: return ""
    if isinstance(v, str): return v.strip()
    if isinstance(v, dict):
        n = v.get("name"); return str(n).strip() if n else ""
    return str(v).strip()

def description_text(v):
    return v.strip() if isinstance(v, str) else ("" if v is None else str(v).strip())

def fetch_channels():
    url = f"{BASE}/api/feeds/autowidget/2"
    params = {"client": "wdp", "show_hidden_videos": "true",
              "show_user_hidden_videos": "true", "origin__type": "rst,rspa"}
    return http_get(url, params=params).json()

def parse_channels(data):
    out = []; seen = set()
    def add(entry, group=None):
        if not entry: return
        cid = entry.get("id")
        if not cid or cid in seen: return
        title = (entry.get("title") or "").strip()
        if not title: return
        d = entry.get("duration")
        if d is not None and d != 0: return
        if entry.get("origin_type") == "ifrm": return
        seen.add(cid)
        own = category_text(entry.get("category")) or None
        base_group = own or (group.strip() if group else None)
        final_group = clean_category(base_group) if base_group else None
        out.append({"id": cid, "title": clean_title(title),
                    "description": description_text(entry.get("description")),
                    "category": final_group, "avatar": "",
                    "stream_url": None, "blocked": False,
                    "blocked_reason": "", "unavailable": False})
    results = data.get("results")
    if results:
        for e in results:
            ch = e.get("childs")
            if ch:
                for c in ch: add(c, e.get("name"))
            else: add(e)
    else:
        feed = data.get("feed") or {}
        res = feed.get("resources") or []
        if len(res) > 1:
            for it in (res[1].get("items") or []): add(it)
    return out

def is_blocked(resp):
    t = resp.get("type")
    if t in ("blocking_rule", "player_stub"): return True
    d = resp.get("detail")
    if isinstance(d, dict):
        dt = d.get("type")
        if dt in ("blocking_rule", "player_stub"): return True
        n = str(d.get("name") or "")
        if n.startswith("blocking_rule") or n == "login_required": return True
    return False

def blocked_reason(resp):
    d = resp.get("detail") or {}
    if not isinstance(d, dict): d = {}
    n = str(d.get("name") or "")
    t = resp.get("type") or d.get("type")
    if t == "blocking_rule" or n.startswith("blocking_rule"): return "правообладатель или VPN"
    if t == "player_stub" or n == "login_required": return "скрыто автором"
    return "недоступно"

def enrich(ch):
    try:
        r = http_get(f"{BASE}/api/play/options/{ch['id']}/")
        resp = r.json(); STATS["ok"] += 1
    except requests.HTTPError as e:
        s = e.response.status_code if e.response is not None else 0
        if s in (404, 410): STATS["404"] += 1; ch["unavailable"] = True
        elif s == 403: STATS["403"] += 1; ch["unavailable"] = True
        elif 500 <= s < 600: STATS["5xx"] += 1
        else: STATS["other"] += 1
        return
    except (requests.Timeout, requests.ConnectionError):
        STATS["timeout"] += 1; return
    except Exception:
        STATS["other"] += 1; return

    if is_blocked(resp):
        ch["blocked"] = True; ch["blocked_reason"] = blocked_reason(resp); return

    thumb = resp.get("thumbnail_url")
    if isinstance(thumb, dict):
        ch["avatar"] = thumb.get("hq") or thumb.get("original") or ""
    elif isinstance(thumb, str):
        ch["avatar"] = thumb
    if not ch["avatar"]:
        author = resp.get("author")
        if isinstance(author, dict):
            ch["avatar"] = author.get("avatar_url") or ""

    live = resp.get("live_streams") or {}
    if isinstance(live, dict):
        hls = live.get("hls") or []
        if hls and isinstance(hls, list):
            first = hls[0]
            if isinstance(first, dict):
                ch["stream_url"] = first.get("url")

def main():
    print(f"sync started {datetime.now(timezone.utc).isoformat()}")
    try:
        data = fetch_channels()
    except Exception as e:
        print(f"FATAL: {e}"); sys.exit(1)
    channels = parse_channels(data)
    print(f"got {len(channels)} channels")
    if not channels:
        print("FATAL: no channels"); sys.exit(1)
    for i, ch in enumerate(channels, 1):
        enrich(ch)
        if i % 20 == 0 or i == len(channels):
            print(f"[{i}/{len(channels)}] ok={STATS['ok']} 404={STATS['404']}")
        time.sleep(CHANNEL_DELAY)
    final = [c for c in channels if not c.get("blocked")]
    payload = {
        "updated": datetime.now(timezone.utc).isoformat(),
        "total": len(final),
        "with_url": sum(1 for c in final if c.get("stream_url")),
        "no_url": sum(1 for c in final if not c.get("stream_url")),
        "channels": final,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"saved {OUT} with {len(final)} channels")

if __name__ == "__main__":
    main()
XEOF

echo "=== fix2 applied ==="
ls -la
ls -la app/src/main/java/com/nova/sync/
