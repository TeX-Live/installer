use strict;
use warnings;

package Test::Deep::Stack 1.204;

use Carp qw( confess );
use Scalar::Util;

use Test::Deep::MM qw( new init Stack Arrow );

sub init
{
  my $self = shift;

  $self->SUPER::init(@_);

  $self->setStack([]) unless $self->getStack;
}

sub push
{
  my $self = shift;

  push(@{$self->getStack}, @_);
}

sub pop
{
  my $self = shift;

  return pop @{$self->getStack};
}

sub render
{
  my $self = shift;
  my $var = shift;

  my $stack = $self->getStack;

  $self->setArrow(0);

  foreach my $data (@$stack)
  {
    my $exp = $data->{exp};
    if (Scalar::Util::blessed($exp) and $exp->isa("Test::Deep::Cmp"))
    {
      $var = $exp->render_stack($var, $data);

      $self->setArrow(0) if $exp->reset_arrow;
    }
    else
    {
      confess "Don't know how to render '$exp'";
    }
  }

  return $var;
}

sub getLast
{
  my $self = shift;

  return $self->getStack->[-1];
}

sub incArrow
{
  my $self = shift;

  my $a = $self->getArrow;
  $self->setArrow($a + 1);

  return $a;
}

sub length
{
  my $self = shift;

  return @{$self->getStack} + 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Stack

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
