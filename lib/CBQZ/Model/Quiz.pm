package CBQZ::Model::Quiz;

use Moose;
use Try::Tiny;
use CBQZ::Model::Program;

extends 'CBQZ';

sub chapter_set {
    my ( $self, $cbqz_prefs ) = @_;

    my @chapter_set_prime = map { $_->{book} . ' ' . $_->{chapter} } @{ $cbqz_prefs->{selected_chapters} };
    my @chapter_set_weight;
    push( @chapter_set_weight, pop @chapter_set_prime )
        while ( @chapter_set_weight < $cbqz_prefs->{weight_chapters} );

    return {
        prime  => join( ', ', map { $self->dq->quote($_) } @chapter_set_prime ),
        weight => join( ', ', map { $self->dq->quote($_) } @chapter_set_weight ),
    };
}

sub generate {
    my ( $self, $cbqz_prefs ) = @_;

    my $chapter_set            = $self->chapter_set($cbqz_prefs);
    my $program                = CBQZ::Model::Program->new->load( $cbqz_prefs->{program_id} );
    my @question_types         = @{ $self->json->decode( $program->obj->question_types ) };
    my $target_questions_count = $program->obj->target_questions;

    my ( @questions, $error );
    try {
        for my $question_type (@question_types) {
            my $types = join( ', ', map { $self->dq->quote($_) } @{ $question_type->[0] } );
            my $min   = $question_type->[1][0];

            my %min;
            $min{prime} = ( $cbqz_prefs->{weight_percent} )
                ? int( $min * ( 1 - $cbqz_prefs->{weight_percent} / 100 ) )
                : $min;
            $min{weight} = $min - $min{prime};

            my @pending_questions;
            for my $selection ( qw( prime weight ) ) {
                my $selection_set = $chapter_set->{$selection};

                my $refs = (@questions)
                    ? 'AND CONCAT( book, " ", chapter, ":", verse ) NOT IN (' . join( ', ',
                        map { $self->dq->quote($_) }
                        'invalid reference',
                        ( map { $_->{book} . ' ' . $_->{chapter} . ':' . $_->{verse} } @questions )
                    ) . ')'
                    : '';

                my $results = $self->dq->sql(qq{
                    SELECT question_id, book, chapter, verse, question, answer, type, used
                    FROM question
                    WHERE
                        type IN ($types) $refs AND marked IS NULL AND question_set_id = ? AND
                        CONCAT( book, " ", chapter ) IN ($selection_set)
                    ORDER BY used, RAND()
                    LIMIT $min{$selection}
                })->run( $cbqz_prefs->{question_set_id} )->all({});

                if ( @$results < $min{$selection} ) {
                    my $sub_min = $min{$selection} - @$results;
                    my $ids = ( @questions or @$results )
                        ? 'AND question_id NOT IN (' . join( ', ',
                            map { $_->{question_id} } @questions, @$results
                        ) . ')'
                        : '';

                    push( @$results, @{ $self->dq->sql(qq{
                        SELECT question_id, book, chapter, verse, question, answer, type, used
                        FROM question
                        WHERE
                            type IN ($types) $ids AND marked IS NULL AND question_set_id = ? AND
                            CONCAT( book, " ", chapter ) IN ($selection_set)
                        ORDER BY used, RAND()
                        LIMIT $sub_min
                    })->run( $cbqz_prefs->{question_set_id} )->all({}) } );
                }

                push( @pending_questions, @$results );
            }

            die 'Unable to meet quiz set minimum requirements' if ( @pending_questions < $min );
            push( @questions, @pending_questions );
        }

        @questions = map { $_->[0] } sort { $a->[1] <=> $b->[1] } map { [ $_, rand ] } @questions;

        @question_types = (
            (
                map { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map { [ $_, rand() ] }
                grep { $_->[1][1] - $_->[1][0] > 0 } @question_types
            ),
            (
                map { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map { [ $_, rand() ] }
                map { ($_) x ( $_->[1][1] - $_->[1][0] - 1 ) }
                grep { $_->[1][1] - $_->[1][0] > 1 } @question_types
            ),
        );

        while ( @questions < $target_questions_count and @question_types ) {
            my $question_type = shift @question_types;

            my $types = join( ', ', map { $self->dq->quote($_) } @{ $question_type->[0] } );
            my $min   = $question_type->[1][0];
            my $refs  = join( ', ',
                map { $self->dq->quote($_) }
                'invalid reference', ( map { $_->{book} . ' ' . $_->{chapter} . ':' . $_->{verse} } @questions )
            );
            my $selection_set = $chapter_set->{
                ( $cbqz_prefs->{weight_percent} >= rand() * 100 ) ? 'weight' : 'prime'
            };

            my $results = $self->dq->sql(qq{
                SELECT question_id, book, chapter, verse, question, answer, type, used
                FROM question
                WHERE
                    type IN ($types) AND
                    CONCAT( book, ' ', chapter, ':', verse ) NOT IN ($refs) AND
                    marked IS NULL AND
                    question_set_id = ? AND
                    CONCAT( book, " ", chapter ) IN ($selection_set)
                ORDER BY used, RAND()
                LIMIT 1
            })->run( $cbqz_prefs->{question_set_id} )->all({});

            unless (@$results) {
                my $ids = join( ', ', map { $_->{question_id} } @questions, @$results );

                push( @$results, @{ $self->dq->sql(qq{
                    SELECT question_id, book, chapter, verse, question, answer, type, used
                    FROM question
                    WHERE
                        type IN ($types) AND
                        question_id NOT IN ($ids) AND
                        marked IS NULL AND
                        question_set_id = ? AND
                        CONCAT( book, " ", chapter ) IN ($selection_set)
                    ORDER BY used, RAND()
                    LIMIT 1
                })->run( $cbqz_prefs->{question_set_id} )->all({}) } );
            }

            push( @questions, @$results );
        }

        while ( @questions < $target_questions_count ) {
            my $selection_set = $chapter_set->{
                ( $cbqz_prefs->{weight_percent} >= rand() * 100 ) ? 'weight' : 'prime'
            };
            my $refs = join( ', ',
                map { $self->dq->quote($_) }
                'invalid reference', ( map { $_->{book} . ' ' . $_->{chapter} . ':' . $_->{verse} } @questions )
            );

            my ($question) = @{ $self->dq->sql(qq{
                SELECT question_id, book, chapter, verse, question, answer, type, used
                FROM question
                WHERE
                    CONCAT( book, ' ', chapter, ':', verse ) NOT IN ($refs) AND
                    marked IS NULL AND
                    question_set_id = ? AND
                    CONCAT( book, " ", chapter ) IN ($selection_set)
                ORDER BY used, RAND()
                LIMIT 1
            })->run( $cbqz_prefs->{question_set_id} )->all({}) };

            last unless ($question);
            push( @questions, $question );
        }

        while ( @questions < $target_questions_count ) {
            my $selection_set = $chapter_set->{
                ( $cbqz_prefs->{weight_percent} >= rand() * 100 ) ? 'weight' : 'prime'
            };
            my $ids = join( ', ', map { $_->{question_id} } @questions );

            my ($question) = @{ $self->dq->sql(qq{
                SELECT question_id, book, chapter, verse, question, answer, type, used
                FROM question
                WHERE
                    question_id NOT IN ($ids) AND marked IS NULL AND question_set_id = ? AND
                    CONCAT( book, " ", chapter ) IN ($selection_set)
                ORDER BY used, RAND()
                LIMIT 1
            })->run( $cbqz_prefs->{question_set_id} )->all({}) };

            last unless ($question);
            push( @questions, $question );
        }

        die 'Failed to create a question set to target size' if ( @questions < $target_questions_count );
    }
    catch {
        $error = $self->clean_error($_);
    };

    return {
        questions => \@questions,
        error     => $error,
    };
}

sub replace {
    my ( $self, $request, $cbqz_prefs ) = @_;

    my $chapter_set   = $self->chapter_set($cbqz_prefs);
    my $selection_set = $chapter_set->{
        ( $cbqz_prefs->{weight_percent} >= rand() * 100 ) ? 'weight' : 'prime'
    };

    my $refs = join( ', ',
        map { $self->dq->quote($_) }
        'invalid reference',
        ( map { $_->{book} . ' ' . $_->{chapter} . ':' . $_->{verse} } @{ $request->{questions} } )
    );

    my $results = $self->dq->sql(qq{
        SELECT question_id, book, chapter, verse, question, answer, type, used
        FROM question
        WHERE
            type = ? AND marked IS NULL AND
            CONCAT( book, " ", chapter ) IN ($selection_set) AND
            CONCAT( book, ' ', chapter, ':', verse ) NOT IN ($refs)
        ORDER BY used, RAND()
        LIMIT 1
    })->run( $request->{type} )->all({});

    unless (@$results) {
        my $ids = join( ', ', 0, map { $_->{question_id} } @{ $request->{questions} } );

        $results = $self->dq->sql(qq{
            SELECT question_id, book, chapter, verse, question, answer, type, used
            FROM question
            WHERE
                type = ? AND marked IS NULL AND
                CONCAT( book, " ", chapter ) IN ($selection_set) AND
                question_id NOT IN ($ids)
            ORDER BY used, RAND()
            LIMIT 1
        })->run( $request->{type} )->all({});
    }

    return $results;
}

__PACKAGE__->meta->make_immutable;

1;
