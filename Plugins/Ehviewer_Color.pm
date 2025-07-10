package LANraragi::Plugin::Metadata::Ehviewer_Color;

use strict;
use warnings;

use Mojo::DOM;
use utf8;
#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json decode_json);

#You can also use the LRR Internal API when fitting.
use LANraragi::Model::Plugins;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Archive qw(is_file_in_archive extract_file_from_archive);

#Meta-information about your plugin.
sub plugin_info {

    return (
        #Standard metadata
        name         => "Ehviewer Color",
        type         => "metadata",
        namespace    => "ehviewercolor",
        author       => "zizzdog",
        version      => "1.0.5",
        description  => "解析彩色版Ehviewer下载的cbz存档中嵌入的 ComicInfo.xml 中的元数据，若提供tag翻译json文件则进行翻译",
        icon =>
          "data:image/jpg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAAZABkDAREAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9hf2v/wBqD4i/Abx38OPAnw68KaVqdx44146fL/aZk/d5aNF2bHUAkydWyOPxr5bizM87y7L3/ZNOE8Q1LkjO/K5Je6naUbJvS99DwMxzynlme5fhKy/dYiooTl1jFtJuO+qvfVPaxvaL8Sv2hbXxdpGjePvCfhfTrXUrwQ5OobJpB1bygZSXYDnaAfw61+Y5DxJ46Vs7w9HN8rw1PDzklOUZtSUerj+9ldpapcru9NN1+tYnJ+EZ4CtVwNarOUI3+G6XbmfIrJvq2j1mv3c+ECgD5b/b+Xw8fjN8GZJ5J/7fXxOT4WjUfuXvfNt/LEv+zu2+gxnmvyTxSqcf03gXwtCnKpzvm9p8uW12lvvqcEqfAc87wn+sc6kZKS9jybOfNH4rJvtbpvd7Hin7e13+0Uf2lf2fW8cWmlx6iPHEf9grasux5/tllgPhjxu2DnHBNfCwr+Msot57ToxxK/3ZQa5XU6KdpPTm5N2tLn9c+G1PhH/VPP8A6lKbp+wftL3uo8lXbTe1/wAD3j4LftO/HjV/219Z/Zh+Kul6Mltp/hcagkljERIsmIWHzBiCCsuMY4xX9RcIcMcSQ8IsNn3EsksfOtOMowt7NQvJRtZvW0bt33la2h/ImaZzgZcbVcsy9f7PGCabvzN2Td79NbbdD6XriPRPnr9tP9nn4v8Axg+JPwt8f/CeLTHfwT4jOoXi6jc+WMB4nXAx83MZBGR1FfJ8W4XPa2AdXJ4xliIKTgpu0ef7PNtpffXY+azXIpZrxBltebtRo1VKp35bxb5dHd2Vl5nN/Hz9mD9pD4+fFr4L/EjX18P2/wDwgXjYajrSwXLKfsqz2swKDB3MfIdcZ/iX3r5fIcu8QMzw+Fr8SRoxr0qrbVJu3JeLW99dHs+x/R/DnGPCPDOSZzgMP7R/W6HJC6XxuNSLu9LL309ujOs8O/s0fEHTP+ChWvftO3M9j/wjmo+Eo7C2VZyZzOFgQgpjgDySc57j3r+lMTxNl1Xw7o5LFP20ark9NLXk9/8At4/m2lk+LhxXUzF29m4JLvfRbfI99r8/PqAoAKACgAoA/9k=",
          
        parameters => [ 
            { type => "bool",   desc => "只获取标题，以供其他插件使用" },
            { type => "bool",   desc => "只获取源链接，以供其他插件使用" },
            { type => "bool",   desc => "如果可用，保存原始标题而不是英文或罗马拼音标题" },
            { type  => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" }
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift; # Global info hash, contains various metadata provided by LRR
    my ($only_title, $only_source, $save_jpn_title, $db_path) = @_;

    #Use the logger to output status - they'll be passed to a specialized logfile and written to STDOUT.
    my $logger = get_plugin_logger();

    my $file = $lrr_info->{file_path};
    my $path_in_archive = is_file_in_archive( $file, "ComicInfo.xml" );

    if ( !$path_in_archive ){
        return ( error => "No ComicInfo.xml file found in archive");   
    }
        
    #Extract ComicInfo.xml
    my $filepath = extract_file_from_archive( $file, $path_in_archive );

    #Read file into string
    my $stringxml = "";
    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or return ( error => "Could not open $filepath!" );
    while ( my $line = <$fh> ) {
        chomp $line;
        $stringxml .= $line;
    }

    #Parse file into DOM object and extract tags
    my $genre;
    my $groups;
    my $url;
    my $artists;
    my $lang;
    my $title;
    my $jpn_title;
    my $parodies;
    my $characters;

    # 解析 XML 并提取所需标签
    my $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Genre');
    if (defined $result) {
        $genre = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Web');
    if (defined $result) {
        $url = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Writer');
    if (defined $result) {
        $groups = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Penciller');
    if (defined $result) {
        $artists = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('LanguageISO');
    if (defined $result) {
        $lang = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Series');
    if (defined $result) {
        $title = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Teams');
    if (defined $result) {
        $parodies = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('Characters');
    if (defined $result) {
        $characters = $result->text;
    }
    $result = Mojo::DOM->new->xml(1)->parse($stringxml)->at('AlternateSeries');
    if (defined $result) {
        $jpn_title = $result->text;
    }

    # 删除本地文件
    unlink $filepath;

    # 返回指定语言标题
    if ($save_jpn_title) {
        $title = $jpn_title;
    }
    $logger->info("返回标题：" . $title );
    
    #根据选项返回标题和来源
    if($only_title || $only_source){        
        my %only_hashdata;
        if($only_source){
            my $tags_source = ("source:". $url);
            $logger->info("提取的source是：". $tags_source);
            $only_hashdata{tags} = $tags_source;
        }
        if($only_title){
            $only_hashdata{title} = $title;
        }
        return %only_hashdata;
    }

    # 处理语言 ISO 代码到小写的全称
    my %lang_map = (
        'ja' => 'japanese',
        'en' => 'english',
        'zh' => 'chinese',
        'nl' => 'dutch',
        'fr' => 'french',
        'de' => 'german',
        'hu' => 'hungarian',
        'it' => 'italian',
        'ko' => 'korean',
        'pl' => 'polish',
        'pt' => 'portuguese',
        'ru' => 'russian',
        'es' => 'spanish',
        'th' => 'thai',
        'vi' => 'vietnamese',
    );
    if (exists $lang_map{$lang}) {
        $lang = $lang_map{$lang};
    }

    # 添加前缀并拼接
    my @found_tags;
    @found_tags = try_add_tags(\@found_tags, "source:", $url);
    @found_tags = try_add_tags(\@found_tags, "language:", $lang);
    @found_tags = try_add_tags(\@found_tags, "parody:", $parodies);
    @found_tags = try_add_tags(\@found_tags, "group:", $groups);
    @found_tags = try_add_tags(\@found_tags, "artist:", $artists);
    @found_tags = try_add_tags(\@found_tags, "character:", $characters);

    # 处理 genres 并去除前缀
    my @genres = split(',', $genre);
    foreach my $genre_tag (@genres) {
        $genre_tag = trim($genre_tag); # 移除空格
        if ($genre_tag =~ /^m:/) { # 以 m: 开头，移除 m:，添加到 male: 下
            push(@found_tags, "male:" . substr($genre_tag, 2));
        } elsif ($genre_tag =~ /^f:/) { # 以 f: 开头，移除 f:，添加到 female: 下
            push(@found_tags, "female:" . substr($genre_tag, 2));
        } else { # 其他的直接添加到 other:
            push(@found_tags, "other:" . $genre_tag);
        }
    }
    my $tags = join(", ", @found_tags);

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

sub try_add_tags {
    my @found_tags = @{$_[0]};
    my $prefix = $_[1];
    my $tags = $_[2];
    my @tags_array = split(',', $tags);

    foreach my $tag (@tags_array) {
        push( @found_tags, $prefix . trim($tag) );
    }
    return @found_tags;
}

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

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