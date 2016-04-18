
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

sub fetch_user {
    shift()->call( GET => '/v1/users/:user', @_ );
}

sub search_my_boards {
    shift()->call( GET => '/v1/me/search/boards/', @_ );
}

sub search_my_pins {
    shift()->call( GET => '/v1/me/search/pins/', @_ );
}

sub create_my_following_board {
    shift()->call( POST => '/v1/me/following/boards/', @_ );
}

sub create_my_following_user {
    shift()->call( POST => '/v1/me/following/users/', @_ );
}

sub fetch_my_followers {
    shift()->call( GET => '/v1/me/followers/', @_ );
}

sub fetch_my_following_boards {
    shift()->call( GET => '/v1/me/following/boards/', @_ );
}

sub fetch_my_following_interests {
    shift()->call( GET => '/v1/me/following/interests/', @_ );
}

sub fetch_my_following_users {
    shift()->call( GET => '/v1/me/following/users/', @_ );
}

sub delete_my_following_board {
    shift()->call( DELETE => '/v1/me/following/boards/:board/', @_ );
}

sub delete_my_following_user {
    shift()->call( DELETE => '/v1/me/following/users/:user/', @_ );
}

sub create_board {
    shift()->call( POST => '/v1/boards/', @_ );
}

sub fetch_board {
    shift()->call( GET => '/v1/boards/:board/', @_ );
}

sub fetch_board_pins {
    shift()->call( GET => '/v1/boards/:board/pins/', @_ );
}

sub edit_board {
    shift()->call( PATCH => '/v1/boards/:board/', @_ );
}

sub delete_board {
    shift()->call( DELETE => '/v1/boards/:board/', @_ );
}

sub create_pin {
    shift()->call( POST => '/v1/pins/', @_ );
}

sub fetch_pin {
    shift()->call( GET => '/v1/pins/:pin/', @_ );
}

sub edit_pin {
    shift()->call( PATCH => '/v1/pins/:pin/', @_ );
}

sub delete_pin {
    shift()->call( DELETE => '/v1/pins/:pin/', @_ );
}


1;

