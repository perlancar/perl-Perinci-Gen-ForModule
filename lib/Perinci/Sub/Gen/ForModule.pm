package Perinci::Sub::Gen::ForModule;

use 5.010;
use strict;
use warnings;

use Exporter::Lite;
use Log::Any '$log';
use Module::Info;
use SHARYANTO::Array::Util qw(match_array_or_regex);

our @EXPORT_OK = qw(gen_meta_for_module);

# VERSION

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
            }],
            summary => 'If specified, exclude these subs',
        },
    },
};
sub gen_meta_for_module {
    my %args = @_;

    my $inc = $args{include_subs};
    my $exc = $args{exclude_subs};

    # XXX schema
    my $module = $args{module}
        or return [400, "Please specify module"];
    my $load = $args{load} // 1;

    eval {
        my $modulep = $module; $modulep =~ s!::!/!g;
        require "$modulep.pm";
    };
    my $eval_err = $@;
    return [500, "Can't load module $module: $eval_err"] if $eval_err;

    my $mod = Module::Info->new_from_loaded($module);

    for my $sub ($mod->subroutines) {
        next if ref($sub);
        $sub =~ s/.+:://;
        $log->tracef("Adding meta for subroutine %s ...", $sub);
        if (defined($inc) && !match_array_or_regex($sub, $inc)) {
            $log->info("Subroutine $sub skipped: doesn't match include_subs");
            next;
        }
        if (defined($exc) &&  match_array_or_regex($sub, $exc)) {
            $log->info("Subroutine $sub skipped: doesn't match include_subs");
            next;
        }
        no strict 'refs';
        my $metas = \%{"$module\::SPEC"};
        if ($metas->{$sub}) {
            $log->debugf("SPEC keys: %s", [keys %$metas]);
            $log->info("Subroutine $sub skipped: already has meta");
            next;
        }

        no strict 'vars'; # for $VERSION
        my $meta = {
            v => 1.1,
            summary => $sub,
            description => "This metadata is automatically generated by ".
                __PACKAGE__." version ".($VERSION//"?")." on ".localtime(),
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

    [200, "OK"];
}

1;
#ABSTRACT: Generate metadata for a module

=head1 SYNOPSIS

In Foo.pm:

 package Foo;
 sub sub1 { ... }
 sub sub2 { ... }
 1;

In another script:

 use Perinci::Sub::Gen::FromModule qw(gen_meta_for_module);
 gen_meta_for_module(module=>'Foo');

Now Foo's functions have function metadata (in %Foo::SPEC).


=head1 DESCRIPTION

This module provides gen_meta_for_module().

This module uses L<Log::Any> for logging framework.

This module has L<Rinci> metadata.


=head1 FUNCTIONS

None are exported by default, but they are exportable.


=head1 FAQ


=head1 SEE ALSO

L<Perinci>, L<Rinci>

=cut
