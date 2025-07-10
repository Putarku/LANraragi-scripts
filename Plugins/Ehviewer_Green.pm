package LANraragi::Plugin::Metadata::Ehviewer_Green;

use strict;
use warnings;
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json decode_json);

#You can also use the LRR Internal API when fitting.
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
require LANraragi::Plugin::Metadata::EHentai;

# Meta-information about the plugin.
sub plugin_info {

    return (
        # Standard metadata:
        name        => 'Ehviewer Green',
        type        => 'metadata',
        namespace   => 'ehviewergreen',
        login_from  => "ehlogin",
        author      => 'zizzdog',
        version     => '1.0.5',
        description => '解析绿色版Ehviewer下载文件中的.ehviewer提供的Gid和Token直接打开画廊获取元数据，若提供tag翻译json文件则进行翻译',
        icon => 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAQXSURBVEhLtZXNT1RnFMbfO5e2YtKmXXXTjRsTV+1CF03T9g+ouybdNKZpHeRrEJgZmC+ZAUEcBgexLahoWpu0VoM1UrAiMiMGRLFKIqO1RsuHJtWmWoR/4Olz3nvvwEwHicYuHt5779x7fu85zzkvSnU0Qmtv0/+jDkr/KfTji5RR6OGL1jNBVirratV4nkxepkzqFbnX4FU8fbZMYjASEXx1ZRSZ+/dwanICKh6GStqQlTLNQuSFPVF81nccoeHTCKd+QSR1Jiu5b+D6Bt/bdLgTJ38dR/rGFFTdNn7XYH2/KkTEl5MjQ5icuYu/Hj/C0PXJrEZ/y2BhYQHrol6YfK97NI30zetQvhKoQBlU+44lkPZoGTAnE8oVD8Fz7Aimpu/CrP4cZs0XMGvd2LgrhMXFRawLV+OlQAW6xy9oiOEvgRnywNhRDTMZYwyRHc8B5UPMZBSVAycwNfMHXDVb9U4NrxuvByvx0dd7UBwoh8tfii6WTiBFPjc2JXfik2/34+19rUsZaUA+xAYJxNPfa0FqCaHWNwexNsjd1rEslFFXiu70IEboSUfqLG7cm0OGevjob7zT2crmIEhnZW28ACQGz0AvMjPTKPaWYE3Zpxi7fQsfdO5GUaCS9a+AUV+G/efPYv7JE5Qe/w6vharwaqgC/YQemxiHavTpJsqCCkGqBn7C4/l5zD18gNkHf/L6H3z4ZRyukEDKdUZdqUGcZzPIvUv8CJbj4NgIzt1kx8W8UDvrLNBqmaz1bsOayi24dOc23t8X1wZrSLBCe5KSgLxW4Sr9rGfUhkgmTX6oloCVTWGIbTwhRm0JNh/sxJvcXZFkEqY3VBc90RB5Fq2FwQ30MJNhB9IShGJHqlZqCWKZZDJFgWRmp+HycdBk5/Wlum038KPiBglYhS56kpaAke0M6tfgnrELGJYBbWYGAhEVgrhsiM5EppllcFFvxXx6Tt6jN0ZEIEPMhMNIPzQk4sGhi4QIWMrkAHbnQCgC3DxWTmUmtemxn09oNfafROJMn574d/e24OMjB5Cm6bfuz2HL0W+gGqqxmXNy6c7vbOVZuHu/t0ACkLMtC5Eu4HHRfO40frw8ZunKRWo8RxviEWznRo5O8LdrEwgN9hFSgzJuRu5/uHoZjYyhWuqh2ghoi+RBRDxllZ9l4pTrw4+taYldJCvPLtm5LpOIpqtdLE0TW5Zl060rAB5PGpDg4ZlTLhtksMMMGpoVg2lJQOkcymCLGjqgGGx5YNADwymRzoKAHIgAnGvpbRkkCSq7lQ6S1QZo6TmwO8gxWaQzIECCt/F4STDOfzJZDhJJcNY8ByBaCZBYDnAyedr/Z4EKSHadBfA6fw5EUiYnA1E7M3BWy4cVALI6pZP6CyQfoD0QgG1yex4gEcW/X0p3UAMSG4wAAAAASUVORK5CYII=',

        # Custom arguments:
        parameters => [
            { type => 'bool', desc => '如果可用，保存原始标题而不是英文或罗马拼音标题' },
            { type => 'bool', desc => '保存额外的时间戳（发布时间）和上传者元数据' },
            { type => 'bool', desc => '使用 ExHentai 链接作为源而不是 E-Hentai 链接' },
            { type => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" },
        ],
        
        oneshot_arg => '输入有效的 EH 库 URL 以将此 EH 库中的元数据复制到此 LANraragi 存档',
        cooldown    => 4
    );
}

# Mandatory function implemented by every plugin.
sub get_tags {

    shift;
    my $lrr_info      = shift;
    my $ua            = $lrr_info->{user_agent};
    my $logger        = get_plugin_logger();
    my $gallery_id    = '';
    my $gallery_token = '';
    my ( $save_jpn_title, $save_additional_metadata, $use_exhentai, $db_path ) = @_;

    # 首先从给定链接获取GID和Token
    if ( $lrr_info->{oneshot_param} =~ /e(?:x|-)hentai\.org\/g\/(\d+)\/([0-9a-z]+)/i ) {
        $gallery_id    = $1;
        $gallery_token = $2;
        $logger->debug("Directly using gallery ID $gallery_id and token $gallery_token from oneshot parameters.");
    }
    # 没有则从tag中的source寻找链接中的GID和Token
    elsif ( $lrr_info->{existing_tags} =~ /source:e(?:x|-)hentai\.org\/g\/(\d+)\/([0-9a-z]+)/i ) {
        $gallery_id    = $1;
        $gallery_token = $2;
        $logger->debug("Directly using gallery ID $gallery_id and token $gallery_token from source tag.");
    } 
    # 最后才使用压缩包内.ehviewer附带的GID和Token
    else {
        #获取压缩包内.ehviewer文件
        my $path_in_archive = is_file_in_archive( $lrr_info->{file_path}, ".ehviewer" );

        my $filepath;
        my $delete_after_parse;

        #把.ehviewer从解压包提取出来
        if($path_in_archive) {
            $filepath = extract_file_from_archive( $lrr_info->{file_path}, $path_in_archive );
            $logger->debug("Found file in archive at $filepath");
            $delete_after_parse = 1;
        } else {
            return ( error => "No in-archive .ehviewer file found!" );
        }

        #打开.ehviewer
        open( my $fh, '<:encoding(UTF-8)', $filepath )
            or return ( error => "Could not open $filepath!" );

        #读取.ehviewer第三行和第四行的画廊Gid和Token
        while( <$fh> ) {
            if( $. == 3 ) {
                $gallery_id = $_;
                chomp $gallery_id;

                $logger->debug("Gid:" . $gallery_id);
            }elsif( $. == 4 ) {
                $gallery_token = $_;
                chomp $gallery_token;

                $logger->debug("Gtoken:" . $gallery_token);
                last;
            }
        }

        #删除解压的文件
        if ($delete_after_parse){
            unlink $filepath;
        }

        if ( $gallery_id eq '' || $gallery_token eq '' ) {
            my $file_error = '没有找到画廊的Gid或Token，搜索失败';
            $logger->error($file_error);
            return ( error => $file_error );
        }
    }

    # 访问tags数据库
    $logger->info('找到画廊的Gid和Token，访问EH API获取tags.');
    my ( $eh_all_tags, $eh_title ) = LANraragi::Plugin::Metadata::EHentai::get_tags_from_EH( $ua, $gallery_id,
        $gallery_token, $save_jpn_title, $save_additional_metadata );

    # 获取到空tags，终止匹配
    if ( $eh_all_tags eq "" ) {
        my $source_error = '没有匹配的画廊，搜索失败！';
        $logger->error($source_error);
        return ( error => $source_error );
    }
    
    # 在tags中添加source信息
    my $host = ( $use_exhentai ? 'exhentai.org' : 'e-hentai.org' );
    $eh_all_tags .= ", source:$host/g/$gallery_id/$gallery_token";

    # 构建哈希结构数据
    my %hashdata = ( tags => $eh_all_tags, title => $eh_title );

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
