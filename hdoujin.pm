package LANraragi::Plugin::Metadata::hdoujin;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(html_unescape);
use Mojo::UserAgent;
use utf8; # 这一行是重复的，已在前面声明过，故移除
#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name       => "hdoujin",
        type       => "metadata",
        namespace  => "hdoujin",
        login_from => "",
        author     => "Paturku",
        version    => "1.3.0",
        description =>
                "从 hdoujin.org 获取元数据，并提取namespace为8和9的标签（自动添加female:和male:前缀）。支持URL格式：hdoujin.org/g/{id}/{key}。",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAABP0lEQVR4nO2UMUvDQBTH/3dJLLQFoYOLk4uLs5ODH0AQnBwcHJwcHPwAIjg5ODg4ODg4iKODg4M4Ojg4iKOgIEWkpZe8c0itqQYaW3Dw4A2Pd7/7/d+7907wjyGAOwCvAKKsXgDcAigA8Fwwxh0MBpVut7vXbrdPAZQBbAJIAHwCeAdwZIzZXwpGUVTpdDr7nU7nDMCGiGwZY7aMMbUwDPestRcANqWU1Ov1k4VgGIYH3W73HEBZRLbTNG2EYVhL07QRx/FRkiQXAMpRFB3OBb1SqVTr9XoHgA9gO0mSRhAEtSRJGmEY1qy1FwDKALZqtdrxTDCO4+MgCPZFZCdJkkYQBDVrbX0MjsF6vX46BcZxfDwGd5MkaQRBULPWnmeQMeZwJhiG4eEYrFtrz7KKJ+AXgMpS8Df4BvUdKYlU/Pc2AAAAAElFTkSuQmCC",
          
        parameters => [
            { type => "string", desc => "搜索语言（默认为12，表示中文）" },
            { type => "bool",   desc => "使用标题的 ID 进行搜索（仅匹配数字开头-结尾的标题，例如：134-(C100)ABC.zip，如果失败，则回退到标题）" },
            { type => "string", desc => "API认证令牌（必填，格式为UUID，例如：73d2333b-ddc1-4953-9a37-2e130dd87ea6）" },
            { type => "bool",   desc => "启用中文标签翻译" },
            { type => "string", desc => "中文翻译数据库路径（JSON文件，仅在启用中文标签翻译时需要）" },
        ],

        oneshot_arg => "该漫画在hdoujin.org的URL(支持格式：hdoujin.org/g/{id}/{key} 或 hdoujin.org/books/detail/{id}/{key})",
        cooldown    => 4
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                                # Global info hash
    my $ua       = $lrr_info->{user_agent};
    my ( $lang, $search_id, $api_token, $enable_cn_translation, $cn_db_path ) = @_;          # Plugin parameters

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    # 检查API令牌是否提供
    if (!$api_token) {
        return ( error => "请提供API认证令牌！在插件设置中填写正确的令牌。" );
    }

    # 设置API认证头部
    $ua->on(start => sub {
        my ($ua, $tx) = @_;
        $tx->req->headers->header('authorization' => "Bearer $api_token");
    });

    # Work your magic here - You can create subroutines below to organize the code better
    my $id    = "";
    my $key   = "";
    my $hasSrc = 0;

    # 设置默认语言为中文(12)
    $lang = 12 if $lang eq "";

    # Quick regex to get the hdoujin archive ids from the provided url or source tag
    $logger->debug("oneshot_param: " . $lrr_info->{oneshot_param});
    if ( $lrr_info->{oneshot_param} =~ /.*\/(?:books\/detail|g)\/([0-9]*)\/([a-z0-9]*)(?:\/|\$|$)/ ) {
        $id  = $1;
        $key = $2;
        $logger->debug("Skipping search and using gallery $id / $key from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*hdoujin\.org\/(?:books\/detail|g)\/([0-9]*)\/([a-z0-9]*)\/?.*/gi ) {
        $id  = $1;
        $key = $2;
        $hasSrc = 1;
        $logger->debug("Skipping search and using gallery $id / $key from source tag");
    } else {
        # 如果没有直接提供ID和key，则进行搜索
        ( $id, $key ) = &lookup_gallery(
            $lrr_info->{archive_title},
            $ua, $lang, $search_id
        );
    }

    # If an error occured, return a hash containing an error message.
    if ( $id eq "" || $key eq "" ) {
        $logger->info("未找到匹配的 HDOujin 画廊！");
        return ( error => "未找到匹配的 HDOujin 画廊！" );
    } else {
        $logger->debug("HDOujin 画廊ID: $id / $key");
    }

    my ( $tags, $title ) = &get_tags_from_hdoujin( $ua, $id, $key, $enable_cn_translation, $cn_db_path );
    my %hashdata = ( tags => $tags );

    # Add source URL and title if possible/applicable
    if ( $hashdata{tags} ne "" ) {
        if ( !$hasSrc ) { $hashdata{tags} .= ", source:hdoujin.org/g/$id/$key"; }
        $hashdata{title} = $title if $title ne "";
    }
    
    # 把数据交给LRR
    $logger->info( "返回LRR的tags: " . $hashdata{tags} );
    return %hashdata;
}

