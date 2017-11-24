=head1 NAME

AnT::Worker::BufferFH - Object containing a buffered filehandle

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

An AnT::Worker::BufferFH provides a buffered filehandle for use
with classes which need to look ahead while reading e.g. EMBL

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

package AnT::Worker::BufferFH;

use strict;
use Carp;

=head2 new

 Title   : new
 Usage   : $buffered_fh = AnT::Worker::BufferFH->new(-fh => \*FH)
 Function: Creates an object which acts as a wrapper to a filehandle
         : and carries its own buffer around with it
 Returns : A new AnT::Worker::BufferFH object
 Args    : -fh (filehandle) or -file (filename). If -buffer is
         : specified it must be an array reference. It primes
         : the buffer with the array contents

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my @args  = @_;

    my $self  = {};

    my $_defaults = {
		     filehandle => undef,
		     buffer     => []
		    };

    bless($self, $class);

    $self->_init($_defaults, @args);
    return $self;
}

=head2 _init

 Title   : _init
 Usage   : N/A
 Function: Object initialisation from default values which may be
         : overridden by arguments supplied to the constructor
 Returns : Nothing
 Args    : Reference to a hash of defaults, plus the arguments to
         : the constructor

=cut

sub _init
{
    my ($self, $_defaults, %args) = @_;
    my ($fh, $file, $buffer);

    %$self = %$_defaults;

    %args = map { lc($_), $args{$_} } keys %args;
    foreach (keys %args)
    {
	my $val = $args{$_};
	if (/^-fh$/)     { $fh     = $val; next }
	if (/^-file$/)   { $file   = $val; next }
	if (/^-buffer$/) { $buffer = $val; next }
    }

    unless (defined $fh or defined $file)
    {
	confess "BufferFH requires either a file or filehandle as arguments"
    }

    if (defined $file)
    {
	if (defined $fh)
	{
	    confess "BufferFH is unable to accept both file and filehandle arguments at once"
	}
	else
	{
	    $fh = IO::File->new("$file");
	    confess "BufferFH was unable to open file $file\n" unless defined $fh;
	}
    }
    if (defined $buffer)
    {
	unless (ref($buffer) eq 'ARRAY')
	{
	    confess "BufferFH constructor argument -buffer expects an array reference"
	}
    }
    $self->{filehandle} = $fh;
    $self->{buffer}     = $buffer if defined $buffer;
}

=head2 buffered_read

 Title   : buffered_read
 Usage   : N/A
 Function: Returns the next line from the filehandle if the
         : buffer is empty, otherwise it returns a line from
         : the buffer
 Returns : Line, or buffer contents
 Args    : None

=cut

sub buffered_read
{
    my ($self) = @_;
    my $line;
    my $fh = $self->{filehandle};

    if (@{$self->{buffer}})
    {
	$line = shift @{$self->{buffer}}
    }
    else
    {
	# We invoke a local copy of the input record separator to
	# protect us from evil scripts which alter this global.
	# Back, fiend!
	local $/ = "\n";

	$line = <$fh>;
	chomp($line) if defined $line;
    }
    return $line;
}

=head2 unbuffered_read

 Title   : buffered_read
 Usage   : N/A
 Function: Returns the next line from the filehandle, bypassing
         : the buffer
 Returns : Line from filehandle
 Args    : None

=cut

sub unbuffered_read
{
    my ($self) = @_;
    my $fh = $self->{filehandle};

    # We invoke a local copy of the input record separator to
    # protect us from evil scripts which alter this global.
    # Back, fiend!
    local $/ = "\n";

    my $line = <$fh>;
    chomp($line) if defined $line;

    return $line;
}

=head2 buffer_line

 Title   : buffered_line
 Usage   : N/A
 Function: Adds a line to the buffer
 Returns : Nothing
 Args    : Line to add to buffer

=cut

sub buffer_line
{
    my ($self, $line) = @_;

    push(@{$self->{buffer}}, $line) if defined $line;
}

=head2 flush_buffer

 Title   : flush_buffer
 Usage   : N/A
 Function: Flushes the buffer
 Returns : The content of the buffer as an array of lines
 Args    : None

=cut

sub flush_buffer
{
    my ($self) = @_;

    my @buffer = @{$self->{buffer}};
    $self->{buffer} = [];
    return @buffer;
}

=head2 write_line

 Title   : write_line
 Usage   : N/A
 Function: Writes a line to the file/filehandle
 Returns : Nothing
 Args    : None

=cut

sub write_line
{
    my ($self, $line) = @_;

    my $fh = $self->{filehandle};
    print $fh $line;
}

1;
