use strict;
use warnings;

package Test::Deep::Number 1.204;

use Test::Deep::Cmp;

use Scalar::Util;

sub init
{
  my $self = shift;

  $self->{val} = shift(@_) + 0;
  $self->{tolerance} = shift;
}

sub descend
{
  my $self = shift;
  my $got = shift;
  $self->data->{got_string} = $got;
  {
    no warnings 'numeric';
    $got += 0;
  }

  $self->data->{got} = $got;
  if (defined(my $tolerance = $self->{tolerance}))
  {
    return abs($got - $self->{val}) <= $tolerance;
  }
  else
  {
    return $got == $self->{val};
  }
}

sub diag_message
{
  my $self = shift;

  my $where = shift;

  return "Comparing $where as a number";
}

sub renderGot
{
  my $self = shift;
  my $val = shift;

  my $got_string = $self->data->{got_string};
  if ("$val" ne "$got_string")
  {
    $got_string = $self->SUPER::renderGot($got_string);
    return "$val ($got_string)"
  }
  else
  {
    return $val;
  }
}
sub renderExp
{
  my $self = shift;

  my $exp = $self->{val};

  if (defined(my $tolerance = $self->{tolerance}))
  {
    return "$exp +/- $tolerance";
  }
  else
  {
    return $exp;
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Number

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
