use strict;
use warnings;

package Test::Deep::ArrayEach 1.204;

use Test::Deep::Cmp;
use Scalar::Util ();

sub init
{
  my $self = shift;

  my $val = shift;

  $self->{val} = $val;
}

sub descend
{
  my $self = shift;
  my $got = shift;

  return unless ref $got && Scalar::Util::reftype($got) eq 'ARRAY';
  my $exp = [ ($self->{val}) x @$got ];

  return Test::Deep::descend($got, $exp);
}

sub renderExp
{
  my $self = shift;
  my $exp = shift;

  return '[ ' . $self->SUPER::renderExp($self->{val}) . ', ... ]';
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::ArrayEach

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
