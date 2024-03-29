package Win32::PrintBox;

use warnings;
use strict;
use Win32;
use Win32::Console::ANSI qw/ Cursor /;
require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw(set_page_size get_page_size);

our $VERSION = sprintf "%d.%03d", q$Revision: 0.001 $ =~ /: (\d+)\.(\d+)/;

our @COLLECTED_TEXT = ();
our $DEFAULT_PAGE_SIZE = 25;
our $PAGE_SIZE = $DEFAULT_PAGE_SIZE;
our $PAGE_NUM = 1;

my $WinMode = ($^X =~ m/wperl/i) ? 1 : 0;
my $CMDExists = CMD_Cursor();

if ($WinMode) {
	tie *MSG_FH, 'Win32::PrintBox::IO';
	select MSG_FH;
}

END {
    return if $CMDExists;
    # Otherwise, ask the user for permission to close, so any output is acknowledged
    print STDERR "Press any key to continue\n";
    <>;
}

##################################
sub CMD_Cursor {
    # If a new command prompt window is opened, then the 'y' cursor position will be at the top
    # This can be faked by running cls & my_perl_script.pl
    my ($x, $y) = Cursor();     # reads cursor position
    return $y-1;                # Home is 1,1, subtract 1 to get true/false flag
}

##################################
# Accessor for number or elements to cache in @collected_text
sub get_page_size {
    return $PAGE_SIZE;
}
##################################
# Mutator for number or elements to cache in @collected_text
sub set_page_size {
    my $temp = shift // $DEFAULT_PAGE_SIZE;
    $PAGE_SIZE = $temp;
}
##################################
package Win32::PrintBox::IO;

use constant VB_OK => 0;
use constant VB_OK_CANCEL => 1;
use constant VB_CANCEL => 2;

##################################
sub new {
	my $self = bless {}, shift;
	# Using a "__WARN__" handler provides the way to re-direct warn statements to a MsgBox
	$SIG{'__WARN__'} = sub { WarnBox(@_) };
	return $self;
}

##################################
sub WarnBox {											# Send Warnings immediately
	my $msg = join("\n", @_);
	return unless $msg ne '';
	my $answer = Win32::MsgBox($msg, VB_OK_CANCEL, 'Warning!');
	die if $answer == VB_CANCEL;
}

##################################
sub PrintMsgBox {
	my $self = shift;
	push (@COLLECTED_TEXT, @_);
	if ($#COLLECTED_TEXT >= $PAGE_SIZE - 1) {
		my $answer = Win32::MsgBox( join('', @COLLECTED_TEXT), VB_OK_CANCEL, 'Page ' . $PAGE_NUM++);
		@COLLECTED_TEXT = ();
		die if $answer == VB_CANCEL;
	}
}

sub TIEHANDLE	{ shift->new(@_) }
sub PRINT		{ shift->PrintMsgBox(@_) }
sub PRINTF		{ shift->PrintMsgBox(sprintf(@_)) }
# DESTROY only applies in WinMode; in DOS mode, we didnt tie anything, so nothing to destroy
sub DESTROY     { Win32::MsgBox( join('', @COLLECTED_TEXT), VB_OK, 'Done') if @COLLECTED_TEXT}

1;
__END__

=for pod

=head1 NAME

Win32::PrintBox - Redirects print STDOUT and warn statements to a message box under wperl

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Win32::PrintBox;
    
    print "Program output\n";
    warn "I am here\n";

At startup, the module checks if the script was started in C<Windows Mode> (it 
looks for wperl in $^X).  If so, it creates a new glob (*MSG_FH), and ties the 
PRINT, PRINTF and DESTROY methods to it, to convert warn and print statements 
into Win32 message boxes. It also sets up a handler to trap __WARN__ signals, to 
do the same.

For warn, output is immediately sent to the user as a message box.

For print and printf, the output is buffered.  When a C<PAGE_SIZE> of output is 
collected, it is displayed to the user.  When DESTROY is called, any remaining output left in 
the buffer is also displayed.  The user may press CANCEL to exit the script prematurely.

In console mode (non-windows), this module does nothing, unless the script was 
started from a windows program (File Explorer or other windows application).  In 
this case, A DOS pause command is emulated at the end of the script, so that the 
user can acknowledge console output before the console window closes.

=head1 SUBROUTINES/METHODS

=head2 new

Sets up a handler to catch __WARN__ signals, and process them with sub C<WarnBox> .

=head2 WarnBox

Sends warn text to a Win32::MsgBox immediately.  Script dies if user presses CANCEL.

=head2 PrintMsgBox

This sub is called via a tied file handle when there is a print or printf to 
STDOUT.  Normally it just buffers the input, and returns.

If enough data is collected, the page full of is presented to the user in one 
shot via a message box and the buffer is emptied.  The user acknowleges the 
message by clicking OK, but can exit, by clicking CANCEL.

Does not actually override the print function, but traps the currently selected 
file handle, and redirects the output directed to the selected filehandle, and 
handles it with the subroutines within this package.  Not exactly easy to 
understand, but works very nicely.

No need to override CORE::print or CORE::GLOBAL::print.  Which doesnt work anyways.

=head2 CMD_Cursor

Examines the cursor location of the console window. If a new command prompt 
window is opened, then the 'y' cursor position will be at row 1. This will be 
used in the END block to decide whether a `Press any key to continue` should be 
added.

=head2 get_page_size

Returns the configured number of lines of collected text, before a message box is displayed.  Default is 25.

=head2 set_page_size

Sets the configured number of lines of collected text, before a message box is displayed.

=head1 AUTHOR

David Clarke, C<< <dclarke@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-win32-printbox at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Win32-PrintBox>.  
I will be notified, and then you will automatically be notified of progress on 
your bug as I make changes.

This module does not play nicely with other modules that use the __WARN__ signal 
handler, for obvious reasions.

compiler errors/warnings will not be visible if the script is executed via wperl 

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Win32::PrintBox

You can also look for information at:

=over 4

=item * RT: CPANs request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Win32-PrintBox>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Win32-PrintBox>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Win32-PrintBox>

=item * Search CPAN

L<http://search.cpan.org/dist/Win32-PrintBox/>

=back

=head1 ACKNOWLEDGEMENTS

Concepts for intercepting warn and print statements are borrowed from the 
Apache::ASP module by Joshua Chamas.

The idea for checking the cursor location came from 
L<http://www.codeguru.com/cpp/misc/misc/consoleapps/article.php/c15893/Pause-Before-Exiting-a-Console-Application.htm>.  Thanks to Marc Gregoire.  I tried 
using Win32::Console to capture the initial cursor position, but Win32::Console::ANSI seemed
to work better.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 David Clarke

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
