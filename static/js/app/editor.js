Vue.http.get( cntlr + "/data" ).then( function (response) {
    var data = response.body;
    if ( data.error ) alert( data.error );

    data.lookup = {
        book    : null,
        chapter : null,
        verse   : null
    };
    data.question = {
        question_id : null,
        book        : null,
        chapter     : null,
        verse       : null,
        question    : null,
        answer      : null,
        type        : null,
        used        : null,
        marked      : null,
        score       : null
    };
    data.questions.question_id        = null;
    data.questions.marked_question_id = null;
    data.questions.marked_questions   = [];
    data.questions.questions          = null;
    data.questions.sort_by            = get_cookie("cbqz_editor_sort_by") || "desc_ref";
    data.questions.book               = null;
    data.questions.chapter            = null;
    data.questions.books              = null;
    data.questions.chapters           = null;

    data.classes = {
        cursor_progress : false
    };

    data.total_questions = 0;

    var sort_by = {
        desc_ref : function ( a, b ) {
            var icmp = b.book.toLowerCase().localeCompare( a.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter > b.chapter ) return -1;
            if ( a.chapter < b.chapter ) return 1;
            if ( a.verse > b.verse ) return -1;
            if ( a.verse < b.verse ) return 1;
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            return 0;
        },
        ref : function ( a, b ) {
            var icmp = a.book.toLowerCase().localeCompare( b.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter < b.chapter ) return -1;
            if ( a.chapter > b.chapter ) return 1;
            if ( a.verse < b.verse ) return -1;
            if ( a.verse > b.verse ) return 1;
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            return 0;
        },
        type : function ( a, b ) {
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;

            var icmp = b.book.toLowerCase().localeCompare( a.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter > b.chapter ) return -1;
            if ( a.chapter < b.chapter ) return 1;
            if ( a.verse > b.verse ) return -1;
            if ( a.verse < b.verse ) return 1;
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            return 0;
        },
        used : function ( a, b ) {
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;

            var icmp = b.book.toLowerCase().localeCompare( a.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter > b.chapter ) return -1;
            if ( a.chapter < b.chapter ) return 1;
            if ( a.verse > b.verse ) return -1;
            if ( a.verse < b.verse ) return 1;
            return 0;
        },
        length : function ( a, b ) {
            if ( a.question.length + a.answer.length < b.question.length + b.answer.length ) return -1;
            if ( a.question.length + a.answer.length > b.question.length + b.answer.length ) return 1;

            var icmp = a.book.toLowerCase().localeCompare( b.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter < b.chapter ) return -1;
            if ( a.chapter > b.chapter ) return 1;
            if ( a.verse < b.verse ) return -1;
            if ( a.verse > b.verse ) return 1;
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            return 0;
        },
        alphabetical : function ( a, b ) {
            var qa_a = a.question + a.answer;
            var qa_b = a.question + a.answer;
            var qcmp = qa_a.toLowerCase().localeCompare( qa_b.toLowerCase() );
            if ( qcmp != 0 ) return qcmp;

            var icmp = a.book.toLowerCase().localeCompare( b.book.toLowerCase() );
            if ( icmp != 0 ) return icmp;

            if ( a.chapter < b.chapter ) return -1;
            if ( a.chapter > b.chapter ) return 1;
            if ( a.verse < b.verse ) return -1;
            if ( a.verse > b.verse ) return 1;
            if ( a.type < b.type ) return -1;
            if ( a.type > b.type ) return 1;
            if ( a.used > b.used ) return -1;
            if ( a.used < b.used ) return 1;
            return 0;
        }
    };

    function count_questions (vue_obj) {
        var questions_count = 0;
        for ( book in vue_obj.questions.data ) {
            for ( chapter in vue_obj.questions.data[book] ) {
                for ( question in vue_obj.questions.data[book][chapter] ) {
                    questions_count++;
                }
            }
        }
        vue_obj.total_questions = questions_count;
    }

    function delete_question (vue_obj) {
        delete vue_obj.questions.data
            [ vue_obj.questions.book ][ vue_obj.questions.chapter ][ vue_obj.questions.question_id ];

        if ( ! Object.keys(
            vue_obj.questions.data[ vue_obj.questions.book ][ vue_obj.questions.chapter ]
        ).length )
            delete vue_obj.questions.data[ vue_obj.questions.book ][ vue_obj.questions.chapter ];

        if ( ! Object.keys(
            vue_obj.questions.data[ vue_obj.questions.book ]
        ).length )
            delete vue_obj.questions.data[ vue_obj.questions.book ];

        if ( ! vue_obj.questions.data[ vue_obj.questions.book ] ) {
            vue_obj.questions.books = Object.keys( vue_obj.questions.data ).sort();
            if ( vue_obj.questions.books[0] ) {
                vue_obj.questions.book = vue_obj.questions.books[0];
            }
            else {
                vue_obj.questions.chapters = null;
                vue_obj.questions.questions = null;
            }
        }
        else if ( ! vue_obj.questions.data[ vue_obj.questions.book ][ vue_obj.questions.chapter ] ) {
            vue_obj.questions.chapters = Object.keys( vue_obj.questions.data[ vue_obj.questions.book ] ).sort(
                function ( a, b ) {
                    return a - b;
                }
            );
            vue_obj.questions.chapter = vue_obj.questions.chapters[0];
        }
        else {
            var questions_hash = vue_obj.questions.data[ vue_obj.questions.book ][ vue_obj.questions.chapter ];
            var keys = Object.keys(questions_hash);

            var questions_array = new Array();
            for ( var i = 0; i < keys.length; i++ ) {
                questions_array.push( questions_hash[ keys[i] ] );
            }

            vue_obj.questions.questions = questions_array.sort( sort_by.ref );
        }

        count_questions(vue_obj);
    }

    function create_question ( vue_obj, question, clear_form ) {
        if ( ! vue_obj.questions.data[ question.book ] )
            vue_obj.questions.data[ question.book ] = {};
        if ( ! vue_obj.questions.data[ question.book ][ question.chapter ] )
            vue_obj.questions.data[ question.book ][ question.chapter ] = {};

        vue_obj.questions.data
            [ question.book ][ question.chapter ][ question.question_id ] = question;

        vue_obj.questions.books = Object.keys( vue_obj.questions.data ).sort();
        vue_obj.questions.book = null;

        vue_obj.$nextTick( function () {
            vue_obj.questions.book = question.book;

            vue_obj.$nextTick( function () {
                vue_obj.questions.chapter = question.chapter;
                vue_obj.questions.marked_questions = vue_obj.grep_marked_questions();
            } );
        } );

        if ( !! clear_form ) vue_obj.clear_form();

        vue_obj.$nextTick( function () {
            vue_obj.question.book    = question.book;
            vue_obj.question.chapter = question.chapter;
            vue_obj.question.verse   = question.verse;

            document.getElementById("verse").focus();
            vue_obj.$nextTick( function () {
                document.getElementById("verse").select();
            } );
        } );

        count_questions(vue_obj);
    }

    var vue_app = new Vue({
        el: "#editor",
        data: data,
        methods: {
            copy_verse: function () {
                if ( ! this.verse_incomplete ) {
                    var verse = this.material
                        [ this.question.book ][ this.question.chapter ][ this.question.verse ];

                    this.question.question = "";
                    this.question.answer   = "";

                    this.$nextTick( function () {
                        this.question.question = verse.text;
                        this.question.answer   = verse.text;
                    } );
                }
                else {
                    alert("Incomplete reference; copy verse not possible.");
                }
            },

            lookup_reference: function () {
                if ( ! this.verse_incomplete ) {
                    this.lookup.book    = this.question.book;
                    this.lookup.chapter = this.question.chapter;
                    this.lookup.verse   = this.question.verse;
                }
                else {
                    alert("Incomplete reference; lookup not possible.");
                }
            },

            auto_text: function () {
                if ( ! this.new_question_incomplete ) {
                    this.classes.cursor_progress = true;

                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;

                    this.$http.post( cntlr + "/auto_text", this.question ).then( function (response) {
                        if ( response.body.question.error ) {
                            alert( response.body.question.error );
                        }
                        else {
                            this.question.question = response.body.question.question;
                            this.question.answer   = response.body.question.answer;
                        }

                        this.classes.cursor_progress = false;
                    } );
                }
                else {
                    alert("Incomplete reference and type; auto not possible.");
                }
            },

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
                    alert("No text selected to format.");
                }
            },

            save_new: function () {
                if ( ! this.verse_incomplete ) {
                    this.classes.cursor_progress = true;

                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;
                    this.question.marked   = (
                        !! this.question.type &&
                        this.question.question.length > 0 &&
                        this.question.answer.length > 0
                    ) ? null : "Incomplete question";

                    this.question.question_id = null;

                    this.$http.post( cntlr + "/save", this.question ).then( function (response) {
                        create_question( this, response.body.question, "clear_form" );
                        this.classes.cursor_progress = false;
                    } );
                }
                else {
                    alert("Not all required fields have data.");
                }
            },

            save_changes: function () {
                if ( ! this.no_saved_question ) {
                    this.classes.cursor_progress = true;

                    this.question.question = this.$refs.question.innerHTML;
                    this.question.answer   = this.$refs.answer.innerHTML;

                    var marked_original = this.questions.data
                        [ this.questions.book ][ this.questions.chapter ]
                        [ this.questions.question_id ]['marked'];

                    this.question.marked =
                        (
                            ! (
                                !! this.question.type &&
                                this.question.question.length > 0 &&
                                this.question.answer.length > 0
                            )
                        ) ? "Incomplete question" :
                        ( this.question.marked == marked_original ) ? null :
                        ( !! this.question.marked ) ? this.question.marked : null;

                    this.$http.post( cntlr + "/save", this.question ).then( function (response) {
                        delete_question(this);
                        this.$nextTick( function () {
                            create_question( this, response.body.question );
                            this.classes.cursor_progress = false;
                        } );
                    } );
                }
                else {
                    alert("No previously saved question selected.");
                }
            },

            delete_question: function () {
                if ( ! this.no_saved_question ) {
                    this.classes.cursor_progress = true;

                    this.$http.post(
                        cntlr + "/delete",
                        { question_id: this.questions.question_id }
                    ).then( function (response) {
                        this.classes.cursor_progress = false;
                        if ( response.body.success ) {
                            delete_question(this);
                            this.questions.marked_questions = this.grep_marked_questions();
                        }
                        else {
                            alert("There was an error deleting the question.");
                        }
                    } );
                }
                else {
                    alert("No question selected to delete.");
                }
            },

            clear_form: function () {
                this.questions.question_id        = null;
                this.questions.marked_question_id = null;

                this.question.question_id = null;
                this.question.used        = null;
                this.question.book        = null;
                this.question.chapter     = null;
                this.question.verse       = null;
                this.question.question    = null;
                this.question.answer      = null;
                this.question.type        = null;
                this.question.marked      = null;

                this.$refs.question.innerHTML = '';
                this.$refs.answer.innerHTML   = '';

                document.getElementById("book").focus();
            },

            grep_marked_questions: function () {
                var marked_questions = [];

                for ( var book in this.questions.data ) {
                    for ( var chapter in this.questions.data[book] ) {
                        for ( var id in this.questions.data[book][chapter] ) {
                            if ( this.questions.data[book][chapter][id].marked ) {
                                marked_questions.push( this.questions.data[book][chapter][id] );
                            }
                        }
                    }
                }

                return marked_questions.sort( sort_by[ data.questions.sort_by ] );
            },

            lookup_reference_change: function ( book, chapter, verse ) {
                this.lookup.book    = book;
                this.lookup.chapter = chapter;
                this.lookup.verse   = verse;
            },

            lookup_reference_click: function (verse) {
                this.questions.question_id = null;

                this.question.book     = verse.book;
                this.question.chapter  = verse.chapter;
                this.question.verse    = verse.verse;
                this.question.question = verse.text;
                this.question.answer   = verse.text;

                this.question.question_id = null;
                this.question.used        = null;
                this.question.type        = null;
                this.question.marked      = null;
            },

            search_reference_click: function (verse) {
                this.lookup.book    = verse.book;
                this.lookup.chapter = verse.chapter;
                this.lookup.verse   = verse.verse;
            }
        },

        computed: {
            verse_incomplete: function () {
                return (
                    !! this.question.book &&
                    parseInt( this.question.chapter ) > 0 &&
                    parseInt( this.question.verse ) > 0
                ) ? false : true;
            },

            no_saved_question: function () {
                return ! this.questions.question_id;
            },

            new_question_incomplete: function () {
                return (
                    !! this.question.book &&
                    parseInt( this.question.chapter ) > 0 &&
                    parseInt( this.question.verse ) > 0 &&
                    !! this.question.type
                ) ? false : true;
            }
        },

        watch: {
            "questions.book": function () {
                if ( !! this.questions.book ) {
                    var sort_by = this.questions.sort_by;
                    this.questions.chapters = Object.keys( this.questions.data[ this.questions.book ] ).sort(
                        function ( a, b ) {
                            return ( sort_by == "desc_ref" ) ? b - a : a - b;
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

                    this.questions.questions = questions_array.sort( sort_by[ this.questions.sort_by ] );
                }
            },

            "questions.question_id": function () {
                if ( !! this.questions.question_id ) {
                    var question = this.questions.data
                        [ this.questions.book ][ this.questions.chapter ][ this.questions.question_id ];

                    for ( var key in question ) {
                        this.question[key] = question[key];
                    }

                    var question_id = this.questions.question_id;
                    if (
                        this.questions.marked_questions.filter( function (question) {
                            return question.question_id == question_id;
                        } ).length > 0
                    ) {
                        this.questions.marked_question_id = this.questions.question_id;
                    }
                    else {
                        this.questions.marked_question_id = null;
                    }
                }
            },

            "questions.marked_question_id": function () {
                if (
                    !! this.questions.marked_question_id &&
                    (
                        ! this.questions.question_id ||
                        this.questions.marked_question_id != this.questions.question_id
                    )
                ) {
                    var questions = this.questions;
                    var marked_question = this.questions.marked_questions.filter( function (question) {
                        return question.question_id == questions.marked_question_id;
                    } ).shift();

                    this.questions.book = marked_question.book;
                    this.$nextTick( function () {
                        this.$nextTick( function () {
                            this.questions.chapter = marked_question.chapter;

                            this.$nextTick( function () {
                                this.questions.question_id = this.questions.marked_question_id;
                            } );
                        } );
                    } );
                }
            },

            "questions.sort_by": function () {
                this.questions.book = null;
                this.$nextTick( function () {
                    this.questions.books = Object.keys( this.questions.data ).sort();
                    if ( this.questions.books[0] ) this.questions.book = this.questions.books[0];
                } );

                this.questions.marked_questions = this.grep_marked_questions();

                set_cookie( "cbqz_editor_sort_by", this.questions.sort_by, 65535 );
            }
        },

        mounted: function () {
            this.questions.books = Object.keys( this.questions.data ).sort();
            if ( this.questions.books[0] ) this.questions.book = this.questions.books[0];

            this.questions.marked_questions = this.grep_marked_questions();
            count_questions(this);
        }
    });

    function cbqz_html_markup_only (html) {
        while (true) {
            var old_html = html;
            html = html.replace(
                /<span class="unique_(word|phrase|chapter)">([^<]+)<\/span>/gi,
                function ( match, type, content ) {
                    var symbol =
                        ( type == "word"    ) ? "*" :
                        ( type == "phrase"  ) ? "^" :
                        ( type == "chapter" ) ? "_" : "#";
                    return symbol + content + "/";
                }
            );
            if ( old_html == html ) break;
        }

        return html.replace( /<[^>]*>/gi, "" ).replace(
            /(\*|\^|\_|\/)/gi,
            function ( match, symbol ) {
                if ( symbol == "*" ) return '<span class="unique_word">';
                if ( symbol == "^" ) return '<span class="unique_phrase">';
                if ( symbol == "_" ) return '<span class="unique_chapter">';
                if ( symbol == "/" ) return '</span>';
                return "";
            }
        );
    }

    document.addEventListener( "keyup", function(event) {
        // for Cntl+V: Paste
        if ( event.ctrlKey && event.keyCode == 86 ) {
            var element = document.activeElement;
            var class_name = element.getAttribute("class");

            if ( !! class_name ) {
                if ( class_name.match(/\bquestion_box\b/) ) {
                    vue_app.$refs.question.innerHTML = cbqz_html_markup_only( vue_app.$refs.question.innerHTML );
                }
                else if ( class_name.match(/\banswer_box\b/) ) {
                    vue_app.$refs.answer.innerHTML = cbqz_html_markup_only( vue_app.$refs.answer.innerHTML );
                }
            }
        }
    } );

    document.addEventListener( "keyup", function(event) {
        event.preventDefault();

        // for Alt+V: Copy Verse
        if ( event.altKey && event.keyCode == 86 ) document.getElementById("copy_verse").click();

        // for Alt+G, F2: Lookup Verse
        if ( ( event.altKey && event.keyCode == 71 ) || event.keyCode == 113 )
            document.getElementById("lookup").click();

        // for Alt+Z: Auto
        if ( event.altKey && event.keyCode == 90 ) document.getElementById("auto_text").click();

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

        // for Alt+T: Prompt for Reference
        if ( event.altKey && event.keyCode == 84 )
            vue_app.$refs.material_lookup.enter_reference();

        // for Alt+F, F4: Find Text
        if ( ( event.altKey && event.keyCode == 70 ) || event.keyCode == 115 )
            vue_app.$refs.material_search.find();
    } );
} );
