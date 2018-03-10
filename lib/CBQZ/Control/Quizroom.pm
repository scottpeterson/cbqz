package CBQZ::Control::Quizroom;

use Mojo::Base 'Mojolicious::Controller';
use exact;
use Try::Tiny;
use CBQZ::Model::Quiz;
use CBQZ::Model::Program;
use CBQZ::Model::MaterialSet;
use CBQZ::Model::Question;
use CBQZ::Util::Format 'date_time_ansi';

sub path ($self) {
    my $cbqz_prefs       = $self->decode_cookie('cbqz_prefs');
    my $path             = $self->url_for('/quizroom');
    my $result_operation = '';

    try {
        $result_operation = CBQZ::Model::Program->new->load(
            $cbqz_prefs->{program_id}
        )->obj->result_operation;
    }
    catch {
        $self->warn($_);
    };

    # TODO: move "result_operation" definition out of here and into (probably) the "data" sub

    return $self->render(
        text => qq/
            var cntlr = "$path";
            function result_operation( result, as, number ) {
                $result_operation
                return { result: result, as: as, number: number };
            }
        /,
    );
}

{
    my @quizzer_names = qw(
        Alpha Bravo Charlie Delta Echo Foxtrot Gulf Hotel India Juliet Kilo Lima Mike November Oscar
    );
    my $quiz_teams_quizzers = join( "\n\n", map {
        $_ . "\n" . join( "\n", map { $_ . '. ' . shift(@quizzer_names) . ' Quizzer' } 1 .. 5 )
    } map { 'Team ' . $_ } 'A' .. 'C' );

    sub quiz_setup ($self) {
        my $cbqz_prefs = $self->decode_cookie('cbqz_prefs');

        my @selected_chapters = map {
            $_->{book} . '|' . $_->{chapter}
        } @{ $cbqz_prefs->{selected_chapters} };

        my ($question_set) =
            grep { $cbqz_prefs->{question_set_id} == $_->{question_set_id} }
            ( map { +{ %{ $_->data }, share => 0 } } $self->stash('user')->question_sets ),
            ( map { +{ %{ $_->data }, share => 1 } } $self->stash('user')->shared_question_sets );

        for ( @{ $question_set->{statistics} } ) {
            my $id = $_->{book} . '|' . $_->{chapter};
            $_->{selected} = ( grep { $id eq $_ } @selected_chapters ) ? 1 : 0;
        }

        my $program = CBQZ::Model::Program->new->load( $cbqz_prefs->{program_id} );

        return $self->render( json => {
            weight_chapters     => $cbqz_prefs->{weight_chapters} // 0,
            weight_percent      => $cbqz_prefs->{weight_percent}  // 50,
            program_id          => $cbqz_prefs->{program_id}      || undef,
            question_set_id     => $cbqz_prefs->{question_set_id} || undef,
            material_set_id     => $cbqz_prefs->{material_set_id} || undef,
            question_set        => $question_set,
            quiz_teams_quizzers => $quiz_teams_quizzers,
            scheduled           => date_time_ansi(),
            name                => date_time_ansi(),
            quizmaster          => $self->stash('user')->obj->realname,
            user_is_official    => $self->stash('user')->has_role('Official'),
            target_questions    => $program->obj->target_questions,
            timer_default       => $program->obj->timer_default,
            timer_values        => join( ', ', @{ $self->cbqz->json->decode( $program->obj->timer_values ) } ),
            saved_quizzes       => CBQZ::Model::Quiz->new->quizzes_for_user( $self->stash('user'), $program ),
            question_types      => join( "\n",
                map {
                    $_->[2] . ': ' . $_->[1][0] . '-' . $_->[1][1] . ' (' . join( ' ', @{ $_->[0] } ) . ')'
                } @{ $self->cbqz->json->decode( $program->obj->question_types ) }
            ),
        } );
    }
}

sub generate_quiz ($self) {
    my $cbqz_prefs = $self->decode_cookie('cbqz_prefs');
    my $quiz;

    try {
        E->throw('User is not a member of program ID set in CBQZ preferences cookie')
            unless ( $self->stash('user')->has_program_id( $cbqz_prefs->{program_id} ) );

        E->throw('User is not an official but has set the "official" flag for the quiz')
            if ( $self->req->param('official') and not $self->stash('user')->has_role('Official') );

        my $quiz_teams_quizzers = [
            map {
                my @quizzers = split(/\r?\n/);
                ( my $team = shift @quizzers ) =~ s/^\s+|\s+$//g;
                E->throw('Team name parsing failed') unless ( $team and $team =~ /\w/ and $team !~ /\n/ );
                {
                    team     => $team,
                    quizzers => [
                        map {
                            /^\s*(?<bib>\d+)\D\s*(?<name>\w[\w\s]*)/;
                            my $quizzer = +{ %+ };
                            $quizzer->{name} =~ s/^\s+|\s+$//g;
                            $quizzer->{name} =~ s/\s+/ /g;

                            E->throw('Quizzer name parsing failed') unless (
                                $quizzer->{name} and
                                $quizzer->{name} =~ /\w/ and
                                $quizzer->{name} !~ /\n/
                            );

                            E->throw('Quizzer bib parsing failed') unless (
                                $quizzer->{bib} and
                                $quizzer->{bib} =~ /^\d+$/
                            );

                            $quizzer;
                        } @quizzers
                    ],
                };
            } split( /(?:\r?\n){2,}/, $self->req->param('quiz_teams_quizzers') )
        ];

        my $set = CBQZ::Model::QuestionSet->new->load( $cbqz_prefs->{question_set_id} );
        E->throw('User does not own requested question set')
            unless ( $set and $set->is_usable_by( $self->stash('user') ) );

        $quiz = CBQZ::Model::Quiz->new->create({
            %$cbqz_prefs,
            %{ $self->params },
            user_id             => $self->stash('user')->obj->id,
            quiz_teams_quizzers => $quiz_teams_quizzers,
        });
    }
    catch {
        $self->warn($_);
        $self->flash( message =>
            'An error occurred while trying to generate quiz data. ' .
            'This is likely due to invalid quiz configuration settings.'
        );
        return $self->redirect_to('/quizroom');
    };

    $self->flash( message => {
        type => 'success',
        text => 'Quiz "' . $self->req->param('name') . '" generated and saved for later.',
    } ) if ( $self->req->param('save_for_later') );

    return $self->redirect_to(
        ( $self->req->param('save_for_later') )
            ? '/quizroom'
            : '/quizroom/quiz?id=' . $quiz->obj->id
    );
}

