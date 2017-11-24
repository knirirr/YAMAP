#!/usr/local/bin/perl

# 2qmfasta.pl v 0.02
#
# Cared for by Gareth Wilson (gawi@ceh.ac.uk)

use strict;
use Config::Simple;

unless (@ARGV ==1) {
        die "\n\nUsage:\n ./2qmfasta.pl file.cfg\nPlease try again.\n\n\n";}


# pick up the values in the config file
my $config_file = shift;

# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);

# initialize the variables shared with the config file
my $path2proteins = $cfg->param('PATHS.path2proteins');
my $ext = $cfg->param('LEAVE_ALONE.ext');
my $path2output = $cfg->param('PATHS.path2output');
my $write_fasta_files = $cfg->param('LEAVE_ALONE.write_fasta_files');

# in the quickmine file - so leave as our
our @cmd = "";
my $fasta_file_ending = $cfg->param('LEAVE_ALONE.fasta_file_ending');


my @files		= undef;		# list of initial protein files
my $file                = "";  # file with a list of proteins in fasta format
my $line                = "";           # each line read from this file for parsing
my @line		= "";	# lines of a fasta seq
my $seq			= "";	# each fasta seq
my $header		= "";	# header line of fasta file
my $abbr		= "";		# abbreviations of genome
my $newfilename		= ""; 		# each new fasta file


my $home = `pwd`;
chomp($home);
chdir "$path2proteins";

open (ABBR, ">$path2output/abbr.list") or die "Can't open $path2output/abbr.list for writing\n";

my $blast_database = "SELF_blast_database";	# fasta file of all proteins


@files = <*$ext>;

my $debug = 1;

if ($debug) { print "FILES: @files\n";}

open (SUMMARY, ">$path2output/$blast_database")
		or die "can't open blast database $home/$blast_database for writing";


foreach $file (@files) {
	my $count = "0000"; # orf count
	open (IN, $file) or die "can't read file $file: $!\n";
	open OUTGEN, ">$path2output/$file".".complete";
        $header = <IN>;

        if($header !~ /^>/){ die "$0:  file doesn't begin with header line.\n";}

	while ($header) {

if ($debug) { print "$header\n"; }
		undef ($seq);

		#read the sequence
                while(($line = <IN>) && ($line !~ /^>/))
                {
                	push (@line,$line);
	        }


       	$seq=join('',@line);
        undef @line;


	# process the sequence and write to file
	$count++;
	$file  =~ /(.+)($ext)/;
	$abbr = $1;


	$newfilename = "$abbr"."orf"."$count.fasta";
	$header =~ s/^>/>$newfilename /;
	#this writes the SELF_blast_database
	print SUMMARY "$header$seq";
	print OUTGEN "$header$seq";
	if ($write_fasta_files)
	{
		open (OUT, ">$path2output/$newfilename") 
				or die "can't open $path2output/$newfilename for writing: $!";
		print OUT "$header$seq";
	}else
	{
		print "Did not write individual fasta files\n";
	}	

	if($line) { $header = $line;}
        	else { undef($header);}

	} # end while $header

print ABBR "$abbr\n";

close IN;
close OUTGEN;
} # end foreach $file 

print "Done\n";

