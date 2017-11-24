#!/usr/bin/perl -w


##############################################
#SCRIPT NAME: paralogue_count.pl
#DESCRIPTION: Determines which orfs have paralogues but aren't present in other genomes
##############################################


use strict;

use Config::Simple;

my ($tag, @tags, $file, @lines, $lines, $i, $j, $orf, $field_number, @fields, $genome, %paralogous, $paralogous);

# get this from the command line

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./paralogue_count.pl count_end configfile\nPlease try again.\n\n\n";}
                                                                                
my $count_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
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
open OUT, ">paralogous_orphans.html";
print OUT "<PRE>Table showing paralogous orphans in all query genomes\n";
print OUT "Genome$record_separator"."Paralogue$record_separator"."Number of Paralogues\n";
foreach $tag (@tags)
{
	my $para_count = 0;
	$file  = "$tag"."$count_end";	
	print "Counting paralogues : $tag\n";
        open (INPUT, "$file") or die "can't open file: $file";

	@lines = <INPUT>;
	close INPUT;
	for ($i = 0; $i <= $#lines; $i++)
	{
		if ($lines[$i] ne "" && $i>0)
		{
			$orf = $lines[$i];			
			chomp($orf);
			@fields = split /$record_separator/,$orf;
			$field_number = $#fields;
			if ($i == 1)
			{
				for ($j = 2; $j < $#fields; $j++)
				{
					if ($tag eq $fields[$j])
					{
						$genome = $j;
					}
				}
			}
			else
			{
				if ($fields[$genome] > 1 && $fields[$field_number] == 1)
				{
					print OUT "$tag$record_separator$fields[0]$record_separator$fields[$genome]\n";
					$para_count++;
				}
			}
		}
	}
print "$para_count\n";
$paralogous{$tag} = $para_count;
}
open COUNT, ">paralogue_count.html";
print COUNT "<PRE>Paralogue orphan count for each genome\n";
foreach $tag (@tags)
{
	print COUNT "$tag$record_separator$paralogous{$tag}\n";
}
close OUT;
close COUNT;
