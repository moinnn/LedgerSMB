package Dancer2::Plugin::Auth::Extensible::Provider::DBConnection;

use Carp qw/croak/;
use DBI;
use Try::Tiny;

use Moo;
with "Dancer2::Plugin::Auth::Extensible::Role::Provider";
use namespace::clean;

our $VERSION = '0.001';

has auth_database => ( is => 'ro' );

sub authenticate_user {
   my ($self, $username, $password) = @_;

   croak "username and password must be defined"
     unless defined $username and defined $password;

   my $dbname =
       $self->auth_database
       // $self->plugin->app->request
          ->body_parameters->get('__auth_extensible_database');
   croak "session doesn't contain database name for auth"
     unless defined $dbname;

   my $dbh;
   try {
     $dbh = DBI->connect('dbi:Pg:host=postgres;dbname=' . $dbname,
                         $username, $password);
   };

   if (defined $dbh) {
      my $session = $self->plugin->app->session;
      $session->write('__auth_extensible_database', $dbname);
      $session->write('__auth_extensible_pass', $password);

      return 1;
   }

   return 0;
}


1;
