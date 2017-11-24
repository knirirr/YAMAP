#!/usr/bin/perl
use strict;                                                                                
#################################################
#################################################
# SCRIPT NAME:  emboss_palindrome_repeats_parser
# FUNCTION:     converts emboss ouput to Artemis readable format
# AUTHOR:       Adrian Tett (adet@ceh.ac.uk)
#################################################
                                                                                
my $file1 = $ARGV[0];
my $output = $ARGV[1];
my @lines;
my $line;

open (IN, $file1) or die "ooops can't open file: $file1";
open OUT, "> $output" or die "can't open $output";

@lines = <IN>;
	foreach $line(@lines) {
	chomp ($line);
	$line =~ s/^\s+//;
	if ($line =~ /^\d/) {
	my ($start, $seq, $end) = split/\s+/, $line; 	
print "$seq\n";
print OUT "FT   repeat_region   $start..$end\n";
print OUT "FT                   \/REPEAT_TYPE=\"palindrome\"\n";
print OUT "FT                   \/note\=\"from emboss palindrome, sequence $seq\"\n";
}
}

close IN;
close OUT;





