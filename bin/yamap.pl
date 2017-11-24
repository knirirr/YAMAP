#!/usr/bin/perl

use strict;
use lib qw(/usr/local/bioinf/yamap/yamap/lib);

#use Bio::SeqIO;
use Config::Simple;
use Cwd;
use File::Copy;
use File::Basename;
use IO::Pipe;
use Proc::ProcessTable;
use Proc::Simple;
use Tk;
use Tk::DirSelect;
use Tk::ExecuteCommand;
use Tk::FileSelect;
use Tk::DialogBox;
use Tk::NoteBook;

# version
my $version="1.0.1";

# location of install files
my $script = "yamap_nogui.pl";
my $pwd = getcwd;
my $dir = undef;
my $glob = "fasta";
my $installdir = "/usr/local/bioinf/yamap/yamap";
my $artemis = "$installdir/bin/run_art.pl";
my $basedir;
my $oneormany = "one";
my $image = "$installdir/etc/yamap_small.gif";
my $text = "Yet\nAnother\nMicrobial/Metagenomic\nAnnotation\nPipeline/Program\nv. $version";
my $write_excel = 1;
my $top_hits = 1;

# location of config files
my $home = $ENV{'HOME'};

# set pager to less so that tfm works
$ENV{'EMBOSS_PAGER'} = "less";
my $tfm = "/usr/local/bioinf/EMBOSS/EMBOSS/emboss/bin/tfm";

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

# set up the quickmine file
unless (-e "$home/.yamap/quickmine.ini")
{
	&copy("$installdir/etc/quickmine.ini","$home/.yamap/quickmine.ini") or warn "Can't copy quickmine config file to $home/.yamap: $!";
}
my $quickmine_file = "$home/.yamap/quickmine.ini";


# set up the paths file
my $update = 0;
my $path_file =  "$home/.yamap/yamap_paths.ini";;
if (-e $path_file)
{
	my $pathconf = new Config::Simple($path_file) or die "Can't open path config file: $!"; 
	my $vers =  $pathconf->param(-block=>'VERSION');
	my $number = $vers->{version};

	unless ($number eq $version)
	{
		$update = 1;
	}
}
else
{
	&copy("$installdir/etc/yamap_paths.ini","$home/.yamap/yamap_paths.ini") or warn "Can't copy path config file to $home/.yamap: $!";
}

my $config = new Config::Simple($config_file);
my $confcolour = "green";

# run variables, from config file
my $common = $config->param(-block=>'COMMON');
my $outdir = $common->{outdir};
my $r_quickmine = $common->{quickmine};
my $r_dbblast = $common->{dbblast}; 
my $r_selfblast = $common->{selfblast}; 
my $r_consblast = $common->{consblast}; 
my $r_bigblast = $common->{bigblast}; 
my $r_pfam = $common->{pfam}; 
my $r_invert = $common->{einverted};
my $r_tandem = $common->{etandem};
my $r_glim = $common->{glimmer};
my $r_msat = $common->{msatfinder};
my $r_palin = $common->{palindrome};
my $r_trna = $common->{trnascan};
my $r_trans = $common->{transterm};
my $dontask = $common->{dontask};

# get details for running artemis
my $paths =  new Config::Simple($path_file) or die "Can't get artemis location: $!";
my $proc = $paths->param(-block=>'PROCESSING');

#########################
#Create the Main Window #
#########################
my $mw = MainWindow->new();
$mw->title('yamap');
my $photo = $mw -> Photo(-format => 'gif', -file => "$image");
my $label = $mw->Canvas(
    -width => $photo->width,
    -height => $photo->height);
$label->createImage(0, 0, -image => $photo, -anchor => 'nw');
my $tagline = $mw -> Label(-text=>"$text",-font=>"fixed 6",-justify=>"left"); 
my $spacer1 = $mw -> Label(-text=>"Select input files",-relief=>"groove");
my $spacer2 = $mw -> Label(-text=>"Configure annotation programs",-relief=>"groove");
my $spacer3 = $mw -> Label(-text=>"");
my $spacer4 = $mw -> Label(-text=>"Select output directory",-relief=>"groove");
my $spacer5 = $mw -> Label(-text=>"Sequence Type", -relief=>"groove");
my $spacer6 = $mw -> Label(-text=>"Annotation Type", -relief=>"groove");
# the Tk listbox should be tied to the array of files
# allowing the selection to be changed before running.
my ($fsref,$basedir);
my (@files);
my %fullpath=();
my $file_names = $mw->ScrlListbox(-selectmode => "extended",
																	-height => 5);
tie @files, "Tk::Listbox", $file_names;
my $enter_args = $mw ->  Button(-text=>"Select sequences", 
																-command => sub {
																$dir = undef;
																$fsref = $mw->FileSelect(-directory => "$pwd",
													                              -selectmode => 'extended');
																my @new = $fsref->Show();
																$basedir = &dirname(@new[0]);
																$basedir =~ s/\/$//;
																foreach my $file (@new)
																{
																	my $shortname = &basename($file);
																	$fullpath{$shortname} = $file;
																	$file_names->insert('end', $shortname);
																}
																});
my $clear_args  = $mw ->  Button(-text=>"Delete selected", 
																-command => sub {
																my @elms = $file_names->curselection;
																foreach my $elm (@elms) 
																{
																	$file_names->delete($elm);
																}
																});
# radio buttons for layout choices
my $anno_type;
my $meta_input_type;
my $anno_check = 1;
my $t_tester;
my $state;
my $genome_annotation = $mw -> Radiobutton(-text => 'Whole Genome Annotation', -value => 1, -variable =>\$anno_type, -command=>\&genome_function);

my $meta_annotation = $mw -> Radiobutton(-text => 'Meta-Genome Annotation', -value => 0, -variable =>\$anno_type, -command=>\&meta_function);

# run or quit
my $run_button =  $mw -> Button(-text => "Run", 
																-command => \&runprogs );
my $quit_button = $mw -> Button(-text => "Quit", 
																-command => \&exitprogram );

# top section geometry
$label -> grid(-row=>0,-column=>0,-sticky=>"e");
$tagline -> grid(-row=>0,-column=>1,-sticky=>"w");
$spacer1-> grid(-row=>1,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$clear_args -> grid(-row=>2,-column=>0);
$enter_args -> grid(-row=>2,-column=>1);
$file_names -> grid(-row=>3,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$spacer2-> grid(-row=>13,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);


# run and quit geometry
$spacer3-> grid(-row=>25,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$run_button -> grid(-row=>26,-column=>0,-sticky=>"w");
$quit_button -> grid(-row=>26,-column=>1,-sticky=>"e");

#temp buttons
$genome_annotation -> grid(-row=>8,-column=>0,-sticky=>"w");
$meta_annotation -> grid(-row=>9,-column=>0,-sticky=>"w");
$spacer5-> grid(-row=>10,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
$spacer6-> grid(-row=>7,-column=>0,-columnspan=>2,-sticky=>"ew",-ipady=>3);
my $meta_protein = $mw -> Radiobutton(-text => 'Protein Input', -value => 1, -variable =>\$meta_input_type, -state=>"disabled");
my $meta_dna = $mw -> Radiobutton(-text => 'DNA Input', -value => 0, -variable =>\$meta_input_type, -state=>"disabled");
$meta_protein -> grid(-row=>11,-column=>0,-sticky=>"w");
$meta_dna -> grid(-row=>12,-column=>0,-sticky=>"w");

# a warning if there is a version mismatch
if ($update == 1)
{
	my $message = "Version number has changed. If you experience problems, please delete \$HOME/.yamap and restart.";
	$mw -> messageBox(-type=>"ok",
										-icon=>'error',
										-font=>'helvetica 10 bold',
										-message=>"$message");
}


my $t_quickmine = $mw -> Checkbutton(-text=>"QuickMine BLAST", -variable=>\$r_quickmine, -state=>"disabled");
my $t_dbblast = $mw -> Checkbutton(-text=>"Blast vs. database", -variable=>\$r_dbblast, -state=>"disabled");
my $t_selfblast = $mw -> Checkbutton(-text=>"Blast vs. own seqs", -variable=>\$r_selfblast, -state=>"disabled");
my $t_consblast = $mw -> Checkbutton(-text=>"Blast vs. consortium db.", -variable=>\$r_consblast, -state=>"disabled");
my $t_bigblast = $mw -> Checkbutton(-text=>"Sanger\'s \"big blast\"", -variable=>\$r_bigblast, -state=>"disabled");
my $t_pfam = $mw -> Checkbutton(-text=>"Pfam", -variable=>\$r_pfam, -command=>sub {if ($r_pfam + $r_trans > 0) 	{$r_glim = 1 };}, -state=>"disabled"); # N.B. glimmer is needed for pfam to work properly
my $t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert, -state=>"disabled");
my $t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem, -state=>"disabled");
my $t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim, -state=>"disabled");
my $t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat, -state=>"disabled");
my $t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin, -state=>"disabled");
my $t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna, -state=>"disabled");
my $t_trans = $mw -> Checkbutton(-text=>"TransTerm", -variable=>\$r_trans, -command=>sub {if ($r_pfam + $r_trans > 0) {$r_glim = 1 };}, -state=>"disabled"); # N.B. glimmer is needed for transterm to work properly

