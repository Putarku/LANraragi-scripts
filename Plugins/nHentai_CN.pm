package LANraragi::Plugin::Metadata::nHentai_CN;

use strict;
use warnings;
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(from_json decode_json);
use Mojo::UserAgent;

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "nHentai_CN",
        type        => "metadata",
        namespace   => "nhplugin_cn",
        login_from  => "nhentaicfbypass",
        author      => "Difegue and others & zizzdog",
        version     => "1.7.3_1",
        description => "在 nHentai 中搜索与您的档案匹配的标签并翻译成中文. 
          <br>支持从格式为以下的文件中读取 ID \"{Id} Title\" 如果没有，尝试搜索匹配的图库.
          <br><i class='fa fa-exclamation-circle'></i> 此插件将使用 source: tag 的标签（如果存在）.",
        icon =>
          "data:image/png;base64,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",
        parameters  => [{ type  => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" }],
        cooldown    => 4,
        oneshot_arg => "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)"
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                      # Global info hash
    my ($db_path) = @_;
    my $ua       = $lrr_info->{user_agent};    # UserAgent from login plugin

    my $logger = get_plugin_logger();

    # Work your magic here - You can create subs below to organize the code better
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

        #Get Gallery ID by hand if the user didn't specify a URL
        my $archive_title = $lrr_info->{archive_title};

        # 从标题获取GID，并把搜索标题过滤GID
        my ($title_gid, $title_search) = $archive_title =~ /^(\d+)-(.+)/;
        # 匹配到GID，标题改为去除GID的部分
        $archive_title = $title_search if defined $title_gid;

        $galleryID = get_gallery_id_from_title( $archive_title, $ua );
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
    my %hashdata = get_tags_from_NH( $galleryID, $ua );

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
sub get_gallery_dom_by_title {

    my ( $title, $ua ) = @_;

    my $logger = get_plugin_logger();

    #Strip away hyphens and apostrophes as they apparently break search
    $title =~ s/-|'/ /g;

    my $URL = "https://nhentai.net/search/?q=" . uri_escape_utf8($title);

    $logger->debug("Using URL $URL to search on nH.");

    my $res = $ua->get($URL)->result;
    $logger->debug( "Got response " . $res->body );

    if ( $res->is_error ) {
        return;
    }

    return $res->dom;
}

sub get_gallery_id_from_title {

    my ( $title, $ua ) = @_;

    my $logger = get_plugin_logger();

    if ( $title =~ /\{(\d*)\}.*$/gm ) {
        $logger->debug("Got $1 from file.");
        return $1;
    }

    my $dom = get_gallery_dom_by_title( $title, $ua );

    if ($dom) {

        # Get the first gallery url of the search results
        my $gURL =
          ( $dom->at('.cover') )
          ? $dom->at('.cover')->attr('href')
          : "";

        $logger->debug("Got $gURL from parsing.");
        if ( $gURL =~ /\/g\/(\d*)\//gm ) {
            return $1;
        }
    }

    return;
}

# retrieves html page from NH
sub get_html_from_NH {

    my ( $gID, $ua ) = @_;

    my $URL = "https://nhentai.net/g/$gID/";

    my $res = $ua->get($URL)->result;

    if ( $res->is_error ) {
        my $code = $res->code;
        return "error ($code)";
    }

    return $res->body;
}

#Find the metadata JSON in the HTML and turn it into an object
#It's located under a N.gallery JS object.
sub get_json_from_html {

    my ($html) = @_;

    my $logger = get_plugin_logger();

    my $jsonstring = "{}";
    if ( $html =~ /window\._gallery.*=.*JSON\.parse\((.*)\);/gmi ) {
        $jsonstring = $1;
    }

    $logger->debug("Tentative JSON: $jsonstring");

    # nH now provides their JSON with \uXXXX escaped characters.
    # The first pass of decode_json decodes those characters, but still outputs a string.
    # The second pass turns said string into an object properly so we can exploit it as a hash.
    my $json = decode_json $jsonstring;
    $json = decode_json $json;

    return $json;
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

sub get_tags_from_NH {

    my ( $gID, $ua ) = @_;

    my %hashdata = ( tags => "" );

    my $html = get_html_from_NH( $gID, $ua );

    # If the string starts with "error", we couldn't retrieve data from NH.
    if ( $html =~ /^error/ ) {
        return ( error => "Error retrieving gallery from nHentai! ($html)" );
    }

    my $json = get_json_from_html($html);

    if ($json) {
        my @tags = get_tags_from_json($json);
        push( @tags, "source:nhentai.net/g/$gID" ) if ( @tags > 0 );

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
    my $filename = $db_path; # json 文件的路径
    my $json_text = do {
        open(my $json_fh, "<", $filename)
            or $logger->debug("Can't open $filename: $!\n");
        local $/;
        <$json_fh>;
    };
    my $json = decode_json($json_text);
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
