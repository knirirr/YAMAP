#!/usr/bin/perl -w


###################################
#SCRIPT NAME: orphan_time.pl
#FUNCTION: Displays number of orphans as more genomes are added
###################################


use strict;

use Config::Simple;

my ($tag, @tags, $file, @lines, $orphan_count, $lines, $i, $j,$k,$names, @names, $blank, @fields, $field_number, @initial_fields, $fields, $headings, $top_line);

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./orphan_time.pl time_end configfile\nPlease try again.\n\n\n";}
                                                                                
my $time_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

my $self_hit = $cfg->param('PATHS.self_hit');

if ($self_hit == 0)
{
	$blank = 0;
}

print "RECORD SEP $record_separator\n";


open (TAGS, "abbr.list") or die "can't open abbr.list file";
open OUT, ">orphan_time.html";
print OUT "<PRE>Orphan Summary Table\n";
print OUT "Genome";

while ($tag = <TAGS>)
{
        chomp($tag);
	push (@tags, $tag);
}
 

$headings = 1;
foreach $tag (@tags)
{
	$file  = "$tag"."$time_end";
	open (INPUT, "$file") or die "can't open file: $file";
                                                                                
	@lines = <INPUT>;
	close INPUT;
	$top_line = $lines[1];
	@names = split /$record_separator/, $top_line;
	# obtain array element containing the genome currently being written
	for ($k = 0; $k<=$#names; $k++)
	{
		if ($names[$k] eq $tag)
		{
			$blank = $k + 1;			
		}
	}
	# prints to file the top line
	if ($headings == 1)
	{
		$top_line =~s/Orphan$record_separator//g;
		$top_line =~s/Query[\t,]Self//;
		$top_line =~s/[\t,]Total Libs with Hits//;
		chomp $top_line;
		print OUT qq{$top_line};
	}
	$headings = 0;
	print OUT qq{\n$tag};
        print "TAG: $tag - Timing orphans $file\n";
	chomp($lines[1]);
	@initial_fields = split /$record_separator/,$lines[1];
	$field_number = $#initial_fields;
	# $j starts on 3 as thats the first column containing orphan data, it then
	# increments in two
	for ($j = 3; $j <=$field_number; $j=$j+2)
	{
		print qq{j = $j genome = $tag\n};
		if ($j == $blank)
		{
			print OUT qq{$record_separator -};
		}
		else
		{
		$orphan_count = 0;
		# reads down column $j counting orphans
		for ($i = 0; $i <= $#lines; $i++)
		{
			if ($lines[$i] ne "" && $i>1)
			{
				@fields = split /$record_separator/, $lines[$i];				
				if ($fields[$j] =~m/Y/)
				{					
					$orphan_count++;					
				}
			}
		}
		print OUT qq{$record_separator$orphan_count};
		}
	}
}
