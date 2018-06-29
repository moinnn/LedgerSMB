package Dancer2::Plugin::SessionDatabase;

use strict;
use warnings;
use Carp qw/croak/;
use DBI;

use Dancer2::Core::Types qw(Int Str);
use Dancer2::Plugin;

has host => (
    is          => 'ro',
    isa         => Str,
    from_config => sub { 'localhost' },
);

has port => (
    is          => 'ro',
    isa         => Int,
);

our $VERSION = '0.001';


register database => sub {
    my $self = shift;

    my $session = $self->app->session;
    my $dbname = $session->read('__auth_extensible_database');
    my $username = $session->read('logged_in_user');
    my $password = $session->read('__auth_extensible_pass');
    my $dbh = DBI->connect('dbi:Pg:database=' . $dbname
                           . ';host=' . $self->host,
                           $username, $password)
        or croak DBI->errstr;

    return $dbh;
};


register_plugin;

1;
