#!/usr/bin/perl

use warnings;
use Data::Dumper;
use DBI;
$/ = "\r\n";

my $dbh = DBI->connect("DBI:CSV:f_dir=.;csv_eol=\n;");
$dbh->{'csv_tables'}->{'data'} = { 'file' => 'EURUSD_080817_081231.csv'};

sub BuildEMA_old {
	my %EMA;
	my $period = $_[0];
	my $alpha = 2/($period + 1);
	my $prevEMA = "";

	my $buildema_query = "select DATE,TIME,CLOSE from data";
	my $sth = $dbh->prepare($buildema_query);
	$sth->execute();

	while (my $row = $sth->fetchrow_hashref) {
		if ($prevEMA eq "") {
			$prevEMA = $row->{'CLOSE'};
		} else {
			$prevEMA = $alpha*($row->{'CLOSE'}) + (1 - $alpha)*$prevEMA;
		}
		$EMA{($row->{'DATE'})." ".($row->{'TIME'})} = $prevEMA;
	}
	return %EMA
}


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

##### MAIN #####

my %PRICES = BuildPrices();
our (%COMPARE1,%COMPARE2);

%COMPARE1 = BuildEMA(10,\%PRICES);
%COMPARE2 = BuildEMA(25,\%PRICES);
%COMPARE3 = BuildEMA(50,\%PRICES);


#print "hash sizes are ".scalar(keys %PRICES).", ".scalar(keys %COMPARE1).", ".scalar(keys %COMPARE2).", ".scalar(keys %COMPARE3)."\n";

my ($prevCompare, @currSlice);
foreach my $currTime (sort keys %PRICES) {
	#print "$currTime: ";
	#if (Compare(\%COMPARE1,\%COMPARE2,\%COMPARE1,\%COMPARE3,$currTime) > 0) {
	#	#print "POSITIVE\n";
	#} elsif (Compare(\%COMPARE1,\%COMPARE2,\%COMPARE1,\%COMPARE3,$currTime) < 0) {
	#	#print "NEGATIVE\n";
	#} else {
	#	#print "DISAGREEMENT\n";
	#}

	push (@currSlice,$currTime);
	if (!(Compare(\%COMPARE1,\%COMPARE2,\%COMPARE1,\%COMPARE3,$currTime) == $prevCompare)) {
		pop(@currSlice);
	} else {
		#Process(\@currSlice);
		@currSlice = {};
	}
		$prevCompare = Compare(\%COMPARE1,\%COMPARE2,\%COMPARE1,\%COMPARE3,$currTime); 
		
}
