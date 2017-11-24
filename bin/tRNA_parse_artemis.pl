#!/usr/bin/perl -w


#################################################################
# Creates artemis tab file from tRNAscan output .
#################################################################

use strict;

unless (@ARGV ==2) 
{
	die "\n\nUsage:\n ./tRNA_parse_artemis.pl path2tRNA.out path2output\nPlease try again.\n\n\n";
}

my $path2tRNA = shift;
my $path2output = shift;

my ($header, @lines, $rs, $line, @temp, $start, $stop, $codon);

open (IN, "$path2tRNA");
@lines = <IN>;
close IN;
open (OUT, ">$path2output");

$header = 0;
$rs = "\t";

foreach $line (@lines)
{
	$header++;
	if ($header > 3)
	{
		$line =~s/\s+/$rs/g;
		print "$line\n";
		@temp = split /$rs/, $line;
		$start = $temp[2];
		$stop = $temp[3];
		$codon = $temp[5];
		if ($start > $stop)
		{
			print OUT "FT   tRNA            complement($stop"."..$start)\n";
			print OUT "FT                   /colour=3\n";
			print OUT "FT                   /note=\"predicted using tRNAscan-SE\"\n";
		}
		else
		{
			print OUT "FT   tRNA             $start"."..$stop\n";
			print OUT "FT                   /colour=3\n";
			print OUT "FT                   /note=\"predicted using tRNAscan-SE\"\n";
		}
	}
}
