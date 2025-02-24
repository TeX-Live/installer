package ExtUtils::Helpers::Windows;
$ExtUtils::Helpers::Windows::VERSION = '0.028';
use strict;
use warnings FATAL => 'all';

use Exporter 5.57 'import';
our @EXPORT = qw/make_executable split_like_shell detildefy/;

use Config;
use Carp qw/carp croak/;
use ExtUtils::PL2Bat 'pl2bat';

sub make_executable {
	my $script = shift;
	if (-T $script && $script !~ / \. (?:bat|cmd) $ /x) {
		pl2bat(in => $script, update => 1);
	}
	return;
}

sub split_like_shell {
	# As it turns out, Windows command-parsing is very different from
	# Unix command-parsing.	Double-quotes mean different things,
	# backslashes don't necessarily mean escapes, and so on.	So we
	# can't use Text::ParseWords::shellwords() to break a command string
	# into words.	The algorithm below was bashed out by Randy and Ken
	# (mostly Randy), and there are a lot of regression tests, so we
	# should feel free to adjust if desired.

	local ($_) = @_;

	my @argv;
	return @argv unless defined && length;

	my $arg = '';
	my ($i, $quote_mode ) = ( 0, 0 );

	while ( $i < length ) {

		my $ch      = substr $_, $i, 1;
		my $next_ch = substr $_, $i+1, 1;

		if ( $ch eq '\\' && $next_ch eq '"' ) {
			$arg .= '"';
			$i++;
		} elsif ( $ch eq '\\' && $next_ch eq '\\' ) {
			$arg .= '\\';
			$i++;
		} elsif ( $ch eq '"' && $next_ch eq '"' && $quote_mode ) {
			$quote_mode = !$quote_mode;
			$arg .= '"';
			$i++;
		} elsif ( $ch eq '"' && $next_ch eq '"' && !$quote_mode &&
				( $i + 2 == length() || substr( $_, $i + 2, 1 ) eq ' ' )
			) { # for cases like: a"" => [ 'a' ]
			push @argv, $arg;
			$arg = '';
			$i += 2;
		} elsif ( $ch eq '"' ) {
			$quote_mode = !$quote_mode;
		} elsif ( $ch =~ /\s/ && !$quote_mode ) {
			push @argv, $arg if $arg;
			$arg = '';
			++$i while substr( $_, $i + 1, 1 ) =~ /\s/;
		} else {
			$arg .= $ch;
		}

		$i++;
	}

	push @argv, $arg if defined $arg && length $arg;
	return @argv;
}

sub detildefy {
	my $value = shift;
	$value =~ s{ ^ ~ (?= [/\\] | $ ) }[$ENV{USERPROFILE}]x if $ENV{USERPROFILE};
	return $value;
}

1;

# ABSTRACT: Windows specific helper bits

__END__

=pod

=encoding UTF-8

=head1 NAME

ExtUtils::Helpers::Windows - Windows specific helper bits

=head1 VERSION

version 0.028

=for Pod::Coverage make_executable
split_like_shell
detildefy

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
