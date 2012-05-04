#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;

my $dbh = prepare_dbh();
prepare_testdata($dbh);

my $table_name = 'TEST';
my $condition = { value => 'aaa' };
my $option = { order_by => 'id' };

subtest 'select_row', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_row($table_name, $condition, $option);
    single_row_ok($row);
};


subtest 'select_all', sub {
    my $ex = SQL::Executor->new($dbh);
    my @rows = $ex->select_all($table_name, $condition, $option);
    rows_ok(@rows);
};

subtest 'select', sub {
    my $ex = SQL::Executor->new($dbh);

    my $row = $ex->select($table_name, $condition, $option);
    single_row_ok($row);

    my @rows = $ex->select($table_name, $condition, $option);
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
