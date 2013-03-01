#!perl
use strict;
use warnings;
use SQL::Executor;
use Test::More;
use t::Util;
use Try::Tiny;


my $dbh = prepare_dbh();

subtest 'handle_exception', sub {
    my $db = SQL::Executor->new($dbh);
    try {
        $db->select_row('TEST', { id => \'no_exist_func()' }); # causes SQL error
        fail 'exception expected';
    } catch {
        #warn $_;
        like( $_, qr/at $0 line \d+/ );#contains error and line no in this test
    }
};


done_testing;

