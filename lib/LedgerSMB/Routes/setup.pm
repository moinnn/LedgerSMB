package LedgerSMB::Routes::setup;

use Dancer2 appname => 'LedgerSMB/Setup';

use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::SessionDatabase;

use Locale::Country;
use Try::Tiny;

use LedgerSMB;
use LedgerSMB::Database;
use LedgerSMB::Entity::Person::Employee;
use LedgerSMB::Entity::User;
use LedgerSMB::Sysconfig;
use LedgerSMB::Template::DB;

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


sub _list_countries {
    return [
        sort { $a->{name} cmp $b->{name} }
        map { +{ code => $_, name => code2country($_) } }
        all_country_codes()
        ];
}

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

sub _list_directory {
    my $dir = shift;

    return [] if ! -d $dir;

    opendir(COA, $dir);
    my @files =
        map +{ code => $_ },
        sort(grep !/^(\.|[Ss]ample.*)/,
             readdir(COA));
    closedir(COA);

    return \@files;
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

sub _coa_countries {
    my $countries = _list_directory('sql/coa');

    for my $country (@$countries) {
        $country->{name} = code2country($country->{code}, 'alpha-2');
        for my $dir (qw(chart gifi sic)) {
            $country->{$dir} =
                _list_directory("sql/coa/$country->{code}/$dir");
        }
    }

    return [ sort { $a->{name} cmp $b->{name} } @$countries ];
}

sub _coa_data {
    my $coa_countries = _coa_countries();
    return {
        map { $_->{code} => $_ }
        @$coa_countries
    };
}

sub _template_sets {
    my $templates = _list_directory('templates');

    return $templates;
}

sub _load_templates {
    my $template_dir = shift;
    my $basedir = LedgerSMB::Sysconfig::templates();

    for my $filename (
        grep { $_ =~ m|^\Q$basedir/$template_dir/\E| }
        File::Find::Rule->new->in($basedir)) {

        my $dbtemp = LedgerSMB::Template::DB->get_from_file($filename);
        $dbtemp->save; ###TODO: Check return value!
    }
}

sub _create_user {
    my ($database, $employeenumber, $dob, $ssn, $username,
        $pls_import, $password) = @_;
    my $employee = LedgerSMB::Entity::Person::Employee->new(
        dbh => $database->dbh,
        control_code => $employeenumber,
        dob => LedgerSMB::PGDate->from_input($dob),
        ssn => $ssn,
        );
    $employee->save;

    my $user = LedgerSMB::Entity::User->new(
        dbh => $database->dbh,
        entity_id => $employee->id,
        username => $username,
        pls_import => ($pls_import eq '1'),
        );
    try {
        $user->create($password);
    }
    catch {
        if ($_ =~ /duplicate user/i) {
            ###TODO: Offer form for resubmission!
            # Option: check before we start the creation process?
            return _template_create_company(
                q{Company creation failed. Duplicate user.});
        }
        else {
            die $_;
        }
    };
}

sub _assign_user_roles {
    my ($database, $username, $roles) = @_;

    for my $role (@$roles) {
        PGObject->call_procedure(
            dbh => $database->dbh,
            funcname => 'admin__add_user_to_role'
            args => [ $username, $role ]);
    }
}

sub _get_admin_roles {
    return [
        map { $_->{rolname} }
        PGObject->call_procedure(
                 dbh => $database->dbh,
                 funcname => 'admin__get_roles',
                 args => [])
        ];
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

sub _template_create_company {
    template 'create-company', {
        'coa_countries' => _coa_countries(),
        'coa_data' => _coa_data(),
        'templates' => , _template_sets(),
        'username' => '',
        'salutations' => [
            { id => 1, salutation => 'Dr.' },
            { id => 2, salutation => 'Miss.' },
            { id => 3, salutation => 'Mr.' },
            { id => 4, salutation => 'Mrs.' },
            { id => 5, salutation => 'Ms.' },
            { id => 6, salutation => 'Sir.' }
            ],
        'countries' => _list_countries(),
        'perm_sets' => [
            { id =>  0, label => 'Manage Users' },
            { id =>  1, label => 'Full Permissions' },
            { id => -1, label => 'No changes' },
            ],
    };
}

post '/create-company' => require_login sub {
    my $error_message = '';
    my $action = param('action');

    if (! ($action && $action eq 'create')) {
        return _template_create_company();
    }

    my @missing_params;
    for my $param (qw(username first_name last_name country_id perms)) {
        if (undefined param($param)) {
            push @missing_params, $param;
        }
    }
    die "Missing required values: " . join(', ', @missing_params)
        if @missing_params;

    my $dbname = session->read('__auth_extensible_database');
    my $database = LedgerSMB::Database->new(
        username => session->read('logged_in_user'),
        password => session->read('__auth_extensible_pass'),
        dbname => $dbname);
    my $info = $database->get_info;

    if ($info->{status} ne 'does not exist') {
        return _template_create_company("Database '$dbname' already exists");
    }
    my $rc = $database->create_and_load;
    if ($rc != 0) {
        ###TODO: include the failure logs in the result page!
        return _template_create_company(
            'Database creation & initialisation failed');
    }

    # for my $filename (
    #     grep { $_ =~ m|^\Qsql/coa/\E|;

    $rc = $database->load_coa(
        ###TODO: Validate country/chart/gifi/sic parameters!
        {
            country => param('coa_country'),
            chart => param('chart'),
            gifi => param('gifi'),
            sic => param('sic'),
        });
    if ($rc != 0) {
        return _template_create_company(
            q{Initial COA load failed -- Database creation aborted});
    }

    _load_templates(param('template_dir'));
    _create_user($database, param('employeenumber'), param('dob'), param('ssn'),
                 param('username'), param('pls_import'), param('password'));

    if (param('perms') != -1) {
        _assign_user_roles( param('username'),
                            (param('perms') == 0)
                            ? [ 'users_manage' ] : _get_admin_roles );
    }
    $database->dbh->commit;
    ###TODO: rebuild_modules
};

post '/create-user' => require_login sub {
    'Todo'
};

get '/edit-user' => require_login sub {
    'Todo'
};

sub render_login_template {
    template 'transparent_login' => {
        return_url => query_parameters->get('return_url')
    }, { layout => undef };
}

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
