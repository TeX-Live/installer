use strict;
use warnings;
package Test::Warnings; # git description: v0.037-4-gdc90508
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: Test for warnings and the lack of them
# KEYWORDS: testing tests warnings

our $VERSION = '0.038';

use parent 'Exporter';
use Test::Builder;

our @EXPORT_OK = qw(
    allow_warnings allowing_warnings
    had_no_warnings
    warnings warning
    allow_patterns
    disallow_patterns
);
our @EXPORT = qw(done_testing);
our %EXPORT_TAGS = ( all => [ @EXPORT_OK, @EXPORT ] );

my $warnings_allowed;
my $forbidden_warnings_found;
my $done_testing_called;
my $no_end_test;
my $fail_on_warning;
my $report_warnings;
my @collected_warnings;
my @allowed_patterns;

sub import {
    my $class = shift @_;

    my %names; @names{@_} = ();
    # END block will check for this status
    $no_end_test = exists $names{':no_end_test'};
    # __WARN__ handler will check for this status
    $fail_on_warning = exists $names{':fail_on_warning'};
    # Collect and report warnings at the end
    $report_warnings = exists $names{':report_warnings'};

    delete @names{qw(:no_end_test :fail_on_warning :report_warnings)};

    if (not $no_end_test) {
        $names{done_testing} = ();
        my $callpkg = caller(0);
        no strict 'refs';
        no warnings 'once';
        undef *{$callpkg.'::done_testing'} if *{$callpkg.'::done_testing'}{CODE};
    }

    __PACKAGE__->export_to_level(1, $class, keys %names);
}

# swap this out for testing this module only!
my $tb;
sub _builder(;$) {
    if (not @_) {
        $tb ||= Test::Builder->new;
        return $tb;
    }

    $tb = shift;
}

my $_orig_warn_handler = $SIG{__WARN__};
$SIG{__WARN__} = sub {
    if ($warnings_allowed or grep +($_[0] =~ $_), @allowed_patterns) {
        Test::Builder->new->note($_[0]);
    }
    else {
        $forbidden_warnings_found++;
        push @collected_warnings, $_[0] if $report_warnings;

        # TODO: this doesn't handle blessed coderefs... does anyone care?
        goto &$_orig_warn_handler if $_orig_warn_handler
            and (  (ref $_orig_warn_handler eq 'CODE')
                or ($_orig_warn_handler ne 'DEFAULT'
                    and $_orig_warn_handler ne 'IGNORE'
                    and defined &$_orig_warn_handler));

        if ($_[0] =~ /\n$/) {
            warn $_[0];
        } else {
            require Carp;
            Carp::carp($_[0]);
        }
        _builder->ok(0, 'unexpected warning') if $fail_on_warning;
    }
};

sub warnings(;&) {
    # if someone manually does warnings->import in the same namespace this is
    # imported into, this sub will be called.  in that case, just return the
    # string "warnings" so it calls the correct method.
    if (!@_) {
        return 'warnings';
    }
    my $code = shift;
    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, shift;
    };
    $code->();
    @warnings;
}

sub warning(&) {
    my @warnings = &warnings(@_);
    return @warnings == 1 ? $warnings[0] : \@warnings;
}

# check for any forbidden warnings, and record that we have done so
# so we do not check again via END
sub done_testing {
    if (Test2::Tools::Basic->can('done_testing')) {
        if (not $no_end_test and not $done_testing_called) {
            # we could use $ctx to create the test, which means not having to adjust Level,
            # but then we need to make _builder Test2-compatible, which seems like a PITA.
            local $Test::Builder::Level = $Test::Builder::Level + 3;
            had_no_warnings('no (unexpected) warnings (via done_testing)');
            $done_testing_called = 1;
        }

        Test2::Tools::Basic::done_testing(@_);
    }
    elsif (Test::Builder->can('done_testing')) {
        # only do this at the end of all tests, not at the end of a subtest
        my $builder = _builder;
        my $in_subtest_sub = $builder->can('in_subtest');
        if (not $no_end_test and not $done_testing_called
            and not ($in_subtest_sub ? $builder->$in_subtest_sub : $builder->parent)) {
            local $Test::Builder::Level = $Test::Builder::Level + 3;
            had_no_warnings('no (unexpected) warnings (via done_testing)');
            $done_testing_called = 1;
        }

        _builder->done_testing(@_);
    }
    else {
        die 'no done_testing available via a Test module';
    }
}

