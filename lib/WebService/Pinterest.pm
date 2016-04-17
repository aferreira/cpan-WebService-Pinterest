package WebService::Pinterest;

# ABSTRACT: Pinterest API client

use strict;
use warnings;

use Moose;

with 'WebService::Pinterest::Spec';
with 'WebService::Pinterest::Common';

use WebService::Pinterest::Upload;
use WebService::Pinterest::Pager;

use HTTP::Request;
use HTTP::Request::Common ();
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
    default => sub { LWP::UserAgent->new( agent => shift->ua_string ) },
    lazy    => 1,
);

has ua_string => (
    is => 'ro',
    default =>
      sub { "WebService-Pinterest-perl/$WebService::Pinterest::VERSION" },
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
    my $self = shift;

    my ( $method, $path, $query, $form_data ) = $self->validate_call(@_);

    my $uri = URI->new;
    $uri->scheme( $self->api_scheme );
    $uri->host( $self->api_host );
    $uri->path($path);
    $uri->query_form($query);

    if ($form_data) {
        return HTTP::Request::Common::POST(
            $uri,
            'Content-Type' => 'multipart/form-data',
            'Content'      => $form_data
        );
    }
    else {
        return HTTP::Request->new( $method => $uri );
    }
}

# $upload = $api->upload($file);
# $upload = $api->upload($file, $filename);
sub upload {
    shift();
    return WebService::Pinterest::Upload->new( args => [@_] );
}

# $res = $api->call( $method => $endpoint, %params );
# $res = $api->call( $method => $endpoint, \%params );
# $res = $api->call( $method => $endpoint, \%params, \%opts );
sub call {
    my $self = shift;
    my $req  = $self->_build_request(@_);
    return $self->_call($req);
}

sub _call {
    my ( $self, $req ) = @_;

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
# );
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

# $res = $api->fetch($resource, %args);
sub fetch {
    my $self     = shift;
    my $resource = shift;

    my $endpoint = $self->resolve_resource( GET => $resource );
    unless ($endpoint) {
        croak "Can't find resource '$resource' to fetch\n";    # FIXME throw
    }
    return $self->call( @$endpoint, @_ );
}

sub create {
    my $self     = shift;
    my $resource = shift;

    my $endpoint = $self->resolve_resource( POST => $resource );
    unless ($endpoint) {
        croak "Can't find resource '$resource' to create\n";    # FIXME throw
    }
    return $self->call( @$endpoint, @_ );
}

sub edit {
    my $self     = shift;
    my $resource = shift;

    my $endpoint = $self->resolve_resource( PATCH => $resource );
    unless ($endpoint) {
        croak "Can't find resource '$resource' to edit\n";      # FIXME throw
    }
    return $self->call( @$endpoint, @_ );
}

sub delete {
    my $self     = shift;
    my $resource = shift;

    my $endpoint = $self->resolve_resource( DELETE => $resource );
    unless ($endpoint) {
        croak "Can't find resource '$resource' to delete\n";    # FIXME throw
    }
    return $self->call( @$endpoint, @_ );
}

# $pager = $api->fetch_paged($resource, ...);
sub fetch_paged {
    my $self     = shift;
    my $resource = shift;

    my $endpoint = $self->resolve_resource( GET => $resource );
    unless ($endpoint) {
        croak "Can't find resource '$resource' to fetch\n";     # FIXME throw
    }
    return $self->pager( @$endpoint, @_ );
}

sub pager {
    my $self = shift();
    # FIXME check: is the endpoint 'cursor' type?
    return WebService::Pinterest::Pager->new( api => $self, call => [@_] );
}

1;
