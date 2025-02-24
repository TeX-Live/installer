use strict;
use warnings;

package Test::Deep::MM 1.204;

sub import
{
  my $self = shift;

  my ($pkg) = caller();
  my $mpkg = $pkg."::Methods";
  foreach my $attr (@_)
  {
    if ($attr =~ /^[a-z]/)
    {
      no strict 'refs';
      *{$mpkg."::$attr"} = \&{$attr};
    }
    else
    {
      my $get_name = $mpkg."::get$attr";
      my $set_name = $mpkg."::set$attr";
      my $get_sub = sub {
        return $_[0]->{$attr};
      };
      my $set_sub = sub {
        return $_[0]->{$attr} = $_[1];
      };

      {
        no strict 'refs';
        *$get_name = $get_sub;
        *$set_name = $set_sub;
        push(@{$pkg."::ISA"}, $mpkg);
      }
    }
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
  my $self = shift;

  while (@_)
  {
    my $name = shift || confess("No name");

    my $method = "set$name";
    $self->$method(shift);
  }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::MM

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
