#!/usr/bin/perl -w

use warnings;
use Data::Dumper;
use DBI;
$/ = "\r\n";

my $dbh = DBI->connect("DBI:CSV:f_dir=.;csv_eol=\n;");
$dbh->{'csv_tables'}->{'data'} = { 'file' => 'EURUSD_080817_081231.csv'};



sub BuildEMA {
	my %EMA;
	my $period = $_[0];
	my %HASH = %{$_[1]};
	my $alpha = 2/($period + 1);
	my $prevEMA = "";
	
	foreach my $currKey (sort keys %HASH) {
		if ($prevEMA eq "") {
			$prevEMA = $HASH{$currKey};
		} else {
			$prevEMA = $alpha*($HASH{$currKey}) + (1 - $alpha)*$prevEMA;
		}
		$EMA{$currKey} = $prevEMA;
	}
	return %EMA
}



sub BuildMACD {
	my %MACD;
	my %EMA12 = BuildEMA(12,\%{$_[0]});
	my %EMA26 = BuildEMA(26,\%{$_[0]});

	foreach my $currTime (sort keys %EMA12) {
		$MACD{$currTime} = $EMA12{$currTime} - $EMA26{$currTime};
	}
	return %MACD;
}


sub BuildPrices {
	my %PRICES;
	my $buildprices_query = "select DATE,TIME,CLOSE from data";
	my $sth = $dbh->prepare($buildprices_query);
	$sth->execute();
	while (my $row = $sth->fetchrow_hashref) {
		$PRICES{($row->{'DATE'})." ".($row->{'TIME'})} = $row->{'CLOSE'};	
	}
	return %PRICES;
}

sub FindIndex {
	our ($target,@array) = ($_[0],@{$_[1]});
	my $index = -1;
	for (my $i = 0; $i < @array; $i++) {
		if ($array[$i] eq $target) {
			$index = $i;
			last;
		}
	}
	return $index;
}


sub Max {
	our ($start,$end,%HASH) = ($_[0],$_[1],%{$_[2]});
	my @keyArray = (sort keys %HASH);
	my $i = FindIndex($start,\@keyArray);
	my $j = FindIndex($end,\@keyArray);
	my @arraySlice = splice(@keyArray,$i,$j-$i+1);
	foreach my $currKey (@arraySlice) {
		if (!($maxValue) || $HASH{$currKey} > $maxValue) {
			$maxValue = $HASH{$currKey};
		}
	}
	return $maxValue;	
}


sub Min {
	our ($start,$end,%HASH) = ($_[0],$_[1],%{$_[2]});
	my @keyArray = (sort keys %HASH);
	my $i = FindIndex($start,\@keyArray);
	my $j = FindIndex($end,\@keyArray);
	my @arraySlice = splice(@keyArray,$i,$j-$i+1);
	my $minValue;
	foreach my $currKey (@arraySlice) {
		if (!($minValue) || $HASH{$currKey} < $minValue) {
			$minValue = $HASH{$currKey};
		}
	}
	return $minValue;	
}



sub Cross {
	my %CROSS;
	my %DATA1 = %{$_[0]};
	my %DATA2 = %{$_[1]};

	our ($prev1,$prev2) = ("","");

## TODO: Code to check that keys are identical in data hashes

	foreach my $currTime (sort keys %DATA1) {
		if(($prev1 eq "" || $prev2 eq "")) {
			$prev1 = $DATA1{$currTime};
			$prev2 = $DATA2{$currTime};
			next;
		}

		if (($DATA1{$currTime} > $DATA2{$currTime}) && !($prev1>$prev2)) {
			$CROSS{$currTime} = 1;	
		} elsif (($DATA1{$currTime} < $DATA2{$currTime}) && !($prev1<$prev2)) {
			$CROSS{$currTime} = -1;
		} 

		$prev1 = $DATA1{$currTime};
		$prev2 = $DATA2{$currTime};
	}

	return %CROSS;
}

sub Sum {
	my @data = @{$_[0]};
	my $total=0;
	while (@data) {
		$total+=pop(@data);	
	}
	return $total;
}

sub Average {
	my @data = @{$_[0]};
	return Sum(\@data)/@data;
}

##### MAIN #####

my %PRICES = BuildPrices();
our (%COMPARE1,%COMPARE2,%RESULTS);

#if ($ARGV[0] ne "MACD") {
#	%COMPARE1 = BuildEMA($ARGV[0],\%PRICES);
#	%COMPARE2 = BuildEMA($ARGV[1],\%PRICES);
#} else {
#	%COMPARE1 = BuildMACD(\%PRICES);
#	%COMPARE2 = BuildEMA(9,\%COMPARE1);
#}

for (my $i=10;$i<=100;$i+=5) {
for (my $j=5;$j<$i;$j+=5) {

%COMPARE1 = BuildEMA($j,\%PRICES);
%COMPARE2 = BuildEMA($i,\%PRICES);

my %CROSS= Cross(\%COMPARE1,\%COMPARE2);

my @cross_times= (sort keys %CROSS);

my @results;

for (my $i=0 ; $i < $#cross_times; $i++) {
	if ($CROSS{$cross_times[$i]} == 1) {
		push(@data,(Max($cross_times[$i],$cross_times[$i+1],\%PRICES) - $PRICES{$cross_times[$i]}));
	} elsif ($CROSS{$cross_times[$i]} == -1) {
		push(@data,($PRICES{$cross_times[$i]} - Min($cross_times[$i],$cross_times[$i+1],\%PRICES)));
	} else { print "Some issue constructing grabbing peaks."; }
}

print "$j x $i, ".Average(\@data)."\n";
$RESULTS{$j,$i} = Average(\@data);
#while (@data) {
#	print pop(@data)."\n";
#}

}
}

my $max=0;
for (keys %RESULTS) {
	$max = $RESULTS{$_} if ($RESULTS{$_}>$max);
}
print "Max = $max";
