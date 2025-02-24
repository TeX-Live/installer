use strict;
use warnings;
package Test2::Warnings;
# vim: set ts=8 sts=2 sw=2 tw=100 et :
# ABSTRACT: Test for warnings and the lack of them
# KEYWORDS: testing tests warnings Test2

our $VERSION = '0.038';

use parent 'Exporter';
use Test::Warnings;

sub import {
  goto \&Test::Warnings::import;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Warnings - Test for warnings and the lack of them

=head1 VERSION

version 0.038

=head1 SYNOPSIS

    use Test2::V0;
    use Test::Warnings;

    pass('yay!');
    done_testing;

emits TAP:

    ok 1 - yay!
    ok 2 - no (unexpected) warnings (via done_testing)
    1..2

and:

    use Test::More tests => 3;
    use Test::Warnings 0.005 ':all';

    pass('yay!');
    like(warning { warn "oh noes!" }, qr/^oh noes/, 'we warned');

emits TAP:

    ok 1 - yay!
    ok 2 - we warned
    ok 3 - no (unexpected) warnings (via END block)
    1..3

=head1 DESCRIPTION

See L<Test::Warnings> for full documentation.

For now, this is a simple wrapper around L<Test::Warnings>, but there is a plan to make this a full
port and eject all the old L<Test::Builder> compatibility and use the Test2 suite correctly.

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Warnings>
(or L<bug-Test-Warnings@rt.cpan.org|mailto:bug-Test-Warnings@rt.cpan.org>).

There is also a mailing list available for users of this distribution, at
L<http://lists.perl.org/list/perl-qa.html>.

There is also an irc channel available for users of this distribution, at
L<C<#perl> on C<irc.perl.org>|irc://irc.perl.org/#perl-qa>.

I am also usually active on irc, as 'ether' at C<irc.perl.org> and C<irc.libera.chat>.

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
