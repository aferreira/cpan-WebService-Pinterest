
package WebService::Pinterest::Spec;

use strict;
use warnings;

use Moose::Role;

use Carp qw(carp croak);
use Params::Validate qw(:all);
use Data::Validate::URI qw(is_web_uri is_https_uri);
use List::MoreUtils qw(all);

use WebService::Pinterest::X;

use namespace::autoclean;

my @ENDPOINTS = (
    {
        type       => 'plain',
        endpoint   => [ GET => '/oauth' ],
        parameters => {
            response_type => { spec => 'response-code' },
            client_id     => { spec => 'client-id' },
            state         => { spec => 'any', optional => 1 },
            scope         => { spec => 'permission-list' },
            redirect_uri  => { spec => 'https-uri' },

        },
    },
    {
        type       => 'plain',
        endpoint   => [ POST => '/v1/oauth/token' ],
        parameters => {
            grant_type    => { spec => 'grant-type' },
            client_id     => { spec => 'client-id' },
            client_secret => { spec => 'any' },
            code          => { spec => 'any' },
        },
    },
    ## TODO oauth/inspect

    # Users
    # https://developers.pinterest.com/docs/api/users/#fetch-user-data
    {
        endpoint => [ GET => '/v1/me/' ],
        object   => 'user',
    },
    {
        endpoint => [ GET => '/v1/me/boards/' ],
        object   => 'board',
    },
    {
        endpoint => [ GET => '/v1/me/boards/suggested/' ],
        object   => 'board',
    },
    {
        endpoint => [ GET => '/v1/me/likes/' ],
        object   => 'pin',
        ## TODO cursor, maybe type => 'std+cursor' or '+cursor'
    },
    {
        endpoint => [ GET => '/v1/me/pins/' ],
        object   => 'pin',
        ## TODO cursor
    },

    # hinted at https://developers.pinterest.com/docs/api/overview/#user-errors
    {
        endpoint   => [ GET => '/v1/users/:user' ],
        object     => 'user',
        parameters => {
            user => { spec => 'user-id' },
        },
    },

    # https://developers.pinterest.com/docs/api/users/#search-user-data
    {
        endpoint   => [ GET => '/v1/me/search/boards/' ],
        object     => 'board',
        parameters => {
            query => { spec => 'any' },
        },
        ## TODO cursor
    },
    {
        endpoint   => [ GET => '/v1/me/search/pins/' ],
        object     => 'board',
        parameters => {
            query => { spec => 'any' },
        },
        ## TODO cursor
    },

    # https://developers.pinterest.com/docs/api/users/#create-follow-data
    {
        endpoint   => [ POST => '/v1/me/following/boards/' ],
        object     => 'board',
        parameters => {
            board => { spec => 'board' },
        },
    },
    {
        endpoint   => [ POST => '/v1/me/following/users/' ],
        object     => 'user',
        parameters => {
            user => { spec => 'user-id' },
        },

        # 'POST /v1/me/following/users/:user/' works too 2016-04-10
    },

    # https://developers.pinterest.com/docs/api/users/#fetch-follow-data
    {
        endpoint => [ GET => '/v1/me/followers/' ],
        object   => 'user',
        ## TODO cursor
    },
    {
        endpoint => [ GET => '/v1/me/following/boards/' ],
        object   => 'board',
        ## TODO cursor
    },
    {
        endpoint => [ GET => '/v1/me/following/interests/' ],
        object   => 'interest',
        ## TODO cursor
    },
    {
        endpoint => [ GET => '/v1/me/following/users/' ],
        object   => 'user',
        ## TODO cursor
    },

    # https://developers.pinterest.com/docs/api/users/#remove-follow-data
    {
        endpoint   => [ DELETE => '/v1/me/following/boards/:board/' ],
        object     => 'board',
        parameters => {
            board => { spec => 'board' },
        },
    },
    {
        endpoint   => [ DELETE => '/v1/me/following/users/:user/' ],
        object     => 'user',
        parameters => {
            user => { spec => 'user-id' },
        },
    },

    # https://developers.pinterest.com/docs/api/boards/#create-boards
    {
        endpoint   => [ POST => '/v1/boards/' ],
        object     => 'board',
        parameters => {
            name        => { spec => 'any' },
            description => { spec => 'any', optional => 1 },
        },
    },

    # https://developers.pinterest.com/docs/api/boards/#fetch-board-data
    {
        endpoint   => [ GET => '/v1/boards/:board/' ],
        object     => 'board',
        parameters => {
            board => { spec => 'board' },
        },
    },
    {
        endpoint   => [ GET => '/v1/boards/:board/pins/' ],
        object     => 'pin',
        parameters => {
            board => { spec => 'board' },
        },
    },

    # https://developers.pinterest.com/docs/api/boards/#edit-boards
    {
        endpoint   => [ PATCH => '/v1/boards/:board/' ],
        object     => 'board',
        parameters => {
            board       => { spec => 'board' },
            name        => { spec => 'any', optional => 1, },
            description => { spec => 'any', optional => 1 },
        },
    },

    # https://developers.pinterest.com/docs/api/boards/#delete-boards
    {
        endpoint   => [ DELETE => '/v1/boards/:board/' ],
        object     => 'board',
        parameters => {
            board => { spec => 'board' },
        },
    },

    # https://developers.pinterest.com/docs/api/pins/#create-pins
    {
        endpoint   => [ POST => '/v1/pins/' ],
        object     => 'pin',
        parameters => {
            board          => { spec => 'board' },
            note           => { spec => 'any', },
            link           => { spec => 'web-uri', optional => 1 },
            image_url      => { spec => 'web-uri', optional => 1 },
            image_base64 => { spec => 'web-uri', optional => 1 },

            #image_upload => { spec => 'upload', optional => 1},
            ## FIXME implement one-of-three requirement
        },
    },

    # https://developers.pinterest.com/docs/api/pins/#fetch-pins
    {
        endpoint   => [ GET => '/v1/pins/:pin/' ],
        object     => 'pin',
        parameters => {
            pin => { spec => 'pin-id' },
        },
    },

    # https://developers.pinterest.com/docs/api/pins/#edit-pins
    {
        endpoint   => [ PATCH => '/v1/pins/:pin/' ],
        object     => 'pin',
        parameters => {
            pin   => { spec => 'pin-id' },
            board => { spec => 'board', optional => 1 },
            note  => { spec => 'any', optional => 1 },
            link  => { spec => 'web-uri', optional => 1 },
        },
    },

    # https://developers.pinterest.com/docs/api/pins/#delete-pins
    {
        endpoint   => [ DELETE => '/v1/pins/:pin/' ],
        object     => 'pin',
        parameters => {
            pin => { spec => 'pin-id' },
        },
    },
);

