#!/usr/bin/perl
use Data::Dumper;

my %HASH;

$HASH{"20090701,0"} = 1.5;
$HASH{"20090701,0100"} = 1.6;
$HASH{"20090701,0930"} = 1.4;
$HASH{"20090702,0"} = 1.7;
$HASH{"20090702,0100"} = 1.7;
$HASH{"20090702,0930"} = 1.5;

print Dumper(\%HASH);
