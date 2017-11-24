#!/usr/bin/perl -w


###################################
#SCRIPT NAME: orphan_count.pl
#FUNCTION: Counts the number of orphans present in _SELF_blastp_overview.html files
###################################


use strict;

use Config::Simple;

my ($tag, @tags, $file, @lines, $total_orfans, $lines, $i, $orf, $query, $hits, $total_orfs, $percentage_orfans, @fields, $field_number, $family, $total_families, $tag_count, $real_tag_count);

unless (@ARGV ==3) {
        die "\n\nUsage:\n ./orphan_count.pl self_hit count_end configfile\nPlease try again.\n\n\n";}

my $self_hit = shift;                                                                                 
my $count_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";
my $grand_total_orfs = 0;
my $grand_total_orfans = 0;

open (TAGS, "abbr.list") or die "can't open abbr.list file";
open OUT, ">orphan_count.html";
print OUT "<PRE>Genome Summary Table\n";
print OUT "genome$record_separator total_orfs$record_separator total_orfans$record_separator percentage_orfans$record_separator Total families\n";

#open TOTAL, ">total_orphans.txt";

while ($tag = <TAGS>)
{
        chomp($tag);
        push (@tags, $tag);
}
 

# read each overview file in order of tags (NC numbers)
$tag_count = 0;
foreach $tag (@tags) {
	$tag_count++;
	$real_tag_count = $tag_count + 1;
        $file  = "$tag"."$count_end";
        print "TAG: $tag - Counting orphans $file\n";
        open (INPUT, "$file") or die "can't open file: $file";
                                                                                
	@lines = <INPUT>;
	close INPUT;
	open ORPHAN, ">$tag"."_orphan_list.html";
	print ORPHAN "<PRE>Proposed orphan genes in $tag\n";
	#open NONS, ">$tag"."_orphans.txt";
	$total_orfans = 0;
	$total_families = 0;
	$total_orfs = 0;
	for ($i = 0; $i <= $#lines; $i++)
	{
		if ($lines[$i] ne "" && $i>1)
		{
			$orf = $lines[$i];
			chomp($orf);
			@fields = split /$record_separator/,$orf;
			$field_number = $#fields;
			$total_orfs++;
			$hits = $fields[$field_number];
			$family = $fields[$real_tag_count];
			if ($family > 1)
			{
				$total_families = $total_families + 1;
			}
			$query = $fields[0];
			if ($self_hit == 1)
			{
				if ($hits <= 1)
				#if ($hits > 1)
				{
					print ORPHAN "$query\n";
					#$query =~m/(NC_\d{6}orf\d{4})\.fasta/;
					#my $txt_query = $1;
					#print TOTAL "$txt_query\n";
					#print NONS "$txt_query\n";
					$total_orfans = $total_orfans + 1;
				}
			}
			if ($self_hit == 0)
			{
				if ($hits == 0 )
				{
					print ORPHAN "$query\n";
					$total_orfans = $total_orfans + 1;
				}
			}
			
		}
	}
	if ($total_orfs == 0)
	{
		print "$tag - no entries!!!\n";
		next;
	}
	print qq{Total ORFS in $tag = $total_orfs\n};
	print qq{Total ORFans in $tag = $total_orfans\n};
	$percentage_orfans = ($total_orfans/$total_orfs)*100;
	$percentage_orfans = sprintf("%.2f",$percentage_orfans);
	print qq{Percentage of ORFans in $tag = $percentage_orfans%\n};
	
	print OUT qq{$tag$record_separator$total_orfs$record_separator$total_orfans$record_separator$percentage_orfans$record_separator$total_families\n};
	close ORPHAN;
	#close NONS;
	$grand_total_orfs = $total_orfs + $grand_total_orfs;
	$grand_total_orfans = $total_orfans + $grand_total_orfans;
} # next tag and file
my $grand_percentage = ($grand_total_orfans/$grand_total_orfs)*100;
$grand_percentage = sprintf("%.2f",$grand_percentage);
print OUT qq{\nGrand Total$record_separator$grand_total_orfs$record_separator$grand_total_orfans$record_separator$grand_percentage};
close OUT;
#close TOTAL;
