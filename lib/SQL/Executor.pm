package SQL::Executor;
use parent qw(Exporter);
use strict;
use warnings;
our $VERSION = '0.01';

our @EXPORT_OK = qw(named_bind);

use Class::Accessor::Lite (
    ro => ['builder', 'dbh', 'allow_empty_condition', 'backup_callback'],
    rw => ['callback'],
);
use SQL::Maker;
use Carp qw();
use SQL::Executor::Iterator;
use Data::UUID;

=head1 NAME

SQL::Executor - Thin DBI wrapper using SQL::Maker

=head1 SYNOPSIS

  use DBI;
  use SQL::Executor;
  my $dbh = DBI->connect($dsn, $id, $pass);
  my $ex = SQL::Executor->new($dbh);
  #
  # SQL::Maker-like interfaces
  my @rows = $ex->select('SOME_TABLE', { id => 123 });
  $ex->insert('SOME_TABLE', { id => 124, value => 'xxxx'} );
  $ex->update('SOME_TABLE', { value => 'yyyy'}, { id => 124 } );
  $ex->delete('SOME_TABLE', { id => 124 } );
  #
  # select using SQL with named placeholder
  my @rows= $ex->select_named('SELECT id, value1 FROM SOME_TABLE WHERE value2 = :arg1', { arg1 => 'aaa' });

=head1 DESCRIPTION

SQL::Executor is thin DBI wrapper using L<SQL::Maker>. This module provides interfaces to make easier access to SQL.

You can execute SQL via SQL::Maker-like interface in select(), select_row(), select_all(), select_with_fields(), select_row_with_fields(), select_all_with_fields(), insert(), insert_multi(), update() and delete().

If you want to use more complex select query, you can use select_named(), select_row_named() or select_all_named() these execute SQL with named placeholder. If you don't want to use named placeholder, you can use select_by_sql(), select_row_by_sql() or select_all_by_sql() these execute SQL with normal placeholder('?').

=cut

=head1 METHODS

=cut

=head2 new($dbh, $option_href)

$dbh: Database Handler
$option_href: option

available option is as follows

allow_empty_condition (BOOL default 1): allow empty condition(where) in select/delete/update
callback (coderef): specify callback coderef. callback is called for each select* method

These callbacks are useful for making row object.

  my $ex = SQL::Executor->new($dbh, {
      callback => sub {
          my ($self, $row, $table_name, $select_id) = @_;
          return CallBack::Class->new($row);
      },
  });

  my $row = $ex->select_by_sql($sql1, \@binds1, 'TEST');
  # $row isa 'CallBack::Class'


=cut

sub new {
    my ($class, $dbh, $option_href) = @_;
    my $builder = SQL::Maker->new( driver => $dbh->{Driver}->{Name} );
    SQL::Maker->load_plugin('InsertMulti');

    my $self = {
        builder               => $builder,
        dbh                   => $dbh,
        allow_empty_condition => defined $option_href->{allow_empty_condition} ? $option_href->{allow_empty_condition} : 1,
        callback              => $option_href->{callback},
        backup_callback       => $option_href->{callback},
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
    my %option = %{ $option || {} };
    $option{limit} = 1;
    return $self->select_row_with_fields($table_name, ['*'], $where, \%option);
}

=head2 select_all($table_name, $where, $option)

select all rows. parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all {
    my ($self, $table_name, $where, $option) = @_;
    return $self->select_all_with_fields($table_name, ['*'], $where, $option);
}

=head2 select_itr($table_name, $where, $option)

select and returns iterator. parameter is the same as select method in L<SQL::Maker>. But array ref for field names are not needed.
Iterator is L<SQL::Executor::Iterator> object.

  my $itr = select_itr('SOME_TABLE', { name => 'aaa' });
  while( my $row = $itr->next ) {
      # ... using row
  }

=cut

sub select_itr {
    my ($self, $table_name, $where, $option) = @_;
    return $self->select_itr_with_fields($table_name, ['*'], $where, $option);
}


=head2 select_named($sql, $params_href, $table_name)

select row(s). In array context, this method behaves the same as select_all_with_fields.
In scalar context, this method behaves the same as select_one_with_fileds

You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

$table_name is used for callback.

=cut

sub select_named {
    my ($self, $sql, $params_href, $table_name) = @_;
    if( wantarray() ) {
        return $self->select_all_named($sql, $params_href, $table_name);
    }
    return $self->select_row_named($sql, $params_href, $table_name);
}

=head2 select_row_named($sql, $params_href, $table_name)

select only one row. You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_row_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

$table_name is used for callback.

=cut

sub select_row_named {
    my ($self, $sql, $params_href, $table_name) = @_;
    my ($new_sql, @binds) = named_bind($sql, $params_href);
    return $self->select_row_by_sql($new_sql, \@binds, $table_name);
}

=head2 select_all_named($sql, $params_href, $table_name)

select all rows. You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my @rows = $ex->select_all_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).
$table_name is used for callback.

