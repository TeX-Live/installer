use strict;
use warnings;

package Test::Deep::Cmp 1.204;

use overload
  '&' => \&make_all,
  '|' => \&make_any,
  '""' => \&string,
  fallback => 1,
;

use Scalar::Util ();

sub import
{
  my $pkg = shift;

  my $callpkg = caller();
  if ($callpkg =~ /^Test::Deep::/)
  {
    no strict 'refs';

    push @{$callpkg."::ISA"}, $pkg;
  }
}

sub new
{
  my $pkg = shift;

  my $self = bless {}, $pkg;

  $self->init(@_);
  return $self;
}

sub init
{
}

sub make_all
{
  my ($e1, $e2) = @_;

  return Test::Deep::all($e1, $e2);
}

sub make_any
{
  my ($e1, $e2) = @_;

  return Test::Deep::any($e1, $e2);
}

sub cmp
{
  my ($a1, $a2, $rev) = @_;

  ($a1, $a2) = ($a2, $a1) if $rev;

  return (overload::StrVal($a1) cmp overload::StrVal($a2));
}

sub string
{
  my $self = shift;

  return overload::StrVal($self);
}

sub render_stack
{
  my $self = shift;
  my $var = shift;

  return $var;
}

sub renderExp
{
  my $self = shift;

  return $self->renderGot($self->{val});
}

sub renderGot
{
  my $self = shift;

  return Test::Deep::render_val(@_);
}

sub reset_arrow
{
  return 1;
}

sub data
{
  my $self = shift;

  return $Test::Deep::Stack->getLast;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Cmp

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
