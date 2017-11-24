=head1 NAME

AnT::Searchfactory - Object which creates sequence I/O stream
objects for various search programs

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

An AnT::Searchfactory object creates AnT::Worker::<format>::Search
objects for I/O of each supported search program. These objects
provide the relevant next_result() methods to read search results.

=head1 METHODS

See below. Methods private to this module are prefixed by an
underscore.

=head1 AUTHOR

Keith James (kdj@sanger.ac.uk)

=head1 ACKNOWLEDGEMENTS

See AnT.pod

=head1 COPYRIGHT

Copyright (C) 2000 Keith James. All Rights Reserved.

=head1 DISCLAIMER

This module is provided "as is" without warranty of any kind. It may
be used, redistributed and/or modified under the same conditions as
Perl itself.

=cut

package AnT::Searchfactory;

use strict;
use Carp;
use IO::File;
use AnT::Worker::BufferFH;
use AnT::Worker::Fasta::Search;
use AnT::Worker::Blast::Search;

=head2 make

 Title   : make
 Usage   : $search = AnT::Searchfactory->make(-fh => \*FH, -program =>
         : 'fasta');
         : $search = AnT::Searchfactory->make(-file => "foo", -program =>
         : 'blast');
 Function: Creates a new AnT::Searchfactory stream to read
         : AnT::Worker::<format>::Search objects. The stream of Blast or
         : Fasta reports may come from a file (e.g. previously run
         : searches) or a filehandle (e.g. a pipe opened from a running
         : search program).
 Returns : AnT::Worker::<format>::Search object
 Args    : -fh (filehandle) or -file (filename) or -bfh
         : (AnT::Worker::BufferFH object), -program (blast or fasta)

=cut

sub make
{
    my $proto = shift;
    my %args = @_;

    my ($fh, $bfh, $file, $program, $stream);

    %args = map { lc($_), $args{$_} } keys %args;
    foreach (keys %args)
    {
	my $val = $args{$_};
	if (/^-fh$/)      { $fh      = $val; next }
	if (/^-bfh$/)     { $bfh     = $val; next }
	if (/^-file$/)    { $file    = $val; next }
	if (/^-program$/) { $program = $val; next }
    }

    if (defined $fh and defined $bfh)
    {
	confess "Searchfactory accepts one of -file, -fh or -bfh at once"
    }

    if (defined $file)
    {
	if (defined $fh)
	{
	    	confess "Searchfactory accepts one of -file, -fh or -bfh at once"
	}
	else
	{
	    $fh = IO::File->new("$file")
	}
    }

    unless (defined $program)
    {
	carp "You need to supply a program to Searchfactory";
	return;
    }

    $bfh = AnT::Worker::BufferFH->new(-fh => $fh) unless defined $bfh;

 CASE:
    {
	if ($program =~ /fasta/i)
	{
	    $stream = AnT::Worker::Fasta::Search->new(-bfh => $bfh);
	    last CASE;
	}
	if ($program =~ /blast/i)
	{
	    $stream = AnT::Worker::Blast::Search->new(-bfh => $bfh);
	    last CASE;
	}

	carp "Invalid program [$program] supplied to Searchfactory";
	return;
    }
    return $stream;
}

1;
