use strict;
use warnings;
package Test::Fatal;
# ABSTRACT: incredibly simple helpers for testing code with exceptions
$Test::Fatal::VERSION = '0.017';
#pod =head1 SYNOPSIS
#pod
#pod   use Test::More;
#pod   use Test::Fatal;
#pod
#pod   use System::Under::Test qw(might_die);
#pod
#pod   is(
#pod     exception { might_die; },
#pod     undef,
#pod     "the code lived",
#pod   );
#pod
#pod   like(
#pod     exception { might_die; },
#pod     qr/turns out it died/,
#pod     "the code died as expected",
#pod   );
#pod
#pod   isa_ok(
#pod     exception { might_die; },
#pod     'Exception::Whatever',
#pod     'the thrown exception',
#pod   );
#pod
#pod =head1 DESCRIPTION
#pod
#pod Test::Fatal is an alternative to the popular L<Test::Exception>.  It does much
#pod less, but should allow greater flexibility in testing exception-throwing code
#pod with about the same amount of typing.
#pod
#pod It exports one routine by default: C<exception>.
#pod
#pod B<Achtung!>  C<exception> intentionally does not manipulate the call stack.
#pod User-written test functions that use C<exception> must be careful to avoid
#pod false positives if exceptions use stack traces that show arguments.  For a more
#pod magical approach involving globally overriding C<caller>, see
#pod L<Test::Exception>.
#pod
#pod =cut

use Carp ();
use Try::Tiny 0.07;

use Exporter 5.57 'import';

our @EXPORT    = qw(exception);
our @EXPORT_OK = qw(exception success dies_ok lives_ok);

#pod =func exception
#pod
#pod   my $exception = exception { ... };
#pod
#pod C<exception> takes a bare block of code and returns the exception thrown by
#pod that block.  If no exception was thrown, it returns undef.
#pod
#pod B<Achtung!>  If the block results in a I<false> exception, such as 0 or the
#pod empty string, Test::Fatal itself will die.  Since either of these cases
#pod indicates a serious problem with the system under testing, this behavior is
#pod considered a I<feature>.  If you must test for these conditions, you should use
#pod L<Try::Tiny>'s try/catch mechanism.  (Try::Tiny is the underlying exception
#pod handling system of Test::Fatal.)
#pod
#pod Note that there is no TAP assert being performed.  In other words, no "ok" or
#pod "not ok" line is emitted.  It's up to you to use the rest of C<exception> in an
#pod existing test like C<ok>, C<isa_ok>, C<is>, et cetera.  Or you may wish to use
#pod the C<dies_ok> and C<lives_ok> wrappers, which do provide TAP output.
#pod
#pod C<exception> does I<not> alter the stack presented to the called block, meaning
#pod that if the exception returned has a stack trace, it will include some frames
#pod between the code calling C<exception> and the thing throwing the exception.
#pod This is considered a I<feature> because it avoids the occasionally twitchy
#pod C<Sub::Uplevel> mechanism.
#pod
#pod B<Achtung!>  This is not a great idea:
#pod
#pod   sub exception_like(&$;$) {
#pod       my ($code, $pattern, $name) = @_;
#pod       like( &exception($code), $pattern, $name );
#pod   }
#pod
#pod   exception_like(sub { }, qr/foo/, 'foo appears in the exception');
#pod
#pod If the code in the C<...> is going to throw a stack trace with the arguments to
#pod each subroutine in its call stack (for example via C<Carp::confess>,
#pod the test name, "foo appears in the exception" will itself be matched by the
#pod regex.  Instead, write this:
#pod
#pod   like( exception { ... }, qr/foo/, 'foo appears in the exception' );
#pod
#pod If you really want a test function that passes the test name, wrap the
#pod arguments in an array reference to hide the literal text from a stack trace:
#pod
#pod   sub exception_like(&$) {
#pod       my ($code, $args) = @_;
#pod       my ($pattern, $name) = @$args;
#pod       like( &exception($code), $pattern, $name );
#pod   }
#pod
#pod   exception_like(sub { }, [ qr/foo/, 'foo appears in the exception' ] );
#pod
#pod To aid in avoiding the problem where the pattern is seen in the exception
#pod because of the call stack, C<$Carp::MaxArgNums> is locally set to -1 when the
#pod code block is called.  If you really don't want that, set it back to whatever
#pod value you like at the beginning of the code block.  Obviously, this solution
#pod doens't affect all possible ways that args of subroutines in the call stack
#pod might taint the test.  The intention here is to prevent some false passes from
#pod people who didn't read the documentation.  Your punishment for reading it is
#pod that you must consider whether to do anything about this.
#pod
#pod B<Achtung>: One final bad idea:
#pod
#pod   isnt( exception { ... }, undef, "my code died!");
#pod
#pod It's true that this tests that your code died, but you should really test that
#pod it died I<for the right reason>.  For example, if you make an unrelated mistake
#pod in the block, like using the wrong dereference, your test will pass even though
#pod the code to be tested isn't really run at all.  If you're expecting an
#pod inspectable exception with an identifier or class, test that.  If you're
#pod expecting a string exception, consider using C<like>.
#pod
#pod =cut