# we also monkey-patch Test::Builder::done_testing (which is called by Test::More::done_testing),
# in case Test::More was loaded after Test::Warnings and therefore its version of done_testing was
# imported into the test rather than ours.
if (Test::Builder->can('done_testing')) {
    no strict 'refs';
    my $orig = *{'Test::Builder::done_testing'}{CODE};
    no warnings 'redefine';
    *{'Test::Builder::done_testing'} = sub {
        # only do this at the end of all tests, not at the end of a subtest
        my $builder = _builder;
        my $in_subtest_sub = $builder->can('in_subtest');
        if (not $no_end_test and not $done_testing_called
            and not ($in_subtest_sub ? $builder->$in_subtest_sub : $builder->parent)) {
            local $Test::Builder::Level = $Test::Builder::Level + 3;
            had_no_warnings('no (unexpected) warnings (via done_testing)');
            $done_testing_called = 1;
        }

        $orig->(@_);
    };
}

END {
    if (not $no_end_test
        and not $done_testing_called
        # skip this if there is no plan and no tests have been run (e.g.
        # compilation tests of this module!)
        and (_builder->expected_tests or _builder->current_test > 0)
    ) {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        had_no_warnings('no (unexpected) warnings (via END block)');
    }
}

# setter
sub allow_warnings(;$) {
    $warnings_allowed = @_ || defined $_[0] ? $_[0] : 1;
}

# getter
sub allowing_warnings() { $warnings_allowed }

# call at any time to assert no (unexpected) warnings so far
sub had_no_warnings(;$) {
    if ($ENV{PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS}) {
        $forbidden_warnings_found
            and _builder->diag("Found $forbidden_warnings_found warnings but allowing them because PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS is set");
    }
    else {
        _builder->ok(!$forbidden_warnings_found, shift || 'no (unexpected) warnings');
    }
    if (($report_warnings or $ENV{PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS})
          and $forbidden_warnings_found) {
        _builder->diag("Got the following unexpected warnings:");
        for my $i (1 .. @collected_warnings) {
            _builder->diag("  $i: $collected_warnings[ $i - 1 ]");
        }
    }
}

# pass one or more regexes (in qr format)
# when called in void context, lasting effect is universal
# otherwise, returns objects: when they go out of scope, the effect is removed
#   (warning disallowed again).
sub allow_patterns(@) {
  push @allowed_patterns, @_;
  return if not defined wantarray;
  return [ map +Test::Warnings::TemporaryWarning->new($_), @_ ];
}

sub disallow_patterns(@) {
  foreach my $pattern (@_) {
    @allowed_patterns = grep +($_ ne $pattern), @allowed_patterns;
  }
}

package # hide from PAUSE
  Test::Warnings::TemporaryWarning;

sub new {
  my ($class, $pattern) = @_;
  bless \$pattern, $class;
}

