#!/usr/bin/perl

####################################################
# YAMAP: Yet Another Microbial Annotation Pipeline #
# 1. Run each of the programs below                #
# 2. Convert the outputs to .tab                   #
####################################################

use strict;
use threads;
use Bio::SeqIO;
use Config::Simple;
use Cwd;
use File::Basename;
use File::Copy;
use Getopt::Std;
use Data::Dumper;

#####################
# usage information #
#####################
my $usage="
Usage:

./yamap.pl [-c <config_file>] [-p <path_file>] <input_files>

Options:

-c full path to user config file.
-p full path to path config file.
-q full path to quickmine config file
-x purge extraneous output files
-h print this message.
";

print "Yet Another Microbial Annotation Pipeline - running...\n";

###################
# setup variables #
###################
my $pwd = getcwd;
my $runfile;
my $installdir = "/usr/local/bioinf/yamap/yamap";
my $converter = "yamap_embl.pl";
my $dbname = "self_blast";
my $pathfile;
my $condor = 0;
my $nothing = 0;
my @blastfiles;
my $quickfile;

###############
# get options #
###############
my %opts=();
getopts('c:hp:xq:',\%opts);
# print help message
if (defined $opts{h})
{
	print $usage;
	exit;
}
# get user config file info
if (defined $opts{c})
{
	$runfile = $opts{c};
}
else
{
	print "Using default configuration...\n";
	$runfile = "$installdir/etc/yamap_run.ini";
}
# get path config file info
if (defined $opts{p})
{
	$pathfile = $opts{p};
}
else
{
	print "Using default paths...\n";
	$pathfile = "$installdir/etc/yamap_paths.ini";
}
# get quickmine config file info
if (defined $opts{q})
{
	$quickfile = $opts{q};
}
else
{
	print "Using default configuration...\n";
	$runfile = "$installdir/etc/quickmine.ini";
}


#####################
# files to annotate #
#####################
my @infiles = @ARGV;
unless (@infiles)
{
	print "Whoops! No input files specified!\n";
	print $usage;
	exit;
}


# check all are fasta files
my @dudfiles;
foreach my $file (@infiles)
{
	my $test_file = basename($file);
	print "my file = $file\n";
	my $file = Bio::SeqIO->new(-file => "$file",
														 -format => "FASTA");
	while (my $seq = $file->next_seq())
	{
		my $id = $seq->display_id();
		print "my id = $id\n";
		if ($id eq $test_file)
		{
			print "\nProgram terminated. The filename and fasta header are identical. \nThis will lead to loss of data. Please change your filenames and try again\n";
			exit;
		}
		my $sequence_string = $seq->seq();
		unless ($seq->validate_seq($sequence_string))	
		{
			push(@dudfiles, $file);
		}
	}
}
if (@dudfiles)
{
	print "Program terminated. The following input files are not valid FASTA files:\n";
	foreach my $file (@dudfiles)
	{
		print "$file\n";
	}
	exit;
}


