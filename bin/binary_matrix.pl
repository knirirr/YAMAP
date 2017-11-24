#!/usr/bin/perl -w

##############################################
##############################################
# SCRIPT NAME:  binary_matrix
# FUNCTION:    Convert overview files to a binary matrix
###############################################


# Takes an input file ending in .overview.html as an input

use strict;

use Config::Simple;

my ($tag, @tags, $file, $output, $header, $line, @binary, $binary, $row, $done);

unless (@ARGV ==2) {
        die "\n\nProper Command Line Usage: binary_matrix.pl count_end config_file\nPlease try again.\n\n\n";}

# shift the first command line arg passed through @ARGV
my $count_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $path2output = $cfg->param('PATHS.path2output');
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";
open (TAGS, "abbr.list") or die "can't open abbr.list file";

while ($tag = <TAGS>)
{
	chomp($tag);
        push (@tags, $tag);
}
foreach $tag (@tags)
{
	print "$tag - Generating binary matrix\n";
        $file  = "$tag"."$count_end";
	my (@lines, @header) = ();

	open (IN, $file) or die "can't open file: $file";

	$output = "$tag"."_binary.html";
	open OUT, ">$path2output/$output" or die "can't open file: $output";
	print OUT "<PRE>$tag Binary Matrix\n";
	# pick up all lines in file
	@lines = <IN>;
	# get rid of summary line
	shift @lines;

	# Take header and discard last element in array  

	$header = shift @lines;
	@header = split /$record_separator/,$header;
	pop @header;
	$header = join "$record_separator", @header;

	print OUT "$header\n";

	# convert values greater than 1 to 1

	foreach $line (@lines)
	{
		@binary = split /$record_separator/,$line;
		pop @binary;
		$row = shift @binary;
		print OUT "$row$record_separator";
		foreach $binary (@binary)
		{
			if ($binary >= 1)
			{
				$binary = 1; 
			}
			else
			{
				$binary = 0; 
			}
		}
		$done = join "$record_separator", @binary;
		print OUT "$done\n";
	}
}
close OUT;