sub DESTROY {
  Test::Warnings::disallow_patterns(${$_[0]});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Warnings - Test for warnings and the lack of them

=head1 VERSION

version 0.038

=head1 SYNOPSIS

    use Test::More;
    use Test::Warnings;

    pass('yay!');
    done_testing;

emits TAP:

    ok 1 - yay!
    ok 2 - no (unexpected) warnings (via done_testing)
    1..2

and:

    use Test::More tests => 3;
    use Test::Warnings 0.005 ':all';

    pass('yay!');
    like(warning { warn "oh noes!" }, qr/^oh noes/, 'we warned');

emits TAP:

    ok 1 - yay!
    ok 2 - we warned
    ok 3 - no (unexpected) warnings (via END block)
    1..3

=head1 DESCRIPTION

If you've ever tried to use L<Test::NoWarnings> to confirm there are no warnings
generated by your tests, combined with the convenience of C<done_testing> to
not have to declare a
L<test count|Test::More/I love it-when-a-plan-comes-together>,
you'll have discovered that these two features do not play well together,
as the test count will be calculated I<before> the warnings test is run,
resulting in a TAP error. (See C<examples/test_nowarnings.pl> in this
distribution for a demonstration.)

This module is intended to be used as a drop-in replacement for
L<Test::NoWarnings>: it also adds an extra test, but runs this test I<before>
C<done_testing> calculates the test count, rather than after.  It does this by
hooking into C<done_testing> as well as via an C<END> block.  You can declare
a plan, or not, and things will still Just Work.

It is actually equivalent to:

    use Test::NoWarnings 1.04 ':early';

as warnings are still printed normally as they occur.  You are safe, and
enthusiastically encouraged, to perform a global search-replace of the above
with C<use Test::Warnings;> whether or not your tests have a plan.

It can also be used as a replacement for L<Test::Warn>, if you wish to test
the content of expected warnings; read on to find out how.

=head1 FUNCTIONS

=for Pod::Coverage done_testing

The following functions are available for import (not included by default; you
can also get all of them by importing the tag C<:all>):

=head2 C<< allow_warnings([bool]) >> - EXPERIMENTAL - MAY BE REMOVED

When passed a true value, or no value at all, subsequent warnings will not
result in a test failure; when passed a false value, subsequent warnings will
result in a test failure.  Initial value is C<false>.

When warnings are allowed, any warnings will instead be emitted via
L<Test::Builder::note|Test::Builder/Output>.

=head2 C<allowing_warnings> - EXPERIMENTAL - MAY BE REMOVED

Returns whether we are currently allowing warnings (set by C<allow_warnings>
as described above).

=head2 C<< had_no_warnings(<optional test name>) >>

Tests whether there have been any warnings so far, not preceded by an
C<allowing_warnings> call.  It is run
automatically at the end of all tests, but can also be called manually at any
time, as often as desired.

=head2 C<< warnings( { code } ) >>

Given a code block, runs the block and returns a list of all the
(not previously allowed via C<allow_warnings>) warnings issued within.  This
lets you test for the presence of warnings that you not only would I<allow>,
but I<must> be issued.  Testing functions are not provided; given the strings
returned, you can test these yourself using your favourite testing functions,
such as L<Test::More::is|Test::More/is> or L<Test::Deep::cmp_deeply|Test::Deep/cmp_deeply>.

You can use this construct as a replacement for
L<Test::Warn::warnings_are|Test::Warn/warnings_are>:

    is_deeply(
        [ warnings { ... } ],
        [
            'warning message 1',
            'warning message 2',
        ],
        'got expected warnings',
    );

or, to replace L<Test::Warn::warnings_like|Test::Warn/warnings_like>:

    cmp_deeply(
        [ warnings { ... } ],
        bag(    # ordering of messages doesn't matter
            re(qr/warning message 1/),
            re(qr/warning message 2/),
        ),
        'got expected warnings (in any order)',
    );

Warnings generated by this code block are I<NOT> propagated further. However,
since they are returned from this function with their filename and line
numbers intact, you can re-issue them yourself immediately after calling
C<warnings(...)>, if desired.

Note that C<use Test::Warnings 'warnings'> will give you a C<warnings>
subroutine in your namespace (most likely C<main>, if you're writing a test),
so you (or things you load) can't subsequently do C<< warnings->import >> --
it will result in the error: "Not enough arguments for
Test::Warnings::warnings at ..., near "warnings->import"".  To work around
this, either use the fully-qualified form (C<Test::warnings>) or make your
calls to the C<warnings> package first.

=head2 C<< warning( { code } ) >>

Same as C<< warnings( { code } ) >>, except a scalar is always returned - the
single warning produced, if there was one, or an arrayref otherwise -- which
can be more convenient to use than C<warnings()> if you are expecting exactly
one warning.

However, you are advised to capture the result from C<warning()> into a temp
variable so you can dump its value if it doesn't contain what you expect.
e.g. with this test:

    like(
        warning { foo() },
        qr/^this is a warning/,
        'got a warning from foo()',
    );

if you get two warnings (or none) back instead of one, you'll get an
arrayref, which will result in an unhelpful test failure message like:

    #   Failed test 'got a warning from foo()'
    #   at t/mytest.t line 10.
    #                   'ARRAY(0xdeadbeef)'
    #     doesn't match '(?^:^this is a warning)'

So instead, change your test to:

    my $warning = warning { foo() };
    like(
        $warning,
        qr/^this is a warning/,
        'got a warning from foo()',
    ) or diag 'got warning(s): ', explain($warning);

=head2 allow_patterns

  allow_patterns(qr/always allow this warning/);
  {
    my $temp = allow_patterns(qr/only allow in this scope/, qr/another temporary warning/);
    ... stuff ...
  }

Given one or more regular expressions, in C<qr/.../> form, add them to the allow-list (warnings will
be emitted with C<note> rather than triggering the warning handler). If the return value is saved in
a local variable, the warning exemption will only be in effect for that local scope (the addition is
reversed at the end of the scope); otherwise, the effect is global.

=head2 disallow_patterns

Given one or more regular expressions, in C<qr/.../> form, remove it from the allow-list. The
pattern must exactly match a pattern previously provided to L</allow_patterns>.

=head1 IMPORT OPTIONS

=head2 C<:all>

Imports all functions listed above

=head2 C<:no_end_test>

Disables the addition of a C<had_no_warnings> test
via C<END> or C<done_testing>

=head2 C<:fail_on_warning>

=for stopwords unexempted

When used, fail immediately when an unexempted warning is generated (as opposed to waiting until
L</had_no_warnings> or C<done_testing> is called).

I recommend you only turn this option on when debugging a test, to see where a surprise warning is coming from,
and rely on the end-of-tests check otherwise.

=head2 C<:report_warnings>

When used, C<had_no_warnings()> will print all the unexempted warning content, in case it had been suppressed
earlier by other captures (such as L<Test::Output/stderr_like> or L<Capture::Tiny/capture>).

=head1 OTHER OPTIONS

You can temporarily turn off the failure behaviour of this module, swapping it out for reporting
(see C<:report_warnings> above) with:

  $ENV{PERL_TEST_WARNINGS_ONLY_REPORT_WARNINGS} = 1;

This can be useful for working around problematic modules that have warnings in newer Perl versions.

=head1 CAVEATS

=for stopwords smartmatch TODO irc

Sometimes new warnings can appear in Perl that should B<not> block
installation -- for example, smartmatch was recently deprecated in
perl 5.17.11, so now any distribution that uses smartmatch and also
tests for warnings cannot be installed under 5.18.0.  You might want to
consider only making warnings fail tests in an author environment -- you can
do this with the L<if> pragma:

    use if $ENV{AUTHOR_TESTING} || $ENV{RELEASE_TESTING}, 'Test::Warnings';

In future versions of this module, when interfaces are added to test the
content of warnings, there will likely be additional sugar available to
indicate that warnings should be checked only in author tests (or TODO when
not in author testing), but will still provide exported subs.  Comments are
enthusiastically solicited - drop me an email, write up an RT ticket, or come
by C<#perl-qa> on irc!

=for stopwords Achtung

B<Achtung!>  This is not a great idea:

    sub warning_like(&$;$) {
        my ($code, $pattern, $name) = @_;
        like( &warning($code), $pattern, $name );
    }

    warning_like( { ... }, qr/foo/, 'foo appears in the warning' );

If the code in the C<{ ... }> is going to warn with a stack trace with the
arguments to each subroutine in its call stack (for example via C<Carp::cluck>),
the test name, "foo appears in the warning" will itself be matched by the
regex (see F<examples/warning_like.t>).  Instead, write this:

  like( warning { ... }, qr/foo/, 'foo appears in the warning' );

=head1 CAVEATS

If you are using another module that sets its own warning handler (for example L<Devel::Confess> or
L<diagnostics>) your results may be mixed, as those handlers will interfere with this module's
ability to properly detect and capture warnings in their original form.

=head1 TO DO (or: POSSIBLE FEATURES COMING IN FUTURE RELEASES)

=over

=item * C<< allow_warnings(qr/.../) >> - allow some warnings and not others

=for stopwords subtest subtests

=item * more sophisticated handling in subtests - if we save some state on the
L<Test::Builder> object itself, we can allow warnings in a subtest and then
the state will revert when the subtest ends, as well as check for warnings at
the end of every subtest via C<done_testing>.

=item * sugar for making failures TODO when testing outside an author
environment

=back

=head1 SEE ALSO

=for stopwords YANWT

=over 4

=item *

L<Test::NoWarnings>

=item *

L<Test::FailWarnings>

=item *

L<blogs.perl.org: YANWT (Yet Another No-Warnings Tester)|http://blogs.perl.org/users/ether/2013/03/yanwt-yet-another-no-warnings-tester.html>

=item *

L<strictures> - which makes all warnings fatal in tests, hence lessening the need for special warning testing

=item *

L<Test::Warn>

=item *

L<Test::Fatal>

=back

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Warnings>
(or L<bug-Test-Warnings@rt.cpan.org|mailto:bug-Test-Warnings@rt.cpan.org>).

There is also a mailing list available for users of this distribution, at
L<http://lists.perl.org/list/perl-qa.html>.

There is also an irc channel available for users of this distribution, at
L<C<#perl> on C<irc.perl.org>|irc://irc.perl.org/#perl-qa>.

I am also usually active on irc, as 'ether' at C<irc.perl.org> and C<irc.libera.chat>.

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 CONTRIBUTORS

=for stopwords Graham Knop Tina Müller A. Sinan Unur Leon Timmermans

=over 4

=item *

Graham Knop <haarg@haarg.org>

=item *

Tina Müller <cpan2@tinita.de>

=item *

A. Sinan Unur <nanis@cpan.org>

=item *

Leon Timmermans <fawaka@gmail.com>

=back

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
