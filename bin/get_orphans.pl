#!/usr/bin/perl -w



# creates .overview .matrix, .rank, .score and .seq files

##############################################
##############################################
# SCRIPT NAME:  get_orphans
# FUNCTION:     Summarize blast reports
# AUTHOR:       Cared for by Gareth Wilson (gawi@ceh.ac.uk)
# AUTHOR:	Kerr Wall ported code to use SearchIO intead of Blast.pm
##############################################



# This script takes 5 or 6 input arguments:
# scriptname
# YES|NO - if yes tag must match input file
# TAG to name the output files with
# and a file glob to grab input files

# ./get_orphans_table YES SELF SELF_blastp condor_output ext configfile


#no strict 'refs';
#use strict;
# broken below for using contruct $$var

use Bio::SearchIO;
use Config::Simple;




my $species = "";
my $hit_tag = "";

unless (@ARGV ==6) {
        die "\n\nProper Command Line Usage: 
		get_orphans YES/NO TAG glob condor_output ext configfile\nPlease try again.\n\n\n";}

# shift the first command line arg passed through @ARGV
my $yes_or_no = shift;

unless ($yes_or_no eq "YES" || $yes_or_no eq "NO") {
        die "\n\nProper Command Line Usage: 
		get_orphans YES|NO TAG glob\nPlease try again.";}

my $tag = shift;
my $glob = shift;
my $condor_output = shift;
my $ext = shift;
my $config_file = shift;

print "CONFIG FILE =*$config_file*\n";

# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);

# initialize the variables shared with the config file
my $path2output = $cfg->param('PATHS.path2output');
my $path2blast = $cfg->param('PATHS.path2blast');
my $path2public = $cfg->param('PATHS.path2public');

print "My $path2output\n";

# initialize the variables shared with the config file
my $sig_thresh = $cfg->param('PARAMS.sig_thresh');

print "***Significance threshold for detecting orphans: $sig_thresh\n";

# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";
my $quick_tax = 1;
my @taxi = ();
open TAX, "$path2output/tax.list" or $quick_tax = 1;
open (HELP, ">>$path2output/help$tag.txt");
print HELP "quick_tax = $quick_tax\n";
my $taggle;
my @taggles;
if ($quick_tax == 0)
{
	@taxi = <TAX>;
	close TAX;
}
else
{
	if ($tag =~/,/)
	{
		print HELP "Comma found\n";
		@taggles = split/,/,$tag;
		foreach $taggle (@taggles)
		{
			print "taggle = $taggle\n";
			push @taxi, $taggle;
		}
	}
	else
	{
		push @taxi, $tag;
		print HELP "Single chromosome\n";
	}
}

my $tax;
my @input_files = ();
 
# if YES, make input file match TAG
if ($yes_or_no eq "YES")
{
	foreach $tax (@taxi)
	{
		chomp $tax;
		chdir "$path2blast/$tag".".dir";
		my @tmp = <*$glob>;
		print HELP "tax = $tax\n";
		print HELP "size tmp = $#tmp\n";
		for (@tmp)
		{
			print HELP "$_, tax = $tax\n";
			if ($_ =~ /$tax/ && $condor_output == 1)
			{
				push (@input_files, "$path2blast"."/"."$tag".".dir/"."$_");
				print HELP "condor output = 1 size input = $#input_files\n";
			}
			elsif ($_ =~ /$tax/ && $condor_output == 0)
			{
				push (@input_files, "$path2blast"."/"."$_");
				
			}
		}
	}
}
print HELP "size input = $#input_files\n";
# if NO, use all files that match glob
if ($yes_or_no eq "NO")
{
	@input_files = <*$glob>;
}

my (%hit_name, @ranked);

# parse the abbreviations from the abbr.list file

my $line = "";
my @species = ();
if (-e "$path2output/abbr.list")
{
        print "Found an abbr.list file.";  
	print "Will read \@species from your abbr.list file\n";
	open (ABBR, "$path2output/abbr.list" ) 
		or die "Can't open $path2output/abbr.list\n";
	while ($line = <ABBR>)
	{
		if ($line =~ /#/) {next;}
	        chomp $line;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		push (@species, $line);
        	
	}

close (ABBR);

}


# print to screen for debugging

foreach my $abbr (@species) {
	print "Abbr: $abbr\n";
}


# Now get extra names to parse from abbr_extra.list file
$line = "";
@species = (); # we're adding to this now
if (-e "$path2output/abbr_extra.list")
{
	print "Found an abbr.list file.";
	print "Will read \@species from your abbr_extra.list file\n";
	open (ABBR, "$path2output/abbr_extra.list" )
            or die "Can't open $path2output/abbr_extra.list\n";
	while ($line = <ABBR>)
	{
            if ($line =~ /#/) {next;}
            chomp $line;
            $line =~ s/^\s+//;
             $line =~ s/\s+$//;
             push (@species, $line);
     }

close (ABBR);
}


# and print again for debugging purposes

foreach my $abbr (@species)
{
       print "Full List Abbr: $abbr\n";
}


my $hitnumber;

my ($report, $hit);
my $orphan_count = 0;
my $error_count = 0;


# old files - not put to html to remind me which are old
my $orphans_file = $tag."_".$glob."_orphans";
my $summary_file = $tag."_".$glob."_orphans_summary";
my $errors_file = $tag."_".$glob."_errors";

# files that are most important
my $overview_file = $tag."_".$glob."_overview.html";
my $scores = $tag."_".$glob."_scores.html";
my $matrix = $tag."_".$glob."_matrix.html";
my $rank = $tag."_".$glob."_rank.html";
my $top_hit = $tag."_".$glob."_tophit.html";
my $tab_info = $tag."_tabinfo.txt";

open (OUT, ">$orphans_file") or die "can't open orphans file for writing";
open (ERROR, ">$errors_file") or die "can't open blast error file for writing";
open (SUMMARY, ">$summary_file") or die "can't open summary file for writing";
open (OVERVIEW, ">$path2output/$overview_file") or die "can't open overview file for writing";
open (SCORES, ">$path2output/$scores") or die "can't open scores file for writing";
open (TOPHIT, ">$path2output/$top_hit") or die "can't open top hit file for writing";
open (TABINFO, ">$path2output/$tab_info") or die "can't open tab info file for writing";
open (MATRIX, ">$path2output/$matrix") or die "can't open matrix file for writing";
open (RANK, ">$path2output/$rank") or die "can't open rank file for writing";
open (LOG, ">>logfile") or die "can't open logfile file for appending";


print HELP "starting to print to files\n";
print OUT "<PRE>Total orphans:\n";
print ERROR "<PRE>Total reports against SELF without hits\n";
print SUMMARY "<PRE>Summary of orphans\n";
print SCORES "<PRE>Scores\n";
print TOPHIT "<PRE>Top Hits\n";
print OVERVIEW "<PRE>Summary of hits by species (for loading into Excel)\n";
print OVERVIEW "Query$record_separator"."Self$record_separator";
print MATRIX "<PRE>Summary of top hit by species (for loading into Excel)\n";
print MATRIX " Query";
print RANK "<PRE>Top hits from each species in rank order (for loading into Excel)\n";

# write all the column headers to the output file

for (@species)
{
	print OVERVIEW "$_$record_separator";
	print MATRIX "$record_separator$_";
}

print OVERVIEW "Total Libs with Hits\n";


# do all the work here
foreach $report (@input_files)
{
	
	print HELP "input = $#input_files , report = $report\n";
	my $public_report = $report;
	my $taggle;
	my $tagorf;
	if ($tag =~/,/)
	{
		print HELP "size taggles = $#taggles\n";
		foreach $taggle (@taggles)
		{
			print HELP "taggle = $taggle\n";
			my $orf = 'orf';
			if ($report =~m/$taggle$orf/)
			{
				$tagorf = "$taggle"."orf";
			}
			
		}
	
	}
	else
	{
		$tagorf = "$tag"."orf";
	}
	$report =~m/($tagorf.{4})/;
	my $brief_report = $1;
	print HELP "brief report = $brief_report\ntag = $tag\nreport = $report\n";
	$public_report =~s/$path2blast/$path2public/;
	%hit_name = ();
	@ranked = ();

	# make a local link to file
	my $reportlink = "<a href=\"$public_report\">$brief_report</a>";
	print HELP "report link = $reportlink\n";

        print "\nSummarizing file $report\n";
	my $blast_report = new Bio::SearchIO( -format => 'blast', -file => $report);
	my $result = $blast_report->next_result;
	my $query_name = $result->query_name();
	my $query_length = $result->query_length();
	
	# since a genome report, we only want the original
	# abbreviation
	$query_name =~ /(.+)(orf)/;
	$query_name = $1;

	my @hits;
	my $self = 0;
	my $top_hit_count = 0;
     	while (my $hit = $result->next_hit())
	{

                my $hit_name = $hit->name();

		my $desc = $hit->description();

		# all the names of the files should be in the @species array
		# after reading the abbr.list file.  Bring the needed variables
		# into existance by initializing them

		# should take the place of the set array below
		my $fasta_report;
		my $string;
		my $stringy;
		my $length;
		my $stringy_count = 0;
		my $total_length = 0;
		my $mean_length = 0;
		my @mean;
		my $short_number = 0;
		my $long_number = 0;

		foreach my $abbr (@species)
		{
			print "ABBR: $abbr\n";
			$$abbr = "";
		}

                $hit_name =~ s/\.fasta,//;
                my $expect = $hit->significance(),
		my $score = $hit->raw_score();
		my $description = $hit->description();
		my $first_value = substr($expect,0,1);
		if ($first_value eq "e")
		{
			$expect = "1" . $expect;
		}	
		# keep only hits above a certain threshold
		my $hsp_string;
		my @hsps =();
		while (my $hsp = $hit->next_hsp())
		{
			my $identity = $hsp->percent_identity;
			$identity = sprintf("%.2f",$identity);
			my $hsp_score = $hsp->score;
			my $q_start = $hsp->start('query');
			my $q_stop = $hsp->end('query');
			my $s_start = $hsp->start('hit');
			my $s_stop = $hsp->end('hit');
			my $blast_type = $glob;
			$blast_type =~s/SELF_//;
			$hsp_string = "$brief_report\t$blast_type\t$hit_name\t$identity\t$hsp_score\t$q_start\t$q_stop\t$s_start\t$s_stop\n";
			push @hsps, $hsp_string;
		}
		if ($expect < $sig_thresh)
		{
			$hit_name =~ /(.+)(orf)(.)/;
			$hit_tag = $1;
			print SCORES "$tag$record_separator$reportlink$record_separator$hit_name$record_separator$expect$record_separator$description\n";
			if ($top_hit_count == 0)
			{
				print TOPHIT "$tag$record_separator$reportlink$record_separator$hit_name$record_separator$expect$record_separator$description\n";
			}
			if (!$hit_name{$hit_tag})
			{
				$hit_name{$hit_tag} = $hit_name;
				push (@ranked, $hit_name);
			}
			print "HIT: $hit_name QUERY $query_name\n";
			# if we hit self (match file name) don't keep
			# but set $self equal to "true"
			if ($hit_name =~ $query_name)
			{
				$self = 1;
			}
			push (@hits, $hit_name); 
			$top_hit_count++;
			foreach my $hsp (@hsps)
			{
				print TABINFO "$hsp";
			}
		}
			
	}
	# SELF NOT INCLUDED IN @hits
	$species = 0; 
		foreach	my $hit (@hits) {
		foreach $species (@species) {
			# check for match on $species first, then on 
			# $species{$species}
			#if ($hit =~ /$species/) {$$species++;}
			if ($species =~/,/)
			{
				my @problems = split /,/,$species;
				my $problem;
				foreach $problem (@problems)
				{
					if ($hit =~ /$problem/ )  ## || $hit =~ /$species{$species}/) 
					{$$species++;}
				}
			}
			else
			{
				if ($hit =~ /$species/ )  ## || $hit =~ /$species{$species}/) 
				{$$species++;}
			}
		}
	}
	my $hitnumber = @hits;
	if ($hitnumber == 0  && $report =~ "SELF")
	{
                print ERROR "ERROR: $reportlink against SELF has no hits\n";

	}
	elsif ($hitnumber == 1 && $report =~ "SELF")
	{
		print OUT "ORPHAN: $reportlink against SELF has only SELF hit\n";
		$orphan_count++;
        }
	elsif ($hitnumber == 0 && $report =~ "swiss")
	{
	        print OUT "ORPHAN: $reportlink against swiss has no hits\n";
        	$orphan_count++;
        }
	elsif ($hitnumber == 1 && $report =~ "swiss")
	{
        	print OUT "ORPHAN: $reportlink against swiss has 1 hit - could be self\n";
        	$orphan_count++;
	}
	else
	{
	}

	print OVERVIEW "$reportlink$record_separator";
	print MATRIX "\n$reportlink$record_separator";
	print RANK "\n$reportlink$record_separator";
	my $count_sp = 0;
	print OVERVIEW "$self$record_separator";
	foreach $species (@species)
	{
        	if ($$species)
		{
			print OVERVIEW "$$species$record_separator";$count_sp++
		}
		else
		{
			print OVERVIEW "0$record_separator";
		}
		if ($hit_name{$species})
		{		
			$hit_name{$species} =~ /(orf)(\d{4})/;
			my $orf_num = $2;			
					
			print MATRIX "$orf_num$record_separator";
		}
		else
		{
			print MATRIX "0$record_separator";
		}
	
		# this is why strict won't work at present
        	$$species = "";
        	#print HELP "input after dollar dollar = $#input_files\n";
	}
	print OVERVIEW "$count_sp\n";
	print RANK "@ranked";
	
}



# print out summary for each genome
print SUMMARY "Total orphans: $orphan_count\n";
print SUMMARY "Total errors (low, complexity proteins, possible orphans): $error_count\n";

print "Files created\n";
print LOG "$orphans_file$record_separator$summary_file$record_separator$errors_file$record_separator$overview_file";
close HELP;
