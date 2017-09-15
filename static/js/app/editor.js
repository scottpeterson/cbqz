document.addEventListener( "keyup", function(event) {
    event.preventDefault();

    // for Alt+Q: Reset Formatting
    if ( event.altKey && event.keyCode == 81 ) document.getElementById("format_reset").click();

    // for Alt+W, Ctrl+B: Global Unique
    if ( ( event.altKey && event.keyCode == 87 ) || ( event.ctrlKey && event.keyCode == 66 ) )
        document.getElementById("format_unique_word").click();

    // for Alt+E, Ctrl+I: Chapter Unique
    if ( ( event.altKey && event.keyCode == 69 ) || ( event.ctrlKey && event.keyCode == 73 ) )
        document.getElementById("format_unique_chapter").click();

    // for Alt+R, Ctrl+U: Unique Phrase
    if ( ( event.altKey && event.keyCode == 82 ) || ( event.ctrlKey && event.keyCode == 85 ) )
        document.getElementById("format_unique_phrase").click();

    // for Alt+G, F2: Lookup Verse
    if ( ( event.altKey && event.keyCode == 71 ) || event.keyCode == 113 )
        document.getElementById("lookup").click();

    // for Alt+F, F4: Find Text
    if ( ( event.altKey && event.keyCode == 70 ) || event.keyCode == 115 )
        document.getElementById("find").click();

    // for Alt+V: Copy Verse
    if ( event.altKey && event.keyCode == 86 ) document.getElementById("copy_verse").click();

    // for Alt+A, F8: Save As New
    if ( ( event.altKey && event.keyCode == 65 ) || event.keyCode == 119 )
        document.getElementById("save_new").click();

    // for Alt+S, F9: Save Changes
    if ( ( event.altKey && event.keyCode == 83 ) || event.keyCode == 120 )
        document.getElementById("save_changes").click();

    // for Alt+X: Delete
    if ( event.altKey && event.keyCode == 88 ) document.getElementById("delete_question").click();

    // for Alt+C: Clear
    if ( event.altKey && event.keyCode == 67 ) document.getElementById("clear_form").click();
} );

