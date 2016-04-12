package WebService::Pinterest;

# ABSTRACT: Pinterest API client

use strict;
use warnings;

use Moose;

with 'WebService::Pinterest::Spec';

use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;
use Carp qw(croak);

use namespace::autoclean;

has app_id => (
    is        => 'ro',
    predicate => 'has_app_id',
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

sub last_ua_request {
    my $res = shift()->last_ua_response;
    $res && $res->request;
}

# $req = $self->_build_request($method, $endpoint, %params);
# $req = $self->_build_request($method, $endpoint, \%params);
# $req = $self->_build_request($method, $endpoint, \%params, \%opts);
sub _build_request {
    my $self     = shift;
    my $method   = shift;
    my $endpoint = shift;

    my ( $params, $opts );
    if ( ref $_[0] eq 'HASH' ) {    # \%params
        $params = shift;
        if (@_) {                   # \%opts
            die "Invalid usage" unless ref $_[0] eq 'HASH';
            $opts = shift;
        }
    }
    elsif ( @_ % 2 == 0 ) {         # %params
        $params = {@_};
    }
    else {
        die "Invalid usage";
    }
    ## FIXME explain better "Invalid usage" errors

    # TODO check: $method is one of GET, POST, PATCH, DELETE
    # TODO check: $endpoint looks like relative or absolute file path

    unless ( $endpoint =~ m{^/} ) {
        $endpoint = '/v1/' . $endpoint;
    }

    if ( $self->has_access_token ) {
        $params = { access_token => $self->access_token, %$params };
    }

    # Validate params
    my ( $path, $query ) =
      $self->validate_endpoint_params( $method, $endpoint, $params, $opts );

    my $uri = URI->new;
    $uri->scheme( $self->api_scheme );
    $uri->host( $self->api_host );
    $uri->path($path);
    $uri->query_form($query);

    my $req = HTTP::Request->new( $method => $uri );
    return $req;
}

# $res = $api->call( $method => $endpoint, %params );
# $res = $api->call( $method => $endpoint, \%params );
# $res = $api->call( $method => $endpoint, \%params, \%opts );
sub call {
    my $self = shift;
    my $req  = $self->_build_request(@_);

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

# $url = $api->authorization_url(
#                response_type => 'code',
#                state         => $state,
#                scope         => $permission_scope, # eg. 'read_public,write_public'
#                redirect_uri  => $redirect_uri,     # defined in your app settings
#                );
#
# Used to get the authorization from app user
sub authorization_url {
    my $self = shift;

    unless ( $self->has_app_id ) {
        croak "Attribute app_id must be set";    # FIXME throw
    }

    my $req = $self->_build_request(
        GET => '/oauth',
        {
            client_id => $self->app_id,
            @_,
        },
    );
    return $req->uri->as_string;
}

#    $res = $pinner->get_access_token(
#        grant_type => 'authorization_code',
#        code       => $code,
#    );
# Used to get authorization code
sub get_access_token {
    my $self = shift;

    unless ( $self->has_app_id && $self->has_app_secret ) {
        croak "Attributes app_id & app_secret must be set";    # FIXME throw
    }

    return $self->call(
        POST => '/v1/oauth/token',
        {
            client_id     => $self->app_id,
            client_secret => $self->app_secret,
            @_,
        },
    );
}

sub fetch_me        { shift()->call( GET => '/v1/me/',        @_ ) }
sub fetch_my_boards { shift()->call( GET => '/v1/me/boards/', @_ ) }

sub fetch_my_suggested_boards {
    shift()->call( GET => '/v1/me/boards/suggested/', @_ );
}    ##
sub fetch_my_likes { shift()->call( GET => '/v1/me/likes/', @_ ) }
sub fetch_my_pins  { shift()->call( GET => '/v1/me/pins/',  @_ ) }

sub fetch_pin { shift()->call( GET => '/v1/pins/:pin/', @_ ) }

# $res = $api->fetch($resource, %args);
sub fetch {
    my $self     = shift;
    my $resource = shift;

    # FIXME check resource exists
    return $self->call( GET => $resource, @_ );
}

sub create {
    my $self     = shift;
    my $resource = shift;

    # FIXME check resource exists
    return $self->call( POST => $resource, @_ );
}

sub edit {
    my $self     = shift;
    my $resource = shift;

    # FIXME check resource exists
    return $self->call( PATCH => $resource, @_ );
}

sub delete {
    my $self     = shift;
    my $resource = shift;

    # FIXME check resource exists
    return $self->call( DELETE => $resource, @_ );
}

sub create_pin {
    my $self = shift;
    return $self->call( POST => '/v1/pins/', @_ );
}

1;
