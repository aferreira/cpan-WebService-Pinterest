
package WebService::Pinterest::Pager;

use Jojo::Base -base;

use zim 'Carp' => 'croak';

use Safe::Isa '$_isa';    # XXX

sub api { $_[0]{api} }

sub call { $_[0]{call} }

sub total { $_[0]{total} }

# Internal state

has 'active' => 1;

has 'next_tx';

sub new {
    my $self = shift->SUPER::new(@_);

    croak qq{Attribute (api) is required}
      unless exists $self->{api};
    croak
qq{Attribute (api) is invalid: value $self->{api} (not isa WebService::Pinterest)}
      unless $self->{api}->$_isa('WebService::Pinterest');

    croak qq{Attribute (call) is required}
      unless exists $self->{call};
    croak qq{Attribute (call) is invalid: value $self->{call} (not arrayref)}
      unless ref $self->{call} eq 'ARRAY';

    $self->{total} //= 0;

    croak qq{Attribute (total) is invalid: value $self->{total} (not int)}
      unless !ref $self->{total} && $self->{total} =~ /\A[0-9]+\z/;

    # First request
    my $tx = $self->api->_build_tx( @{ $self->call } );    # throws
    $self->next_tx($tx);

    return $self;
}

sub inc_total { ++$_[0]->{total} }

sub next {
    my $self = shift;

    return undef unless $self->active;

    my $tx = $self->next_tx;
    return !1 unless defined $tx;

    $self->inc_total;
    my $res = $self->api->_call($tx);

    if ( exists $res->{page} ) {
        if ( defined $res->{page}{next} ) {
            my $next_url = $res->{page}{next};
            my $next_tx  = self->api->_build_next_tx($next_url);
            $self->next_tx($next_tx);
        }
        elsif ( exists $res->{data} && scalar @{ $res->{data} } == 0 )
        {    # It is over
            $self->next_tx(undef);
            return !1;
        }
        else {    # That was the last page
            $self->next_tx(undef);
        }
        return $res;

    }

    # On error
    $self->active( !1 );
    return undef;

}

1;
