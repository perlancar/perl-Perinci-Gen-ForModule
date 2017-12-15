package Perinci::Gen::ForModule;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use String::Util::Match qw(match_array_or_regex);
use Package::MoreUtil qw(package_exists list_package_contents);

use Exporter qw(import);
our @EXPORT_OK = qw(gen_meta_for_module);

our %SPEC;

$SPEC{gen_meta_for_module} = {
    v => 1.1,
    summary => 'Generate metadata for a module',
    description => <<'_',

This function can be used to automatically generate Rinci metadata for a
"traditional" Perl module which do not have any. Currently, only a plain and
generic package and function metadata are generated.

The resulting metadata will be put in %<PACKAGE>::SPEC. Functions that already
have metadata in the %SPEC will be skipped. The metadata will have
C<result_naked> property set to true, C<args_as> set to C<array>, and C<args>
set to C<{args => ["any" => {schema=>'any', pos=>0, greedy=>1}]}>. In the
future, function's arguments (and other properties) will be parsed from POD (and
other indicators).

_
    args => {
        module => {
            schema => 'str*',
            summary => 'The module name',
        },
        load => {
            schema => ['bool*' => {default=>1}],
            summary => 'Whether to load the module using require()',
        },
        include_subs => {
            schema => ['any' => { # XXX or regex
                of => [['array*'=>{of=>'str*'}], 'str*'], # 2nd should be regex*
            }],
            summary => 'If specified, only include these subs',
        },
        exclude_subs => {
            schema => ['any' => { # XXX or regex
                of => [['array*'=>{of=>'str*'}], 'str*'], # 2nd should be regex*
                default => '^_',
            }],
            summary => 'If specified, exclude these subs',
            description => <<'_',

By default, exclude private subroutines (subroutines which have _ prefix in
their names).

_
        },
    },
};
sub gen_meta_for_module {
    my %args = @_;

    my $inc = $args{include_subs};
    my $exc = $args{exclude_subs} // qr/^_/;

    # XXX schema
    my $module = $args{module}
        or return [400, "Please specify module"];
    my $load = $args{load} // 1;

    if ($load) {
        eval {
            my $modulep = $module; $modulep =~ s!::!/!g;
            require "$modulep.pm";
        };
        my $eval_err = $@;
        #return [500, "Can't load module $module: $eval_err"] if $eval_err;
        # ignore the error and try to load it anyway
    }
    return [500, "Package $module does not exist"]
        unless package_exists($module);

    my $note;
    {
        no strict 'vars'; # for $VERSION
        $note = "This metadata is automatically generated by ".
            __PACKAGE__." version ".($VERSION//"?")." on ".localtime();
    }

    my $metas;
    {
        no strict 'refs';
        $metas = \%{"$module\::SPEC"};
    }

    if (keys %$metas) {
        log_info("Not creating metadata for package $module: ".
                       "already defined");
        return [304, "Not modified"];
    }

    # generate package metadata
    $metas->{":package"} = {
        v => 1.1,
        summary => $module,
        description => $note,
    };

    my %content = list_package_contents($module);

    # generate subroutine metadatas
    for my $sub (sort grep {ref($content{$_}) eq 'CODE'} keys %content) {
        log_trace("Adding meta for subroutine %s ...", $sub);
        if (defined($inc) && !match_array_or_regex($sub, $inc)) {
            log_info("Not creating metadata for sub $module\::$sub: ".
                           "doesn't match include_subs");
            next;
        }
        if (defined($exc) &&  match_array_or_regex($sub, $exc)) {
            log_info("Not creating metadata for sub $module\::$sub: ".
                           "matches exclude_subs");
            next;
        }
        if ($metas->{$sub}) {
            log_info("Not creating metadata for sub $module\::$sub: ".
                           "already defined");
            next;
        }

        my $meta = {
            v => 1.1,
            summary => $sub,
            description => $note,
            result_naked => 1,
            args_as => 'array',
            args => {
                args => {
                    schema => ['array*' => {of=>'any'}],
                    summary => 'Arguments',
                    pos => 0,
                    greedy => 1,
                },
            },
        };
        $metas->{$sub} = $meta;
    }

    [200, "OK", $metas];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

In Foo/Bar.pm:

 package Foo::Bar;
 sub sub1 { ... }
 sub sub2 { ... }
 1;

In another script:

 use Perinci::Gen::FromModule qw(gen_meta_for_module);
 gen_meta_for_module(module=>'Foo::Bar');

Now Foo::Bar has metadata stored in %Foo::Bar::SPEC.


=head1 SEE ALSO

L<Perinci>, L<Rinci>

=cut
