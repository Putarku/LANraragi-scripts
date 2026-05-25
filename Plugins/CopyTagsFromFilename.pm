package LANraragi::Plugin::Metadata::CopyTagsFromFilename;

use strict;
use warnings;

use File::Basename;

use LANraragi::Model::Config;
use LANraragi::Utils::Logging qw(get_plugin_logger);
use LANraragi::Utils::Redis   qw(redis_decode);
use LANraragi::Utils::Tags    qw(join_tags_to_string split_tags_to_array);

sub plugin_info {

    return (
        name        => "Copy Tags From Filename",
        type        => "metadata",
        namespace   => "copy-tags-from-filename",
        author      => "Putarku",
        version     => "1.1",
        description => "使用当前画廊的名字在库中检索，并将其tag复制到当前画廊中，适用于更优质的版本替换的时候用"
    );

}

sub get_tags {
    shift;
    my ($lrr_info) = @_;

    my $logger = get_plugin_logger();
    my $redis  = LANraragi::Model::Config->get_redis;

    my $file_path = redis_decode( $lrr_info->{file_path} // q{} );
    my ( $archive_name, undef, undef ) = fileparse( $file_path, qr/\.[^.]*?/ );
    my $clean_archive_name = cleanup_archive_name($archive_name);

    if ( !$clean_archive_name ) {
        $redis->quit;
        return ( tags => q{} );
    }

    my @ids = $redis->keys('????????????????????????????????????????');
    my %seen_tags;
    my @copied_tags;
    my $match_count = 0;

    foreach my $id (@ids) {
        next if $id eq $lrr_info->{archive_id};

        my %archive = $redis->hgetall($id);
        next if !%archive;

        my $candidate_name       = redis_decode( $archive{name} // q{} );
        my $clean_candidate_name = cleanup_archive_name($candidate_name);
        next if !$clean_candidate_name || $clean_candidate_name ne $clean_archive_name;

        $match_count++;
        foreach my $tag ( split_tags_to_array( redis_decode( $archive{tags} // q{} ) ) ) {
            next if $tag =~ /^date_added:/i;
            next if !$tag || $seen_tags{$tag}++;
            push @copied_tags, $tag;
        }
    }

    $redis->quit;

    my $tags = join_tags_to_string(@copied_tags);
    $logger->info("Found $match_count archive(s) with cleaned filename '$clean_archive_name'.");
    $logger->info( "Sending the following tags to LRR: " . ( $tags || '-' ) );

    return ( tags => $tags );
}

sub cleanup_archive_name {
    my ($name) = @_;
    return q{} if !defined $name;

    $name = lc $name;

    # Drop common replacement-noise markers before matching against existing archives.
    $name =~ s/\[(?:\d+(?:p|x\d+)|v\d+(?:\.\d+)?|ver\s*\d+(?:\.\d+)?|rev\s*\d+|fix(?:ed)?|updated?|repack|rescanned?|complete|digital|uncensored|censored|english|japanese|chinese|translated?|ai[ -]?upscaled?)\]/ /gi;
    $name =~ s/\((?:\d+(?:p|x\d+)|v\d+(?:\.\d+)?|ver\s*\d+(?:\.\d+)?|rev\s*\d+|fix(?:ed)?|updated?|repack|rescanned?|complete|digital|uncensored|censored|english|japanese|chinese|translated?|ai[ -]?upscaled?)\)/ /gi;
    $name =~ s/\b\d{3,4}p\b/ /gi;
    $name =~ s/\b\d+\s*(?:pages?|p)\b/ /gi;
    $name =~ s/\b(?:v|ver|rev)\s*\d+(?:\.\d+)?\b/ /gi;
    $name =~ s/\b(?:fix(?:ed)?|updated?|repack|rescanned?|complete|digital|uncensored|censored|english|japanese|chinese|translated?|raw)\b/ /gi;
    $name =~ s/[\[\](){}]/ /g;
    $name =~ s/[._-]+/ /g;
    $name =~ s/\s+/ /g;
    $name =~ s/^\s+|\s+$//g;

    return $name;
}

1;
