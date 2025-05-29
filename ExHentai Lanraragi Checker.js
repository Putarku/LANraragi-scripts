// ==UserScript==
// @name        ExHentai Lanraragi Checker
// @namespace   https://github.com/Putarku
// @match       https://exhentai.org/*
// @match       https://e-hentai.org/*
// @grant       GM_xmlhttpRequest
// @grant       GM_addStyle
// @updateURL    https://github.com/Putarku/LANraragi-scripts/refs/heads/main/ExHentai Lanraragi Checker.js
// @downloadURL  https://github.com/Putarku/LANraragi-scripts/refs/heads/main/ExHentai Lanraragi Checker.js
// @version     1.2
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

        .lrr-marker-error {
            color: #dc3545; /* 红色 */
            background-color: #fbe9ea;
        }
    `);

    const galleryLinks = document.querySelectorAll('.itg .gl1t a[href*="/g/"]');

    galleryLinks.forEach(linkElement => {
        const galleryUrl = linkElement.href;
        const titleElement = linkElement.querySelector('.glink'); // 这是 visied.js 添加 ::before 的元素

        if (!galleryUrl || !titleElement) {
            return;
        }

        // 防止重复添加标记
        if (titleElement.querySelector('.lrr-marker-span')) {
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
                    let markerSpan = document.createElement('span');
                    markerSpan.classList.add('lrr-marker-span');

                    if (result.success === 1) {
                        console.log(`[LRR Checker] Found: ${galleryUrl} (ID: ${result.data.id})`);
                        markerSpan.textContent = '(LRR ✔)';
                        markerSpan.classList.add('lrr-marker-downloaded');
                        titleElement.prepend(markerSpan); // 将 span 插入到 .glink 内部的最前面
                    } else {
                        console.log(`[LRR Checker] Not found or error: ${galleryUrl} - ${result.error}`);
                        // 如果需要在未找到或API出错时也显示标记，可以在这里添加
                        // markerSpan.textContent = '(LRR ?)';
                        // markerSpan.classList.add('lrr-marker-error');
                        // titleElement.prepend(markerSpan);
                    }
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

})();