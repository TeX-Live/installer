use strict;
use warnings;

package Test::Deep::HashKeysOnly 1.204;

use Test::Deep::Ref;

sub init
{
  my $self = shift;

  my %keys;
  @keys{@_} = ();
  $self->{val} = \%keys;
  $self->{keys} = [sort @_];
}

sub descend
{
  my $self = shift;
  my $hash = shift;

  my $data = $self->data;
  my $exp = $self->{val};
  my %got;
  @got{keys %$hash} = ();

  my @missing;
  my @extra;

  while (my ($key, $value) = each %$exp)
  {
    if (exists $got{$key})
    {
      delete $got{$key};
    }
    else
    {
      push(@missing, $key);
    }
  }

  my @diags;
  if (@missing and (not $self->ignoreMissing))
  {
    push(@diags, "Missing: ".nice_list(\@missing));
  }

  if (%got and (not $self->ignoreExtra))
  {
    push(@diags, "Extra: ".nice_list([keys %got]));
  }

  if (@diags)
  {
    $data->{diag} = join("\n", @diags);
    return 0;
  }

  return 1;
}

sub diagnostics
{
  my $self = shift;
  my ($where, $last) = @_;

  my $type = $self->{IgnoreDupes} ? "Set" : "Bag";

  my $error = $last->{diag};
  my $diag = <<EOM;
Comparing hash keys of $where
$error
EOM

  return $diag;
}

sub nice_list
{
  my $list = shift;

  return join(", ",
    (map {"'$_'"} sort @$list),
  );
}

sub ignoreMissing
{
  return 0;
}

sub ignoreExtra
{
  return 0;
}

package Test::Deep::SuperHashKeysOnly 1.204;

use base 'Test::Deep::HashKeysOnly';

sub ignoreMissing
{
  return 0;
}

sub ignoreExtra
{
  return 1;
}

package Test::Deep::SubHashKeysOnly 1.204;

use base 'Test::Deep::HashKeysOnly';

sub ignoreMissing
{
  return 1;
}

sub ignoreExtra
{
  return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::HashKeysOnly

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
