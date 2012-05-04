#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;

my $dbh = prepare_dbh();
prepare_testdata($dbh);

subtest 'delete', sub {
    my $ex = SQL::Executor->new($dbh);
    $ex->delete('TEST', { id => 1 });
    my $row = $ex->select('TEST', { id => 1 });
    ok( !defined $row );
};

done_testing;


