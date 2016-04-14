
package WebService::Pinterest::Common;

use Moose::Role;

sub fetch_me {
    shift()->call( GET => '/v1/me/', @_ );
}

sub fetch_my_boards {
    shift()->call( GET => '/v1/me/boards/', @_ );
}

sub fetch_my_suggested_boards {
    shift()->call( GET => '/v1/me/boards/suggested/', @_ );
}

sub fetch_my_likes {
    shift()->call( GET => '/v1/me/likes/', @_ );
}

sub fetch_my_pins {
    shift()->call( GET => '/v1/me/pins/', @_ );
}

sub fetch_pin {
    shift()->call( GET => '/v1/pins/:pin/', @_ );
}

sub create_pin {
    shift()->call( POST => '/v1/pins/', @_ );
}

1;
