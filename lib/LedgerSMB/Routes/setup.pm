package LedgerSMB::Routes::setup;

use Dancer2 appname => 'LedgerSMB/Setup';

use Dancer2::Plugin::Auth::Extensible;


use LedgerSMB;

hook before => sub {
    # we want separate auth cookies for setup and the main app
    engine('session')->{cookie_name} = 'ledgersmb.setup';
};

hook before_template => sub {
    my ($tokens) = @_;

    $tokens->{text} = sub { return shift };
    $tokens->{ledgersmb_version} = $LedgerSMB::VERSION;
};

get '/' => require_login sub {
    'Ok.'
};

get '/setup/' => require_login sub {
    # Workaround for
    # https://github.com/PerlDancer/Dancer2-Plugin-Auth-Extensible/issues/82
    redirect '/';
};

1;
