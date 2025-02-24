use v5.10.0;
use strict;
use warnings;

package Test::Deep 1.204;
# ABSTRACT: Extremely flexible deep comparison

use Carp qw( confess );

use Test::Deep::Cache;
use Test::Deep::Stack;
use Test::Deep::RegexpVersion;

require overload;
use Scalar::Util;

my $Test;
unless (defined $Test::Deep::NoTest::NoTest)
{
# for people who want eq_deeply but not Test::Builder
  require Test::Builder;
  $Test = Test::Builder->new;
}

our ($Stack, %Compared, $CompareCache, %WrapCache, $Shallow);

require Exporter;
our @ISA = qw( Exporter );

our $Snobby = 1; # should we compare classes?
our $Expects = 0; # are we comparing got vs expect or expect vs expect

our $LeafWrapper; # to wrap simple values in a test; if not set, shallow()

our $DNE = \"";
our $DNE_ADDR = Scalar::Util::refaddr($DNE);

# if no sub name is supplied then we use the package name in lower case
my @constructors = (
  All               => "",
  Any               => "",
  Array             => "",
  ArrayEach         => "array_each",
  ArrayElementsOnly => "",
  ArrayLength       => "",
  ArrayLengthOnly   => "",
  Blessed           => "",
  Boolean           => "bool",
  Code              => "",
  Hash              => "",
  HashEach          => "hash_each",
  HashKeys          => "",
  HashKeysOnly      => "",
  Ignore            => "",
  Isa               => "Isa",
  ListMethods       => "",
  Methods           => "",
  None              => "",
  Number            => "num",
  Obj               => "obj_isa",
  RefType           => "",
  Regexp            => "re",
  RegexpMatches     => "",
  RegexpOnly        => "",
  RegexpRef         => "",
  RegexpRefOnly     => "",
  ScalarRef         => "scalref",
  ScalarRefOnly     => "",
  Shallow           => "",
  String            => "str",
);

my @CONSTRUCTORS_FROM_CLASSES;

while (my ($pkg, $name) = splice @constructors, 0, 2)
{
  $name = lc($pkg) unless $name;
  my $full_pkg = "Test::Deep::$pkg";
  my $file = "$full_pkg.pm";
  $file =~ s#::#/#g;
  my $sub = sub {
    # We might be in the middle of testing one of the globals that require()
    # overwrites. To simplify test authorship, we'll preserve any existing
    # value.
    {
      local $@;
      local $!;
      local $^E;
      require $file;
    }

    return $full_pkg->new(@_);
  };
  {
    no strict 'refs';
    *{$name} = $sub;
  }

  push @CONSTRUCTORS_FROM_CLASSES, $name;
}

{
  our @EXPORT_OK = qw(
    descend render_stack cmp_details deep_diag
    true false
  );

  our %EXPORT_TAGS;
  $EXPORT_TAGS{preload} = [];
  $EXPORT_TAGS{v0} = [
    qw(
      Isa
      blessed
      obj_isa

      all any array array_each arrayelementsonly arraylength arraylengthonly
      bag bool cmp_bag cmp_deeply cmp_methods cmp_set code eq_deeply
      hash hash_each hashkeys hashkeysonly ignore isa listmethods methods
      noclass none noneof num re reftype regexpmatches regexponly regexpref
      regexprefonly scalarrefonly scalref set shallow str subbagof subhashof
      subsetof superbagof superhashof supersetof useclass
    )
  ];

  $EXPORT_TAGS{v1} = [
    qw(
      obj_isa

      all any array array_each arrayelementsonly arraylength arraylengthonly
      bag bool cmp_bag cmp_deeply cmp_methods cmp_set code eq_deeply
      hash hash_each hashkeys hashkeysonly ignore listmethods methods
      noclass none noneof num re reftype regexpmatches regexponly regexpref
      regexprefonly scalarrefonly scalref set shallow str subbagof subhashof
      subsetof superbagof superhashof supersetof useclass
    )
  ];

  our @EXPORT = @{ $EXPORT_TAGS{ v0 } };

  $EXPORT_TAGS{all} = [ @EXPORT, @EXPORT_OK ];
}

sub import {
  my $self = shift;

  my $from_notest = grep {$_ eq '_notest'} @_;
  if ($from_notest) {
      @_ = grep {$_ ne '_notest'} @_;
  } else {
    require Test::Builder;
    $Test = Test::Builder->new;
  }

  my @sans_preload = grep {; $_ ne ':preload' } @_;
  if (@_ != @sans_preload) {
    require Test::Deep::All;
    require Test::Deep::Any;
    require Test::Deep::Array;
    require Test::Deep::ArrayEach;
    require Test::Deep::ArrayElementsOnly;
    require Test::Deep::ArrayLength;
    require Test::Deep::ArrayLengthOnly;
    require Test::Deep::Blessed;
    require Test::Deep::Boolean;
    require Test::Deep::Cache::Simple;
    require Test::Deep::Cache;
    require Test::Deep::Class;
    require Test::Deep::Cmp;
    require Test::Deep::Code;
    require Test::Deep::Hash;
    require Test::Deep::HashEach;
    require Test::Deep::HashElements;
    require Test::Deep::HashKeys;
    require Test::Deep::HashKeysOnly;
    require Test::Deep::Ignore;
    require Test::Deep::Isa;
    require Test::Deep::ListMethods;
    require Test::Deep::Methods;
    require Test::Deep::MM;
    require Test::Deep::None;
    require Test::Deep::Number;
    require Test::Deep::Obj;
    require Test::Deep::Ref;
    require Test::Deep::RefType;
    require Test::Deep::Regexp;
    require Test::Deep::RegexpMatches;
    require Test::Deep::RegexpOnly;
    require Test::Deep::RegexpRef;
    require Test::Deep::RegexpRefOnly;
    require Test::Deep::RegexpVersion;
    require Test::Deep::ScalarRef;
    require Test::Deep::ScalarRefOnly;
    require Test::Deep::Set;
    require Test::Deep::Shallow;
    require Test::Deep::Stack;
    require Test::Deep::String;
  }

  $self->export_to_level(1, $self, @_);
}

# this is ugly, I should never have exported a sub called isa now I
# have to try figure out if the recipient wanted my isa or if a class
# imported us and UNIVERSAL::isa is being called on that class.
# Luckily our isa always expects 1 argument and U::isa always expects
# 2, so we can figure out (assuming the caller is not buggy).
sub isa
{
  if (@_ == 1)
  {
    goto &Isa;
  }
  else
  {
    goto &UNIVERSAL::isa;
  }
}

sub cmp_deeply
{
  my ($d1, $d2, $name) = @_;

  my ($ok, $stack) = cmp_details($d1, $d2);

  if (not $Test->ok($ok, $name))
  {
    my $diag = deep_diag($stack);
    $Test->diag($diag);
  }

  return $ok;
}

sub cmp_details
{
  my ($d1, $d2) = @_;

  local $Stack = Test::Deep::Stack->new;
  local $CompareCache = Test::Deep::Cache->new;
  local %WrapCache;

  my $ok = descend($d1, $d2);

  return ($ok, $Stack);
}

sub eq_deeply
{
  my ($d1, $d2) = @_;

  my ($ok) = cmp_details($d1, $d2);

  return $ok
}

sub eq_deeply_cache
{
  # this is like cross between eq_deeply and descend(). It doesn't start
  # with a new $CompareCache but if the comparison fails it will leave
  # $CompareCache as if nothing happened. However, if the comparison
  # succeeds then $CompareCache retains all the new information

  # this allows Set and Bag to handle circular refs

  my ($d1, $d2, $name) = @_;

  local $Stack = Test::Deep::Stack->new;
  $CompareCache->local;

  my $ok = descend($d1, $d2);

  $CompareCache->finish($ok);

  return $ok;
}

sub deep_diag
{
  my $stack = shift;
  # ick! incArrow and other things expect the stack has to be visible
  # in a well known place . TODO clean this up
  local $Stack = $stack;

  my $where = render_stack('$data', $stack);

  confess "No stack to diagnose" unless $stack;
  my $last = $stack->getLast;

  my $diag;
  my $message;
  my $got;
  my $expected;

  my $exp = $last->{exp};
  if (Scalar::Util::blessed($exp))
  {
    if ($exp->can("diagnostics"))
    {
      $diag = $exp->diagnostics($where, $last);
      $diag =~ s/\n+$/\n/;
    }
    else
    {
      if ($exp->can("diag_message"))
      {
        $message = $exp->diag_message($where);
      }
    }
  }

  if (not defined $diag)
  {
    $got //= $exp->renderGot($last->{got});
    $expected //= $exp->renderExp;
    $message //= "Compared $where";

    $diag = <<EOM
$message
   got : $got
expect : $expected
EOM
  }

  return $diag;
}

sub render_val
{
  my $val = shift;

  my $rendered;
  if (defined $val)
  {
     $rendered = ref($val) ?
       (Scalar::Util::refaddr($val) eq $DNE_ADDR ?
         "Does not exist" :
        overload::StrVal($val)
      ) :
      qq('$val');
  }
  else
  {
    $rendered = "undef";
  }

  return $rendered;
}

sub descend
{
  my ($d1, $d2) = @_;

  if (!ref $d1 and !ref $d2)
  {
    # Shortcut comparison for the non-reference case.
    if (defined $d1)
    {
      return 1 if defined $d2 and $d1 eq $d2;
    }
    else
    {
      return 1 if !defined $d2;
    }
  }

  if (! $Expects and Scalar::Util::blessed($d1) and $d1->isa("Test::Deep::Cmp"))
  {
    my $where = $Stack->render('$data');
    confess "Found a special comparison in $where\nYou can only use specials in the expects structure";
  }

  if (ref $d1 and ref $d2)
  {
    # this check is only done when we're comparing 2 expecteds against each
    # other

    if ($Expects and Scalar::Util::blessed($d1) and $d1->isa("Test::Deep::Cmp"))
    {
      # check they are the same class
      return 0 unless Test::Deep::blessed(Scalar::Util::blessed($d2))->descend($d1);
      if ($d1->can("compare"))
      {
        return $d1->compare($d2);
      }
    }

    my $s1 = Scalar::Util::refaddr($d1);
    my $s2 = Scalar::Util::refaddr($d2);

    if ($s1 eq $s2)
    {
      return 1;
    }
    if ($CompareCache->cmp($d1, $d2))
    {
      # we've tried comparing these already so either they turned out to
      # be the same or we must be in a loop and we have to assume they're
      # the same

      return 1;
    }
    else
    {
      $CompareCache->add($d1, $d2)
    }
  }

  $d2 = wrap($d2);

  $Stack->push({exp => $d2, got => $d1});

  if (ref($d1) and (Scalar::Util::refaddr($d1) == $DNE_ADDR))
  {
    # whatever it was supposed to be, it didn't exist and so it's an
    # automatic fail
    return 0;
  }

  if ($d2->descend($d1))
  {
#    print "d1 = $d1, d2 = $d2\nok\n";
    $Stack->pop;

    return 1;
  }
  else
  {
#    print "d1 = $d1, d2 = $d2\nnot ok\n";
    return 0;
  }
}

sub wrap
{
  my $data = shift;

  my $class = Scalar::Util::blessed($data);
  return $data if defined $class and $data->isa("Test::Deep::Cmp");

  if (defined $class and $data->can('as_test_deep_cmp')) {
    my $cmp = $data->as_test_deep_cmp;
    return $cmp if $cmp->isa('Test::Deep::Cmp');
    Carp::confess("object in expected structure provides as_test_deep_cmp but it did not return a Test::Deep::Cmp");
  }

  my $reftype = _td_reftype($data);

  my $cmp;

  if($reftype eq '')
  {
    $cmp = $Test::Deep::LeafWrapper
         ? $Test::Deep::LeafWrapper->($data)
         : shallow($data);
  }
  else
  {
    my $addr = Scalar::Util::refaddr($data);

    return $WrapCache{$addr} if $WrapCache{$addr};

    if($reftype eq 'ARRAY')
    {
      $cmp = array($data);
    }
    elsif($reftype eq 'HASH')
    {
      $cmp = hash($data);
    }
    elsif($reftype eq 'SCALAR' or $reftype eq 'REF')
    {
      $cmp = scalref($data);
    }
    elsif(($reftype eq 'Regexp') or ($reftype eq 'REGEXP'))
    {
      $cmp = regexpref($data);
    }
    else
    {
      $cmp = $Test::Deep::LeafWrapper
           ? $Test::Deep::LeafWrapper->($data)
           : shallow($data);
    }

    $WrapCache{$addr} = $cmp;
  }
  return $cmp;
}

