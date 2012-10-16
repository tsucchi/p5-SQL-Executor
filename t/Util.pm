package t::Util;
use parent qw(Exporter);
use strict;
use warnings;

our @EXPORT = qw(prepare_dbh prepare_testdata);

sub prepare_dbh {
    my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:","","", { RaiseError => 1, PrintError => 0 });
    $dbh->do('CREATE TABLE TEST ( id integer PRIMARY KEY, value text )');
    return $dbh;
}

sub prepare_testdata {
    my ($dbh) = @_;
    $dbh->do("INSERT INTO TEST VALUES (1, 'aaa')");
    $dbh->do("INSERT INTO TEST VALUES (2, 'aaa')");
    $dbh->do("INSERT INTO TEST VALUES (3, 'bbb')");
}


1;
