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

        .lrr-marker-file {
            color: #356ddc; 
            background-color: #071226;/* 紫色 */
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
                        // 尝试使用另一个API接口获取内容
                        // 从标题中提取作者和标题信息
                        const fullTitle = titleElement.textContent.trim();
                        
                        

                        // 使用正则表达式提取第一个中括号中的内容作为作者，后面的内容作为标题
                        //const titleMatch = fullTitle.match(/\[(?:(?!.*\([^()]*\)).*|.*?\(([^()]+)\).*?)\]\s*([^\[\]\(\)]+)/i);
                        //if (titleMatch && titleMatch.length >= 3) {
                        //    author = titleMatch[1].trim();
                        //    title = titleMatch[2].trim();
                        //}
                        const authorRegex = /\[((?!汉化|漢化|DL版|中国翻訳)[^\]]+)\]/;
                        const authorMatch = fullTitle.match(authorRegex);
                        const author = authorMatch ? authorMatch[1] : null;
                        if (!author) {
                            console.log(`[LRR Checker] Skipping due to missing ${fullTitle}`);
                            return;
                        }

                        // 提取中括号后的内容
                        const titleRegex = /\]([^\[\]\(\)]+)/;
                        const titleMatch = fullTitle.match(titleRegex);
                        const title = titleMatch ? titleMatch[1] : null;

                        if (author === title || title === null) {
                            console.log(`[LRR Checker] Skipping due to missing ${fullTitle}`);
                            return;
                        }
                        // 拼接成{作者},{标题}格式
                        const searchQuery = `${author},${title}`;
                        console.log(`[LRR Checker] Trying alternative search with: ${searchQuery}`);

                        // 使用新的API接口
                        const randomSearchUrl = `${LRR_SERVER_URL}/api/search/random?filter=${encodeURIComponent(searchQuery)}`;

                        GM_xmlhttpRequest({
                            method: 'GET',
                            url: randomSearchUrl,
                            headers: headers,
                            onload: function(randomResponse) {
                                try {
                                    const randomResult = JSON.parse(randomResponse.responseText);

                                    // 检查是否有返回结果
                                    if (randomResult && randomResult.data && randomResult.data.length > 0) {
                                        console.log(`[LRR Checker] Found via alternative search: ${searchQuery}`);

                                        // 创建标记并添加到标题前面
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