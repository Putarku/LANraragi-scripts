package LANraragi::Plugin::Metadata::EHentai;

use strict;
use warnings;
no warnings 'uninitialized';

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use URI::Escape;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(html_unescape);
use Mojo::UserAgent;
use utf8;
#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "E-Hentai",
        type        => "metadata",
        namespace   => "ehplugin",
        login_from  => "ehlogin",
        author      => "Difegue and others and zizzdog",
        version     => "2.5.2_1",
        description =>
          "搜索 g.e-hentai 以查找与您的存档匹配的标签. <br/><i class='fa fa-exclamation-circle'></i> 此插件将使用存档的 source: tag （如果存在）",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI\nWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH4wYBFg0JvyFIYgAAAB1pVFh0Q29tbWVudAAAAAAAQ3Jl\nYXRlZCB3aXRoIEdJTVBkLmUHAAAEo0lEQVQ4y02UPWhT7RvGf8/5yMkxMU2NKaYIFtKAHxWloYNU\ncRDeQTsUFPwAFwUHByu4ODq4Oghdiri8UIrooCC0Lx01ONSKfYOioi1WpWmaxtTm5PTkfNzv0H/D\n/9oeePjdPNd13Y8aHR2VR48eEUURpmmiaRqmaXbOAK7r4vs+IsLk5CSTk5P4vo9hGIgIsViMra0t\nCoUCRi6XY8+ePVSrVTRN61yybZuXL1/y7t078vk8mUyGvXv3cuLECWZnZ1lbW6PdbpNIJHAcB8uy\nePr0KYZlWTSbTRKJBLquo5TCMAwmJia4f/8+Sini8Ti1Wo0oikin09i2TbPZJJPJUK/XefDgAefO\nnWNlZQVD0zSUUvi+TxAE6LqOrut8/fqVTCaDbdvkcjk0TSOdTrOysoLrujiOw+bmJmEYMjAwQLVa\nJZVKYXR1ddFut/F9H9M0MU0T3/dZXV3FdV36+/vp7u7m6NGj7Nq1i0qlwuLiIqVSib6+Pubn5wGw\nbZtYLIaxMymVSuH7PpZlEUURSina7TZBEOD7Pp8/fyYMQ3zfZ25ujv3795NOp3n48CE9PT3ouk4Q\nBBi/fv3Ctm0cx6Grq4utrS26u7sREQzDIIoifv78SU9PD5VKhTAMGRoaYnV1leHhYa5evUoQBIRh\niIigiQhRFKHrOs1mE9u2iaKIkydPYhgGAKZp8v79e+LxOPl8Htd1uXbtGrdv3yYMQ3ZyAODFixeb\nrVZLvn//Lq7rSqVSkfX1dREROXz4sBw/flyUUjI6OipXrlyRQ4cOSbPZlCiKxHVdCcNQHMcRz/PE\ndV0BGL53756sra1JrVaT9fV1cRxHRESGhoakr69PUqmUvHr1SsrlsuzI931ptVriuq78+fNHPM+T\nVqslhoikjh075p09e9ba6aKu6/T39zM4OMjS0hIzMzM0Gg12794N0LEIwPd9YrEYrusShiEK4Nmz\nZ41yudyVy+XI5/MMDAyQzWap1+tks1lEhIWFBQqFArZto5QiCAJc1+14t7m5STweRwOo1WoSBAEj\nIyMUi0WSySQiQiqV6lRoYWGhY3673e7sfRAEiAjZbBbHcbaBb9++5cCBA2SzWZLJJLZt43kesViM\nHX379g1d1wnDsNNVEQEgCAIajQZ3797dBi4tLWGaJq7rYpompVKJmZkZ2u12B3j58mWUUmiahoiw\nsbFBEASdD2VsbIwnT55gACil+PHjB7Ozs0xPT/P7929u3ryJZVmEYUgYhhQKBZRSiAie52EYBkop\nLMvi8ePHTE1NUSwWt0OZn5/3hoeHzRs3bqhcLseXL1+YmJjowGzbRtO07RT/F8jO09+8ecP58+dJ\nJBKcPn0abW5uThWLRevOnTv/Li4u8vr1a3p7e9E0jXg8zsePHymVSnz69Kmzr7quY9s2U1NTXLp0\nCc/zOHLkCPv27UPxf6rX63+NjIz8IyKMj48zPT3NwYMHGRwcpLe3FwARodVqcf36dS5evMj4+DhB\nEHDmzBkymQz6DqxSqZDNZr8tLy//DYzdunWL5eVlqtUqHz58IJVKkUwmaTQalMtlLly4gIjw/Plz\nTp06RT6fZ2Njg/8AqMV7tO07rnsAAAAASUVORK5CYII=",
        parameters => [
            { type => "string", desc => "在搜索中强制使用语言（由于 EH 限制，日语无法使用）" },
            { type => "bool",   desc => "首先使用缩略图获取（如果失败，则回退到标题）" },
            { type => "bool",   desc => "使用标题的 gID 进行搜索（仅匹配Ehviewer下载的数字开头-结尾的标题，例如：134-(C100)ABC.zip，如果失败，则回退到标题）" },
            { type => "bool",   desc => "使用 ExHentai（可以在没有捐赠用户星级的cookie 的情况下搜索fjorded内容，即捐赠账号才可表站看里站）" },
            { type => "bool",   desc => "如果可用，请保存原始标题，而不是英文或罗马拼音标题" },
            { type => "bool",   desc => "获取额外的时间戳（发布时间）和上传者元数据" },
            { type => "bool",   desc => "搜索已删除的图库" },
        ],
        
        oneshot_arg => "该漫画在e-hentai的URL(将于确切的漫画相匹配的标签到你的档案中)",
        cooldown    => 4
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                                                                               # Global info hash
    my $ua       = $lrr_info->{user_agent};
    my ( $lang, $usethumbs, $search_gid, $enablepanda, $jpntitle, $additionaltags, $expunged ) = @_;    # Plugin parameters

    # Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    # Work your magic here - You can create subroutines below to organize the code better
    my $gID    = "";
    my $gToken = "";
    my $domain = ( $enablepanda ? 'https://exhentai.org' : 'https://e-hentai.org' );
    my $hasSrc = 0;

    # Quick regex to get the E-H archive ids from the provided url or source tag
    if ( $lrr_info->{oneshot_param} =~ /.*\/g\/([0-9]*)\/([0-z]*)\/*.*/ ) {
        $gID    = $1;
        $gToken = $2;
        $logger->debug("Skipping search and using gallery $gID / $gToken from oneshot args");
    } elsif ( $lrr_info->{existing_tags} =~ /.*source:\s*e(?:x|-)hentai\.org\/g\/([0-9]*)\/([0-z]*)\/*.*/gi ) {
        $gID    = $1;
        $gToken = $2;
        $hasSrc = 1;
        $logger->debug("Skipping search and using gallery $gID / $gToken from source tag");
    } else {

        # Craft URL for Text Search on EH if there's no user argument
        ( $gID, $gToken ) = &lookup_gallery(
            $lrr_info->{archive_title},
            $lrr_info->{existing_tags},
            $lrr_info->{thumbnail_hash},
            $ua, $domain, $lang, $usethumbs, $search_gid, $expunged
        );
    }

    # If an error occured, return a hash containing an error message.
    # LRR will display that error to the client.
    # Using the GToken to store error codes - not the cleanest but it's convenient
    if ( $gID eq "" ) {

        if ( $gToken ne "" ) {
            $logger->error($gToken);
            return ( error => $gToken );
        }

        $logger->info("未找到匹配的 EH 画廊！");
        return ( error => "未找到匹配的 EH 画廊！" );
    } else {
        $logger->debug("EH API 令牌是 $gID / $gToken");
    }

    my ( $ehtags, $ehtitle ) = &get_tags_from_EH( $ua, $gID, $gToken, $jpntitle, $additionaltags );
    my %hashdata = ( tags => $ehtags );

    # Add source URL and title if possible/applicable
    if ( $hashdata{tags} ne "" ) {

        if ( !$hasSrc ) { $hashdata{tags} .= ", source:" . ( split( '://', $domain ) )[1] . "/g/$gID/$gToken"; }
        $hashdata{title} = $ehtitle;
    }

    # 把数据交给LRR
    return %hashdata;
}

