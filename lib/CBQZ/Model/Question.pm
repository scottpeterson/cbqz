package CBQZ::Model::Question;

use Moose;
use MooseX::ClassAttribute;
use exact;
use Mojo::DOM;
use Time::Out 'timeout';
use Try::Tiny;

extends 'CBQZ::Model';

class_has 'schema_name' => ( isa => 'Str', is => 'ro', default => 'Question' );

sub is_owned_by ( $self, $user ) {
    return (
        $user->obj->id and $self->obj->question_set->user_id and
        $user->obj->id == $self->obj->question_set->user_id
    ) ? 1 : 0;
}

{
    my $material = [{}];

    my $first_5 = sub ($text) {
        $text =~ s/<[^>]+>//g;
        $text =~ s/\s+/ /g;
        $text =~ s/(^\s+|\s+$)//g;

        my @text = split( /\s/, $text );

        return
            join( ' ', @text[ 0 .. 4 ] ),
            join( ' ', @text[ 5 .. @text - 1 ] );
    };

    my $get_2_verses = sub ($data) {
        return
            sort { $a->{verse} <=> $b->{verse} }
            grep {
                $_->{book} eq $data->{book} and
                $_->{chapter} == $data->{chapter} and
                (
                    $_->{verse} == $data->{verse} or
                    $_->{verse} == $data->{verse} + 1
                )
            } @$material;
    };

    my $case = sub ($text) {
        $text =~ s/^((?:<[^>]+>)|\W)*(\w)/ ($2) ? ( $1 || '' ) . uc $2 : uc $1 /e;
        return $text;
    };

    my $fix = sub ($text) {
        $text =~ s/[-,;:]+(?:<[^>]+>)*$//;
        $text = Mojo::DOM->new($text)->to_string;
        $text =~ s/&quot;/"/g;
        $text =~ s/&#39;/'/g;

        return $text;
    };

    my $search = sub ( $text, $book, $chapter, $verse, $range ) {
        $text =~ s/\s+/ /g;
        $text =~ s/[^\w\s]+//g;
        $text =~ s/(\w)/$1(?:<[^>]+>)*['-]*(?:<[^>]+>)*/g;
        $text =~ s/(?:^\s+|\s+$)//g;
        $text =~ s/\s/(?:<[^>]+>|\\W)+/g;
        $text = '(?:<[^>]+>)*\b' . $text . '\b';

        my @matches =
            map { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map { [ $_, abs( $verse - $_->{verse} ) ] }
            grep {
                $_->{book} eq $book and
                $_->{chapter} eq $chapter and
                $_->{verse} >= $verse - $range and
                $_->{verse} <= $verse + $range
            }
            @$material;

        my @filtered_matches;
        timeout 2 => sub {
            @filtered_matches =
                grep { defined }
                map {
                    ( $_->{text} =~ /($text)/i ) ? { verse => $_, match => $fix->($1) } : undef
                }
                @matches;
        };

        return @filtered_matches;
    };

    my $process_question = sub ( $data, $skip_casing, $range, $skip_interogative ) {
        $range //= 5;

        my $int;
        unless ($skip_interogative) {
            if ( $data->{question} =~ s/(\W*\b(?:who|what|when|where|why|how|whom|whose)\b\W*)$//i ) {
                $int->{phrase} = lc $1;
                $int->{pos}    = 'aft';
            }
            elsif ( $data->{question} =~ s/^(\W*\b(?:who|what|when|where|why|how|whose)\b\W*)//i ) {
                $int->{phrase} = lc $1;
                $int->{phrase} = ucfirst $1 unless ($skip_casing);
                $int->{pos}    = 'fore';
            }
        }
        my @matches = $search->( @$data{ qw( question book chapter verse ) }, $range );

        E->throw('Multiple question matches found where only 1 expected') if ( @matches > 1 );
        E->throw('Unable to find question match') if ( @matches == 0 );

        my $match = $matches[0]->{match};
        if ( $int->{phrase} ) {
            if ( $int->{pos} eq 'aft' ) {
                $match = $case->($match) unless ($skip_casing);
                $match .= $int->{phrase};
            }
            else {
                $match = $int->{phrase} . $match;
            }
        }
        $data->{question} = $match;

        @matches = $search->( @$data{ qw( answer book chapter verse ) }, $range );
        E->throw('Unable to find answer match') if ( @matches == 0 );

        $match = $matches[0]->{match};
        $match = $case->($match) unless ( $skip_casing and $skip_casing ne 'answer_only' );
        $data->{answer} = $match;

        return $data;
    };

    my $type_fork = sub ($data) {
        $data->{$_} =~ s/<[^>]*>//g for ( qw( question answer ) );

        if ( $data->{type} eq 'INT' or $data->{type} eq 'MA' ) {
            $data = $process_question->( $data, 0, 5, 0 );
            return unless ($data);
            $data->{question} .= '?' unless ( $data->{question} =~ /\?$/ );
        }
        elsif (
            $data->{type} eq 'CR' or $data->{type} eq 'CVR' or
            $data->{type} eq 'MACR' or $data->{type} eq 'MACVR'
        ) {
            $data->{question} =~ s/ac\w*\sto\s+(\d\s+)?\w+[,\s]+c\w*\s*\d+(?:[,\s]+v\w*\s*\d+)?[\s:,]*//i;
            $data = $process_question->(
                $data,
                'answer_only',
                ( ( $data->{type} eq 'CVR' or $data->{type} eq 'MACVR' ) ? 0 : 5 ),
                0,
            );
            return unless ($data);
            $data->{question} =
                'According to ' . $data->{book} . ', chapter ' . $data->{chapter} .
                ( ( $data->{type} eq 'CVR' or $data->{type} eq 'MACVR' ) ? ', verse ' . $data->{verse} : '' ) .
                ', ' . $data->{question};
            $data->{question} .= '?' unless ( $data->{question} =~ /\?$/ );
        }
        elsif ( $data->{type} eq 'Q' or $data->{type} eq 'Q2V' ) {
            my @verses = $get_2_verses->($data);

            $data->{question} = 'Quote ' . $data->{book} . ', chapter ' . $data->{chapter} . ', ' .
                (
                    ( $data->{type} eq 'Q' )
                        ? 'verse ' . $data->{verse}
                        : 'verses ' . $data->{verse} . ' and ' . ( $data->{verse} + 1 )
                ) . '.';

            $data->{answer} = ( $data->{type} eq 'Q' )
                ? $verses[0]->{text}
                : join( ' ', map { $_->{text} } @verses );
        }
        elsif ( $data->{type} eq 'FTV' or $data->{type} eq 'F2V' ) {
            my @verses = $get_2_verses->($data);
            ( $data->{question}, $data->{answer} ) = $first_5->( $verses[0]->{text} );
            $data = $process_question->( $data, 1, 0, 1 );
            return unless ($data);

            $data->{question} .= '...' unless ( $data->{question} =~ /\.{3}$/ );
            $data->{answer} = '...' . $data->{answer} unless ( $data->{answer} =~ /^\.{3}/ );

            $data->{answer} .= ' ' . $verses[1]->{text} if ( $data->{type} eq 'F2V' );
        }
        elsif ( $data->{type} eq 'FT' or $data->{type} eq 'FTN' ) {
            my @verses = $get_2_verses->($data);
            ( $data->{question}, $data->{answer} ) = $first_5->( $data->{question} . ' ' . $data->{answer} );

            $data = $process_question->( $data, 1, 0, 1 );
            return unless ($data);

            $data->{question} .= '...' unless ( $data->{question} =~ /\.{3}$/ );
            $data->{answer} = '...' . $data->{answer} unless ( $data->{answer} =~ /^\.{3}/ );

            $data->{answer} .= ' ' . $verses[1]->{text} if ( $data->{type} eq 'FTN' );
        }
        else {
            E->throw('Auto-text not supported for question type');
        }

        $data->{answer} =~ s/[,:\-]+$//g;
        $data->{answer} .= '.' unless ( $data->{answer} =~ /[.!?]$/ );
        return $data;
    };

    sub auto_text ( $self, $material_set = undef, $question = undef ) {
        $question = $self->data if ( not $question and $self->obj );
        $question->{previously_marked} = $question->{marked};

        try {
            $material = $material_set->load_material->material;
        }
        catch {
            E->throw('Unable to load material from provided material set');
        };

        try {
            $question = $type_fork->($question);
        }
        catch {
            $question->{error} = 'Auto-text error: ' . ( split(/\n/) )[0];
        };

        return $question;
    }
}

__PACKAGE__->meta->make_immutable;

1;
