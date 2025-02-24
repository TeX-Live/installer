use strict;
use warnings;

package Test::Deep::ArrayLength 1.204;

use Test::Deep::Ref;

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

  my $exp = $self->{val};

  return 0 unless $self->test_reftype($got, "ARRAY");

  return Test::Deep::descend($got, Test::Deep::arraylengthonly($exp));
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::ArrayLength

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