my %IS_PERMISSION = map { $_ => 1 } qw(
  read_public
  write_public
  read_relationships
  write_relationships
);

sub is_pinterest_permission_list {
    my $suspect = shift;
    return 1 if defined $suspect && length($suspect) == 0;    # None
    return all { $IS_PERMISSION{$_} } split( ',', $suspect );
}

sub is_pinterest_response_code {
    my $suspect = shift;
    return 1 if defined $suspect && ( $suspect eq 'code' );
    return 0;
}

sub is_pinterest_grant_type {
    my $suspect = shift;
    return 1 if defined $suspect && ( $suspect eq 'authorization_code' );
    return 0;
}

# spec x predicate
my %PREDICATE_FOR = (

    'any'       => sub { length( shift() ) > 0 },
    'https-uri' => \&is_https_uri,
    'web-uri'   => \&is_web_uri,
    'pinterest:response-code' => \&is_pinterest_response_code,
    'pinterest:grant-type'    => \&is_pinterest_grant_type,
    'pinterest:client-id'     => sub { shift() =~ qr/^[a-zA-Z0-9]+$/ },
    'pinterest:pin-id'        => sub { shift() =~ qr/^[a-zA-Z0-9\-]+$/ },
    'pinterest:user-id'       => sub { shift() =~ qr/^[a-zA-Z0-9]+$/ },
    'pinterest:board' =>
      sub { shift() =~ qr{^[a-z0-9]+/[a-z0-9\-]+$|^[0-9]+$} },
    'pinterest:permission-list' => \&is_pinterest_permission_list,

);
$PREDICATE_FOR{'pinterest:access-token'} = $PREDICATE_FOR{'any'};
$PREDICATE_FOR{'pinterest:user-fields'}  = $PREDICATE_FOR{'any'};    # FIXME
$PREDICATE_FOR{'pinterest:board-fields'} = $PREDICATE_FOR{'any'};    # FIXME
$PREDICATE_FOR{'pinterest:pin-fields'}   = $PREDICATE_FOR{'any'};    # FIXME
$PREDICATE_FOR{'pinterest:interest-fields'} =
  $PREDICATE_FOR{'any'};    # FIXME at least id,name

