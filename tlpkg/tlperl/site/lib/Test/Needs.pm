package Test::Needs;
use strict;
use warnings;
no warnings 'once';
our $VERSION = '0.002005';
$VERSION =~ tr/_//d;

BEGIN {
  *_WORK_AROUND_HINT_LEAKAGE
    = "$]" < 5.011 && !("$]" >= 5.009004 && "$]" < 5.010001)
    ? sub(){1} : sub(){0};
  *_WORK_AROUND_BROKEN_MODULE_STATE
    = "$]" < 5.009
    ? sub(){1} : sub(){0};
}

sub _try_require {
  local %^H
    if _WORK_AROUND_HINT_LEAKAGE;
  my ($module) = @_;
  (my $file = "$module.pm") =~ s{::|'}{/}g;
  my $err;
  {
    local $@;
    eval { require $file }
      or $err = $@;
  }
  if (defined $err) {
    delete $INC{$file}
      if _WORK_AROUND_BROKEN_MODULE_STATE;
    die $err
      unless $err =~ /\ACan't locate \Q$file\E/;
    return !1;
  }
  !0;
}

sub _find_missing {
  my @bad = map {
    my ($module, $version) = @$_;
    if ($module eq 'perl') {
      $version
        = !$version ? 0
        : $version =~ /^[0-9]+\.[0-9]+$/ ? sprintf('%.6f', $version)
        : $version =~ /^v?([0-9]+(?:\.[0-9]+)+)$/ ? do {
          my @p = split /\./, $1;
          push @p, 0
            until @p >= 3;
          sprintf '%d.%03d%03d', @p;
        }
        : $version =~ /^\x05..?$/s ? do {
          my @p = map ord, split //, $version;
          push @p, 0
            until @p >= 3;
          sprintf '%d.%03d%03d', @p;
        }
        : do {
          use warnings FATAL => 'numeric';
          no warnings 'void';
          eval { 0 + $version; 1 } ? $version
            : die sprintf qq{version "%s" for perl does not look like a number at %s line %s.\n},
              $version, (caller( 1 + ($Test::Builder::Level||0) ))[1,2];
        };
      if ("$]" < $version) {
        sprintf "perl %s (have %.6f)", $version, $];
      }
      else {
        ();
      }
    }
    elsif ($module =~ /^\d|[^\w:]|:::|[^:]:[^:]|^:|:$/) {
      die sprintf qq{"%s" does not look like a module name at %s line %s.\n},
        $module, (caller( 1 + ($Test::Builder::Level||0) ))[1,2];
      die
    }
    elsif (_try_require($module)) {
      local $@;
      if (defined $version && !eval { $module->VERSION($version); 1 }) {
        "$module $version (have ".$module->VERSION.')';
      }
      else {
        ();
      }
    }
    else {
      $version ? "$module $version" : $module;
    }
  }
  map {
    if (ref eq 'HASH') {
      my $arg = $_;
      map [ $_ => $arg->{$_} ], sort keys %$arg;
    }
    elsif (ref eq 'ARRAY') {
      my $arg = $_;
      map [ @{$arg}[$_*2,$_*2+1] ], 0 .. int($#$arg / 2);
    }
    else {
      [ $_ => undef ];
    }
  } @_;
  @bad ? "Need " . join(', ', @bad) : undef;
}

sub import {
  my $class = shift;
  my $target = caller;
  if (@_) {
    local $Test::Builder::Level = ($Test::Builder::Level||0) + 1;
    test_needs(@_);
  }
  no strict 'refs';
  *{"${target}::test_needs"} = \&test_needs;
}

sub test_needs {
  my $missing = _find_missing(@_);
  local $Test::Builder::Level = ($Test::Builder::Level||0) + 1;
  _fail_or_skip($missing, $ENV{RELEASE_TESTING})
    if $missing;
}

sub _skip { _fail_or_skip($_[0], 0) }
sub _fail { _fail_or_skip($_[0], 1) }

sub _fail_or_skip {
  my ($message, $fail) = @_;
  if ($INC{'Test2/API.pm'}) {
    my $ctx = Test2::API::context();
    my $hub = $ctx->hub;
    if ($fail) {
      $ctx->ok(0, "Test::Needs modules available", [$message]);
    }
    else {
      my $plan = $hub->plan;
      my $tests = $hub->count;
      if ($plan || $tests) {
        my $skips
          = $plan && $plan ne 'NO PLAN' ? $plan - $tests : 1;
        $ctx->skip("Test::Needs modules not available") for 1 .. $skips;
        $ctx->note($message);
      }
      else {
        $ctx->plan(0, 'SKIP', $message);
      }
    }
    $ctx->done_testing;
    $ctx->release if $Test2::API::VERSION < 1.302053;
    $ctx->send_event('+'._t2_terminate_event());
  }
  elsif ($INC{'Test/Builder.pm'}) {
    my $tb = Test::Builder->new;
    my $has_plan = Test::Builder->can('has_plan') ? 'has_plan'
      : sub { $_[0]->expected_tests || eval { $_[0]->current_test($_[0]->current_test); 'no_plan' } };
    if ($fail) {
      $tb->plan(tests => 1)
        unless $tb->$has_plan;
      $tb->ok(0, "Test::Needs modules available");
      $tb->diag($message);
    }
    else {
      my $plan = $tb->$has_plan;
      my $tests = $tb->current_test;
      if ($plan || $tests) {
        my $skips
          = $plan && $plan ne 'no_plan' ? $plan - $tests : 1;
        $tb->skip("Test::Needs modules not available")
          for 1 .. $skips;
        Test::Builer->can('note') ? $tb->note($message) : print "# $message\n";
      }
      else {
        $tb->skip_all($message);
      }
    }
    $tb->done_testing
      if Test::Builder->can('done_testing');
    die bless {} => 'Test::Builder::Exception'
      if Test::Builder->can('parent') && $tb->parent;
  }
  else {
    if ($fail) {
      print "1..1\n";
      print "not ok 1 - Test::Needs modules available\n";
      print STDERR "# $message\n";
      exit 1;
    }
    else {
      print "1..0 # SKIP $message\n";
    }
  }
  exit 0;
}

my $terminate_event;
sub _t2_terminate_event () {
  local $@;
  $terminate_event ||= eval q{
    $INC{'Test/Needs/Event/Terminate.pm'} = $INC{'Test/Needs.pm'};
    package # hide
      Test::Needs::Event::Terminate;
    use Test2::Event ();
    our @ISA = qw(Test2::Event);
    sub no_display { 1 }
    sub terminate { 0 }
    __PACKAGE__;
  } or die "$@";
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Test::Needs - Skip tests when modules not available

=head1 SYNOPSIS

  # need one module
  use Test::Needs 'Some::Module';

  # need multiple modules
  use Test::Needs 'Some::Module', 'Some::Other::Module';

  # need a given version of a module
  use Test::Needs {
    'Some::Module' => '1.005',
  };

  # check later
  use Test::Needs;
  test_needs 'Some::Module';

  # skips remainder of subtest
  use Test::More;
  use Test::Needs;
  subtest 'my subtest' => sub {
    test_needs 'Some::Module';
    ...
  };

  # check perl version
  use Test::Needs { perl => 5.020 };

=head1 DESCRIPTION

Skip test scripts if modules are not available.  The requested modules will be
loaded, and optionally have their versions checked.  If the module is missing,
the test script will be skipped.  Modules that are found but fail to compile
will exit with an error rather than skip.

If used in a subtest, the remainder of the subtest will be skipped.

Skipping will work even if some tests have already been run, or if a plan has
been declared.

Versions are checked via a C<< $module->VERSION($wanted_version) >> call.
Versions must be provided in a format that will be accepted.  No extra
processing is done on them.

If C<perl> is used as a module, the version is checked against the running perl
version (L<$]|perlvar/$]>).  The version can be specified as a number,
dotted-decimal string, v-string, or version object.

If the C<RELEASE_TESTING> environment variable is set, the tests will fail
rather than skip.  Subtests will be aborted, but the test script will continue
running after that point.

=head1 EXPORTS

=head2 test_needs

Has the same interface as when using Test::Needs in a C<use>.

=head1 SEE ALSO

=over 4

=item L<Test::Requires>

A similar module, with some important differences.  L<Test::Requires> will act
as a C<use> statement (despite its name), calling the import sub.  Under
C<RELEASE_TESTING>, it will BAIL_OUT if a module fails to load rather than
using a normal test fail.  It also doesn't distinguish between missing modules
and broken modules.

=item L<Test2::Require::Module>

Part of the L<Test2> ecosystem.  Only supports running as a C<use> command to
skip an entire plan.

=back

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head1 CONTRIBUTORS

None so far.

=head1 COPYRIGHT

Copyright (c) 2016 the Test::Needs L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut
