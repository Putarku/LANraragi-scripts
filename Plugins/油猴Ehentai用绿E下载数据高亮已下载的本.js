// ==UserScript==
// @name         EH高亮已下载的本
// @namespace    http://tampermonkey.net/
// @version      0.5
// @description  仅在匹配本地数据时高亮行并输出日志
// @author       You
// @match        https://exhentai.org/*
// @require      https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.6.2/sql-wasm.js
// @grant        GM_getValue
// @grant        GM_setValue
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    // 创建文件上传按钮
    const uploadBtn = document.createElement('input');
    uploadBtn.type = 'file';
    uploadBtn.style.position = 'fixed';
    uploadBtn.style.top = '5px'; // 距离顶部的距离
    uploadBtn.style.width = '120px';
    uploadBtn.style.right = '10px'; // 距离右侧的距离
    uploadBtn.style.zIndex = '1000';
    uploadBtn.title = '上传绿E导出的db文件';
    document.body.appendChild(uploadBtn);

    // 创建清空数据按钮
    const clearBtn = document.createElement('button');
    clearBtn.textContent = '清空缓存数据';
    clearBtn.style.position = 'fixed';
    clearBtn.style.top = '36px'; // 距离顶部的距离
    clearBtn.style.width = '124px';
    clearBtn.style.right = '10px'; // 距离右侧的距离
    clearBtn.style.zIndex = '1000';
    clearBtn.title = '清空缓存中的所有数据';
    document.body.appendChild(clearBtn);


    // 监听文件上传事件，从绿E导出的db文件中提取已下载的GID列表
    uploadBtn.addEventListener('change', async function(event) {
        const file = event.target.files[0];
        if (!file) return;

        // 初始化 SQL.js 模块
        initSqlJs({ locateFile: file => `https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.6.2/${file}` })
            .then(SQL => {
                const reader = new FileReader();
                reader.onload = function(e) {
                    // 使用 sql.js 处理 SQLite 数据库
                    try {
                        // 创建一个 Uint8Array 并加载数据库
                        const uInt8Array = new Uint8Array(e.target.result);
                        const db = new SQL.Database(uInt8Array);

                        // 查询 DOWNLOADS 表的 GID 字段
                        const stmt = db.prepare("SELECT GID FROM DOWNLOADS");
                        const gidArray = [];
                        while (stmt.step()) {
                            const row = stmt.get();
                            gidArray.push(row[0]); // GID 是第一列
                        }
                        stmt.free();

                        // 将数据存储到油猴缓存
                        GM_setValue('localData', gidArray);
                        console.log('已将数据存储到缓存:', GM_getValue('localData'));

                        // 提示用户上传成功
                        alert('数据已成功上传并存储到缓存中！');
                    } catch (error) {
                        console.error('处理数据库文件时出错:', error);
                        alert('数据库文件处理失败，请检查文件格式！');
                    }
                };

                // 读取文件内容
                reader.readAsArrayBuffer(file); // 读取为 ArrayBuffer
            })
            .catch(error => {
                console.error('SQL.js 模块加载失败:', error);
            });
    });

    // 监听清空缓存数据按钮事件
    clearBtn.addEventListener('click', function() {
        GM_setValue('localData', []);
        console.log('缓存数据已清空');
        alert('缓存数据已清空！');
    });

    // 设置表格行背景色
    setTimeout(() => {
        // 读取存储在缓存中的localData数组
        const localData = GM_getValue('localData', []);
        console.log('加载的本地数据');

        // 检查localData是否已加载
        if (localData.length === 0) {
            console.warn('没有找到本地数据，请确保缓存正确设置或上传数据。');
            return; // 如果没有本地数据，直接退出
        }

        // 选择所有符合条件的<tr>元素
        const rows = document.querySelectorAll('table.itg.glte tr');

        rows.forEach((row, index) => {
            // 获取<tr>元素中的链接
            const link = row.querySelector('a[href^="https://exhentai.org/g/"]');
            if (link) {
                const url = link.href;

                // 从URL中提取数字
                const match = url.match(/g\/(\d+)\//);
                if (match) {
                    const number = match[1];

                    // 检查localData数组是否包含这个数字，并设置背景色
                    if (localData.includes(Number(number))) {
                        row.style.backgroundColor = 'blue';
                        console.log(`第 ${index + 1} 行: 数字 ${number} 在本地数据中，背景已设置为蓝色`);
                    }
                }
            }
        });
    }, 1000);
})();
