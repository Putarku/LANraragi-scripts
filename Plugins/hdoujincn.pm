package LANraragi::Plugin::Metadata::hdoujincn;

use strict;
use warnings;
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(html_unescape);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name       => "hdoujincn",
        type       => "metadata",
        namespace  => "hdoujincn",
        login_from => "",
        author     => "Paturku",
        version    => "1.0.0",
        description =>
          "从 hdoujin.org 获取元数据，并提取namespace为9的标签。",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAABP0lEQVR4nO2UMUvDQBTH/3dJLLQFoYOLk4uLs5ODH0AQnBwcHJwcHPwAIjg5ODg4ODg4iKODg4M4Ojg4iKOgIEWkpZe8c0itqQYaW3Dw4A2Pd7/7/d+7907wjyGAOwCvAKKsXgDcAigA8Fwwxh0MBpVut7vXbrdPAZQBbAJIAHwCeAdwZIzZXwpGUVTpdDr7nU7nDMCGiGwZY7aMMbUwDPestRcANqWU1Ov1k4VgGIYH3W73HEBZRLbTNG2EYVhL07QRx/FRkiQXAMpRFB3OBb1SqVTr9XoHgA9gO0mSRhAEtSRJGmEY1qy1FwDKALZqtdrxTDCO4+MgCPZFZCdJkkYQBDVrbX0MjsF6vX46BcZxfDwGd5MkaQRBULPWnmeQMeZwJhiG4eEYrFtrz7KKJ+AXgMpS8Df4BvUdKYlU/Pc2AAAAAElFTkSuQmCC",
          
        parameters => [
            { type => "string", desc => "搜索语言（默认为12，表示中文）" },
            { type => "bool",   desc => "使用标题的 ID 进行搜索（仅匹配数字开头-结尾的标题，例如：134-(C100)ABC.zip，如果失败，则回退到标题）" },
        ],

        oneshot_arg => "该漫画在hdoujin.org的URL(将与确切的漫画匹配的标签添加到你的档案中)",
        cooldown    => 4
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                                # Global info hash
    my $ua       = $lrr_info->{user_agent};
    my ( $lang, $search_id ) = @_;                      # Plugin parameters

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    # Work your magic here - You can create subroutines below to organize the code better
    my $id    = "";
    my $key   = "";
    my $hasSrc = 0;

    # 设置默认语言为中文(12)
    $lang = 12 if $lang eq "";

    # Quick regex to get the hdoujin archive ids from the provided url or source tag
    if ( $lrr_info->{oneshot_param} =~ /.*\/books\/detail\/([0-9]*)\/(.*?)(?:\/|\$)/ ) {
        $id  = $1;
        $key = $2;
        $logger->debug("Skipping search and using gallery $id / $key from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*hdoujin\.org\/books\/detail\/([0-9]*)\/([0-z]*)\/?.*/gi ) {
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
        $logger->debug("HDOujin API 令牌是 $id / $key");
    }

    my ( $tags, $title ) = &get_tags_from_hdoujin( $ua, $id, $key );
    my %hashdata = ( tags => $tags );

    # Add source URL and title if possible/applicable
    if ( $hashdata{tags} ne "" ) {
        if ( !$hasSrc ) { $hashdata{tags} .= ", source:hdoujin.org/books/detail/$id/$key"; }
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
    my $encoded_title = uri_escape_utf8($title);
    my $search_url = "https://api.hdoujin.org/books?s=$encoded_title&lang=$lang";
    
    $logger->debug("使用 URL $search_url（存档标题）");
    return &hdoujin_parse( $search_url, $ua );
}

# hdoujin_parse(URL, UA)
# 执行hdoujin.org的搜索，并返回匹配的ID/key
sub hdoujin_parse {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    # 从 fatch 文件中提取的请求头，针对 api.hdoujin.org/books 的请求
    my $headers = {
        'Accept'             => '*/*', # 根据fatch文件，API请求的Accept是*/*
        'Accept-Language'    => 'zh-CN,zh;q=0.9',
        'Cache-Control'      => 'no-cache',
        'Pragma'             => 'no-cache',
        'Sec-CH-UA'          => '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        'Sec-CH-UA-Mobile'   => '?1',
        'Sec-CH-UA-Platform' => '"Android"',
        'Sec-Fetch-Dest'     => 'empty',
        'Sec-Fetch-Mode'     => 'cors',
        'Sec-Fetch-Site'     => 'same-site', # API请求是same-site
        'User-Agent'         => 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.95 Mobile Safari/537.36',
        'Referer'            => 'https://hdoujin.org/' # API请求的Referer是主站
        # 'Origin' 通常在CORS请求中由浏览器自动添加，Mojo::UserAgent可能不需要显式设置，或者如果需要，也应为 'https://hdoujin.org'
    };

    $logger->debug("使用请求头: " . encode_json($headers));
    my $res = $ua->get($url, $headers)->result;

    if (!$res || $res->code != 200) {
        $logger->error("无法连接到hdoujin.org或请求失败: " . ($res ? $res->code . " " . $res->message : "No response"));
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
        return ("", "");
    }
    
    # 获取第一个结果的ID和key
    my $id = $jsonresponse->{entries}[0]->{id};
    my $key = $jsonresponse->{entries}[0]->{key};
    
    return ($id, $key);
}

# get_tags_from_hdoujin(userAgent, id, key)
# 执行hdoujin.org API请求并返回标签和标题
sub get_tags_from_hdoujin {

    my ( $ua, $id, $key ) = @_;
    my $logger = get_plugin_logger();
    
    my $detail_url = "https://api.hdoujin.org/books/detail/$id/$key";
    $logger->debug("获取详细信息: $detail_url");
    
    my $res = $ua->get($detail_url)->result;
    if (!$res) {
        $logger->error("无法获取详细信息");
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
    
    # 提取namespace为9的标签
    my @namespace9_tags;
    if ($jsonresponse->{tags} && ref($jsonresponse->{tags}) eq 'ARRAY') {
        foreach my $tag (@{$jsonresponse->{tags}}) {
            if ($tag->{namespace} == 9) {
                push @namespace9_tags, $tag->{name};
            }
        }
    }
    
    # 将标签拼接为字符串
    my $tags = join(", ", @namespace9_tags);
    $logger->info("提取的namespace=9标签: $tags");
    
    return ($tags, $title);
}

1;