# read a config file containing the options for
# all the scripts to be run. This to be set up
# by GUI.
my $datestring = `date +%j%H%M%S`;
chomp($datestring);
my $config = new Config::Simple("$runfile") or die "Can't open run config file $runfile: $!";
my $common = $config->param(-block=>'COMMON');
my $outdir = $common->{outdir};
unless (-e $outdir)
{
	mkdir("$outdir") or die "Can't create $outdir: $!";
}
# Copy the sequence files to the output directory and add a file extension to their name (for use with quickmine)
foreach my $file (@infiles)
{
	system ("cp $file $outdir");
	my @elems = split/\//, $file;
	my $file_name = $elems[$#elems];
	$file_name =~s/\s/_/;
	my $temp_file;
	if ($file_name =~m/\./)
	{
		$file_name =~m/(.*)\.(.*)/;
		$temp_file = $1;
	}
	else
	{
		$temp_file = $file_name;
	}	
	my $ext_file_name = "$temp_file".".qm";
	system ("mv $outdir/$file_name $outdir/$ext_file_name");
}




# another config file containing all the hardcoded paths
my $pathconf = new Config::Simple($pathfile) or die "Can't open path config file: $!"; 
my $proc =  $pathconf->param(-block=>'PROCESSING');
my $parse =  $pathconf->param(-block=>'PARSING');


# quickmine config file
my $quickfig = new Config::Simple("$quickfile") or die "Can't open run config file $quickfile: $!";


######################################################
# parsers, executables, and the link between the two #
######################################################
my @execs = qw(bigblast dbblast selfblast consblast einverted etandem palindrome trnascan msatfinder glimmer pfam transterm);
my %execpaths = ("bigblast" => $proc->{bigblast},
								 "dbblast" => $proc->{dbblast},
								 "selfblast" => $proc->{selfblast},
								 "consblast" => $proc->{consblast},
								 "pfam" => $proc->{pfam},
								 "mspcrunch" => $proc->{mspcrunch},
								 "formatdb" => $proc->{formatdb},
								 "einverted" => $proc->{einverted},
								 "etandem" => $proc->{etandem}, 
								 "palindrome" => $proc->{palindrome},
								 "trnascan" => $proc->{trnascan},
								 "msatfinder" => $proc->{msatfinder},
								 "glimmer" => $proc->{glimmer},
								 "longorfs" => $proc->{longorfs},
								 "extract" => $proc->{extract},
								 "build_icm" => $proc->{build_icm},
								 "formatdb" => $proc->{formatdb},
								 "transterm" => $proc->{transterm},
								 "rbs" => $proc->{rbs});
my %parsers = ("bigblast" => $parse->{bigblast},
							 "dbblast" => $parse->{dbblast},
							 "selfblast" => $parse->{selfblast},
							 "consblast" => $parse->{consblast},
							 "pfam" => $parse->{pfam},
							 "einverted" => $parse->{einverted},
							 "etandem" => $parse->{etandem}, 
							 "palindrome" => $parse->{palindrome},
							 "trnascan" => $parse->{trnascan},
							 "msatfinder" => $parse->{msatfinder},
							 "glimmer" => $parse->{glimmer},
							 "repfinder" => $parse->{repfinder},
							 "transterm" => $parse->{transterm},
							 "rbs" => $parse->{rbs},
							 "quickmine" => $parse->{quickmine});
my %realname = ("bigblast" => "big_blast.pl",
								"dbblast" => "blastall",
								"selfblast" => "blastall",
								"consblast" => "blastall",
								"rbs" => "rbs_finder.pl",
								"glimmer" => "glimmer2",
								"pfam" => "pfam_scan.pl",
							  "longorfs" => "long-orfs",
								"trnascan" => "tRNAscan-SE",
								"build_icm" => "build-icm");

#################################################
# check that all the execpaths are in the $PATH #
#################################################
my @missing = ();
my $skipblast = 0;
foreach my $bin (keys %execpaths)
{
	# only run if this program is required
	if ($bin =~ /blast/) { $skipblast++ }
	next if ($skipblast > 1); 
	next if ($common->{$bin} eq "0");
	my $real;
	if (defined $realname{$bin}) 
	{ 
		$real = $realname{$bin}; 
	}
	else
	{
		$real = $bin;
	}
	my $elsewhere = "$bin found, but not where your config file says it should be. Continuing...\n";
	# check the various places it could be...
	if (-e $execpaths{$bin})
	{
		next;
	}
	else
	{
		my $search = `which $real 2> /dev/null`;
		chomp($search);
		if ($search =~ /aliased to (\.+)/)
		{
			$execpaths{$bin} = $1;
			print $elsewhere;
		}
		elsif (-x $search)
		{
			$execpaths{$bin} = $search;
			print $elsewhere;
		}
		else
		{
			push(@missing, $real);
		}
	}
} 

# warn the user if missing stuff
if (@missing)
{
	print "The following programs were not found on this system: @missing\n";
	print "Please add the full path to each dependency to the configuration file and try again.\n";
	exit;
}

my $len = @infiles;
##########################################
# run quickmine if needed #
##########################################
if ($common->{quickmine} == 1 and $len => 1)
{
	system("perl $installdir/bin/quickmine.pl -c $quickfile");


} 

##########################################
# create a self-blast database if needed #
##########################################
my $formatdb = $execpaths{formatdb};
my @catfiles = ();
if ($common->{selfblast} == 1 and $len > 1)
{
	print "Preparing self blast database...\n";
	# clean up old d
	if (-e "$outdir/$dbname")
	{
		unlink("$outdir/$dbname") or die "Can't remove old self-blast database: $!";
	}
	# cat only the other file to the db if there are two files
	my @dbfiles;
	if ($len == 2)
	{
		push (@catfiles, $infiles[1]);
	}
	else
	{
		foreach my $cf (@infiles) { push (@catfiles, $cf); }
	}
	# create new
	if (system("cat @catfiles >> $outdir/$dbname") == 0)
	{
		if (system("cd $outdir; $formatdb -i $dbname -o F -p F") == 0)
		{
			print "$dbname formatting complete.\n";
		}
		else
		{
			warn "Could not run formatdb.";
		}
	}
	else
	{
		print "Could not create $dbname: $!";	
	}
}
elsif ($common->{selfblast} == 1 and $len == 1) 
{
	print "Single sequence only - self-blast will not be run.\n";
}

####################################
# glimmer is needed if pfam is run #
####################################
if ($common->{pfam} == 1)
{
	unless ($common->{glimmer} == 1)
	{
		print "Activating glimmer - needed for pfam.\n";	
		$common->{glimmer} = 1;
	}
}
########################################
# glimmer is also needed for transterm #
########################################
if ($common->{transterm} == 1)
{
	unless ($common->{glimmer} == 1)
	{
		print "Activating glimmer - needed for transterm.\n";	
		$common->{glimmer} = 1;
	}
}
######################################
# run each of the annotation methods #
######################################
my %artline=();
my ($out,@seqfiles, $multiseq);

foreach my $infile (@infiles)
{
	# setup input file name and output directory name
	$infile = [split(/\//,$infile)]->[-1];
	my @tabfiles = ();

	# oh dear. Some people insist upon putting in FASTA
	# files with many sequences in them rather than the
	# one-file-per-metagenomic-sequence that I was expecting.
	# However, this can be dealt with using the power of SeqIO.
	# First, we must determine if the file has multiple sequences.
	$multiseq = 0;
	my $fastas = 0;
	my @slurp = ();
	open (CHECK, "<$infile") or die "Can't check $infile for No. of seqs. $!";
	while (my $line = <CHECK>)
	{
		$fastas++ if ($line =~ /^>/);
		if ($fastas > 1)
		{
			$multiseq = 1;
			last;
		}
	}
	close CHECK;
	
	if ($multiseq == 1)
	{
		my $parsed_files_already = $quickfig->param('RUN.parse');
		#check to see if files have already been split up using quickmine
		# if not they need to be processed now
		if ($common->{quickmine} != 1 || $parsed_files_already != 1)
		{
			# set quickmine config file so writes individual fasta files
			$quickfig->param("LEAVE_ALONE.write_fasta_files", 1);
			$quickfig -> save();
			# run script responsible for splitting the files
			system("perl $installdir/2qmfasta.pl $quickfile");
		}
		$infile =~m/(.*)\.(.*)/;
		my $temp_file = $1;
		my $temp_command = "$outdir/$temp_file"."orf*fasta";
		# this line may cause problems such as list too long, check for alternatives
		my @temp_seqfiles = `ls $temp_command`;
		foreach my $seqfile (@temp_seqfiles)
		{
			$seqfile =~m/$outdir\/(.*\.fasta)/;
			my $id = $1;
			push (@seqfiles, $id);
			$out = $outdir . "/" . $id . ".out";
			unless (-e $out)
			{
				mkdir("$out") or die "Can't create $out: $!";
			}
			system("ln -sf $pwd/$outdir/$id $pwd/$out/$id") == 0 or warn "Can't link genome file: $!";
			foreach my $exec (@execs)
			{
				if ($common->{$exec} == 1) 
				{
					$nothing = 1;
					# create a thread for each of the annotation steps
					# each thread to run its own condor job
					my $pass = "$id" . "|" . $exec . "|" . $out;
					my $pass = $id . "|" . $exec . "|" . $out;
					my $subroutine = "run_" . $exec;
					my $thr = threads->new("$subroutine","$pass");
					my $made = $thr->join();

					# remember which files go with each genome
					foreach my $file (@$made)
					{
						push(@{$artline{$id}}, $file);
					}
				}
			}
			if ($common->{quickmine} == 1)
			{
				my $quick_parse = $parsers{quickmine};
				system("perl $quick_parse $id $out $multiseq $quickfile")
				
			}
			print "Converting output to EMBL format...$out\n";
			print "$installdir/bin/$converter $id $out $multiseq\n";
			if (system("perl $installdir/bin/$converter $id $out $multiseq") == 0)
			{
				print "File converter finished.\n";
			}
			else
			{
				warn "Could not run converter.";
			}
		}
	}
	else
	{
		# use seqio to get an id
		my $basefile = Bio::SeqIO->new(-file => "$infile", -format => 'Fasta');

		while (my $seq = $basefile->next_seq())
		{
			my $id = $seq->display_id();
			$id =~ s/[\.|\||:|,|;]/_/g;
			if ($id eq "")
			{
				print "Invalid name in FASTA header. Please replace with something like \"seq1\", \"seq2\" etc.\nExiting!\n";
				next;
			}
			push (@seqfiles, $id);
	
			# the output directory should be named based on the seq id
			$out = $outdir . "/" . $id . ".out";
			unless (-e $out)
			{
				mkdir("$out") or die "Can't create $out: $!";
			}

			# this file should be written out to a temp. file 
			# for the various progs to run on it, and delete afterwards.
			# use a symlink instead if the file is a single seq, to save
			# on disk space
		
			system("ln -sf $pwd/$infile $pwd/$out/$id") == 0 or die "Can't symlink $id to $infile: $!";
			
			# run the outputs:
			# threading - go through each genome in turn, but spawn a
			# separate thread for each of the execs. This allows the use
			# of "die" in each thread. Threads must be joined rather than
			# detached at present in order to wait for completion.
			# This is slow, but will be changed in future to detach threads
			# containing condor DAG jobs &c.
			foreach my $exec (@execs)
			{
				if ($common->{$exec} == 1) 
				{
					$nothing = 1;
					# create a thread for each of the annotation steps
					# each thread to run its own condor job
					my $pass = "$id" . "|" . $exec . "|" . $out;
					my $pass = $id . "|" . $exec . "|" . $out;
					my $subroutine = "run_" . $exec;
					my $thr = threads->new("$subroutine","$pass");
					my $made = $thr->join();

					# remember which files go with each genome
					foreach my $file (@$made)
					{
						push(@{$artline{$id}}, $file);
					}
				}
			}
			if ($common->{quickmine} == 1)
			{
				my $quick_parse = $parsers{quickmine};
				print "parse = $quick_parse\n";
				system("perl $quick_parse $id $out $multiseq $quickfile")
			}
			print "Converting output to EMBL format...$out\n";
			print "$installdir/bin/$converter $id $out $multiseq\n";
			if (system("perl $installdir/bin/$converter $id $out $multiseq") == 0)
			{
				print "File converter finished.\n";
			}
			else
			{
				warn "Could not run converter.";
			}
		}	
	}
}

# exit early if no options set
if ($nothing == 0)
{
	print "No options were set, so no annotation programs were run.\n";
	print "\nYAMAP finished!\n";
	exit;
}


# convert output files to EMBL format
#if (@seqfiles  & $multiseq != 1)
#{
#	print "Converting output to EMBL format...$out\n";
#	if (system("cd $out; $installdir/bin/$converter @seqfiles") == 0)
#	{
#		print "File converter finished.\n";
#	}
#	else
#	{
#		warn "Could not run converter.";
#	}
#}
#elsif (@seqfiles  & $multiseq == 1)
#{
#	print "Multiple sequences - skipping EMBL conversion...\n";
#}
#else
#{
#	print "No output - skipping EMBL conversion...\n";
#}

#################################################
# print out a handy summary of what was created #
#################################################
my $printout = 0;
foreach my $infile (@seqfiles)
{
	if (defined @{$artline{$infile}})
	{
		$printout = 1;
		last;
	}
}
if ($printout == 1)
{
	print "Output files can be found in the following directories:\n\n";
	foreach my $infile (@seqfiles)
	{
		if (defined @{$artline{$infile}})
		{
			print "$pwd/$outdir/$infile.out\n";
		}
	}
}
else
{
	print "No output files created.\n";
}

# cleanup last file
if ($common->{msatfinder} == 1)
{
	unlink("msatfinder.rc");
}

# cleanup all extra seq files
if (defined $opts{x})
{
	foreach (@seqfiles) { unlink $_; }
}

# Finished
print "\nYAMAP finished!\n";

#######################################
# subroutines for each of the methods #
#######################################
# DBBLAST
sub run_dbblast 
{
	# now re-written to use blastall directly...
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $conf = uc $exec;
	my $blast = $execpaths{dbblast};
	my $blast_parse = $parsers{dbblast};
	my $bconf = $config->param(-block=>"$conf");
	my $program = $bconf->{program};
	my $jobs = $bconf->{jobs};
	my $other_opts = $bconf->{other_opts};
	my @outfiles;

	# set the correct database
	my $database;
	my $base = &basename($infile);
	my $dir = &dirname($infile);
	if ($exec eq "dbblast")
	{
		$database = $bconf->{database};
	}
	elsif ($exec eq "selfblast")
	{
		$database = "../self_blast";
	}
	elsif  ($exec eq "selfblast")
	{
		warn "This option is not yet available.\n";
		exit;
	}
	else
	{
		warn "ERROR: Something odd has happened with the blastall routine.\n";
		exit;
	}

	# only blast once if using "bl2seq"
	if ($len == 2 and $exec eq "selfblast")
	{
		return if (&basename($infile) eq $infiles[1]);
	}

	# exit if only one seq
	if ($len == 1 and $exec eq "selfblast")
	{
		return;
	}

	# get the correct program
	my %progs = ("blastn" => "-p blastn",
							 "blastx" => "-p blastx",
 							 "blastp" => "-p blastp",
							 "tblastx" => "-p tblastx");

	# run blast
	print "Running $exec on $infile...\n";
	if ($dir eq ".") { $dir = $pwd; }
	
	# collect the output in order to see if there are any warnings from blast 
	# failing to run for whatever reason
	my @output = `cd $dir/$out; $blast -d $database -i $infile $progs{$program} -m9 $other_opts 2>&1`;
	
	# write to stdout another way
	open (WARN, ">$dir/$out/$infile.$exec.stdout") or die "Can't write stdout for blast: $!";
	foreach my $outerr (@output) { print WARN "$outerr"; }
	close WARN;
	if (grep /WARNING/, @output)
	{
		print "Blast error! Please check $infile.$exec.stdout for details.\n"; 
		return;
	}
	else
	{
		print "Blast complete!\n";
		&copy("$dir/$out/$infile.$exec.stdout", "$dir/$out/$infile.$exec.out") or die "Can't copy blast output: $!"; 

		# attempt to parse the blast output
		if (system("$blast_parse $dir/$out/$infile.$exec.out") == 0)
		{
			push(@outfiles, "$infile.$exec.out");
		}
		else
		{
			warn "Could not parse blast output: $!";
			return;
		}
	}
	return \@outfiles;
}
# EINVERTED
sub run_einverted 
{
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $einverted = $execpaths{$exec};
	my $parse_einverted = $parsers{$exec};
	my $econf = $config->param(-block=>'EINVERTED');
	my $gap =	$econf->{gap};
	my $threshold =	$econf->{threshold};
	my $match =	$econf->{match};
	my $mismatch =$econf->{mismatch};
	my $maxrepeat =	$econf->{maxrepeat};
	my @outfiles;

	# run einverted
	print "Running einverted on $infile...\n";
	if (system("cd $out; $einverted -gap $gap -threshold $threshold -match $match -mismatch $mismatch -maxrepeat $maxrepeat -auto -outfile $infile.einverted.out $infile > $infile.einverted.stdout 2>&1") == 0)
	{
		if (system("cd $out; $parse_einverted $infile.einverted.out $infile.einverted.tab > $infile.einverted.stdout 2>&1") == 0)
		{
			print "Einverted complete!\n";
			push (@outfiles, "$out/$infile.einverted.tab");
			# clean up output files
		}
		else
		{
			warn "Could not parse $out/$infile.einverted.out: $!";
		}
	}
	else
	{
		warn "Could not run $einverted on $infile.";
	}
	unlink("$out/$infile.einverted.out");
	return \@outfiles;
}
# ETANDEM
sub run_etandem 
{
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $etandem = $execpaths{$exec};
	my $parse_etandem = $parsers{$exec};
	my @outfiles;
	my $equicktandem = $etandem;
	$equicktandem =~ s/etandem/equicktandem/;
	my $qtanfile = "$infile.qtan.out";
	my $tanfile = "$infile.tan.out";
	
	# equicktandem configs
	my $eqconf = $config->param(-block=>'EQUICKTANDEM');
	my $maxrepeat = $eqconf->{maxrepeat};	
	my $threshold = $eqconf->{threshold};

	# etandem configs
	my $econf = $config->param(-block=>'ETANDEM');
	my $mismatch = $econf->{mismatch};
	my $uniform = $econf->{uniform};

	# run equicktandem, parse to get min. and max sizes and
	# feed these into etandem 
	my ($max, $min, @sizes);
	print "Running equicktandem on $infile...\n";
	my $runquick = 0;
	if (system("cd $out; $equicktandem -threshold $threshold -maxrepeat $maxrepeat -outfile $qtanfile $infile > $infile.equicktandem.stdout 2>&1") == 0)
	{
		# get min and max repeat sizes by parsing qtan
		open (IN, "<$out/$qtanfile") or warn "Can't open $qtanfile: $!";
		my @lines = <IN>;
		close IN;
		foreach my $line (@lines)
		{
			next if ($line =~ /^#/ or $line =~ /Start/ or $line =~ /^\s+$/);
			push (@sizes, [split(/\s+/,$line)]->[3]);	
		}
		my @minmax = sort { $a <=> $b } @sizes;

		# don't run if no repeats found
		if (@minmax)
		{
			$max = $minmax[-1];
			$min = $minmax[0];
			$runquick = 1;
		}
		else
		{
			print "No repeats found; etandem will not be run.\n";
			return;
		}
	}
	else
	{
		warn "Could not run equicktandem - etandem will not be run.\n";
		return;
	}
	unlink("$out/$qtanfile");

	# run etandem on original file
	if ($runquick == 1)
	{
		if (system("cd $out; $etandem -minrepeat $min -maxrepeat $max -outfile $tanfile $infile > $infile.etandem.stdout 2>&1") == 0)
		{
			#parse etandem
			system("cd $out; $parse_etandem $tanfile $infile.etandem.tab");
			push(@outfiles, "$infile.etandem.tab");
			print "Etandem complete!\n";
		}
		else
		{
			warn "Could not run etandem!\n";		
		}
	}
	return \@outfiles;
}
# GLIMMER
sub run_glimmer 
{
	# glimmer is slightly different - there are more steps and more
	# executables. This is adapated from Chimdi's glimmer_auto script
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $glimmer = $execpaths{$exec};
	my $parse_glimmer = $parsers{$exec};
	my @outfiles;
	my $gconf = $config->param(-block=>'GLIMMER');
	my $args_longorfs = $gconf->{arguments_longorfs};
	my $args_glimmer2 = $gconf->{arguments_glimmer2};
	my $longorfs = $execpaths{longorfs};
	my $extract = $execpaths{extract};
	my $build_icm = $execpaths{build_icm};
	my $rbs = $execpaths{rbs};
	my $parse_rbs = $parse->{rbs};
	my $stdoutfile = "$infile.glimmer.stdout";
	my @outfiles;
	my $continue = 1;

	#######################################
	# run glimmer components and then rbs #
	#######################################
	# run long-orfs
	print "Running long-orfs on $infile...\n";
	unless (system("cd $out; $longorfs $args_longorfs $infile > $infile.glimmer.orfs 2> $stdoutfile") == 0)
	{
		warn "Could not run long-orfs.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return unless ($continue == 1);
	# remove header information from longorfs output
	my @long_orfs;
	if (!open(LONG_ORFS, "$out/$infile.glimmer.orfs"))
	{
		warn "Can't open $infile.glimmer.orfs for reading: $!";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	else
	{
		while (my $line = <LONG_ORFS>)
		{
			if ($line =~ /^\s*(T.*)\n/)
			{
				my $thing = $1;
				push(@long_orfs, $thing);
			}
		}
	}
	close LONG_ORFS;
	return unless ($continue == 1);
	# write each long orf to file
	if (!open (LONG_ORFS, ">$out/$infile.glimmer.orfs"))
	{ 
		warn "Can't open $infile.glimmer.orfs for reading: $!";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	else
	{
		foreach my $long_orfs (@long_orfs)
		{
			print LONG_ORFS "$long_orfs\n";
		}
	}
	close LONG_ORFS;
	return unless ($continue == 1);

	# run extract
	print "Running extract on $infile.glimmer.orfs...\n";
	unless (system ("cd $out; $extract $infile $infile.glimmer.orfs > $infile.glimmer.seq 2>> $stdoutfile") == 0)
	{
		warn "Could not run extract.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return unless ($continue == 1);

	# run build-icm
	print "Running build-icm on $infile.glimmer.seq...\n";
	unless (system ("cd $out; $build_icm < $infile.glimmer.seq > $infile.glimmer.icm 2>> $stdoutfile") == 0)
	{
		warn "Could not run build-icm.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return unless ($continue == 1);

	# actually run glimmer2 at last
	print "Running glimmer2 on $infile.glimmer.icm...\n";
	unless (system ("cd $out; $glimmer $args_glimmer2 $infile $infile.glimmer.icm > $infile.glimmer.output 2>> $stdoutfile") == 0)
	{
		warn "Could not run glimmer2.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return unless ($continue == 1);
	# parse glimmer output
	if (system ("cd $out; $parse_glimmer $infile.glimmer.output > $infile.glimmer.tab 2>> $stdoutfile") == 0)
	{
		print "Glimmer complete!\n";
		push (@outfiles, "$infile.glimmer.tab");
	}
	else
	{
		warn "Could not parse glimmer2: $!";
		print "Attempting to run rbsfinder...\n";
	}

	# run rbsfinder on glimmer output
	print "Running rbsfinder on $infile.glimmer.output...\n";
	unless (system("cd $out; $rbs $infile $infile.glimmer.output $infile.rbs.output >> $stdoutfile 2>&1") == 0)
	{
		warn "Could not run rbsfinder.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return unless ($continue == 1);

	# parse rbsfinder output
	if (system("cd $out; $parse_rbs $infile.rbs.output $infile.rbs.tab 2> $stdoutfile") == 0)
	{
		print "Rbsfinder complete!\n";
		push (@outfiles, "$infile.rbs.tab");
	}
	else
	{
		warn "Could not run rbsfinder.";
		print "Exiting glimmer pipeline!\n";
		$continue = 0;
	}
	return \@outfiles unless ($continue == 1);

	# clean up intermediate files
	my @clearup =  ("$infile.glimmer.icm", "$infile.glimmer.orfs", "$infile.glimmer.output", "$infile.glimmer.seq", "$infile.rbs.output");
	#foreach my $file (@clearup) { unlink "$out/$file"; }
	return \@outfiles;
}
# PALINDROME
sub run_palindrome 
{ 
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $palindrome = $execpaths{$exec};
	my $parse_palindrome = $parsers{$exec};
	my $pconf = $config->param(-block=>'PALINDROME');
	my $minpallen = $pconf->{minpallen};
	my $maxpallen = $pconf->{maxpallen};
	my $gaplimit = $pconf->{gaplimit};
	my $nummismatches = $pconf->{nummismatches};
	my $overlap = $pconf->{overlap};
	my @outfiles;
	my $outfile = "$infile.palindrome.out";
	my $tabfile = "$infile.palindrome.tab";
	my $stdoutfile = "$infile.palindrome.stdout";

	# run palindrome
	print "Running palindrome on $infile...\n";
	if (system("cd $out; $palindrome -stdout -minpallen $minpallen -maxpallen $maxpallen -gaplimit $gaplimit -nummismatches $nummismatches -overlap $overlap -outfile $outfile $infile > $stdoutfile 2>&1") == 0)
	{
		if (system("cd $out; $parse_palindrome $outfile $tabfile > $stdoutfile 2>&1") == 0)
		{
			push (@outfiles, $tabfile);
			print "Palindrome complete!\n";
		}
		else
		{
			warn "Could not parse palindrome output: $!";
		}
	}
	else
	{
		warn "Could not run palindrome";
	}
	# clean up
	if (-e "$outfile")
	{
		unlink ("$outfile");
	}
	return \@outfiles;
}
# TRNASCAN
sub run_trnascan 
{ 
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $trnascan = $execpaths{$exec};
	my $parse_trna = $parsers{$exec};
	my $tconf = $config->param(-block=>'TRNASCAN');
	my $searchmode = $tconf->{searchmode};
	my $covariance = $tconf->{covariance};
	my $showall = $tconf->{showall};
	my $other_opts = $tconf->{options};
	
	# outfiles
	my $outfile = "$infile.trnascan.out";
	my $stdoutfile = "$infile.trnascan.stdout";
	my $tabfile = "$infile.trnascan.tab";
	my @outfiles;

	# convert config file details into command line
	my %taxon = ("Bacterial" => "-B",
							 "Archeal" => "-A",
							 "Organellar" => "-O",
							 "Eukaryotic" => "-E",
							 "General" => "-G");
	my %covar = ("Y" => "-C", "N" => undef);
	my %show = ("Y" => "-H", "N" => undef);

	# command line
	my @options;

	# load command line
	push (@options, $taxon{$searchmode}) if (defined $taxon{$searchmode});
	push (@options, $covar{$covariance}) if (defined $covar{$covariance});
	push (@options, $show{$showall}) if (defined $show{$showall});
	push (@options, $other_opts) if (defined $other_opts);

	# run the code
	my $continue = 1;
	print "Running tRNAscan-SE with options \"@options\" on $infile...\n";
	unless (system("cd $out; $trnascan @options $infile > $outfile 2> $stdoutfile") == 0)
	{
		warn "Could not run tRNAscan-SE.";	
		$continue = 0;
	}
	return unless ($continue == 1);
	unless (-s "$out/$outfile")
	{
		print "No tRNAs found!\n";	
		$continue = 0;
	}
	return unless ($continue == 1);
	if (system("cd $out; $parse_trna $outfile $tabfile 2>> $stdoutfile") == 0)
	{
		print "tRNAscan complete!\n";
		push (@outfiles,$tabfile);
	}
	else
	{
		warn "Could not parse tRNAscan-SE output: $!";		
	}
	unlink("$outfile");
	return \@outfiles;
}
# SELFBLAST 
sub run_selfblast
{
	my $incoming = shift;
	return &run_dbblast($incoming);
}
# CONSBLAST
sub run_consblast
{
	#my $incoming = shift;
	#return &run_dbblast($incoming);
	print "This option is not yet available.\n";
}
# BIGBLAST
sub run_bigblast
{
	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $conf = uc $exec;
	my $bigblast = $execpaths{bigblast};
	my $bconf = $config->param(-block=>"$conf");
	my $database = $bconf->{database};
	my $program = $bconf->{program};
	my $jobs = $bconf->{jobs} || 1;
	my $other_opts = $bconf->{other_opts};
	my @outfiles;

	# set the correct database
	my $base = &basename($infile);
	my $dir = &dirname($infile);

	# get the correct program
	my %progs = ("blastn" => "-2",
							 "blastx" => "-x2",
							 "tblastx" => "-tx2");

	# run blast
	print "Running $exec on $infile...\n";
	if ($dir eq ".") { $dir = $pwd; }
	if (system("cd $out; $bigblast $progs{$program} -j $jobs  $database $infile $other_opts > $infile.$exec.stdout 2>&1") == 0)
	{
		print "Blast complete!\n";
		my @files = glob "$out/big_blast*";
		foreach my $file (@files)
		{
			if ($file =~ /\.\d{8}/)
			{
				unlink("$file");
			}
			else
			{
				my $newname = &basename($infile) . ".$exec." . [split(/\./, $file)]->[-1];
				&move("$file", "$out/$newname") or warn "Can't move $file to $newname: $!";
				push (@outfiles, $newname);
			}
		}
	}
	else
	{
		warn "Could not run $bigblast on $infile: $!\n";
	}
	return \@outfiles;

}

# MSATFINDER
sub run_msatfinder 
{ 
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];

	# write out msatfinder config file
	my $msatfinder = $execpaths{$exec};
	my $mconf = $config->param(-block=>'MSATFINDER');
	my $flank_size = $mconf->{flank_size};
	my $mrange =  $mconf->{mrange};
	my $engine =  $mconf->{engine};
	my $interrupts =  $mconf->{interrupts};
	my @outfiles;

	# Annoyingly, when yamap.pl saves $mrange, it drops the quotes
	# which causes Config::Simple to convert it into an array, with
	# disastrous consequences. So, yamap's config file uses "+" not 
	# ",", and this matter is corrected below:
	$mrange =~ s/\+/,/g;

	# write configuration file
	open (CONF, ">$out/msatfinder.rc") or die "Can't open msatfinder.rc: $!";
	print CONF <<EOF;
[COMMON]
debug=0
flank_size=$flank_size
mine_dir="MINE/"
repeat_dir="Repeats/"
tab_dir="Msat_tabs/"
bigtab_dir="Flank_tabs/"
fasta_dir="Fasta/"
prime_dir="Primers/"
align_dir="Aligner/"
anno_dir="Annotations/"
count_dir="Counts/"
[DEPENDENCIES]
run_eprimer=0
eprimer_args="-primer"
eprimer="/usr/bin/eprimer3"
primer3core="/usr/bin/primer3_core"
[FINDER]
override=0
motif_threshold="$mrange"
artemis=1
mine=0
fastafile=0
sumswitch=0
screendump=0
EOF
	close CONF;

	# run msatfinder
	my $cleanup = 0;
	print "Running msatfinder on $infile...\n";
	if (system("cd $out; $msatfinder -e $engine $infile > $infile.msatfinder.stdout 2>&1") == 0)
	{
		print "Msatfinder finished.\n";	
		$cleanup = 1;
	}
	else
	{
		warn "Could not run $msatfinder.";
		return;
	}

	# move tabs to the proper location
	# and delete all output
	if ($cleanup == 1)
	{
		# move
		my @tabs = glob "$out/Msat_tabs/*.msat_tab";
		foreach my $tab (@tabs)
		{
			&move("$tab", "$out/$infile.msatfinder.tab");
			push (@outfiles, "$infile.msatfinder.tab");
		}
		# purge
		my @purge = qw(results.html MINE Repeats Msat_tabs Flank_tabs Fasta Primers Aligner Annotations Counts msatfinder.rc);
		foreach my $pu (@purge)
		{
			system("rm -rf $out/$pu") == 0 or warn "Can't unlink $pu: $!";
		}
	}
	return \@outfiles;
}

# PFAM
sub run_pfam
{
	unless ($common->{glimmer} == 1)
	{
		print "Pfam cannot be run without glimmer's output. Skipping...\n";
		return;
	}
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];

	my $conf = uc $exec;
	my $pconf = $config->param(-block=>"$conf");
	my $db = $pconf->{database};
	my $fast = $pconf->{fast};
	my $overlap = $pconf->{overlap};
	my $other_opts = $pconf->{other_opts};

	my $pfam = $execpaths{$exec};
	my $parse_pfam = $parsers{$exec};
	my $orffile = "$infile.glimmer.orfs";
	my @outfiles;
	my @tabfile;

	# exit if the orffile is not there
	unless (-s "$out/$orffile")
	{
		print "No orfs found - cannot run Pfam. Skipping...\n";
		return;
	}

	# the "overlap" and "fast" options are 
	# on or off, and should be set by buttons
	# on the GUI. I'll leave the rest for 
	# "other_opts"
	my $fastyn = "";
	if ($fast == 1)
	{
		$fastyn = "--fast";
	}
	my $overlapyn = "";
	if ($overlap == 1)
	{
		$overlapyn = "--overlap";
	}

	# if the database does not exist, then there's no point carrying on
	my @pfams = glob "$db/Pfam-*";
	unless (@pfams)
	{
		print "No Pfam database found, skipping scan of $infile...\n";
		return;
	}
	
	# get orfs
	open (ORFS, "<$out/$orffile") or warn "Can't read orfs from $orffile: $!";
	my @olines = <ORFS>;
	close ORFS;

	# put each orf into an array
	my (%orfs,@transfiles);
	foreach my $line (@olines)
	{
		my ($name,$start,$stop) = split(/\s+/, $line);
		$orfs{$start} = $stop;
	}

	# open seq
	my $seqobj = Bio::SeqIO->new(-file => "$out/$infile", -format=>"FASTA");
	while (my $seq = $seqobj->next_seq())
	{
		foreach my $start (keys %orfs)
		{
			# generate an AA translation for each orf
			my $stop = $orfs{$start};
			my ($transfile,$outfile,$tabfile,$stdoutfile,$subseq,$protseq);
			if ($start < $stop)
			{
				$transfile = "$infile.$start-$stop.trans";
				$subseq = $seq->trunc($start,$stop);
				$protseq = $subseq->translate();
			}
			elsif ($start > $stop)
			{
				$transfile = "$infile.$start.trans";
				$subseq = $seq->trunc($stop,$start);
				$protseq = $subseq->translate();
			}
			else 
			{
				print "Something has gone horribly wrong.\n";
				next;
			}

			# print it out to the translation
			open (OUT, ">$out/$transfile") or exit "Can't write AA translation: $!";
			print OUT "> $transfile\n";
			print OUT $protseq->seq();
			push (@transfiles, $transfile);
		}
	}
	close OUT;

	# run pfam on the local database, using the translated file
	foreach my $tf (@transfiles)
	{
		my $outfile = $tf;
		my $tabfile =  $tf;
		my $stdoutfile = $tf;
		$outfile =~ s/trans/pfam/;
		$tabfile =~ s/trans/pfam.tab/;
		$stdoutfile =~ s/trans/pfam.stdout/; 
		print "Running Pfam scan on $tf...\n";

		if (system("cd $out; $pfam -d $db -o $outfile $fastyn $overlapyn $other_opts $tf > $stdoutfile 2>&1") == 0)
		{
			# it worked
			print "Pfam scan complete.\n";
			# empty output file if no hits found
			if (-z "$out/$outfile") 
			{
				print "No Pfam hits found.\n";
				unlink "$out/$outfile";
				unlink "$out/$stdoutfile";
				next;
			}
		}
		else
		{
			print "Pfam scan failed! $!";
			next;
		}

		# parse the pfam output
		eval {
		if (system("cd $out; $parse_pfam $outfile $tabfile") == 0)
		{
			print "Parsing Pfam output...\n";
			push(@outfiles, $tabfile);
		}
		else
		{
			print "Could not parse Pfam! $!";
			return;
		} };

		# finish
		unlink "$out/$tf" if (-e "$out/$tf");
		unlink "$out/$outfile" if (-e "$out/$outfile");
	}
	# concatenate all tab files into one big one...
	# some people are never satisfied.
	my $concat = "$out/$infile.pfam.tab";
	open (TAB, ">$concat") or die "Can't concatenate pfam tab files: $!";
	foreach my $tab (@outfiles)
	{
		print "OUT: $tab\n";
		open (SMALL, "<$out/$tab") or die  "Can't open $tab: $!";		
		while (my $line = <SMALL>)
		{
			print TAB $line;
		}
		close SMALL;
		unlink "$out/$tab";
	} 
	close TAB;
	push (@tabfile, $concat);
	return \@tabfile;
}
# TRANSTERM
sub run_transterm
{ 
	# N.B. TransTerm is a bit dodgy, and may die if there is no space
	# between > and the seq. identifier in the FASTA header...
	# this is supposed to be fixed, according to the developer, but
	# it still seems not to work. This code has therefore been hacked
	# to get the code to produce a result. For it to work there
	# MUST NOT be the space, as mentioned above.
	# Please fix this as soon as transterm can be made to behave!

	# get the config details
	my $incoming = shift;
	my @parts = split(/\|/, $incoming);
	my $infile = $parts[0];
	my $exec = $parts[1];
	my $out = $parts[2];
	my $transterm = $execpaths{$exec};
	my $parse_transterm = $parsers{$exec};
	my $tconf = $config->param(-block=>'TRANSTERM');
	my $version =  $tconf->{version};
	my $other_opts = $tconf->{other_opts} || "";
	my $confidence = "";;
	my $expterm = "/usr/local/bioinf/transterm/transterm/expterm.dat";
	
	# use v.2 confidence if available
	if ( -e $expterm && $version == 2)
	{
		$confidence = "-r $expterm";
	}

	# abort here if there is no output from glimmer
	my $orffile = "$infile.glimmer.orfs";

	# exit if the orffile is not there
	unless (-e "$out/$orffile")
	{
		print "No orfs found - cannot run TransTerm. Skipping...\n";
		return;
	}
	
	# outfiles
	my $outfile = "$infile.transterm.out";
	my $stdoutfile = "$infile.transterm.stdout";
	my $tabfile = "$infile.transterm.tab";
	my $coordfile = "$infile.crd";

	# a coordfile will have to be fabricated from the 
	# orffile in order to make transterm work
	open (ORF,"<$out/$orffile") or warn "Can't open $orffile: $!";
	my @orfinfo = <ORF>;
	close ORF;
	open (CRD, ">$out/$coordfile") or warn "Can't open $coordfile: $!";
	foreach my $line (@orfinfo)
	{
		chomp($line);
		my @items = split(/\s+/, $line);
		# the name of the file should really be added to this
		# array, but it seems to break transterm. It has therefore
		# been omitted for now. It should be added when more info.
		# on making transterm work can be determined.
		#push(@items, $infile);
		print CRD join("\t", @items), "\n";
	}
	close CRD;
	
	my @outfiles;

	# command line
	my $continue = 1;
	print "Running TransTerm on $infile...\n";
	unless (system("cd $out; $transterm $other_opts $confidence $infile $coordfile > $outfile 2> $stdoutfile") == 0)
	{
		warn "Could not run TransTerm";	
		$continue = 0;
	}
	return unless ($continue == 1);
	unless (-s "$out/$outfile")
	{
		print "No TransTerm output!\n";	
		$continue = 0;
	}
	return unless ($continue == 1);
	if (system("cd $out; $parse_transterm $outfile $tabfile 2>> $stdoutfile") == 0)
	{
		print "TransTerm finished!\n";
		push (@outfiles,$tabfile);
	}
	else
	{
		warn "Could not parse TransTerm output: $!";		
	}
	unlink("$outfile");
	return \@outfiles;
}

__END__