######
## EH Specific Methods
######

sub lookup_gallery {

    my ( $title, $tags, $thumbhash, $ua, $domain, $defaultlanguage, $usethumbs, $search_gid, $expunged ) = @_;
    my $logger = get_plugin_logger();
    my $URL    = "";

    #Thumbnail reverse image search
    if ( $thumbhash ne "" && $usethumbs ) {

        $logger->info("反向图像搜索已启用，正在尝试。");

        #search with image SHA hash
        $URL = $domain . "?f_shash=" . $thumbhash . "&fs_similar=on&fs_covers=on";

        $logger->debug("使用 URL $URL（存档缩略图哈希）");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    # 从标题获取GID，并把搜索标题过滤GID
    my ($title_gid, $title_search) = $title =~ /^(\d+)-(.+)/;
    # 匹配到GID，标题改为去除GID的部分
    $title = $title_search if defined $title_gid;

    #使用GID进行搜索
    if ( $search_gid && $title_gid ) {
        $URL = $domain . "?f_search=" . uri_escape_utf8("gid:$title_gid");

        $logger->debug("找到 gID：$title_gid，使用 URL $URL（来自存档标题的 gID）");

        my ( $gId, $gToken ) = &ehentai_parse( $URL, $ua );

        if ( $gId ne "" && $gToken ne "" ) {
            return ( $gId, $gToken );
        }
    }

    # Regular text search (advanced options: Disable default filters for: Language, Uploader, Tags)
    $URL = $domain . "?advsearch=1&f_sfu=on&f_sft=on&f_sfl=on" . "&f_search=" . uri_escape_utf8( qw(") . $title . qw(") );

    my $has_artist = 0;

    # Add artist tag from the OG tags if it exists (and only contains ASCII characters)
    if ( $tags =~ /.*artist:\s?([^,]*),*.*/gi ) {
        my $artist = $1;
        if ( $artist =~ /^[\x00-\x7F]*$/ ) {
            $URL        = $URL . "+" . uri_escape_utf8("artist:$artist");
            $has_artist = 1;
        }
    }

    # Add the language override, if it's defined.
    if ( $defaultlanguage ne "" ) {
        $URL = $URL . "+" . uri_escape_utf8("language:$defaultlanguage");
    }

    # Search expunged galleries if the option is enabled.
    if ($expunged) {
        $URL = $URL . "&f_sh=on";
    }

    $logger->debug("使用 URL $URL（存档标题）");
    return &ehentai_parse( $URL, $ua );
}

# ehentai_parse(URL, UA)
# Performs a remote search on e- or exhentai, and returns the ID/token matching the found gallery.
sub ehentai_parse() {

    my ( $url, $ua ) = @_;

    my $logger = get_plugin_logger();

    my ( $dom, $error ) = search_gallery( $url, $ua );
    if ($error) {
        return ( "", $error );
    }

    my $gID    = "";
    my $gToken = "";

    eval {
        # Get the first row of the search results
        # The "glink" class is parented by a <a> tag containing the gallery link in href.
        # This works in Minimal, Minimal+ and Compact modes, which should be enough.
        my $firstgal = $dom->at(".glink")->parent->attr('href');

        # A EH link looks like xhentai.org/g/{gallery id}/{gallery token}
        my $url    = ( split( 'hentai.org/g/', $firstgal ) )[1];
        my @values = ( split( '/',             $url ) );

        $gID    = $values[0];
        $gToken = $values[1];
    };

    if ( index( $dom->to_string, "You are opening" ) != -1 ) {
        my $rand = 15 + int( rand( 51 - 15 ) );
        $logger->info("由于 EH 过多请求警告而休眠 $rand 秒");
        sleep($rand);
    }

    #Returning shit yo
    return ( $gID, $gToken );
}

sub search_gallery {

    my ( $url, $ua ) = @_;
    my $logger = get_plugin_logger();

    my $res = $ua->max_redirects(5)->get($url)->result;

    # 添加判断，检查$res->body是否为空
    if ($res->body eq '') {
        $logger->info("登录插件 `E-Hentai`的`igneous cookie`参数可能已过期，请及时更新！");
        return ( "", "登录插件 `E-Hentai`的`igneous cookie`参数可能已过期，请及时更新！" );
    }

    if ( index( $res->body, "Your IP address has been" ) != -1 ) {
        $logger->info("因页面加载过多，您的 IP 地址已被 E-Hentai 暂时封禁.");
        return ( "", "因页面加载过多，您的 IP 地址已被 E-Hentai 暂时封禁。" );
    }

    return ( $res->dom, undef );
}

# get_tags_from_EH(userAgent, gID, gToken, jpntitle, additionaltags)
# Executes an e-hentai API request with the given JSON and returns tags and title.
sub get_tags_from_EH {

    my ( $ua, $gID, $gToken, $jpntitle, $additionaltags ) = @_;
    my $uri = 'https://api.e-hentai.org/api.php';

    my $logger = get_plugin_logger();

    my $jsonresponse = get_json_from_EH( $ua, $gID, $gToken );

    #if an error occurs(no response) return empty strings.
    if ( !$jsonresponse ) {
        return ( "", "" );
    }

    my $data    = $jsonresponse->{"gmetadata"};
    my @tags    = @{ @$data[0]->{"tags"} };
    my $ehtitle = @$data[0]->{ ( $jpntitle ? "title_jpn" : "title" ) };
    if ( $ehtitle eq "" && $jpntitle ) {
        $ehtitle = @$data[0]->{"title"};
    }
    my $ehcat = lc @$data[0]->{"category"};

    push( @tags, "category:$ehcat" );
    if ($additionaltags) {
        my $ehuploader  = @$data[0]->{"uploader"};
        my $ehtimestamp = @$data[0]->{"posted"};
        push( @tags, "uploader:$ehuploader" );
        push( @tags, "timestamp:$ehtimestamp" );
    }

    # Unescape title received from the API as it might contain some HTML characters
    $ehtitle = html_unescape($ehtitle);

    my $ehtags = join( ', ', @tags );
    $logger->info("将以下标签发送到LRR: $ehtags");

    return ( $ehtags, $ehtitle );
}

sub get_json_from_EH {

    my ( $ua, $gID, $gToken ) = @_;
    my $uri = 'https://api.e-hentai.org/api.php';

    my $logger = get_plugin_logger();

    #Execute the request
    my $rep = $ua->post(
        $uri => json => {
            method    => "gdata",
            gidlist   => [ [ $gID, $gToken ] ],
            namespace => 1
        }
    )->result;

    my $textrep = $rep->body;
    $logger->debug("E-H API 返回的JSON数据: $textrep");

    my $jsonresponse = $rep->json;
    if ( exists $jsonresponse->{"error"} ) {
        return;
    }

    return $jsonresponse;
}

1;