# edit the configs
my $quickmine_button = $mw -> Button(-text=>"Configure", -command =>\&quickmine_conf);
my $dbblast_button = $mw -> Button(-text=>"Configure", -command =>\&dbblast_conf);
my $selfblast_button = $mw -> Button(-text=>"Configure", -command =>\&selfblast_conf);
my $consblast_button = $mw -> Button(-text=>"Configure", -command =>\&consblast_conf);
my $bigblast_button = $mw -> Button(-text=>"Configure", -command =>\&bigblast_conf);
my $pfam_button = $mw -> Button(-text=>"Configure", -command =>\&pfam_conf);
my $invert_button = $mw -> Button(-text=>"Configure", -command =>\&invert_conf);
my $tandem_button = $mw -> Button(-text=>"Configure", -command =>\&tandem_conf);
my $glim_button = $mw -> Button(-text=>"Configure", -command =>\&glim_conf);
my $msat_button = $mw -> Button(-text=>"Configure", -command =>\&msat_conf);
my $palin_button = $mw -> Button(-text=>"Configure", -command =>\&palin_conf);
my $trna_button = $mw -> Button(-text=>"Configure", -command =>\&trna_conf);
my $trans_button = $mw -> Button(-text=>"Configure", -command =>\&trans_conf);

# edit button geometry
# labels...

#$t_dbblast -> grid(-row=>8,-column=>0,-sticky=>"w");
#$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
$t_consblast -> grid(-row=>14,-column=>0,-sticky=>"w");
$t_bigblast -> grid(-row=>16,-column=>0,-sticky=>"w");
$t_invert -> grid(-row=>17,-column=>0,-sticky=>"w");
$t_tandem -> grid(-row=>18,-column=>0,-sticky=>"w");
$t_glim -> grid(-row=>19,-column=>0,-sticky=>"w");
$t_msat -> grid(-row=>20,-column=>0,-sticky=>"w");
$t_palin -> grid(-row=>21,-column=>0,-sticky=>"w");
$t_pfam -> grid(-row=>22,-column=>0,-sticky=>"w");
$t_trna -> grid(-row=>23,-column=>0,-sticky=>"w");
$t_trans -> grid(-row=>24,-column=>0,-sticky=>"w");
$t_quickmine -> grid(-row=>15,-column=>0,-sticky=>"w");
# buttons...
#$dbblast_button -> grid(-row=>8,-column=>1,-sticky=>"e");
#$selfblast_button -> grid(-row=>9,-column=>1,-sticky=>"e");
$consblast_button -> grid(-row=>14,-column=>1,-sticky=>"e");
$bigblast_button -> grid(-row=>16,-column=>1,-sticky=>"e");
$invert_button -> grid(-row=>17,-column=>1,-sticky=>"e");
$tandem_button -> grid(-row=>18,-column=>1,-sticky=>"e");
$glim_button -> grid(-row=>19,-column=>1,-sticky=>"e");
$msat_button -> grid(-row=>20,-column=>1,-sticky=>"e");
$palin_button -> grid(-row=>21,-column=>1,-sticky=>"e");
$pfam_button -> grid(-row=>22,-column=>1,-sticky=>"e");
$trna_button -> grid(-row=>23,-column=>1,-sticky=>"e");
$trans_button -> grid(-row=>24,-column=>1,-sticky=>"e");
$quickmine_button -> grid(-row=>15,-column=>1,-sticky=>"e");
	
# initialise blast buttons for use in quickmine menu
my $sblastb;
my $dblastb;

# stick it on the screen!
$mw->MainLoop;

