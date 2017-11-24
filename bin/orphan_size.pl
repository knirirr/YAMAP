#!/usr/bin/perl -w

###################################
#SCRIPT NAME: orphan_size.pl
#FUNCTION: Calculates the size of each orphan and creates relevant fasta files (short, long)
###################################


use strict;

use Config::Simple;
use Bio::SeqIO;

my ($tag, @tags, @list, @seq, $orphan, $total, $large_count, $short_count, $genome, @genomes, $total_length, $mean_size, $genome_count, $non_orphan, @old_para, $old, $good_orphan, @good_orphans);


unless (@ARGV ==2) {
        die "\n\nUsage:\n ./orphan_size.pl para_check configfile\nPlease try again.\n\n\n";}

# para_check determines whether the file should remove non-orphan paralogues from the list of orphans, 1 = remove. #Requires old_para file to remove.
my $para_check = shift;                                                                                
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $record_separator = $cfg->param('PARAMS.record_separator');
my $path2output = $cfg -> param('PATHS.path2output');
my $path2blast = $cfg -> param('PATHS.path2blast');
my $ext = $cfg -> param('PARAMS.ext');

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";

open (TAGS, "$path2output"."/abbr.list") or die "can't open abbr.list file";
open (OUT, ">$path2output"."/orphan_size.txt");
open (OUTH, ">$path2output"."/orphan_size.html");
print OUT "<PRE>Genome Summary Table\n";
print OUT "genome$record_separator total_orphans$record_separator long_orphans$record_separator short_orphans$record_separator Mean_orphan_length\n";
print OUTH "<PRE>Genome Summary Table\n";
print OUTH "genome$record_separator total_orphans$record_separator long_orphans$record_separator short_orphans$record_separator Mean_orphan_length\n";

while ($tag = <TAGS>)
{
        chomp($tag);
        push (@tags, $tag);
}

foreach $tag (@tags)
{
	open (SEQOUT, ">$path2output/$tag"."_orphan.faa.complete");
	print "$tag\n";
	if ($tag=~m/,/)
	{
		$large_count = 0;
		$short_count = 0;
		$total = 0;
		$total_length = 0;
		@genomes = split /,/, $tag;
		$genome_count = 0;
		foreach $genome (@genomes)
		{
			&orphan_size($tag,$genome,$ext,$path2output,$path2blast,$genome_count,$para_check);
			print "$tag,$genome,$ext,$path2output,$genome_count\n";
			$genome_count++;
		}	
		
	}
	else
	{
		$large_count = 0;
		$short_count = 0;
		$total = 0;
		$total_length = 0;
		$genome_count = 1;
		&orphan_size($tag,$tag,$ext,$path2output,$path2blast,$genome_count,$para_check);
	}
	close SEQOUT;
	
}
close OUT;
close OUTH;

sub orphan_size
{
	my $tag = $_[0];
	my $genome = $_[1];
	my $ext = $_[2];
	my $path2output = $_[3];
	my $path2blast = $_[4];
	my $genome_count = $_[5];
	my $para_check = $_[6];
	my $no_file = 0;
	my @good_orphans = ();
	open (LIST, "$path2output/$tag"."_orphan_list.html") or $no_file = 1;
	@list = <LIST>;
	close LIST;
	if ($#list < 1)
	{
		$no_file = 1;
	}
	if ($para_check == 1)
	{
		open (PARA, "$path2output/old_para.txt") or die "can't open old_para.txt";;
		@old_para = <PARA>;
		close PARA;
	}
	print "no file = $no_file\n";
	my $inseq = Bio::SeqIO ->new('-file' => "<$path2blast/$genome$ext".".complete", '-format' => 'fasta');
	foreach $orphan (@list)
	{
		#if ($orphan =~m/\<a href=".*(.*orf.{4}).*"/)
		if ($orphan =~m/>(.*orf.{4})/)
		{
			$orphan = $1;
			if ($para_check == 1)
			{
				$old = 0;
				foreach $non_orphan (@old_para)
				{
					chomp $non_orphan;
					if ($orphan =~m/$non_orphan/)
					{
						$old = 1;
					}
				}
				if ($old == 0)
				{
					push (@good_orphans, $orphan);
				}
			}
			else
			{
				if ($orphan =~m/$genome/)
				{
					push (@good_orphans, $orphan);
				}
			}
		}
	}
	print "good orphans = $#good_orphans\n";
	foreach $good_orphan (@good_orphans)
	{
		if ($good_orphan =~m/$genome/)
		{
			while (my $seq = $inseq->next_seq)
			{
				my $orf_id = $seq->display_id;
				#print "orf_id = $orf_id\n";
				$orf_id =~m/(.+)\.fasta/;
				my $orf = $1;
				print "orf = $orf\n";
				if ($orf =~m/$good_orphan/)
				{
					$total++;
					my $length = $seq->length();
					my $sequence = $seq->seq();
					my $description = $seq->description;
					$total_length = $length + $total_length;
					print SEQOUT ">$orf_id $description\n$sequence\n";
					if ($length >149)
					{
						$large_count++;
					}
					else
					{
						$short_count++;
					}
					last;
				}
			}
		}
	}	
	
	if ($no_file == 0)
	{
		if ($genome_count == 1)
		{
			$mean_size = $total_length/$total;
			print OUT "$tag$record_separator$total$record_separator$large_count$record_separator$short_count$record_separator$mean_size\n";
			print OUTH "$tag$record_separator$total$record_separator$large_count$record_separator$short_count$record_separator$mean_size\n";
		}
	}
	else
	{
		print OUT "$tag$record_separator"."0$record_separator"."0$record_separator"."0$record_separator"."-\n";
		print OUTH "$tag$record_separator"."0$record_separator"."0$record_separator"."0$record_separator"."-\n";
	}
}
