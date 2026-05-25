package LANraragi::Plugin::Scripts::SourceBatch;

use strict;
use warnings;
no warnings 'uninitialized';
use utf8;

# 上传时 LRR 会 require 本文件并立刻调用 plugin_info()。
# 顶层不要 use LANraragi::*：否则 require 阶段会拉一整条依赖链，易失败。
# 也不要顶层 use LANraragi::Utils::Plugins（会与 Module::Pluggable 循环加载）。
# 所有 LRR 依赖在 run_script 开头 require；下方子程序一律全限定名调用。

sub plugin_info {

    return (
        name        => "Source 批量补全",
        type        => "script",
        namespace   => "sourcebatch",
        author      => "custom",
        version     => "1.0.3",
        description => qq{批量处理 source 标签：<br>
          <b>1)</b> 对<b>没有 source:</b> 标签的画廊，按顺序依次运行您指定的多个<b>元数据插件</b>（namespace），可设置多轮尝试。<br>
          <b>2)</b> 为已有 source 中缺少协议的网址补全 <code>https://</code>（含 <code>//</code> 协议相对 URL、无协议的域名；可选将 <code>http://</code> 升为 <code>https://</code>）。<br>
          <i class="fa fa-info-circle"></i> 请在参数中填写元数据插件的 <b>namespace</b>（逗号分隔），与插件设置页中的标识一致。},
        icon =>
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
        oneshot_arg => "可选：仅处理此档案 ID（40 位十六进制），留空则处理全部",
        parameters  => {
            plugin_names => {
                type          => "string",
                desc          => "要依次运行的元数据插件 namespace，逗号分隔（例：nhplugin_cn,nhentaiv2）。留空则跳过「无 source 时跑插件」步骤。",
                default_value => ""
            },
            rounds => {
                type          => "string",
                desc          => "对每个仍缺 source 的画廊，将上述插件列表完整执行的次数（整数 >=1，用于多次检索尝试）。",
                default_value => "1"
            },
            run_metadata_plugins => {
                type          => "bool",
                desc          => "对无 source 的画廊执行上方元数据插件（关闭则只做网址 https 补全）。",
                default_value => 1
            },
            stop_when_source_found => {
                type          => "bool",
                desc          => "某一插件已为该画廊写入 source 后，同一轮内不再运行后续插件（节省请求）。",
                default_value => 1
            },
            normalize_https => {
                type          => "bool",
                desc          => "为所有含 source: 的标签补全/规范为 https（见下方子选项）。",
                default_value => 1
            },
            upgrade_http_to_https => {
                type          => "bool",
                desc          => "将 source 中的 http:// 改为 https://（与「补全缺失协议」可同时开启）。",
                default_value => 1
            }
        },
        cooldown => 2
    );
}

sub _dedupe_tags {
    my @a = @_;
    my %seen;
    return grep { !$seen{$_}++ } @a;
}

sub archive_tags_have_source {
    my ($tags) = @_;
    return 0 unless defined $tags && $tags ne '';
    return $tags =~ /(?:^|,\s*)source\s*:/i ? 1 : 0;
}

sub normalize_source_value {
    my ( $value, $upgrade_http ) = @_;
    $value = LANraragi::Utils::String::trim($value);
    return $value if $value eq '';

    if ( $value =~ /^https:\/\//i ) {
        return $value;
    }
    if ( $value =~ /^http:\/\//i ) {
        if ($upgrade_http) {
            $value =~ s/^http:/https:/i;
        }
        return $value;
    }
    if ( $value =~ /^\/\// ) {
        return 'https:' . $value;
    }
    if ( $value =~ /^(?:www\.)?[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}/ ) {
        return 'https://' . $value;
    }

    return $value;
}

sub normalize_tags_string_sources {
    my ( $tags, $upgrade_http ) = @_;

    my @parts = LANraragi::Utils::Tags::split_tags_to_array($tags);
    my $changed = 0;

    for my $tag (@parts) {
        next unless $tag =~ /^source\s*:\s*(.+)$/i;
        my $rest = $1;
        my $newrest = normalize_source_value( $rest, $upgrade_http );
        if ( $newrest ne $rest ) {
            $tag = 'source:' . $newrest;
            $changed = 1;
        }
    }

    return ( $changed, LANraragi::Utils::Tags::join_tags_to_string(@parts) );
}