sub _compile_spec {
    my $specs = shift;
    my %specs;
    for my $k ( keys %$specs ) {
        my $v = $specs->{$k};
        my $s = $v->{spec}
          or die "No 'spec' for parameter $k\n";
        my $p = $PREDICATE_FOR{$s} // $PREDICATE_FOR{"pinterest:$s"}
          or die "Unknown 'spec' ($s) for parameter $k\n";
        my $cb = sub {
            return 1 if $p->( $_[0] );
            WebService::Pinterest::Spec::X->throw(
                {
                    key     => $k,
                    value   => $_[0],
                    message => "Invalid parameter '%s' (%s)"
                }
            );
        };
        $specs{$k} = { %$v, type => SCALAR, callbacks => { check => $cb } };
    }
    return \%specs;
}

# ($tpl, $places, $argns) = _compile_path($enpoint_path);
#
#   $places (the mapping between sprintf parameters and named placeholders)
#   $argns  (the current argument names)
#
#  TODO escape special chars for sprintf
sub _compile_path {
    my $path   = shift;
    my $tpl    = '';
    my @places = ();
    my %args   = ();

    for ( $_ = $path ; ; ) {
        $tpl .= ':', next
          if /\G\\:/gc;
        $tpl .= '%s', push( @places, $1 ), $args{$1} = 1, next
          if /\G:([a-z0-9_]+)/gc;
        $tpl .= $1, next
          if /\G([^:]*)/gc;
        last;
    }

    # if not at the end of string, invalid use of :[^\w:] -> not yet implemented

    my @argns = keys %args;
    return ( $tpl, \@places, \@argns );
}

sub _compile_endpoints {

    my $compiled;
    for my $ep (@ENDPOINTS) {
        my $endpoint = $ep->{endpoint};
        my $params   = $ep->{parameters} // {};
        my $k        = join( ' ', @$endpoint );    # eg. 'POST /v1/pins'
        my $v;

        die "Error: endpoint '$k' redefined\n" if exists $compiled->{$k};

        $ep->{type} //=
          'std';    # default endpoint type (includes 'access_token' + 'fields')
        if ( $ep->{type} eq 'std' ) {

            # add access_token & fields
            my $object = $ep->{object}
              or die
              "Error in '$k' endpoint specs: no 'object' where type='std'\n";
            $params->{access_token} //= { spec => 'access-token' };
            $params->{fields} //= { spec => "$object-fields", optional => 1 };
        }

        my $path = $endpoint->[1];
        my ( $tpl, $places, $argns ) = _compile_path($path);
        if (@$argns) {
            $v->{path_tpl} =
              { tpl => $tpl, places => $places, argns => $argns };
            $params->{$_}{optional} = 0 for @$argns;
        }
        else {
            $v->{path} = $tpl;
        }

        my $spec = $params;
        my $pv_spec = eval { _compile_spec($spec) };
        die "Failed to compile '$k' endpoint specs: $@" if $@;
        $v->{spec} = $pv_spec;

        $compiled->{$k} = $v;
    }
    return $compiled;
}

our $COMPILED_ENDPOINTS = _compile_endpoints();

# $compiled = $api->find_endpoint($method, $endpoint);
sub find_endpoint {
    my ( $self, $method, $endpoint ) = @_;
    my $k = join( ' ', $method, $endpoint );
    return $COMPILED_ENDPOINTS->{$k};
}

# ($path, $query) = $api->validate_endpoint_params($method, $endpoint, $params);
sub validate_endpoint_params {
    my ( $self, $method, $endpoint, $params ) = @_;
    my $compiled = $self->find_endpoint( $method, $endpoint );
    unless ($compiled) {
        carp "Could not find spec for '$method $endpoint'";
        return $params;
    }

    my $checked = validate_with(
        params => [%$params],
        spec   => $compiled->{spec},

        #normalize
        #called
    );

    my $path;
    if ( $compiled->{path} ) {
        $path = $compiled->{path};
    }
    else {
        my ( $tpl, $places, $argns ) =
          @{ $compiled->{path_tpl} }{qw(tpl places argns)};
        $path = sprintf( $tpl, @{$params}{@$places} );
        delete @{$params}{@$argns};
    }

    # FIXME $params is changed

    return ( $path, $params );
}

1;

