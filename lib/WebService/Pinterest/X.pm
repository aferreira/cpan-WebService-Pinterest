
package WebService::Pinterest::X;

use Jojo::Base -base;

use overload '""' => \&as_string;

sub new { shift->SUPER::new(shift) }

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

