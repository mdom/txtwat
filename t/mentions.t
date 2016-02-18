use strict;
use warnings;
use Test::More;
use App::twtxtpl;
use FindBin qw($Bin);

my $twtxt = App::twtxtpl->new( config_file => "$Bin/config" );

is( $twtxt->collapse_mentions('@<foo https://example.com/foo/twtxt.txt>'),
    '@foo' );
is( $twtxt->collapse_mentions('@<bar https://example.com/bar/twtxt.txt>'),
    '@<bar https://example.com/bar/twtxt.txt>' );
is( $twtxt->expand_mentions('@foo'),
    '@<foo https://example.com/foo/twtxt.txt>' );
is( $twtxt->expand_mentions('@bar'), '@bar' );

$twtxt->embed_names(0);
is( $twtxt->expand_mentions('@foo'), '@<https://example.com/foo/twtxt.txt>' );

done_testing;