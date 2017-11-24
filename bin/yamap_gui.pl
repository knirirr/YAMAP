#!/usr/bin/perl

use strict;
use lib qw(/usr/local/bioinf/yamap/lib);

use Config::Simple;
use Cwd;
use File::Copy;
use File::Basename;
use IO::Pipe;
use Proc::ProcessTable;
use Tk;
use Tk::DirSelect;
use Tk::ExecuteCommand;
use Tk::ROText;

# location of install files (/usr/local/bioinf/yamap)
my $script = "yamap.pl";
my $pwd = getcwd;
my $dir = undef;
my $glob = "fasta";
my $installdir = "/usr/local/bioinf/yamap";
my $artemis = "$installdir/bin/run_art.pl";
my $basedir;
my $oneormany = "one";

# location of config files
my $home = $ENV{'HOME'};
# create a ~/.yamap dir for the user
unless (-e "$home/.yamap")
{
	system("mkdir $home/.yamap") == 0 or warn "Can't create $home/.yamap: $!";
}
# set up the run file
unless (-e "$home/.yamap/yamap_run.ini")
{
	&copy("$installdir/etc/yamap_run.ini","$home/.yamap/yamap_run.ini") or warn "Can't copy user config file to $home/.yamap: $!";
}
my $config_file = "$home/.yamap/yamap_run.ini";
# set up the paths file
unless (-e  "$home/.yamap/yamap_paths.ini")
{
	&copy("$installdir/etc/yamap_paths.ini","$home/.yamap/yamap_paths.ini") or warn "Can't copy path config file to $home/.yamap: $!";
}
my $path_file =  "$home/.yamap/yamap_paths.ini";;

my $config = new Config::Simple($config_file);
my $args;
my $confcolour = "green";

# run variables, from config file
my $common = $config->param(-block=>'COMMON');
my $outdir = $common->{outdir};
my $r_bigblast = $common->{bigblast}; 
my $r_selfblast = $common->{selfblast}; 
my $r_invert = $common->{einverted};
my $r_tandem = $common->{etandem};
my $r_glim = $common->{glimmer};
my $r_msat = $common->{msatfinder};
my $r_palin = $common->{palindrome};
my $r_trna = $common->{trnascan};

# get details for running artemis
my $paths =  new Config::Simple($path_file) or die "Can't get artemis location: $!";
my $proc = $paths->param(-block=>'PROCESSING');

#########################
#Create the Main Window #
#########################
my $mw = MainWindow->new();
my $label = $mw -> Label(-text=>"YAMAP-GUI",-relief=>"raised");
my $spacer1 = $mw -> Label(-text=>"Select input files",-relief=>"groove");
my $spacer2 = $mw -> Label(-text=>"Configure annotation programs",-relief=>"groove");
my $spacer3 = $mw -> Label(-text=>"");
my $enter_args = $mw ->  Button(-text=>"Single file", 
																-command => sub {
																$args = $mw->getOpenFile(-filetypes => [ ['All Files','*'] ],
																												 -title=>"Select genome file",
																												 -initialdir => "$pwd");
																
																});

my $suff_lab = $mw -> Entry(-textvariable=>\$glob);
$suff_lab->configure(-state=>'disabled');
my $suff_txt = $mw -> Label(-text=>"File suffix");
my $file_name = $mw -> Entry(-textvariable=>\$args);
my $ds = $mw->DirSelect(-title=>'Data Directory');
my $dir_name = $mw -> Entry(-textvariable=>\$dir);
$dir_name->configure(-state=>'disabled');
my $choose_dir = $mw ->  Button(-text=>"Select data directory", 
																-command=>sub { 
																$dir = $ds->Show();
																return $dir;
																});
$choose_dir->configure(-state=>'disabled');
my $onefile = $mw -> Radiobutton(-text => 'Single file',
																 -value    => "one",
																 -variable => \$oneormany,
																 -command => sub { 
																 $enter_args->configure(-state=>'normal'); 
																 $file_name->configure(-state=>'normal'); 
																 $choose_dir->configure(-state=>'disabled');
																 $suff_lab->configure(-state=>'disabled');
																 $dir_name->configure(-state=>'disabled')
																 });
