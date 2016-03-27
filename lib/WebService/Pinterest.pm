package WebService::Pinterest;

use strict;
use warnings;

use Moose;

use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;

has app_id => (
    is       => 'ro',
    required => 1,
);

has app_secret => (
    is        => 'ro',
    predicate => 'has_app_secret',
);

has api_host => (
    is      => 'ro',
    default => 'api.pinterest.com'
);

has api_scheme => (
    is      => 'ro',
    default => 'https',
);

has ua => (
    is      => 'ro',
    default => sub { LWP::UserAgent->new },
);

has access_token => (
    is        => 'rw',
    predicate => 'has_access_token',
    clearer   => 'clear_access_token',
);

# $req = $self->_build_request($method, $endpoint, %args);
sub _build_request {

    my ( $self, $method, $endpoint, %args ) = @_;

    # TODO check: $method is one of GET, POST, PATCH, DELETE
    # TODO check: $endpoint looks like relative or absolute file path
    # TODO check: $query is map<str,str>
    #

    my $query = $args{query} // {};
    my $path = ( $endpoint =~ m{^/} ) ? $endpoint : '/v1/' . $endpoint;
    my $uri = URI->new;
    $uri->scheme( $self->api_scheme );
    $uri->host( $self->api_host );
    $uri->path($path);
    $uri->query_form( $self->has_access_token
        ? { access_token => $self->access_token, %$query }
        : $query );

    my $req = HTTP::Request->new( $method => $uri );
    return $req;
}

# ($res, $http_res) = $api->call( $method => $endpoint, query => \%query );
sub call {
    my ( $self, $method, $endpoint, %args ) = @_;
    my $req = $self->_build_request( $method, $endpoint, %args );
    my $ua  = $self->ua;
    my $res = $ua->request($req);

    # JSON decode content
    my $r;
    if ( $res && $res->content_type eq 'application/json' ) {
        my $json = $res->decoded_content;
        $r = eval { decode_json($json) };
        if ( my $err = $@ ) {
            $r = { error => 'bad_json', message => $err, json => $json };
        }
    }
    $r //= { error => 'not_json', content_type => $res->content_type };
    $r->{_code}        = $res->code;
    $r->{_status_line} = $res->status_line;
    return ( $r, $res );
}

sub _auth_code {

    # GET /oauth
    #    response_type: code
    #    client_id: <app_id>
    #    state:     <state>
    #    scope:     <permission scopes>, eg 'read_public,write_public'
    #    redirect_uri
}

sub authenticate {

    # Get authorization code
    #
    # Get access token
}

1;
