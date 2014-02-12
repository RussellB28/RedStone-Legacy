# Module: Note. See below for documentation.
# Copyright (C) 2012-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Note;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans hook_add hook_del conf_get);
use API::IRC qw(privmsg notice);
use API::Log qw(slog dbug alog);

my $CMDChar;

# Initialization subroutine.
sub _init {
	cmd_add('note', 0, 0, \%M::Note::HELP_NOTE, \&M::Note::cmd_note) or return;
	# Create the Note_onjoin hook.
    hook_add('on_rcjoin', 'Note_onrcjoin', \&M::Note::on_rcjoin) or return;
	
	$Auto::DB->do('CREATE TABLE IF NOT EXISTS note (id INT PRIMARY KEY,user TEXT, touser TEXT, text TEXT, net TEXT)') or return;
	
	$CMDChar = (conf_get('fantasy_pf') ? (conf_get('fantasy_pf'))[0][0] : "!");
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('note') or return;
	
	hook_del('on_rcjoin', 'Note_onrcjoin') or return;
    # Success.
    return 1;
}

our %HELP_NOTE = (
    en => "Adds a note system so messages can be passed on by a bot. \2Syntax:\2 NOTE [ADD|DEL] <NOTE/ID>",
	#nl => "Zorgt voor een notitie systeem. \2Syntax:\2 NOTE [ADD|DEL] <NOTE/ID>",
);

sub cmd_note {
	my ($src,@argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr},$src->{chan},trans("Not enough parameters.").q{.});
		return;
	}
	
	if(uc($argv[0]) eq "ADD") {
		if(!defined($argv[2])) {
			privmsg($src->{svr},$src->{chan},trans("Not enough parameters.").q{.});
			return;
		}
		my $dbh = $Auto::DB->prepare("SELECT id FROM note ORDER BY id DESC LIMIT 1");
		$dbh->execute();
		my $ID;
		while (my $ref = $dbh->fetchrow_hashref()) {
			$ID = $ref->{'id'};
		}
		$ID++;
		my $msg = join(' ',@argv[2 .. $#argv]);
		my $dbh = $Auto::DB->prepare("INSERT INTO note (user,touser,text,net,id) VALUES ('".$src->{nick}."','".lc($argv[1])."', '".$msg."', '".uc($src->{svr})."',".$ID.")");
		$dbh->execute();
		notice($src->{svr},$src->{nick},"Added note for ".$argv[1]." (".$msg.") ID: ".$ID.".");
		return 1;
	} elsif(uc($argv[0]) eq "DEL") {
		if(defined($argv[2])) {
			privmsg($src->{svr},$src->{chan},trans("Too many parameters.").q{.});
			return;
		}
		privmsg($src->{svr}, $src->{chan}, "Deleted ID \2$argv[1]\2 from the note list.");
		my $dbh = $Auto::DB->prepare('DELETE FROM note WHERE id = ?');
		$dbh->execute($argv[1]);
		return 1;
	} else {
		privmsg($src->{svr},$src->{chan},trans("Incorrect parameter").q{.});
		return;
	}
}

sub on_rcjoin {
    my ($src,$chan) = @_;
	my $dbh = $Auto::DB->prepare("SELECT * FROM note WHERE touser = '".lc($src->{nick})."'");
	#my $dbh = $Auto::DB->prepare("INSERT INTO note (user,to,text,net) VALUES ('".$src->{nick}."','".lc($argv[0])."', '".$msg."', '".uc($src->{svr})."')");
	$dbh->execute();
	my ($NoteUser,$NoteTo,$NoteText,$NoteNet,$NoteID);
	while (my $ref = $dbh->fetchrow_hashref()) {
		if($ref->{'touser'} eq lc($src->{nick})) {
			$NoteUser = $ref->{'user'};
			$NoteTo = $ref->{'touser'};
			$NoteText = $ref->{'text'};
			$NoteNet = $ref->{'net'};
			$NoteID = $ref->{'id'};
			
			
			if(!defined($NoteText)) {
				return;
			}
			
			if($NoteNet eq uc($src->{svr})) {
				notice($src->{svr},$src->{nick},"\x0307\2Note\2 from \x0305\2".$NoteUser."\2:\x0307 ".$NoteText);
				notice($src->{svr},$src->{nick},"To delete this note use: ".$CMDChar."note del ".$NoteID);
			} else {
				return;
			}
			
			
		}
	}
}

# Start initialization.
API::Std::mod_init('Note', 'Peter', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Note - allows users to add notes for one other.

=head1 VERSION

 1.00
 
=head1 SYNOPSIS

 <~[nas]peter> ^note
 

=head1 DESCRIPTION

This will send notes to users left by other users.

=head1 CONFIGURATION

No configurable options.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<DBI>

The SQL agent used

=back

=head1 AUTHOR

This module was written by Peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