###############
# subroutines #
###############
# Creates gui layout for genome annotation
sub genome_function
{
	#reset variables from meta annotation
	$r_quickmine = 0;

	$t_quickmine = $mw -> Checkbutton(-text=>"QuickMine BLAST", -variable=>\$r_quickmine, -state=>"normal");
	#$t_dbblast = $mw -> Checkbutton(-text=>"Blast vs. database", -variable=>\$r_dbblast, -state=>"normal");
	#$t_selfblast = $mw -> Checkbutton(-text=>"Blast vs. own seqs", -variable=>\$r_selfblast, -state=>"normal");
	$t_consblast = $mw -> Checkbutton(-text=>"Blast vs. consortium db.", -variable=>\$r_consblast, -state=>"disabled");
	$t_bigblast = $mw -> Checkbutton(-text=>"Sanger\'s \"big blast\"", -variable=>\$r_bigblast, -state=>"normal");
	$t_pfam = $mw -> Checkbutton(-text=>"Pfam", -variable=>\$r_pfam, -command=>sub {if ($r_pfam + $r_trans > 0) 	{$r_glim = 1 };}, -state=>"normal"); # N.B. glimmer is needed for pfam to work properly
	$t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert, -state=>"normal");
	$t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem, -state=>"normal");
	$t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim, -state=>"normal");
	$t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat, -state=>"normal");
	$t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin, -state=>"normal");
	$t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna, -state=>"normal");
	$t_trans = $mw -> Checkbutton(-text=>"TransTerm", -variable=>\$r_trans, -command=>sub {if ($r_pfam + $r_trans > 0) {$r_glim = 1 };}, -state=>"normal"); # N.B. glimmer is needed for transterm to work properly

	#$t_dbblast -> grid(-row=>8,-column=>0,-sticky=>"w");
	#$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
	$t_consblast -> grid(-row=>14,-column=>0,-sticky=>"w");
	$t_bigblast -> grid(-row=>16,-column=>0,-sticky=>"w");
	$t_invert -> grid(-row=>17,-column=>0,-sticky=>"w");
	$t_tandem -> grid(-row=>18,-column=>0,-sticky=>"w");
	$t_glim -> grid(-row=>19,-column=>0,-sticky=>"w");
	$t_msat -> grid(-row=>20,-column=>0,-sticky=>"w");
	$t_palin -> grid(-row=>21,-column=>0,-sticky=>"w");
	$t_pfam -> grid(-row=>22,-column=>0,-sticky=>"w");
	$t_trna -> grid(-row=>23,-column=>0,-sticky=>"w");
	$t_trans -> grid(-row=>24,-column=>0,-sticky=>"w");
	$t_quickmine -> grid(-row=>15,-column=>0,-sticky=>"w");
	
	$meta_protein = $mw -> Radiobutton(-text => 'Protein Input', -value => 1, -variable =>\$meta_input_type, -state=>"disabled");
	$meta_dna = $mw -> Radiobutton(-text => 'DNA Input', -value => 0, -variable =>\$meta_input_type, -state=>"disabled");
	$meta_protein -> grid(-row=>11,-column=>0,-sticky=>"w");
	$meta_dna -> grid(-row=>12,-column=>0,-sticky=>"w");
	
}
# Create layout for general meta annotation
sub meta_function
{
	#reset variables from genome annotation
	$r_consblast = 0;
	$r_bigblast = 0;
	$r_pfam = 0;
	$r_invert = 0;
	$r_tandem = 0;
	$r_glim = 0;
	$r_msat = 0;
	$r_palin = 0;
	$r_trna = 0;
	$r_trans = 0;
	
	$t_quickmine = $mw -> Checkbutton(-text=>"QuickMine BLAST", -variable=>\$r_quickmine, -state=>"normal");
	#$t_dbblast = $mw -> Checkbutton(-text=>"Blast vs. database", -variable=>\$r_dbblast, -state=>"disable");
	#$t_selfblast = $mw -> Checkbutton(-text=>"Blast vs. own seqs", -variable=>\$r_selfblast, -state=>"disable");
	$t_consblast = $mw -> Checkbutton(-text=>"Blast vs. consortium db.", -variable=>\$r_consblast, -state=>"disable");
	$t_bigblast = $mw -> Checkbutton(-text=>"Sanger\'s \"big blast\"", -variable=>\$r_bigblast, -state=>"disable");
	$t_pfam = $mw -> Checkbutton(-text=>"Pfam", -variable=>\$r_pfam, -command=>sub {if ($r_pfam + $r_trans > 0) 	{$r_glim = 1 };}, -state=>"disable"); # N.B. glimmer is needed for pfam to work properly
	$t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert, -state=>"disable");
	$t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem, -state=>"disable");
	$t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim, -state=>"disable");
	$t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat, -state=>"disable");
	$t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin, -state=>"disable");
	$t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna, -state=>"disable");
	$t_trans = $mw -> Checkbutton(-text=>"TransTerm", -variable=>\$r_trans, -command=>sub {if ($r_pfam + $r_trans > 0) {$r_glim = 1 };}, -state=>"disable"); # N.B. glimmer is needed for transterm to work properly
	
	#$t_dbblast -> grid(-row=>8,-column=>0,-sticky=>"w");
	#$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
	$t_consblast -> grid(-row=>14,-column=>0,-sticky=>"w");
	$t_bigblast -> grid(-row=>16,-column=>0,-sticky=>"w");
	$t_invert -> grid(-row=>17,-column=>0,-sticky=>"w");
	$t_tandem -> grid(-row=>18,-column=>0,-sticky=>"w");
	$t_glim -> grid(-row=>19,-column=>0,-sticky=>"w");
	$t_msat -> grid(-row=>20,-column=>0,-sticky=>"w");
	$t_palin -> grid(-row=>21,-column=>0,-sticky=>"w");
	$t_pfam -> grid(-row=>22,-column=>0,-sticky=>"w");
	$t_trna -> grid(-row=>23,-column=>0,-sticky=>"w");
	$t_trans -> grid(-row=>24,-column=>0,-sticky=>"w");
	$t_quickmine -> grid(-row=>15,-column=>0,-sticky=>"w");
	
	$meta_input_type = 1;
	$meta_protein = $mw -> Radiobutton(-text => 'Protein Input', -value => 1, -variable =>\$meta_input_type, -state=>"normal", -command=>\&protein_function);
	$meta_dna = $mw -> Radiobutton(-text => 'DNA Input', -value => 0, -variable =>\$meta_input_type, -state=>"normal", -command=>\&dna_function);
	$meta_protein -> grid(-row=>11,-column=>0,-sticky=>"w");
	$meta_dna -> grid(-row=>12,-column=>0,-sticky=>"w");
}
# provides options available for annotation of proteins
sub protein_function
{
	#reset variables from genome annotation
	$r_consblast = 0;
	$r_bigblast = 0;
	$r_pfam = 0;
	$r_invert = 0;
	$r_tandem = 0;
	$r_glim = 0;
	$r_msat = 0;
	$r_palin = 0;
	$r_trna = 0;
	$r_trans = 0;
	
	$t_quickmine = $mw -> Checkbutton(-text=>"QuickMine BLAST", -variable=>\$r_quickmine, -state=>"normal");
	#$t_dbblast = $mw -> Checkbutton(-text=>"Blast vs. database", -variable=>\$r_dbblast, -state=>"disable");
	#$t_selfblast = $mw -> Checkbutton(-text=>"Blast vs. own seqs", -variable=>\$r_selfblast, -state=>"disable");
	$t_consblast = $mw -> Checkbutton(-text=>"Blast vs. consortium db.", -variable=>\$r_consblast, -state=>"disable");
	$t_bigblast = $mw -> Checkbutton(-text=>"Sanger\'s \"big blast\"", -variable=>\$r_bigblast, -state=>"disable");
	$t_pfam = $mw -> Checkbutton(-text=>"Pfam", -variable=>\$r_pfam, -command=>sub {if ($r_pfam + $r_trans > 0) 	{$r_glim = 1 };}, -state=>"disable"); # N.B. glimmer is needed for pfam to work properly
	$t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert, -state=>"disable");
	$t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem, -state=>"disable");
	$t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim, -state=>"disable");
	$t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat, -state=>"disable");
	$t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin, -state=>"disable");
	$t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna, -state=>"disable");
	$t_trans = $mw -> Checkbutton(-text=>"TransTerm", -variable=>\$r_trans, -command=>sub {if ($r_pfam + $r_trans > 0) {$r_glim = 1 };}, -state=>"disable"); # N.B. glimmer is needed for transterm to work properly
	
	#$t_dbblast -> grid(-row=>8,-column=>0,-sticky=>"w");
	#$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
	$t_consblast -> grid(-row=>14,-column=>0,-sticky=>"w");
	$t_bigblast -> grid(-row=>16,-column=>0,-sticky=>"w");
	$t_invert -> grid(-row=>17,-column=>0,-sticky=>"w");
	$t_tandem -> grid(-row=>18,-column=>0,-sticky=>"w");
	$t_glim -> grid(-row=>19,-column=>0,-sticky=>"w");
	$t_msat -> grid(-row=>20,-column=>0,-sticky=>"w");
	$t_palin -> grid(-row=>21,-column=>0,-sticky=>"w");
	$t_pfam -> grid(-row=>22,-column=>0,-sticky=>"w");
	$t_trna -> grid(-row=>23,-column=>0,-sticky=>"w");
	$t_trans -> grid(-row=>24,-column=>0,-sticky=>"w");
	$t_quickmine -> grid(-row=>15,-column=>0,-sticky=>"w");
}
# provides options for annotation of dna sequences
sub dna_function
{
	$t_quickmine = $mw -> Checkbutton(-text=>"QuickMine BLAST", -variable=>\$r_quickmine, -state=>"normal");
	#$t_dbblast = $mw -> Checkbutton(-text=>"Blast vs. database", -variable=>\$r_dbblast, -state=>"normal");
	#$t_selfblast = $mw -> Checkbutton(-text=>"Blast vs. own seqs", -variable=>\$r_selfblast, -state=>"normal");
	$t_consblast = $mw -> Checkbutton(-text=>"Blast vs. consortium db.", -variable=>\$r_consblast, -state=>"disabled");
	$t_bigblast = $mw -> Checkbutton(-text=>"Sanger\'s \"big blast\"", -variable=>\$r_bigblast, -state=>"disabled");
	$t_pfam = $mw -> Checkbutton(-text=>"Pfam", -variable=>\$r_pfam, -command=>sub {if ($r_pfam + $r_trans > 0) 	{$r_glim = 1 };}, -state=>"normal"); # N.B. glimmer is needed for pfam to work properly
	$t_invert = $mw -> Checkbutton(-text=>"Einverted", -variable=>\$r_invert, -state=>"normal");
	$t_tandem = $mw -> Checkbutton(-text=>"Etandem", -variable=>\$r_tandem, -state=>"normal");
	$t_glim = $mw -> Checkbutton(-text=>"Glimmer", -variable=>\$r_glim, -state=>"normal");
	$t_msat = $mw -> Checkbutton(-text=>"Msatfinder", -variable=>\$r_msat, -state=>"normal");
	$t_palin = $mw -> Checkbutton(-text=>"Palindrome", -variable=>\$r_palin, -state=>"normal");
	$t_trna = $mw -> Checkbutton(-text=>"tRNAscan", -variable=>\$r_trna, -state=>"normal");
	$t_trans = $mw -> Checkbutton(-text=>"TransTerm", -variable=>\$r_trans, -command=>sub {if ($r_pfam + $r_trans > 0) {$r_glim = 1 };}, -state=>"normal"); # N.B. glimmer is needed for transterm to work properly

	#$t_dbblast -> grid(-row=>8,-column=>0,-sticky=>"w");
	#$t_selfblast -> grid(-row=>9,-column=>0,-sticky=>"w");
	$t_consblast -> grid(-row=>14,-column=>0,-sticky=>"w");
	$t_bigblast -> grid(-row=>16,-column=>0,-sticky=>"w");
	$t_invert -> grid(-row=>17,-column=>0,-sticky=>"w");
	$t_tandem -> grid(-row=>18,-column=>0,-sticky=>"w");
	$t_glim -> grid(-row=>19,-column=>0,-sticky=>"w");
	$t_msat -> grid(-row=>20,-column=>0,-sticky=>"w");
	$t_palin -> grid(-row=>21,-column=>0,-sticky=>"w");
	$t_pfam -> grid(-row=>22,-column=>0,-sticky=>"w");
	$t_trna -> grid(-row=>23,-column=>0,-sticky=>"w");
	$t_trans -> grid(-row=>24,-column=>0,-sticky=>"w");
	$t_quickmine -> grid(-row=>15,-column=>0,-sticky=>"w");
}
# RUN
sub runprogs
{
	# die if no files
	my $len = @files;
	unless (@files)
	{
		$mw -> messageBox(-type=>"ok",
											-icon=>'error',
											-message=>"Please select at least one sequence file.");
		return;
	}
	#die if white space in file names
	foreach my $space_check (@files)
	{
		if ($space_check =~m/\s/)
		{
			$mw -> messageBox(-type=>"ok",-icon=>'error',-message=>"Please remove spaces from your input filenames.");
			return;
		}
	}
	# save info on which programs are to be run
	$config->param("COMMON.dbblast", $r_dbblast || 0);
	$config->param("COMMON.selfblast", $r_selfblast || 0);
	$config->param("COMMON.consblast", $r_consblast || 0);
	$config->param("COMMON.bigblast", $r_bigblast || 0);
	$config->param("COMMON.pfam", $r_pfam || 0);
	$config->param("COMMON.einverted", $r_invert || 0);
	$config->param("COMMON.etandem", $r_tandem || 0);
	$config->param("COMMON.glimmer", $r_glim || 0);
	$config->param("COMMON.msatfinder", $r_msat || 0);
	$config->param("COMMON.palindrome", $r_palin || 0);
	$config->param("COMMON.trnascan", $r_trna || 0);
	$config->param("COMMON.transterm", $r_trans || 0);
	$config->param("COMMON.quickmine", $r_quickmine || 0);
	$config->save();

	# make sure full path is passed to command line
	# and only one copy of each file is viewed
	# might be safe to omit full path if cd to 
	# $basedir before running $script
	my %nameseen=();
	my @fullnames;
	foreach my $file (@files)
	{
		push(@fullnames, $fullpath{$file}) unless $nameseen{$file} == 1;
		$nameseen{$file} = 1;
	}

	# create display window
	my $top = $mw-> Toplevel();
	$top->title('Executing annotation programs...');
	my $label = $top -> Label(-text=>"Pipeline progress", 
														-relief=>"groove")->pack();
	
	# set up path2proteins for quickmine
	my $cfgq = new Config::Simple($quickmine_file);
	my $outdirpath = "$basedir/$outdir";
	$cfgq->param("PATHS.path2output", $outdirpath);
	$cfgq->param("PATHS.path2blast", $outdirpath);
	$cfgq->param("PATHS.path2public", $outdirpath);
	$cfgq->param("PATHS.path2proteins", $outdirpath);
	$cfgq -> save();
	
	# run the program
	my ($write,$tophits);
	if ($write_excel ==1)
	{
		$write = "-w";
	}
	if ($top_hits ==1)
	{
		$tophits = "-t";
	}
	my $ec = $top->ExecuteCommand(-command    => '',
																-entryWidth => 50,
																-height     => 10,
																-label      => 'Run YAMAP',
																-text       => 'Execute')->pack(-fill=>"both",-expand=>1);
	$ec->configure(-command => "cd $basedir; $installdir/bin/$script -x -c $config_file -p $path_file -q $quickmine_file @fullnames");
	$ec->execute_command;
	$ec->bell;
	$ec->update;
	
	# check to determine if analysis is of whole genome, if so provide artemis button
	if ($anno_type == 1)
	{
		# view results in artemis
		my $art = $top -> Button(-text=>"View results in artemis", -command => sub 
		{ 
			# strange Tk::Widget::insert problems appear here
			# this is a bit naughty, but will have to do for now
			no warnings;

			# view results in artemis
			my $top2 = $top->Toplevel();
			$top->title('Running Artemis...');
			my $runart = $top2->ExecuteCommand(-command => '',-entryWidth => 40,-height => 5,-label => 'Run Artemis',-text=> 'View results in Artemis')->pack(-fill=>"both",-expand=>1);
			$runart->configure(-command => "$artemis $basedir");
			my $close = $top2 -> Button(-text=>"Close window", -command => sub { destroy $top2; })->pack();

			$runart->execute_command;
			$runart->bell;
			$runart->update;
		})->pack();
	}
	if ($anno_type == 0 && $r_quickmine == 1)
	{
		my $firefox = $top -> Button(-text=>"View QuickMine results in Firefox", -command=> sub
		{
			my $top2 = $top->Toplevel();
			$top2->title('Running Firefox...');
			my $exec_fox = $top2->ExecuteCommand(-command=>'',-entryWidth=>40,-height=>5,-label=>'',-text=>'Execute')->pack;
 			$exec_fox->configure(-command => "firefox $outdirpath/index.html");
 			my $close = $top2 -> Button(-text=>"Close window", -command => sub { destroy $top2; })->pack();
			$exec_fox->execute_command;
			$exec_fox->bell;
			$exec_fox->update;
		})->pack();
	}
	# add close button
	my $close = $top -> Button(-text=>"Close window", -command => sub { destroy $top; })->pack();
}
# EXIT
sub exitprogram 
{
	if ($dontask eq "no" )
	{
		my $d = $mw->DialogBox(-title => "Confirm quit", -buttons => ["OK", "Cancel"]);
		$d->add('Label', -text=>"Are you sure?", -font=>"helvetica 18 bold")->pack(-side=>"top",-anchor=>"center");
		$d->add('Radiobutton', -text => 'Don\'t ask for confirmation again.',
													 -value    => "yes",
  												 -variable => \$dontask)->pack(-side=>"top",-anchor=>"w");

		my $button = $d->Show;
		if ($button =~ /OK/i)
		{
			$config->param("COMMON.dontask", $dontask || "no");
			$config->save();
			exit;
		}
	}
	elsif ($dontask eq "yes")
	{
		$config->save();
		exit;
	}
}

