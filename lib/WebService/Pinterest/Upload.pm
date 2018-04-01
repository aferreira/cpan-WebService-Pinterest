
package WebService::Pinterest::Upload;

use Jojo::Base -base;

use zim 'Carp' => 'croak';

sub args { $_[0]{args} }

sub new {
    my $self = shift->SUPER::new(@_);

    croak qq{Attribute (args) is required}
      unless exists $self->{args};
    croak qq{Attribute (args) is invalid: value $self->{args} (not arrayref)}
      unless ref $self->{args} eq 'ARRAY';

    return $self;
}

sub file {
    shift->args->[0];
}

# Valid if file is a readable file
sub is_valid {
    my $file = shift()->file;
    $file && -r -f $file;
}

sub lwp_file_spec {
    shift()->args;
}

1;

