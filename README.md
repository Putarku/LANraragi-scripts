# LANraragi-scripts
自用LANraragi相关脚本

## e站浏览标识器
- 脚本功能：在e站的搜索浏览页面上添加标识，标识出该画廊是否在LANraragi中存在
- 安装方法：将`ExHentai Lanraragi Checker.js`放入浏览器的用户脚本管理器中，配置`lanraragi的地址`和`API key`后启用该脚本
- 使用效果：
 其中绿色标记`LRR ✔`为存在且使用该画廊的元数据刮削，紫色标记`LRR！`为使用标题检索在LANraragi中存在，刮削源可能为同名的其他画廊。
![](图片1.png)

## 版权作者标记
- 脚本功能：在LANraragi中标记版权作者的所有画廊，由于没有确切的版权本数据来源，因此脚本会将存在版权作者的所有画廊均打上`其他:版权本`标记
- 使用前提：LANraragi的画廊元数据中包含`艺术家:xx`或`群组:xx`的标签
- 使用方法：将`ApplyCopyrightTags.py`和`search_keywords.txt`下载到同一位置，配置`lanraragi的地址`和`管理员密码`后使用`python ApplyCopyrightTags.py`启动。我个人测试约花费了10分钟左右的时间。
![](图片2.png)