sub _td_reftype
{
  my $val = shift;

  my $reftype = Scalar::Util::reftype($val);
  return '' unless defined $reftype;

  return $reftype unless $Test::Deep::RegexpVersion::OldStyle;

  my $blessed = Scalar::Util::blessed($val);
  return $reftype unless defined $blessed;

  if ($blessed && $blessed eq "Regexp" and $reftype eq "SCALAR")
  {
    $reftype = "Regexp"
  }

  return $reftype;
}

sub render_stack
{
  my ($var, $stack) = @_;

  return $stack->render($var);
}

sub cmp_methods
{
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return cmp_deeply(shift, methods(@{shift()}), shift);
}

sub requireclass
{
  require Test::Deep::Class;

  my $val = shift;

  return Test::Deep::Class->new(1, $val);
}

# docs and export say this is called useclass, doh!

*useclass = \&requireclass;

sub noclass
{
  require Test::Deep::Class;

  my $val = shift;

  return Test::Deep::Class->new(0, $val);
}

sub set
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(1, "", @_);
}

sub supersetof
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(1, "sup", @_);
}

sub subsetof
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(1, "sub", @_);
}

sub noneof
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(1, "none", @_);
}

sub cmp_set
{
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return cmp_deeply(shift, set(@{shift()}), shift);
}

sub bag
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(0, "", @_);
}

sub superbagof
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(0, "sup", @_);
}

sub subbagof
{
  require Test::Deep::Set;

  return Test::Deep::Set->new(0, "sub", @_);
}

sub cmp_bag
{
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  my $ref = ref($_[1]) || "";
  confess "Argument 2 to cmp_bag is not an ARRAY ref (".render_val($_[1]).")"
    unless $ref eq "ARRAY";
  return cmp_deeply(shift, bag(@{shift()}), shift);
}

sub superhashof
{
  require Test::Deep::Hash;

  my $val = shift;

  return Test::Deep::SuperHash->new($val);
}

sub subhashof
{
  require Test::Deep::Hash;

  my $val = shift;

  return Test::Deep::SubHash->new($val);
}

sub true
{
  bool(1);
}

sub false
{
  bool(0);
}

sub builder
{
  if (@_)
  {
    $Test = shift;
  }
  return $Test;
}

1;

=pod

=encoding UTF-8

=head1 NAME

Test::Deep - Extremely flexible deep comparison

=head1 VERSION

version 1.204

=head1 SYNOPSIS

  use Test::More tests => $Num_Tests;
  use Test::Deep;

  cmp_deeply(
    $actual_horrible_nested_data_structure,
    $expected_horrible_nested_data_structure,
    "got the right horrible nested data structure"
  );

  cmp_deeply(
    $object,
    methods(name => "John", phone => "55378008"),
    "object methods ok"
  );

  cmp_deeply(
    \@array,
    [$hash1, $hash2, ignore()],
    "first 2 elements are as expected, ignoring 3"
  );

  cmp_deeply(
    $object,
    noclass({value => 5}),
    "object looks ok, not checking its class"
  );

  cmp_deeply(
    \@result,
    bag('a', 'b', {key => [1, 2]}),
    "array has the 3 things we wanted in some order"
  );

=head1 DESCRIPTION

If you don't know anything about automated testing in Perl then you should
probably read about L<Test::Simple> and L<Test::More> before preceding.
Test::Deep uses the L<Test::Builder> framework.

Test::Deep gives you very flexible ways to check that the result you got is
the result you were expecting. At its simplest it compares two structures
by going through each level, ensuring that the values match, that arrays and
hashes have the same elements and that references are blessed into the
correct class. It also handles circular data structures without getting
caught in an infinite loop.

Where it becomes more interesting is in allowing you to do something besides
simple exact comparisons. With strings, the C<eq> operator checks that 2
strings are exactly equal but sometimes that's not what you want. When you
don't know exactly what the string should be but you do know some things
about how it should look, C<eq> is no good and you must use pattern matching
instead. Test::Deep provides pattern matching for complex data structures

Test::Deep has B<I<a lot>> of exports.  See L</EXPORTS> below.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 EXAMPLES

How Test::Deep works is much easier to understand by seeing some examples.

=head2 Without Test::Deep

Say you want to test a function which returns a string. You know that your
string should be a 7 digit number beginning with 0, C<eq> is no good in this
situation, you need a regular expression. So you could use Test::More's
C<like()> function:

  like($string, qr/^0[0-9]{6}$/, "number looks good");

Similarly, to check that a string looks like a name, you could do:

  like($string, qr/^(Mr|Mrs|Miss) \w+ \w+$/,
    "got title, first and last name");

Now imagine your function produces a hash with some personal details in it.
You want to make sure that there are 2 keys, Name and Phone and that the
name looks like a name and the phone number looks like a phone number. You
could do:

  $hash = make_person();
  like($hash->{Name}, qr/^(Mr|Mrs|Miss) \w+ \w+$/, "name ok");
  like($hash->{Phone}, qr/^0[0-9]{6}$/, "phone ok");
  is(scalar keys %$hash, 2, "correct number of keys");

But that's not quite right, what if make_person has a serious problem and
didn't even return a hash? We really need to write

  if (ref($hash) eq "HASH")
  {
    like($hash->{Name}, qr/^(Mr|Mrs|Miss) \w+ \w+$/, "name ok");
    like($hash->{Phone}, qr/^0[0-9]{6}$/, "phone ok");
    is(scalar keys %$hash, 2, "correct number of keys");
  }
  else
  {
    fail("person not a hash");
    fail("person not a hash");
    fail("person not a hash"); # need 3 to keep the plan correct
  }

Already this is getting messy, now imagine another entry in the hash, an
array of children's names. This would require

  if (ref($hash) eq "HASH")
  {
    like($hash->{Name}, $name_pat, "name ok");
    like($hash->{Phone}, '/^0d{6}$/', "phone ok");
    my $cn = $hash->{ChildNames};
    if (ref($cn) eq "ARRAY")
    {
      foreach my $child (@$cn)
      {
        like($child, $name_pat);
      }
    }
    else
    {
        fail("child names not an array")
    }
  }
  else
  {
    fail("person not a hash");
  }

This is a horrible mess and because we don't know in advance how many
children's names there will be, we can't make a plan for our test anymore
(actually, we could but it would make things even more complicated).

Test::Deep to the rescue.

=head2 With Test::Deep

  my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
  cmp_deeply(
    $person,
    {
      Name => $name_re,
      Phone => re('^0d{6}$'),
      ChildNames => array_each($name_re)
    },
    "person ok"
  );

This will do everything that the messy code above does and it will give a
sensible message telling you exactly what went wrong if it finds a part of
$person that doesn't match the pattern. C<re()> and C<array_each()> are
special function imported from Test::Deep. They create a marker that tells
Test::Deep that something different is happening here. Instead of just doing
a simple comparison and checking are two things exactly equal, it should do
something else.

If a person was asked to check that 2 structures are equal, they could print
them both out and compare them line by line. The markers above are similar
to writing a note in red pen on one of the printouts telling the person that
for this piece of the structure, they should stop doing simple line by line
comparison and do something else.

C<re($regex)> means that Test::Deep should check that the current piece of
data matches the regex in C<$regex>. C<array_each($struct)> means that
Test::Deep should expect the current piece of data to be an array and it
should check that every element of that array matches C<$struct>.
In this case, every element of C<< $person->{ChildNames} >> should look like a
name. If say the 3rd one didn't you would get an error message something
like

  Using Regexp on $data->{ChildNames}[3]
     got    : 'Queen John Paul Sartre'
     expect : /^(Mr|Mrs|Miss) \w+ \w+$/

There are lots of other special comparisons available, see
L<SPECIAL COMPARISONS PROVIDED> below for the full list.

=head2 Reusing structures

Test::Deep is good for reusing test structures so you can do this

  my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
  my $person_cmp = {
    Name => $name_re,
    Phone => re('^0d{6}$'),
    ChildNames => array_each($name_re)
  };

  cmp_deeply($person1, $person_cmp, "person ok");
  cmp_deeply($person2, $person_cmp, "person ok");
  cmp_deeply($person3, $person_cmp, "person ok");

You can even put $person_cmp in a module and let other people use it when
they are writing test scripts for modules that use your modules.

To make things a little more difficult, lets change the person data
structure so that instead of a list of ChildNames, it contains a list of
hashes, one for each child. So in fact our person structure will contain
other person structures which may contain other person structures and so on.
This is easy to handle with Test::Deep because Test::Deep structures can
include themselves. Simply do

  my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
  my $person_cmp = {
    Name => $name_re,
    Phone => re('^0d{6}$'),
    # note no mention of Children here
  };

  $person_cmp->{Children} = array_each($person_cmp);

  cmp_deeply($person, $person_cmp, "person ok");

This will now check that $person->{Children} is an array and that every
element of that array also matches C<$person_cmp>, this includes checking
that its children also match the same pattern and so on.

=head2 Circular data structures

A circular data structure is one which loops back on itself, you can make
one easily by doing

  my @b;
  my @a = (1, 2, 3, \@b);
  push(@b, \@a);

now C<@a> contains a reference to be C<@b> and C<@b> contains a reference to
C<@a>. This causes problems if you have a program that wants to look inside
C<@a> and keep looking deeper and deeper at every level, it could get caught
in an infinite loop looking into C<@a> then C<@b> then C<@a> then C<@b> and
so on.

Test::Deep avoids this problem so we can extend our example further by
saying that a person should also list their parents.

  my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
  my $person_cmp = {
    Name => $name_re,
    Phone => re('^0d{6}$'),
    # note no mention of Children here
  };

  $person_cmp->{Children} = each_array($person_cmp);
  $person_cmp->{Parents} = each_array($person_cmp);

  cmp_deeply($person, $person_cmp, "person ok");

So this will check that for each child C<$child> in C<< $person->{Children} >>
that the C<< $child->{Parents} >> matches C<$person_cmp> however it is smart
enough not to get caught in an infinite loop where it keeps bouncing between
the same Parent and Child.

=head1 TERMINOLOGY

C<cmp_deeply($got, $expected, $name)> takes 3 arguments. C<$got> is the
structure that you are checking, you must not include any special
comparisons in this structure or you will get a fatal error. C<$expected>
describes what Test::Deep will be looking for in $got. You can put special
comparisons in $expected if you want to.

As Test::Deep descends through the 2 structures, it compares them one piece
at a time, so at any point in the process, Test::Deep is thinking about 2
things - the current value from C<$got> and the current value from
C<$expected>. In the documentation, I call them C<$got_v> and C<exp_v>
respectively.

=head1 COMPARISON FUNCTIONS

=head3 cmp_deeply

  my $ok = cmp_deeply($got, $expected, $name)

C<$got> is the result to be checked. C<$expected> is the structure against
which C<$got> will be check. C<$name> is the test name.

This is the main comparison function, the others are just wrappers around
this.  C<$got> and C<$expected> are compared recursively.  Each value in
C<$expected> defines what's expected at the corresponding location in C<$got>.
Simple scalars are compared with C<eq>.  References to structures like hashes
and arrays are compared recursively.

Items in C<$expected>, though, can also represent complex tests that check for
numbers in a given range, hashes with at least a certain set of keys, a string
matching a regex, or many other things.

See L</WHAT ARE SPECIAL COMPARISONS> for details.

=head3 cmp_bag

  my $ok = cmp_bag(\@got, \@bag, $name)

Is shorthand for cmp_deeply(\@got, bag(@bag), $name)

I<n.b.>: Both arguments must be array refs. If they aren't an exception will be
thrown.

=head3 cmp_set

  my $ok = cmp_set(\@got, \@set, $name)

Is shorthand for cmp_deeply(\@got, set(@set), $name)

=head3 cmp_methods

  my $ok = cmp_methods(\@got, \@methods, $name)

Is shorthand for cmp_deeply(\@got, methods(@methods), $name)

=head3 eq_deeply

  my $ok = eq_deeply($got, $expected)

