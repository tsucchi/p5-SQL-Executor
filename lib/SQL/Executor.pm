package SQL::Executor;
use strict;
use warnings;
our $VERSION = '0.01';

use Class::Accessor::Lite (
    ro => ['builder', 'dbh', 'allow_empty_condition'],
);
use SQL::Maker;
use Carp qw();

=head1 NAME

SQL::Executor - Thin DBI wrapper using SQL::Maker

=head1 SYNOPSIS

  use DBI;
  use SQL::Executor;
  my $dbh = DBI->connect($dsn, $id, $pass);
  my $ex = SQL::Executor->new($dbh);
  my @rows = $ex->select('SOME_TABLE', { id => 123 });
  $ex->insert('SOME_TABLE', { id => 124, value => 'xxxx'} );
  $ex->update('SOME_TABLE', { value => 'yyyy'}, { id => 124 } );
  $ex->delete('SOME_TABLE', { id => 124 } );

=head1 DESCRIPTION

SQL::Executor is Thin DBI wrapper using SQL::Maker. This module provides interfaces to make easier access to SQL.

=cut

=head1 METHODS

=cut

=head2 new($dbh, $option_href)

$dbh: Database Handler
$option_href: option

available option is as follows

allow_empty_condition (BOOL default 1): allow empty condition(where) in select/delete/update

=cut

sub new {
    my ($class, $dbh, $option_href) = @_;
    my $builder = SQL::Maker->new( driver => $dbh->{Driver}->{Name} );
    SQL::Maker->load_plugin('InsertMulti');

    my $self = {
        builder               => $builder,
        dbh                   => $dbh,
        allow_empty_condition => defined $option_href->{allow_empty_condition} ? $option_href->{allow_empty_condition} : 1,
    };
    bless $self, $class;
}


=head2 select($table_name, $where, $option)

select row(s). parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
In array context, this method behaves the same as select_all. In scalar context, this method behaves the same as select_one

=cut

sub select {
    my ($self, $table_name, $where, $option) = @_;
    if( wantarray() ) {
        return $self->select_all($table_name, $where, $option);
    }
    return $self->select_row($table_name, $where, $option);
}


=head2 select_row($table_name, $where, $option)

select only one row. parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

=cut

sub select_row {
    my ($self, $table_name, $where, $option) = @_;
    return $self->select_row_with_fields($table_name, ['*'], $where, $option);
}

=head2 select_all($table_name, $where, $option)

select all rows. parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all {
    my ($self, $table_name, $where, $option) = @_;
    return $self->select_all_with_fields($table_name, ['*'], $where, $option);
}


=head2 select_named($sql, $params_href)

select row(s). In array context, this method behaves the same as select_all_with_fields.
In scalar context, this method behaves the same as select_one_with_fileds

You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

=cut

sub select_named {
    my ($self, $sql, $params_href) = @_;
    if( wantarray() ) {
        return $self->select_all_named($sql, $params_href);
    }
    return $self->select_row_named($sql, $params_href);
}

=head2 select_row_named($sql, $params_href)

select only one row. You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_row_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

=cut

sub select_row_named {
    my ($self, $sql, $params_href) = @_;
    my @binds = $self->_named_bind($sql, $params_href);
    return $self->select_row_by_sql($sql, @binds);
}

=head2 select_all_named($sql, $params_href)

select all rows. You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my @rows = $ex->select_all_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all_named {
    my ($self, $sql, $params_href) = @_;
    my @binds = $self->_named_bind($sql, $params_href);
    return $self->select_all_by_sql($sql, @binds);
}


# modify sql in parameter and returns parameters for bind.
# this code is taken from Teng's search_named()
sub _named_bind {
    my ($self, $sql, $params_href) = @_;

    my %named_bind = %{ $params_href };
    my @binds;
    $sql =~ s{:([A-Za-z_][A-Za-z0-9_]*)}{
        Carp::croak("'$1' does not exist in bind hash") if !exists $named_bind{$1};
        if ( ref $named_bind{$1} && ref $named_bind{$1} eq "ARRAY" ) {
            push @binds, @{ $named_bind{$1} };
            my $tmp = join ',', map { '?' } @{ $named_bind{$1} };
            "( $tmp )";
        } else {
            push @binds, $named_bind{$1};
            '?'
        }
    }ge;
    return @binds;
}


