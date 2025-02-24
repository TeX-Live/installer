use strict;
use warnings;

package Test::Deep::Regexp 1.204;

use Test::Deep::Cmp;
use Test::Deep::RegexpMatches;

sub init
{
  my $self = shift;

  my $val = shift;

  $val = ref $val ? $val : qr/$val/;

  $self->{val} = $val;

  if (my $matches = shift)
  {
    $self->{matches} = Test::Deep::regexpmatches($matches, $val);

    $self->{flags} = shift || "";
  }
}

sub descend
{
  my $self = shift;
  my $got = shift;

  my $re = $self->{val};
  if (my $match_exp = $self->{matches})
  {
    my $flags = $self->{flags};
    my @match_got;
    if ($flags eq "g")
    {
      @match_got = $got =~ /$re/g;
    }
    else
    {
      @match_got = $got =~ /$re/;
    }

    if (@match_got)
    {
      return Test::Deep::descend(\@match_got, $match_exp);
    }
    else
    {
      return 0;
    }
  }
  else
  {
    return ($got =~ $re) ? 1 : 0;
  }
}

sub diag_message
{
  my $self = shift;

  my $where = shift;

  return "Using Regexp on $where";
}

sub render_stack1
{
  my $self = shift;

  my $stack = shift;
  return "($stack =~ $self->{regex})";
}

sub renderExp
{
  my $self = shift;

  return "$self->{val}";
}

sub renderGot
{
  my $self = shift;
  my $got  = shift;

  if (defined (my $class = Scalar::Util::blessed($got)))
  {
    my $ostr = qq{$got};
    if ($ostr ne overload::StrVal($got))
    {
      return qq{'$ostr' (instance of $class)};
    }
  }

  return Test::Deep::render_val($got);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Regexp

=head1 VERSION

version 1.204

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 AUTHORS

=over 4

=item *

Fergal Daly

=item *

Ricardo SIGNES <cpan@semiotic.systems>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2003 by Fergal Daly.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