# DBBLAST
sub dbblast_conf 
{
	# vars
	my $confs = $config->param(-block=>'DBBLAST');
	my $program = $confs->{program};
	my $database = $confs->{database};
	my $other_opts = $confs->{other_opts};
	# new window
	my $top = $mw -> Toplevel();
	$top->title('dbblast');

	# radio buttons
	my $rad0 = $top -> Radiobutton(-text => 'blastn',
																 -value    => "blastn",
  															 -variable => \$program);
	my $rad1 = $top -> Radiobutton(-text => 'blastx',
																 -value    => "blastx",
  															 -variable => \$program);
	my $rad2 = $top -> Radiobutton(-text => 'tblastx',
																 -value    => "tblastx",
  															 -variable => \$program);
	my $rad3 = $top -> Radiobutton(-text => 'blastp',
																 -value    => "blastp",
  															 -variable => \$program);

	my $rad4 = $top -> Checkbutton(-text=>"Write summary of results (xls)", -variable=>\$write_excel);
	my $rad5 = $top -> Checkbutton(-text=>"Write top hits only (xls)", -variable=>\$top_hits);
	my $ent2 = $top -> Entry(-textvariable=>\$database);
	my $ent4 = $top -> Entry(-textvariable=>\$other_opts);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("DBBLAST.program", $program);
		$config->param("DBBLAST.database", $database);
		$config->param("DBBLAST.other_opts", $other_opts);
		$config -> save();
		$dbblast_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"blastall documentation", -command => sub { &rtfm("xterm -e \"man blastall\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"DB-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Database");
	my $lab4 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad0 -> grid(-row=>1,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>2,-column=>0,-columnspan=>2);
	$rad2 -> grid(-row=>3,-column=>0,-columnspan=>2);
	$rad3 -> grid(-row=>4,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>5,-column=>0);
	$lab4 -> grid(-row=>6,-column=>0);
	$ent2 -> grid(-row=>5,-column=>1);
	$ent4 -> grid(-row=>6,-column=>1);
	$rad4 -> grid(-row=>7,-column=>0,-columnspan=>2,-sticky=>"w");
	$rad5 -> grid(-row=>8,-column=>0,-columnspan=>2,-sticky=>"w");
	$rtfm -> grid(-row=>9,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>10,-column=>0,-sticky=>"w");
	$close -> grid(-row=>10,-column=>1,-sticky=>"e");

}
# SELFBLAST
sub selfblast_conf 
{
	# vars
	my $confs = $config->param(-block=>'SELFBLAST');
	my $program = $confs->{program};
	my $other_opts = $confs->{other_opts};

	# new window
	my $top = $mw -> Toplevel();
	$top->title('selfblast');

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'blastn',
																 -value    => "blastn",
  															 -variable => \$program);
	my $rad3 = $top -> Radiobutton(-text => 'tblastx',
																 -value    => "tblastx",
  															 -variable => \$program);


	my $ent3 = $top -> Entry(-textvariable=>\$other_opts);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("SELFBLAST.program", $program);
		$config->param("SELFBLAST.other_opts", $other_opts);
		$config -> save();
		$selfblast_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"blastall documentation", -command => sub { &rtfm("xterm -e \"man blastall\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"Self-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Expect");
	my $lab3 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2);
	$rad3 -> grid(-row=>2,-column=>0,-columnspan=>2);
	$lab3 -> grid(-row=>3,-column=>0);
	$ent3 -> grid(-row=>3,-column=>1);
	$rtfm -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>5,-column=>0,-sticky=>"w");
	$close -> grid(-row=>5,-column=>1,-sticky=>"e");
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
	$top->title('einverted');
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
	my $rtfm =   $top -> Button(-text=>"einverted documentation", -command => sub { &rtfm("xterm -e \"$tfm einverted\"") });

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
	$rtfm -> grid(-row=>6,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>7,-column=>0,-sticky=>"w");
	$close -> grid(-row=>7,-column=>1,-sticky=>"e");
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
	$top->title('etandem');
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
	my $rtfm =   $top -> Button(-text=>"etandem documentation", -command => sub { &rtfm("xterm -e \"$tfm etandem\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"Etandem configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Uniform");
	my $lab3 = $top -> Label(-text=>"Mismatch");
	my $lab4 = $top -> Label(-text=>"Minrepeat");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$ent3 -> grid(-row=>3,-column=>1);
	$rtfm -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>5,-column=>0,-sticky=>"w");
	$close -> grid(-row=>5,-column=>1,-sticky=>"e");
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
	$top->title('glimmer');
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
	my $rtfm1 =   $top -> Button(-text=>"glimmer documentation", -command => sub { &rtfm("xterm -e \"less /usr/local/bioinf/glimmer/glimmer/glimmer2.readme\"") });
	my $rtfm2 =   $top -> Button(-text=>"long-orfs documentation", -command => sub { &rtfm("xterm -e \"less /usr/local/bioinf/glimmer/glimmer/long-orfs.readme\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"Glimmer configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Glimmer arguments");
	my $lab3 = $top -> Label(-text=>"Longorfs arguments");

	# geometry
	$ent1 -> grid(-row=>1,-column=>1);
	$ent2 -> grid(-row=>2,-column=>1);
	$rtfm1 -> grid(-row=>3,-column=>0,-columnspan=>2,-sticky=>"ew");
	$rtfm2 -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>5,-column=>0,-sticky=>"w");
	$close -> grid(-row=>5,-column=>1,-sticky=>"e");
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
	$top->title('palindrome');
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
	my $rtfm =   $top -> Button(-text=>"palindrome documentation", -command => sub { &rtfm("xterm -e \"$tfm palindrome\"") });

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
	$rtfm -> grid(-row=>6,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>7,-column=>0,-sticky=>"w");
	$close -> grid(-row=>7,-column=>1,-sticky=>"e");
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
	$top->title('trnascan');

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
	my $rtfm =   $top -> Button(-text=>"tRNAscan-SE documentation", -command => sub { &rtfm("xterm -e \"man /usr/share/man/man1/man1/tRNAscan-SE.1\"") });

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
	$rtfm -> grid(-row=>9,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>10,-column=>0,-sticky=>"w");
	$close -> grid(-row=>10,-column=>1,-sticky=>"e");
}
# MSATFINDER
sub msat_conf 
{
	# vars
	my $mconf = $config->param(-block=>'MSATFINDER');
	my $flank_size = $mconf->{flank_size};
	my $mrange = $mconf->{mrange};
	my $engine = $mconf->{engine};
	my $interrupts = $mconf->{interrupts};

	# match the engine to the number
	my %motor = (1 => "regex",
							 2 => "multipass",
							 3 => "iterative");
	my %rotom = ("regex" => 1,
							 "multipass" => 2,
							 "iterative" => 3);
	my $eng = $motor{$engine};


	# set up msats to search in order that they
	# may be written back to the config file
	my %detect=(1 => 0,
							2 => 0,
							3 => 0,
							4 => 0,
							5 => 0,
							6 => 0);
	my %thresh=(1 => 0,
							2 => 0,
							3 => 0,
							4 => 0,
							5 => 0,
							6 => 0);
	my @parts = (split/\|/, $mrange);
	foreach my $part (@parts)
	{
		my ($type,$thr) = split(/\+/,$part);
		$detect{$type} = 1;
		$thresh{$type} = $thr;
	}

	# prepare the widgets
	# radio buttons
	my $top = $mw -> Toplevel();
	$top->title('msatfinder');
	my $rad1 = $top -> Radiobutton(-text => 'Regex',
																 -value    => "regex",
  															 -variable => \$eng);
	my $rad2 = $top -> Radiobutton(-text => 'Multipass',
																 -value    => "multipass",
  															 -variable => \$eng);
	my $rad3 = $top -> Radiobutton(-text => 'Iterative',
																 -value    => "iterative",
  															 -variable => \$eng);
	# Checkbuttons
	my $find_int = $top -> Checkbutton(-text=>"Find interrupted", -variable=>\$interrupts);
	my $b_mono = $top -> Checkbutton(-text=>"Mono", -variable=>\$detect{1});
	my $b_di = $top -> Checkbutton(-text=>"Di", -variable=>\$detect{2});
	my $b_tri = $top -> Checkbutton(-text=>"Tri", -variable=>\$detect{3});
	my $b_tetra = $top -> Checkbutton(-text=>"Tetra", -variable=>\$detect{4});
	my $b_penta = $top -> Checkbutton(-text=>"Penta", -variable=>\$detect{5});
	my $b_hexa = $top -> Checkbutton(-text=>"Hexa", -variable=>\$detect{6});

	# text boxes
	my $t_flank = $top -> Entry(-textvariable=>\$flank_size);
	my $t_mono = $top -> Entry(-textvariable=>\$thresh{1});
	my $t_di = $top -> Entry(-textvariable=>\$thresh{2});
	my $t_tri = $top -> Entry(-textvariable=>\$thresh{3});
	my $t_tetra = $top -> Entry(-textvariable=>\$thresh{4});
	my $t_penta = $top -> Entry(-textvariable=>\$thresh{5});
	my $t_hexa = $top -> Entry(-textvariable=>\$thresh{6});

	# labels
	my $mainlabel = $top -> Label(-text=>"Msatfinder configuration",-relief=>"groove");
	my $flanklabel = $top -> Label(-text=>"Flank size");
	my $englab = $top -> Label(-text=>"Msat finding engine");

	# save files when save pressed
	# save the information
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		# re-form the string passed to $mconf
		my @newranges;
		foreach (my $i=1;$i<=6;$i++)
		{
			if (defined $detect{$i})
			{
				push (@newranges,"$i+$thresh{$i}");
			}
		}
		my $newmrange = join("|",@newranges);
		$config->param("MSATFINDER.interrupts", $interrupts);
		$config->param("MSATFINDER.engine", $rotom{$eng});
		$config->param("MSATFINDER.flank_size", $flank_size);
		$config->param("MSATFINDER.mrange", "\"$newmrange\"");
		$config -> save();
		$msat_button -> configure(-background => "$confcolour");
		destroy $top;
	})->pack();
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"msatfinder documentation (html)", -command => sub { &rtfm("xterm -e \"lynx $installdir/etc/msatfinder_manual.html\"") });

	# configure the layout 
	$mainlabel -> grid(-row=>0,-column=>0,-columnspan=>2);
	$b_mono -> grid(-row=>1,-column=>0,-sticky=>"w");
	$b_di -> grid(-row=>2,-column=>0,-sticky=>"w");
	$b_tri -> grid(-row=>3,-column=>0,-sticky=>"w");
	$b_tetra -> grid(-row=>4,-column=>0,-sticky=>"w");
	$b_penta -> grid(-row=>5,-column=>0,-sticky=>"w");
	$b_hexa -> grid(-row=>6,-column=>0,-sticky=>"w");
	$t_mono -> grid(-row=>1,-column=>1);
	$t_di -> grid(-row=>2,-column=>1);
	$t_tri -> grid(-row=>3,-column=>1);
	$t_tetra -> grid(-row=>4,-column=>1);
	$t_penta -> grid(-row=>5,-column=>1);
	$t_hexa -> grid(-row=>6,-column=>1);
	$find_int -> grid(-row=>7,-column=>0,-sticky=>"w");
	$flanklabel -> grid(-row=>8,-column=>0,-sticky=>"w");
	$t_flank -> grid(-row=>8,-column=>1);
	$englab -> grid(-row=>9,-column=>0);
	$rad1 -> grid(-row=>9,-column=>1);
	$rad2 -> grid(-row=>10,-column=>0);
	$rad3 -> grid(-row=>10,-column=>1);

	$rtfm -> grid(-row=>11,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>12,-column=>0,-sticky=>"w");
	$close -> grid(-row=>12,-column=>1,-sticky=>"e");

}
# PFAM
sub pfam_conf
{
	my $pconf = $config->param(-block=>'PFAM');
	my $fast = $pconf->{fast};
	my $overlap = $pconf->{overlap};
	my $database = $pconf->{database};
	my $other_opts = $pconf->{other_opts};

	# new window
	my $top = $mw -> Toplevel();
	$top->title('pfam scan');

	# radio buttons
	my $fast_but = $top -> Radiobutton(-text => 'Fast',
																 -value    => "fast",
  															 -variable => \$fast);
	my $olap_but = $top -> Radiobutton(-text => 'Overlap',
																 -value    => "overlap",
  															 -variable => \$overlap);
	my $ent_db = $top -> Entry(-textvariable=>\$database);
	my $ent_oo = $top -> Entry(-textvariable=>\$other_opts);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("PFAM.fast", $fast);
		$config->param("PFAM.database", $database);
		$config->param("PFAM.overlap", $overlap);
		$config->param("PFAM.other_opts", $other_opts);
		$config -> save();
		$pfam_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"pfam-scan documentation (html)", -command => sub { &rtfm("xterm -e \"lynx $installdir/etc/pfam_scan.html\"") });


	# labels
	my $lab_top = $top -> Label(-text=>"Pfam configuration",-relief=>"groove");
	my $lab_db = $top -> Label(-text=>"Database");
	my $lab_oo = $top -> Label(-text=>"Other options");

	# geometry
	$lab_top -> grid(-row=>0,-column=>0,-columnspan=>2);
	$fast_but -> grid(-row=>1,-column=>0,-columnspan=>2);
	$olap_but -> grid(-row=>2,-column=>0,-columnspan=>2);
	$lab_db -> grid(-row=>3,-column=>0);
	$lab_oo -> grid(-row=>4,-column=>0);
	$ent_db -> grid(-row=>3,-column=>1);
	$ent_oo -> grid(-row=>4,-column=>1);
	$rtfm -> grid(-row=>5,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>6,-column=>0,-sticky=>"w");
	$close -> grid(-row=>6,-column=>1,-sticky=>"e");

}

# awesome rtfm facility
sub rtfm
{
	my $string = shift;

	# non blocking execution of whatever
	# shell command is passed
	my $proc = Proc::Simple->new();
	return $proc->start("$string");
}

# blast upon the database that's downloaded
# from Newcastle
# CONSBLAST
sub consblast_conf
{
	# vars
	my $confs = $config->param(-block=>'CONSBLAST');
	my $program = $confs->{program};
	my $database = $confs->{database};
	my $other_opts = $confs->{other_opts};

	# new window
	my $top = $mw -> Toplevel();
	$top->title('consblast');

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'blastn',
																 -value    => "blastn",
  															 -variable => \$program);
	my $rad3 = $top -> Radiobutton(-text => 'tblastx',
																 -value    => "tblastx",
  															 -variable => \$program);


	my $ent3 = $top -> Entry(-textvariable=>\$other_opts);
	my $dbent = $top -> Entry(-textvariable=>\$database);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("CONSBLAST.program", $program);
		$config->param("CONSBLAST.database", $database);
		$config->param("CONSBLAST.other_opts", $other_opts);
		$config -> save();
		$consblast_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"blastall documentation", -command => sub { &rtfm("xterm -e \"man blastall\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"Self-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Expect");
	my $dblab = $top -> Label(-text=>"Database");
	my $lab3 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2);
	$rad3 -> grid(-row=>2,-column=>0,-columnspan=>2);
	$lab3 -> grid(-row=>4,-column=>0);
	$ent3 -> grid(-row=>4,-column=>1);
	$dblab -> grid(-row=>3,-column=>0);
	$dbent -> grid(-row=>3,-column=>1);
	$rtfm -> grid(-row=>5,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>6,-column=>0,-sticky=>"w");
	$close -> grid(-row=>6,-column=>1,-sticky=>"e");
}

# BIGBLAST
sub bigblast_conf
{
	# vars
	my $confs = $config->param(-block=>'BIGBLAST');
	my $program = $confs->{program};
	my $database = $confs->{database};
	my $jobs = $confs->{jobs};
	my $other_opts = $confs->{other_opts};
	# new window
	my $top = $mw -> Toplevel();
	$top->title('bigblast');

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'blastn',
																 -value    => "blastn",
  															 -variable => \$program);
	my $rad2 = $top -> Radiobutton(-text => 'blastx',
																 -value    => "blastx",
  															 -variable => \$program);
	my $rad3 = $top -> Radiobutton(-text => 'tblastx',
																 -value    => "tblastx",
  															 -variable => \$program);

	my $ent2 = $top -> Entry(-textvariable=>\$database);
	my $ent3 = $top -> Entry(-textvariable=>\$jobs);
	my $ent4 = $top -> Entry(-textvariable=>\$other_opts);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("BIGBLAST.program", $program);
		$config->param("BIGBLAST.database", $database);
		$config->param("BIGBLAST.jobs", $jobs);
		$config->param("BIGBLAST.other_opts", $other_opts);
		$config -> save();
		$bigblast_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"big_blast.pl usage", -command => sub { &rtfm("xterm -e \"less /usr/local/bioinf/yamap/yamap/etc/big_blast.txt\"") });


	# labels
	my $lab1 = $top -> Label(-text=>"Big-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Database");
	my $lab3 = $top -> Label(-text=>"Number of jobs");
	my $lab4 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2);
	$rad2 -> grid(-row=>2,-column=>0,-columnspan=>2);
	$rad3 -> grid(-row=>3,-column=>0,-columnspan=>2);
	$lab2 -> grid(-row=>4,-column=>0);
	$lab3 -> grid(-row=>5,-column=>0);
	$lab4 -> grid(-row=>6,-column=>0);
	$ent2 -> grid(-row=>4,-column=>1);
	$ent3 -> grid(-row=>5,-column=>1);
	$ent4 -> grid(-row=>6,-column=>1);
	$rtfm -> grid(-row=>7,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>8,-column=>0,-sticky=>"w");
	$close -> grid(-row=>8,-column=>1,-sticky=>"e");

}
# TRANSTERM
sub trans_conf 
{
	# vars
	my $tconf = $config->param(-block=>'TRANSTERM');
	my $version = $tconf->{version};
	my $other_opts = $tconf->{other_opts};

	# new window, buttons &c.
	my $top = $mw -> Toplevel();
	$top->title('transterm');

	# radio buttons
	my $rad1 = $top -> Radiobutton(-text => 'V. 1.0 confidence',
																 -value    => 1,
  															 -variable => \$version);
	my $rad2 = $top -> Radiobutton(-text => 'V. 2.0 confidence',
																 -value    => 2,
  															 -variable => \$version);

	# save the information
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$config->param("TRANSTERM.version", $version);
		$config->param("TRANSTERM.other_opts", $other_opts);
		$config -> save();
		$trna_button -> configure(-background => "$confcolour");
		destroy $top;
	})->pack();
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"TransTerm documentation", -command => sub { &rtfm("xterm -e \"less /usr/local/bioinf/transterm/transterm/USAGE.txt\"") });

	# entries
	my $ent2 = $top -> Entry(-textvariable=>\$other_opts);

	# labels
	my $lab1 = $top -> Label(-text=>"TransTerm configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad1 -> grid(-row=>1,-column=>0,-columnspan=>2, -sticky=>"w");
	$rad2 -> grid(-row=>2,-column=>0,-columnspan=>2, -sticky=>"w");
	$lab2 -> grid(-row=>3,-column=>0);
	$ent2 -> grid(-row=>3,-column=>1);
	$rtfm -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>5,-column=>0,-sticky=>"w");
	$close -> grid(-row=>5,-column=>1,-sticky=>"e");
}
# QUICKMINE
sub quickmine_conf
{
	# vars
	my $cfg = new Config::Simple($quickmine_file);
	#my $path2proteins = $cfg->param('path2proteins');
	#my $ext = $cfg->param('ext');
	my $path2scripts = "$installdir/bin";
	my $outdirpath = "$basedir/$outdir";
	my $formatdb = $cfg->param("PARAMS.formatdb");
	##my $end = $cfg->param('end');
	#my $condor_output = $cfg->param('condor_output');
	#my $record_separator = $cfg->param('record_separator');
	my $write_fasta_files = $cfg->param("LEAVE_ALONE.write_fasta_files");
	my $sig_thresh = $cfg->param("PARAMS.sig_thresh");
	my $self_blast = $cfg->param("PARAMS.self_hit");
	
	my $parse = $cfg->param("RUN.parse");
	my $format = $cfg->param("RUN.format");
	my $quickmine = $cfg->param("RUN.quickmine");
	my $split = $cfg->param("RUN.split");
	my $orphans = $cfg->param("RUN.orphans");
	my $hits = $cfg->param("RUN.hits");
	my $genetable = $cfg->param("RUN.genetable");
	my $orphan_count = $cfg->param("RUN.orphan_count");
	my $orphan_size = $cfg->param("RUN.orphan_size");
	my $paralogue_count = $cfg->param("RUN.paralogue_count");
	my $increment = $cfg->param("RUN.increment");
	my $time = $cfg->param("RUN.time");
	my $binary = $cfg->param("RUN.binary");
	my $plots = $cfg->param("RUN.plots");
	my $indiv_plot = $cfg->param("RUN.indiv_plot");
	my $dot_plot = $cfg->param("RUN.dot_plot");
	my $summarizer = $cfg->param("RUN.summarizer");
	
	my $default = 1;
	# prepare the widgets
	
	my $top = $mw -> Toplevel();
	$top->title('QuickMine');
	
	#frames
	my $fra1 = $top -> Frame()->pack(-side => 'top', -fill=>'x');
	my $fra2 = $top -> Frame()->pack(-side => 'top',-fill=>'x');
	my $fra3 = $top -> Frame(-borderwidth => '3')->pack(-side => 'top',-fill=>'x');
	
	# notebook tabs
	my $n = $top->NoteBook(qw/-ipadx 6 -ipady 6/)->pack(-fill=>'x');
	my $basic = $n->add(qw/basic -label Basic
                                 -underline 0/);
	my $advance = $n->add(qw/advance -label Advanced
                                 -underline 0/);

	
	
	
	#more frames
	my $fra4 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top',-fill=>'x');
	
	#frames within tabs
	my $tabfra1 = $basic -> Frame(-borderwidth => '3')->pack(-side => 'top',-fill=>'x');
	my $tabfra2 = $basic -> Frame(-relief => 'groove', -borderwidth => '5')->pack(-side => 'top',-fill=>'both');
	my $tabfra3 = $advance -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top',-fill=>'x');
	my $tabfra4 = $advance -> Frame(-relief => 'groove', -borderwidth => '5')->pack(-side => 'top',-fill=>'x');
	
	# radio buttons
	my $rad1 = $fra1 -> Radiobutton(-text => 'Self-Blast', -value => '1', -variable =>\$self_blast);
	my $rad2 = $fra2 -> Radiobutton(-text => 'Database Blast', -value => '0', -variable =>\$self_blast);
	my $rad3 = $tabfra2 -> Radiobutton(-text => 'Use Default Settings', -value => '1', -variable =>\$default);
	my $rad4 = $tabfra2 -> Radiobutton(-text => 'Use Advanced Settings', -value => '0', -variable =>\$default);
	
	# Checkbuttons
	my $parseb = $tabfra4 -> Checkbutton(-text=>"Parse input files", -variable =>\$parse);
	my $quick_blastb = $tabfra4 -> Checkbutton(-text=>"Perform BLASTs", -variable =>\$quickmine);
	my $get_orphansb = $tabfra4 -> Checkbutton(-text=>"Parse BLAST reports", -variable =>\$orphans);
	my $orphan_countb = $tabfra4 -> Checkbutton(-text=>"Count orphans", -variable =>\$orphan_count);
	my $syntenyb = $tabfra4 -> Checkbutton(-text=>"Plot synteny maps", -variable =>\$dot_plot);
	
	# text boxes
	my $quick_thresh = $fra3 -> Entry(-textvariable=>\$sig_thresh);
	
	# blast button
	$sblastb = $fra1 -> Button(-text=>"Configure", -command =>\&quick_selfblast_conf);
	$dblastb = $fra2 -> Button(-text=>"Configure", -command =>\&quick_dbblast_conf);
		
	# labels
	my $quick_description = $tabfra1 -> Label(-text=>"Quickmine is a computational pipeline comprised \nof several scripts. Advanced settings allow you to\n choose which parts of the pipeline to run. Its \nrecommended that you use the default settings");
	my $mainlabel = $top -> Label(-text=>"QuickMine configuration",-relief=>"groove");
	my $threshlabel = $fra3 -> Label(-text=>"Threshold Score");
	#my $englab = $top -> Label(-text=>"Msat finding engine");
	
	#check for default values
	if ($default == 1)
	{
		$parse = 1;
		$quickmine = 1;
		$orphans = 1;
		$orphan_count = 0;
		$dot_plot = 0;
	}
	
	# save files when save pressed
	# save the information
	my $save = $fra4 -> Button(-text=>"Save", -command => sub { 
		# create new instance of the config file so can keep the changes made by the blast subroutines
		my $cfg2 = new Config::Simple($quickmine_file);
		# re-form the string passed to $mconf
		$cfg2->param("PARAMS.sig_thresh", $sig_thresh);
		$cfg2->param("LEAVE_ALONE.write_fasta_files", $write_fasta_files);
		$cfg2->param("RUN.parse", $parse);
		$cfg2->param("RUN.format", $self_blast);
		
		$cfg2->param("RUN.quickmine", $quickmine);
		$cfg2->param("RUN.split", $quickmine);
		
		$cfg2->param("RUN.orphans", $orphans);
		$cfg2->param("RUN.binary", $orphans);
		$cfg2->param("RUN.hits", $orphans);
		$cfg2->param("RUN.genetable", $orphans);
		
		$cfg2->param("RUN.orphan_count", $orphan_count);
		$cfg2->param("RUN.orphan_size", $orphan_count);
		$cfg2->param("RUN.paralogue_count", $orphan_count);
		$cfg2->param("RUN.increment", $orphan_count);
		$cfg2->param("RUN.time", $orphan_count);
		$cfg2->param("RUN.plots", $orphan_count);
		$cfg2->param("RUN.indiv_plot", $orphan_count);
		
		$cfg2->param("RUN.dot_plot", $dot_plot);
		$cfg2->param("PARAMS.self_hit", $self_blast);
		
		$cfg2->param("PATHS.path2scripts", $path2scripts);
		
		
		$cfg2 -> save();
		$quickmine_button -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $fra4 -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $fra4 -> Button(-text=>"QuickMine Documentation (html)", -command => sub { &rtfm("xterm -e \"lynx $installdir/etc/quickmine_manual.html\"") });

	
	# configure the layout 
	#$mainlabel -> pack(-side=>'top',-anchor =>'n', -fill=>'x');
	$quick_description -> pack(-side=>'left', -anchor=>'w', -fill=>'y');
	$rad3 -> pack(-side=>'top', -anchor=>'w', -fill=>'y');
	$rad4 -> pack(-side=>'top', -anchor=>'w', -fill=>'y');
	$rad1 -> pack(-side=>'left',-anchor =>'w', -fill=>'y');
	$sblastb -> pack(-side=>'right',-anchor =>'e',-fill=>'y');
	$rad2 -> pack(-side=>'left',-anchor =>'w',-fill=>'y');
	$dblastb -> pack(-side=>'right',-anchor =>'e',-fill=>'y');
	$parseb-> pack(-side=>'top',-anchor =>'w', -fill=>'y');
	$quick_blastb-> pack(-side=>'top',-anchor =>'w', -fill=>'y');
	$get_orphansb-> pack(-side=>'top',-anchor =>'w', -fill=>'y');
	$orphan_countb-> pack(-side=>'top',-anchor =>'w', -fill=>'y');
	$syntenyb-> pack(-side=>'top',-anchor =>'w', -fill=>'y');
	$threshlabel-> pack(-side=>'left',-anchor =>'w',-fill=>'y');
	$quick_thresh-> pack(-side=>'right',-anchor =>'e',-fill=>'y');

	$rtfm -> pack(-side=>'top',-fill=>'x');
	$save -> pack(-side=>'left',-anchor =>'w',-fill=>'y');
	$close -> pack(-side=>'right',-anchor =>'e',-fill=>'y');
}
# DBBLAST FOR QUICKMINE
sub quick_dbblast_conf 
{
	# vars
	my $cfg = new Config::Simple($quickmine_file);
	my $program = $cfg->param("PARAMS.blast_programme");
	my $blast_command = $cfg->param("PARAMS.blast_command");
	my $database;
	my $other_opts;
	my $proc = $paths->param(-block=>'PROCESSING');
	my $blast_exec = $proc->{dbblast}; 
	#regexp on blast command to obtain individual parts
	$blast_command =~m/-d (.*)/;
	my $temp_command = $1;
	if ($temp_command =~m/\s-.\s/)
	{
		$temp_command =~m/(.*?)\s(-.*)/;
		$database = $1;
		$other_opts = $2;
	}
	else
	{
		$database = $temp_command;
	}
	#replace \ with quotes
	$other_opts =~s/\\/\"/g;
	# new window
	my $top = $mw -> Toplevel();
	$top->title('dbblast');

	# radio buttons
	my $rad0 = $top -> Radiobutton(-text => 'blastn',-value => "blastn",-variable => \$program);
	my $rad1 = $top -> Radiobutton(-text => 'blastx',-value => "blastx",-variable => \$program);
	my $rad2 = $top -> Radiobutton(-text => 'tblastx',-value => "tblastx",-variable => \$program);
	my $rad3 = $top -> Radiobutton(-text => 'blastp',-value => "blastp",-variable => \$program);

	my $ent2 = $top -> Entry(-textvariable=>\$database);
	my $ent4 = $top -> Entry(-textvariable=>\$other_opts);
	my $save = $top -> Button(-text=>"Save", -command => sub { 
		$cfg->param("PARAMS.blast_programme", $program);
		# put the quotes back in
		$other_opts =~s/\"/\\/g;
		$blast_command = "$blast_exec -p $program -d $database $other_opts";
		$cfg->param("PARAMS.blast_command", $blast_command);
		my $count_end = "_SELF_"."$program"."_overview.html";
		$cfg->param("ENDINGS.count_end",$count_end);
		my $time_end = "_orphan_increment.html";
		$cfg->param("ENDINGS.time_end", $time_end);
		my $matrix_end = "_SELF_"."$program"."_matrix.html";
		$cfg->param("ENDINGS.matrix_end", $matrix_end);
		my $end = "_SELF_"."$program"."_overview.html.hits.html";
		$cfg->param("ENDINGS.end",$end);
		$cfg -> save();
		$dblastb -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $top -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $top -> Button(-text=>"blastall documentation", -command => sub { &rtfm("xterm -e \"man blastall\"") });

	# labels
	my $lab1 = $top -> Label(-text=>"DB-blast configuration",-relief=>"groove");
	my $lab2 = $top -> Label(-text=>"Database");
	my $lab4 = $top -> Label(-text=>"Other options");

	# geometry
	$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2);
	$rad0 -> grid(-row=>1,-column=>0,-columnspan=>2,-sticky=>"w");
	$rad1 -> grid(-row=>2,-column=>0,-columnspan=>2,-sticky=>"w");
	$rad2 -> grid(-row=>3,-column=>0,-columnspan=>2,-sticky=>"w");
	$rad3 -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"w");
	$lab2 -> grid(-row=>5,-column=>0,-sticky=>"w");
	$lab4 -> grid(-row=>6,-column=>0,-sticky=>"w");
	$ent2 -> grid(-row=>5,-column=>1,-sticky=>"w");
	$ent4 -> grid(-row=>6,-column=>1,-sticky=>"w");
	$rtfm -> grid(-row=>9,-column=>0,-columnspan=>2,-sticky=>"ew");
	$save -> grid(-row=>10,-column=>0,-sticky=>"w");
	$close -> grid(-row=>10,-column=>1,-sticky=>"e");

}
# SELFBLAST
sub quick_selfblast_conf 
{
	# vars
	# vars
	my $cfg = new Config::Simple($quickmine_file);
	my $program = $cfg->param("PARAMS.blast_programme");
	my $blast_command = $cfg->param("PARAMS.blast_command");
	my $formatdb = $cfg->param("PARAMS.formatdb");
	my $database;
	my $other_opts;
	my $proc = $paths->param(-block=>'PROCESSING');
	my $blast_exec = $proc->{dbblast};
	my $format_exec = $proc->{formatdb}; 
	#regexp on blast command to obtain individual parts
	$blast_command =~m/-d (.*)/;
	my $temp_command = $1;
	if ($temp_command =~m/\s-.\s/)
	{
		$temp_command =~m/(.*?)\s(-.*)/;
		$database = $1;
		$other_opts = $2;
	}
	else
	{
		$database = $temp_command;
	}
	$database = "$outdir/SELF_blast_database";
	#replace \ with quotes
	$other_opts =~s/\\/\"/g;
	
	#regex on formatdb to get sequence type
	$formatdb =~m/-p\s([T|F])/;
	my $sequence_type = $1;
	# new window
	my $top = $mw -> Toplevel();
	$top->title('dbblast');
	
	# Tried using frames to create better looking window. 
	# Takes time and would need to do for all windows. Large operation. Do when have chance.
	
	# frames
	my $fra5 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top', -fill => 'x');
	my $fra0 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top', -fill => 'x');
	my $fra1 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top', -fill => 'x');
	my $fra2 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top', -fill => 'x');
	my $fra3 = $top -> Frame(-relief => 'groove', -borderwidth => '3')->pack(-side => 'top', -fill => 'x');
	# radio buttons
	my $rad0 = $fra0 -> Radiobutton(-text => 'blastn',-value => "blastn",-variable => \$program);
	my $rad1 = $fra0 -> Radiobutton(-text => 'blastx',-value => "blastx",-variable => \$program);
	my $rad2 = $fra0 -> Radiobutton(-text => 'tblastx',-value => "tblastx",-variable => \$program);
	my $rad3 = $fra0 -> Radiobutton(-text => 'blastp',-value => "blastp",-variable => \$program);
	my $rad4 = $fra1 -> Radiobutton(-text => 'DNA',-value => "F",-variable => \$sequence_type);
	my $rad5 = $fra1 -> Radiobutton(-text => 'Protein',-value => "T",-variable => \$sequence_type);
	my $ent4 = $fra2 -> Entry(-textvariable=>\$other_opts);
	my $save = $fra3 -> Button(-text=>"Save", -command => sub { 
		$cfg->param("PARAMS.blast_programme", $program);
		# put the quotes back in
		$other_opts =~s/\"/\\/g;
		$blast_command = "$blast_exec -p $program -d $database $other_opts";
		$cfg->param("PARAMS.blast_command", $blast_command);
		$formatdb = "$format_exec -i $database -p $sequence_type -o F";
		$cfg->param("PARAMS.formatdb", $formatdb);
		my $count_end = "_SELF_"."$program"."_overview.html";
		$cfg->param("ENDINGS.count_end",$count_end);
		my $time_end = "_orphan_increment.html";
		$cfg->param("ENDINGS.time_end", $time_end);
		my $matrix_end = "_SELF_"."$program"."_matrix.html";
		$cfg->param("ENDINGS.matrix_end", $matrix_end);
		my $end = "_SELF_"."$program"."_overview.html.hits.html";
		$cfg->param("ENDINGS.end",$end);
		$cfg -> save();
		$sblastb -> configure(-background => "$confcolour");
		destroy $top;
	});
	my $close =  $fra3 -> Button(-text=>"Close", -command => sub { destroy $top; });
	my $rtfm =   $fra3 -> Button(-text=>"blastall documentation", -command => sub { &rtfm("xterm -e \"man blastall\"") });

	# labels
	my $lab1 = $fra5 -> Label(-text=>"Self-Blast configuration");
	my $lab3 = $fra1 -> Label(-text=>"Input type");
	my $lab4 = $fra2 -> Label(-text=>"BLAST options");

	# pack the widgets
	$lab1 -> pack();
	$rad0 -> pack(-side=>'left');
	$rad1 -> pack(-side=>'left');
	$rad2 -> pack(-side=>'left');
	$rad3 -> pack(-side=>'left');
	$lab3 -> pack();
	$rad4 -> pack(-side=>'left');
	$rad5 -> pack(-side=>'left');
	$lab4 -> pack(-side=>'left');
	$ent4 -> pack(-side=>'right');
	$rtfm -> pack();
	$save -> pack(-side=>'left');
	$close -> pack(-side=>'right');
	# geometry
	#$lab1 -> grid(-row=>0,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad0 -> grid(-row=>1,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad1 -> grid(-row=>2,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad2 -> grid(-row=>3,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad3 -> grid(-row=>4,-column=>0,-columnspan=>2,-sticky=>"w");
	#$lab3 -> grid(-row=>5,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad4 -> grid(-row=>6,-column=>0,-columnspan=>2,-sticky=>"w");
	#$rad5 -> grid(-row=>7,-column=>0,-columnspan=>2,-sticky=>"w");
	#$lab4 -> grid(-row=>9,-column=>0,-sticky=>"w");
	#$ent4 -> grid(-row=>9,-column=>1,-sticky=>"w");
	#$rtfm -> grid(-row=>12,-column=>0,-columnspan=>2,-sticky=>"ew");
	#$save -> grid(-row=>13,-column=>0,-sticky=>"w");
	#$close -> grid(-row=>13,-column=>1,-sticky=>"e");

}
