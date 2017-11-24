#!/usr/bin/perl -w


##################################################
# Creates artemis tab file from rbsfinder output #
##################################################

use strict;

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./rbs_parse_artemis.pl path2rbs path2output\nPlease try again.\n\n\n";}

my $path2rbs = shift;
my $path2output = shift;


my ($header, @lines, $rs, $line, @temp, $start, $stop, $codon);

open (IN, "$path2rbs");
@lines = <IN>;
close IN;
open (OUT, ">$path2output");

$header = 0;
$rs = "\t";

foreach $line (@lines)
{
	$header++;
	if ($header > 2)
	{
		$line =~s/\s+/$rs/g;
	#	print "$line\n";
		@temp = split /$rs/, $line;
		$start = $temp[2];
		$stop = $temp[3];
		$codon = $temp[6];
		if ($start > $stop)
		{
			print OUT "FT   CDS             complement($stop"."..$start)\n";
			print OUT "FT                   /colour=5\n";
			print OUT "FT                   /note=\"predicted using RBSfinder from Glimmer output\"\n";
		}
		else
		{
			print OUT "FT   CDS             $start"."..$stop\n";
			print OUT "FT                   /colour=5\n";
			print OUT "FT                   /note=\"predicted using RBSfinder from Glimmer output\"\n";
		}
	}
}
