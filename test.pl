#!/usr/bin/env perl
use strict;
use warnings;

use feature qw/ say /;

use Data::Dumper;

use toolkit;
use graphql;
use adventofcode;

# # Example usage
# my $query = "{ pos { x y } value neighbor(da:-1) { value } }";
# my $parsed_query = parse_graphql_query($query);
# say Dumper($parsed_query);


# Example usage
my $input =
	[ map [ map [ map [ map [ map [ map [1 .. 2], 1 .. 2 ], 1 .. 2 ], 1 .. 2 ], 1 .. 2 ], 1 .. 2 ], 1 .. 2 ];

say join ",", shape $input;
my $output = map_nd sub { $_[0] * 2 }, $input;

# say "loops: $loops";
# say Dumper($output);
say Dumper([sum flatten_nd $output]);

say Dumper map_nd_indexed sub { { value => $_[1], coord => $_[2] } }, [ [ [ 1 .. 2 ], [ 1 .. 2 ]]];
say Dumper map_nd_indexed graphql_query("{ pos { a b c } value diag: neighbor(da:1, db:1, dc:1) { value pos { a b } } }"), [ [ [ 1 .. 2 ], [ 3 .. 4 ] ], [ [ 5 .. 6 ], [ 7 .. 8 ] ] ];

say get_challenge('2023/day/11/input');
# say post_answer('2023/day/19/answer', 1, 1445);
