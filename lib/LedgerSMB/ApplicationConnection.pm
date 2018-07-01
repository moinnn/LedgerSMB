
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

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use File::Spec;

use LedgerSMB::Database::Config;
use LedgerSMB::Sysconfig;

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


=head2 new_assoc($classname, arg1, ...)

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


=head2 associate($instance)

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

=head2 load_templateset($set_name)

Loads the set of templates indicated by C<$set_name> from the
template directory configured in C<ledgersmb.conf>.

Dies when the given set name can't be found in the configured
directory.

=cut

sub _extract_name_and_params {
    my ($pathname, $basedir) = @_;

    my $relfile = File::Spec->abs2rel($pathname, $basedir);
    my ($unused1, $directories, $filename) =
        File::Spec->splitpath($relfile);
    my @directories = File::Spec->splitdir($directories);
    # $dirs[0] == $template_dir
    # $dirs[1] == language_code (if applicable)
    $filename =~ m/\.([^.]+)$/;
    my $format = $1;
    my %args = (
        template_name => $filename,
        format => $format
    );
    $args{language_code} = $directories[1]
        if (scalar @directories) > 1 && $directories[1];

    return %args;
}

sub load_templateset {
    my $self = shift;
    my $set_name = shift;
    my $templates = LedgerSMB::Database::Config->new->templates;
    my $basedir = LedgerSMB::Sysconfig::templates();

    die "Invalid template set ($set_name) specified"
        if not exists $templates->{$set_name};

    for my $pathname (@{$templates->{$set_name}}) {

        open my $fh, '<', $pathname
            or die "Failed to open tepmlate file $pathname : $!";
        my $content;
        {
            local $/ = undef;
            $content = <$fh>;
        }
        close $fh
            or warn "Can't close file $pathname";

        my $dbtemp = $self->new_assoc('LedgerSMB::Template::DB',
            _extract_name_and_args($pathname, $basedir));
        $dbtemp->save; ###TODO: Check return value!
    }
    return;
}

=head1 COPYRIGHT

Copyright (C) 2018 The LedgerSMB Core Team

This file is licensed under the Gnu General Public License version 2, or at your
option any later version.  A copy of the license should have been included with
your software.

=cut

__PACKAGE__->meta->make_immutable;

1;
