package ExtUtils::Config::MakeMaker;
$ExtUtils::Config::MakeMaker::VERSION = '0.010';
use strict;
use warnings;

use ExtUtils::MakeMaker::Config;

sub new {
    my ($class, $maker) = @_;
    return bless { maker => $maker }, $class;
}

sub get {
    my ($self, $key) = @_;
    return exists $self->{maker}{uc $key} ? $self->{maker}{uc $key} : $Config{$key};
}

sub exists {
    my ($self, $key) = @_;
	return exists $Config{$key};
}

sub all_config {
	my $self = shift;
	my %result;
	for my $key (keys %Config) {
		$result{$key} = $self->get($key);
	}
	return \%result;
}

sub values_set {
	my $self = shift;
	my %result;
	for my $key (keys %Config) {
		next if not exists $self->{maker}{uc $key};
		next if $self->{maker}{uc $key} eq $Config{$key};
		$result{$key} = $self->{maker}{uc $key};
	}
	return \%result;
}

sub serialize {
	my $self = shift;
	require Data::Dumper;
	return $self->{serialized} ||= Data::Dumper->new($self->values_set)->Terse(1)->Sortkeys(1)->Dump;
}

sub materialize {
	my $self = shift;
	require ExtUtils::Config;
	return ExtUtils::Config->new($self->values_set);
}

sub but {
	my ($self, %args) = @_;
	return $self->materialize->but(%args);
}

1;

#ABSTRACT: A ExtUtils::Config compatible wrapper for ExtUtils::MakeMaker's configuration.

__END__

=pod

=encoding UTF-8

=head1 NAME

ExtUtils::Config::MakeMaker - A ExtUtils::Config compatible wrapper for ExtUtils::MakeMaker's configuration.

=head1 VERSION

version 0.010

=head1 SYNOPSIS

 my $config = ExtUtils::Config::MakeMaker->new($makemaker);

=head1 DESCRIPTION

This object wraps L<ExtUtils::MakeMaker|ExtUtils::MakeMaker>'s idea of configuration in an L<ExtUtils::Config|ExtUtils::Config> compatible interface. That means that if you pass a configuration argument to or in Makefile.PL (e.g. C<OPTIMIZE=-O3>) it will show up in the config object (e.g. C<$config->get('optimize')>.

=head1 METHODS

=head2 new($makemaker)

This creates a new C<ExtUtils::Config::MakeMaker> object from a MakeMaker object.

=head2 get($key)

Get the value of C<$key>. If not overridden it will return the value in %Config.

=head2 exists($key)

Tests for the existence of $key.

=head2 values_set()

Get a hashref of all overridden values.

=head2 all_config()

Get a hashref of the complete configuration, including overrides.

=head2 serialize()

This method serializes the object to some kind of string. This can be useful for various caching purposes.

=head2 materialize()

This turns this object into an actual C<ExtUtils::Config> object.

=head2 but(%config)

This returns a C<ExtUtils::Config> object based on the current one but with the given entries overriden. If any value is C<undef> it will revert to the official C<%Config> value instead.

=head1 AUTHORS

=over 4

=item *

Ken Williams <kwilliams@cpan.org>

=item *

Leon Timmermans <leont@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2006 by Ken Williams, Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
