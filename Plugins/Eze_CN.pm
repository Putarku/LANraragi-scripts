package LANraragi::Plugin::Metadata::Eze_CN;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json decode_json);
use File::Basename;
use Time::Local qw(timegm_modern);
use utf8;
#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Database;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::String  qw(trim);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name        => "eze_CN",
        type        => "metadata",
        namespace   => "ezeplugincn",
        author      => "Difegue",
        version     => "2.3.1_1",
        description =>
          "从 eze 样式的 info.json 文件 ({'gallery_info': {xxx} } syntax)中收集元数据并翻译成中文, 这些文件嵌入在您的存档中或具有相同名称的同一文件夹中. ({archive_name}.json),兼容Ehentai和nHentai",
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFDYBnHlU6AAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAETUlEQVQ4y22UTWhTWRTHf/d9JHmNJLFpShMcKoRIqxXE4sKpjgthYLCLggU/wI1CUWRUxlmU\nWblw20WZMlJc1yKKKCjCdDdYuqgRiygq2mL8aJpmQot5uabv3XdnUftG0bu593AOv3M45/yvGBgY\n4OrVqwRBgG3bGIaBbduhDSClxPM8tNZMTEwwMTGB53lYloXWmkgkwqdPnygUCljZbJbW1lYqlQqG\nYYRBjuNw9+5dHj16RD6fJ51O09bWxt69e5mammJ5eZm1tTXi8Tiu6xKNRrlx4wZWNBqlXq8Tj8cx\nTRMhBJZlMT4+zuXLlxFCEIvFqFarBEFAKpXCcRzq9TrpdJparcbIyAiHDh1icXERyzAMhBB4nofv\n+5imiWmavHr1inQ6jeM4ZLNZDMMglUqxuLiIlBLXdfn48SNKKXp6eqhUKiQSCaxkMsna2hqe52Hb\nNsMdec3n8+Pn2+vpETt37qSlpYVyucz8/DzT09Ns3bqVYrEIgOM4RCIRrI1MiUQCz/P43vE8jxcv\nXqCUwvM8Zmdn2bJlC6lUitHRUdrb2zFNE9/3sd6/f4/jOLiuSzKZDCH1wV/EzMwM3d3dNN69o729\nnXK5jFKKPXv2sLS0RF9fHydOnMD3fZRSaK0xtNYEQYBpmtTr9RC4b98+LMsCwLZtHj9+TCwWI5/P\nI6Xk5MmTXLhwAaUUG3MA4M6dOzQaDd68eYOUkqHIZj0U2ay11mzfvp1du3YhhGBgYIDjx4/T3d1N\nvV4nCAKklCilcF2XZrOJlBIBcOnSJc6ePYsQgj9yBf1l//7OJcXPH1Y1wK/Ff8SfvT995R9d/SA8\nzyMaja5Xq7Xm1q1bLCwssLS09M1Atm3bFr67urq+8W8oRUqJlBJLCMHNmze5d+8e2Ww2DPyrsSxq\ntRqZTAattZibm6PZbHJFVoUQgtOxtAbwfR8A13WJxWIYANVqFd/36e/v/ypzIpEgCAKEEMzNzYXN\n34CN/FsSvu+jtSaTyeC67jrw4cOHdHZ2kslkQmCz2SQSiYT269evMU0zhF2RVaH1ejt932dlZYXh\n4eF14MLCArZtI6UMAb+1/qBPx9L6jNOmAY4dO/b/agBnnDb9e1un3vhQzp8/z/Xr19eBQgjevn3L\n1NTUd5WilKJQKGAYxje+lpYWrl27xuTk5PqKARSLRfr6+hgaGiKbzfLy5UvGx8dRSqGUwnEcDMNA\nKYUQIlRGNBplZmaGw4cPE4/HOXDgAMbs7Cy9vb1cvHiR+fl5Hjx4QC6XwzAMYrEYz549Y3p6mufP\nn4d6NU0Tx3GYnJzk6NGjNJtNduzYQUdHB+LL8mu1Gv39/WitGRsb4/79+3R1dbF7925yuVw4/Uaj\nwalTpzhy5AhjY2P4vs/BgwdJp9OYG7ByuUwmk6FUKgFw7tw5SqUSlUqFp0+fkkgk2LRpEysrKzx5\n8oTBwUG01ty+fZv9+/eTz+dZXV3lP31rAEu+yXjEAAAAAElFTkSuQmCC",
        parameters => [
            { type => "bool",   desc => "如果可用，请保存原始标题，而不是英文或罗马拼音标题" },
            { type => "bool",   desc => "获取额外的时间戳（发布时间）和上传者元数据" },
            { type => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" }
        ],
        cooldown   => 4
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                           # Global info hash
    my ( $origin_title, $additional_tags, $db_path ) = @_;    # Plugin parameters

    my $logger = get_plugin_logger();

    my $path_in_archive = is_file_in_archive( $lrr_info->{file_path}, "info.json" );

    my ( $name, $path, $suffix ) = fileparse( $lrr_info->{file_path}, qr/\.[^.]*/ );
    my $path_nearby_json = $path . $name . '.json';

    my $filepath;
    my $delete_after_parse;

    #Extract info.json
    if ($path_in_archive) {
        $filepath = extract_file_from_archive( $lrr_info->{file_path}, $path_in_archive );
        $logger->debug("Found file in archive at $filepath");
        $delete_after_parse = 1;
    } elsif ( -e $path_nearby_json ) {
        $filepath = $path_nearby_json;
        $logger->debug("Found file nearby at $filepath");
        $delete_after_parse = 0;
    } else {
        return ( error => "No in-archive info.json or {archive_name}.json file found!" );
    }

    #Open it
    my $stringjson = "";

    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or return ( error => "Could not open $filepath!" );

    while ( my $row = <$fh> ) {
        chomp $row;
        $stringjson .= $row;
    }

    #Use Mojo::JSON to decode the string into a hash
    my $hashjson = from_json $stringjson;

    $logger->info("Loaded the following JSON: $stringjson");

    #Parse it
    my ( $tags, $title ) = tags_from_eze_json( $origin_title, $additional_tags, $hashjson );

    if ($delete_after_parse) {

        #Delete it
        unlink $filepath;
    }

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

#tags_from_eze_json(decodedjson)
#Goes through the JSON hash obtained from an info.json file and return the contained tags.
sub tags_from_eze_json {

    my ( $origin_title, $additional_tags, $hash ) = @_;
    my $return = "";

    #Tags are in gallery_info -> tags -> one array per namespace
    my $tags = $hash->{"gallery_info"}->{"tags"};

    # Titles returned by eze are in complete E-H notation.
    my $title = $hash->{"gallery_info"}->{"title"};

    if ( $origin_title && $hash->{"gallery_info"}->{"title_original"} ) {
        $title = $hash->{"gallery_info"}->{"title_original"};
    }

    $title = trim($title);

    foreach my $namespace ( sort keys %$tags ) {

        # Get the array for this namespace and iterate on it
        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

            $return .= ", " unless $return eq "";
            if($namespace eq "tag"){
                $return .= $tag;
            } else {
                $return .= $namespace . ":" . $tag;
            }

        }
    }

    my $logger = get_plugin_logger();
    # Add source tag if possible
    my $site        = $hash->{"gallery_info"}->{"source"}->{"site"};
    my $gid         = $hash->{"gallery_info"}->{"source"}->{"gid"};
    my $gtoken      = $hash->{"gallery_info"}->{"source"}->{"token"};
    my $link        = $hash->{"gallery_info"}->{"link"};
    my $category    = $hash->{"gallery_info"}->{"category"};
    my $language    = $hash->{"gallery_info"}->{"language"};
    my $translated  = $hash->{"gallery_info"}->{"translated"};
    my $uploader    = $hash->{"gallery_info_full"}->{"uploader"};
    my $timestamp   = $hash->{"gallery_info_full"}->{"date_uploaded"};

    if ($timestamp) {

        # convert microsecond to second
        $timestamp = $timestamp / 1000;
    } else {
        my $upload_date = $hash->{"gallery_info"}->{"upload_date"};
        my $time = timegm_modern( $$upload_date[5], $$upload_date[4], $$upload_date[3], $$upload_date[2], $$upload_date[1] - 1,
            $$upload_date[0] );
        $timestamp = $time;
    }

    if ($category) {
        $return .= ", category:$category";
    }

    if ($language) {
        $return .= ", language:$language";
    }

    if ($translated) {
        $return .= ", language:translated";
    }

    if ( $additional_tags && $uploader ) {
        $return .= ", uploader:$uploader";
    }

    if ( $additional_tags && $timestamp ) {
        $return .= ", timestamp:$timestamp";
    }

    if ( $site && $gid && $gtoken ) {
        $return .= ", source:$site.org/g/$gid/$gtoken";
    }
    elsif ( $link) {
        $return .= ", source:$link";
    }

    #Done-o
    return ( $return, $title );

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
