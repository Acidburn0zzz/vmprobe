package Vmprobe::Daemon::Router;

use 5.10.0;
use common::sense;

use Regexp::Assemble;
use Plack::Request;
use Plack::Response;
use JSON::XS;

use Vmprobe::Daemon::API::RequestContext;


sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    $self->{ra} = Regexp::Assemble->new->track(1);
    $self->{patterns} = {};

    return $self;
}




sub mount {
    my ($self, $spec) = @_;

    foreach my $route (keys %{ $spec->{routes} }) {
        my $re = '\A' . $route . '\z';

        ## Hack for Regexp::Assemble: https://github.com/ronsavage/Regexp-Assemble/issues/4
        $re =~ s{/}{\\/}g;

        $re =~ s{:([\w]+)}{(?<$1>[^/]+)};

        $self->{ra}->add($re);

        $self->{patterns}->{$re} = {
            methods => $spec->{routes}->{$route},
            entity => $spec->{entity},
        };
    }
}


sub _compile {
    my ($self) = @_;

    $self->{re} = $self->{ra}->re;
}


sub route {
    my ($self, $env) = @_;

    my $path = $env->{PATH_INFO};
    $path = '/' if $path eq '';

    $self->_compile() if !exists $self->{re};

    if ($path !~ $self->{re}) {
        return [404, ["Content-Type" => "application/json"], ['{}']];
    }

    my $url_args = \%+;
    my $spec = $self->{patterns}->{ $self->{ra}->source($^R) };

    my $http_method = $env->{REQUEST_METHOD};

    my $method = $spec->{methods}->{$http_method};

    if (!defined $method) {
        return [405, ["Content-Type" => "application/json"], ['{}']];
    }

    my $req = Plack::Request->new($env);
    my $res = Plack::Response->new(200);

    my $params;

    if ($http_method eq 'GET') {
        $params = $req->query_parameters->as_hashref_mixed;
    } elsif ($req->content_type =~ /json/i) {
        my $raw_body = $req->raw_body;

        eval {
            $params = decode_json($raw_body);
        };

        if ($@) {
            return [400, ["Content-Type" => "text/plain"], ["json decode failed: $@"]];
        }
    } else {
        $params = $req->body_parameters->as_hashref_mixed;
    }

    my $c = Vmprobe::Daemon::API::RequestContext->new(
        req => $req,
        res => $res,
        url_args => $url_args,
        params => $params,
        lmdb => $self->{lmdb},
    );

    my $content = $spec->{entity}->$method($c);

    if (ref $content) {
        $res->content_type('application/json');
        $res->body(encode_json($content));
    } else {
        $res->body($content);
    }

    return $res->finalize;
}




1;