=head2 select_by_sql($sql, @binds)

select row(s). In array context, this method behaves the same as select_all_with_fields.
In scalar context, this method behaves the same as select_one_with_fileds

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", 1234);

=cut

sub select_by_sql {
    my ($self, $sql, @binds) = @_;
    if( wantarray() ) {
        return $self->select_all_by_sql($sql, @binds);
    }
    return $self->select_row_by_sql($sql, @binds);
}

=head2 select_row_by_sql($sql, @binds)

select only one row.

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_row_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", 1234);

this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

=cut

sub select_row_by_sql {
    my ($self, $sql, @binds) = @_;
    my $dbh = $self->dbh;
    my $row = $dbh->selectrow_hashref($sql, undef, @binds);
    return $row;
}

=head2 select_all_by_sql($sql, @binds)

select all rows.

  my $ex = SQL::Executor->new($dbh);
  my @rows = $ex->select_all_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", 1234);

this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all_by_sql {
    my ($self, $sql, @binds) = @_;
    my $dbh = $self->dbh;
    my @rows = @{ $dbh->selectall_arrayref($sql, { Slice => {} }, @binds) || [] };
    return @rows;
}


=head2 select_with_fields($table_name, $fields_aref, $where, $option)

select row(s). parameter is the same as select method in L<SQL::Maker>. 
In array context, this method behaves the same as select_all_with_fields.
In scalar context, this method behaves the same as select_one_with_fileds

=cut

sub select_with_fields {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    if( wantarray() ) {
        return $self->select_all_with_fields($table_name, $fields_aref, $where, $option);
    }
    return $self->select_row_with_fields($table_name, $fields_aref, $where, $option);
}

=head2 select_row_with_fields($table_name, $fields_aref, $where, $option)

select only one row. parameter is the same as select method in L<SQL::Maker>.
this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

=cut

sub select_row_with_fields {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->select($table_name, $fields_aref, $where, $option);
    return $self->select_row_by_sql($sql, @binds);
}

=head2 select_all_with_fields($table_name, $fields_aref, $where, $option)

select all rows. parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all_with_fields {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->select($table_name, $fields_aref, $where, $option);
    return $self->select_all_by_sql($sql, @binds);
}


=head2 insert($table_name, $values)

Do INSERT statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub insert {
    my ($self, $table_name, $values) = @_;
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->insert($table_name, $values);
    $self->_execute_and_finish($sql, @binds);
}

=head2 insert_multi($table_name, @args)

Do INSERT-multi statement using L<SQL::Maker::Plugin::InsertMulti>.

=cut

sub insert_multi {
    my ($self, $table_name, @args) = @_;
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->insert_multi($table_name, @args);
    $self->_execute_and_finish($sql, @binds);
}


=head2 delete($table_name, $where)

Do DELETE statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub delete {
    my ($self, $table_name, $where) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->delete($table_name, $where);
    $self->_execute_and_finish($sql, @binds);
}


=head2 update($table_name, $set, $where)

Do UPDATE statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub update {
    my ($self, $table_name, $set, $where) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->update($table_name, $set, $where);
    $self->_execute_and_finish($sql, @binds);
}


=head2 execute_query($sql, @binds)

execute query and returns statement handler($sth).

=cut

sub execute_query {
    my ($self, $sql, @binds) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@binds);
    return $sth;
}

sub _execute_and_finish {
    my ($self, $sql, @binds) = @_;
    my $sth = $self->execute_query($sql, @binds);
    $sth->finish;
}

sub _is_empty_where {
    my ($self, $where) = @_;
    return !defined $where 
           || ( ref $where eq 'ARRAY' && !@{ $where } )
           || ( ref $where eq 'HASH'  && !%{ $where } )
           || ( ref $where->can('as_sql') && $where->as_sql eq '' ) #SQL::Maker::Condition
    ;
}

1;
__END__


=head1 AUTHOR

Takuya Tsuchida E<lt>tsucchi {at} cpan.orgE<gt>

=head1 SEE ALSO

L<DBI>, L<SQL::Maker>, L<DBIx::Simple>

Codes for named placeholder is taken from L<Teng>'s search_named.

=head1 LICENSE

Copyright (C) Takuya Tsuchida

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
