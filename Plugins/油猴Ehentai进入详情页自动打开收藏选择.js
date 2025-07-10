// ==UserScript==
// @name         EH进入详情页自动打开收藏选择
// @namespace    http://tampermonkey.net/
// @version      0.4
// @description  自动点击特定的 id 为 "gdf" 且 onclick="return pop_fav()" 的元素，延迟2秒后运行
// @author       You
// @match        https://exhentai.org/g/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    console.log("脚本已加载，等待2秒...");

    // 延迟2秒后执行
    setTimeout(function() {
        console.log("2秒延迟结束，开始查找符合条件的元素...");

        // 查找所有 id 为 "gdf" 的元素
        var gdfElements = document.querySelectorAll('div#gdf');
        console.log("找到 " + gdfElements.length + " 个 id 为 'gdf' 的元素");

        // 遍历所有找到的元素
        gdfElements.forEach(function(element, index) {
            console.log("检查元素 " + (index + 1) + " 是否具有 onclick='return pop_fav()'");

            // 检查是否具有特定的 onclick 属性
            if (element.getAttribute('onclick') === 'return pop_fav()') {
                console.log("元素 " + (index + 1) + " 匹配成功，准备触发点击事件");

                // 触发点击事件
                element.click();

                // 调用 pop_fav() 函数
                console.log("调用 pop_fav() 函数");
            } else {
                console.log("元素 " + (index + 1) + " 不符合条件，跳过");
            }
        });
    }, 1000); // 延迟2秒后执行代码

})();