our ($REAL_TBL, $REAL_CALCULATED_TBL) = (1, 1);

sub exception (&) {
  my $code = shift;

  return try {
    my $incremented = defined $Test::Builder::Level
                    ? $Test::Builder::Level - $REAL_CALCULATED_TBL
                    : 0;
    local $Test::Builder::Level = $REAL_CALCULATED_TBL;
    if ($incremented) {
        # each call to exception adds 5 stack frames
        $Test::Builder::Level += 5;
        for my $i (1..$incremented) {
            # -2 because we want to see it from the perspective of the call to
            # is() within the call to $code->()
            my $caller = caller($Test::Builder::Level - 2);
            if ($caller eq __PACKAGE__) {
                # each call to exception adds 5 stack frames
                $Test::Builder::Level = $Test::Builder::Level + 5;
            }
            else {
                $Test::Builder::Level = $Test::Builder::Level + 1;
            }
        }
    }

    local $REAL_CALCULATED_TBL = $Test::Builder::Level;
    local $Carp::MaxArgNums = -1;
    $code->();
    return undef;
  } catch {
    return $_ if $_;

    my $problem = defined $_ ? 'false' : 'undef';
    Carp::confess("$problem exception caught by Test::Fatal::exception");
  };
}

#pod =func success
#pod
#pod   try {
#pod     should_live;
#pod   } catch {
#pod     fail("boo, we died");
#pod   } success {
#pod     pass("hooray, we lived");
#pod   };
#pod
#pod C<success>, exported only by request, is a L<Try::Tiny> helper with semantics
#pod identical to L<C<finally>|Try::Tiny/finally>, but the body of the block will
#pod only be run if the C<try> block ran without error.
#pod
#pod Although almost any needed exception tests can be performed with C<exception>,
#pod success blocks may sometimes help organize complex testing.
#pod
#pod =cut

sub success (&;@) {
  my $code = shift;
  return finally( sub {
    return if @_; # <-- only run on success
    $code->();
  }, @_ );
}

#pod =func dies_ok
#pod
#pod =func lives_ok
#pod
#pod Exported only by request, these two functions run a given block of code, and
#pod provide TAP output indicating if it did, or did not throw an exception.
#pod These provide an easy upgrade path for replacing existing unit tests based on
#pod C<Test::Exception>.
#pod
#pod RJBS does not suggest using this except as a convenience while porting tests to
#pod use Test::Fatal's C<exception> routine.
#pod
#pod   use Test::More tests => 2;
#pod   use Test::Fatal qw(dies_ok lives_ok);
#pod
#pod   dies_ok { die "I failed" } 'code that fails';
#pod
#pod   lives_ok { return "I'm still alive" } 'code that does not fail';
#pod
#pod =cut

my $Tester;

# Signature should match that of Test::Exception
sub dies_ok (&;$) {
  my $code = shift;
  my $name = shift;

  require Test::Builder;
  $Tester ||= Test::Builder->new;

  my $tap_pos = $Tester->current_test;

  my $exception = exception( \&$code );

  $name ||= $tap_pos != $Tester->current_test
        ? "...and code should throw an exception"
        : "code should throw an exception";

  my $ok = $Tester->ok( $exception, $name );
  $ok or $Tester->diag( "expected an exception but none was raised" );
  return $ok;
}

sub lives_ok (&;$) {
  my $code = shift;
  my $name = shift;

  require Test::Builder;
  $Tester ||= Test::Builder->new;

  my $tap_pos = $Tester->current_test;

  my $exception = exception( \&$code );

  $name ||= $tap_pos != $Tester->current_test
        ? "...and code should not throw an exception"
        : "code should not throw an exception";

  my $ok = $Tester->ok( ! $exception, $name );
  $ok or $Tester->diag( "expected return but an exception was raised" );
  return $ok;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Fatal - incredibly simple helpers for testing code with exceptions

=head1 VERSION

version 0.017

=head1 SYNOPSIS

  use Test::More;
  use Test::Fatal;

  use System::Under::Test qw(might_die);

  is(
    exception { might_die; },
    undef,
    "the code lived",
  );

  like(
    exception { might_die; },
    qr/turns out it died/,
    "the code died as expected",
  );

  isa_ok(
    exception { might_die; },
    'Exception::Whatever',
    'the thrown exception',
  );

=head1 DESCRIPTION

Test::Fatal is an alternative to the popular L<Test::Exception>.  It does much
less, but should allow greater flexibility in testing exception-throwing code
with about the same amount of typing.

It exports one routine by default: C<exception>.

B<Achtung!>  C<exception> intentionally does not manipulate the call stack.
User-written test functions that use C<exception> must be careful to avoid
false positives if exceptions use stack traces that show arguments.  For a more
magical approach involving globally overriding C<caller>, see
L<Test::Exception>.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 FUNCTIONS

=head2 exception

  my $exception = exception { ... };

C<exception> takes a bare block of code and returns the exception thrown by
that block.  If no exception was thrown, it returns undef.

B<Achtung!>  If the block results in a I<false> exception, such as 0 or the
empty string, Test::Fatal itself will die.  Since either of these cases
indicates a serious problem with the system under testing, this behavior is
considered a I<feature>.  If you must test for these conditions, you should use
L<Try::Tiny>'s try/catch mechanism.  (Try::Tiny is the underlying exception
handling system of Test::Fatal.)

