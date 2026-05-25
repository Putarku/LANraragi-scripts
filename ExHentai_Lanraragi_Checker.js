// ==UserScript==
// @name        ExHentai Lanraragi Checker Putarku
// @namespace   https://github.com/Putarku
// @match       https://exhentai.org/*
// @match       https://e-hentai.org/*
// @grant       GM_xmlhttpRequest
// @grant       GM_addStyle
// @updateURL https://update.sleazyfork.org/scripts/538357/ExHentai%20Lanraragi%20Checker.user.js
// @downloadURL https://update.sleazyfork.org/scripts/538357/ExHentai%20Lanraragi%20Checker.user.js
// @version     1.8
// @author      Putarku
// @description Checks if galleries on ExHentai/E-Hentai are already in your Lanraragi library (urlfinder + /api/search fallback) and marks them by inserting a span at the beginning of the title.
// ==/UserScript==

(function() {
    'use strict';

    // --- 用户配置开始 ---
    const LRR_SERVER_URL = 'http://hostloacl:3000'; // 替换为您的 Lanraragi 服务器地址
    const LRR_API_KEY = ''; // 如果您的 Lanraragi API 需要密钥，请填写
    /** urlfinder（主检查）并发。局域网、NAS 负载不高时可改为 8～12 以加快整页扫完 */
    const MAX_CONCURRENT_REQUESTS = 8;
    /** 设为 false 可完全跳过备用搜索，仅依赖 urlfinder + 缓存，整页会快很多 */
    const ENABLE_ALT_SEARCH = true;
    /** 备用 GET /api/search 的并发上限（相同 filter 会自动合并为一次请求） */
    const ALT_SEARCH_CONCURRENCY = 2;
    const REQUEST_TIMEOUT_MS = 45000; // urlfinder 等默认超时
    /** 仅备用搜索使用，略短可更快失败；搜库慢时可酌情调大 */
    const SEARCH_REQUEST_TIMEOUT_MS = 40000;
    /** 设为 false 可关闭脚本所有控制台日志输出 */
    const ENABLE_LOGGING = true;
    // --- 用户配置结束 ---

    GM_addStyle(`
        .lrr-marker-span {
            font-weight: bold;
            border-radius: 3px;
            padding: 0px 3px;
            margin-right: 4px; /* 与 visied.js 的 ● 标记或标题文本的间距 */
            font-size: 0.9em;
        }

        .lrr-marker-downloaded {
            color: #28a745; /* 绿色 */
            background-color: #49995d;
        }

        .lrr-marker-file {
            color: #356ddc; /* 蓝色 */
            background-color: #894ab0;
        }

        .lrr-marker-error {
            color: #dc3545; /* 红色 */
            background-color: #fbe9ea;
        }
    `);

    const CACHE_DURATION = 3 * 24 * 60 * 60 * 1000; // 3 days in milliseconds
    const CLEANUP_INTERVAL = 7 * 24 * 60 * 60 * 1000; // 7 days cleanup interval
    const MAX_CACHE_ITEMS = 2000; // 限制最多缓存条目数，避免占满localStorage
    const MUTATION_DEBOUNCE_MS = 400;

    /** 已发起过检查或已用缓存处理过的画廊 URL（含同页重复链接、动态插入） */
    const seenGalleryUrls = new Set();

    /** 相同 searchQuery 合并为一次 HTTP（多行标题解析出同一作者+标题时） */
    const altSearchInflight = new Map();

    function simpleHash(str) {
        var h = 0;
        for (var i = 0; i < str.length; i++) {
            h = ((h << 5) - h) + str.charCodeAt(i);
            h |= 0;
        }
        return (h >>> 0).toString(16);
    }

    /** 简单异步并发池：同时最多 limit 个任务在执行 */
    function createPool(limit) {
        var active = 0;
        var queue = [];
        function runNext() {
            if (active >= limit || queue.length === 0) return;
            var item = queue.shift();
            active++;
            Promise.resolve(item.fn()).then(
                function(v) {
                    active--;
                    item.resolve(v);
                    runNext();
                },
                function(e) {
                    active--;
                    item.reject(e);
                    runNext();
                }
            );
        }
        return function run(fn) {
            return new Promise(function(resolve, reject) {
                queue.push({ fn: fn, resolve: resolve, reject: reject });
                runNext();
            });
        };
    }

    var runAltSearchLimited = createPool(ALT_SEARCH_CONCURRENCY);

    function log() {
        if (!ENABLE_LOGGING) return;
        console.log.apply(console, arguments);
    }

    function warn() {
        if (!ENABLE_LOGGING) return;
        console.warn.apply(console, arguments);
    }

    function error() {
        if (!ENABLE_LOGGING) return;
        console.error.apply(console, arguments);
    }

    function getCache(key) {
        const cached = localStorage.getItem(key);
        if (cached) {
            try {
                const parsed = JSON.parse(cached);
                const { timestamp, data } = parsed;
                if (timestamp && (Date.now() - timestamp) < CACHE_DURATION) {
                    return data;
                }
            } catch (e) {
                // 数据损坏时清理该条目
                warn(`[LRR Checker] Corrupted cache for key ${key}, removing.`);
                localStorage.removeItem(key);
            }
        }
        return null;
    }

    function setCache(key, data) {
        const item = {
            timestamp: Date.now(),
            data: minimizeCacheData(data)
        };
        const serialized = JSON.stringify(item);

        try {
            localStorage.setItem(key, serialized);
        } catch (e) {
            if (isQuotaExceeded(e)) {
                warn('[LRR Checker] Cache quota exceeded. Running emergency cleanup...');
                // 先清理过期缓存
                cleanupExpiredCache();
                try {
                    localStorage.setItem(key, serialized);
                    log('[LRR Checker] Cache write succeeded after expired cleanup.');
                    return;
                } catch (e2) {
                    // 强制LRU淘汰，限制总条目数
                    const removedByLimit = enforceMaxCacheItems();
                    if (removedByLimit === 0) {
                        // 若没有达到限制或未删除，则再删除最旧的25条作为兜底
                        purgeOldest(25);
                    }
                    try {
                        localStorage.setItem(key, serialized);
                        log('[LRR Checker] Cache write succeeded after LRU purge.');
                        return;
                    } catch (e3) {
                        error('[LRR Checker] Cache write failed even after cleanup:', e3);
                    }
                }
            } else {
                error('[LRR Checker] Error setting cache:', e);
            }
        }
    }

    // 压缩缓存内容，只保留脚本实际用到的字段
    function minimizeCacheData(original) {
        try {
            if (typeof original === 'object' && original && typeof original.altHit === 'boolean') {
                return { altHit: original.altHit };
            }
            const out = {};
            if (typeof original === 'object' && original) {
                if ('success' in original) out.success = original.success;
                if (original.error) out.error = original.error;
                if (original.data) {
                    const id = original.data.id;
                    out.data = {};
                    if (id !== undefined) out.data.id = id;
                }
            }
            return out;
        } catch (_) {
            return original;
        }
    }

    function isQuotaExceeded(err) {
        return err && (err.name === 'QuotaExceededError' || err.code === 22);
    }

    function listCacheEntries() {
        const entries = [];
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('lrr-checker-')) {
                try {
                    const item = localStorage.getItem(key);
                    const parsed = item ? JSON.parse(item) : null;
                    const ts = parsed && parsed.timestamp ? parsed.timestamp : 0;
                    entries.push({ key, timestamp: ts });
                } catch (_) {
                    // 数据损坏则视为最旧
                    entries.push({ key, timestamp: 0 });
                }
            }
        }
        return entries;
    }

    function purgeOldest(count) {
        const entries = listCacheEntries().sort((a, b) => a.timestamp - b.timestamp);
        let removed = 0;
        for (let i = 0; i < entries.length && removed < count; i++) {
            localStorage.removeItem(entries[i].key);
            removed++;
        }
        return removed;
    }

    function enforceMaxCacheItems() {
        const entries = listCacheEntries();
        if (entries.length > MAX_CACHE_ITEMS) {
            const toRemove = entries.length - MAX_CACHE_ITEMS;
            return purgeOldest(toRemove);
        }
        return 0;
    }

    // 清理过期缓存
    function cleanupExpiredCache() {
        const lastCleanup = localStorage.getItem('lrr-cache-last-cleanup');
        const currentTime = Date.now();

        // 如果距离上次清理超过7天，执行清理
        if (!lastCleanup || (currentTime - parseInt(lastCleanup, 10)) > CLEANUP_INTERVAL) {
            log('[LRR Checker] Starting cache cleanup...');
            let removedCount = 0;

            for (let i = 0; i < localStorage.length; i++) {
                const key = localStorage.key(i);
                if (key && key.startsWith('lrr-checker-')) {
                    try {
                        const item = localStorage.getItem(key);
                        if (item) {
                            const cacheData = JSON.parse(item);
                            if (currentTime - cacheData.timestamp > CACHE_DURATION) {
                                localStorage.removeItem(key);
                                removedCount++;
                                i--; // 因为删除后数组长度变化
                            }
                        }
                    } catch (e) {
                        error(`[LRR Checker] Error cleaning up cache key ${key}:`, e);
                    }
                }
            }

            localStorage.setItem('lrr-cache-last-cleanup', currentTime.toString());
            log(`[LRR Checker] Cache cleanup completed. Removed ${removedCount} expired items.`);
        }
    }

    /** 排除本脚本已插入的标记，避免备用搜索正则匹配到 “(LRR ✔)” 等 */
    function getGalleryTitlePlain(titleElement) {
        const clone = titleElement.cloneNode(true);
        clone.querySelectorAll('.lrr-marker-span').forEach(function(el) { el.remove(); });
        return clone.textContent.replace(/\s+/g, ' ').trim();
    }

    function hasLrrMarker(titleElement) {
        return !!(titleElement && titleElement.querySelector('.lrr-marker-span'));
    }

    function prependLrrMarker(titleElement, text, classNames) {
        if (!titleElement || hasLrrMarker(titleElement)) return;
        const markerSpan = document.createElement('span');
        markerSpan.classList.add('lrr-marker-span');
        classNames.forEach(function(c) { markerSpan.classList.add(c); });
        markerSpan.textContent = text;
        titleElement.prepend(markerSpan);
    }

    function getAuthorizationHeaderValue(apiKey) {
        if (!apiKey) return '';

        // LANraragi 的 Bearer 令牌要求传 base64(api_key)，这里统一编码，
        // 避免把原始 key 直接发出去导致 401。
        return 'Bearer ' + btoa(apiKey);
    }

    function isUrlfinderHit(result) {
        if (!result) return false;
        if (result.success === 1 || result.success === true) return true;

        // urlfinder 的返回在不同版本/插件实现里可能没有可靠的 success 标志，
        // 但只要已经带回归档 ID，就应视为已命中，避免误掉到备用标题搜索。
        const data = result.data;
        return !!(
            data && (
                (typeof data.id === 'string' && data.id) ||
                (typeof data.arcid === 'string' && data.arcid)
            )
        );
    }

    function delay(ms) {
        return new Promise(function(resolve) {
            setTimeout(resolve, ms);
        });
    }

    // 将GM_xmlhttpRequest包装为Promise（含超时与非 2xx）
    function makeRequest(options) {
        return new Promise(function(resolve, reject) {
            GM_xmlhttpRequest({
                method: options.method,
                url: options.url,
                headers: options.headers || {},
                timeout: options.timeout != null ? options.timeout : REQUEST_TIMEOUT_MS,
                onload: function(response) {
                    const ok = typeof options.validateStatus === 'function'
                        ? options.validateStatus(response.status)
                        : (response.status >= 200 && response.status < 300);
                    if (!ok) {
                        reject(new Error('HTTP ' + response.status + ' ' + (response.statusText || '')));
                        return;
                    }
                    resolve(response);
                },
                onerror: function(err) {
                    reject(err || new Error('Network error'));
                },
                ontimeout: function() {
                    reject(new Error('Request timeout'));
                },
                onabort: function() {
                    reject(new Error('Request aborted'));
                }
            });
        });
    }

    // 限制并发请求数量的函数
    async function processInBatches(items, processFn, batchSize) {
        const results = [];
        for (let i = 0; i < items.length; i += batchSize) {
            const batch = items.slice(i, i + batchSize);
            const batchPromises = batch.map(processFn);
            const batchResults = await Promise.all(batchPromises);
            results.push.apply(results, batchResults);
        }
        return results;
    }

    async function processGallery(gallery) {
        const galleryUrl = gallery.galleryUrl;
        const titleElement = gallery.titleElement;
        const cacheKey = gallery.cacheKey;
        const apiUrl = LRR_SERVER_URL + '/api/plugins/use?plugin=urlfinder&arg=' + encodeURIComponent(galleryUrl);
        const headers = {};
        if (LRR_API_KEY) {
            headers['Authorization'] = getAuthorizationHeaderValue(LRR_API_KEY);
        }

        try {
            const response = await makeRequest({
                method: 'POST',
                url: apiUrl,
                headers: headers
            });

            try {
                const result = JSON.parse(response.responseText);
                setCache(cacheKey, result);
                handleResponse(result, titleElement, galleryUrl);
                return { success: true, galleryUrl: galleryUrl };
            } catch (e) {
                error('[LRR Checker] Error parsing JSON for ' + galleryUrl + ':', e, response.responseText);
                prependLrrMarker(titleElement, '(LRR ❓)', ['lrr-marker-error']);
                return { success: false, galleryUrl: galleryUrl, error: e };
            }
        } catch (error) {
            error('[LRR Checker] Network error checking ' + galleryUrl + ':', error);
            prependLrrMarker(titleElement, '(LRR ❓)', ['lrr-marker-error']);
            return { success: false, galleryUrl: galleryUrl, error: error };
        }
    }

    /**
     * 仅发起 HTTP：返回是否命中，并写入 lrr-checker-alt-* 缓存（与 performAlternativeSearch 分离便于合并请求）
     * https://sugoi.gitbook.io/lanraragi/api-documentation/search-api
     */
    async function fetchAltSearchHttp(searchQuery, altKey) {
        const params = new URLSearchParams();
        params.set('filter', searchQuery);
        params.set('start', '0');
        params.set('groupby_tanks', 'false');
        const searchUrl = LRR_SERVER_URL + '/api/search?' + params.toString();

        const headers = {};
        if (LRR_API_KEY) {
            headers['Authorization'] = getAuthorizationHeaderValue(LRR_API_KEY);
        }

        let response = await makeRequest({
            method: 'GET',
            url: searchUrl,
            headers: headers,
            timeout: SEARCH_REQUEST_TIMEOUT_MS,
            validateStatus: function(status) {
                return (status >= 200 && status < 300) || status === 204;
            }
        });

        if (response.status === 204) {
            warn('[LRR Checker] GET /api/search returned 204 (search engine not ready), retrying in 2s...');
            await delay(2000);
            response = await makeRequest({
                method: 'GET',
                url: searchUrl,
                headers: headers,
                timeout: SEARCH_REQUEST_TIMEOUT_MS,
                validateStatus: function(status) {
                    return (status >= 200 && status < 300) || status === 204;
                }
            });
        }

        if (response.status === 204) {
            warn('[LRR Checker] GET /api/search still 204 after retry.');
            setCache(altKey, { altHit: false });
            return false;
        }

        const body = (response.responseText || '').trim();
        if (!body) {
            setCache(altKey, { altHit: false });
            return false;
        }

        var searchResult;
        try {
            searchResult = JSON.parse(body);
        } catch (e) {
            error('[LRR Checker] Error parsing JSON for /api/search:', e, response.responseText);
            throw e;
        }

        var hasHits =
            (typeof searchResult.recordsFiltered === 'number' && searchResult.recordsFiltered > 0) ||
            (searchResult.data && searchResult.data.length > 0);

        setCache(altKey, { altHit: hasHits });
        if (hasHits) {
            log('[LRR Checker] Found via GET /api/search: ' + searchQuery);
        } else {
            log('[LRR Checker] No hits from /api/search: ' + searchQuery);
        }
        return hasHits;
    }

    /**
     * 备用：GET /api/search；本地缓存 + 同页相同 filter 合并 + 并发池限流
     */
    async function performAlternativeSearch(searchQuery, titleElement) {
        if (hasLrrMarker(titleElement)) {
            return { success: false, searchQuery: searchQuery, skipped: true };
        }

        const altKey = 'lrr-checker-alt-' + simpleHash(searchQuery);
        const cached = getCache(altKey);
        if (cached && typeof cached.altHit === 'boolean') {
            if (cached.altHit) {
                prependLrrMarker(titleElement, '(LRR！)', ['lrr-marker-file']);
            }
            return { success: cached.altHit, searchQuery: searchQuery, cached: true };
        }

        if (!altSearchInflight.has(searchQuery)) {
            var p = runAltSearchLimited(function() {
                return fetchAltSearchHttp(searchQuery, altKey);
            });
            altSearchInflight.set(searchQuery, p);
            p.catch(function() {}).finally(function() {
                altSearchInflight.delete(searchQuery);
            });
        }
        var inflight = altSearchInflight.get(searchQuery);

        try {
            var hit = await inflight;
            if (hit && !hasLrrMarker(titleElement)) {
                prependLrrMarker(titleElement, '(LRR！)', ['lrr-marker-file']);
            }
            return { success: hit, searchQuery: searchQuery };
        } catch (error) {
            error('[LRR Checker] Network error during /api/search:', error);
            return { success: false, searchQuery: searchQuery, error: error };
        }
    }

    function handleResponse(result, titleElement, galleryUrl) {
        if (hasLrrMarker(titleElement)) return;

        if (isUrlfinderHit(result)) {
            log('[LRR Checker] Found: ' + galleryUrl + ' (ID: ' + (result.data && result.data.id) + ')');
            prependLrrMarker(titleElement, '(LRR ✔)', ['lrr-marker-downloaded']);
            return;
        }

        log('[LRR Checker] Not found or error: ' + galleryUrl + ' - ' + ((result && result.error) || ('success=' + (result && result.success))));
        if (!ENABLE_ALT_SEARCH) {
            return;
        }
        const fullTitle = getGalleryTitlePlain(titleElement);
        const authorRegex = /\[((?!汉化|漢化|DL版|中国翻訳)[^\]]+)\]/;
        const authorMatch = fullTitle.match(authorRegex);
        const author = authorMatch ? authorMatch[1] : null;
        if (!author) {
            log('[LRR Checker] Skipping alternative search (no author tag): ' + fullTitle);
            return;
        }

        const titleRegex = /\]([^\[\]\(\)]+)/;
        const titleMatch = fullTitle.match(titleRegex);
        const title = titleMatch ? titleMatch[1].trim() : null;

        if (author === title || title === null || title === '') {
            log('[LRR Checker] Skipping alternative search (no distinct title): ' + fullTitle);
            return;
        }

        const searchQuery = author + ',' + title;
        log('[LRR Checker] Trying alternative search with: ' + searchQuery);

        performAlternativeSearch(searchQuery, titleElement);
    }

    const galleriesToCheck = [];

    function collectGalleriesFromDom() {
        const galleryLinks = document.querySelectorAll('.itg .gl1t a[href*="/g/"]');
        galleryLinks.forEach(function(linkElement) {
            const galleryUrl = linkElement.href;
            const titleElement = linkElement.querySelector('.glink');

            if (!galleryUrl || !titleElement) {
                return;
            }

            if (seenGalleryUrls.has(galleryUrl)) {
                return;
            }
            seenGalleryUrls.add(galleryUrl);

            if (hasLrrMarker(titleElement)) {
                return;
            }

            const cacheKey = 'lrr-checker-' + galleryUrl;
            const cachedData = getCache(cacheKey);

            if (cachedData) {
                log('[LRR Checker] Using cached data for: ' + galleryUrl);
                handleResponse(cachedData, titleElement, galleryUrl);
                return;
            }

            galleriesToCheck.push({
                galleryUrl: galleryUrl,
                titleElement: titleElement,
                cacheKey: cacheKey
            });
        });
    }

    function flushPendingRequests() {
        const batch = galleriesToCheck.splice(0, galleriesToCheck.length);
        if (batch.length === 0) return;
        log('[LRR Checker] Processing ' + batch.length + ' galleries in parallel batches');
        processInBatches(batch, processGallery, MAX_CONCURRENT_REQUESTS)
            .then(function(results) {
                log('[LRR Checker] Completed batch. Success: ' + results.filter(function(r) { return r.success; }).length + ', Failed: ' + results.filter(function(r) { return !r.success; }).length);
            })
            .catch(function(error) {
                error('[LRR Checker] Error in batch processing:', error);
            });
    }

    cleanupExpiredCache();
    collectGalleriesFromDom();
    flushPendingRequests();

    let mutationTimer = null;
    const galleryTable = document.querySelector('.itg');
    if (galleryTable && typeof MutationObserver !== 'undefined') {
        const observer = new MutationObserver(function() {
            if (mutationTimer) clearTimeout(mutationTimer);
            mutationTimer = setTimeout(function() {
                mutationTimer = null;
                collectGalleriesFromDom();
                flushPendingRequests();
            }, MUTATION_DEBOUNCE_MS);
        });
        observer.observe(galleryTable, { childList: true, subtree: true });
    }
})();
