use strict;
use warnings;

package Test::Deep::None 1.204;

use Test::Deep::Cmp;

sub init
{
  my $self = shift;

  my @list = map {
    eval { $_->isa('Test::Deep::None') }
    ? @{ $_->{val} }
    : $_
  } @_;

  $self->{val} = \@list;
}

sub descend
{
  my $self = shift;
  my $got = shift;

  foreach my $cmp (@{$self->{val}})
  {
    return 0 if Test::Deep::eq_deeply_cache($got, $cmp);
  }

  return 1;
}

sub renderExp
{
  my $self = shift;

  my @expect = map {; Test::Deep::wrap($_) } @{ $self->{val} };
  my $things = join(", ", map {$_->renderExp} @expect);

  return "None of ( $things )";
}

sub diagnostics
{
  my $self = shift;
  my ($where, $last) = @_;

  my $got = $self->renderGot($last->{got});
  my $exp = $self->renderExp;

  my $diag = <<EOM;
Comparing $where with None
got      : $got
expected : $exp
EOM

  $diag =~ s/\n+$/\n/;
  return $diag;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::None

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
