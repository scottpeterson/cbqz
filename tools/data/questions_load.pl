#!/usr/bin/env perl
use exact;
use Config::App;
use Util::CommandLine qw( options pod2usage );
use Text::CSV_XS 'csv';
use Text::Unidecode 'unidecode';
use CBQZ;

my $settings = options( qw( set|s=s questions|q=s user|u=s create|c delete|d ) );
pod2usage unless ( $settings->{set} and $settings->{questions} and $settings->{user} );

my $dq = CBQZ->new->dq;

my $user_id = $dq->sql('SELECT user_id FROM user WHERE username = ?')->run( $settings->{user} )->value;
die "Failed to find user $settings->{user}\n" unless ($user_id);

$dq->sql('INSERT INTO question_set ( name, user_id ) VALUES ( ?, ? )')->run(
    $settings->{set},
    $user_id,
) if ( $settings->{create} );

my $set_id = $dq->sql('SELECT question_set_id FROM question_set WHERE name = ? AND user_id = ?')
    ->run( $settings->{set}, $user_id )->value;
die "Set name $settings->{set} not found\n" unless ($set_id);

$dq->sql('DELETE FROM question WHERE question_set_id = ?')->run($set_id) if ( $settings->{delete} );

my $insert = $dq->sql(q{
    INSERT INTO question ( question_set_id, type, book, chapter, verse, question, answer, used )
    VALUES ( ?, ?, ?, ?, ?, ?, ?, ? )
});

for my $line (
    map { ( @$_ == 6 ) ? [ @$_, 0 ] : $_ }
    map {
        [ map {
            s/(?:^\s+|\s+$)//g;
            unidecode($_);
        } @$_ ]
    }
    @{ csv( in => $settings->{questions} ) }
) {
    $line->[0] = 'MA' . $1 if ( $line->[0] =~ /(CV?R)MA/ );
    $insert->run( $set_id, @$line );
}

=head1 NAME

questions_load.pl - Load questions data into the database as a new questions set

=head1 SYNOPSIS

    questions_load.pl OPTIONS
        -s|set        QUESTIONS_SET_NAME
        -q|questions  QUESTIONS_DATA_FILE
        -u|user       USERNAME
        -c|create
        -d|delete
        -h|help
        -m|man

=head1 DESCRIPTION

This program will load questions data into the database as a new questions set.
The questions data file needs to be a CSV with columns in the following order:
type, book, chapter, verse, question, answer, used. Used is optional.
