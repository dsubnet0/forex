#!/usr/bin/perl

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
	my $maxValue = 0;
	#print "@arraySlice\n";
	foreach my $currKey (@arraySlice) {
		#print "currKey = $currKey => $HASH{$currKey}\n";
		if ($maxValue==0 || $HASH{$currKey} > $maxValue) {
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

sub Compare {
	my %COMPARE1 = %{$_[0]};
	my %COMPARE2 = %{$_[1]};
	my %COMPARE3 = %{$_[2]};
	my %COMPARE4 = %{$_[3]};
	my $key = $_[4];

	if ($COMPARE1{$key}>=$COMPARE2{$key} && $COMPARE3{$key}>=$COMPARE4{$key}) {
		return 1;
	} elsif ($COMPARE1{$key}<$COMPARE2{$key} && $COMPARE3{$key}<$COMPARE4{$key}) {
		return -1;
	} else {
		return 0;
	}
}


sub GetDayMax {
	our ($start,%HASH) = ($_[0],%{$_[1]});
	my $date = substr($start,0,8);
	$date++;
	my $end = "$date 000000";

	#print "Checking for max between $start and $end\n";
	return Max($start,$end,\%HASH);
}

sub InitializeWeights {
	my $size = $_[0];
	my @returnArray = ();

	for (my $i=0;$i<$size;$i++) {
		$returnArray[$i] = rand();
	}
	
	return @returnArray;
}

##### MAIN ##### 

my %PRICES = BuildPrices();

my %COMPARE1 = BuildEMA(10,\%PRICES);
my %COMPARE2 = BuildEMA(25,\%PRICES);
my %COMPARE3 = BuildEMA(50,\%PRICES);
my %CROSS1 = Cross(\%COMPARE1,\%COMPARE2);
my %CROSS2 = Cross(\%COMPARE1,\%COMPARE3);

my @weights = InitializeWeights(2);
my $eta = 0.01;
my ($input1,$input2,$output);
foreach my $currTime (sort keys %PRICES) {
	my $currRise = (GetDayMax($currTime,\%PRICES) - $PRICES{$currTime});
	if ($currRise >= 0.0030) {
		#print "$currTime:\n";
		$output = 1;
	} else {
		$output = 0;
	}

	# if $currTime is in (keys %CROSS1) and $CROSS1{$currTime} is 1, then set neuron1 to $CROSS1{$currTime}, else 0
	# same deal with %CROSS2 and neuron2

	if ($CROSS1{$currTime} == 1) {
		$input1 = 1;
	} else {
		$input1 = 0;
	}


	if ($CROSS2{$currTime} == 1) {
		$input2 = 1;
	} else {
		$input2 = 0;
	}

	$weights[0] += $eta * $input1 * (2*$output-1);
	$weights[1] += $eta * $input2 * (2*$output-1);
}

print Dumper(\@weights);
