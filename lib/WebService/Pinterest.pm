package WebService::Pinterest;

# ABSTRACT: Pinterest API client

use strict;
use warnings;

use Moose;

with 'WebService::Pinterest::Spec';

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

has access_token => (
    is        => 'rw',
    predicate => 'has_access_token',
    clearer   => 'clear_access_token',
);

has api_host => (
    is      => 'ro',
    default => 'api.pinterest.com'
);

has api_scheme => (
    is      => 'ro',
    default => 'https',
);

# Engine / Implementation mechanism

has ua => (
    is      => 'ro',
    default => sub { LWP::UserAgent->new },
);

# Context

has last_ua_response => ( is => 'rw', );

# $req = $self->_build_request($method, $endpoint, %args);
sub _build_request {

    my ( $self, $method, $endpoint, %args ) = @_;

    # TODO check: $method is one of GET, POST, PATCH, DELETE
    # TODO check: $endpoint looks like relative or absolute file path
    # TODO check: $query is map<str,str>
    #

    my $q = $args{query} // {};
    my $p = ( $endpoint =~ m{^/} ) ? $endpoint : '/v1/' . $endpoint;

    $q =
      $self->has_access_token
      ? { access_token => $self->access_token, %$q }
      : $q;

    # Validate params
    my ( $path, $query ) = $self->validate_endpoint_params( $method, $p, $q );

    my $uri = URI->new;
    $uri->scheme( $self->api_scheme );
    $uri->host( $self->api_host );
    $uri->path($path);
    $uri->query_form($query);

    my $req = HTTP::Request->new( $method => $uri );
    return $req;
}

# ($res, $http_res) = $api->call( $method => $endpoint, query => \%query );
sub call {
    my ( $self, $method, $endpoint, %args ) = @_;
    my $req = $self->_build_request( $method, $endpoint, %args );

    # TODO catch exception, convert to error response

    my $ua  = $self->ua;
    my $res = $ua->request($req);
    $self->last_ua_response($res);

    # Decode JSON content
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
    $r->{_http_status} = $res->status_line;

    return $r;
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

sub fetch_me {
    my $self = shift;
    return $self->call( GET => '/v1/me/', query => {@_} );
}

sub fetch_my_boards {
    my $self = shift;
    return $self->call( GET => 'me/boards/', query => {@_} );
}

sub fetch_pin {
    my $self = shift;
    return $self->call( GET => '/v1/pins/:pin/', query => {@_} );
}

# $res = $api->fetch($entity, %args);
sub fetch {
    my $self     = shift;
    my $resource = shift;

    # FIXME check resource exists
    return $self->call( GET => $resource, query => {@_} );
}

sub create_pin {
    my $self = shift;
    return $self->call( POST => '/v1/pins/', query => {@_} );
}

1;
