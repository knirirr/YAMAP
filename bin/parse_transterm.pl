#!/usr/bin/perl

# A script to parse the output of TransTerm

use strict;
use File::Basename;

# usage
unless (@ARGV)
{
	print "Usage: ./parse_transterm.pl <infile> <outfile>\n";
	exit;
}

my $infile = shift;
my $outfile = shift;

open (IN, "<$infile") or die "Can't open $infile: $!";
my @lines = <IN>;
close IN;

# because the interesting stuff is on two lines, it is necessary
# to store it and print it out later
my %lineinfo;

open (OUT, ">$outfile") or die "Can't open $outfile: $!";
my $number;
my $oldnumber;
foreach my $line (@lines)
{
		# Each terminator entry starts in column 3 and is of the form:
		# term #       start - end      +/-  regionconf   hp     tail | notes
		# Followed by the sequence of the 5' tail, 5' stem, loop, 3' stem, and 3' tail.
		
		if ($line =~ /^\s+TERM/)
		{
			$line =~ s/^\s+//;
			chomp($line);
			my @parts = split(/\s+/,$line);
			my $number = $parts[1];
			my $seq_start = $parts[2]; 
			my $seq_end = $parts[4];
			$lineinfo{$number}{number} = $number;
			$lineinfo{$number}{direction} = "$parts[5]ve";
			$lineinfo{$number}{regionconf} = $parts[6];
			$lineinfo{$number}{conf} = $parts[7];
			$lineinfo{$number}{notes} = [split(/\|/,$line)]->[-1];
			if ($seq_start <= $seq_end)
			{
				$lineinfo{$number}{lineout} = "$seq_start..$seq_end";
			}
			else
			{
				$lineinfo{$number}{lineout} = "complement($seq_end..$seq_start)";
			}
			$oldnumber = $number;
		}
		elsif ($line =~ /^\s+[GATC]+/)
		{
			$line =~ s/^\s+//;
			chomp($line);
			my @parts = split(/\s+/,$line);
			$lineinfo{$oldnumber}{tail_5} = $parts[0];
			$lineinfo{$oldnumber}{stem_5} = $parts[1];
			$lineinfo{$oldnumber}{loop} = $parts[2];
			$lineinfo{$oldnumber}{stem_3} = $parts[3];
			$lineinfo{$oldnumber}{tail_3} = $parts[4];
		}
		else
		{
			next;
		}
	}

	# dont' bother printingif we haven't started 
	# counting TERMs yet
	# now print each thing out
	foreach my $num (sort {$a <=> $b} keys %lineinfo)
	{
		# print to tab file
		print OUT <<EOF;
FT   stem_loop       $lineinfo{$num}{lineout}
FT                   /label="stem_loop $lineinfo{$num}{number}"
FT                   /colour=12 153 210
FT                   /note="detected with transterm" 
FT                   /note="direction: $lineinfo{$num}{direction}, Loc: $lineinfo{$num}{regionconf}, confidence: $lineinfo{$num}{conf}, notes: $lineinfo{$num}{notes}"  
FT                   /note="5-prime tail seq $lineinfo{$num}{tail_5}"
FT                   /note="5-prime stem seq $lineinfo{$num}{stem_5}"
FT                   /note="loop seq $lineinfo{$num}{loop}"
FT                   /note="3-prime stem seq $lineinfo{$num}{stem_3}"
FT                   /note="3-prime tail seq $lineinfo{$num}{tail_3}"
EOF
}

close OUT;

__END__
