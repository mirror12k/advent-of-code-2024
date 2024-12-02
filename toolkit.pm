use strict;
use warnings;

use feature qw/ say /;
use Data::Dumper;

sub sum { my $s = 0; foreach my $n (@_) { $s += $n } $s }
sub product { my $p = 1; foreach my $n (@_) { $p *= $n } $p }
sub min { (sort { $a <=> $b } @_)[0] }
sub max { (sort { $a <=> $b } @_)[-1] }
sub reduce (&$@) { my ($fun, $reduced, @values) = @_; for (@values) { $reduced = $fun->($reduced, $_) } $reduced }
sub freq { my %freq; $freq{$_}++ for @_; return %freq; }
sub all (&@) { my ($fun, @args) = @_; foreach (@args) { return 0 unless $fun->() } return 1 }
sub none (&@) { my ($fun, @args) = @_; foreach (@args) { return 0 if $fun->() } return 1 }
# n-dimensional mapper function
sub map_nd {
	my ($fun, $arr) = @_;
	return [ map { $fun->($_) } @$arr ] if (@$arr >= 0 and ref $arr->[0] ne 'ARRAY');
	return [ map map_nd($fun, $_), @$arr ];
}
# Function to determine the dimensionality and lengths in each dimension of an n-dimensional array
sub shape {
	my ($arr) = @_;
	my @dims;
	while (ref $arr eq 'ARRAY') {
		push @dims, scalar @$arr;
		$arr = $arr->[0];
	}
	return @dims;
}
# n-dimensional flatten function
sub flatten_nd {
	my ($arr) = @_;
	return @$arr if (@$arr >= 0 and ref $arr->[0] ne 'ARRAY');
	return map flatten_nd($_), @$arr;
}
# n-dimensional mapper function with coordinates
sub map_nd_indexed {
	my ($fun, $arr, $iter, @coords) = @_;
	$iter //= $arr;
	return [ map $fun->($arr, [ @coords, $_ ]), 0 .. $#$iter ] if (@$iter >= 0 and ref $iter->[0] ne 'ARRAY');
	return [ map map_nd_indexed($fun, $arr, $iter->[$_], @coords, $_), 0 .. $#$iter ];
}

sub parse_2d_string_array {
    my ($input) = @_;
    return [ map [ split ], grep $_, split /\n/, $input ];
}

sub transpose_2d (@) {
    my ($arr) = @_;
    return [ map { my $i = $_; [ map $_->[$i], @$arr ] } 0 .. $#{$arr->[0]} ]
}


1;
