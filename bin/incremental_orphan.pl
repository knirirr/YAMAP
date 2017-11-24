#!/usr/bin/perl -w


##############################################
#SCRIPT NAME: incremental_orphan.pl
#DESCRIPTION: Determines which orfs are orphans as new genomes are added
##############################################


use strict;

use Config::Simple;

my ($tag, @tags, $file, @lines, $lines, $i, $j, $orf, $field_number, @fields, $orphan, $genome);

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./orphan_count.pl count_end configfile\nPlease try again.\n\n\n";}
                                                                                
my $count_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
my $self_hit = $cfg->param('PARAMS.self_hit');
if ($self_hit == 0)
{
	$genome = 0;
}
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
	$file  = "$tag"."$count_end";
        print "TAG: $tag - Generating orphan increments $file\n";
        open (INPUT, "$file") or die "can't open file: $file";

	@lines = <INPUT>;
	close INPUT;
	open OUT, ">$tag"."_orphan_increment.html";
	print OUT "<PRE>Table showing orphans over time in $tag\n";
	for ($i = 0; $i <= $#lines; $i++)
	{
		if ($lines[$i] ne "" && $i>0)
		{
			$orf = $lines[$i];			
			chomp($orf);
			@fields = split /$record_separator/,$orf;
			$field_number = $#fields;
			$orphan = "Y";
			if ($i == 1)
			{
				print OUT qq{$fields[0]$record_separator$fields[1]$record_separator};
				for ($j = 2; $j < $#fields; $j++)
				{
					print OUT qq{$fields[$j]$record_separator};
					print OUT qq{Orphan$record_separator};
					if ($tag eq $fields[$j])
					{
						$genome = $j;
					}
				}
				print OUT qq{$fields[$#fields]\n};
			}
			else
			{
				print OUT qq{$fields[0]$record_separator};
				print OUT qq{$fields[1]$record_separator};
				for ($j = 2; $j < $#fields; $j++)
				{
					print OUT qq{$fields[$j]$record_separator};
					if ($fields[$j] == 0 || $genome == $j)
					{
					print OUT qq{$orphan$record_separator};
					}
					else
					{
						print OUT qq{N$record_separator};
						$orphan = "N";
					}
				}
				print OUT qq{$fields[$#fields]\n};
			}
		}
	}
close OUT;
}
