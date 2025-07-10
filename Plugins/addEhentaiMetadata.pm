package LANraragi::Plugin::Scripts::addEhentaiMetadata;

use strict;
use warnings;
no warnings 'uninitialized';

use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Plugins qw(use_plugin);
use LANraragi::Utils::Database qw(set_tags);
use LANraragi::Model::Archive;

# Meta-information about your plugin.
sub plugin_info {

    return (
        # Standard metadata
        name        => "Add Ehentai Metatdata",
        type        => "script",
        namespace   => "addehentaimetatdata",
        author      => "CHUSHEN",
        version     => "1.5",
        description => "Using the Ehentai plugin to search for metadata for files that do not have a source tag. If No matching EH Gallery Found!, will add source:nogalleryinehentai",
        oneshot_arg => "Search gallery again with source:nogalleryinehentai. True/False",
        parameters => [
            { type => "int", desc => "Timeout. This plugin recommends a cooldown of 4 seconds." }
        ]
    );

}

# Mandatory function to be implemented by your script
sub run_script {
    shift;
    my $lrr_info = shift;
    my $logger   = get_plugin_logger();
    my $success = 0;
    my $total = 0;
    my $nogalleryinehentai = $lrr_info->{oneshot_param};
    my $timeout = $lrr_info->{parameters}[0] || 10;

    # 获取所有档案
    my @archives = LANraragi::Model::Archive->generate_archive_list;
    for my $archive (@archives) {
        my $arcid = $archive->{"arcid"};
        my $title  = $archive->{"title"};
        my $old_tags = $archive->{"tags"};

        # 跳过有`source`标签的档案
        next if $old_tags =~ /\bsource\b/;

        $logger->info("Start process: '$title'");
        $total++;

        # 调用Ehentai插件
        my $ehentai_plugin_info;
        my $ehentai_tags;
        eval {
            ($ehentai_plugin_info, $ehentai_tags) = use_plugin("ehplugin", $arcid, undef);
        };
        if ($@) {
            $ehentai_tags->{error} = $@;
        }
        if ( exists $ehentai_tags->{error} ) {
            $logger->warn("Ehentai plugin returned an error: " . $ehentai_tags->{error});
            if ($ehentai_tags->{error} eq "No matching EH Gallery Found!") {
                $ehentai_tags->{new_tags} = "source:nogalleryinehentai";
                $logger->info("Add tag: " . $ehentai_tags->{new_tags});
                sleep(10);
            }else{
                sleep(10);
                next;
            }
        }

        # If the plugin exec returned tags, add them
        if ( exists $ehentai_tags->{new_tags} ) {
            $logger->debug("Add ehentai tags: " . $ehentai_tags->{new_tags});
            # 在原标签的基础上增加Ehentai标签
            set_tags( $arcid, $ehentai_tags->{new_tags}, 1 );
            $success++;
            sleep(10);
        }

        if ($timeout>0){
            sleep($timeout);
        }
        sleep(10);
    }
    if ($nogalleryinehentai eq "True"){
        my @nogalleryineh_archives = grep { $_->{"tags"} =~ /\bsource:nogalleryinehentai\b/ } @archives;
        for my $archive (@nogalleryineh_archives) {
            my $arcid = $archive->{"arcid"};
            my $title  = $archive->{"title"};
            my $old_tags = $archive->{"tags"};

            $logger->info("Start process: '$title'");
            $total++;

            # 重新调用Ehentai插件
            my $ehentai_plugin_info;
            my $ehentai_tags;
            eval {
                ($ehentai_plugin_info, $ehentai_tags) = use_plugin("ehplugin", $arcid, undef);
            };
            if ($@) {
                $ehentai_tags->{error} = $@;
            }
            if ( exists $ehentai_tags->{error} ) {
                $logger->warn("Ehentai plugin returned an error: " . $ehentai_tags->{error});
                sleep(10);
                next;
            }

            # If the plugin exec returned tags, add them
            unless ( exists $ehentai_tags->{error} ) {
                $logger->debug("Add ehentai tags: " . $ehentai_tags->{new_tags});
                $old_tags =~ s/\bsource:nogalleryinehentai\b/$ehentai_tags->{new_tags}/g;
                
                set_tags( $arcid, $old_tags, 0 );
                $success++;
                sleep(10);
            }
            
            if ($timeout>0){
                sleep($timeout);
            }
            sleep(10);
        }
    }

    return (modified => $success,total=>$total);
}

1;