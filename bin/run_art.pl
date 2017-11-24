#!/usr/bin/perl

use strict;
use Config::Simple;
use File::Basename;

# get infiles and glob tabs
unless (@ARGV)
{
	die "Usage run_art.pl <basedir>\n";
}

# basedir
my $basedir = shift;

# get artemis location from configs
my $installdir = "/usr/local/bioinf/yamap/yamap";
my $path_file  = "$installdir/etc/yamap_paths.ini";
my $paths = new Config::Simple($path_file);
my $proc = $paths->param(-block=>'PROCESSING');
my $artemis = $proc->{artemis};


# get the list out output files
my $out = $basedir . "/yamap_out/"; 
opendir(DIR, $out) || warn "Can't opendir $out: $!";
my @files = grep { /\.embl$/ } readdir(DIR);
closedir DIR;
unless (@files)
{
	print "No annotations found for this genome.\n";
	exit;
}
foreach my $file (@files) 
{ 
	print "Running command: $artemis $file\n";
	unless (system("$artemis $out/$file") ==0)
	{
		die "Can't run artemis: $!";
	}
}

# finished
print "All files viewed.\n";
