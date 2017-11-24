#!/usr/bin/perl

#
# quickmine.pl
#

# Gareth Wilson v 1.0.2

use strict;
use warnings;
use Config::Simple;
use Getopt::Std;

my $config_file;

my %opts;
getopts('hc:d',\%opts);

if (defined $opts{h})
{
       print <<USAGE;

Usage:
-c quickmine configuration file (please provide full path)
-d delete existing QuickMine output
-h list these options


USAGE
       exit;
}

if (defined $opts{c})
{
	$config_file = $opts{c};
}
else
{
	print <<USAGE;

Usage:
-c quickmine configuration file name (do not use full path, make sure config file is in the scripts directory)
-d delete existing QuickMine output
-h list these options

USAGE
       exit;
}


# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);

# initialize the variables shared with the config file
my $path2proteins = $cfg->param('PATHS.path2proteins');
my $ext = $cfg->param('LEAVE_ALONE.ext');
my $path2output = $cfg->param('PATHS.path2output');
my $path2scripts = $cfg->param('PATHS.path2scripts');
my $formatdb = $cfg->param('PARAMS.formatdb');
my $end = $cfg->param('ENDINGS.end');
my $count_end = $cfg->param('ENDINGS.count_end');
my $time_end = $cfg->param('ENDINGS.time_end');
my $matrix_end = $cfg->param('ENDINGS.matrix_end');
my $condor_output = $cfg->param('LEAVE_ALONE.condor_output');
my $record_separator = $cfg->param('PARAMS.record_separator');
my $self_hit = $cfg->param('PARAMS.self_hit');
my $fasta_file_ending = $cfg->param('LEAVE_ALONE.fasta_file_ending');
my $write_fasta_files = $cfg->param('LEAVE_ALONE.write_fasta_files');
my $blast_programme = $cfg->param('PARAMS.blast_programme');
my $blast_command = $cfg->param('PARAMS.blast_command');

my $parse = $cfg->param('RUN.parse');
my $format = $cfg->param('RUN.format');
my $quickmine = $cfg->param('RUN.quickmine');
my $split = $cfg->param('RUN.split');
my $orphans = $cfg->param('RUN.orphans');
my $hits = $cfg->param('RUN.hits');
my $genetable = $cfg->param('RUN.genetable');
my $orphan_count = $cfg->param('RUN.orphan_count');
my $orphan_size = $cfg->param('RUN.orphan_size');
my $paralogue_count = $cfg->param('RUN.paralogue_count');
my $increment = $cfg->param('RUN.increment');
my $time = $cfg->param('RUN.time');
my $binary = $cfg->param('RUN.binary');
my $plots = $cfg->param('RUN.plots');
my $indiv_plot = $cfg->param('RUN.indiv_plot');
my $dot_plot = $cfg->param('RUN.dot_plot');
my $summarizer = $cfg->param('RUN.summarizer');

my $para_check = 0;

if ($opts{d})
{
       print "Deleting old reports.\n";
       unlink glob "$path2output/condor_mine.cmd";
       unlink glob "$path2output/*plotter*\.dat";
       unlink glob "$path2output/gene_table.html";
       unlink glob "$path2output/index.html";
       unlink glob "$path2output/*\.complete";
       unlink glob "$path2output/*\.blast[pn]";
       unlink glob "$path2output/*\.SELF_blast[pn]";
       unlink glob "$path2output/*\_orphan_increment.html";
       unlink glob "$path2output/*orphan_plot*";
       unlink glob "$path2output/*\_errors";
       unlink glob "$path2output/*\_matrix.html";
       unlink glob "$path2output/*\_orphans*";
       unlink glob "$path2output/*\_overview*";
       unlink glob "$path2output/*\_rank.html";
       unlink glob "$path2output/*\_scores.html";
       unlink glob "$path2output/*orphan_count.html";
       unlink glob "$path2output/*orphan_time.html";
       unlink glob "$path2output/*SELF_blast_database*";
       unlink glob "$path2output/*time_error.txt";
       unlink glob "$path2output/help*";
       unlink glob "$path2output/*.dir/*";
       #exit;
}

# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

# in the quickmine file - so leave as our
our @cmd = ();


# find out where we are so we can come back to the scripts directory
# when we need to
my $home = `pwd`;
chomp($home);


# print a bit to screen - 
print "Your path2proteins is $path2proteins\n";
print "Your path2output is $path2output\n";
print <<TEXT;
You should delete all the files in $path2output before rerunning the pipeline from the start....
TEXT

if ($parse ) {

	# start creating the fasta files we need 
	print "Parsing all $ext files to create new fasta files...\n";
	system ("perl $path2scripts/2qmfasta.pl $config_file");
	
}
# getting abbreviations

# pick up the abbreviations to use
open (ABBR, "$path2output/abbr.list" ) or die "Can't reopen $path2output/abbr.list for reading";
my @abbr_list = ();
while (my $line = <ABBR>)
{
	chomp $line;
	push (@abbr_list, $line);
}

# print them to screen
print "The abbreviations created from your input files: @abbr_list\n";

foreach my $abbr (@abbr_list)
{
	if ($parse)
	{
		if ($write_fasta_files == 1)
		{
			print "fasta_html.pl $abbr $fasta_file_ending $path2output\n";
			system ("perl $path2scripts/fasta_html.pl $abbr $fasta_file_ending $path2output");
		}
	}
}


if ($format) {
	# format the SELF_blast_database of all sequences
	print "Running command: $formatdb\n";
	system ("$formatdb");
}

  
       