######
## HDOujin Specific Methods
######

sub lookup_gallery {

    my ( $title, $ua, $lang, $search_id ) = @_;
    my $logger = get_plugin_logger();
    
    # 从标题获取ID，并把搜索标题过滤ID
    my ($title_id, $title_search) = $title =~ /^(\d+)-(.+)/;
    # 匹配到ID，标题改为去除ID的部分
    $title = $title_search if defined $title_id;

    # 使用ID进行搜索
    if ( $search_id && $title_id ) {
        $logger->debug("找到 ID：$title_id，使用ID进行搜索");
        
        my $search_url = "https://api.hdoujin.org/books?s=$title_id&lang=$lang";
        my ( $id, $key ) = &hdoujin_parse( $search_url, $ua );

        if ( $id ne "" && $key ne "" ) {
            return ( $id, $key );
        }
    }

    # 使用标题进行搜索
    # 清理标题中的特殊字符，如方括号等
    # 这些特殊字符可能导致API请求失败（返回400错误）
    # 例如：[作者名]标题 -> 作者名 标题
    #$title =~ s/[\[\]\(\)\{\}]/ /g;  # 将括号替换为空格
    $title =~ s/\[[^\[\]]*\]|\([^\(\)]*\)|\{[^\{\}]*\}//g;
    $title =~ s/\s+/ /g;                # 将多个空格合并为一个
    $title =~ s/^\s+|\s+$//g;          # 去除首尾空格
    
    my $encoded_title = uri_escape_utf8($title);
    my $search_url = "https://api.hdoujin.org/books?s=$encoded_title&lang=$lang";
    
    $logger->debug("清理后的标题: $title");
    $logger->debug("使用 URL $search_url（存档标题）");
    return &hdoujin_parse( $search_url, $ua );
}

