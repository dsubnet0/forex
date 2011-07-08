#!/usr/bin/perl

use Data::Dumper;

my @a = (a..z);
my %h;

my $i=0;
foreach (@a) {
	$h{$_} = $i++;
}
############################
my $conditions_met = 0;
foreach (sort keys %h) {
	
}