This is the same as cmp_deeply() except it just returns true or
false. It does not create diagnostics or talk to L<Test::Builder>, but
if you want to use it in a non-testing environment then you should
import it through L<Test::Deep::NoTest>. For example

  use Test::Deep::NoTest;
  print "a equals b" unless eq_deeply($a, $b);

otherwise the L<Test::Builder> framework will be loaded and testing messages
will be output when your program ends.

=head3 cmp_details

  ($ok, $stack) = cmp_details($got, $expected)

This behaves much like eq_deeply, but it additionally allows you to
produce diagnostics in case of failure by passing the value in C<$stack>
to C<deep_diag>.

Do not make assumptions about the structure or content of C<$stack> and
do not use it if C<$ok> contains a true value.

See L</USING TEST::DEEP WITH TEST::BUILDER> for example uses.

=head1 SPECIAL COMPARISONS PROVIDED

In the documentation below, C<$got_v> is used to indicate any given value
within the C<$got> structure.

=head3 ignore

  cmp_deeply( $got, ignore() );

This makes Test::Deep skip tests on C<$got_v>. No matter what value C<$got_v>
has, Test::Deep will think it's correct. This is useful if some part of the
structure you are testing is very complicated and already tested elsewhere,
or if it is unpredictable.

  cmp_deeply(
    $got,
    {
      name    => 'John',
      random  => ignore(),
      address => [ '5 A street', 'a town', 'a country' ],
    }
  );

is the equivalent of checking

  $got->{name} eq 'John';
  exists $got->{random};
  cmp_deeply($got->{address}, ['5 A street', 'a town', 'a country']);

=head3 methods

  cmp_deeply( $got, methods(%hash) );

%hash is a hash of method call => expected value pairs.

This lets you call methods on an object and check the result of each call.
The methods will be called in the order supplied. If you want to pass
arguments to the method you should wrap the method name and arguments in an
array reference.

  cmp_deeply(
    $obj,
    methods(name => "John", ["favourite", "food"] => "taco")
  );

is roughly the equivalent of checking that

  $obj->name eq "John"
  $obj->favourite("food") eq "taco"

The methods will be called in the order you supply them and will be called
in scalar context. If you need to test methods called in list context then
you should use C<listmethods()>.

B<NOTE> Just as in a normal test script, you need to be careful if the
methods you call have side effects like changing the object or other objects
in the structure. Although the order of the methods is fixed, the order of
some other tests is not so if C<$expected> is

  {
    manager => methods(@manager_methods),
    coder => methods(@coder_methods)
  }

there is no way to know which if manager and coder will be tested first. If
the methods you are testing depend on and alter global variables or if
manager and coder are the same object then you may run into problems.

=head3 listmethods

  cmp_deeply( $got, listmethods(%hash) );

C<%hash> is a hash of pairs mapping method names to expected return values.

This is almost identical to methods() except the methods are called in list
context instead of scalar context. This means that the expected return
values supplied must be in array references.

  cmp_deeply(
    $obj,
    listmethods(
      name => [ "John" ],
      ["favourites", "food"] => ["Mapo tofu", "Gongbao chicken"]
    )
  );

is the equivalent of checking that

  cmp_deeply([$obj->name], ["John"]);
  cmp_deeply([$obj->favourites("food")], ["Mapo tofu", "Gongbao chicken"]);

The methods will be called in the order you supply them.

B<NOTE> The same caveats apply as for methods().

=head3 shallow

  cmp_deeply( $got, shallow($thing) );

C<$thing> is a ref.

This prevents Test::Deep from looking inside C<$thing>. It allows you to
check that C<$got_v> and C<$thing> are references to the same variable. So

  my @a = @b = (1, 2, 3);
  cmp_deeply(\@a, \@b);

will pass because C<@a> and C<@b> have the same elements however

  cmp_deeply(\@a, shallow(\@b))

will fail because although C<\@a> and C<\@b> both contain C<1, 2, 3> they are
references to different arrays.

=head3 noclass

  cmp_deeply( $got, noclass($thing) );

C<$thing> is a structure to be compared against.

This makes Test::Deep ignore the class of objects, so it just looks at the
data they contain. Class checking will be turned off until Test::Deep is
finished comparing C<$got_v> against C<$thing>. Once Test::Deep comes out of
C<$thing> it will go back to its previous setting for checking class.

This can be useful when you want to check that objects have been
constructed correctly but you don't want to write lots of
C<bless>es. If C<@people> is an array of Person objects then

  cmp_deeply(\@people, [
    bless {name => 'John', phone => '555-5555'}, "Person",
    bless {name => 'Anne', phone => '444-4444'}, "Person",
  ]);

can be replaced with

  cmp_deeply(\@people, noclass([
    {name => 'John', phone => '555-5555'},
    {name => 'Anne', phone => '444-4444'}
  ]));

