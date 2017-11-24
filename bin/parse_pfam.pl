#!/usr/bin/perl

# A script to parse the output of pfam_scan.pl

use strict;
use File::Basename;

# usage
unless (@ARGV)
{
	print "Usage: ./parse_pfam.pl <infile> <outfile>\n";
	exit;
}

my $infile = shift;
my $outfile = shift;

open (IN, "<$infile") or die "Can't open $infile: $!";
my @lines = <IN>;
close IN;

open (OUT, ">$outfile") or die "Can't open $outfile: $!";
foreach my $line (@lines)
{
		# correct place
		# the start and stop locations are calculated from 
		# the original orf, the locations of which are
		# in the "trans" file name
		my @parts = split(/\s+/,$line);
		my $seq_id = $parts[0];
		my $hmm_acc = $parts[3]; 
		my $hmm_start = $parts[4];
		my $hmm_end = $parts[5];
		my $bit_score = $parts[6];
		my $evalue = $parts[7];
		my $hmm_name = $parts[8];
		my $positions = [split(/\./,$seq_id)]->[-2];
		my ($seq_start,$seq_end) = split(/-/,$positions);
		my $lineout;
		if ($seq_start < $seq_end)
		{
			$lineout = "$seq_start..$seq_end";
		}
		else
		{
			$lineout = "complement($seq_end..$seq_start)";
		}
		

		# print to tab file
		print OUT <<EOF;
FT   gene            $lineout
FT                   /note="PFAM match to $hmm_acc $hmm_start..$hmm_end  bit score $bit_score evalue $evalue"  
FT                   /label=$seq_id
FT                   /label=$hmm_name
FT                   /score=$bit_score
FT                   /colour=10 155 100
EOF
}

close OUT;


__END__
