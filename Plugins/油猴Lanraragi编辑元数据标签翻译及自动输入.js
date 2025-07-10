// ==UserScript==
// @name         Lanraragi标签翻译及自动输入脚本
// @namespace    http://tampermonkey.net/
// @version      3.2
// @description  自动翻译标签并替换为中文，支持缓存 JSON 文件，提供手动触发翻译按钮，插入新标签并删除已翻译标签，支持输入字符串自动生成标签
// @author       You
// @match        http://192.168.1.110:3333/edit*
// @match        https://192.168.1.110:3333/edit*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_xmlhttpRequest
// ==/UserScript==

(function() {
    'use strict';

    const dbUrl = 'https://raw.githubusercontent.com/EhTagTranslation/DatabaseReleases/c7032446e82b272943c46f2900461e7e49c001c7/db.text.json';
    const cacheKey = 'tagTranslationDB';
    const cacheDuration = 24 * 60 * 60 * 1000; // 1 day in milliseconds
    let translatedTags = []; // 记录翻译后的标签

    // 初始化翻译按钮及自动输入模块
    initTranslateButton();
    initAutoInputModule();

    // 初始化翻译按钮模块
    function initTranslateButton() {
        const targetElement = document.querySelector('tbody > tr:nth-child(4) > td:nth-child(1)');

        if (!targetElement) {
            console.error('未找到目标元素 tbody > tr:nth-child(4) > td:nth-child(1)');
            return;
        }

        targetElement.style.position = 'relative';

        const button = document.createElement('button');
        button.textContent = '翻译标签';
        styleButton(button);
        button.addEventListener('click', handleTranslateButtonClick);
        targetElement.appendChild(button);
    }

    // 翻译按钮点击事件
    function handleTranslateButtonClick(event) {
        event.preventDefault();

        const cachedData = GM_getValue(cacheKey, null);
        const cachedTime = GM_getValue(`${cacheKey}_time`, 0);
        const currentTime = new Date().getTime();

        if (cachedData && currentTime - cachedTime < cacheDuration) {
            console.log('使用缓存的翻译数据库');
            translateTags(cachedData);
        } else {
            console.log('获取远程翻译数据库');
            GM_xmlhttpRequest({
                method: 'GET',
                url: dbUrl,
                onload: function(response) {
                    const jsonData = JSON.parse(response.responseText);
                    GM_setValue(cacheKey, jsonData);
                    GM_setValue(`${cacheKey}_time`, currentTime);
                    translateTags(jsonData);
                },
                onerror: function() {
                    console.error('获取翻译数据库失败');
                }
            });
        }
    }

    // 样式按钮
    function styleButton(button) {
        button.style.position = 'absolute';
        button.style.bottom = '10px';
        button.style.left = '10px';
        button.style.padding = '10px';
        button.style.backgroundColor = '#007bff';
        button.style.color = '#fff';
        button.style.border = 'none';
        button.style.borderRadius = '5px';
        button.style.cursor = 'pointer';
        button.style.transition = 'background-color 0.3s ease';

        button.addEventListener('mouseover', function() {
            button.style.backgroundColor = '#0056b3';
        });

        button.addEventListener('mouseout', function() {
            button.style.backgroundColor = '#007bff';
        });
    }

    // 翻译标签并替换
    function translateTags(jsonData) {
        const target = jsonData['data'];
        const tags = document.querySelectorAll('.tagger ul li .label');
        const tagInput = document.querySelector('.tagger-new input');

        translatedTags = [];
        let matchTags = []; // 用于保存无命名空间标签的翻译结果

        tags.forEach(label => {
            let tagText = label.textContent;
            tagText = tagText.replace(/category:/, 'reclass:');
            tagText = tagText.replace(/Chinese/, 'chinese');
            tagText = tagText.replace(/tag:/, '');
            const parts = tagText.split(':');

            // 处理有命名空间的标签
            if (parts.length === 2) {
                let [namespace, key] = parts;
                for (const element of target) {
                    const namespaceAliases = [element.frontMatters.key].concat(element.frontMatters.aliases || []);
                    if (namespaceAliases.includes(namespace)) {
                        let translatedTag = tagText.replace(namespace, element.frontMatters.name);
                        if (element.data[key]) {
                            translatedTag = translatedTag.replace(key, element.data[key].name);
                        }
                        translatedTags.push(label); // 标记为已翻译
                        addTagToInput(translatedTag, tagInput); // 添加翻译后的标签到输入框
                        break; // 找到后结束循环
                    }
                }
            } else {
                // 处理无命名空间的标签
                const key = parts[0];
                for (const element of target) {
                    if (element.data[key]) {
                        translatedTags.push(label); // 标记为已翻译
                        addTagToInput(element.data[key].name, tagInput); // 添加翻译后的标签到输入框
                        break; // 找到后结束循环
                    }
                }
            }
        });

        removeTranslatedTags(); //删除已翻译的标签
    }

    // 添加标签到输入框并模拟逗号事件
    function addTagToInput(tag, tagInput) {
        tagInput.value = tag;
        const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, keyCode: 188 });
        tagInput.dispatchEvent(event);
    }

    // 删除已翻译标签
    function removeTranslatedTags() {
        console.log(translatedTags);
        translatedTags.forEach(label => {
            console.log(label);
            const closeButton = label.parentElement.querySelector('.close');
            if (closeButton) {
                const event = new Event('click', { bubbles: true, cancelable: true });
                closeButton.dispatchEvent(event);
            }
        });
    }

    // 初始化自动输入模块
    function initAutoInputModule() {
        const targetRow = document.querySelector('tbody > tr:nth-child(3)');

        if (targetRow) {
            const newRow = document.createElement('tr');
            const cell1 = document.createElement('td');
            const cell2 = document.createElement('td');
            const button = document.createElement('button');
            button.textContent = '字符串转标签';
            cell1.appendChild(button);
            const newInput = document.createElement('input');
            newInput.className = 'stdinput edit-mode-stdinput';
            newInput.type = 'text';
            newInput.maxLength = 255;
            newInput.size = 20;
            newInput.placeholder = '格式: "A:a, B:b, C:c"，用逗号隔开';
            cell2.appendChild(newInput);
            newRow.appendChild(cell1);
            newRow.appendChild(cell2);
            targetRow.parentNode.insertBefore(newRow, targetRow.nextSibling);

            button.addEventListener('click', function(event) {
                event.preventDefault();
                handleAutoInput(newInput);
            });
        } else {
            console.log('未找到目标行。');
        }
    }

    // 自动输入标签功能
    function handleAutoInput(newInput) {
        const value = newInput.value.trim();
        if (!value) {
            alert('输入框不能为空。');
            return;
        }

        const tagInput = document.querySelector('.tagger-new input');
        const tags = value.split(',').map(tag => tag.trim());
        tags.forEach(tag => {
            tagInput.value = tag;
            const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, keyCode: 188 });
            tagInput.dispatchEvent(event);
        });

        newInput.value = '';
    }

})();