Note that there is no TAP assert being performed.  In other words, no "ok" or
"not ok" line is emitted.  It's up to you to use the rest of C<exception> in an
existing test like C<ok>, C<isa_ok>, C<is>, et cetera.  Or you may wish to use
the C<dies_ok> and C<lives_ok> wrappers, which do provide TAP output.

C<exception> does I<not> alter the stack presented to the called block, meaning
that if the exception returned has a stack trace, it will include some frames
between the code calling C<exception> and the thing throwing the exception.
This is considered a I<feature> because it avoids the occasionally twitchy
C<Sub::Uplevel> mechanism.

B<Achtung!>  This is not a great idea:

  sub exception_like(&$;$) {
      my ($code, $pattern, $name) = @_;
      like( &exception($code), $pattern, $name );
  }

  exception_like(sub { }, qr/foo/, 'foo appears in the exception');

If the code in the C<...> is going to throw a stack trace with the arguments to
each subroutine in its call stack (for example via C<Carp::confess>,
the test name, "foo appears in the exception" will itself be matched by the
regex.  Instead, write this:

  like( exception { ... }, qr/foo/, 'foo appears in the exception' );

If you really want a test function that passes the test name, wrap the
arguments in an array reference to hide the literal text from a stack trace:

  sub exception_like(&$) {
      my ($code, $args) = @_;
      my ($pattern, $name) = @$args;
      like( &exception($code), $pattern, $name );
  }

  exception_like(sub { }, [ qr/foo/, 'foo appears in the exception' ] );

To aid in avoiding the problem where the pattern is seen in the exception
because of the call stack, C<$Carp::MaxArgNums> is locally set to -1 when the
code block is called.  If you really don't want that, set it back to whatever
value you like at the beginning of the code block.  Obviously, this solution
doens't affect all possible ways that args of subroutines in the call stack
might taint the test.  The intention here is to prevent some false passes from
people who didn't read the documentation.  Your punishment for reading it is
that you must consider whether to do anything about this.

B<Achtung>: One final bad idea:

  isnt( exception { ... }, undef, "my code died!");

It's true that this tests that your code died, but you should really test that
it died I<for the right reason>.  For example, if you make an unrelated mistake
in the block, like using the wrong dereference, your test will pass even though
the code to be tested isn't really run at all.  If you're expecting an
inspectable exception with an identifier or class, test that.  If you're
expecting a string exception, consider using C<like>.

=head2 success

  try {
    should_live;
  } catch {
    fail("boo, we died");
  } success {
    pass("hooray, we lived");
  };

C<success>, exported only by request, is a L<Try::Tiny> helper with semantics
identical to L<C<finally>|Try::Tiny/finally>, but the body of the block will
only be run if the C<try> block ran without error.

Although almost any needed exception tests can be performed with C<exception>,
success blocks may sometimes help organize complex testing.

=head2 dies_ok

=head2 lives_ok

Exported only by request, these two functions run a given block of code, and
provide TAP output indicating if it did, or did not throw an exception.
These provide an easy upgrade path for replacing existing unit tests based on
C<Test::Exception>.

RJBS does not suggest using this except as a convenience while porting tests to
use Test::Fatal's C<exception> routine.

  use Test::More tests => 2;
  use Test::Fatal qw(dies_ok lives_ok);

  dies_ok { die "I failed" } 'code that fails';

  lives_ok { return "I'm still alive" } 'code that does not fail';

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 CONTRIBUTORS

=for stopwords David Golden Graham Knop Jesse Luehrs Joel Bernstein Karen Etheridge Ricardo Signes

=over 4

=item *

David Golden <dagolden@cpan.org>

=item *

Graham Knop <haarg@haarg.org>

=item *

Jesse Luehrs <doy@tozt.net>

=item *

Joel Bernstein <joel@fysh.org>

=item *

Karen Etheridge <ether@cpan.org>

=item *

Ricardo Signes <rjbs@semiotic.systems>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
