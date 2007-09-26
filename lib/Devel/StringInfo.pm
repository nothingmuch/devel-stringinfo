#!/usr/bin/perl

package Devel::StringInfo;
use Moose;

our $VERSION = "0.01";

use utf8 ();
use Encode qw(decode encode);
use Encode::Guess ();
use Scalar::Util qw(looks_like_number);
use Tie::IxHash;

has omit_false => (
	isa => "Bool",
	is  => "rw",
	default => 1,
);

has guess_encoding => (
	isa => "Bool",
	is  => "rw",
	default => 1,
);

has encoding_suspects => (
	isa => "ArrayRef",
	is  => "rw",
	auto_deref => 1,
	default    => sub { [] },
);

has include_decoded => (
	isa => "Bool",
	is  => "rw",
	default => 1,
);

has guess_if_valid => (
	isa => "Bool",
	is  => "rw",
	default => 1,
);

has include_value_info => (
	isa => "Bool",
	is  => "rw",
	default => 0,
);

sub sorted_hash {
	my ( @args ) = @_;
	tie my %hash, 'Tie::IxHash', @args;
	return \%hash,
}

sub dump_info {
	my ( $self, $string, @args ) = @_;

	require YAML;
	local $YAML::SortKeys = 0; # let IxHash decide
	local $YAML::UseHeader = 0;
	my $dump = YAML::Dump(sorted_hash @args, $self->filter_data( $self->debug_data($string) ));

	if ( defined wantarray ) {
		return $dump;
	} else {
		warn "$dump\n";
	}
}

sub filter_data {
	my ( $self, @args ) = @_;

	return @args; # FIXME strip out false keys if omit_false, etc
}

sub debug_data {
	my ( $self, $string ) = @_;

	return (
		string => $string,
		$self->debug_data_unicode($string),
		( $self->include_value_info ? $self->debug_data_value($string) : () ),,
	);
}

sub debug_data_unicode {
	my ( $self, $string ) = @_;	

	if ( utf8::is_utf8($string) ) {
		return (
			$self->debug_data_is_unicode($string),
		);
	} else {
		return (
			$self->debug_data_is_octets($string),
		)
	}
}

sub debug_data_vlaue {
	my ( $self, $string ) = @_;

	for ( $string ) {
		return (
			is_alphanumeric   => 0+ /^[[:alnum:]]+$/s,
			is_printable      => 0+ /^[[:print:]+]$/s,
			is_ascii          => 0+ /^[[:ascii:]+]$/s,
			has_zero          => 0+ /\x{00}/s,
			has_line_ending   => 0+ /[\r\n]/s,
			looks_like_number => looks_like_number($string),
		);
	}	
}

sub debug_data_is_unicode {
	my ( $self, $string ) = @_;

	return (
		is_utf8      => 1,
		char_length  => length($string),
		octet_length => length(encode(utf8 => $string)),
		downgradable => 0+ do {
			my $copy = $string;
			utf8::downgrade($copy, 1); # fail OK
		},
	);
}

sub debug_data_is_octets {
	my ( $self, $string ) = @_;

	return (
		is_utf8      => 0,
		octet_length => length($string),
		( utf8::valid($string)
			? $self->debug_data_utf8_octets($string)
			: $self->debug_data_non_utf8_octets($string) ),
	);
}

sub debug_data_utf8_octets {
	my ( $self, $string ) = @_;

	my $decoded = decode( utf8 => $string );
	
	my $guessed = sorted_hash $self->debug_data_encoding_info($string);

	if ( ($guessed->{guessed_encoding}||'') eq 'utf8' ) {
		return (
			valid_utf8  => 1,
			( $self->include_decoded ? $self->debug_data_decoded( $decoded, $string ) : () ),,
		);
	} else {
		return (
			valid_utf8 => 1,
			( $self->include_decoded ? (
				as_utf8    => sorted_hash($self->debug_data_decoded( $decoded, $string ) ),
				as_guess   => $guessed,
			) : () ),
		);
	}
}

sub debug_data_non_utf8_octets {
	my ( $self, $string ) = @_;

	return (
		valid_utf8 => 0,
		$self->debug_data_encoding_info($string),
	);
}

sub debug_data_encoding_info {
	my ( $self, $string ) = @_;

	return unless $self->guess_encoding;

	my $decoder = Encode::Guess::guess_encoding( $string, $self->encoding_suspects );

	if ( ref $decoder ) {
		my $decoded = $decoder->decode($string);

		return (
			guessed_encoding => $decoder->name,
			( $self->include_decoded ? $self->debug_data_decoded( $decoded, $string ) : () ),
		);
	} else {
		return (
			guess_error => $decoder,
		);
	}
}

sub debug_data_decoded {
	my ( $self, $decoded, $string ) = @_;

	if ( $string ne $decoded ) {
		return (
			decoded_is_same => 0,
			decoded => {
				string => $decoded,
				$self->debug_data($decoded),
			}
		);
	} else {
		return (
			decoded_is_same => 1,
		);
	}
}

__PACKAGE__;

__END__