sub quiz ($self) {
    my $cbqz_prefs = $self->decode_cookie('cbqz_prefs');

    # TODO: remove this bit as it's no longer necessary (probably)

    try {
        my $program = CBQZ::Model::Program->new->load( $cbqz_prefs->{program_id} );

        $self->stash(
            question_types => $program->types_list,
            timer_values   => $program->timer_values,
        );
    }
    catch {
        $self->warn($_);
        $self->flash( message =>
            "An error occurred while trying to load data.\n" .
            "This is likely due to invalid settings on the main page.\n" .
            "Visit the main page and verify your settings."
        );
    };

    return;
}

sub data ($self) {
    my $cbqz_prefs = $self->decode_cookie('cbqz_prefs');

    # TODO: load up the quiz from the quiz table

    my $data = {
        metadata => {
            types         => [],
            timer_default => 0,
            as_default    => 'Error',
            type_ranges   => [],
        },
        material  => { Error => { 1 => { 1 => {
            book    => 'Error',
            chapter => 1,
            verse   => 1,
            text    =>
                'An error occurred while trying to load data. ' .
                'This is likely due to invalid settings on the main page. ' .
                'Visit the main page and verify your settings.',
        } } } },
        questions => [],
    };

    try {
        my $program = CBQZ::Model::Program->new->load( $cbqz_prefs->{program_id} );
        my $set     = CBQZ::Model::QuestionSet->new->load( $cbqz_prefs->{question_set_id} );
        my $quiz    = ( $set and $set->is_usable_by( $self->stash('user') ) )
            ? CBQZ::Model::Quiz->new->generate($cbqz_prefs)
            : { error => 'User does not own requested question set' };

        $self->notice( $quiz->{error} ) if ( $quiz->{error} );

        $data->{metadata} = {
            types         => $program->types_list,
            timer_default => $program->obj->timer_default,
            as_default    => $program->obj->as_default,
            type_ranges   => [
                map {
                    my ( $label, $min, $max, @types ) = split(/\W+/);
                    [ \@types, [ $min, $max ], $label ];
                } split( /\r?\n/, $cbqz_prefs->{question_types} )
            ],
        };

        $data->{material} = CBQZ::Model::MaterialSet->new->load(
            $cbqz_prefs->{material_set_id}
        )->get_material;

        $data->{questions} = [
            map {
                $_->{number} = undef;
                $_->{as}     = undef;
                $_->{marked} = undef;
                $_;
            } @{ $quiz->{questions} }
        ];

        $data->{error} = ( $quiz->{error} ) ? $quiz->{error} : undef;
    }
    catch {
        $self->warn($_);
        $data->{error} =
            'An error occurred while trying to load data. ' .
            'This is likely due to invalid settings on the quiz configuration settings page. ' .
            'Visit the quiz configuration settings page and verify your settings';
    };

    return $self->render( json => $data );
}

sub used ($self) {

    # TODO: return a value on failure that allows for continuing quiz OK

    my $question = CBQZ::Model::Question->new->load( $self->req_body_json->{question_id} );
    if ( $question and $question->is_usable_by( $self->stash('user') ) ) {
        $question->obj->update({ used => \'used + 1' });
        return $self->render( json => { success => 1 } );
    }
}

sub mark ($self) {

    # TODO: return a value on failure that allows for continuing quiz OK

    my $json     = $self->req_body_json;
    my $question = CBQZ::Model::Question->new->load( $self->req_body_json->{question_id} );
    if ( $question and $question->is_usable_by( $self->stash('user') ) ) {
        $question->obj->update({ marked => $json->{reason} });
        return $self->render( json => { success => 1 } );
    }
}

sub replace ($self) {

    # TODO: return a value on failure that allows for continuing quiz OK

    my $cbqz_prefs = $self->decode_cookie('cbqz_prefs');
    my $set = CBQZ::Model::QuestionSet->new->load( $cbqz_prefs->{question_set_id} );
    if ( $set and $set->is_usable_by( $self->stash('user') ) ) {
        my $results = CBQZ::Model::Quiz->new->replace( $self->req_body_json, $cbqz_prefs );
        return $self->render( json => {
            question => (@$results) ? $results->[0] : undef,
            error    => (@$results) ? undef : 'Failed to find question of that type.',
        } );
    }
}

1;
