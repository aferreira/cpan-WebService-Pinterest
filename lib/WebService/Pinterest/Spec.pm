
package WebService::Pinterest::Spec;

use strict;
use warnings;

use Moose::Role;

use Carp qw(carp croak);
use Params::Validate qw(:all);
use Data::Validate::URI qw(is_web_uri is_https_uri);
use List::MoreUtils qw(all);

use namespace::autoclean;

# TODO type=std as default

my @ENDPOINTS = (
    {
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
        endpoint   => [ POST => '/v1/oauth/token' ],
        parameters => {},
    },

    # Users
    # https://developers.pinterest.com/docs/api/users/#fetch-user-data
    {
        endpoint => [ GET => '/v1/me/' ],
        object   => 'user',
        type     => 'std', # access_token + fields
    },
    { endpoint => [ GET => '/v1/me/boards/' ],
            object => 'board',
            type => 'std',
    },
    { endpoint => [ GET => '/v1/me/boards/suggested/' ],
            object => 'board',
            type => 'std',
    },
    { endpoint => [ GET => '/v1/me/likes/'],
            object => 'pin',
            type => 'std',
            # TODO cursor
    },
    { endpoint => [ GET => '/v1/me/pins/'],
            object => 'pin',
            type => 'std',
            # TODO cursor
    },

    # https://developers.pinterest.com/docs/api/users/#search-user-data
    # https://developers.pinterest.com/docs/api/users/#create-follow-data
    # https://developers.pinterest.com/docs/api/users/#fetch-follow-data
    # https://developers.pinterest.com/docs/api/users/#remove-follow-data

    {
        endpoint   => [ GET => '/v1/users/:user' ],
        object     => 'user',
        type       => 'std',
        parameters => {
            user => { spec => 'user-id' },
        },
    },
    {
        endpoint => [ GET => '/v1/me/boards/' ],
        object   => 'board',
        type     => 'std',
    },
    {
        endpoint   => [ GET => '/v1/boards/:board/' ],
        object     => 'board',
        type       => 'std',
        parameters => {
            board => { spec => 'board' },
        },
    },
    {
        endpoint   => [ GET => '/v1/pins/:pin/' ],
        object     => 'pin',
        type       => 'std',
        parameters => {
            pin => { spec => 'pin-id' },
        },
    },
    {
        endpoint   => [ POST => '/v1/pins/' ],
        object     => 'pin',
        type       => 'std',
        parameters => {
            board => { spec => 'board' },
            note  => { spec => 'any', },
            link  => { spec => 'web-uri', optional => 1 },
            image_url => { spec => 'web-uri' },    # FIXME other options
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

# spec x predicate
my %PREDICATE_FOR = (

    'any'       => sub { length( shift() ) > 0 },
    'https-uri' => \&is_https_uri,
    'web-uri'   => \&is_web_uri,
    'pinterest:response-code' => \&is_pinterest_response_code,
    'pinterest:client-id'     => sub { shift() =~ qr/^[a-zA-Z0-9]+$/ },
    'pinterest:pin-id'        => sub { shift() =~ qr/^[a-zA-Z0-9]+$/ },
    'pinterest:user-id'       => sub { shift() =~ qr/^[a-zA-Z0-9]+$/ },
    'pinterest:board' => sub { shift() =~ qr{^[a-z0-9]+/[a-z0-9]+$|^[0-9]+$} },
    'pinterest:permission-list' => \&is_pinterest_permission_list,

);
$PREDICATE_FOR{'pinterest:access-token'} = $PREDICATE_FOR{'any'};
$PREDICATE_FOR{'pinterest:user-fields'}  = $PREDICATE_FOR{'any'};    # FIXME
$PREDICATE_FOR{'pinterest:board-fields'} = $PREDICATE_FOR{'any'};    # FIXME
$PREDICATE_FOR{'pinterest:pin-fields'}   = $PREDICATE_FOR{'any'};    # FIXME

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

        if ($ep->{type} && $ep->{type} eq 'std') {

            # add access_token & fields
            my $object = $ep->{object}
              or die "Error in '$k' endpoint specs: no 'object' where type='std'\n";
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

package WebService::Pinterest::Spec::X;

use overload '""' => \&as_string;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    bless shift(), $class;
}

sub throw {
    die shift->new(shift);
}

# key
# value
# message

sub as_string {
    my $self = shift;
    return sprintf $self->{message}, $self->{key}, $self->{value};
}

1;

__END__

sub _auth_code {
        # GET /oauth
        #    response_type: code
        #    client_id: <app_id>
        #    state:     <state>
        #    scope:     <permission scopes>, eg 'read_public,write_public'
        #    redirect_uri
}

