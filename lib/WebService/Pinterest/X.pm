
package WebService::Pinterest::X;

use Jojo::Base -base;

use overload '""' => \&as_string;

sub new { shift->SUPER::new(shift) }

sub throw {
    die shift->new(shift);
}

sub as_string {
    my $self = shift;
    return sprintf $self->{message}, $self->{key}, $self->{value};
}

1;

=encoding utf8

=head1 NAME

WebService::Pinterest::X - Exceptions for WebService::Pinterest

=head1 SYNOPSIS

    use WebService::Pinterest::X;

    $x = WebService::Pinterest::X->new({ message => '%s %s', key => 'k', value => 'foo' } );

=head1 METHODS

=head2 as_string

    $str = $x->as_string;

=head2 new

    $x = WebService::Pinterest::X->new({ message => '%s %s', key => 'k', value => 'foo' } );

=over 4

=item key

=item value

=item message

=back

Constructor.

=head2 throw

    WebService::Pinterest::X->throw({ message => '%s %s', key => 'k', value => 'foo' } );

=cut
