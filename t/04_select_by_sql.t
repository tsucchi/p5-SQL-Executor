#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;

my $dbh = prepare_dbh();
prepare_testdata($dbh);

my $sql = "SELECT * FROM TEST WHERE value = ? ORDER BY id";
my @binds = ('aaa');

subtest 'select_row_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_row_by_sql($sql, @binds);
    single_row_ok($row);
};


subtest 'select_all_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my @rows = $ex->select_all_by_sql($sql, @binds);
    rows_ok(@rows);
};

subtest 'select_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_by_sql($sql, @binds);
    single_row_ok($row);

    my @rows = $ex->select_by_sql($sql, @binds);
    rows_ok(@rows);
};

done_testing;

sub single_row_ok {
    my ($row) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok( defined $row );
    is( ref $row,      'HASH' );
    is( $row->{id},    1);
    is( $row->{value}, 'aaa');
}

sub rows_ok {
    my (@rows) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $expected = [
        { id => 1, value => 'aaa' },
        { id => 2, value => 'aaa' },
    ];
    is_deeply( \@rows, $expected );
}
