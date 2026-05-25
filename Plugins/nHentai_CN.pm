package LANraragi::Plugin::Metadata::nHentai_CN;

use strict;
use warnings;
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use File::Basename;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Redis qw(redis_decode);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "nHentai_CN",
        type        => "metadata",
        namespace   => "nhplugin_cn",
        login_from  => "nhapiauth",
        author      => "Difegue and others & zizzdog",
        version     => "1.8.2",
        description => "在 nHentai 中搜索与您的档案匹配的标签并翻译成中文. 
          <br>支持从格式为以下的文件中读取 ID \"{Id} Title\" 如果没有，尝试搜索匹配的图库.
          <br><i class='fa fa-exclamation-circle'></i> 此插件将使用 source: tag 的标签（如果存在）.",
        icon =>
          "data:image/png;base64,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",
        parameters  => [
            { type => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" },
            { type => "bool",   desc => "获取上传日期并写入 timestamp 标签" },
        ],
        cooldown    => 4,
        oneshot_arg => "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                      # Global info hash
    my ( $db_path, $add_uploaded ) = @_;
    my $ua = $lrr_info->{user_agent};          # UserAgent from login plugin

    my $logger = get_plugin_logger();

    my $galleryID = "";

    # Quick regex to get the nh gallery id from the provided url or source tag.
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]+).*/ ) {
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*(?:https?:\/\/)?nhentai\.net\/g\/([0-9]*).*/gi ) {

        # Matching URL Scheme like 'https://' is only for backward compatible purpose.
        $galleryID = $1;
        $logger->debug("Skipping search and using gallery $galleryID from source tag");
    } else {
        $logger->debug("Searching gallery by title (filename)");

        # lrr_info's file_path is taken straight from the filesystem, which might not be proper UTF-8.
        my $file_path = redis_decode( $lrr_info->{file_path} );

        $galleryID = get_gallery_id_from_title( $file_path, $ua );
    }

    # Did we detect a nHentai gallery?
    if ( defined $galleryID ) {
        $logger->debug("Detected nHentai gallery id is $galleryID");
    } else {
        $logger->info("No matching nHentai Gallery Found!");
        return ( error => "No matching nHentai Gallery Found!" );
    }

    #If no tokens were found, return a hash containing an error message.
    #LRR will display that error to the client.
    if ( $galleryID eq "" ) {
        $logger->info("No matching nHentai Gallery Found!");
        return ( error => "No matching nHentai Gallery Found!" );
    }

    # 构建哈希结构数据
    my %hashdata = get_tags_from_NH( $galleryID, $ua, $add_uploaded );

    return %hashdata if exists $hashdata{error};

    # 调用translate_tag_to_cn函数进行tag翻译
    my $tags_string = $hashdata{tags};
    if ($tags_string ne "" && $db_path) {
        $logger->info( "获取到的tags: " . $hashdata{tags} );
        $hashdata{tags} = translate_tag_to_cn($tags_string, $db_path);
    }
    
    # 把数据交给LRR
    $logger->info( "返回LRR的tags: " . $hashdata{tags} );
    return %hashdata;
}

######
## NH Specific Methods
######

#Uses the website's search to find a gallery and returns its content.
sub get_search_json {

    my ( $title, $ua ) = @_;

    my $logger = get_plugin_logger();

    my $URL = "https://nhentai.net/api/v2/search?query=" . uri_escape_utf8($title);

    my $res = $ua->get($URL)->result;

    if ( $res->is_error ) {
        my $code = $res->code;
        die "Search gallery by title failed! (Code: $code)\n";
    }

    $logger->debug("Tentative JSON: " . $res->body);

    return decode_json $res->body;
}

sub get_gallery_id_from_title {

    my ( $file, $ua ) = @_;
    my ( $title, $filepath, $suffix ) = fileparse( $file, qr/\.[^.]*/ );

    my $logger = get_plugin_logger();

    if ( $title =~ /\{(\d*)\}.*$/gm ) {
        $logger->debug("Got $1 from file.");
        return $1;
    }

    my $json = get_search_json( $title, $ua );

    my @results = @{ $json->{"result"} };

    if ( scalar @results > 0 ) {
        return $results[0]->{"id"};
    }

    return;
}

# retrieves gallery JSON from NH API
sub get_json_from_NH {

    my ( $gID, $ua ) = @_;

    my $logger = get_plugin_logger();

    my $URL = "https://nhentai.net/api/v2/galleries/$gID";

    my $res = $ua->get($URL)->result;

    if ( $res->is_error ) {
        my $code = $res->code;
        die "Error retrieving gallery from nHentai! (Code: $code)\n";
    }

    $logger->debug("Tentative JSON: " . $res->body);

    return decode_json $res->body;
}

