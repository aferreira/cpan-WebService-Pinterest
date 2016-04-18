#!/usr/bin/env perl

# Usage: perl -Ilib etc/generate_common.pl

use strict;
use warnings;

use Text::Caml;

use WebService::Pinterest;

my %BASE_METHOD_FOR = (
    GET    => 'fetch',
    POST   => 'create',
    PATCH  => 'edit',
    DELETE => 'delete',
);

my @endpoint_specs = @WebService::Pinterest::Spec::ENDPOINT_SPECS;    # XXX
my @endpoints;
for my $e_spec (@endpoint_specs) {
    next unless $e_spec->{resource};

    my ( $m, $p ) = @{ $e_spec->{endpoint} };

    my $b = $BASE_METHOD_FOR{$m};    # fetch, create, ...
    my $r =
      do { my $r = $e_spec->{resource}; ref $r eq 'ARRAY' ? $r->[0] : $r };
    $r =~ s{/}{_}g;                  # me, my_boards, ...

    my $om = ( $b eq 'fetch' && $r =~ /^search_/ ) ? $r : "${b}_${r}";

    push @endpoints, {
        object_method => $om,        # fetch_me, create_pin, ...
        http_method   => $m,         # GET, POST, ...
        endpoint_path => $p,         # /v1/me/, /v1/pins/ ...
    };

}

my $template = do { local $/; <DATA> };
my $view     = Text::Caml->new();
my $output   = $view->render( $template, { endpoint => \@endpoints } );

my $PM = 'lib/WebService/Pinterest/Common.pm';
open my $pm, '>', $PM
  or die "Can't open $PM: $!\n";
print {$pm} $output;
close $pm
  or warn "Problem to close $PM: $!\n";

__DATA__

package WebService::Pinterest::Common;

use Moose::Role;

{{#endpoint}}
sub {{object_method}} {
    shift()->call( {{http_method}} => '{{endpoint_path}}', @_ );
}


{{/endpoint}}

1;

