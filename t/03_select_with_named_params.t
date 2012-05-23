#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor qw(named_bind);
use DBI;
use Test::More;
use t::Util;
use t::Global;
use t::Table;

my $dbh = prepare_dbh();
prepare_testdata($dbh);


my $sql = "SELECT * FROM TEST WHERE value = :value ORDER BY id";
my $condition = { value => 'aaa' };

subtest 'named_bind', sub {
    my ($new_sql, @binds) = named_bind($sql, $condition);
    is( $new_sql, "SELECT * FROM TEST WHERE value = ? ORDER BY id" );
    is_deeply(\@binds, ['aaa']);
};

subtest 'select_row_named', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_row_named($sql, $condition);
    single_row_ok($row);
};


subtest 'select_all_named', sub {
    my $ex = SQL::Executor->new($dbh);
    my @rows = $ex->select_all_named($sql, $condition);
    rows_ok(@rows);
};

subtest 'select_named', sub {
    my $ex = SQL::Executor->new($dbh);

    my $row = $ex->select_named($sql, $condition);
    single_row_ok($row);

    my @rows = $ex->select_named($sql, $condition);
    rows_ok(@rows);
};

subtest 'select_itr_named', sub {
    my $ex = SQL::Executor->new($dbh);
    my $itr = $ex->select_itr_named($sql, $condition);
    my $row = $itr->next;
    single_row_ok($row);
};


subtest 'with_callback', sub {
    my $ex = SQL::Executor->new($dbh, {
        callback => sub {
            my ($self, $row, $table_name) = @_;
            return t::Global->new($row);
        },
    });

    my $row = $ex->select_named($sql, $condition);
    is( $row->name, 'global_callback');

    my @rows = $ex->select_named($sql, $condition);
    is( $rows[0]->name, 'global_callback');
    is( $rows[1]->name, 'global_callback');

    my $itr = $ex->select_itr_named($sql, $condition);
    my $next_row = $itr->next;
    is( $next_row->name, 'global_callback');

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
