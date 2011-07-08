#!/usr/bin/perl
use Data::Dumper;
my %HASH;

$HASH{'array1'} = {'a1','a2','a3'};

$HASH{'array2'} = {'b1','b2','b3'};

print Dumper(\%HASH);
