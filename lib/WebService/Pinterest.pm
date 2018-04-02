package WebService::Pinterest;

# ABSTRACT: Pinterest API client

use Jojo::Base -base;

with 'WebService::Pinterest::Spec';
with 'WebService::Pinterest::Common';

use WebService::Pinterest::Upload;
use WebService::Pinterest::Pager;

use Mojo::UserAgent ();
use Mojo::URL       ();

use zim 'Carp'     => 'croak';
use zim 'JSON::XS' => 'decode_json';

sub app_id { $_[0]{app_id} }

sub has_app_id { exists $_[0]{app_id} }    # Predicate

sub app_secret { $_[0]{app_secret} }

sub has_app_secret { exists $_[0]{app_secret} }    # Predicate

sub access_token { $_[0]{access_token} }

sub has_access_token { exists $_[0]{access_token} }    # Predicate

has 'trace_calls';

sub api_host { $_[0]{api_host} //= 'api.pinterest.com' }

sub api_scheme { $_[0]{api_scheme} //= 'https' }

# Engine / Implementation mechanism

has 'ua' => sub {
    my $self = shift;
    Mojo::UserAgent->new->tap( sub { $_->transactor->name( $self->ua_string ) }
    );
};

has 'ua_string' =>
  sub { "WebService-Pinterest-perl/$WebService::Pinterest::VERSION" };

# Context

has 'last_ua_tx';

sub last_ua_response {
    my $tx = shift()->last_ua_tx;
    $tx && $tx->res;
}

sub last_ua_request {
    my $tx = shift()->last_ua_tx;
    $tx && $tx->req;
}

# $tx = $self->_build_tx($method, $endpoint, %params);
# $tx = $self->_build_tx($method, $endpoint, \%params);
# $tx = $self->_build_tx($method, $endpoint, \%params, \%opts);
sub _build_tx {
    my $self = shift;

    my ( $method, $path, $query, $form_data ) = $self->validate_call(@_);

    my $uri = Mojo::URL->new;
    $uri->scheme( $self->api_scheme );
    $uri->host( $self->api_host );
    $uri->path($path);
    $uri->query($query);

    if ($form_data) {
        my $headers = { 'Content-Type' => 'multipart/form-data' };
        return $self->ua->build_tx(
            $method => $uri => $headers => form => $form_data );
    }
    else {
        return $self->ua->build_tx( $method => $uri );
    }
}

# $tx = $api->_build_next_tx($url);
sub _build_next_request {
    my ( $self, $url ) = @_;
    return $self->ua->build_tx( GET => $url );
}

# $upload = $api->upload($file);
# $upload = $api->upload($file, $filename);
sub upload {
    shift();
    return WebService::Pinterest::Upload->new( args => [@_] );
}

# $tx = $api->call( $method => $endpoint, %params );
# $tx = $api->call( $method => $endpoint, \%params );
# $tx = $api->call( $method => $endpoint, \%params, \%opts );
sub call {
    my $self = shift;
    my $tx   = $self->_build_tx(@_);
    return $self->_call($tx);
}

sub _dump {
    my ( $msg, %args ) = @_;
    my $prefix = $args{prefix} // '';
    my $str = shift->to_string;
    $str =~ s/^/$prefix/gms;
    print STDERR $str, "\n";
}

sub _call {
    my $self = shift;

    # TODO catch exception, convert to error response

    my $tx = $self->ua->start(@_);
    $self->last_ua_tx($tx);

    my $res = $tx->res;

    if ( $self->trace_calls ) {
        my $req = $tx->req;
        _dump( $req, prefix => '< ' );
        _dump( $res, prefix => '> ' );
    }

    # Decode JSON content
    my $r;
    if ( $res && $res->headers->content_type eq 'application/json' ) {
        $r = $res->json;
        unless ( defined $r ) {
            $r = {
                _error   => 'bad_json',
                _message => 'Failed to decode body as JSON',
                json     => $res->body
            };
        }
    }
    $r //=
      { _error => 'not_json', _content_type => $res->headers->content_type };
    $r->{_http_status} = sprintf '%s %s', $res->code, $res->message;
    $r->{_status} = _status_group( $res->code );

    return $r;
}

sub _status_group {
    if ( $_[0] >= 200 && $_[0] < 300 ) {
        return 'success';
    }
    elsif ( $_[0] >= 400 && $_[0] < 500 ) {
        return 'error,client_error';
    }
    elsif ( $_[0] >= 500 && $_[0] < 600 ) {
        return 'error,server_error';
    }
    elsif ( $_[0] >= 300 && $_[0] < 400 ) {
        return 'redirect';
    }
    elsif ( $_[0] >= 100 && $_[0] < 200 ) {
        return 'info';
    }
    else {
        return 'unknown';
    }
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

    my $tx = $self->_build_tx(
        GET => '/oauth',
        {
            client_id => $self->app_id,
            @_,
        },
    );
    return $tx->req->uri->to_string;
}

#    $res = $api->get_access_token(
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

sub inspect_token {
    my $self = shift;

    unless ( $self->has_app_id && $self->has_access_token ) {
        croak "Attributes app_id & access_token must be set";    # FIXME throw
    }

    return $self->call(
        GET => '/v1/oauth/inspect',
        {
            client_id    => $self->app_id,
            access_token => $self->access_token,
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
