package CBQZ::Db;

use Config::App;
use Moose;
use MooseX::MarkAsMethods autoclean => 1;
use exact;

extends 'DBIx::Class::Schema', 'CBQZ';

{
    my $db;
    my $config = Config::App->new->get('database');

    sub connect ($self) {
        return $db if ($db);

        my ( $dsn, $dbname, $username, $password, $settings ) =
            @{$config}{ qw( dsn dbname username password settings ) };

        $db = $self->clone->connection( $dsn . $dbname, $username, $password, $settings );

        # if logging is active, we're going to setup a nice, pretty-looking
        # SQL log output based on configuration settings
        if ( $config->{'logging'} ) {
            require DBIx::Class::Storage::Debug::PrettyPrint;

            $db->storage->debug( $config->{'logging'}{'debug'} ) if ( defined $config->{'logging'}{'debug'} );

            $db->storage->debugobj( DBIx::Class::Storage::Debug::PrettyPrint->new({
                profile => $config->{'logging'}{'profile'},
            }) ) if ( defined $config->{'logging'}{'profile'} );

            if ( defined $config->{'logging'}{'file'} ) {
                $config->{'logging'}{'file'} =
                    Config::App->new->get( 'config_app', 'root_dir' ) . '/' . $config->{'logging'}{'file'}
                    if ( substr( $config->{'logging'}{'file'}, 0, 1 ) ne '/' );

                open( my $dbic_log_file, '>>', $config->{'logging'}{'file'} ) or E::Db->throw( join( '',
                    'Unable to append to "', $config->{'logging'}{'file'}, '"; ',
                    'See the database/logging/file setting'
                ) );
                binmode( $dbic_log_file, ':utf8' );
                $dbic_log_file->autoflush;
                $db->storage->debugfh($dbic_log_file);
            }
        }

        return $db;
    }
}

sub enum ( $self, $sources, $columns ) {
    $sources ||= [ $self->sources ];
    $sources = [$sources] if ( defined $sources and not ref $sources );
    $columns = [$columns] if ( defined $columns and not ref $columns );

    my %enums;
    for my $name ( map { ucfirst($_) } @$sources ) {
        for my $column ( ($columns) ? @$columns : $self->source($name)->columns ) {
            my $info = $self->source($name)->column_info($column);
            $enums{$name}{$column} = $info->{extra}{list} if ( $info->{data_type} eq 'enum' );
        }
    }

    my @sources = keys %enums;
    return undef unless ( @sources > 0 );
    return \%enums unless ( @sources == 1 );

    my @columns = keys %{ $enums{ $sources[0] } };
    return undef unless ( @columns > 0 );
    return $enums{ $sources[0] }{ $columns[0] } if ( @columns == 1 );
    return $enums{ $sources[0] };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

CBQZ::Db

=head1 SYNOPSIS

    my $db = CBQZ::Db::Schema->connect;
    my $rs = CBQZ::Db::Schema->connect->resultset('User');

    $db->enum;
    $db->enum( $sources, $columns );

=head1 DESCRIPTION

This package should likely not be used directly. Instead, it's purpose is to be
inheritted by L<CBQZ::Db::Schema> so that we can allow
L<CBQZ::Db::Schema> to be auto-generated by the schema generator script
and yet we can overload the C<connect()> method.

    my $db = CBQZ::Db::Schema->connect;

That being said, you should likely not ever do that either. Instead,
L<CBQZ::Model> provides an attribute of "db" which is the instantiated
L<CBQZ::Db::Schema>.

=head1 METHODS

=head2 connect

This method, which handles no arguments, sets up a database connection using
the application's L<DBIx::Class> modules.

    my $rs = CBQZ::Db::Schema->connect->resultset('User');

You should likely never need do this, though. And it's probable that if you
are, you're doing something wrong.

Note that the connection C<connect()> provides is a singleton.

=head2 enum

This method is intended to easily provide the enum values possible for enum
columns in the database. You can optionally provide a "source" name (table name)
and a "type" name (column name). These can be purely strings or arrayrefs of
strings.

In the case where there is only a single enum column from a single table
possible to be returned, this method will return an arrayref of the possible
values. In the case where there is multiple enum columns for a single table
or multiple enum columns across multiple tables, a hashref data structure is
returned.

=head1 CONFIGURATION SETTINGS

The following optional configuration settings block defines how SQL logging of
L<DBIx::Class> SQL should happen:

    database:
        logging:
            debug: 1
            file: /var/log/CBQZ/dbi_class.sql
            profile: console

See L<DBIx::Class::Storage::Debug::PrettyPrint> for more information on the
"profile" setting.

=head1 INHERITANCE AND DEPENDENCIES

This module inherits from:

=over 1

=item * L<CBQZ>

=item * L<DBIx::Class::Schema>

=back

This module has the following dependencies:

=over 1

=item * L<Config::App>

=item * L<Moose>

=item * L<MooseX::MarkAsMethods>

=item * L<DBIx::Class::Storage::Debug::PrettyPrint>

=back
