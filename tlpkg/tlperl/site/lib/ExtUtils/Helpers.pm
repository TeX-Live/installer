package ExtUtils::Helpers;
$ExtUtils::Helpers::VERSION = '0.028';
use strict;
use warnings FATAL => 'all';
use Exporter 5.57 'import';

use Config;
use File::Basename qw/basename/;
use File::Spec::Functions qw/splitpath canonpath abs2rel splitdir/;

our @EXPORT_OK = qw/make_executable split_like_shell man1_pagename man3_pagename detildefy/;

BEGIN {
	my %impl_for = ( MSWin32 => 'Windows', VMS => 'VMS');
	my $package = 'ExtUtils::Helpers::' . ($impl_for{$^O} || 'Unix');
	my $impl = $impl_for{$^O} || 'Unix';
	require "ExtUtils/Helpers/$impl.pm";
	"ExtUtils::Helpers::$impl"->import();
}

sub man1_pagename {
	my ($filename, $ext) = @_;
	$ext ||= $Config{man1ext};
	return basename($filename).".$ext";
}

my %separator = (
	MSWin32 => '.',
	VMS => '__',
	os2 => '.',
	cygwin => '.',
);
my $separator = $separator{$^O} || '::';

sub man3_pagename {
	my ($filename, $base, $ext) = @_;
	$base ||= 'lib';
	$ext  ||= $Config{man3ext};
	my ($vols, $dirs, $file) = splitpath(canonpath(abs2rel($filename, $base)));
	$file = basename($file, qw/.pm .pod/);
	my @dirs = grep { length } splitdir($dirs);
	return join $separator, @dirs, "$file.$ext";
}

1;

# ABSTRACT: Various portability utilities for module builders

__END__

=pod

=encoding utf-8

=head1 NAME

ExtUtils::Helpers - Various portability utilities for module builders

=head1 VERSION

version 0.028

=head1 SYNOPSIS

 use ExtUtils::Helpers qw/make_executable split_like_shell/;

 unshift @ARGV, split_like_shell($ENV{PROGRAM_OPTS});
 write_script_to('Build');
 make_executable('Build');

=head1 DESCRIPTION

This module provides various portable helper functions for module building modules.

=head1 FUNCTIONS

=head2 make_executable($filename)

This makes a perl script executable.

=head2 split_like_shell($string)

This function splits a string the same way as the local platform does.

=head2 detildefy($path)

This function substitutes a tilde at the start of a path with the users homedir in an appropriate manner.

=head2 man1_pagename($filename, $ext = $Config{man1ext})

Returns the man page filename for a script.

=head2 man3_pagename($filename, $basedir = 'lib', $ext = $Config{man3ext})

Returns the man page filename for a Perl library.

=head1 ACKNOWLEDGEMENTS

Olivier Mengué and Christian Walde made C<make_executable> work on Windows.

=head1 AUTHORS

=over 4

=item *

Ken Williams <kwilliams@cpan.org>

=item *

Leon Timmermans <leont@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ken Williams, Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
