use strict;
use warnings;

package Test::Deep::Cache 1.204;

use Test::Deep::Cache::Simple;

sub new
{
  my $pkg = shift;

  my $self = bless {}, $pkg;

  $self->{expects} = [Test::Deep::Cache::Simple->new];
  $self->{normal} = [Test::Deep::Cache::Simple->new];

  $self->local;

  return $self;
}

sub add
{
  my $self = shift;

  my $type = $self->type;

  $self->{$type}->[-1]->add(@_);
}

sub cmp
{
  # go through all the caches to see if we know this one

  my $self = shift;

  my $type = $self->type;

  foreach my $cache (@{$self->{$type}})
  {
    return 1 if $cache->cmp(@_);
  }

  return 0
}

sub local
{
  my $self = shift;

  foreach my $type (qw( expects normal ))
  {
    push(@{$self->{$type}}, Test::Deep::Cache::Simple->new);
  }
}

sub finish
{
  my $self = shift;

  my $keep = shift;

  foreach my $type (qw( expects normal ))
  {
    my $caches = $self->{$type};

    my $last = pop @$caches;

    $caches->[-1]->absorb($last) if $keep;
  }
}

sub type
{
  return $Test::Deep::Expects ? "expects" : "normal";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Cache

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
