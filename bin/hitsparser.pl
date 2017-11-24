#!/usr/bin/perl

##############################################
##############################################
# SCRIPT NAME:  hit_summarizer
# FUNCTION:    summarize *overview.html files created by get_orphans
# AUTHOR:       Cared for by Gareth Wilson (gawi@ceh.ac.uk)
##############################################

use strict;

# Takes an input file ending in .overview.html as an input

use Config::Simple;

###########################################################
# Parse the command line and die if it doesn't look right #
###########################################################


unless (@ARGV ==2) {
        die "\n\nProper Command Line Usage: hitsparser.pl *overview.html configfile \nPlease try again.\n\n\n";}

# shift the first command line arg passed through @ARGV
my $file = shift;
my $config_file = shift;

unless ($file =~ /overview\.html$/) {
        die "\n\n Your input file must end with overview.html\nPlease try again.\n\n
";}

# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);
my $path2output = $cfg ->param('PATHS.path2output');
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

#print "RECORD SEP $record_separator\n";


my (@lines, @header) = ();
open (IN, "$file") or die "can't open file: $file";

# pick up all lines in file
@lines = <IN>;
# get rid of summary line

my ($header, $junk, $seqs, $total, $total_minus_self, $i, $hits, $total_hits, $line, $total_hits, $last, @count, $total_species);


$junk = shift @lines;
$header = shift @lines;
chomp($header);
$seqs = @lines;


@header = split(/$record_separator/,$header);

$total = @header;
$total = $total - 1; # minus file name and 'self' column
# print some details of file

print "<PRE>";
print "path2 = $path2output, file = $file\n";
print "Total sequences in file: $seqs\n";
$total_minus_self = $total-2;
print "Unique Data Sets compared including SELF: $total_minus_self\n";


# take off last field

# SUMMARY 1
print "Genome$record_separator genes with hit$record_separator percentage hits$record_separator total hits\n";
for ($i=1; $i<=$total-1; $i++) {
($hits, $total_hits) = 0;
	foreach $line (@lines) {
		chomp($line);
		my @fields = split(/$record_separator/,$line);
		$hits++ if $fields[$i] > 0;
		$total_hits = $total_hits + $fields[$i];			
	}
	my $per_hits = ($hits/$seqs)*100;
	print "$i$record_separator$header[$i]$record_separator$hits$record_separator$per_hits$record_separator$total_hits\n";
}

#SUMMARY 2

print "\nData sets matched (not including self), number of genes that match this number of data sets\n";
foreach $line (@lines) {
       chomp($line);
       my @fields = split(/$record_separator/,$line);
	$last = @fields;
	$total_species = $fields[$last-1];
	$count[$total_species]++;

}

# one less than the number of datasets - doesn't include SELF
for ($i=1; $i<$total; $i++) {
	print "$i$record_separator$count[$i]\n";
}
