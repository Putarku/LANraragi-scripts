import requests
import json

# Lanraragi API 的基本 URL
BASE_URL = "http://localhost:3000"  # 替换为你的 Lanraragi 实例的地址

ADMIN_PASSWORD = ""  # 替换为你的管理员密码

# 要添加的标签
TAG_TO_ADD = "其他:版权本"  # 替换为你要添加的标签
# 用于存储cookies的变量
SESSION_COOKIES = None

def login(password):

    global SESSION_COOKIES # 声明全局变量

    login_url = f"{BASE_URL}/login"
    data = {"password": password}

    try:
        response = requests.post(login_url, data=data)
        response.raise_for_status()

        # 提取 cookies
        SESSION_COOKIES = response.cookies.get_dict()
        print(f"登录成功，获取到 cookies: {SESSION_COOKIES}")
        return SESSION_COOKIES
    except requests.exceptions.RequestException as e:
        print(f"登录失败: {e}")
        return None

def search_gallery(keyword):
    """
    使用关键词搜索画廊。

    Args:
        keyword (str): 搜索关键词.

    Returns:
        list: 画廊 ID 的列表. 如果发生错误，返回 None.
    """
    url = f"{BASE_URL}/api/search?filter={keyword}"  # 使用 GET 请求和 filter 参数
    headers = {}

    try:
        response = requests.get(url, headers=headers, cookies=SESSION_COOKIES)  # 使用 GET 请求，并传递 cookies
        response.raise_for_status()  # 检查 HTTP 错误

        search_result = response.json()  

        if not search_result["data"]:
            print("未找到相关结果")
            return None

        results = search_result["data"] # 从 'data' 字段中提取结果
        gallery_ids = [item["arcid"] for item in results] # 提取 arcid 而不是 id
        return gallery_ids

    except requests.exceptions.RequestException as e:
        print(f"搜索请求错误: {e}")
        return None
    except json.JSONDecodeError as e:
        print(f"JSON 解析错误: {e}")
        return None


def add_tag_to_gallery(gallery_id, tag_to_add):
    """
    向画廊添加标签。
    Args:
        gallery_id (str): 画廊的 ID (arcid).
        tag_to_add (str): 要添加的标签.
    """
    global SESSION_COOKIES # 声明全局变量
    # 1. 获取档案元数据
    get_metadata_url = f"{BASE_URL}/api/archives/{gallery_id}/metadata"
    try:
        response = requests.get(get_metadata_url, cookies=SESSION_COOKIES) # 使用 cookies 进行身份验证
        response.raise_for_status()
        metadata = response.json()
        existing_tags = metadata.get("tags", "")  # 获取现有的 tags 字符串, 如果没有则默认为空字符串
    except requests.exceptions.RequestException as e:
        print(f"获取画廊 {gallery_id} 元数据时出错: {e}")
        return
    # 2. 检查是否已经存在该标签
    if tag_to_add in existing_tags:
        print(f"画廊 {gallery_id} 已经包含标签 '{tag_to_add}'，跳过添加步骤。")
        return
    # 3. 更新 tags 字段
    if existing_tags:
        updated_tags = f"{existing_tags},{tag_to_add}"  # 添加新标签
    else:
        updated_tags = tag_to_add #如果本身没有标签，那么直接添加
    # 4. 推送更新后的元数据
    put_metadata_url = f"{BASE_URL}/api/archives/{gallery_id}/metadata"  # PUT 请求的 URL
    data = {"tags": updated_tags}  # 仅更新 tags 字段
    try:
        response = requests.put(put_metadata_url, data=data, cookies=SESSION_COOKIES) # 使用 cookies 进行身份验证
        response.raise_for_status()
        print(f"成功更新画廊 {gallery_id} 的标签: {updated_tags}")
    except requests.exceptions.RequestException as e:
        print(f"更新画廊 {gallery_id} 标签时出错: {e}")

# 主程序
if __name__ == "__main__":
    # 1. 登录
    if not login(ADMIN_PASSWORD):
        print("登录失败，无法继续。")
    else:
        # 2. 从文件中读取搜索关键词
        try:
            with open("search_keywords.txt", "r", encoding="utf-8") as f:  # 确保使用正确的编码打开文件
                search_keywords = [line.strip() for line in f]  # 读取每一行并去除空白字符
        except FileNotFoundError:
            print("未找到 search_keywords.txt 文件。")
            exit()
        # 3. 遍历搜索关键词
        for SEARCH_KEYWORD in search_keywords:  # 使用循环遍历搜索词
            print(f"当前搜索关键词: {SEARCH_KEYWORD}")
            gallery_ids = search_gallery(SEARCH_KEYWORD)
            if gallery_ids:
                print(f"找到以下画廊: {gallery_ids}")
                # 4. 为每个画廊添加标签
                for gallery_id in gallery_ids:
                    add_tag_to_gallery(gallery_id, TAG_TO_ADD)
            else:
                print(f"未找到包含关键词 '{SEARCH_KEYWORD}' 的画廊。")