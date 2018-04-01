
package WebService::Pinterest::Pager;

use Jojo::Base -base;

use zim 'Carp' => 'croak';

use Safe::Isa '$_isa';    # XXX

sub api { $_[0]{api} }

sub call { $_[0]{call} }

sub total { $_[0]{total} }

# Internal state

has 'active' => 1;

has 'next_request';

sub new {
    my $self = shift->SUPER::new(@_);

    croak qq{Attribute (api) is required}
      unless exists $self->{api};
    croak qq{Attribute (api) is invalid: value $self->{api} (not isa WebService::Pinterest)}
      unless $self->{api}->$_isa('WebService::Pinterest');

    croak qq{Attribute (call) is required}
      unless exists $self->{call};
    croak qq{Attribute (call) is invalid: value $self->{call} (not arrayref)}
      unless ref $self->{call} eq 'ARRAY';

    $self->{total} //= 0;

    croak qq{Attribute (total) is invalid: value $self->{total} (not int)}
      unless !ref $self->{total} && $self->{total} =~ /\A[0-9]+\z/;

    # First request
    my $req = $self->api->_build_request( @{ $self->call } );    # throws
    $self->next_request($req);

    return $self;
}

sub inc_total { ++$_[0]->{total} }

sub next {
    my $self = shift;

    return undef unless $self->active;

    my $req = $self->next_request;
    return !1 unless defined $req;

    $self->inc_total;
    my $res = $self->api->_call($req);

    if ( exists $res->{page} ) {
        if ( defined $res->{page}{next} ) {
            my $next_url = $res->{page}{next};
            my $next_req = self->api->_build_next_request($next_url);
            $self->next_request($next_req);
        }
        elsif ( exists $res->{data} && scalar @{ $res->{data} } == 0 )
        {    # It is over
            $self->next_request(undef);
            return !1;
        }
        else {    # That was the last page
            $self->next_request(undef);
        }
        return $res;

    }

    # On error
    $self->active( !1 );
    return undef;

}

1;
