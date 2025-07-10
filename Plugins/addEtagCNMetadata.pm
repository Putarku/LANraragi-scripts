package LANraragi::Plugin::Scripts::addEtagCNMetadata;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Plugins qw(use_plugin);
use LANraragi::Utils::Database qw(set_tags);
use LANraragi::Model::Archive;

# Meta-information
sub plugin_info {
    return (
        name        => "Add EtagCN Metadata",
        type        => "script",
        namespace   => "addetagcnmetadata",
        author      => "fl0w1nd",
        version     => "1.0",
        description => "Using the EtagCN plugin to search for metadata for files that do not have a source tag. If no matching E-Hentai Gallery found, will add source:nogalleryinehentai",
        oneshot_arg => "Search gallery again with source:nogalleryinehentai. True/False",
        parameters => [
            { type => "int", desc => "Timeout in seconds between requests (recommended: 4 seconds)" },
            { type => "string", desc => "EhTagTranslation JSON database file absolute path (db.text.json)" }
        ]
    );
}

sub run_script {
    shift;
    my $lrr_info = shift;
    my $logger   = get_plugin_logger();
    my $success = 0;
    my $total = 0;
    my $nogalleryinehentai = $lrr_info->{oneshot_param};
    my $timeout = $lrr_info->{parameters}[0] || 10;
    my $db_path = $lrr_info->{parameters}[1] || "";
    
    $logger->info("Using timeout: $timeout seconds");

    $logger->info("Starting EtagCN Metadata script...");

    # 获取所有档案
    my @archives = LANraragi::Model::Archive->generate_archive_list;
    for my $archive (@archives) {
        my $arcid = $archive->{"arcid"};
        my $title = $archive->{"title"};
        my $old_tags = $archive->{"tags"};

        # 跳过已有`source`标签的档案
        next if $old_tags =~ /\bsource\b/;

        $logger->info("Processing archive '$title' with ID '$arcid'");
        $total++;

        # 调用ETagCN插件
        my ($etagcn_plugin_info, $etagcn_tags);
        eval {
            ($etagcn_plugin_info, $etagcn_tags) = use_plugin("etagcn", $arcid, $db_path);
        };
        if ($@) {
            $etagcn_tags->{error} = $@;
        }
        
        # 在调用插件后立即延时，避免频繁请求导致被网站封锁
        if ($timeout > 0) {
            $logger->info("Waiting for $timeout seconds before processing next archive...");
            sleep($timeout);
        }


        use Data::Dumper;
        $logger->info("ETagCN plugin returned for '$title': " . Dumper($etagcn_tags));

        if (exists $etagcn_tags->{error}) {
            $logger->warn("ETagCN plugin returned an error for '$title': " . $etagcn_tags->{error});
            if ($etagcn_tags->{error} eq "No matching EH Gallery Found!") {
                $etagcn_tags->{tags} = "source:nogalleryinehentai";
                $logger->info("Adding fallback tag for '$title': " . $etagcn_tags->{tags});
            } else {
                next;
            }
        }


        if (exists $etagcn_tags->{new_tags} && $etagcn_tags->{new_tags} ne "") {
            my $retrieved_tags = $etagcn_tags->{new_tags};
            $logger->info("Retrieved tags from ETagCN for '$title': $retrieved_tags");

            # 拼接旧标签与新标签
            my $new_tags_str = join(", ", grep { $_ ne "" } ($old_tags, $retrieved_tags));


            # 对标签进行去重和排序
            my %tags_hash = map { $_ => 1 } split(', ', $new_tags_str);
            my @sorted_tags = sort keys %tags_hash;
            my $sorted_tags_str = join(", ", @sorted_tags);

            $logger->info("Old tags for '$title': $old_tags");
            $logger->info("Final sorted tags for '$title': $sorted_tags_str");

            # 确保最终生成的标签与旧标签不同
            if ($sorted_tags_str ne $old_tags) {
                eval {
                    set_tags($arcid, $sorted_tags_str, 0);
                    $logger->info("Tags updated for archive '$title': $sorted_tags_str");
                    $success++;
                };
                if ($@) {
                    $logger->error("Failed to set tags for archive '$title': $@");
                }
            } else {
                $logger->info("No changes detected for '$title', skipping update.");
            }
        } else {
            $logger->warn("No tags returned by ETagCN plugin for '$title', skipping update.");
        }

        # 延时已在调用插件后立即执行，此处不再需要
    }

    $logger->info("Completed processing: $success archives updated out of $total processed.");

    return (modified => $success, total => $total);
}


1;