However, this is testing so you should also check that the objects are
blessed correctly. You could use a map to bless all those hashes or you
could do a second test like

  cmp_deeply(\@people, array_each(isa("Person"));

=head3 useclass

  cmp_deeply( $got, useclass($thing) );

This turns back on the class comparison while inside a C<noclass()>.

  cmp_deeply(
    $got,
    noclass(
      [
        useclass( $object )
      ]
    )
  )

In this example the class of the array reference in C<$got> is ignored but
the class of C<$object> is checked, as is the class of everything inside
C<$object>.

=head3 re

  cmp_deeply( $got, re($regexp, $capture_data, $flags) );

C<$regexp> is either a regular expression reference produced with C<qr/.../>
or a string which will be used to construct a regular expression.

C<$capture_data> is optional and is used to check the strings captured by an
regex. This should can be an array ref or a Test::Deep comparator that works
on array refs.

C<$flags> is an optional string which controls whether the regex runs as a
global match. If C<$flags> is "g" then the regex will run as C<m/$regexp/g>.

Without C<$capture_data>, this simply compares C<$got_v> with the regular
expression provided. So

  cmp_deeply($got, [ re("ferg") ])

is the equivalent of

  $got->[0] =~ /ferg/

With C<$capture_data>,

  cmp_deeply($got, [re($regex, $capture_data)])

is the equivalent of

  my @data = $got->[0] =~ /$regex/;
  cmp_deeply(\@data, $capture_data);

So you can do something simple like

  cmp_deeply($got, re(qr/(\d\d)(\w\w)/, [25, "ab" ]))

to check that C<(\d\d)> was 25 and C<(\w\w)> was "ab" but you can also use
Test::Deep objects to do more complex testing of the captured values

  cmp_deeply(
    "cat=2,dog=67,sheep=3,goat=2,dog=5",
    re(
      qr/(\D+)=\d+,?/,
      set(qw( cat sheep dog )),
      "g"
    ),
  );

here, the regex will match the string and will capture the animal names and
check that they match the specified set, in this case it will fail,
complaining that "goat" is not in the set.

=head3 all

  cmp_deeply( $got, all(@expecteds) );

C<@expecteds> is an array of expected structures.

This allows you to compare data against multiple expected results and make
sure each of them matches.

  cmp_deeply($got, all(isa("Person"), methods(name => 'John')))

is equivalent to

  $got->isa("Person")
  $got->name eq 'John'

If either test fails then the whole thing is considered a fail. This is a
short-circuit test, the testing is stopped after the first failure, although
in the future it may complete all tests so that diagnostics can be output
for all failures. When reporting failure, the parts are counted from 1.

Thanks to the magic of overloading, you can write

  any( re("^wi"), all(isa("Person"), methods(name => 'John')) )

as

   re("^wi") | isa("Person") & methods(name => 'John')

Note B<single> C<|> not double, as C<||> cannot be overloaded. This will
only work when there is a special comparison involved. If you write

  "john" | "anne" | "robert"

Perl will turn this into

  "{onort"

which is presumably not what you wanted. This is because perl ors them
together as strings before Test::Deep gets a chance to do any overload
tricks.

=head3 any

  cmp_deeply( $got, any(@expecteds) );

C<@expecteds> is an array of expected structures.

This can be used to compare data against multiple expected results and make
sure that at least one of them matches. This is a short-circuit test so if
a test passes then none of the tests after that will be attempted.

You can also use overloading with C<|> similarly to all().

=head3 Isa

  cmp_deeply( $got, Isa($class) );

=head3 isa

  cmp_deeply( $got, isa($class) );

C<$class> is a class name.

This uses C<UNIVERSAL::isa()> to check that C<$got_v> is blessed into the
class C<$class>.

B<NOTE:> C<Isa()> does exactly as documented here, but C<isa()> is slightly
different. If C<isa()> is called with 1 argument it falls through to
C<Isa()>. If C<isa()> called with 2 arguments, it falls through to
C<UNIVERSAL::isa>. This is to prevent breakage when you import C<isa()> into
a package that is used as a class. Without this, anyone calling
C<Class-E<gt>isa($other_class)> would get the wrong answer. This is a hack
to patch over the fact that C<isa> is exported by default.

=head3 obj_isa

  cmp_deeply( $got, obj_isa($class) );

This test accepts only objects that are instances of C<$class> or a subclass.
Unlike the C<Isa> test, this test will never accept class names.

=head3 array_each

  cmp_deeply( \@got, array_each($thing) );

C<$thing> is a structure to be compared against.

<$got_v> must be an array reference. Each element of it will be compared to
C<$thing>. This is useful when you have an array of similar things, for example
objects of a known type and you don't want to have to repeat the same test
for each one.

  my $common_tests = all(
     isa("MyFile"),
     methods(
       handle => isa("IO::Handle")
       filename => re("^/home/ted/tmp"),
    )
  );

  cmp_deeply($got, array_each($common_tests));

is similar to

  foreach my $got_v (@$got) {
    cmp_deeply($got_v, $common_tests)
  }

Except it will not explode if C<$got> is not an array reference. It will
check that each of the objects in C<@$got> is a MyFile and that each one
gives the correct results for its methods.

You could go further, if for example there were 3 files and you knew the
size of each one you could do this

  cmp_deeply(
    $got,
    all(
      array_each($common_tests),
      [
        methods(size => 1000),
        methods(size => 200),
        methods(size => 20)
      ]
    )
  )
  cmp_deeply($got, array_each($structure));

=head3 hash_each

  cmp_deeply( \%got, hash_each($thing) );

This test behaves like C<array_each> (see above) but tests that each hash
value passes its tests.

=head3 str

  cmp_deeply( $got, str($string) );

$string is a string.

This will stringify C<$got_v> and compare it to C<$string> using C<eq>, even
if C<$got_v> is a ref. It is useful for checking the stringified value of an
overloaded reference.

=head3 num

  cmp_deeply( $got, num($number, $tolerance) );

C<$number> is a number.

C<$tolerance> is an optional number.

This will add 0 to C<$got_v> and check if it's numerically equal to
C<$number>, even if C<$got_v> is a ref. It is useful for checking the
numerical value of an overloaded reference. If C<$tolerance> is supplied
then this will check that C<$got_v> and C<$exp_v> are less than
C<$tolerance> apart. This is useful when comparing floating point numbers as
rounding errors can make it hard or impossible for C<$got_v> to be exactly
equal to C<$exp_v>. When C<$tolerance> is supplied, the test passes if
C<abs($got_v - $exp_v) <= $tolerance>.

B<Note> in Perl, C<"12blah" == 12> because Perl will be smart and convert
"12blah" into 12. You may not want this. There was a strict mode but that is
now gone. A "looks like a number" test will replace it soon. Until then you
can usually just use the string() comparison to be more strict. This will
work fine for almost all situations, however it will not work when <$got_v>
is an overloaded value who's string and numerical values differ.

=head3 bool, true, false

  cmp_deeply( $got, bool($value) );
  cmp_deeply( $got, true );
  cmp_deeply( $got, false );

C<$value> is anything you like but it's probably best to use 0 or 1

This will check that C<$got_v> and C<$value> have the same truth value, that
is they will give the same result when used in boolean context, like in an
C<if()> statement.

B<Note:> C<true> and C<false> are only imported by special request.

=head3 code

  cmp_deeply( $got, code(\&subref) );

C<\&subref> is a reference to a subroutine which will be passed a single
argument, it then should return a true or false and possibly a string

This will pass C<$got_v> to the subroutine which returns true or false to
indicate a pass or fail. Fails can be accompanied by a diagnostic string
which gives an explanation of why it's a fail.

  sub check_name
  {
    my $name = shift;
    if ($boss->likes($name))
    {
      return 1;
    }
    else
    {
      return (0, "the boss doesn't like your name");
    }
  }

  cmp_deeply("Brian", code(\&check_name));

=head2 SET COMPARISONS

Set comparisons give special semantics to array comparisons:

=over 4

=item * The order of items in a set is irrelevant

=item * The presence of duplicate items in a set is ignored.

=back

As such, in any set comparison, the following arrays are equal:

  [ 1, 2 ]
  [ 1, 1, 2 ]
  [ 1, 2, 1 ]
  [ 2, 1, 1 ]
  [ 1, 1, 2 ]

All are interpreted by C<set> semantics as if the set was only specified as:

  [ 1, 2 ]

All C<set> functions return an object which can have additional items added to
it:

  my $set = set( 1, 2 );
  $set->add(1, 3, 1 );  # Set is now ( 1, 2, 3 )

Special care must be taken when using special comparisons within sets. See
L</SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS> for details.

=head3 set

  cmp_deeply( \@got, set(@elements) );

This does a set comparison, that is, it compares two arrays but ignores the
order of the elements and it ignores duplicate elements, but ensures that all
items in C<@elements> will be in C<$got> and all items in C<$got> will be
in C<@elements>.

So the following tests will be passes, and will be equivalent:

  cmp_deeply([1, 2, 2, 3], set(3, 2, 1, 1));
  cmp_deeply([1, 2, 3],    set(3, 2, 1));

=head3 supersetof

  cmp_deeply( \@got, supersetof(@elements) );

This function works much like L<< C<set>|/set >>, and performs a set comparison
of C<$got_v> with the elements of C<@elements>.

C<supersetof> is however slightly relaxed, such that C<$got> may contain things
not in C<@elements>, but must at least contain all C<@elements>.

These two statements are equivalent, and will be passes:

  cmp_deeply([1,2,3,3,4,5], supersetof(2,2,3));
  cmp_deeply([1,2,3,4,5],   supersetof(2,3));

But these will be failures:

  cmp_deeply([1,2,3,4,5],   supersetof(2,3,6)); # 6 not in superset
  cmp_deeply([1],           supersetof(1,2));   # 2 not in superset

=head3 subsetof

  cmp_deeply( \@got, subsetof(@elements) );

This function works much like L<< C<set>|/set >>, and performs a set comparison
of C<$got_v> with the elements of C<@elements>.

This is the inverse of C<supersetof>, which expects all unique elements found
in C<$got_v> must be in C<@elements>.

  cmp_deeply([1,2,4,5], subsetof(2,3,3)    ) # Fail: 1,4 & 5 extra
  cmp_deeply([2,3,3],   subsetof(1,2,4,5)  ) # Fail: 3 extra
  cmp_deeply([2,3,3],   subsetof(1,2,4,5,3)) # Pass

=head3 none

  cmp_deeply( $got, none(@elements) );

@elements is an array of elements, wherein no elements in C<@elements> may
be equal to C<$got_v>.

=head3 noneof

  cmp_deeply( \@got, noneof(@elements) );

@elements is an array of elements, wherein no elements in C<@elements> may be
found in C<$got_v>.

For example:

  # Got has no 1, no 2, and no 3
  cmp_deeply( [1], noneof( 1, 2, 3 ) ); # fail
  cmp_deeply( [5], noneof( 1, 2, 3 ) ); # pass

=head2 BAG COMPARISONS

Bag comparisons give special semantics to array comparisons, that are similar
to L<< set comparisons|/SET COMPARISONS >>, but slightly different.

=over 4

=item * The order of items in a bag is irrelevant

=item * The presence of duplicate items in a bag is B<PRESERVED>

=back

As such, in any bag comparison, the following arrays are equal:

  [ 1, 1, 2 ]
  [ 1, 2, 1 ]
  [ 2, 1, 1 ]
  [ 1, 1, 2 ]

However, they are B<NOT> equal to any of the following:

  [ 1, 2 ]
  [ 1, 2, 2 ]
  [ 1, 1, 1, 2 ]

All C<bag> functions return an object which can have additional items added to
it:

  my $bag = bag( 1, 2 );
  $bag->add(1, 3, 1 );  # Bag is now ( 1, 1, 1, 2, 3 )

Special care must be taken when using special comparisons within bags. See
L</SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS> for details.

=head3 bag

  cmp_deeply( \@got, bag(@elements) );

This does an order-insensitive bag comparison between C<$got> and
C<@elements>, ensuring that:

=over 4

=item each item in C<@elements> is found in C<$got>

=item the number of times a C<$expected_v> is found in C<@elements> is
reflected in C<$got>

=item no items are found in C<$got> other than those in C<@elements>.

=back

As such, the following are passes, and are equivalent to each other:

  cmp_deeply([1, 2, 2], bag(2, 2, 1))
  cmp_deeply([2, 1, 2], bag(2, 2, 1))
  cmp_deeply([2, 2, 1], bag(2, 2, 1))

But the following are failures:

  cmp_deeply([1, 2, 2],     bag(2, 2, 1, 1)) # Not enough 1's in Got
  cmp_deeply([1, 2, 2, 1],  bag(2, 2, 1)   ) # Too many   1's in Got

=head3 superbagof

  cmp_deeply( \@got, superbagof( @elements ) );

This function works much like L<< C<bag>|/bag >>, and performs a bag comparison
of C<$got_v> with the elements of C<@elements>.

C<superbagof> is however slightly relaxed, such that C<$got> may contain things
not in C<@elements>, but must at least contain all C<@elements>.

So:

  # pass
  cmp_deeply( [1, 1, 2], superbagof( 1 )      );

  # fail: not enough 1's in superbag
  cmp_deeply( [1, 1, 2], superbagof( 1, 1, 1 ));

=head3 subbagof

  cmp_deeply( \@got, subbagof(@elements) );

This function works much like L<< C<bag>|/bag >>, and performs a bag comparison
of C<$got_v> with the elements of C<@elements>.

This is the inverse of C<superbagof>, and expects all elements in C<$got> to
be in C<@elements>, while allowing items to exist in C<@elements> that are not
in C<$got>

  # pass
  cmp_deeply( [1],        subbagof( 1, 1, 2 ) );

  # fail: too many 1's in subbag
  cmp_deeply( [1, 1, 1],  subbagof( 1, 1, 2 ) );

=head2 HASH COMPARISONS

Typically, if you're doing simple hash comparisons,

  cmp_deeply( \%got, \%expected )

is sufficient. C<cmp_deeply> will ensure C<%got> and C<%hash> have identical
keys, and each key from either has the same corresponding value.

=head3 superhashof

  cmp_deeply( \%got, superhashof(\%hash) );

This will check that the hash C<%$got> is a "super-hash" of C<%hash>. That
is that all the key and value pairs in C<%hash> appear in C<%$got> but
C<%$got> can have extra ones also.

For example

  cmp_deeply({a => 1, b => 2}, superhashof({a => 1}))

will pass but

  cmp_deeply({a => 1, b => 2}, superhashof({a => 1, c => 3}))

will fail.

=head3 subhashof

  cmp_deeply( \%got, subhashof(\%hash) );

This will check that the hash C<%$got> is a "sub-hash" of C<%hash>. That is
that all the key and value pairs in C<%$got> also appear in C<%hash>.

For example

  cmp_deeply({a => 1}, subhashof({a => 1, b => 2}))

will pass but

  cmp_deeply({a => 1, c => 3}, subhashof({a => 1, b => 2}))

will fail.

=head1 DIAGNOSTIC FUNCTIONS

=head3 deep_diag

  my $reason = deep_diag($stack);

C<$stack> is a value returned by cmp_details.  Do not call this function
if cmp_details returned a true value for C<$ok>.

C<deep_diag()> returns a human readable string describing how the
comparison failed.

=head1 ANOTHER EXAMPLE

You've written a module to handle people and their film interests. Say you
have a function that returns an array of people from a query, each person is
a hash with 2 keys: Name and Age and the array is sorted by Name. You can do

  cmp_deeply(
    $result,
    [
      {Name => 'Anne', Age => 26},
      {Name => "Bill", Age => 47}
      {Name => 'John', Age => 25},
    ]
  );

Soon after, your query function changes and all the results now have an ID
field. Now your test is failing again because you left out ID from each of
the hashes. The problem is that the IDs are generated by the database and
you have no way of knowing what each person's ID is. With Test::Deep you can
change your query to

  cmp_deeply(
    $result,
    [
      {Name => 'John', Age => 25, ID => ignore()},
      {Name => 'Anne', Age => 26, ID => ignore()},
      {Name => "Bill", Age => 47, ID => ignore()}
    ]
  );

But your test still fails. Now, because you're using a database, you no
longer know what order the people will appear in. You could add a sort into
the database query but that could slow down your application. Instead you
can get Test::Deep to ignore the order of the array by doing a bag
comparison instead.

  cmp_deeply(
    $result,
    bag(
      {Name => 'John', Age => 25, ID => ignore()},
      {Name => 'Anne', Age => 26, ID => ignore()},
      {Name => "Bill", Age => 47, ID => ignore()}
    )
  );

Finally person gets even more complicated and includes a new field called
Movies, this is a list of movies that the person has seen recently, again
these movies could also come back in any order so we need a bag inside our
other bag comparison, giving us something like

  cmp_deeply(
  $result,
    bag(
      {Name => 'John', Age => 25, ID => ignore(), Movies => bag(...)},
      {Name => 'Anne', Age => 26, ID => ignore(), Movies => bag(...)},
      {Name => "Bill", Age => 47, ID => ignore(), Movies => bag(...)}
    )
  );

=head1 USING TEST::DEEP WITH TEST::BUILDER

Combining C<cmp_details> and C<deep_diag> makes it possible to use
Test::Deep in your own test classes.

In a L<Test::Builder> subclass, create a test method in the following
form:

  sub behaves_ok {
    my $self = shift;
    my $expected = shift;
    my $test_name = shift;

    my $got = do_the_important_work_here();

    my ($ok, $stack) = cmp_details($got, $expected);
    unless ($Test->ok($ok, $test_name)) {
      my $diag = deep_diag($stack);
      $Test->diag($diag);
    }
  }

As the subclass defines a test class, not tests themselves, make sure it
uses L<Test::Deep::NoTest>, not C<Test::Deep> itself.

=head1 LIMITATIONS

Currently any CODE, GLOB or IO refs will be compared using shallow(), which
means only their memory addresses are compared.

=head1 BUGS

There is a bug in set and bag compare to do with competing SCs. It only
occurs when you put certain special comparisons inside bag or set
comparisons you don't need to worry about it. The full details are in the
C<bag()> docs. It will be fixed in an upcoming version.

=head1 CAVEATS

=head2 SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS

If you use certain special comparisons within a bag or set comparison there is
a danger that a test will fail when it should have passed. It can only happen
if two or more special comparisons in the bag are competing to match elements.
Consider this comparison

  cmp_deeply(['furry', 'furball'], bag(re("^fur"), re("furb")))

There are two things that could happen, hopefully C<re("^fur")> is paired with
"furry" and C<re("^furb")> is paired with "furb" and everything is fine but it
could happen that C<re("^fur")> is paired with "furball" and then C<re("^furb")>
cannot find a match and so the test fails. Examples of other competing
comparisons are C<bag(1, 2, 2)> vs C<set(1, 2)> and
C<< methods(m1 => "v1", m2 => "v2") >> vs C<< methods(m1 => "v1") >>

This problem is could be solved by using a slower and more complicated
algorithm for set and bag matching. Something for the future...

=head1 WHAT ARE SPECIAL COMPARISONS?

A special comparison (SC) is simply an object that inherits from
Test::Deep::Cmp. Whenever C<$expected_v> is an SC then instead of checking
C<$got_v eq $expected_v>, we pass control over to the SC and let it do its
thing.

Test::Deep exports lots of SC constructors, to make it easy for you to use
them in your test scripts. For example is C<re("hello")> is just a handy way
of creating a Test::Deep::Regexp object that will match any string containing
"hello". So

  cmp_deeply([ 'a', 'b', 'hello world'], ['a', 'b', re("^hello")]);

will check C<'a' eq 'a'>, C<'b' eq 'b'> but when it comes to comparing
C<'hello world'> and C<re("^hello")> it will see that
$expected_v is an SC and so will pass control to the Test::Deep::Regexp class
by do something like C<< $expected_v->descend($got_v) >>. The C<descend()>
method should just return true or false.

This gives you enough to write your own SCs but I haven't documented how
diagnostics works because it's about to get an overhaul (theoretically).

=head1 EXPORTS

By default, Test::Deep will export everything in its C<v0> tag, as if you had
written:

  use Test::Deep ':v0';

Those things are:

  all any array array_each arrayelementsonly arraylength arraylengthonly bag
  blessed bool cmp_bag cmp_deeply cmp_methods cmp_set code eq_deeply hash
  hash_each hashkeys hashkeysonly ignore Isa isa listmethods methods noclass
  none noneof num obj_isa re reftype regexpmatches regexponly regexpref
  regexprefonly scalarrefonly scalref set shallow str subbagof subhashof
  subsetof superbagof superhashof supersetof useclass

A slightly better set of exports is the C<v1> set.  It's all the same things,
with the exception of C<Isa> and C<blessed>.  If you want to import
"everything", you probably want to C<< use Test::Deep ':V1'; >>.

There's another magic export group:  C<:preload>.  If that is specified, all of
the Test::Deep plugins will be loaded immediately instead of lazily.

=head1 SEE ALSO

L<Test::More>

=head1 THANKS

Thanks to Michael G Schwern for Test::More's is_deeply function which inspired
this library.

=head1 AUTHORS

=over 4

=item *

Fergal Daly

=item *

Ricardo SIGNES <cpan@semiotic.systems>

=back

=head1 CONTRIBUTORS

=for stopwords Alexander Karelas Belden Lyman Daniel Böhmer David Steinbrunner Denis Ibaev Ed Adjei Fabrice Gabolde Felipe Gasper Fergal Daly George Hartzell Graham Knop Ivan Bessarabov José Joaquín Atria Karen Etheridge Kent Fredric Lance Wicks Matthew Horsfall Michael Hamlin Mohammad S Anwar Peter Haworth Philip J. Ludlam Ricardo Signes Zoffix Znet

=over 4

=item *

Alexander Karelas <karjala@karjala.org>

=item *

Belden Lyman <blyman@shutterstock.com>

=item *

Daniel Böhmer <dboehmer@cpan.org>

=item *

David Steinbrunner <dsteinbrunner@pobox.com>

=item *

Denis Ibaev <dionys@gmail.com>

=item *

Ed Adjei <edmund@cpan.org>

=item *

Fabrice Gabolde <fabrice.gabolde@gmail.com>

=item *

Felipe Gasper <felipe@felipegasper.com>

=item *

Fergal Daly <fergal@esatclear.ie>

=item *

George Hartzell <hartzell@alerce.com>

=item *

Graham Knop <haarg@haarg.org>

=item *

Ivan Bessarabov <ivan@bessarabov.ru>

=item *

José Joaquín Atria <jjatria@cpan.org>

=item *

Karen Etheridge <ether@cpan.org>

=item *

Kent Fredric <kentfredric@gmail.com>

=item *

Lance Wicks <lancew@cpan.org>

=item *

Matthew Horsfall <wolfsage@gmail.com>

=item *

Michael Hamlin <myrrhlin@gmail.com>

=item *

Mohammad S Anwar <mohammad.anwar@yahoo.com>

=item *

Peter Haworth <peter.haworth@headforwards.com>

=item *

Philip J. Ludlam <p.ludlam@cv-library.co.uk>

=item *

Ricardo Signes <rjbs@semiotic.systems>

=item *

Zoffix Znet <cpan@zoffix.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2003 by Fergal Daly.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__

#pod =head1 SYNOPSIS
#pod
#pod   use Test::More tests => $Num_Tests;
#pod   use Test::Deep;
#pod
#pod   cmp_deeply(
#pod     $actual_horrible_nested_data_structure,
#pod     $expected_horrible_nested_data_structure,
#pod     "got the right horrible nested data structure"
#pod   );
#pod
#pod   cmp_deeply(
#pod     $object,
#pod     methods(name => "John", phone => "55378008"),
#pod     "object methods ok"
#pod   );
#pod
#pod   cmp_deeply(
#pod     \@array,
#pod     [$hash1, $hash2, ignore()],
#pod     "first 2 elements are as expected, ignoring 3"
#pod   );
#pod
#pod   cmp_deeply(
#pod     $object,
#pod     noclass({value => 5}),
#pod     "object looks ok, not checking its class"
#pod   );
#pod
#pod   cmp_deeply(
#pod     \@result,
#pod     bag('a', 'b', {key => [1, 2]}),
#pod     "array has the 3 things we wanted in some order"
#pod   );
#pod
#pod =head1 DESCRIPTION
#pod
#pod If you don't know anything about automated testing in Perl then you should
#pod probably read about L<Test::Simple> and L<Test::More> before preceding.
#pod Test::Deep uses the L<Test::Builder> framework.
#pod
#pod Test::Deep gives you very flexible ways to check that the result you got is
#pod the result you were expecting. At its simplest it compares two structures
#pod by going through each level, ensuring that the values match, that arrays and
#pod hashes have the same elements and that references are blessed into the
#pod correct class. It also handles circular data structures without getting
#pod caught in an infinite loop.
#pod
#pod Where it becomes more interesting is in allowing you to do something besides
#pod simple exact comparisons. With strings, the C<eq> operator checks that 2
#pod strings are exactly equal but sometimes that's not what you want. When you
#pod don't know exactly what the string should be but you do know some things
#pod about how it should look, C<eq> is no good and you must use pattern matching
#pod instead. Test::Deep provides pattern matching for complex data structures
#pod
#pod Test::Deep has B<I<a lot>> of exports.  See L</EXPORTS> below.
#pod
#pod =head1 EXAMPLES
#pod
#pod How Test::Deep works is much easier to understand by seeing some examples.
#pod
#pod =head2 Without Test::Deep
#pod
#pod Say you want to test a function which returns a string. You know that your
#pod string should be a 7 digit number beginning with 0, C<eq> is no good in this
#pod situation, you need a regular expression. So you could use Test::More's
#pod C<like()> function:
#pod
#pod   like($string, qr/^0[0-9]{6}$/, "number looks good");
#pod
#pod Similarly, to check that a string looks like a name, you could do:
#pod
#pod   like($string, qr/^(Mr|Mrs|Miss) \w+ \w+$/,
#pod     "got title, first and last name");
#pod
#pod Now imagine your function produces a hash with some personal details in it.
#pod You want to make sure that there are 2 keys, Name and Phone and that the
#pod name looks like a name and the phone number looks like a phone number. You
#pod could do:
#pod
#pod   $hash = make_person();
#pod   like($hash->{Name}, qr/^(Mr|Mrs|Miss) \w+ \w+$/, "name ok");
#pod   like($hash->{Phone}, qr/^0[0-9]{6}$/, "phone ok");
#pod   is(scalar keys %$hash, 2, "correct number of keys");
#pod
#pod But that's not quite right, what if make_person has a serious problem and
#pod didn't even return a hash? We really need to write
#pod
#pod   if (ref($hash) eq "HASH")
#pod   {
#pod     like($hash->{Name}, qr/^(Mr|Mrs|Miss) \w+ \w+$/, "name ok");
#pod     like($hash->{Phone}, qr/^0[0-9]{6}$/, "phone ok");
#pod     is(scalar keys %$hash, 2, "correct number of keys");
#pod   }
#pod   else
#pod   {
#pod     fail("person not a hash");
#pod     fail("person not a hash");
#pod     fail("person not a hash"); # need 3 to keep the plan correct
#pod   }
#pod
#pod Already this is getting messy, now imagine another entry in the hash, an
#pod array of children's names. This would require
#pod
#pod
#pod   if (ref($hash) eq "HASH")
#pod   {
#pod     like($hash->{Name}, $name_pat, "name ok");
#pod     like($hash->{Phone}, '/^0d{6}$/', "phone ok");
#pod     my $cn = $hash->{ChildNames};
#pod     if (ref($cn) eq "ARRAY")
#pod     {
#pod       foreach my $child (@$cn)
#pod       {
#pod         like($child, $name_pat);
#pod       }
#pod     }
#pod     else
#pod     {
#pod         fail("child names not an array")
#pod     }
#pod   }
#pod   else
#pod   {
#pod     fail("person not a hash");
#pod   }
#pod
#pod This is a horrible mess and because we don't know in advance how many
#pod children's names there will be, we can't make a plan for our test anymore
#pod (actually, we could but it would make things even more complicated).
#pod
#pod Test::Deep to the rescue.
#pod
#pod =head2 With Test::Deep
#pod
#pod   my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
#pod   cmp_deeply(
#pod     $person,
#pod     {
#pod       Name => $name_re,
#pod       Phone => re('^0d{6}$'),
#pod       ChildNames => array_each($name_re)
#pod     },
#pod     "person ok"
#pod   );
#pod
#pod This will do everything that the messy code above does and it will give a
#pod sensible message telling you exactly what went wrong if it finds a part of
#pod $person that doesn't match the pattern. C<re()> and C<array_each()> are
#pod special function imported from Test::Deep. They create a marker that tells
#pod Test::Deep that something different is happening here. Instead of just doing
#pod a simple comparison and checking are two things exactly equal, it should do
#pod something else.
#pod
#pod If a person was asked to check that 2 structures are equal, they could print
#pod them both out and compare them line by line. The markers above are similar
#pod to writing a note in red pen on one of the printouts telling the person that
#pod for this piece of the structure, they should stop doing simple line by line
#pod comparison and do something else.
#pod
#pod C<re($regex)> means that Test::Deep should check that the current piece of
#pod data matches the regex in C<$regex>. C<array_each($struct)> means that
#pod Test::Deep should expect the current piece of data to be an array and it
#pod should check that every element of that array matches C<$struct>.
#pod In this case, every element of C<< $person->{ChildNames} >> should look like a
#pod name. If say the 3rd one didn't you would get an error message something
#pod like
#pod
#pod   Using Regexp on $data->{ChildNames}[3]
#pod      got    : 'Queen John Paul Sartre'
#pod      expect : /^(Mr|Mrs|Miss) \w+ \w+$/
#pod
#pod There are lots of other special comparisons available, see
#pod L<SPECIAL COMPARISONS PROVIDED> below for the full list.
#pod
#pod =head2 Reusing structures
#pod
#pod Test::Deep is good for reusing test structures so you can do this
#pod
#pod   my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
#pod   my $person_cmp = {
#pod     Name => $name_re,
#pod     Phone => re('^0d{6}$'),
#pod     ChildNames => array_each($name_re)
#pod   };
#pod
#pod   cmp_deeply($person1, $person_cmp, "person ok");
#pod   cmp_deeply($person2, $person_cmp, "person ok");
#pod   cmp_deeply($person3, $person_cmp, "person ok");
#pod
#pod You can even put $person_cmp in a module and let other people use it when
#pod they are writing test scripts for modules that use your modules.
#pod
#pod To make things a little more difficult, lets change the person data
#pod structure so that instead of a list of ChildNames, it contains a list of
#pod hashes, one for each child. So in fact our person structure will contain
#pod other person structures which may contain other person structures and so on.
#pod This is easy to handle with Test::Deep because Test::Deep structures can
#pod include themselves. Simply do
#pod
#pod   my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
#pod   my $person_cmp = {
#pod     Name => $name_re,
#pod     Phone => re('^0d{6}$'),
#pod     # note no mention of Children here
#pod   };
#pod
#pod   $person_cmp->{Children} = array_each($person_cmp);
#pod
#pod   cmp_deeply($person, $person_cmp, "person ok");
#pod
#pod This will now check that $person->{Children} is an array and that every
#pod element of that array also matches C<$person_cmp>, this includes checking
#pod that its children also match the same pattern and so on.
#pod
#pod =head2 Circular data structures
#pod
#pod A circular data structure is one which loops back on itself, you can make
#pod one easily by doing
#pod
#pod   my @b;
#pod   my @a = (1, 2, 3, \@b);
#pod   push(@b, \@a);
#pod
#pod now C<@a> contains a reference to be C<@b> and C<@b> contains a reference to
#pod C<@a>. This causes problems if you have a program that wants to look inside
#pod C<@a> and keep looking deeper and deeper at every level, it could get caught
#pod in an infinite loop looking into C<@a> then C<@b> then C<@a> then C<@b> and
#pod so on.
#pod
#pod Test::Deep avoids this problem so we can extend our example further by
#pod saying that a person should also list their parents.
#pod
#pod   my $name_re = re('^(Mr|Mrs|Miss) \w+ \w+$');
#pod   my $person_cmp = {
#pod     Name => $name_re,
#pod     Phone => re('^0d{6}$'),
#pod     # note no mention of Children here
#pod   };
#pod
#pod   $person_cmp->{Children} = each_array($person_cmp);
#pod   $person_cmp->{Parents} = each_array($person_cmp);
#pod
#pod   cmp_deeply($person, $person_cmp, "person ok");
#pod
#pod So this will check that for each child C<$child> in C<< $person->{Children} >>
#pod that the C<< $child->{Parents} >> matches C<$person_cmp> however it is smart
#pod enough not to get caught in an infinite loop where it keeps bouncing between
#pod the same Parent and Child.
#pod
#pod =head1 TERMINOLOGY
#pod
#pod C<cmp_deeply($got, $expected, $name)> takes 3 arguments. C<$got> is the
#pod structure that you are checking, you must not include any special
#pod comparisons in this structure or you will get a fatal error. C<$expected>
#pod describes what Test::Deep will be looking for in $got. You can put special
#pod comparisons in $expected if you want to.
#pod
#pod As Test::Deep descends through the 2 structures, it compares them one piece
#pod at a time, so at any point in the process, Test::Deep is thinking about 2
#pod things - the current value from C<$got> and the current value from
#pod C<$expected>. In the documentation, I call them C<$got_v> and C<exp_v>
#pod respectively.
#pod
#pod =head1 COMPARISON FUNCTIONS
#pod
#pod =head3 cmp_deeply
#pod
#pod   my $ok = cmp_deeply($got, $expected, $name)
#pod
#pod C<$got> is the result to be checked. C<$expected> is the structure against
#pod which C<$got> will be check. C<$name> is the test name.
#pod
#pod This is the main comparison function, the others are just wrappers around
#pod this.  C<$got> and C<$expected> are compared recursively.  Each value in
#pod C<$expected> defines what's expected at the corresponding location in C<$got>.
#pod Simple scalars are compared with C<eq>.  References to structures like hashes
#pod and arrays are compared recursively.
#pod
#pod Items in C<$expected>, though, can also represent complex tests that check for
#pod numbers in a given range, hashes with at least a certain set of keys, a string
#pod matching a regex, or many other things.
#pod
#pod See L</WHAT ARE SPECIAL COMPARISONS> for details.
#pod
#pod =head3 cmp_bag
#pod
#pod   my $ok = cmp_bag(\@got, \@bag, $name)
#pod
#pod Is shorthand for cmp_deeply(\@got, bag(@bag), $name)
#pod
#pod I<n.b.>: Both arguments must be array refs. If they aren't an exception will be
#pod thrown.
#pod
#pod =head3 cmp_set
#pod
#pod   my $ok = cmp_set(\@got, \@set, $name)
#pod
#pod Is shorthand for cmp_deeply(\@got, set(@set), $name)
#pod
#pod =head3 cmp_methods
#pod
#pod   my $ok = cmp_methods(\@got, \@methods, $name)
#pod
#pod Is shorthand for cmp_deeply(\@got, methods(@methods), $name)
#pod
#pod =head3 eq_deeply
#pod
#pod   my $ok = eq_deeply($got, $expected)
#pod
#pod This is the same as cmp_deeply() except it just returns true or
#pod false. It does not create diagnostics or talk to L<Test::Builder>, but
#pod if you want to use it in a non-testing environment then you should
#pod import it through L<Test::Deep::NoTest>. For example
#pod
#pod   use Test::Deep::NoTest;
#pod   print "a equals b" unless eq_deeply($a, $b);
#pod
#pod otherwise the L<Test::Builder> framework will be loaded and testing messages
#pod will be output when your program ends.
#pod
#pod =head3 cmp_details
#pod
#pod   ($ok, $stack) = cmp_details($got, $expected)
#pod
#pod This behaves much like eq_deeply, but it additionally allows you to
#pod produce diagnostics in case of failure by passing the value in C<$stack>
#pod to C<deep_diag>.
#pod
#pod Do not make assumptions about the structure or content of C<$stack> and
#pod do not use it if C<$ok> contains a true value.
#pod
#pod See L</USING TEST::DEEP WITH TEST::BUILDER> for example uses.
#pod
#pod =head1 SPECIAL COMPARISONS PROVIDED
#pod
#pod In the documentation below, C<$got_v> is used to indicate any given value
#pod within the C<$got> structure.
#pod
#pod =head3 ignore
#pod
#pod   cmp_deeply( $got, ignore() );
#pod
#pod This makes Test::Deep skip tests on C<$got_v>. No matter what value C<$got_v>
#pod has, Test::Deep will think it's correct. This is useful if some part of the
#pod structure you are testing is very complicated and already tested elsewhere,
#pod or if it is unpredictable.
#pod
#pod   cmp_deeply(
#pod     $got,
#pod     {
#pod       name    => 'John',
#pod       random  => ignore(),
#pod       address => [ '5 A street', 'a town', 'a country' ],
#pod     }
#pod   );
#pod
#pod is the equivalent of checking
#pod
#pod   $got->{name} eq 'John';
#pod   exists $got->{random};
#pod   cmp_deeply($got->{address}, ['5 A street', 'a town', 'a country']);
#pod
#pod =head3 methods
#pod
#pod   cmp_deeply( $got, methods(%hash) );
#pod
#pod %hash is a hash of method call => expected value pairs.
#pod
#pod This lets you call methods on an object and check the result of each call.
#pod The methods will be called in the order supplied. If you want to pass
#pod arguments to the method you should wrap the method name and arguments in an
#pod array reference.
#pod
#pod   cmp_deeply(
#pod     $obj,
#pod     methods(name => "John", ["favourite", "food"] => "taco")
#pod   );
#pod
#pod is roughly the equivalent of checking that
#pod
#pod   $obj->name eq "John"
#pod   $obj->favourite("food") eq "taco"
#pod
#pod The methods will be called in the order you supply them and will be called
#pod in scalar context. If you need to test methods called in list context then
#pod you should use C<listmethods()>.
#pod
#pod B<NOTE> Just as in a normal test script, you need to be careful if the
#pod methods you call have side effects like changing the object or other objects
#pod in the structure. Although the order of the methods is fixed, the order of
#pod some other tests is not so if C<$expected> is
#pod
#pod   {
#pod     manager => methods(@manager_methods),
#pod     coder => methods(@coder_methods)
#pod   }
#pod
#pod there is no way to know which if manager and coder will be tested first. If
#pod the methods you are testing depend on and alter global variables or if
#pod manager and coder are the same object then you may run into problems.
#pod
#pod =head3 listmethods
#pod
#pod   cmp_deeply( $got, listmethods(%hash) );
#pod
#pod C<%hash> is a hash of pairs mapping method names to expected return values.
#pod
#pod This is almost identical to methods() except the methods are called in list
#pod context instead of scalar context. This means that the expected return
#pod values supplied must be in array references.
#pod
#pod   cmp_deeply(
#pod     $obj,
#pod     listmethods(
#pod       name => [ "John" ],
#pod       ["favourites", "food"] => ["Mapo tofu", "Gongbao chicken"]
#pod     )
#pod   );
#pod
#pod is the equivalent of checking that
#pod
#pod   cmp_deeply([$obj->name], ["John"]);
#pod   cmp_deeply([$obj->favourites("food")], ["Mapo tofu", "Gongbao chicken"]);
#pod
#pod The methods will be called in the order you supply them.
#pod
#pod B<NOTE> The same caveats apply as for methods().
#pod
#pod =head3 shallow
#pod
#pod   cmp_deeply( $got, shallow($thing) );
#pod
#pod C<$thing> is a ref.
#pod
#pod This prevents Test::Deep from looking inside C<$thing>. It allows you to
#pod check that C<$got_v> and C<$thing> are references to the same variable. So
#pod
#pod   my @a = @b = (1, 2, 3);
#pod   cmp_deeply(\@a, \@b);
#pod
#pod will pass because C<@a> and C<@b> have the same elements however
#pod
#pod   cmp_deeply(\@a, shallow(\@b))
#pod
#pod will fail because although C<\@a> and C<\@b> both contain C<1, 2, 3> they are
#pod references to different arrays.
#pod
#pod =head3 noclass
#pod
#pod   cmp_deeply( $got, noclass($thing) );
#pod
#pod C<$thing> is a structure to be compared against.
#pod
#pod This makes Test::Deep ignore the class of objects, so it just looks at the
#pod data they contain. Class checking will be turned off until Test::Deep is
#pod finished comparing C<$got_v> against C<$thing>. Once Test::Deep comes out of
#pod C<$thing> it will go back to its previous setting for checking class.
#pod
#pod This can be useful when you want to check that objects have been
#pod constructed correctly but you don't want to write lots of
#pod C<bless>es. If C<@people> is an array of Person objects then
#pod
#pod   cmp_deeply(\@people, [
#pod     bless {name => 'John', phone => '555-5555'}, "Person",
#pod     bless {name => 'Anne', phone => '444-4444'}, "Person",
#pod   ]);
#pod
#pod can be replaced with
#pod
#pod   cmp_deeply(\@people, noclass([
#pod     {name => 'John', phone => '555-5555'},
#pod     {name => 'Anne', phone => '444-4444'}
#pod   ]));
#pod
#pod However, this is testing so you should also check that the objects are
#pod blessed correctly. You could use a map to bless all those hashes or you
#pod could do a second test like
#pod
#pod   cmp_deeply(\@people, array_each(isa("Person"));
#pod
#pod =head3 useclass
#pod
#pod   cmp_deeply( $got, useclass($thing) );
#pod
#pod This turns back on the class comparison while inside a C<noclass()>.
#pod
#pod   cmp_deeply(
#pod     $got,
#pod     noclass(
#pod       [
#pod         useclass( $object )
#pod       ]
#pod     )
#pod   )
#pod
#pod In this example the class of the array reference in C<$got> is ignored but
#pod the class of C<$object> is checked, as is the class of everything inside
#pod C<$object>.
#pod
#pod =head3 re
#pod
#pod   cmp_deeply( $got, re($regexp, $capture_data, $flags) );
#pod
#pod C<$regexp> is either a regular expression reference produced with C<qr/.../>
#pod or a string which will be used to construct a regular expression.
#pod
#pod C<$capture_data> is optional and is used to check the strings captured by an
#pod regex. This should can be an array ref or a Test::Deep comparator that works
#pod on array refs.
#pod
#pod C<$flags> is an optional string which controls whether the regex runs as a
#pod global match. If C<$flags> is "g" then the regex will run as C<m/$regexp/g>.
#pod
#pod Without C<$capture_data>, this simply compares C<$got_v> with the regular
#pod expression provided. So
#pod
#pod   cmp_deeply($got, [ re("ferg") ])
#pod
#pod is the equivalent of
#pod
#pod   $got->[0] =~ /ferg/
#pod
#pod With C<$capture_data>,
#pod
#pod   cmp_deeply($got, [re($regex, $capture_data)])
#pod
#pod is the equivalent of
#pod
#pod   my @data = $got->[0] =~ /$regex/;
#pod   cmp_deeply(\@data, $capture_data);
#pod
#pod So you can do something simple like
#pod
#pod   cmp_deeply($got, re(qr/(\d\d)(\w\w)/, [25, "ab" ]))
#pod
#pod to check that C<(\d\d)> was 25 and C<(\w\w)> was "ab" but you can also use
#pod Test::Deep objects to do more complex testing of the captured values
#pod
#pod   cmp_deeply(
#pod     "cat=2,dog=67,sheep=3,goat=2,dog=5",
#pod     re(
#pod       qr/(\D+)=\d+,?/,
#pod       set(qw( cat sheep dog )),
#pod       "g"
#pod     ),
#pod   );
#pod
#pod here, the regex will match the string and will capture the animal names and
#pod check that they match the specified set, in this case it will fail,
#pod complaining that "goat" is not in the set.
#pod
#pod =head3 all
#pod
#pod   cmp_deeply( $got, all(@expecteds) );
#pod
#pod C<@expecteds> is an array of expected structures.
#pod
#pod This allows you to compare data against multiple expected results and make
#pod sure each of them matches.
#pod
#pod   cmp_deeply($got, all(isa("Person"), methods(name => 'John')))
#pod
#pod is equivalent to
#pod
#pod   $got->isa("Person")
#pod   $got->name eq 'John'
#pod
#pod If either test fails then the whole thing is considered a fail. This is a
#pod short-circuit test, the testing is stopped after the first failure, although
#pod in the future it may complete all tests so that diagnostics can be output
#pod for all failures. When reporting failure, the parts are counted from 1.
#pod
#pod Thanks to the magic of overloading, you can write
#pod
#pod   any( re("^wi"), all(isa("Person"), methods(name => 'John')) )
#pod
#pod as
#pod
#pod    re("^wi") | isa("Person") & methods(name => 'John')
#pod
#pod Note B<single> C<|> not double, as C<||> cannot be overloaded. This will
#pod only work when there is a special comparison involved. If you write
#pod
#pod   "john" | "anne" | "robert"
#pod
#pod Perl will turn this into
#pod
#pod   "{onort"
#pod
#pod which is presumably not what you wanted. This is because perl ors them
#pod together as strings before Test::Deep gets a chance to do any overload
#pod tricks.
#pod
#pod =head3 any
#pod
#pod   cmp_deeply( $got, any(@expecteds) );
#pod
#pod C<@expecteds> is an array of expected structures.
#pod
#pod This can be used to compare data against multiple expected results and make
#pod sure that at least one of them matches. This is a short-circuit test so if
#pod a test passes then none of the tests after that will be attempted.
#pod
#pod You can also use overloading with C<|> similarly to all().
#pod
#pod =head3 Isa
#pod
#pod   cmp_deeply( $got, Isa($class) );
#pod
#pod =head3 isa
#pod
#pod   cmp_deeply( $got, isa($class) );
#pod
#pod C<$class> is a class name.
#pod
#pod This uses C<UNIVERSAL::isa()> to check that C<$got_v> is blessed into the
#pod class C<$class>.
#pod
#pod B<NOTE:> C<Isa()> does exactly as documented here, but C<isa()> is slightly
#pod different. If C<isa()> is called with 1 argument it falls through to
#pod C<Isa()>. If C<isa()> called with 2 arguments, it falls through to
#pod C<UNIVERSAL::isa>. This is to prevent breakage when you import C<isa()> into
#pod a package that is used as a class. Without this, anyone calling
#pod C<Class-E<gt>isa($other_class)> would get the wrong answer. This is a hack
#pod to patch over the fact that C<isa> is exported by default.
#pod
#pod =head3 obj_isa
#pod
#pod   cmp_deeply( $got, obj_isa($class) );
#pod
#pod This test accepts only objects that are instances of C<$class> or a subclass.
#pod Unlike the C<Isa> test, this test will never accept class names.
#pod
#pod =head3 array_each
#pod
#pod   cmp_deeply( \@got, array_each($thing) );
#pod
#pod C<$thing> is a structure to be compared against.
#pod
#pod <$got_v> must be an array reference. Each element of it will be compared to
#pod C<$thing>. This is useful when you have an array of similar things, for example
#pod objects of a known type and you don't want to have to repeat the same test
#pod for each one.
#pod
#pod   my $common_tests = all(
#pod      isa("MyFile"),
#pod      methods(
#pod        handle => isa("IO::Handle")
#pod        filename => re("^/home/ted/tmp"),
#pod     )
#pod   );
#pod
#pod   cmp_deeply($got, array_each($common_tests));
#pod
#pod is similar to
#pod
#pod   foreach my $got_v (@$got) {
#pod     cmp_deeply($got_v, $common_tests)
#pod   }
#pod
#pod Except it will not explode if C<$got> is not an array reference. It will
#pod check that each of the objects in C<@$got> is a MyFile and that each one
#pod gives the correct results for its methods.
#pod
#pod You could go further, if for example there were 3 files and you knew the
#pod size of each one you could do this
#pod
#pod   cmp_deeply(
#pod     $got,
#pod     all(
#pod       array_each($common_tests),
#pod       [
#pod         methods(size => 1000),
#pod         methods(size => 200),
#pod         methods(size => 20)
#pod       ]
#pod     )
#pod   )
#pod   cmp_deeply($got, array_each($structure));
#pod
#pod =head3 hash_each
#pod
#pod   cmp_deeply( \%got, hash_each($thing) );
#pod
#pod This test behaves like C<array_each> (see above) but tests that each hash
#pod value passes its tests.
#pod
#pod =head3 str
#pod
#pod   cmp_deeply( $got, str($string) );
#pod
#pod $string is a string.
#pod
#pod This will stringify C<$got_v> and compare it to C<$string> using C<eq>, even
#pod if C<$got_v> is a ref. It is useful for checking the stringified value of an
#pod overloaded reference.
#pod
#pod =head3 num
#pod
#pod   cmp_deeply( $got, num($number, $tolerance) );
#pod
#pod C<$number> is a number.
#pod
#pod C<$tolerance> is an optional number.
#pod
#pod This will add 0 to C<$got_v> and check if it's numerically equal to
#pod C<$number>, even if C<$got_v> is a ref. It is useful for checking the
#pod numerical value of an overloaded reference. If C<$tolerance> is supplied
#pod then this will check that C<$got_v> and C<$exp_v> are less than
#pod C<$tolerance> apart. This is useful when comparing floating point numbers as
#pod rounding errors can make it hard or impossible for C<$got_v> to be exactly
#pod equal to C<$exp_v>. When C<$tolerance> is supplied, the test passes if
#pod C<abs($got_v - $exp_v) <= $tolerance>.
#pod
#pod B<Note> in Perl, C<"12blah" == 12> because Perl will be smart and convert
#pod "12blah" into 12. You may not want this. There was a strict mode but that is
#pod now gone. A "looks like a number" test will replace it soon. Until then you
#pod can usually just use the string() comparison to be more strict. This will
#pod work fine for almost all situations, however it will not work when <$got_v>
#pod is an overloaded value who's string and numerical values differ.
#pod
#pod =head3 bool, true, false
#pod
#pod   cmp_deeply( $got, bool($value) );
#pod   cmp_deeply( $got, true );
#pod   cmp_deeply( $got, false );
#pod
#pod C<$value> is anything you like but it's probably best to use 0 or 1
#pod
#pod This will check that C<$got_v> and C<$value> have the same truth value, that
#pod is they will give the same result when used in boolean context, like in an
#pod C<if()> statement.
#pod
#pod B<Note:> C<true> and C<false> are only imported by special request.
#pod
#pod =head3 code
#pod
#pod   cmp_deeply( $got, code(\&subref) );
#pod
#pod C<\&subref> is a reference to a subroutine which will be passed a single
#pod argument, it then should return a true or false and possibly a string
#pod
#pod This will pass C<$got_v> to the subroutine which returns true or false to
#pod indicate a pass or fail. Fails can be accompanied by a diagnostic string
#pod which gives an explanation of why it's a fail.
#pod
#pod   sub check_name
#pod   {
#pod     my $name = shift;
#pod     if ($boss->likes($name))
#pod     {
#pod       return 1;
#pod     }
#pod     else
#pod     {
#pod       return (0, "the boss doesn't like your name");
#pod     }
#pod   }
#pod
#pod   cmp_deeply("Brian", code(\&check_name));
#pod
#pod =head2 SET COMPARISONS
#pod
#pod Set comparisons give special semantics to array comparisons:
#pod
#pod =over 4
#pod
#pod =item * The order of items in a set is irrelevant
#pod
#pod =item * The presence of duplicate items in a set is ignored.
#pod
#pod =back
#pod
#pod As such, in any set comparison, the following arrays are equal:
#pod
#pod   [ 1, 2 ]
#pod   [ 1, 1, 2 ]
#pod   [ 1, 2, 1 ]
#pod   [ 2, 1, 1 ]
#pod   [ 1, 1, 2 ]
#pod
#pod All are interpreted by C<set> semantics as if the set was only specified as:
#pod
#pod   [ 1, 2 ]
#pod
#pod All C<set> functions return an object which can have additional items added to
#pod it:
#pod
#pod   my $set = set( 1, 2 );
#pod   $set->add(1, 3, 1 );  # Set is now ( 1, 2, 3 )
#pod
#pod Special care must be taken when using special comparisons within sets. See
#pod L</SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS> for details.
#pod
#pod =head3 set
#pod
#pod   cmp_deeply( \@got, set(@elements) );
#pod
#pod This does a set comparison, that is, it compares two arrays but ignores the
#pod order of the elements and it ignores duplicate elements, but ensures that all
#pod items in C<@elements> will be in C<$got> and all items in C<$got> will be
#pod in C<@elements>.
#pod
#pod So the following tests will be passes, and will be equivalent:
#pod
#pod   cmp_deeply([1, 2, 2, 3], set(3, 2, 1, 1));
#pod   cmp_deeply([1, 2, 3],    set(3, 2, 1));
#pod
#pod =head3 supersetof
#pod
#pod   cmp_deeply( \@got, supersetof(@elements) );
#pod
#pod This function works much like L<< C<set>|/set >>, and performs a set comparison
#pod of C<$got_v> with the elements of C<@elements>.
#pod
#pod C<supersetof> is however slightly relaxed, such that C<$got> may contain things
#pod not in C<@elements>, but must at least contain all C<@elements>.
#pod
#pod These two statements are equivalent, and will be passes:
#pod
#pod   cmp_deeply([1,2,3,3,4,5], supersetof(2,2,3));
#pod   cmp_deeply([1,2,3,4,5],   supersetof(2,3));
#pod
#pod But these will be failures:
#pod
#pod   cmp_deeply([1,2,3,4,5],   supersetof(2,3,6)); # 6 not in superset
#pod   cmp_deeply([1],           supersetof(1,2));   # 2 not in superset
#pod
#pod =head3 subsetof
#pod
#pod   cmp_deeply( \@got, subsetof(@elements) );
#pod
#pod This function works much like L<< C<set>|/set >>, and performs a set comparison
#pod of C<$got_v> with the elements of C<@elements>.
#pod
#pod This is the inverse of C<supersetof>, which expects all unique elements found
#pod in C<$got_v> must be in C<@elements>.
#pod
#pod   cmp_deeply([1,2,4,5], subsetof(2,3,3)    ) # Fail: 1,4 & 5 extra
#pod   cmp_deeply([2,3,3],   subsetof(1,2,4,5)  ) # Fail: 3 extra
#pod   cmp_deeply([2,3,3],   subsetof(1,2,4,5,3)) # Pass
#pod
#pod =head3 none
#pod
#pod   cmp_deeply( $got, none(@elements) );
#pod
#pod @elements is an array of elements, wherein no elements in C<@elements> may
#pod be equal to C<$got_v>.
#pod
#pod =head3 noneof
#pod
#pod   cmp_deeply( \@got, noneof(@elements) );
#pod
#pod @elements is an array of elements, wherein no elements in C<@elements> may be
#pod found in C<$got_v>.
#pod
#pod For example:
#pod
#pod   # Got has no 1, no 2, and no 3
#pod   cmp_deeply( [1], noneof( 1, 2, 3 ) ); # fail
#pod   cmp_deeply( [5], noneof( 1, 2, 3 ) ); # pass
#pod
#pod =head2 BAG COMPARISONS
#pod
#pod Bag comparisons give special semantics to array comparisons, that are similar
#pod to L<< set comparisons|/SET COMPARISONS >>, but slightly different.
#pod
#pod =over 4
#pod
#pod =item * The order of items in a bag is irrelevant
#pod
#pod =item * The presence of duplicate items in a bag is B<PRESERVED>
#pod
#pod =back
#pod
#pod As such, in any bag comparison, the following arrays are equal:
#pod
#pod   [ 1, 1, 2 ]
#pod   [ 1, 2, 1 ]
#pod   [ 2, 1, 1 ]
#pod   [ 1, 1, 2 ]
#pod
#pod However, they are B<NOT> equal to any of the following:
#pod
#pod   [ 1, 2 ]
#pod   [ 1, 2, 2 ]
#pod   [ 1, 1, 1, 2 ]
#pod
#pod All C<bag> functions return an object which can have additional items added to
#pod it:
#pod
#pod   my $bag = bag( 1, 2 );
#pod   $bag->add(1, 3, 1 );  # Bag is now ( 1, 1, 1, 2, 3 )
#pod
#pod Special care must be taken when using special comparisons within bags. See
#pod L</SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS> for details.
#pod
#pod =head3 bag
#pod
#pod   cmp_deeply( \@got, bag(@elements) );
#pod
#pod This does an order-insensitive bag comparison between C<$got> and
#pod C<@elements>, ensuring that:
#pod
#pod =over 4
#pod
#pod =item each item in C<@elements> is found in C<$got>
#pod
#pod =item the number of times a C<$expected_v> is found in C<@elements> is
#pod reflected in C<$got>
#pod
#pod =item no items are found in C<$got> other than those in C<@elements>.
#pod
#pod =back
#pod
#pod As such, the following are passes, and are equivalent to each other:
#pod
#pod   cmp_deeply([1, 2, 2], bag(2, 2, 1))
#pod   cmp_deeply([2, 1, 2], bag(2, 2, 1))
#pod   cmp_deeply([2, 2, 1], bag(2, 2, 1))
#pod
#pod But the following are failures:
#pod
#pod   cmp_deeply([1, 2, 2],     bag(2, 2, 1, 1)) # Not enough 1's in Got
#pod   cmp_deeply([1, 2, 2, 1],  bag(2, 2, 1)   ) # Too many   1's in Got
#pod
#pod =head3 superbagof
#pod
#pod   cmp_deeply( \@got, superbagof( @elements ) );
#pod
#pod This function works much like L<< C<bag>|/bag >>, and performs a bag comparison
#pod of C<$got_v> with the elements of C<@elements>.
#pod
#pod C<superbagof> is however slightly relaxed, such that C<$got> may contain things
#pod not in C<@elements>, but must at least contain all C<@elements>.
#pod
#pod So:
#pod
#pod   # pass
#pod   cmp_deeply( [1, 1, 2], superbagof( 1 )      );
#pod
#pod   # fail: not enough 1's in superbag
#pod   cmp_deeply( [1, 1, 2], superbagof( 1, 1, 1 ));
#pod
#pod =head3 subbagof
#pod
#pod   cmp_deeply( \@got, subbagof(@elements) );
#pod
#pod This function works much like L<< C<bag>|/bag >>, and performs a bag comparison
#pod of C<$got_v> with the elements of C<@elements>.
#pod
#pod This is the inverse of C<superbagof>, and expects all elements in C<$got> to
#pod be in C<@elements>, while allowing items to exist in C<@elements> that are not
#pod in C<$got>
#pod
#pod   # pass
#pod   cmp_deeply( [1],        subbagof( 1, 1, 2 ) );
#pod
#pod   # fail: too many 1's in subbag
#pod   cmp_deeply( [1, 1, 1],  subbagof( 1, 1, 2 ) );
#pod
#pod =head2 HASH COMPARISONS
#pod
#pod Typically, if you're doing simple hash comparisons,
#pod
#pod   cmp_deeply( \%got, \%expected )
#pod
#pod is sufficient. C<cmp_deeply> will ensure C<%got> and C<%hash> have identical
#pod keys, and each key from either has the same corresponding value.
#pod
#pod =head3 superhashof
#pod
#pod   cmp_deeply( \%got, superhashof(\%hash) );
#pod
#pod This will check that the hash C<%$got> is a "super-hash" of C<%hash>. That
#pod is that all the key and value pairs in C<%hash> appear in C<%$got> but
#pod C<%$got> can have extra ones also.
#pod
#pod For example
#pod
#pod   cmp_deeply({a => 1, b => 2}, superhashof({a => 1}))
#pod
#pod will pass but
#pod
#pod   cmp_deeply({a => 1, b => 2}, superhashof({a => 1, c => 3}))
#pod
#pod will fail.
#pod
#pod =head3 subhashof
#pod
#pod   cmp_deeply( \%got, subhashof(\%hash) );
#pod
#pod This will check that the hash C<%$got> is a "sub-hash" of C<%hash>. That is
#pod that all the key and value pairs in C<%$got> also appear in C<%hash>.
#pod
#pod For example
#pod
#pod   cmp_deeply({a => 1}, subhashof({a => 1, b => 2}))
#pod
#pod will pass but
#pod
#pod   cmp_deeply({a => 1, c => 3}, subhashof({a => 1, b => 2}))
#pod
#pod will fail.
#pod
#pod =head1 DIAGNOSTIC FUNCTIONS
#pod
#pod =head3 deep_diag
#pod
#pod   my $reason = deep_diag($stack);
#pod
#pod C<$stack> is a value returned by cmp_details.  Do not call this function
#pod if cmp_details returned a true value for C<$ok>.
#pod
#pod C<deep_diag()> returns a human readable string describing how the
#pod comparison failed.
#pod
#pod =head1 ANOTHER EXAMPLE
#pod
#pod You've written a module to handle people and their film interests. Say you
#pod have a function that returns an array of people from a query, each person is
#pod a hash with 2 keys: Name and Age and the array is sorted by Name. You can do
#pod
#pod   cmp_deeply(
#pod     $result,
#pod     [
#pod       {Name => 'Anne', Age => 26},
#pod       {Name => "Bill", Age => 47}
#pod       {Name => 'John', Age => 25},
#pod     ]
#pod   );
#pod
#pod Soon after, your query function changes and all the results now have an ID
#pod field. Now your test is failing again because you left out ID from each of
#pod the hashes. The problem is that the IDs are generated by the database and
#pod you have no way of knowing what each person's ID is. With Test::Deep you can
#pod change your query to
#pod
#pod   cmp_deeply(
#pod     $result,
#pod     [
#pod       {Name => 'John', Age => 25, ID => ignore()},
#pod       {Name => 'Anne', Age => 26, ID => ignore()},
#pod       {Name => "Bill", Age => 47, ID => ignore()}
#pod     ]
#pod   );
#pod
#pod But your test still fails. Now, because you're using a database, you no
#pod longer know what order the people will appear in. You could add a sort into
#pod the database query but that could slow down your application. Instead you
#pod can get Test::Deep to ignore the order of the array by doing a bag
#pod comparison instead.
#pod
#pod   cmp_deeply(
#pod     $result,
#pod     bag(
#pod       {Name => 'John', Age => 25, ID => ignore()},
#pod       {Name => 'Anne', Age => 26, ID => ignore()},
#pod       {Name => "Bill", Age => 47, ID => ignore()}
#pod     )
#pod   );
#pod
#pod Finally person gets even more complicated and includes a new field called
#pod Movies, this is a list of movies that the person has seen recently, again
#pod these movies could also come back in any order so we need a bag inside our
#pod other bag comparison, giving us something like
#pod
#pod   cmp_deeply(
#pod   $result,
#pod     bag(
#pod       {Name => 'John', Age => 25, ID => ignore(), Movies => bag(...)},
#pod       {Name => 'Anne', Age => 26, ID => ignore(), Movies => bag(...)},
#pod       {Name => "Bill", Age => 47, ID => ignore(), Movies => bag(...)}
#pod     )
#pod   );
#pod
#pod =head1 USING TEST::DEEP WITH TEST::BUILDER
#pod
#pod Combining C<cmp_details> and C<deep_diag> makes it possible to use
#pod Test::Deep in your own test classes.
#pod
#pod In a L<Test::Builder> subclass, create a test method in the following
#pod form:
#pod
#pod   sub behaves_ok {
#pod     my $self = shift;
#pod     my $expected = shift;
#pod     my $test_name = shift;
#pod
#pod     my $got = do_the_important_work_here();
#pod
#pod     my ($ok, $stack) = cmp_details($got, $expected);
#pod     unless ($Test->ok($ok, $test_name)) {
#pod       my $diag = deep_diag($stack);
#pod       $Test->diag($diag);
#pod     }
#pod   }
#pod
#pod As the subclass defines a test class, not tests themselves, make sure it
#pod uses L<Test::Deep::NoTest>, not C<Test::Deep> itself.
#pod
#pod =head1 LIMITATIONS
#pod
#pod Currently any CODE, GLOB or IO refs will be compared using shallow(), which
#pod means only their memory addresses are compared.
#pod
#pod =head1 BUGS
#pod
#pod There is a bug in set and bag compare to do with competing SCs. It only
#pod occurs when you put certain special comparisons inside bag or set
#pod comparisons you don't need to worry about it. The full details are in the
#pod C<bag()> docs. It will be fixed in an upcoming version.
#pod
#pod =head1 CAVEATS
#pod
#pod =head2 SPECIAL CARE WITH SPECIAL COMPARISONS IN SETS AND BAGS
#pod
#pod If you use certain special comparisons within a bag or set comparison there is
#pod a danger that a test will fail when it should have passed. It can only happen
#pod if two or more special comparisons in the bag are competing to match elements.
#pod Consider this comparison
#pod
#pod   cmp_deeply(['furry', 'furball'], bag(re("^fur"), re("furb")))
#pod
#pod There are two things that could happen, hopefully C<re("^fur")> is paired with
#pod "furry" and C<re("^furb")> is paired with "furb" and everything is fine but it
#pod could happen that C<re("^fur")> is paired with "furball" and then C<re("^furb")>
#pod cannot find a match and so the test fails. Examples of other competing
#pod comparisons are C<bag(1, 2, 2)> vs C<set(1, 2)> and
#pod C<< methods(m1 => "v1", m2 => "v2") >> vs C<< methods(m1 => "v1") >>
#pod
#pod This problem is could be solved by using a slower and more complicated
#pod algorithm for set and bag matching. Something for the future...
#pod
#pod =head1 WHAT ARE SPECIAL COMPARISONS?
#pod
#pod A special comparison (SC) is simply an object that inherits from
#pod Test::Deep::Cmp. Whenever C<$expected_v> is an SC then instead of checking
#pod C<$got_v eq $expected_v>, we pass control over to the SC and let it do its
#pod thing.
#pod
#pod Test::Deep exports lots of SC constructors, to make it easy for you to use
#pod them in your test scripts. For example is C<re("hello")> is just a handy way
#pod of creating a Test::Deep::Regexp object that will match any string containing
#pod "hello". So
#pod
#pod   cmp_deeply([ 'a', 'b', 'hello world'], ['a', 'b', re("^hello")]);
#pod
#pod will check C<'a' eq 'a'>, C<'b' eq 'b'> but when it comes to comparing
#pod C<'hello world'> and C<re("^hello")> it will see that
#pod $expected_v is an SC and so will pass control to the Test::Deep::Regexp class
#pod by do something like C<< $expected_v->descend($got_v) >>. The C<descend()>
#pod method should just return true or false.
#pod
#pod This gives you enough to write your own SCs but I haven't documented how
#pod diagnostics works because it's about to get an overhaul (theoretically).
#pod
#pod =head1 EXPORTS
#pod
#pod By default, Test::Deep will export everything in its C<v0> tag, as if you had
#pod written:
#pod
#pod   use Test::Deep ':v0';
#pod
#pod Those things are:
#pod
#pod   all any array array_each arrayelementsonly arraylength arraylengthonly bag
#pod   blessed bool cmp_bag cmp_deeply cmp_methods cmp_set code eq_deeply hash
#pod   hash_each hashkeys hashkeysonly ignore Isa isa listmethods methods noclass
#pod   none noneof num obj_isa re reftype regexpmatches regexponly regexpref
#pod   regexprefonly scalarrefonly scalref set shallow str subbagof subhashof
#pod   subsetof superbagof superhashof supersetof useclass
#pod
#pod A slightly better set of exports is the C<v1> set.  It's all the same things,
#pod with the exception of C<Isa> and C<blessed>.  If you want to import
#pod "everything", you probably want to C<< use Test::Deep ':V1'; >>.
#pod
#pod There's another magic export group:  C<:preload>.  If that is specified, all of
#pod the Test::Deep plugins will be loaded immediately instead of lazily.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Test::More>
#pod
#pod =head1 THANKS
#pod
#pod Thanks to Michael G Schwern for Test::More's is_deeply function which inspired
#pod this library.
#pod
#pod =cut
