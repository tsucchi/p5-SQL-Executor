#!/usr/bin/env perl
use strict;
use warnings;
use SQL::Executor;
use DBI;
use Test::More;
use t::Util;
use t::Global;
use t::Table;

my $dbh = prepare_dbh();
prepare_testdata($dbh);

my $sql = "SELECT * FROM TEST WHERE value = ? ORDER BY id";
my @binds = ('aaa');

subtest 'select_row_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_row_by_sql($sql, \@binds);
    single_row_ok($row);
};


subtest 'select_all_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my @rows = $ex->select_all_by_sql($sql, \@binds);
    rows_ok(@rows);
};

subtest 'select_itr_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my $itr = $ex->select_itr_by_sql($sql, \@binds);
    my $row = $itr->next;
    single_row_ok($row);
};


subtest 'select_by_sql', sub {
    my $ex = SQL::Executor->new($dbh);
    my $row = $ex->select_by_sql($sql, \@binds);
    single_row_ok($row);

    my @rows = $ex->select_by_sql($sql, \@binds);
    rows_ok(@rows);
};

subtest 'with_callback', sub {
    my $ex = SQL::Executor->new($dbh, {
        callback => sub {
            my ($self, $row) = @_;
            return t::Global->new($row);
        },
    });

    my $row = $ex->select_by_sql($sql, \@binds);
    is( $row->name, 'global_callback');

    my @rows = $ex->select_by_sql($sql, \@binds);
    is( $rows[0]->name, 'global_callback');
    is( $rows[1]->name, 'global_callback');

    my $itr = $ex->select_itr_by_sql($sql, \@binds);
    my $next_row = $itr->next;
    is( $next_row->name, 'global_callback');

};

subtest 'with_table_callback', sub {
    my $ex = SQL::Executor->new($dbh, {
        callback => sub {
            my ($self, $row) = @_;
            return t::Global->new($row);
        },
        table_callback => { 
            TEST => sub {
                my ($self, $row) = @_;
                return t::Table->new($row);
            },
        },
    });

    my $row = $ex->select_by_sql($sql, \@binds, 'TEST');
    is( $row->name, 'table_callback');

    my @rows = $ex->select_by_sql($sql, \@binds, 'TEST');
    is( $rows[0]->name, 'table_callback');
    is( $rows[1]->name, 'table_callback');

    my $itr = $ex->select_itr_by_sql($sql, \@binds, 'TEST');
    my $next_row = $itr->next;
    is( $next_row->name, 'table_callback');

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