# 不依赖 LANraragi::Utils::Path（部分侧载/精简环境无 Path.pm）；与 core 的 get_archive_path 在 Unix 上等价。
sub _local_get_archive_path {
    my ( $redis, $id ) = @_;
    my $file = $redis->hget( $id, "file" );
    return unless defined $file && $file ne '';
    return $file;
}

# 旧版 LANraragi 的 Generic.pm 可能没有 exec_with_lock_pure；与侧载脚本一致时直接写库。
sub _exec_with_archive_lock {
    my ( $id, $code ) = @_;
    my $generic = 'LANraragi::Utils::Generic';
    if ( $generic->can('exec_with_lock_pure') ) {
        return LANraragi::Utils::Generic::exec_with_lock_pure( ["archive-write:$id"], $code );
    }
    my $response = eval { $code->(); };
    die $@ if $@;
    return ( 1, $response );
}

sub collect_archive_ids {
    my ( $redis, $oneshot ) = @_;

    if ( defined $oneshot && $oneshot ne '' ) {
        my $id = LANraragi::Utils::String::trim($oneshot);
        return () unless $redis->exists($id);
        return ($id);
    }

    my @keys = $redis->keys('????????????????????????????????????????');
    return @keys;
}

sub apply_metadata_plugin_result {
    my ( $id, $plugin_result ) = @_;

    if ( exists $plugin_result->{error} ) {
        return ( 0, $plugin_result->{error} );
    }

    my ( $acquired, undef ) = _exec_with_archive_lock(
        $id,
        sub {
            if ( length( $plugin_result->{new_tags} // '' ) ) {
                LANraragi::Utils::Database::set_tags( $id, $plugin_result->{new_tags}, 1 );
            }
            if ( exists $plugin_result->{title} && LANraragi::Model::Config->can_replacetitles ) {
                LANraragi::Utils::Database::set_title( $id, $plugin_result->{title} );
            }
            if ( exists $plugin_result->{summary} ) {
                LANraragi::Utils::Database::set_summary( $id, $plugin_result->{summary} );
            }
        }
    );

    if ( !$acquired ) {
        return ( 0, "无法获取档案写入锁: $id" );
    }

    return ( 1, undef );
}

sub _load_runtime_deps {

    require LANraragi::Model::Config;
    require LANraragi::Model::Plugins;
    require LANraragi::Utils::Database;
    require LANraragi::Utils::Generic;
    require LANraragi::Utils::Logging;
    require LANraragi::Utils::Plugins;
    require LANraragi::Utils::Redis;
    require LANraragi::Utils::String;
    require LANraragi::Utils::Tags;

    return 1;
}

sub run_script {

    shift;
    my $lrr_info = shift;
    my $params     = shift;
    $params = {} if ref($params) ne 'HASH';

    _load_runtime_deps();

    my $logger = LANraragi::Utils::Logging::get_plugin_logger();

    my $plugin_names_raw = $params->{plugin_names} // '';
    my $rounds             = int( $params->{rounds} // 1 );
    $rounds = 1 if $rounds < 1;

    my $run_metadata = $params->{run_metadata_plugins};
    $run_metadata = 1 if !defined $run_metadata;

    my $stop_on_source = $params->{stop_when_source_found};
    $stop_on_source = 1 if !defined $stop_on_source;

    my $do_https = $params->{normalize_https};
    $do_https = 1 if !defined $do_https;

    my $upgrade_http = $params->{upgrade_http_to_https};
    $upgrade_http = 1 if !defined $upgrade_http;

    my @namespaces = grep { $_ ne '' }
      map { LANraragi::Utils::String::trim($_) } split( /,/, $plugin_names_raw );

    my $redis = LANraragi::Model::Config->get_redis;

    if ( defined $lrr_info->{oneshot_param} && $lrr_info->{oneshot_param} ne '' ) {
        my $oid = LANraragi::Utils::String::trim( $lrr_info->{oneshot_param} );
        unless ( $redis->exists($oid) ) {
            $redis->quit;
            return ( error => "指定的档案 ID 不存在: $oid" );
        }
    }

    my @ids = collect_archive_ids( $redis, $lrr_info->{oneshot_param} );

    my %report = (
        archives_total            => scalar @ids,
        metadata_archives_scanned => 0,
        metadata_plugins_run      => 0,
        metadata_errors           => 0,
        https_archives_changed    => 0,
        https_unchanged           => 0
    );

    if ( $run_metadata && @namespaces ) {

        for my $id (@ids) {
            my $file = _local_get_archive_path( $redis, $id );
            unless ( defined $file && $file ne '' && -e $file ) {
                next;
            }

            my %h = $redis->hgetall($id);
            my $tags = LANraragi::Utils::Redis::redis_decode( $h{tags} // '' );

            $report{metadata_archives_scanned}++;

            next if archive_tags_have_source($tags);

            for my $r ( 1 .. $rounds ) {
                %h = $redis->hgetall($id);
                $tags = LANraragi::Utils::Redis::redis_decode( $h{tags} // '' );
                last if archive_tags_have_source($tags);

                for my $ns (@namespaces) {
                    my $plugin = LANraragi::Utils::Plugins::get_plugin($ns);
                    unless ($plugin) {
                        $logger->error("未找到元数据插件 namespace: $ns");
                        $report{metadata_errors}++;
                        next;
                    }

                    my %pluginfo = $plugin->plugin_info();
                    unless ( ( $pluginfo{type} // '' ) eq 'metadata' ) {
                        $logger->error("插件 $ns 不是元数据插件 (type=$pluginfo{type})");
                        $report{metadata_errors}++;
                        next;
                    }

                    my %settings = LANraragi::Utils::Plugins::get_plugin_parameters($ns);
                    my %plugin_result =
                      LANraragi::Model::Plugins::exec_metadata_plugin( $plugin, $id, %settings );

                    $report{metadata_plugins_run}++;

                    my ( $ok, $err ) = apply_metadata_plugin_result( $id, \%plugin_result );
                    if ( !$ok ) {
                        $logger->error("档案 $id 插件 $ns: $err");
                        $report{metadata_errors}++;
                    }

                    %h    = $redis->hgetall($id);
                    $tags = LANraragi::Utils::Redis::redis_decode( $h{tags} // '' );

                    if ( $stop_on_source && archive_tags_have_source($tags) ) {
                        last;
                    }
                }

                last if archive_tags_have_source($tags);
            }
        }
    }
    elsif ( $run_metadata && !@namespaces ) {
        $logger->info("未填写 plugin_names，跳过「无 source 时跑元数据插件」步骤。");
    }

    if ($do_https) {

        for my $id (@ids) {
            my $file = _local_get_archive_path( $redis, $id );
            unless ( defined $file && $file ne '' && -e $file ) {
                next;
            }

            my %h    = $redis->hgetall($id);
            my $tags = LANraragi::Utils::Redis::redis_decode( $h{tags} // '' );

            next unless archive_tags_have_source($tags);

            my ( $changed, $newtags ) = normalize_tags_string_sources( $tags, $upgrade_http );
            if ($changed) {
                my ( $acquired, undef ) = _exec_with_archive_lock(
                    $id,
                    sub {
                        LANraragi::Utils::Database::set_tags(
                            $id,
                            LANraragi::Utils::Tags::join_tags_to_string(
                                _dedupe_tags( LANraragi::Utils::Tags::split_tags_to_array($newtags) )
                            ),
                            0
                        );
                    }
                );
                if ($acquired) {
                    $report{https_archives_changed}++;
                }
                else {
                    $logger->error("https 补全：无法锁定档案 $id");
                }
            }
            else {
                $report{https_unchanged}++;
            }
        }
    }

    $redis->quit;

    my $summary = sprintf(
        "完成。档案总数=%d；元数据扫描=%d，插件调用次数=%d，元数据错误=%d；https 补全变更=%d，已有 source 且无需改协议=%d。",
        $report{archives_total},
        $report{metadata_archives_scanned},
        $report{metadata_plugins_run},
        $report{metadata_errors},
        $report{https_archives_changed},
        $report{https_unchanged}
    );

    $logger->info($summary);

    return (
        %report,
        message => $summary
    );
}

1;
