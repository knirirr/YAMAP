#!/usr/bin/perl 
use strict;

####################################
# SCRIPT NAME: 	Emboss_repeat_tandem_parser
# FUNCTION: 	coverts Emboss results to artemis readable file
# Author: 	Adrian Tett (adet@ceh.ac.uk)
####################################

my $file = $ARGV[0];
my $output = $ARGV[1];
my @lines;
my $line;
open (IN, $file) or die "Can't open file $file: $!";
open OUT, ">$output" or die "Can't open $output: $!";

# read lines, clear white space at the start and at the end of a string

@lines = <IN>;
	foreach $line(@lines) {
	chomp ($line);
	$line =~ s/^\s+//;
	if ($line =~ /^\d/) {
	my ($start, $end, $score, $size, $count, $identity, $consensus) = split/\s+/, $line;
	print "$start, $end, $score, $size, $count, $identity, $consensus\n";
	print OUT "FT   repeat_region   $start..$end\n";
	print OUT "FT                   \/REPEAT_TYPE=\"tandem\"\n";
	print OUT "FT                   \/score\=$score\n";
	print OUT "FT                   \/id\=\"$identity\"\n";
	print OUT "FT                   \/note\=\"from emboss etandem, size $size, count $count, consensus $consensus\"\n";
}
}

close IN;
close OUT;




