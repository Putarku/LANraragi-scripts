package LANraragi::Plugin::Metadata::ComicLooms;

use strict;
use warnings;

#Plugins can freely use all Perl packages already installed on the system
#Try however to restrain yourself to the ones already installed for LRR (see tools/cpanfile) to avoid extra installations by the end-user.
use Mojo::JSON qw(from_json decode_json);
use File::Basename;
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
        name        => "Comic Looms",
        type        => "metadata",
        namespace   => "comiclooms",
        author      => "zizzdog",
        version     => "1.1",
        description =>
          "https://github.com/MapoMagpie/eh-view-enhance下载器处理脚本，用于从档案中的meta.json获取标签，并翻译成中文(如果提供了翻译数据库)",
        icon =>
          "data:image/jpg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAAyADIDAREAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD9PP8AgvZZ22pf8Emvizpd9EJLe7j0S3uYieJIpNc09HQ+zKxBHcE046yQH5v+DP2APC3x38f/ABMt/gd+wb+x5pHhrwN8TdU8JadF4u+Hmt3WoXC2Qi/fyyW+pRxkt5g+6i9DxX5jxp4n4Dg/OngKuGlN8qldNJWbatr6HuZfktXMMP7WM0tbdT074g/8EjfA0/h7wxH8K/2If2P7bVY9I2+Mpdf+HWtTW9xf7j89msWpI0UO3A2yF2yCd2DgfG0vHrAucvaYGVr+7aabt53Ss/S53y4XqWXLUXnp/wAE5X/h0J4y/wCjOP2GP/DV+Iv/AJbVt/xHnKf+gKf/AIFEn/Vev/z8X3MzfGf/AASp8V+DfB+reL7n9i/9hqePStNnvJIU+FniINIsUbOVBOrcEhcVth/HPKsRiIUlg5rmaXxR6uxM+Ga8IOXtFp5M+kP+DdvSvhxZ+NvjB4i+Ffwj8P8AgTSvFnw7+FXiifwr4UgeLTrK91Hw7NdXPkJI7sqmRz95mOAMk4zX7mz5hn6fUAfIn/Bd7/lFT8Uf+uugf+n/AE6qj8SA+H9E/aD+LH7Fnxk+MXw/tdD+BWv2/iP4v6x4mtbjWv2o9C0G8t4rwQlYJ7K4jeWGRRH8wYg5PTjJ/IuPfCyrxhn7x8cWqfuqNuTm2bd78y79j6HLM7jl+G9k4X1b3t+hvf8AD0X4u/8ARKf2d/8AxNPw1/8AGK+L/wCIBV/+hgv/AAW//kz0f9aIf8+v/Jv+AbHhf/goH+0144s9W1HwV+zj8D9Yt9B01tQ12fS/2wfD9wmnWasqtcTtHbEQxBmUGR8KCwGeRT/4gFX/AOhgv/Bb/wDkw/1oh/z6/wDJv+Acj48/4KQfF/xp4G1rwcnw1/Z2t21bSbmzFwf20PDTCIyxMm7b5IzjdnGRnFb4XwIr4fEwq/X0+Vp29m+jv/ORPiaE4OPst/73/APcP+CDXw+1X4T/ABN+Kfwv1zVtLv73w98Hvg3p13e6HqKXdlcSQ+F5I2kgnj+SaIlSVkX5WUgjg1/RDPkWfpHSEfIn/Bd7/lFT8Uf+uugf+n/TqqPxID4f+A3wc+CnjHU/2lvFvxC8EeEjeQfHvxaD4m17w9Z3TWEaRwMJWa4QgpHkvtY7eDngmv5z8VMfmOH41jSoTnZxh7sZSV25S00e7201P0nhbD4epk0pTir3lq0nbRd+x4H/AMExPFXwD8GfEC3/AGTrf9kXQPjrous63PdTftC+CPhxcXFo9xPKSZNWN/b+RABwN1pcSwqqgLGvNdPEcMyxOE+vyxEsLKMUvYTqJOyX/LvlfM/+34xk3u2fm2c4enQxUnTrqon2uv8AgfddHW/tnfDj4bS/G/42+Avht8PdD8PW2r2fwn+FKw6LpMNrHPLrHiSbWNR3LEqhj9gsYQ2f4SO1fpPhDQxOMyqnKvNzdWrvJt6XjHr6M86VV0cvqVW9k3+B9IfGD9mP9my0+Enim6tf2e/A8UsXhy+eOSPwnZqyMLdyCCI8gg96/qzEYLBrDzapx2fRdvQ/OKOKxLrR997rq+5t/wDBuXHIreM5GjYK3wH+Cm1iODjwm+cV+GM/WWfp/SEfIn/Bd7/lFT8Uf+uugf8Ap/06qj8SA/PL4IfBj9u74r/HL9onVvgb8e/Cngjwpovx68SDTdH1jwqurJ4o1CQ2/nxahl0e3tEjCInkMJC8sjNlUVW/DfEqpw5R4jf1yjOpUlFXaly+zinKzhunJu7fMmrJJattejh+JsdlVONCjblTbaave/f7ulj2z/gk98OP2sPgL8GPEH7OP7T/AML7DQrTwd4nnT4fX2ja+moWN1otwzTR20LnE4S2dniXz0RhEYlwdhNfA8WYnKcfjKeMwVVzc4rnvHlamtG2tryVm+VtXu+p83i6lKtXdSmrJ9O3keA6RP8A8LT/AGr9CvLwecnjD9rnxt4keQHPmWHhDw1beHrU/wC6t5duQfXNf1T4Q5f7HAYCnbaDm/8At5OX5yOTOansckku9l97/wAj65+NH/JHfFn/AGLN/wD+k71/QeJ/3afo/wAj8+ofx4+q/Mu/8G+/xw+J3jr4Xy/BTxR4iW58NeA/gT8JH8LaeLOFDZm+8MeddZkVA8m+SNT87NtxhcAkV+BM/YGfopSEfIn/AAXe/wCUVPxR/wCuugf+n/TqqPxID8vvit8S/DOl/tNfGHT/AICfD79qSC2h+KWqL4lk8E/HbQNI0y51keWLqaC1urJ5Y0Y7MbmbgDnsPk+IKPCNTMW8ypRlUtu4t6XdtUvU+oyjgbPuIsJ9bwdFThdxvzRWq30bT6mZ/wALa+KP/Qn/ALZ//iTnhb/5X14n1bw6/wCgeH/gD/yPU/4hRxd/0Cr/AMDp/wDyRrfGGy+CPhY/D7wl8BfgD+0pNF4A8ParBZeNNC+NXh/StRvZtZ1D+09TW78+3l86Q3RH71QgYIoxhRX1GXcZZVgIr6tUlTsuVWT27aX00RrjfCLiqolSlQjUjo9Jxtft7zi7r0t2bOP8T+OdbHhvUD4l+G/7Y8mnCxl/tBH/AGl/C7K0Gw7wQNPyRtzxXqrxDhVfJ9bm76bS6/I8yfg5n9CDqSwUUo6/HDpr/MfoN/wQavPhzqHxN+Kd98H9G1TTvCk3we+Db+G9P1y7Se9trE+F5DBHPIiqskqx7QzKACwJAAOK6WfJM/SOkI+RP+C73/KKn4o/9ddA/wDT/p1VH4kB+X/inw5+0F8Kf2kPjZaal+xZ8cdYttb+MWs6xo+reGfhRqeoWV7ZTmIxTRTwxFHVgpOQTXxXEuQ5hmOaOrRS5bW1durP27w+46yDh3IXhMZKSnzylpFtWaXX5Dv+Ex+NP/Rhf7R//hjtZ/8AjNfP/wCqWc/yr7z7j/iLHCH88/8AwBh/wmPxp/6ML/aP/wDDHaz/APGaP9Us5/lX3h/xFjhD+ef/AIAzM8a678dNc8G6toth+wT+0aZ7zTJ4IQ3wQ1gAu8bKMnyeOSK1o8K5vCrGTirJrqc+L8U+Eq2EqU4yneUWl7j6o+3v+Df3wZ4t+HPjP4k/D/x94bvdG1zRPgt8GbHWNI1K2aG4srmLwrIksMsbAMjo6lWUgEEEHpX6ez+YmfpdSEfGH/Bw6zR/8EX/AI+TIxV4vClvJE4OCjrqFqysD2IIBB7EA0AfyML+2H+1uihE/al+IwAGAB43v8Af9/qG2wF/4bF/a6/6On+I/wD4XF//APHqAD/hsX9rr/o6f4j/APhcX/8A8eoAP+Gxf2uv+jp/iP8A+Fxf/wDx6gD9+f8Agyu8aeMfiJ8J/wBoPxh8QPFmp67q9x4q0GOfVNZv5Lq5kRLS5CK0shZiFBIAJwM8UAft5QB//9k=",
        parameters => [
            { type => "bool",   desc => "如果可用，请保存原始标题，而不是英文或罗马拼音标题" },
            { type => "string", desc => "EhTagTranslation项目的JSON数据库文件(db.text.json)的绝对路径" }
        ]
    );

}

