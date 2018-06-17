
package LedgerSMB::ApplicationConnection;

=head1 NAME

LedgerSMB::ApplicationConnection - Application instance per user

=head1 SYNOPSIS

    my $app = LedgerSMB::ApplicationConnection->new(
        database => $database,
        connect_options => { ... });
    my $user = $app->new_assoc('LedgerSMB::Entity::User', ... user-args ...);

=head1 DESCRIPTION

LedgerSMB::ApplicationConnection models an application instance for a given
user; as such it caches a database connection based on that user's
credentials.

Along the same lines, it contains logic to instantiate objects from the
application (database) and associate those objects with the cached
database connection.


=cut

use Moose;


=head1 ATTRIBUTES

=cut

# Private attribute _dbh doesn't have any public (=POD) documentation

has _dbh => ( is => 'rw', isa => 'DBI::db',
              predicate => '_has_dbh');


=head2 database

An instance of C<LedgerSMB::Database>, used to spawn database connections
from and retrieve other environment data.

=cut

has database => ( is => 'ro', isa => 'LedgerSMB::Database',
                  required => 1);

=head2 connect_options

Options used as arguments for C<LedgerSMB::Database>'s C<connect> method.

Defaults to

   {  PrintError => 0, AutoCommit => 0 }

=cut

has connect_options => ( is => 'ro', isa => 'HashRef',
                         default => sub { return { PrintError => 0,
                                                   AutoCommit => 0 } } );


=head1 METHODS

=head2 dbh

Returns a (cached) database connection established using the
user's credentials and C<connect_options>.

=cut

sub dbh {
    my $self = shift;

    return $self->_dbh if $self->_has_dbh;

    return $self->_dbh(
        $self->database->connect($self->connect_options));
}


=head2 $self->new_assoc($classname, arg1, ...)

Creates an instance of C<$classname> passing the arguments provided
to the class's C<new> constructor method.

After construction, calls C<associate> with the new instance as its argument
and returns the associated instance.

=cut

sub new_assoc {
    my $self = shift;
    my $class = shift;

    return $self->associate($class->new(@_));
}


=head2 $self->associate($instance)

Associates a C<PGObject::Simple> or C<PGObject::Simple::Role> derived
object with the application connection (using the cached database handle).

Returns C<$instance>.

=cut

sub associate {
    my $self = shift;
    my $instance = shift;

    ### Ouch. Blatant layering violation, but PGObject::Simple::Role
    # (on which LedgerSMB::PGObject is based), doesn't define a setter
    $instance->{_dbh} = $self->dbh;
    return $instance;
}

=head1 COPYRIGHT

Copyright (C) 2018 The LedgerSMB Core Team

This file is licensed under the Gnu General Public License version 2, or at your
option any later version.  A copy of the license should have been included with
your software.

=cut

1;