=cut

sub select_all_named {
    my ($self, $sql, $params_href, $table_name) = @_;
    my ($new_sql, @binds) = named_bind($sql, $params_href);
    return $self->select_all_by_sql($new_sql, \@binds, $table_name);
}

=head2 select_itr_named($sql, $params_href, $table_name)

select and returns iterator. You can use named placeholder in SQL like this,

  my $ex = SQL::Executor->new($dbh);
  my $itr = $ex->select_itr_named("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 1234 });

$table_name is used for callback.

=cut

sub select_itr_named {
    my ($self, $sql, $params_href, $table_name) = @_;
    my ($new_sql, @binds) = named_bind($sql, $params_href);
    return $self->select_itr_by_sql($new_sql, \@binds, $table_name);
}


=head2 named_bind($sql, $params_href)

returns sql which is executable in execute_query() and parameters for bind.

  my ($sql, @binds) = named_bind("SELECT * FROM SOME_TABLE WHERE id = :id", { id => 123 });
  # $sql   =>  "SELECT * FROM SOME_TABLE WHERE id = ?"
  # @binds => (123)

=cut

# this code is taken from Teng's search_named()
sub named_bind {
    my ($sql, $params_href) = @_;

    my %named_bind = %{ $params_href };
    my @binds;
    my $new_sql = $sql;
    $new_sql =~ s{:([A-Za-z_][A-Za-z0-9_]*)}{
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
    return ($new_sql, @binds);
}


=head2 select_by_sql($sql, \@binds, $table_name)

select row(s). In array context, this method behaves the same as select_all_with_fields.
In scalar context, this method behaves the same as select_one_with_fileds

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", [1234]);

$table_name is only used for callback.

=cut

sub select_by_sql {
    my ($self, $sql, $binds_aref, $table_name) = @_;
    if( wantarray() ) {
        return $self->select_all_by_sql($sql, $binds_aref, $table_name);
    }
    return $self->select_row_by_sql($sql, $binds_aref, $table_name);
}

=head2 select_row_by_sql($sql, \@binds, $table_name)

select only one row.

  my $ex = SQL::Executor->new($dbh);
  my $row = $ex->select_row_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", [1234]);

this method returns hash ref and it is the same as return value in DBI's selectrow_hashref/fetchrow_hashref.

=cut

sub select_row_by_sql {
    my ($self, $sql, $binds_aref, $table_name) = @_;
    my $dbh = $self->dbh;
    my $row = $dbh->selectrow_hashref($sql, undef, @{ $binds_aref || [] } );
    my $callback = $self->callback;
    if ( defined $callback && defined $row ) {
        my $ug = Data::UUID->new();
        return $callback->($self, $row, $table_name, $ug->create_str);
    }
    return $row;
}

=head2 select_all_by_sql($sql, \@binds, $table_name)

select all rows.

  my $ex = SQL::Executor->new($dbh);
  my @rows = $ex->select_all_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", [1234]);

this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all_by_sql {
    my ($self, $sql, $binds_aref, $table_name) = @_;
    my $dbh = $self->dbh;
    my @rows = @{ $dbh->selectall_arrayref($sql, { Slice => {} }, @{ $binds_aref || [] }) };
    my $callback = $self->callback;
    if( defined $callback ) {
        my $ug = Data::UUID->new();
        my $select_id = $ug->create_str;
        my @result = map{ $callback->($self, $_, $table_name, $select_id) } @rows;
        return @result;
    }
    return @rows;
}


=head2 select_itr_by_sql($sql, \@binds, $table_name)

select and returns iterator

  my $ex = SQL::Executor->new($dbh);
  my $itr = $ex->select_itr_by_sql("SELECT * FROM SOME_TABLE WHERE id = ?", [1234]);

Iterator is L<SQL::Executor::Iterator> object.

=cut

sub select_itr_by_sql {
    my ($self, $sql, $binds_aref, $table_name) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@{ $binds_aref || [] });
    return SQL::Executor::Iterator->new($sth, $table_name, $self);
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
    my %option = %{ $option || {} };
    $option{limit} = 1;
    my ($sql, @binds) = $self->_prepare_select_statement($table_name, $fields_aref, $where, \%option);
    return $self->select_row_by_sql($sql, \@binds, $table_name);
}

=head2 select_all_with_fields($table_name, $fields_aref, $where, $option)

select all rows. parameter is the same as select method in L<SQL::Maker>. But array ref for filed names are not needed.
this method returns array that is composed of hash refs. (hash ref is same as DBI's selectrow_hashref/fetchrow_hashref).

=cut

sub select_all_with_fields {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    my ($sql, @binds) = $self->_prepare_select_statement($table_name, $fields_aref, $where, $option);
    return $self->select_all_by_sql($sql, \@binds, $table_name);
}

=head2 select_itr_with_fields($table_name, $fields_aref, $where, $option)

select and return iterator object(L<SQL::Executor::Iterator>). parameter is the same as select method in L<SQL::Maker>.

=cut

sub select_itr_with_fields {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    my ($sql, @binds) = $self->_prepare_select_statement($table_name, $fields_aref, $where, $option);
    return $self->select_itr_by_sql($sql, \@binds, $table_name);
}


# prepare select statment using SQL::Maker
sub _prepare_select_statement {
    my ($self, $table_name, $fields_aref, $where, $option) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->select($table_name, $fields_aref, $where, $option);
    return ($sql, @binds);
}


=head2 insert($table_name, $values)

Do INSERT statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub insert {
    my ($self, $table_name, $values) = @_;
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->insert($table_name, $values);
    $self->_execute_and_finish($sql, \@binds);
}

=head2 insert_multi($table_name, @args)

Do INSERT-multi statement using L<SQL::Maker::Plugin::InsertMulti>.

=cut

sub insert_multi {
    my ($self, $table_name, @args) = @_;
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->insert_multi($table_name, @args);
    $self->_execute_and_finish($sql, \@binds);
}


=head2 delete($table_name, $where)

Do DELETE statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub delete {
    my ($self, $table_name, $where) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->delete($table_name, $where);
    $self->_execute_and_finish($sql, \@binds);
}


=head2 update($table_name, $set, $where)

Do UPDATE statement. parameter is the same as select method in L<SQL::Maker>.

=cut

sub update {
    my ($self, $table_name, $set, $where) = @_;
    Carp::croak "condition is empty" if ( !$self->allow_empty_condition && $self->_is_empty_where($where) );
    my $builder = $self->builder;
    my ($sql, @binds) = $builder->update($table_name, $set, $where);
    $self->_execute_and_finish($sql, \@binds);
}


=head2 execute_query($sql, \@binds)

execute query and returns statement handler($sth).

=cut

sub execute_query {
    my ($self, $sql, $binds_aref) = @_;
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@{ $binds_aref || [] });
    return $sth;
}

=head2 execute_query_named($sql, $params_href)

execute query with named placeholder and returns statement handler($sth).

=cut

sub execute_query_named {
    my ($self, $sql, $params_href) = @_;
    my $dbh = $self->dbh;
    my ($new_sql, @binds) = named_bind($sql, $params_href);
    my $sth = $dbh->prepare($new_sql);
    $sth->execute(@binds);
    return $sth;
}



=head2 disable_callback()

disable callback temporarily, 

=cut

sub disable_callback {
    my ($self) = @_;
    $self->callback(undef);
}

=head2 restore_callback()

restore disabled callback.

=cut

sub restore_callback {
    my ($self) = @_;
    $self->callback($self->backup_callback);
}



sub _execute_and_finish {
    my ($self, $sql, $binds_aref) = @_;
    my $sth = $self->execute_query($sql, $binds_aref);
    $sth->finish;
}

sub _is_empty_where {
    my ($self, $where) = @_;
    return !defined $where 
           || ( ref $where eq 'ARRAY' && !@{ $where } )
           || ( ref $where eq 'HASH'  && !%{ $where } )
           || ( eval{ $where->can('as_sql') } && $where->as_sql eq '' ) #SQL::Maker::Condition
    ;
}

1;
__END__


=head1 How to use Transaction.

You can use L<DBI>'s transaction (begin_work and commit).

  use DBI;
  use SQL::Executor;
  my $dbh = DBI->connect($dsn, $id, $pass);
  my $ex = SQL::Executor->new($dbh);
  $dbh->begin_work();
  $ex->insert('SOME_TABLE', { id => 124, value => 'xxxx'} );
  $ex->insert('SOME_TABLE', { id => 125, value => 'yyy'} );
  $dbh->commit();


Or you can also use transaction management modules like L<DBIx::TransactionManager>.

  use DBI;
  use SQL::Executor;
  use DBIx::TransactionManager;
  my $dbh = DBI->connect($dsn, $id, $pass);
  my $ex = SQL::Executor->new($dbh);
  my $tm = DBIx::TransactionManager->new($dbh);
  my $txn = $tm->txn_scope;
  $ex->insert('SOME_TABLE', { id => 124, value => 'xxxx'} );
  $ex->insert('SOME_TABLE', { id => 125, value => 'yyy'} );
  $txn->commit;

=head1 FAQ

=head2 Why don't you use L<DBIx::Simple>?

=over 4

=item * I want to use L<SQL::Maker>.

=item * When I need to use complex query, I want to use named placeholder.

=item * I don't want to manage transaction in this module.

=back

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
