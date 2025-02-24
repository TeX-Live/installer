use strict;
use warnings;

package Test::Deep::Methods 1.204;

use Test::Deep::Cmp;
use Scalar::Util;

sub init
{
  my $self = shift;

  # get them all into [$name,@args] => $value format
  my @methods;
  while (@_)
  {
    my $name = shift;
    my $value = shift;
    push(@methods,
      [
        ref($name) ? $name : [ $name ],
        $value
      ]
    );
  }
  $self->{methods} = \@methods;
}

sub descend
{
  my $self = shift;
  my $got = shift;

  my $data = $self->data;

  foreach my $method (@{$self->{methods}})
  {
    $data->{method} = $method;

    my ($call, $exp_res) = @$method;
    my ($name, @args) = @$call;

    local $@;

    my $got_res;
    if (! eval { $got_res = $self->call_method($got, $call); 1 }) {
      die $@ unless $@ =~ /\ACan't locate object method "\Q$name"/;
      $got_res = $Test::Deep::DNE;
    }

    next if Test::Deep::descend($got_res, $exp_res);

    return 0;
  }

  return 1;
}

sub call_method
{
  my $self = shift;
  my ($got, $call) = @_;
  my ($name, @args) = @$call;

  return $got->$name(@args);
}

sub render_stack
{
  my $self = shift;
  my ($var, $data) = @_;

  my $method = $data->{method};
  my ($call, $expect) = @$method;
  my ($name, @args) = @$call;

  my $args = @args ? "(".join(", ", @args).")" : "";
  $var .= "->$name$args";

  return $var;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::Methods

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