my $onedir = $mw -> Radiobutton(-text => 'Files from directory',
																-value    => "many",
																-variable => \$oneormany,
															 	-command => sub { 
																 $enter_args->configure(-state=>'disabled'); 
																 $file_name->configure(-state=>'disabled'); 
																 $choose_dir->configure(-state=>'normal');
																 $suff_lab->configure(-state=>'normal');
																 $dir_name->configure(-state=>'normal')
															 });



# checkboxes
my $t_bigblast = $mw -> Checkbutton(-text=>"Big blast", -variable=>\$r_bigblast);
my $t_selfblast = $mw -> Checkbutton(-text=>"Self blast", -variable=>\$r_selfblast);
my $t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert);
my $t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem);
my $t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim);
my $t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat);
my $t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin);
my $t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna);

# edit the configs
my $bigblast_button = $mw -> Button(-text=>"Configure", -command =>\&bigblast_conf);
my $selfblast_button = $mw -> Button(-text=>"Configure", -command =>\&selfblast_conf);
my $invert_button = $mw -> Button(-text=>"Configure", -command =>\&invert_conf);
my $tandem_button = $mw -> Button(-text=>"Configure", -command =>\&tandem_conf);
my $glim_button = $mw -> Button(-text=>"Configure", -command =>\&glim_conf);
my $msat_button = $mw -> Button(-text=>"Configure", -command =>\&msat_conf);
my $palin_button = $mw -> Button(-text=>"Configure", -command =>\&palin_conf);
my $trna_button = $mw -> Button(-text=>"Configure", -command =>\&trna_conf);

# run or quit
my $run_button =  $mw -> Button(-text => "Run", 
																-command => \&runprogs );
my $quit_button = $mw -> Button(-text => "Quit", 
																-command => \&exitprogram );