sub get_tags_from_json {

    my ($json) = @_;

    my @json_tags = @{ $json->{"tags"} };
    my @tags      = ();

    foreach my $tag (@json_tags) {

        my $namespace = $tag->{"type"};
        my $name      = $tag->{"name"};

        if ( $namespace eq "tag" ) {
            push( @tags, $name );
        } else {
            push( @tags, "$namespace:$name" );
        }
    }

    return @tags;
}

sub get_title_from_json {
    my ($json) = @_;
    return $json->{"title"}{"pretty"};
}

sub get_upload_from_json {
    my ($json) = @_;
    return $json->{"upload_date"};
}

sub get_tags_from_NH {

    my ( $gID, $ua, $add_uploaded ) = @_;

    my %hashdata = ( tags => "" );

    my $json = get_json_from_NH( $gID, $ua );

    if ($json) {
        my @tags = get_tags_from_json($json);
        if ($add_uploaded) {
            my @upload = get_upload_from_json($json);
            push( @tags, "timestamp:@upload" );
        }
        push( @tags, "source:https://nhentai.net/g/$gID" ) if ( @tags > 0 );

        # Use NH's "pretty" names (romaji titles without extraneous data we already have like (Event)[Artist], etc)
        $hashdata{tags}  = join( ', ', @tags );
        $hashdata{title} = get_title_from_json($json);
    }

    return %hashdata;
}

# 将原tag翻译为中文tag，参数为：(tags字符串,翻译json路径$db_path)
sub translate_tag_to_cn {
    my $logger = get_plugin_logger();
    my ($tags_str, $db_path) = @_;
    my $filename = $db_path;
    my $json_text;
    {
        open( my $json_fh, "<", $filename )
          or do {
            $logger->error("无法打开翻译数据库 $filename: $!");
            return $tags_str;
          };
        local $/;
        $json_text = <$json_fh>;
    }
    if ( !defined $json_text || $json_text eq '' ) {
        $logger->error("翻译数据库为空: $filename");
        return $tags_str;
    }

    my $json = decode_json($json_text);
    if ( !$json || !exists $json->{'data'} ) {
        $logger->error("翻译数据库 JSON 无效或缺少 data 字段: $filename");
        return $tags_str;
    }

    my $target = $json->{'data'};

    # 替换 category: 为 reclass:
    $tags_str =~ s/category:/reclass:/g;

    # 将字符串形式的 tags 转换为数组
    my @tags = split(/,\s*/, $tags_str);

    # 遍历每个标签并进行翻译
    for my $item (@tags) {
        # 使用冒号分割namespace 和 key
        my ($namespace, $key) = split(/:/, $item);

        # 如果成功分割出 namespace 和 key，按原逻辑进行翻译
        if (defined $key) {
            for my $element (@$target) {
                # 翻译数据库的namespace与其别名并合并成一个列表
                my @namespace_aliases = ($element->{'frontMatters'}->{'key'}, @{$element->{'frontMatters'}->{'aliases'} || []});

                # 如果当前namespace翻译数据库匹配，则翻译
                if (grep { $_ eq $namespace } @namespace_aliases) {
                    # 替换 namespace 为中文名称
                    my $name = $element->{'frontMatters'}->{'name'};
                    $item =~ s/$namespace/$name/;

                    my $data = $element->{'data'};
                    # 如果key在翻译数据库中匹配，则翻译
                    if (exists $data->{$key}) {
                        my $value = $data->{$key}->{'name'};
                        $item =~ s/$key/$value/;
                    }
                    last;
                }
            }
        } 
        # 如果没有namespace，把整个标签当作 key，直接查找翻译
        else {
            for my $element (@$target) {
                my $data = $element->{'data'};
                if (exists $data->{$item}) {
                    $item = $data->{$item}->{'name'};
                    last;
                }
            }
        }
    }

    # 将词组前拼接“女性:”，并增加黑名单机制
    my @new_tags;
    my %blacklist = map { $_ => 1 } qw(单行本 团队 外部广告 教练 单男主 男生制服 正太 熟男 系列作品 大根 性转换 马赛克修正 避孕套 白大褂 教师 睡觉 胖男人 眼镜 全彩 秃顶 阴垢 西装 丧失童贞);
    foreach my $tag (@tags) {
        next if exists $blacklist{$tag};
        # 检查是否包含冒号
        if ($tag =~ /:/) {
            push @new_tags, $tag;  # 保持原样
        } else {
            push @new_tags, "女性:$tag";  # 添加前缀
        }
    }
    # 将数组转换回字符串，并返回
    my $translated_tags_str = join(', ', @new_tags);
    return $translated_tags_str;
}

1;
