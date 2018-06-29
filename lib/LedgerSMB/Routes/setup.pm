package LedgerSMB::Routes::setup;

use Dancer2 appname => 'LedgerSMB/Setup';

use Dancer2::Plugin::Auth::Extensible;


hook before_template => sub {
    my ($tokens) = @_;

    $tokens->{text} = sub { return shift };
};

get '/' => require_login sub {
    'Ok.'
};

get '/setup/' => require_login sub {
    # Workaround for https://github.com/PerlDancer/Dancer2-Plugin-Auth-Extensible/issues/82
    redirect '/';
};

1;