Vue.http.get( cntlr + "/data" ).then( function (response) {
    new Vue({
        el: "#editor",
        data: response.body,
        methods: {
            format: function (className) {
                var selection = document.getSelection();
                if ( selection.rangeCount > 0 && selection.isCollapsed == 0 ) {
                    for ( var i = 0; i < selection.rangeCount; i++ ) {
                        var range       = selection.getRangeAt(i);
                        var replacement = document.createTextNode( range.toString() );

                        if (className) {
                            var span = document.createElement("span");
                            span.className = className;
                            span.appendChild(replacement);
                            replacement = span;
                        }

                        range.deleteContents();
                        range.insertNode(replacement);
                    }

                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;
                }
                else {
                    alert('No text selected to format.');
                }
            },
            save_new: function () {
                if (
                    !! this.question.book &&
                    parseInt( this.question.chapter ) > 0 &&
                    parseInt( this.question.verse ) > 0 &&
                    this.question.question.length > 0 &&
                    this.question.answer.length > 0 &&
                    !! this.question.type
                ) {
                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;

                    this.question.question_id = null;

                    this.$http.post( cntlr + "/save", this.question ).then( function (response) {
                        var question = response.body.question;

                        if ( ! this.questions.data[ question.book ] )
                            this.questions.data[ question.book ] = {};
                        if ( ! this.questions.data[ question.book ][ question.chapter ] )
                            this.questions.data[ question.book ][ question.chapter ] = {};

                        this.questions.data
                            [ question.book ][ question.chapter ][ question.question_id ] = question;

                        this.questions.books = Object.keys( this.questions.data ).sort();
                        this.questions.book = null;

                        this.$nextTick( function () {
                            this.questions.book = question.book;

                            this.$nextTick( function () {
                                this.questions.chapter = question.chapter;
                            } );
                        } );

                        this.clear_form();

                        this.$nextTick( function () {
                            this.question.book    = question.book;
                            this.question.chapter = question.chapter;
                            this.question.verse   = question.verse;

                            document.getElementById("verse").focus();
                            this.$nextTick( function () {
                                document.getElementById("verse").select();
                            } );
                        } );
                    } );
                }
                else {
                    alert('Not all required fields have data.');
                }
            },
            save_changes: function () {
                if ( !! this.questions.question_id ) {
                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;

                    this.$http.post( cntlr + "/save", this.question ).then( function (response) {
                        var question = response.body.question;

                        // delete question
                        // (code copied/duplicated for now for expediency; will refactor later)

                        delete this.questions.data
                            [ this.questions.book ][ this.questions.chapter ][ this.questions.question_id ];

                        if ( ! Object.keys(
                            this.questions.data[ this.questions.book ][ this.questions.chapter ]
                        ).length )
                            delete this.questions.data[ this.questions.book ][ this.questions.chapter ];

                        if ( ! Object.keys(
                            this.questions.data[ this.questions.book ]
                        ).length )
                            delete this.questions.data[ this.questions.book ];

                        if ( ! this.questions.data[ this.questions.book ] ) {
                            this.questions.books = Object.keys( this.questions.data ).sort();
                            if ( this.questions.books[0] ) {
                                this.questions.book = this.questions.books[0];
                            }
                            else {
                                this.questions.chapters = null;
                                this.questions.questions = null;
                            }
                        }
                        else if ( ! this.questions.data[ this.questions.book ][ this.questions.chapter ] ) {
                            this.questions.chapters = Object.keys( this.questions.data[ this.questions.book ] ).sort(
                                function ( a, b ) {
                                    return a - b;
                                }
                            );
                            this.questions.chapter = this.questions.chapters[0];
                        }
                        else {
                            var questions_hash = this.questions.data[ this.questions.book ][ this.questions.chapter ];
                            var keys = Object.keys(questions_hash);

                            var questions_array = new Array();
                            for ( var i = 0; i < keys.length; i++ ) {
                                questions_array.push( questions_hash[ keys[i] ] );
                            }

                            this.questions.questions = questions_array.sort( function ( a, b ) {
                                if ( a.verse < b.verse ) return -1;
                                if ( a.verse > b.verse ) return 1;
                                if ( a.type < b.type ) return -1;
                                if ( a.type > b.type ) return 1;
                                if ( a.used > b.used ) return -1;
                                if ( a.used < b.used ) return 1;
                                return 0;
                            } );
                        }

                        // create question
                        // (code copied/duplicated for now for expediency; will refactor later)

                        this.$nextTick( function () {
                            if ( ! this.questions.data[ question.book ] )
                                this.questions.data[ question.book ] = {};
                            if ( ! this.questions.data[ question.book ][ question.chapter ] )
                                this.questions.data[ question.book ][ question.chapter ] = {};

                            this.questions.data
                                [ question.book ][ question.chapter ][ question.question_id ] = question;

                            this.questions.books = Object.keys( this.questions.data ).sort();
                            this.questions.book = null;

                            this.$nextTick( function () {
                                this.questions.book = question.book;

                                this.$nextTick( function () {
                                    this.questions.chapter = question.chapter;
                                } );
                            } );

                            // this.clear_form();
                            // (don't clear form when saving a question)

                            this.$nextTick( function () {
                                this.question.book    = question.book;
                                this.question.chapter = question.chapter;
                                this.question.verse   = question.verse;

                                document.getElementById("verse").focus();
                                this.$nextTick( function () {
                                    document.getElementById("verse").select();
                                } );
                            } );
                        } );
                    } );
                }
                else {
                    alert('No previously saved question selected.');
                }
            },
            delete_question: function () {
                if ( !! this.questions.question_id ) {
                    this.$http.post(
                        cntlr + "/delete",
                        { question_id: this.questions.question_id }
                    ).then( function (response) {

                        delete this.questions.data
                            [ this.questions.book ][ this.questions.chapter ][ this.questions.question_id ];

                        if ( ! Object.keys(
                            this.questions.data[ this.questions.book ][ this.questions.chapter ]
                        ).length )
                            delete this.questions.data[ this.questions.book ][ this.questions.chapter ];

                        if ( ! Object.keys(
                            this.questions.data[ this.questions.book ]
                        ).length )
                            delete this.questions.data[ this.questions.book ];

                        if ( ! this.questions.data[ this.questions.book ] ) {
                            this.questions.books = Object.keys( this.questions.data ).sort();
                            if ( this.questions.books[0] ) {
                                this.questions.book = this.questions.books[0];
                            }
                            else {
                                this.questions.chapters = null;
                                this.questions.questions = null;
                            }
                        }
                        else if ( ! this.questions.data[ this.questions.book ][ this.questions.chapter ] ) {
                            this.questions.chapters = Object.keys( this.questions.data[ this.questions.book ] ).sort(
                                function ( a, b ) {
                                    return a - b;
                                }
                            );
                            this.questions.chapter = this.questions.chapters[0];
                        }
                        else {
                            var questions_hash = this.questions.data[ this.questions.book ][ this.questions.chapter ];
                            var keys = Object.keys(questions_hash);

                            var questions_array = new Array();
                            for ( var i = 0; i < keys.length; i++ ) {
                                questions_array.push( questions_hash[ keys[i] ] );
                            }

                            this.questions.questions = questions_array.sort( function ( a, b ) {
                                if ( a.verse < b.verse ) return -1;
                                if ( a.verse > b.verse ) return 1;
                                if ( a.type < b.type ) return -1;
                                if ( a.type > b.type ) return 1;
                                if ( a.used > b.used ) return -1;
                                if ( a.used < b.used ) return 1;
                                return 0;
                            } );
                        }
                    } );
                }
                else {
                    alert('No question selected to delete.');
                }
            },
            clear_form: function () {
                this.questions.question_id = null;

                this.question.question_id = null;
                this.question.used        = null;
                this.question.book        = null;
                this.question.chapter     = null;
                this.question.verse       = null;
                this.question.question    = null;
                this.question.answer      = null;
                this.question.type        = null;

                document.getElementById("book").focus();
            },
            lookup: function () {
                if (
                    !! this.question.book &&
                    parseInt( this.question.chapter ) > 0 &&
                    parseInt( this.question.verse ) > 0
                ) {
                    this.material.book = this.question.book;
                    this.$nextTick( function () {
                        this.material.chapter = this.question.chapter;
                        this.$nextTick( function () {
                            this.material.verse = this.question.verse;
                        } );
                    } );
                }
                else {
                    alert('Incomplete reference; lookup not possible.');
                }
            },
            find: function () {
                var selection = document.getSelection();
                if ( selection.rangeCount > 0 && selection.isCollapsed == 0 ) {
                    var search_text = "";
                    for ( var i = 0; i < selection.rangeCount; i++ ) {
                        search_text = search_text + selection.getRangeAt(i).toString();
                    }

                    this.material.search = search_text;
                }
                else {
                    alert('No text selected to conduct a find for.');
                }
            },
            copy_verse: function () {
                if (
                    !! this.question.book &&
                    parseInt( this.question.chapter ) > 0 &&
                    parseInt( this.question.verse ) > 0
                ) {
                    this.questions.question_id = null;

                    var verse = this.material.data
                        [ this.question.book ][ this.question.chapter ][ this.question.verse ];

                    this.question.question = "";
                    this.question.answer   = "";

                    this.$nextTick( function () {
                        this.question.question = verse.text;
                        this.question.answer   = verse.text;
                    } );

                    this.question.question_id = null;
                    this.question.used        = null;
                    this.question.type        = null;
                }
                else {
                    alert('Incomplete reference; copy verse not possible.');
                }
            },
            copy_verse_from_lookup: function (verse) {
                this.questions.question_id = null;

                this.question.book     = verse.book;
                this.question.chapter  = verse.chapter;
                this.question.verse    = verse.verse;
                this.question.question = verse.text;
                this.question.answer   = verse.text;

                this.question.question_id = null;
                this.question.used        = null;
                this.question.type        = null;
            },
            lookup_from_search: function (verse) {
                this.material.book = verse.book;
                this.$nextTick( function () {
                    this.material.chapter = verse.chapter;
                    this.$nextTick( function () {
                        this.material.verse = verse.verse;
                    } );
                } );
            }
        },
        watch: {
            "material.book": function () {
                this.material.chapters = Object.keys( this.material.data[ this.material.book ] ).sort(
                    function ( a, b ) {
                        return a - b;
                    }
                );

                this.material.chapter = null;
                this.$nextTick( function () {
                    this.material.chapter = this.material.chapters[0];
                } );
            },
            "material.chapter": function () {
                if ( !! this.material.chapter ) {
                    this.material.verses = this.material.data[ this.material.book ][ this.material.chapter ];
                    this.material.verse  = this.material.verses[1].verse;
                }
            },
            "material.verse": function () {
                this.$nextTick( function () {
                    window.location.href = "#v" + this.material.verse;
                } );
            },
            "material.search": function () {
                this.material.matched_verses = [];

                if ( this.material.search.length > 2 ) {
                    var search_term = this.material.search.toLowerCase().replace( /\W+/g, "" );

                    var books = Object.keys( this.material.data ).sort();
                    for ( var i = 0; i < books.length; i++ ) {
                        var chapters = Object.keys( this.material.data[ books[i] ] ).sort(
                            function ( a, b ) {
                                return a - b;
                            }
                        );

                        for ( var j = 0; j < chapters.length; j++ ) {
                            var verses = this.material.data[ books[i] ][ chapters[j] ];
                            var verse_numbers = Object.keys(verses).sort();

                            for ( var k = 0; k < verse_numbers.length; k++ ) {
                                var verse_number = verse_numbers[k];

                                if ( verses[verse_number].search.indexOf( search_term ) != -1 ) {
                                    this.material.matched_verses.push( verses[verse_number] );
                                }
                            }
                        }
                    }
                }
            },
            "questions.book": function () {
                if ( !! this.questions.book ) {
                    this.questions.chapters = Object.keys( this.questions.data[ this.questions.book ] ).sort(
                        function ( a, b ) {
                            return b - a;
                        }
                    );

                    this.questions.chapter = null;
                    this.$nextTick( function () {
                        this.questions.chapter = this.questions.chapters[0];
                    } );
                }
            },
            "questions.chapter": function () {
                if ( !! this.questions.chapter ) {
                    var questions_hash = this.questions.data[ this.questions.book ][ this.questions.chapter ];
                    var keys = Object.keys(questions_hash);

                    var questions_array = new Array();
                    for ( var i = 0; i < keys.length; i++ ) {
                        questions_array.push( questions_hash[ keys[i] ] );
                    }

                    this.questions.questions = questions_array.sort( function ( a, b ) {
                        if ( a.verse > b.verse ) return -1;
                        if ( a.verse < b.verse ) return 1;
                        if ( a.type < b.type ) return -1;
                        if ( a.type > b.type ) return 1;
                        if ( a.used > b.used ) return -1;
                        if ( a.used < b.used ) return 1;
                        return 0;
                    } );
                }
            },
            "questions.question_id": function () {
                if ( !! this.questions.question_id ) {
                    var question = this.questions.data
                        [ this.questions.book ][ this.questions.chapter ][ this.questions.question_id ];

                    for ( var key in question ) {
                        this.question[key] = question[key];
                    }
                }
            },
        },
        mounted: function () {
            this.material.books = Object.keys( this.material.data );
            this.material.book  = this.material.books[0];

            this.questions.books = Object.keys( this.questions.data ).sort();
            if ( this.questions.books[0] ) this.questions.book = this.questions.books[0];
        }
    });
} );
