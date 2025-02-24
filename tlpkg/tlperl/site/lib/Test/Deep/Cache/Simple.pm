use strict;
use warnings;

package Test::Deep::Cache::Simple 1.204;

use Carp qw( confess );

use Scalar::Util qw( refaddr );

BEGIN
{
  if (grep /^weaken$/, @Scalar::Util::EXPORT_FAIL)
  {
    # we're running on a version of perl that has no weak refs, so we
    # just install a no-op sub for weaken instead of importing it
    *weaken = sub {};
  }
  else
  {
    Scalar::Util->import('weaken');
  }
}

sub new
{
  my $pkg = shift;

  my $self = bless {}, $pkg;

  return $self;
}

sub add
{
  my $self = shift;

  my ($d1, $d2) = @_;
  {
    local $SIG{__DIE__};

    local $@;

    # cannot weaken read only refs, no harm if we can't as they never
    # disappear
    eval{weaken($d1)};
    eval{weaken($d2)};
  }

  $self->{fn_get_key(@_)} = [$d1, $d2];
}

sub cmp
{
  my $self = shift;

  my $key = fn_get_key(@_);
  my $pair = $self->{$key};

  # are both weakened refs still valid, if not delete this entry
  if (ref($pair->[0]) and ref($pair->[1]))
  {
    return 1;
  }
  else
  {
    delete $self->{$key};
    return 0;
  }
}

sub absorb
{
  my $self = shift;

  my $other = shift;

  @{$self}{keys %$other} = values %$other;
}

sub fn_get_key
{
  return join(",", sort (map {refaddr($_)} @_));
}
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Cache::Simple

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
