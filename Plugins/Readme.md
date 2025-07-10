#使用方法：在插件配置页面点击上传插件选择插件即可
注意！上传pm插件时候一定要把文件名改成插件第一行的名字，否则会失败。

ComicLooms.pm：https://github.com/MapoMagpie/eh-view-enhance下载器处理脚本
    特点：提取档案中的meta.json的标签，已针对禁漫，nhentai下载的本子优化，可选汉化
    
EHentai.pm：E站搜索插件
    修改1：修正汉化版的参数顺序，跟随官方配置
    修改2：其中利用GID搜索修改为匹配Ehviewer下载以数字开头横杠结束的GID格式的文件，例如123-(C100)ABC.zip
    修改3：文件名搜索，会过滤掉上一步匹配到的GID，如123-(C100)ABC.zip最终会用(C100)ABC来搜索
    
EHentai_CN.pm：修改自EHentai.pm的刮削中文标签插件
    修改：新增translate_tag_to_cn函数，从插件配置中的翻译json文件，在插件返回标签前将其转换为中文
    
Ehviewer_Color.pm
    特点：从彩E下载的cbz包中的ComicInfo.xml解析元数据，可选翻译
    
Ehviewer_Green.pm
    特点：从绿E下载文件中.ehviewer解析GID和Gtoken组合出源链接刮削元数据，可选翻译
    
ETagConverter.pm：数据库英文标签翻译脚本
    注意：这个是对全部数据进行替换，务必备份好数据库
    
Eze_CN.pm：修改自Eze.pm
    修改：兼容nhentai下载脚本内嵌的info.json获取标签数据，可以翻译成中文
    
HentagOnline_CN.pm：Hentag网站标签搜索插件，返回中文标签
    修改：新增translate_tag_to_cn函数，从插件配置中的翻译json文件，在插件返回标签前将其转换为中文
    
Hitomi_CN.pm：修改自Hitomi.pm
    修改：新增translate_tag_to_cn函数，从插件配置中的翻译json文件，在插件返回标签前将其转换为中文
    
nHentai_CN.pm：N站刮削中文标签脚本
    修改：新增translate_tag_to_cn函数，从插件配置中的翻译json文件，在插件返回标签前将其转换为中文

addEhentaiMetadata.pm：对未刮削画廊触发一次ehentai刮削插件

addEtagCNMetadata.pm：对未刮削画廊触发一次EtagCN刮削插件

addhentag.pm：对未刮削画廊触发一次Hentag Online Lookups刮削插件

油猴Ehentai进入详情页自动打开收藏选择.js：顾名思义
油猴Ehentai用绿E下载数据高亮已下载的本.js：在EH右上角添加绿E数据库导入框，用来高亮已下载的本
油猴Lanraragi编辑元数据标签翻译及自动输入.js：用于在Lanraragi单独编辑元数据时候，对标签进行翻译，还有支持把一整串标签直接导入
