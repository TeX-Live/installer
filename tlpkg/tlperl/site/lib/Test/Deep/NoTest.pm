use strict;
use warnings;

# this is for people who don't want Test::Builder to be loaded but want to
# use eq_deeply. It's a bit hacky...

package Test::Deep::NoTest 1.204;
# ABSTRACT: Use Test::Deep outside of the testing framework

our $NoTest;

{
  local $NoTest = 1;
  require Test::Deep;
}

sub import {
  my $import = Test::Deep->can("import");
  # make the stack look like it should for use Test::Deep
  my $pkg = shift;
  unshift(@_, "Test::Deep");
  push @_, '_notest';
  goto &$import;
}

1;

#pod =head1 SYNOPSIS
#pod
#pod   use Test::Deep::NoTest;
#pod
#pod   if (eq_deeply($a, $b)) {
#pod     print "they were deeply equal\n";
#pod   }
#pod
#pod =head1 DESCRIPTION
#pod
#pod This exports all the same things as Test::Deep but it does not load
#pod Test::Builder so it can be used in ordinary non-test situations.

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Deep::NoTest - Use Test::Deep outside of the testing framework

=head1 VERSION

version 1.204

=head1 SYNOPSIS

  use Test::Deep::NoTest;

  if (eq_deeply($a, $b)) {
    print "they were deeply equal\n";
  }

=head1 DESCRIPTION

This exports all the same things as Test::Deep but it does not load
Test::Builder so it can be used in ordinary non-test situations.

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