# top section geometry
$label -> grid(-row=>0,-column=>0,-columnspan=>2);
$spacer1-> grid(-row=>1,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$onefile -> grid(-row=>2,-column=>0,-sticky=>"w");
$enter_args -> grid(-row=>3,-column=>0);
$file_name ->  grid(-row=>3,-column=>1);
$onedir -> grid(-row=>4,-column=>0,-sticky=>"w");
$suff_lab -> grid(-row=>5,-column=>1);
$suff_txt -> grid(-row=>5,-column=>0);
$choose_dir -> grid(-row=>6,-column=>0);
$dir_name -> grid(-row=>6,-column=>1);
$spacer2-> grid(-row=>7,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);

# edit button geometry
# labels...
$t_bigblast -> grid(-row=>8,-column=>0,-sticky=>"w");
$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
$t_invert -> grid(-row=>10,-column=>0,-sticky=>"w");
$t_tandem -> grid(-row=>11,-column=>0,-sticky=>"w");
$t_glim -> grid(-row=>12,-column=>0,-sticky=>"w");
$t_msat -> grid(-row=>13,-column=>0,-sticky=>"w");
$t_palin -> grid(-row=>14,-column=>0,-sticky=>"w");
$t_trna -> grid(-row=>15,-column=>0,-sticky=>"w");
# buttons...
$bigblast_button -> grid(-row=>8,-column=>1,-sticky=>"e");
$selfblast_button -> grid(-row=>9,-column=>1,-sticky=>"e");
$invert_button -> grid(-row=>10,-column=>1,-sticky=>"e");
$tandem_button -> grid(-row=>11,-column=>1,-sticky=>"e");
$glim_button -> grid(-row=>12,-column=>1,-sticky=>"e");
$msat_button -> grid(-row=>13,-column=>1,-sticky=>"e");
$palin_button -> grid(-row=>14,-column=>1,-sticky=>"e");
$trna_button -> grid(-row=>15,-column=>1,-sticky=>"e");

# run and quit geometry
$spacer3-> grid(-row=>17,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$run_button -> grid(-row=>18,-column=>0,-sticky=>"e");
$quit_button -> grid(-row=>18,-column=>1,-sticky=>"w");

# stick it on the screen!
$mw->MainLoop;



###############
# subroutines #
###############
# RUN
sub runprogs
{
	# if one file selected
	if ($oneormany eq "one")
	{
		unless ($args)
		{
			$mw -> messageBox(-type=>"ok",
												-icon=>'error',
												-message=>"Please select a genome file.");
			return;
		}
	}
	elsif ($oneormany eq "many")
	{
		# determine if a directory has been selected
		if (defined $dir)
		{
			my @files = glob "$dir/*\.$glob";
			foreach my $file (@files) { $args .= "$file "; }
			unless (@files)
			{
				$mw -> messageBox(-type=>"ok",
													-icon=>'error',
													-message=>"No suitable files found.");
				return;
			}
		}
		else
		{
			$mw -> messageBox(-type=>"ok",
												-icon=>'error',
												-message=>"Please select a data directory.");
			return;

		}
	}
	else
	{
		die "Something has gone horribly wrong: $!";
	}

	# save info on which programs are to be run
	$config->param("COMMON.bigblast", $r_bigblast || 0);
	$config->param("COMMON.einverted", $r_invert || 0);
	$config->param("COMMON.etandem", $r_tandem || 0);
	$config->param("COMMON.glimmer", $r_glim || 0);
	$config->param("COMMON.msatfinder", $r_msat || 0);
	$config->param("COMMON.palindrome", $r_palin || 0);
	$config->param("COMMON.trnascan", $r_trna || 0);
	$config->save();

	# determine which dir we're in
	my $basedir;
	if (defined $dir and $oneormany eq "many")
	{
		$basedir = $dir;
	}
	else
	{
		$basedir = &dirname("$args");
		$basedir =~ s/\/$//;
	}

	# create display window
	my $top = $mw-> Toplevel();
	my $label = $top -> Label(-text=>"Pipeline progress", 
														-relief=>"groove")->pack();

	# run the program
	my $ec = $top->ExecuteCommand(-command    => '',
																-entryWidth => 50,
																-height     => 10,
																-label      => 'Run YAMAP',
																-text       => 'Execute')->pack(-fill=>"both",-expand=>1);
	$ec->configure(-command => "cd $basedir; $installdir/bin/$script -c $config_file -p $path_file $args");
	$ec->execute_command;
	$ec->bell;
	$ec->update;

	# view results in artemis
	my $art = $top -> Button(-text=>"View results in artemis", -command => sub 
	{ 
		# strange Tk::Widget::insert problems appear here
		no warnings;

		# view results in artemis
		my $top2 = $top->Toplevel();
		my $runart = $top2->ExecuteCommand(-command    => '',
																			-entryWidth => 40,
																			-height     => 5,
							  											-label      => 'Run Artemis',
								  										-text       => 'View results in Artemis')->pack(-fill=>"both",-expand=>1);
		$runart->configure(-command => "$artemis $basedir $args");
		my $close = $top2 -> Button(-text=>"Close window", -command => sub { destroy $top2; })->pack();

		$runart->execute_command;
		$runart->bell;
		$runart->update;
	})->pack();

	# add close button
	my $close = $top -> Button(-text=>"Close window", -command => sub { destroy $top; })->pack();

	# ask if the user wants to quit
	#my $response = $mw->messageBox(-message=>"Programs complete. Quit?", 
	#															 -type=>'yesno', 
  #                               -icon=>'question');
	#if( $response =~ /yes/i ) { exit; }
}
# EXIT
sub exitprogram 
{
 	my $response = $mw->messageBox(-message=>"Really quit?", 
																 -type=>'yesno',
																 -icon=>'question');
	if( $response =~ /yes/i ) 
	{ 
		exit; 
	}
	#else 
	#{
	#	$mw -> messageBox(-type=>"ok",
	#										-icon=>'info',
	#										-message=>"Huzzah!");
	#}
}
# BIGBLAST
sub bigblast_conf 
{
	# vars
	my $confs = $config->param(-block=>'BIGBLAST');
	my $program = $confs->{program};
	my $database = $confs->{database};
	my $jobs = $confs->{jobs};
	# new window
	my $top = $mw -> Toplevel();

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'blastn',
																 -value    => "blastn",
  															 -variable => \$program);
	my $rad2 = $top -> Radiobutton(-text => 'blastx',
																 -value    => "blastx",
  															 -variable => \$program);
	my $rad4 = $top -> Radiobutton(-text => 'tblastx',
																 -value    => "tblastx",
  															 -variable => \$program);

	my $ent2 = $top -> Entry(-textvariable=>\$database);
	my $ent3 = $top -> Entry(-textvariable=>\$jobs);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("BIGBLAST.program", $program);
		$config->param("BIGBLAST.database", $database);
		$config->param("BIGBLAST.jobs", $jobs);
		$config -> save();
		$bigblast_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });



	# labels
	my $lab1 = $top -> Label(-text=>"Big-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Database");
	my $lab3 = $top -> Label(-text=>"Number of jobs");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2);
	$rad2 -> grid(-row=>2,-column=>0,-columnspan=>2);
	$rad3 -> grid(-row=>3,-column=>0,-columnspan=>2);
	$rad4 -> grid(-row=>4,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>5,-column=>0);
	$lab3 -> grid(-row=>6,-column=>0);
	$ent2 -> grid(-row=>5,-column=>1);
	$ent3 -> grid(-row=>6,-column=>1);
	$save -> grid(-row=>7,-column=>0,-sticky=>"w");
	$close -> grid(-row=>7,-column=>1,-sticky=>"e");
}
# EINVERTED
sub invert_conf 
{
	# vars
	my $confs = $config->param(-block=>'EINVERTED');
	my $gap = $confs->{gap};
	my $threshold = $confs->{threshold};
	my $match = $confs->{match};
	my $mismatch = $confs->{mismatch};
	my $maxrepeat = $confs->{maxrepeat};

	# new window
	my $top = $mw -> Toplevel();
	my $ent1 = $top -> Entry(-textvariable=>\$gap);
	my $ent2 = $top -> Entry(-textvariable=>\$threshold);
	my $ent3 = $top -> Entry(-textvariable=>\$match);
	my $ent4 = $top -> Entry(-textvariable=>\$mismatch);
	my $ent5 = $top -> Entry(-textvariable=>\$maxrepeat);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("EINVERTED.gap", $gap);
		$config->param("EINVERTED.threshold", $threshold);
		$config->param("EINVERTED.match", $match);
		$config->param("EINVERTED.mismatch", $mismatch);
		$config->param("EINVERTED.maxrepeat", $maxrepeat);
		$config -> save();
		$invert_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });

	# labels
	my $lab1 = $top -> Label(-text=>"Einverted configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Gap");
	my $lab3 = $top -> Label(-text=>"Threshold");
	my $lab4 = $top -> Label(-text=>"Match");
	my $lab5 = $top -> Label(-text=>"Mismatch");
	my $lab6 = $top -> Label(-text=>"Maxrepeat");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$ent3 -> grid(-row=>3,-column=>1);
	$ent4 -> grid(-row=>4,-column=>1);
	$ent5 -> grid(-row=>5,-column=>1);
	$save -> grid(-row=>6,-column=>0,-sticky=>"w");
	$close -> grid(-row=>6,-column=>1,-sticky=>"e");
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>1,-column=>0);
	$lab3 -> grid(-row=>2,-column=>0);
	$lab4 -> grid(-row=>3,-column=>0);
	$lab5 -> grid(-row=>4,-column=>0);
	$lab6 -> grid(-row=>5,-column=>0);

}
# ETANDEM
sub tandem_conf 
{
	# vars
	my $confs = $config->param(-block=>'ETANDEM');
	my $uniform = $confs->{uniform};
	my $mismatch = $confs->{mismatch};
	my $minrepeat = $confs->{minrepeat};
	# new window
	my $top = $mw -> Toplevel();
	my $ent1 = $top -> Entry(-textvariable=>\$uniform);
	my $ent2 = $top -> Entry(-textvariable=>\$mismatch);
	my $ent3 = $top -> Entry(-textvariable=>\$minrepeat);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("ETANDEM.program", $uniform);
		$config->param("ETANDEM.database", $mismatch);
		$config->param("ETANDEM.jobs", $minrepeat);
		$config -> save();
		$tandem_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });

	# labels
	my $lab1 = $top -> Label(-text=>"Etandem configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Uniform");
	my $lab3 = $top -> Label(-text=>"Mismatch");
	my $lab4 = $top -> Label(-text=>"Minrepeat");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$ent3 -> grid(-row=>3,-column=>1);
	$save -> grid(-row=>4,-column=>0,-sticky=>"w");
	$close -> grid(-row=>4,-column=>1,-sticky=>"e");
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>1,-column=>0);
	$lab3 -> grid(-row=>2,-column=>0);
	$lab4 -> grid(-row=>3,-column=>0);


}
# GLIMMER
sub glim_conf 
{
	# vars
	my $confs = $config->param(-block=>'GLIMMER');
	my $arguments_longorfs = $confs->{arguments_longorfs};
	my $arguments_glimmer2 = $confs->{arguments_glimmer2};

	# new window
	my $top = $mw -> Toplevel();
	my $ent1 = $top -> Entry(-textvariable=>\$arguments_longorfs);
	my $ent2 = $top -> Entry(-textvariable=>\$arguments_glimmer2);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("GLIMMER.arguments_longorfs", $arguments_longorfs);
		$config->param("GLIMMER.arguments_glimmer2", $arguments_glimmer2);
		$config -> save();
		$glim_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });

	# labels
	my $lab1 = $top -> Label(-text=>"Glimmer configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Glimmer arguments");
	my $lab3 = $top -> Label(-text=>"Longorfs arguments");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$save -> grid(-row=>3,-column=>0,-sticky=>"w");
	$close -> grid(-row=>3,-column=>1,-sticky=>"e");
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>1,-column=>0);
	$lab3 -> grid(-row=>2,-column=>0);
}
# PALINDROME
sub palin_conf 
{
	# vars
	my $confs = $config->param(-block=>'PALINDROME');
	my $minpallen = $confs->{minpallen};
	my $maxpallen = $confs->{maxpallen};
	my $gaplimit = $confs->{gaplimit};
	my $nummismatches = $confs->{nummismatches};
	my $overlap = $confs->{overlap};

	# new window
	my $top = $mw -> Toplevel();
	my $ent1 = $top -> Entry(-textvariable=>\$minpallen);
	my $ent2 = $top -> Entry(-textvariable=>\$maxpallen);
	my $ent3 = $top -> Entry(-textvariable=>\$gaplimit);
	my $ent4 = $top -> Entry(-textvariable=>\$nummismatches);
	my $ent5 = $top -> Entry(-textvariable=>\$overlap);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("PALINDROME.minpallen", $minpallen);
		$config->param("PALINDROME.maxpallen", $maxpallen);
		$config->param("PALINDROME.gaplimit", $gaplimit);
		$config->param("PALINDROME.nummismatches", $nummismatches);
		$config->param("PALINDROME.overlap", $overlap);
		$config -> save();
		$palin_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });

	# labels
	my $lab1 = $top -> Label(-text=>"Palindrome configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Minpallen");
	my $lab3 = $top -> Label(-text=>"Maxpallen");
	my $lab4 = $top -> Label(-text=>"Gaplimit");
	my $lab5 = $top -> Label(-text=>"Nummismatches");
	my $lab6 = $top -> Label(-text=>"overlap");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$ent3 -> grid(-row=>3,-column=>1);
	$ent4 -> grid(-row=>4,-column=>1);
	$ent5 -> grid(-row=>5,-column=>1);
	$save -> grid(-row=>6,-column=>0,-sticky=>"w");
	$close -> grid(-row=>6,-column=>1,-sticky=>"e");
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>1,-column=>0);
	$lab3 -> grid(-row=>2,-column=>0);
	$lab4 -> grid(-row=>3,-column=>0);
	$lab5 -> grid(-row=>4,-column=>0);
	$lab6 -> grid(-row=>5,-column=>0);

}
# TRNASCAN
sub trna_conf 
{
	# vars
	my $tconf = $config->param(-block=>'TRNASCAN');
	my $searchmode = $tconf->{searchmode};
	my $covariance = $tconf->{covariance};
	my $showall = $tconf->{showall};
	my $other_opts = $tconf->{other_opts};

	# new window, buttons &c.
	my $top = $mw -> Toplevel();

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'Bacterial mode',
																 -value    => "Bacterial",
  															 -variable => \$searchmode);
	my $rad2 = $top -> Radiobutton(-text => 'Archeal mode',
																 -value    => "Archeal",
  															 -variable => \$searchmode);
	my $rad3 = $top -> Radiobutton(-text => 'Organellar mode',
																 -value    => "Organellar",
  															 -variable => \$searchmode);
	my $rad4 = $top -> Radiobutton(-text => 'Eukaryotic mode',
																 -value    => "Eukaryotic",
  															 -variable => \$searchmode);
	my $rad5 = $top -> Radiobutton(-text => 'General mode',
																 -value    => "General",
  															 -variable => \$searchmode);

	# checkboxes
	# most of this stuff is to translate from Y/N to 1/0
	my %covar = ("Y" => 1, "N" => 0);
	my %show = ("Y" => 1, "N" => 0);
	my %revcovar = (1 => "Y", 0 => "N");
	my %revshow = (1 => "Y", 0 => "N");
	my $run_covar = $covar{$covariance};
	my $run_show = $show{$showall};

	my $check1 = $top -> Checkbutton(-text=>"Use covariance model", -variable=>\$run_covar);
	my $check2 = $top -> Checkbutton(-text=>"Show pri. and sec. structure", -variable=>\$run_show);

	# save the information
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("TRNASCAN.searchmode", $searchmode);
		$config->param("TRNASCAN.covariance", $revcovar{$run_covar});
		$config->param("TRNASCAN.showall", $revshow{$run_show});
		$config->param("TRNASCAN.other_opts", $other_opts);
		$config -> save();
		$trna_button -> configure(-background => "$confcolour");
		destroy $top;
	})->pack();
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });

	# entries
	my $ent2 = $top -> Entry(-textvariable=>\$other_opts);

	# labels
	my $lab1 = $top -> Label(-text=>"tRNAscan-SE configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2, -sticky=>"w");
	$rad2 -> grid(-row=>2,-column=>0,-columnspan=>2, -sticky=>"w");
	$rad3 -> grid(-row=>3,-column=>0,-columnspan=>2, -sticky=>"w");
	$rad4 -> grid(-row=>4,-column=>0,-columnspan=>2, -sticky=>"w");
	$rad5 -> grid(-row=>5,-column=>0,-columnspan=>2, -sticky=>"w");
	$check1 -> grid(-row=>6,-column=>0,-columnspan=>2, -sticky=>"w");
	$check2 -> grid(-row=>7,-column=>0,-columnspan=>2, -sticky=>"w");
	$lab2 -> grid(-row=>8,-column=>0);
	$ent2 -> grid(-row=>8,-column=>1);
	$save -> grid(-row=>9,-column=>0,-sticky=>"w");
	$close -> grid(-row=>9,-column=>1,-sticky=>"e");
}
# not yet configured
sub selfblast_conf 
{
	$mw -> messageBox(-type=>"ok",
										-icon=>'info',
										-message=>"Sorry, this feature is not yet available.");
}
sub repfind_conf 
{
	$mw -> messageBox(-type=>"ok",
										-icon=>'info',
										-message=>"Sorry, this feature is not yet available.");
}
sub msat_conf 
{
	$mw -> messageBox(-type=>"ok",
										-icon=>'info',
										-message=>"Sorry, this feature is not yet available.");
}



