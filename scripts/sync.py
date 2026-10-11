#!/usr/bin/env python3
"""Data sync script. Runs on GitHub Actions schedule."""
import json, time, sys
from datetime import datetime, timezone
try:
    import requests
except ImportError:
    print("ERROR: requests not installed"); sys.exit(1)

UA = ("Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
BASE = "https://rutube.ru"
HEADERS = {
    "User-Agent": UA, "Referer": "https://rutube.ru/",
    "Origin": "https://rutube.ru", "Accept": "*/*",
    "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
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

    # avatar: prefer thumbnail_url.hq, fallback author.avatar_url
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
