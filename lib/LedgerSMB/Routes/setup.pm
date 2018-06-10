package LedgerSMB::Routes::setup;

use Dancer2 appname => 'LedgerSMB/Setup';

use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::SessionDatabase;

use LedgerSMB;
use LedgerSMB::Database;
use LedgerSMB::Sysconfig;

set layout => 'setup';

hook before => sub {
    # we want separate auth cookies for setup and the main app
    engine('session')->{cookie_name} = 'ledgersmb.setup';
};

hook before_template_render => sub {
    my ($tokens) = @_;

    $tokens->{text} = sub { return shift };
    $tokens->{ledgersmb_version} = $LedgerSMB::VERSION;
    $tokens->{username} = logged_in_user ? logged_in_user->{username} : '';
};


sub _list_databases {
    my $query = q{SELECT datname FROM pg_database
                   WHERE datallowconn
                         AND NOT datistemplate
                  ORDER BY datname};
    my $sth = database->prepare($query);
    my $databases = [];

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        push @$databases, $row->{datname};
    }

    return $databases;
}

sub _list_users {
    return [] unless param('database');

    my $query = q{SELECT id, username FROM users
                  ORDER BY username};
    my $sth = database(param('database'))->prepare($query);
    my $users = [];

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        push @$users, $row;
    }

    return $users;
}

sub _list_templates {
    my $templates = [];
    opendir ( DIR, $LedgerSMB::Sysconfig::templates)
        or die "Couldn't open template directory: $!";

    while( my $name = readdir(DIR)){
        next if ($name =~ /^\./);
        if (-d (LedgerSMB::Sysconfig::templates() . "/$name") ) {
            push @$templates, $name;
        }
    }
    closedir(DIR);
    return $templates;
}



get '/' => require_login sub {
    my $databases = _list_databases;
    my $users = _list_users;
    my $templates = _list_templates;

    template 'setup_welcome', {
        database => param('database'),
        databases => $databases,
        users => $users,
        templates => $templates,
    };
};

post '/create-company' => require_login sub {
    'Todo'
};

post '/create-user' => require_login sub {
    'Todo'
};

get '/edit-user' => require_login sub {
    'Todo'
};

get '/login' => sub {
    template 'transparent_login' => {}, { layout => '' };
};

post '/upgrade' => sub {
    'Todo'
};

post '/load-templates' => sub {
    'Todo'
};

get '/setup/' => require_login sub {
    # Workaround for
    # https://github.com/PerlDancer/Dancer2-Plugin-Auth-Extensible/issues/82
    redirect '/';
};

1;
