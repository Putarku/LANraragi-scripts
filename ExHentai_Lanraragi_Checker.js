// ==UserScript==
// @name        ExHentai Lanraragi Checker
// @namespace   https://github.com/Putarku
// @match       https://exhentai.org/*
// @match       https://e-hentai.org/*
// @grant       GM_xmlhttpRequest
// @grant       GM_addStyle
// @updateURL https://update.sleazyfork.org/scripts/538357/ExHentai%20Lanraragi%20Checker.user.js
// @downloadURL https://update.sleazyfork.org/scripts/538357/ExHentai%20Lanraragi%20Checker.user.js
// @version     1.3
// @author      Putarku
// @description Checks if galleries on ExHentai/E-Hentai are already in your Lanraragi library and marks them by inserting a span at the beginning of the title.
// ==/UserScript==

(function() {
    'use strict';

    // --- 用户配置开始 ---
    const LRR_SERVER_URL = 'http://localhost:3000'; // 替换为您的 Lanraragi 服务器地址
    const LRR_API_KEY = ''; // 如果您的 Lanraragi API 需要密钥，请填写
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
            color: #356ddc; 
            background-color: #071226;/* 紫色 */
        }

        .lrr-marker-error {
            color: #dc3545; /* 红色 */
            background-color: #fbe9ea;
        }
    `);

    const CACHE_DURATION = 3 * 24 * 60 * 60 * 1000; // 3 days in milliseconds

    function getCache(key) {
        const cached = localStorage.getItem(key);
        if (cached) {
            const { timestamp, data } = JSON.parse(cached);
            if (Date.now() - timestamp < CACHE_DURATION) {
                return data;
            }
        }
        return null;
    }

    function setCache(key, data) {
        const item = {
            timestamp: Date.now(),
            data: data
        };
        localStorage.setItem(key, JSON.stringify(item));
    }

    const galleryLinks = document.querySelectorAll('.itg .gl1t a[href*="/g/"]');

    galleryLinks.forEach(linkElement => {
        const galleryUrl = linkElement.href;
        const titleElement = linkElement.querySelector('.glink');

        if (!galleryUrl || !titleElement) {
            return;
        }

        if (titleElement.querySelector('.lrr-marker-span')) {
            return;
        }

        const cacheKey = `lrr-checker-${galleryUrl}`;
        const cachedData = getCache(cacheKey);

        if (cachedData) {
            console.log(`[LRR Checker] Using cached data for: ${galleryUrl}`);
            handleResponse(cachedData, titleElement, galleryUrl);
            return;
        }

        const apiUrl = `${LRR_SERVER_URL}/api/plugins/use?plugin=urlfinder&arg=${encodeURIComponent(galleryUrl)}`;
        const headers = {};
        if (LRR_API_KEY) {
            headers['Authorization'] = `Bearer ${LRR_API_KEY}`;
        }

        GM_xmlhttpRequest({
            method: 'POST',
            url: apiUrl,
            headers: headers,
            onload: function(response) {
                try {
                    const result = JSON.parse(response.responseText);
                    setCache(cacheKey, result);
                    handleResponse(result, titleElement, galleryUrl);
                } catch (e) {
                    console.error(`[LRR Checker] Error parsing JSON for ${galleryUrl}:`, e, response.responseText);
                    let markerSpan = document.createElement('span');
                    markerSpan.classList.add('lrr-marker-span', 'lrr-marker-error');
                    markerSpan.textContent = '(LRR ❓)';
                    if (titleElement) titleElement.prepend(markerSpan);
                }
            },
            onerror: function(error) {
                console.error(`[LRR Checker] Network error checking ${galleryUrl}:`, error);
                let markerSpan = document.createElement('span');
                markerSpan.classList.add('lrr-marker-span', 'lrr-marker-error');
                markerSpan.textContent = '(LRR ❓)';
                if (titleElement) titleElement.prepend(markerSpan);
            }
        });
    });

    function handleResponse(result, titleElement, galleryUrl) {
        let markerSpan = document.createElement('span');
        markerSpan.classList.add('lrr-marker-span');

        if (result.success === 1) {
            console.log(`[LRR Checker] Found: ${galleryUrl} (ID: ${result.data.id})`);
            markerSpan.textContent = '(LRR ✔)';
            markerSpan.classList.add('lrr-marker-downloaded');
            titleElement.prepend(markerSpan);
        } else {
            console.log(`[LRR Checker] Not found or error: ${galleryUrl} - ${result.error}`);
            const fullTitle = titleElement.textContent.trim();
            const authorRegex = /\[((?!汉化|漢化|DL版|中国翻訳)[^\]]+)\]/;
            const authorMatch = fullTitle.match(authorRegex);
            const author = authorMatch ? authorMatch[1] : null;
            if (!author) {
                console.log(`[LRR Checker] Skipping due to missing ${fullTitle}`);
                return;
            }

            const titleRegex = /\]([^\[\]\(\)]+)/;
            const titleMatch = fullTitle.match(titleRegex);
            const title = titleMatch ? titleMatch[1] : null;

            if (author === title || title === null) {
                console.log(`[LRR Checker] Skipping due to missing ${fullTitle}`);
                return;
            }

            const searchQuery = `${author},${title}`;
            console.log(`[LRR Checker] Trying alternative search with: ${searchQuery}`);

            const randomSearchUrl = `${LRR_SERVER_URL}/api/search/random?filter=${encodeURIComponent(searchQuery)}`;
            const headers = {};
            if (LRR_API_KEY) {
                headers['Authorization'] = `Bearer ${LRR_API_KEY}`;
            }

            GM_xmlhttpRequest({
                method: 'GET',
                url: randomSearchUrl,
                headers: headers,
                onload: function(randomResponse) {
                    try {
                        const randomResult = JSON.parse(randomResponse.responseText);
                        if (randomResult && randomResult.data && randomResult.data.length > 0) {
                            console.log(`[LRR Checker] Found via alternative search: ${searchQuery}`);
                            let altMarkerSpan = document.createElement('span');
                            altMarkerSpan.classList.add('lrr-marker-span');
                            altMarkerSpan.textContent = '(LRR！)';
                            altMarkerSpan.classList.add('lrr-marker-file');
                            titleElement.prepend(altMarkerSpan);
                        } else {
                            console.log(`[LRR Checker] Not found via alternative search: ${searchQuery}`);
                        }
                    } catch (e) {
                        console.error(`[LRR Checker] Error parsing JSON for alternative search:`, e, randomResponse.responseText);
                    }
                },
                onerror: function(error) {
                    console.error(`[LRR Checker] Network error during alternative search:`, error);
                }
            });
        }
    }
})();