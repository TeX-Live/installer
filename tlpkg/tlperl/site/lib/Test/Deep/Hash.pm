use strict;
use warnings;

package Test::Deep::Hash 1.204;

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

  my $data = $self->data;

  return 0 unless Test::Deep::descend($got, $self->hash_keys($exp));

  return 0 unless $self->test_class($got);

  return Test::Deep::descend($got, $self->hash_elements($exp));
}

sub hash_elements
{
  require Test::Deep::HashElements;

  my $self = shift;

  return Test::Deep::HashElements->new(@_);
}

sub hash_keys
{
  require Test::Deep::HashKeys;

  my $self = shift;
  my $exp = shift;

  return Test::Deep::HashKeys->new(keys %$exp);
}

sub reset_arrow
{
  return 0;
}

package Test::Deep::SuperHash 1.204;

use base 'Test::Deep::Hash';

sub hash_elements
{
  require Test::Deep::HashElements;

  my $self = shift;

  return Test::Deep::SuperHashElements->new(@_);
}

sub hash_keys
{
  require Test::Deep::HashKeys;

  my $self = shift;
  my $exp = shift;

  return Test::Deep::SuperHashKeys->new(keys %$exp);
}

package Test::Deep::SubHash 1.204;

use base 'Test::Deep::Hash';

sub hash_elements
{
  require Test::Deep::HashElements;

  my $self = shift;

  return Test::Deep::SubHashElements->new(@_);
}

sub hash_keys
{
  require Test::Deep::HashKeys;

  my $self = shift;
  my $exp = shift;

  return Test::Deep::SubHashKeys->new(keys %$exp);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Hash

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