#Mandatory function to be implemented by your plugin
sub get_tags {

    shift;
    my $lrr_info = shift;                           # Global info hash
    my ( $origin_title, $db_path ) = @_;    # Plugin parameters

    my $logger = get_plugin_logger();

    my $path_in_archive = is_file_in_archive( $lrr_info->{file_path}, "meta.json" );

    my $filepath;
    my $delete_after_parse;

    #解压提取 meta.json
    if ($path_in_archive) {
        $filepath = extract_file_from_archive( $lrr_info->{file_path}, $path_in_archive );
        $logger->debug("找到文件：$filepath");
        $delete_after_parse = 1;
    } else {
        return ( error => "No in-archive meta.json or {archive_name}.json file found!" );
    }

    #打开文件
    my $stringjson = "";

    open( my $fh, '<:encoding(UTF-8)', $filepath )
      or return ( error => "无法打开文件：$filepath!" );

    while ( my $row = <$fh> ) {
        chomp $row;
        $stringjson .= $row;
    }

    #使用Mojo::JSON库解析json为hash对
    my $hashjson = from_json $stringjson;

    $logger->info("Loaded the following JSON: $stringjson");

    #解析json为标签
    my ( $tags, $title ) = tags_from_meta_json( $origin_title, $hashjson );

    # 删除解压的文件
    if ($delete_after_parse) {
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

#tags_from_meta_json(decodedjson)
#Goes through the JSON hash obtained from an meta.json file and return the contained tags.
sub tags_from_meta_json {

    my ( $origin_title, $hash ) = @_;

    # 构建返回值，第一个填入原始链接
    my $return = "";
    my $url = $hash->{"url"};
    # 判断是否为禁漫
    my $is_JM = 0;
    if ($url =~ /^(https?:\/\/.*comic.*\/album\/\d+)/) {
        $url = $1;
        $is_JM = 1;
    }
    
    $return .= "source:" . $url;
    
    # 提取tags键的数据
    my $tags = $hash->{"tags"};

    foreach my $namespace ( sort keys %$tags ) {

        # 对每个tags键值进行分割组装成字符串
        my $members = $tags->{$namespace};
        foreach my $tag (@$members) {

            $return .= ", " unless $return eq "";

            #来自禁漫的标签直接是中文，无法用翻译数据库反向分类
            if($is_JM) {
                if($namespace eq "works"){
                    $return .= "原作:" . $tag;
                } elsif($namespace eq "author"){
                    $return .= "艺术家:" . $tag;
                } elsif($namespace eq "actor"){
                    $return .= "角色:" . $tag;
                } elsif($namespace eq "tags"){
                    $return .= $tag;
                } else {
                    $return .= $namespace . ":" . $tag;
                }
            } elsif($namespace eq "tag") {
                $return .= $tag;  
            }
            else {
                $return .= $namespace . ":" . $tag;
            }

        }
    }

    # 提取标题
    my $title = $hash->{"title"};

    # 根据需要提取原始标题
    if ( $origin_title && $hash->{"originTitle"} ) {
        $title = $hash->{"originTitle"};
    }

    $title = trim($title);

    # 返回数据
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