# hdoujin_parse(URL, UA)
# 执行hdoujin.org的搜索，并返回匹配的ID/key
sub hdoujin_parse {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    $logger->debug("发送请求到: $url");
    
    # 设置必要的请求头
    my $tx = $ua->build_tx(GET => $url);
    $tx->req->headers->header('Accept' => '*/*');
    $tx->req->headers->header('User-Agent' => 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.95 Mobile Safari/537.36');
    $tx->req->headers->header('Referer' => 'https://hdoujin.org/');
    $tx->req->headers->header('authority' => 'api.hdoujin.org');
    $tx->req->headers->header('accept-language' => 'zh-CN,zh;q=0.9');
    $tx->req->headers->header('cache-control' => 'no-cache');
    $tx->req->headers->header('dnt' => '1');
    $tx->req->headers->header('origin' => 'https://hdoujin.org');
    $tx->req->headers->header('pragma' => 'no-cache');
    $tx->req->headers->header('sec-ch-ua' => '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"');
    $tx->req->headers->header('sec-ch-ua-mobile' => '?1');
    $tx->req->headers->header('sec-ch-ua-platform' => '"Android"');
    $tx->req->headers->header('sec-fetch-dest' => 'empty');
    $tx->req->headers->header('sec-fetch-mode' => 'cors');
    $tx->req->headers->header('sec-fetch-site' => 'same-site');
    
    # 发送请求并获取结果
    my $res = $ua->start($tx)->result;
    
    if (!$res) {
        $logger->error("无法连接到hdoujin.org - 请检查网络连接");
        return ("", "");
    }
    
    # 检查HTTP状态码
    if ($res->code != 200) {
        $logger->error("API请求失败，状态码: " . $res->code . " - " . $res->message);
        $logger->debug("请求头: " . $tx->req->headers->to_string);
        $logger->debug("响应内容: " . $res->body) if $res->body;
        return ("", "");
    }
    
    my $jsonresponse;
    eval { $jsonresponse = $res->json; };
    
    if ($@) {
        $logger->error("解析JSON响应时出错: $@");
        return ("", "");
    }
    
    # 检查是否有搜索结果
    if (!$jsonresponse->{entries} || scalar @{$jsonresponse->{entries}} == 0) {
        $logger->info("没有找到匹配的结果");
        $logger->debug("API响应: " . encode_json($jsonresponse)) if $jsonresponse;
        return ("", "");
    }
    
    # 记录找到的结果数量
    my $result_count = scalar @{$jsonresponse->{entries}};
    $logger->debug("找到 $result_count 个结果");
    
    # 获取第一个结果的ID和key
    my $id = $jsonresponse->{entries}[0]->{id};
    my $key = $jsonresponse->{entries}[0]->{key};
    my $title = $jsonresponse->{entries}[0]->{title} || "未知标题";
    
    $logger->debug("找到匹配结果: [$title] (ID: $id, Key: $key)");
    return ($id, $key);
}

# get_tags_from_hdoujin(userAgent, id, key)
# 执行hdoujin.org API请求并返回标签和标题
sub get_tags_from_hdoujin {

    my ( $ua, $id, $key, $enable_cn_translation, $cn_db_path ) = @_;
    my $logger = get_plugin_logger();
    
    my $detail_url = "https://api.hdoujin.org/books/detail/$id/$key";
    $logger->debug("获取详细信息: $detail_url");
    
    # 设置必要的请求头
    my $tx = $ua->build_tx(GET => $detail_url);
    $tx->req->headers->header('Accept' => '*/*');
    $tx->req->headers->header('User-Agent' => 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.95 Mobile Safari/537.36');
    $tx->req->headers->header('Referer' => 'https://hdoujin.org/');
    $tx->req->headers->header('authority' => 'api.hdoujin.org');
    $tx->req->headers->header('accept-language' => 'zh-CN,zh;q=0.9');
    $tx->req->headers->header('cache-control' => 'no-cache');
    $tx->req->headers->header('dnt' => '1');
    $tx->req->headers->header('origin' => 'https://hdoujin.org');
    $tx->req->headers->header('pragma' => 'no-cache');
    $tx->req->headers->header('sec-ch-ua' => '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"');
    $tx->req->headers->header('sec-ch-ua-mobile' => '?1');
    $tx->req->headers->header('sec-ch-ua-platform' => '"Android"');
    $tx->req->headers->header('sec-fetch-dest' => 'empty');
    $tx->req->headers->header('sec-fetch-mode' => 'cors');
    $tx->req->headers->header('sec-fetch-site' => 'same-site');
    
    # 发送请求并获取结果
    my $res = $ua->start($tx)->result;
    
    if (!$res) {
        $logger->error("无法获取详细信息 - 请检查网络连接");
        return ("", "");
    }
    
    # 检查HTTP状态码
    if ($res->code != 200) {
        $logger->error("获取详细信息失败，状态码: " . $res->code . " - " . $res->message);
        $logger->debug("请求头: " . $tx->req->headers->to_string);
        $logger->debug("响应内容: " . $res->body) if $res->body;
        return ("", "");
    }
    
    my $jsonresponse;
    eval { $jsonresponse = $res->json; };
    
    if ($@) {
        $logger->error("解析JSON响应时出错: $@");
        return ("", "");
    }
    
    # 提取标题
    my $title = $jsonresponse->{title} || "";
    $logger->debug("获取到标题: $title");
    
    # 提取namespace为8和9的标签
    my @extracted_tags;
    my %tag_counts;
    
    if ($jsonresponse->{tags} && ref($jsonresponse->{tags}) eq 'ARRAY') {
        $logger->debug("找到 " . scalar(@{$jsonresponse->{tags}}) . " 个标签");
        
        foreach my $tag (@{$jsonresponse->{tags}}) {
            if ($tag->{namespace} == 9) {
                push @extracted_tags, "female:" . $tag->{name};
                $tag_counts{$tag->{namespace}}++;
            } elsif ($tag->{namespace} == 8) {
                push @extracted_tags, "male:" . $tag->{name};
                $tag_counts{$tag->{namespace}}++;
            }
        }
        
        $logger->debug("按命名空间统计: " . join(", ", map { "namespace $_ (" . $tag_counts{$_} . " 个)" } sort keys %tag_counts));
    } else {
        $logger->info("未找到任何标签");
    }
    
    # 将标签拼接为字符串
    my $tags = join(", ", @extracted_tags);
    $logger->info("提取的namespace=8和9标签 (" . scalar(@extracted_tags) . "个，已添加female:和male前缀): $tags");
    
    # 如果启用了中文翻译且提供了数据库路径，则进行翻译
    if ($enable_cn_translation && $cn_db_path && -f $cn_db_path) {
        $logger->info("启用中文标签翻译，使用数据库: $cn_db_path");
        my @tag_list = split(/,\s*/, $tags);
        my @translated_tags = @{translate_tag_to_cn(\@tag_list, $cn_db_path)};
        my $translated_tags_str = join(", ", @translated_tags);
        $logger->info("翻译后的标签: $translated_tags_str");
        return ($translated_tags_str, $title);
    } else {
        if ($enable_cn_translation) {
            $logger->info("中文翻译已启用，但数据库文件不存在或未指定: $cn_db_path");
        }
        return ($tags, $title);
    }
}

# 将原tag翻译为中文tag
sub translate_tag_to_cn {
    my $logger = get_plugin_logger();
    my ($list, $db_path) = @_;
    my $filename = $db_path; # json 文件的路径
    my $json_text = do {
        open(my $json_fh, "<", $filename)
            or $logger->debug("Can't open $filename: $!\n");
        local $/;
        <$json_fh>;
    };
    my $json = decode_json($json_text);
    my $target = $json->{'data'};

    for my $item (@$list) {
        my ($namespace, $key) = split(/:/, $item);
        for my $element (@$target) {
            # 如果$namespace与'namespace'字段相同，则进行替换
            if ($element->{'namespace'} eq $namespace) {
                my $name = $element->{'frontMatters'}->{'name'};
                $item =~ s/$namespace/$name/;
                my $data = $element->{'data'};
                # 如果在'data'字段中存在$key，则进行替换
                if (exists $data->{$key}) {
                    my $value = $data->{$key}->{'name'};
                    $item =~ s/$key/$value/;
                }
                last;
            }
        }
    }
    
    return $list;
}

1;