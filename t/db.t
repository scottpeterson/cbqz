use exact;
use Config::App;
use Test::Most;

use constant {
    PACKAGE    => 'CBQZ::Db',
    SUBPACKAGE => 'CBQZ::Db::Schema',
};

exit main();

sub main {
    BEGIN {
        use_ok(PACKAGE);
        use_ok(SUBPACKAGE);
    }
    require_ok(PACKAGE);
    require_ok(SUBPACKAGE);

    my $db;
    lives_ok( sub { $db = SUBPACKAGE->connect }, 'CBQZ::Db::Schema->connect' );
    lives_ok( sub { $db = SUBPACKAGE->connect }, 'CBQZ::Db::Schema->connect 2' );
    is( ref($db), 'CBQZ::Db::Schema', 'connect returns a CBQZ::Db::Schema object' );

    my $enum;
    lives_ok( sub { $enum = $db->enum( 'event', 'type' ) }, 'enum() call' );
    is_deeply( $enum, [ qw( create_user login login_fail role_change ) ], 'enum() data' );

    done_testing();
    return 0;
};