if ($quickmine)
{
        # change path to where we will write all the output files
	chdir "$path2output/";

	# run blast searches
	
	foreach my $abbr (@abbr_list)
	{
		print "Running blast on $abbr using the following commmand:\n$blast_command\n";
		my $cmd = "$blast_command -i $abbr$ext".".complete -o $abbr$ext".".complete.blast";
		system ("$cmd");
		
	}
	
	
} # end if $quickmine

if ($split)
{
	# split the blast report into individual files	
	my $split_cmd = "$path2scripts/quick_splitblast.pl $path2output $ext $config_file";
	print "$split_cmd\n";
	system ("$split_cmd");
	# create abbr_extra file
        open (ABBREX, ">$path2output/abbr_extra.list" ) or die "Can't open $path2output/abbr_extra.list for writing";
	
	if ($self_hit == 1)
	{
		foreach my $abbr (@abbr_list)
		{
			print ABBREX "$abbr\n";
		}
		close ABBREX;
	}
	else
	{
		print ABBREX ".*";
	}
}

if ($orphans)
{
	# change path to where we will write all the output files
        chdir "$path2output/";

	# Run get_orphans

	# needs to get each glob run by quickmine - currently hardcoded!
	print "Running get_orphans with the following commands...\n";
	foreach my $abbr (@abbr_list)
	{
		open (TAX, ">$path2output/tax.list");
		if ($abbr =~/,/)
		{
			my @taxes = split /,/, $abbr;
			my $tax;
			foreach $tax (@taxes)
			{
				print TAX "$tax\n";
			}
		}
		else
		{
			print TAX "$abbr";
		}
		close TAX;
		my $cmd = "$path2scripts/get_orphans.pl YES $abbr SELF_"."$blast_programme $condor_output $ext $config_file";
		print "Running $cmd...\n";
		system ("$cmd");
	}
} # end get_orphans


if ($hits)
{
	# Run hitsparser.pl
	chdir "$path2output";

	my @overview_files = <*overview.html>;
	print "overviews: @overview_files\n";

	foreach my $overview (@overview_files)
	{
		my $cmd = "$path2scripts/hitsparser.pl $path2output/$overview >$path2output/$overview".".hits.html $config_file";  
		print "Running cmd $cmd ...\n";
		system ("$cmd");
	}
} # end ($hits)

if ($genetable)
{
	# Run genetable.pl
	chdir "$path2output";
	my $cmd = "$path2scripts"."/genetable.pl $end $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end ($genetable)



if ($orphan_count)
{
	# Run orphan_count.pl
	chdir "$path2output";
	my $cmd = "$path2scripts/orphan_count.pl $self_hit $count_end $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end ($orphan_count)



if ($orphan_size)
{
	# Run orphan_size.pl
	chdir "$path2output";
	my $cmd = "$path2scripts/orphan_size.pl $para_check $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end ($orphan_size)



if ($paralogue_count)
{
	if ($self_hit == 0)
	{
		print "Sorry, paralogue_count.pl cannot be run as you are not searching against a SELF_blast database\n";
	}
	else
	{
		# Run paralogue_count.pl
		chdir "$path2output";
		my $cmd = "$path2scripts/paralogue_count.pl $count_end $config_file"; 
		print "Running command $cmd\n";
		system ("$cmd");
	}
} # end paralogue_count



if ($increment)
{
	# Run incremental_orphan.pl
	chdir "$path2output";
	my $cmd = "$path2scripts/incremental_orphan.pl $count_end $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end incremental_orphan



if ($time)
{
	# Run orphan_time.pl
	chdir "$path2output";
	my $cmd = "$path2scripts/orphan_time.pl $time_end $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end orphan_time



if ($binary)
{
	# Run binary_matrix.pl
	chdir "$path2output";
	my $cmd = "$path2scripts/binary_matrix.pl $count_end $config_file"; 
	print "Running command $cmd\n";
	system ("$cmd");
} # end orphan_time

###########################################################
# The following perl scripts require gnuplot to be installed
###########################################################

if ($plots)
{
        # Run gnu_plotter.pl
        chdir "$path2output";
        my $cmd = "$path2scripts/gnu_plotter.pl $config_file";
        print "Running command $cmd\n";
        system ("$cmd");
        my $cmd2 = "$path2scripts/gnu_percent_plotter.pl $config_file";
        print "Running command $cmd2\n";
        system ("$cmd2");
} # end gnu_plotter



if ($indiv_plot)
{
        # Run genome_plot.pl
        chdir "$path2output";
        my $cmd = "$path2scripts/genome_plot.pl $config_file";
        print "Running command $cmd\n";
        system ("$cmd");
        my $cmd2 = "$path2scripts/genome_percent_plot.pl $config_file";
        print "Running command $cmd2\n";
        system ("$cmd2");
} # end genome_plot



if ($dot_plot)
{
	if ($self_hit == 0)
	{
		print "Sorry, dotplots can't be created as you are not searching against a SELF_blast database\n";
	}
	else
	{
		# Run dot_plot.pl
		chdir "$path2output";
		my $cmd = "$path2scripts/dot_plot.pl $matrix_end $config_file"; 
		print "Running command $cmd\n";
		system ("$cmd");
	}
} # end dot_plot

##############################################################################

if ($summarizer)
{
	# Run summarizer
	system ("$path2scripts/summarizer.pl $config_file>$path2output/index.html");
} # end ($summarizer)




