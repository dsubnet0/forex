#!/usr/bin/perl

my @a = (1,1,2,3,5,8,13,21,34);

#my ($i,$j) = @a;
#print "i=$i, j=$j\n";
#shift(@a);
#
#my ($i,$j) = @a;
#print "i=$i, j=$j\n";

#foreach my $i (@a) {
#	print "My current indexes are $i and $j\n";
#}

my $k=0;
while ($k<=10) {
	my ($i,$j) = @a;
	print "i=$i, j=$j\n";
	shift(@a);
	$k++;
}
