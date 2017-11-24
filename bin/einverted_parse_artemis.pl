#!/usr/bin/perl
use strict;

#################################################
#################################################
# SCRIPT NAME:  emboss_inverted_repeats_parser
# FUNCTION:     converts emboss ouput to Artemis readable format
# AUTHOR:       Adrian Tett (adet@ceh.ac.uk)
#################################################
                                                                                
my $file1 = $ARGV[0];
my $output = $ARGV[1];

my @lines;
my $line;
my $note;

open (IN, $file1) or die "ooops can't open file: $file1";
open OUT, "> $output" or die "can't open $output";

@lines = <IN>;
	foreach $line(@lines) {
	chomp ($line);
	$line =~ s/^\s+//;
	if ($line =~ /Score/) {
		 $note = $line;
		print "$note\n";
		}		
	if ($line =~ /^\d/) {
	my ($start, $seq, $end) = split/\s+/, $line; 	
print "$seq\n";
print OUT "FT   repeat_region   $start..$end\n";
print OUT "FT                   \/REPEAT_TYPE=\"inverted\"\n";
print OUT "FT                   \/note\=\"from emboss einverted $note, sequence $seq\"\n";
}
}

close IN;
close OUT;





