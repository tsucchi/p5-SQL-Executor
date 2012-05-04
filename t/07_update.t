#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;

my $dbh = prepare_dbh();
prepare_testdata($dbh);

subtest 'update', sub {
    my $ex = SQL::Executor->new($dbh);
    $ex->update('TEST', { value => 'xxxx'}, { id => 1 });
    my $row = $ex->select('TEST', { id => 1 });
    ok( defined $row );
    is( $row->{value}, 'xxxx');
};

done_testing;


