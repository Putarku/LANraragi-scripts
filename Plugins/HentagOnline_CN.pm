package LANraragi::Plugin::Metadata::HentagOnline_CN;

use strict;
use warnings;
use feature qw(signatures);
no warnings 'experimental::signatures';

use URI::Escape;
use Mojo::JSON qw(from_json decode_json);
use Mojo::UserAgent;
use utf8;
#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);

use LANraragi::Utils::String;
use String::Similarity;

# Most parsing is reused between the two plugins
require LANraragi::Plugin::Metadata::Hentag;

#Meta-information about your plugin.
sub plugin_info {

    return (
        name        => "Hentag Online Lookups CN",
        type        => "metadata",
        namespace   => "hentagonlineplugin_cn",
        author      => "siliconfeces & zizzdog",
        version     => "0.2_1",
        description => "在 hentag.com 中搜索与您的档案相匹配的tag，并把tag翻译成中文",
        parameters  => [
            { type  => "string", desc => "搜索语言优先级列表，逗号分隔。 第一语言 = 最优先。 默认为“英语、日语”" },
            { type  => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" },
        ],
        cooldown    => 4,
        oneshot_arg => "Hentag.com vault URL (Will attach matching tags to your archive)",
        icon        =>
          "data:image/png;base64,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",
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;
    my ($allowed_languages, $db_path) = @_;

    my $ua                = $lrr_info->{user_agent};
    my $oneshot_param     = $lrr_info->{oneshot_param};
    my $logger            = get_plugin_logger();
    my $raw_existing_tags = $lrr_info->{existing_tags};
    my @existing_tags;

    if ( defined($raw_existing_tags) ) {
        @existing_tags = split( ',', $lrr_info->{existing_tags} );
    }

    if ( !defined($allowed_languages) || $allowed_languages eq '' ) {

        # Weeby default
        $allowed_languages = "english, japanese";
    }

    my $vault_id;
    my @source_urls   = undef;
    my $archive_title = undef;

    # First, try running based on a vault ID from a hentag URL
    if ( defined($oneshot_param) && $oneshot_param ne '' ) {
        $logger->info("Oneshot param = $oneshot_param");

        # URL was passed as a oneshot param, done!
        $vault_id = parse_vault_url($oneshot_param);
        if ( !defined($vault_id) ) {
            $logger->info("Failed parsing URL $oneshot_param");

            # Don't continue execution if the oneshot URL was invalid. Raise an error instead to avoid surprises
            return ( error => "Did not recognize the URL, is it a proper vault URL?" );
        }
    } elsif ( my $hentag_source = get_existing_hentag_source_url(@existing_tags) ) {

       # There might be a hentag URL inside a tag. If it fails parsing, that's okay, just continue execution with any other approach
        if ( defined($hentag_source) ) {
            $logger->info("Found an existing (parsable) hentag source, will use that!");
            $vault_id = parse_vault_url($hentag_source);
        }
    } else {

        # Try to fetch any other existing source tags
        @source_urls = get_source_tags(@existing_tags);
    }

    my $string_json = '';
    if ( defined($vault_id) ) {

        # Use a vault ID for lookups
        $logger->info('Vault ID run');
        $string_json = get_json_by_vault_id( $ua, $vault_id, $logger );
    } elsif (@source_urls) {

        # Use existing URL tags for lookups
        $logger->info('URL lookup run');
        $string_json = get_json_by_urls( $ua, $logger, @source_urls );
    } else {

        # Title lookup
        $logger->info('Title lookup');
        $archive_title = $lrr_info->{archive_title};
        
        # 从标题获取GID，并把搜索标题过滤GID
        my ($title_gid, $title_search) = $archive_title =~ /^(\d+)-(.+)/;
        # 匹配到GID，标题改为去除GID的部分
        $archive_title = $title_search if defined $title_gid;

        if ( $string_json eq '' ) {
            $string_json = get_json_by_title( $ua, $archive_title, $logger );
        }
        
        if ( $string_json eq '' ) {
            my $source_error = '没有匹配的画廊，搜索失败！';
            $logger->error($source_error);
            return ( error => $source_error );
        }
    }

    $logger->debug("从Hentag获取到的json为: $string_json");
    my $json = from_json($string_json);

    #解析json的tags和title
    my ( $tags, $title ) = tags_from_hentag_api_json( $json, $allowed_languages, $archive_title );

    # 构建哈希结构数据
    my %hashdata = ( tags => $tags, title => $title );

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

# Returns the ID from a hentag URL, or undef if invalid.
sub parse_vault_url ($url) {
    if ( !defined $url ) {
        return;
    }
    if ( $url =~ /https?:\/\/(?:www\.)?hentag\.com\/vault\/([a-zA-Z0-9]*)\/?.*/ ) {
        return $1;
    }
    return;
}

# Fairly good for mocking in tests
# get_json_by_title(ua, archive_title, logger)
sub get_json_by_title ( $ua, $archive_title, $logger ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/title');
    $logger->info("Hentag search for $archive_title");

    my $res = $ua->post( $url => json => { title => $archive_title } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fairly good for mocking in tests
# Returns the json response (as a string) from hentag. If no response, an empty string is returned.
sub get_json_by_vault_id ( $ua, $vault_id, $logger ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/id');
    $logger->info("Hentag search for $vault_id");

    my $res = $ua->post( $url => json => { ids => [$vault_id] } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fairly good for mocking in tests
# Returns the json response (as a string) from hentag. If no response, an empty string is returned.
sub get_json_by_urls ( $ua, $logger, @urls ) {
    my $string_json = '';
    my $url         = Mojo::URL->new('https://hentag.com/api/v1/search/vault/url');
    $logger->info("Hentag search based on URLs: @urls");
    my $res = $ua->post( $url => json => { urls => \@urls } )->result;

    if ( $res->is_success ) {
        $string_json = $res->text;
        $logger->info( 'Successful request, response: ' . $string_json );
    }
    return $string_json;
}

# Fetches tags and title, restricted to a language
# If $title_hint is set, it attempts to pick the "best" result if multiple hits were returned from Hentag
sub tags_in_language_from_hentag_api_json ( $json, $language, $title_hint = undef ) {
    $language =~ s/^\s+|\s+$//g;
    $language = lc($language);

    # The JSON can contain multiple hits. Fetch all that match the requested language
    my @lang_json_pairs = map { LANraragi::Plugin::Metadata::Hentag::language_from_hentag_json($_) eq $language ? $_ : () } @$json;

    if (@lang_json_pairs) {

        # Possible improvement: Look for hits with "better" metadata (more tags, more tags in namespaces, etc).
        my ( $tags, $title ) =
          LANraragi::Plugin::Metadata::Hentag::tags_from_hentag_json( pick_best_hit( $title_hint, @lang_json_pairs ) );
        return ( $tags, $title );
    }
    return ( '', '' );
}

# Returns (string_with_tags, string_with_title) on success, (empty_string, empty_string) on failure
sub tags_from_hentag_api_json ( $json, $string_prefered_languages, $title_hint = undef ) {
    my @prefered_languages = split( ",", $string_prefered_languages );
    foreach my $language (@prefered_languages) {
        my ( $tags, $title ) = tags_in_language_from_hentag_api_json( $json, $language, $title_hint );
        if ( $tags ne '' ) {
            return ( $tags, $title );
        }
    }
    return ( '', '' );
}

sub get_existing_hentag_source_url (@tags) {
    foreach my $tag ( get_source_tags(@tags) ) {
        if ( parse_vault_url($tag) ) {
            return $tag;
        }
    }
    return;
}

sub get_source_tags (@tags) {
    my @found_tags;
    foreach my $tag (@tags) {
        if ( $tag =~ /.*source:(.*)/ ) {
            push( @found_tags, $1 );
        }
    }
    return @found_tags;
}

sub pick_best_hit ( $title_hint, @hits ) {
    if ( !defined($title_hint) ) {
        return $hits[0];
    }
    $title_hint = lc( LANraragi::Utils::String::clean_title($title_hint) );

    my @titles;
    while ( my ( $index, $elem ) = each @hits ) {
        my ( $tags, $title ) = LANraragi::Plugin::Metadata::Hentag::tags_from_hentag_json($elem);
        $titles[$index] = lc( LANraragi::Utils::String::clean_title($title) );
    }
    return $hits[ LANraragi::Utils::String::most_similar( $title_hint, @titles ) ];
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
    # 将数组转换回字符串，并返回
    my $translated_tags_str = join(', ', @tags);
    return $translated_tags_str;
}

1;