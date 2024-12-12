#!/usr/bin/env perl
package graphql;
use strict;
use warnings;

use feature qw/ say /;

use base 'Exporter';
our @EXPORT = qw/
	graphql_query
/;

use Data::Dumper;


sub parse_graphql_query {
	my ($query) = @_;
	my @tokens = tokenize_graphql($query);
	return parse_tokens(\@tokens);
}

# Tokenizer: breaks the query into tokens
sub tokenize_graphql {
	my ($query) = @_;
	$query =~ s/^\s+|\s+$//g;    # Trim leading and trailing whitespace
	my @tokens;
	while ($query =~ /
		([{}])|                   # Match braces
		([()])|                   # Match paren
		([a-z_][a-z0-9_]*)|       # Match field names
		([-+]?\d+)|               # Match numbers
		([,])|                    # Match commas
		(:)|                      # Match colons
		(\s+)                     # Match whitespace
	/xig) {
		push @tokens, $1 // $2 // $3 // $4 // $5 // $6 if defined ($1 // $2 // $3 // $4 // $5 // $6);
	}
	return @tokens;
}

# Recursive parser for GraphQL tokens
sub parse_tokens {
	my ($tokens, $result) = @_;
	$result //= {};

	die "expected '{' at block start, instead got $tokens->[0]" if $tokens->[0] ne '{';
	shift @$tokens;
	while (@$tokens) {
		my $token = shift @$tokens;
		# say "token: $token";
		if ($token eq '}') {
			last; # End of this level
		} elsif ($token =~ /^[a-zA-Z_]/) { # Field name
			my $name = $token;
			my $value = $token;
			if ($tokens->[0] eq ':') { # Argument key
				shift @$tokens; # Consume ':'
				$value = shift @$tokens; # Argument value
				# say "got $name -> $value";
			}

			$result->{$name} = { _key => $value };

			if ($tokens->[0] eq '(') {
                shift @$tokens; # Consume '('
                $result->{$name}{_params} = parse_params($tokens);
                die "expected ')' after parameters" unless shift @$tokens eq ')'; # Consume ')'
            }

			if ($tokens->[0] eq '{') { # Nested object
				$result->{$name}{_nested} = parse_tokens($tokens);
			}
		} else {
			die "unexpected token: $token";
		}
	}
	return $result;
}

# Helper function to parse parameters (e.g., x:-1, y:1)
sub parse_params {
    my ($tokens) = @_;
    my %params;

    while ($tokens->[0] ne ')') {
        my $key = shift @$tokens;
        die "expected argument key, got: $key" unless $key =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;

        die "expected ':' after argument key" unless shift @$tokens eq ':';

        my $value = shift @$tokens;
        die "expected argument value, got: $value" unless $value =~ /^[-+]?\d+(\.\d+)?|[a-zA-Z_][a-zA-Z0-9_]*$/;

        $params{$key} = $value;

        shift @$tokens if $tokens->[0] eq ',';
    }

    return \%params;
}

my @pos_table = 'a' .. 'z';

sub execute_graphql_code {
	my ($code, $context) = @_;
	my %result;
	return undef unless defined $context;

	# say Dumper $context;
	# say "exec: ", Dumper $code;
	foreach my $name (keys %$code) {
		my $key = $code->{$name}{_key};
		# say "wat: $name -> $code->{$name}";
		if (exists $context->{$key}) {
			my $val = $context->{$key};

			if (exists $code->{$name}{_params} or 'CODE' eq ref $val) {
				$val = $val->($context, $code->{$name}{_params});
				# say "got modified val:", Dumper $val;
			}
			if (exists $code->{$name}{_nested}) {
				# say "recurse:", Dumper $val;
				$val = execute_graphql_code($code->{$name}{_nested}, $val);
			}
			$result{$name} = $val;
		} else {
			die "Unsupported query key: $key, context is: " . Dumper $context;
		}
	}

	return \%result;
}

sub get_value {
	my ($arr, $coord) = @_;
	my $value = $arr;
	my () = map { $value = $_ < 0 ? undef : $value->[$_] } @$coord;
    return $value;
}

our %graphql_methods = (
    neighbor => sub {
        my ($self, $params) = @_;
        my $new_coord = [ map { $params->{"abs_$pos_table[$_]"} // ($self->{coord}[$_] + ($params->{"d$pos_table[$_]"} // 0)) } 0 .. $#{$self->{coord}} ];
        return get_context($self->{arr}, $new_coord);
    },
    delta => sub {
        my ($self, $params) = @_;
        my $new_coord = [ map { $params->{"abs_$pos_table[$_]"} // ($self->{coord}[$_] + ($params->{"d$pos_table[$_]"} // 0)) } 0 .. $#{$self->{coord}} ];
        my $ctx = get_context($self->{arr}, $new_coord);
        if (defined $ctx) {
            $ctx->{value} = ($self->{value} // 0) - ($ctx->{value} // 0);
        }
        return $ctx;
    },
);

$graphql::graphql_methods{where} = sub {
        my ($self, $params) = @_;
        return (defined ($self->{value}) and $self->{value} eq $params->{value}) ? $self : undef;
    };

sub get_context {
	my ($arr, $coord) = @_;

	for (@$coord) {
		if ($_ < 0) {
			return undef;
		}
	}

	my $value = get_value($arr, $coord);
	my $pos = { map { $pos_table[$_] => $coord->[$_] } 0 .. $#$coord };
	my $context = {
        arr => $arr,
		value => $value,
		pos => $pos,
        coord => $coord,
        %graphql_methods,
	};

	return $context;
}

sub graphql_query {
	my ($query) = @_;
	my $code = parse_graphql_query($query);
	# say Dumper $code;
	my $handler;
	$handler = sub {
		my $context = get_context(@_);
		return execute_graphql_code($code, $context);
	};
}

1;