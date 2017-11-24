#!/usr/bin/perl  -w

##############################################
##############################################
# SCRIPT NAME:  genetable.pl
# FUNCTION:   Make a gene table from a set of *hits files
# AUTHOR:       Cared for by Gareth Wilson (gawi@ceh.ac.uk)
##############################################

use strict;

use Config::Simple;
my ($line, @fields, @lines, @tags, $tag, $file);

# get this from the command line

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./genetable.pl end configfile\nPlease try again.\n\n\n";}

my $end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";


open (OUT, ">gene_table.html") or die "can't open gene_table.html for writing";
open (TAGS, "abbr.list") or die "can't open abbr.list file";
print OUT "<PRE>\nGenome$record_separator"."SELF$record_separator";
while ($tag = <TAGS>) {
	chomp($tag);
	push (@tags, $tag);
	print OUT "$tag$record_separator";
}

print "TAGS: @tags";



### added here ability to append the values in the abbr_extra
### file if it exists

my @tags_extra = ();
my $tag_extra = "";

if (-e "abbr_extra.list") {
	open (TAGS, "abbr_extra.list") or die "can't open abbr_extra.list file";
	while ($tag_extra = <TAGS>) {
        	chomp($tag_extra);
        	push (@tags_extra, $tag_extra);
        	print OUT "$tag_extra$record_separator";
	}

print "Full TAGS: @tags_extra";

} # end if abbr_extra.list

print OUT "\n";



# pick up all the *hits file in order of tags list
foreach $tag (@tags) {
	$file  = "$tag"."$end";
	print "TAG: $tag - Summarizing file $file\n";
	open (IN, "$file") or die "can't open file: $file";

	# pick up all lines in file
	@lines = <IN>;
	# get rid of summary lines
	$line = shift @lines;
	$line = shift @lines;
	$line = shift @lines;
	$line = shift @lines;
	
	print OUT "\n$tag$record_separator";
	foreach $line (@lines) {
		print "$line\n";
		if ($line =~ /^\s$/) {print "\n";last};
		 @fields = split(/$record_separator/,$line);
		if ($fields[1]) {print OUT "$fields[2]$record_separator";}
	
	}
} # next tag and file
