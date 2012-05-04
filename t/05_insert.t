#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;

my $dbh = prepare_dbh();

subtest 'insert', sub {
    my $ex = SQL::Executor->new($dbh);
    $ex->insert('TEST', { id => 4, value => 'xxx' });
    my $row = $ex->select('TEST', { id => 4 });
    ok( defined $row );
    is( $row->{id},    4);
    is( $row->{value}, 'xxx');
};

done_testing;


