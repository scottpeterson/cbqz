package CBQZ::Model::Meet;

use Moose;
use exact;

extends 'CBQZ::Model';

sub build_draw ( $self, $settings ) {
    my $team_id        = 0;
    $settings->{teams} = [
        map { { name => $_, id => $team_id++ } }
        map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_, rand ] }
        @{ $settings->{teams} }
    ];

    # calculate quiz counts
    my $remainder = @{ $settings->{teams} } * $settings->{quizzes} % 3;
    my $three_team_quizzes = int( @{ $settings->{teams} } * $settings->{quizzes} / 3 );
    $three_team_quizzes-- if ( $remainder == 1 );
    my $two_team_quizzes = ( $remainder == 1 ) ? 2 : ( $remainder == 2 ) ? 1 : 0;

    # generate meet schema
    my ( $meet, @quizzes );
    for ( 1 .. $three_team_quizzes + $two_team_quizzes ) {
        my $set = [];
        for ( 1 .. $settings->{rooms} ) {
            my $quiz = [ (undef) x 3 ];
            push( @$set, $quiz );
            push( @quizzes, $quiz );
            last if ( @quizzes >= $three_team_quizzes + $two_team_quizzes );
        }
        push( @$meet, $set );
        last if ( @quizzes >= $three_team_quizzes + $two_team_quizzes );
    }
    if ($two_team_quizzes) {
        @quizzes = map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_, rand ] } @quizzes;
        pop @{ $quizzes[$_] } for ( 0 .. $two_team_quizzes - 1 );
    }

    # assign teams to slots in meet schema
    for my $set (@$meet) {
        my @already_scheduled_teams;
        for my $room ( 0 .. $settings->{rooms} - 1 ) {
            my $quiz = $set->[$room];
            next unless $quiz;
            for my $position ( 0 .. @$quiz - 1 ) {
                my @available_teams = grep {
                    my $team = $_;
                    not grep { $team->{id} == $_->{id} } @already_scheduled_teams;
                } @{ $settings->{teams} };

                E->throw('Insufficient teams to fill quiz set; reduce rooms or rerun') unless @available_teams;

                my @quiz_team_names = map { $_->{name} } grep { defined } @$quiz;
                if (@quiz_team_names) {
                    for my $team (@available_teams) {
                        $team->{seen_team_weight} = 0;
                        $team->{seen_team_weight} += $team->{teams}{$_} || 0 for (@quiz_team_names);
                    }
                }

                my ($selected_team) = sort {
                    ( $a->{seen_team_weight}     || 0 ) <=> ( $b->{seen_team_weight}     || 0 ) ||
                    ( $a->{rooms}{$room}         || 0 ) <=> ( $b->{rooms}{$room}         || 0 ) ||
                    ( $a->{positions}{$position} || 0 ) <=> ( $b->{positions}{$position} || 0 ) ||
                    $a->{id} <=> $b->{id}
                } @available_teams;

                E->throw('Unable to select a team via algorithm; reduce rooms or rerun') unless $selected_team;

                $quiz->[$position] = $selected_team;
                push( @already_scheduled_teams, $selected_team );

                $selected_team->{rooms}{$room}++;
                $selected_team->{positions}{$position}++;
            }

            my @quiz_team_names = map { $_->{name} } @$quiz;
            for my $team (@$quiz) {
                $team->{teams}{$_}++ for ( grep { $team->{name} ne $_ } @quiz_team_names );
            }
        }
    }

    # randomize sets
    my $last_set = pop @$meet;
    $meet = [ ( map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_, rand ] } @$meet ), $last_set ];

    # randomize the rooms
    my $room_map;
    for my $set (@$meet) {
        $room_map //= [ map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_ - 1, rand ] } 1 .. @$set ];
        next unless ( @$set == @$room_map );
        $set = [ map { $set->[ $room_map->[$_] ] } ( 0 .. @$room_map - 1 ) ];
    }

    return $meet;
}

__PACKAGE__->meta->make_immutable;

1;
