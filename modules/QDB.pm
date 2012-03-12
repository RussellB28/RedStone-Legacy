# Module: QDB. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::QDB;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del trans has_priv conf_get match_user);
use API::IRC qw(privmsg notice);
our @BUFFER;
our $last_id = 0;

sub _init {
    # Create the QDB command.
    cmd_add('QDB', 0, 0, \%M::QDB::HELP_QDB, \&M::QDB::cmd_qdb) or return;
    
    # Check the database format. Fail to load if it's PostgreSQL.
    if ($Auto::ENFEAT =~ /pgsql/) { err(2, 'Unable to load QDB: PostgreSQL is not supported.', 0); return }

    # Check for database table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS qdb (quoteid INTEGER PRIMARY KEY, creator TEXT, time INTEGER, quote TEXT)') or return;

    # Success.
    return 1;
}

sub _void {
    # Delete the QDB command.
    cmd_del('QDB') or return;

    # Success.
    return 1;
}

# Help hash for QDB. Spanish, French and German translations needed.
our %HELP_QDB = (
    en => "This command allows you to add, read, and delete quotes. \002Syntax:\002 QDB (ADD|VIEW|SEARCH|MORE|COUNT|LATEST|BACK|RAND|DEL) [quote|expression]",
);

sub cmd_qdb {
    my ($src, @argv) = @_;
    
    # ADD|VIEW|COUNT|RAND|SEARCH|MORE|DEL|LATEST|BACK.
    given (uc $argv[0]) {
        when ('ADD') {
            &qdb_add($src, @argv);
        }
        when ('VIEW') {
            &qdb_view($src, @argv);
        }

        when ('COUNT') {
            &qdb_count($src, @argv);
        }

        when ('RAND') {
            &qdb_rand($src, @argv);
        }

        when ('SEARCH') {
            &qdb_search($src, @argv);
        }

        when ('MORE') {
            &qdb_more($src, @argv);
        }

        when ('DEL') {
            &qdb_del($src, @argv);
        }

        when ('LATEST') {
            &qdb_latest($src, @argv);
        }

        when('BACK') {
            &qdb_back($src, @argv);
        }

        default { 

            if (defined ($argv[0]) and $argv[0] =~ /[[:digit:]]/) {
                &qdb_view($src, @argv);
                return;
            }

            my $start_string = "Unknown action \002".uc($argv[0])."\002. ";
            if (!defined $argv[0]) {
                $start_string = "";
            }

            notice($src->{svr}, $src->{nick}, "$start_string\002Syntax:\002 QDB (ADD|VIEW|SEARCH|MORE|COUNT|LATEST|BACK|RAND|DEL) [quote]"); 
            return; 
        }

    }

    return 1;
}

sub qdb_add {
    my ($src,@argv) = @_;
    # QDB ADD.
    if (!defined $argv[1]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    # Insert into database.
    my $dbq = $Auto::DB->prepare('INSERT INTO qdb (creator, time, quote) VALUES (?, ?, ?)') or  notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
    $dbq->execute($src->{nick}, time, join(q{ }, @argv[1..$#argv])) or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
    # Get ID.
    my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;

    $dbq = $Auto::DB->prepare('SELECT quoteid FROM qdb LIMIT 1 OFFSET ?') or privmsg($src->{svr}, $src->{chan}, 'Quote successfully submitted.') and return;
    $dbq->execute($count - 1) or privmsg($src->{svr}, $src->{chan}, 'Quote successfully submitted.') and return;
    my @data = $dbq->fetchrow_array;

    if (!defined $data[0]) {
        privmsg($src->{svr}, $src->{chan}, 'Quote successfully submitted.');
        return;
    }


    privmsg($src->{svr}, $src->{chan}, 'Quote successfully submitted. ID: '.$data[0]);
}

sub qdb_view {
    my ($src,@argv) = @_;
    # QDB VIEW.

    my $quoteid;
    if (defined ($argv[0]) and $argv[0] =~ /[[:digit:]]/) {
        $quoteid = $argv[0];
    } else {
        if (!defined $argv[1]) {
            notice($src->{svr}, $src->{nick}, trans('Not enough parameters, please specify a quote id').q{.});
            return;
        }

        if ($argv[1] =~ /[[:alpha:]]/) {
            notice($src->{svr}, $src->{nick}, trans('The quote id must be a number').q{.});
            return;
        }

        $quoteid = $argv[1];
    }

    # Get quote.
    my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE quoteid = ?') or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    $dbq->execute($quoteid) or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    my @data = $dbq->fetchrow_array;
    
    # Check for an unusual issue.
    if (!defined $data[1]) { notice($src->{svr}, $src->{nick}, trans('That quote does not exist, it may have been deleted').q{.}); return }
    $last_id = $data[0];
    # Send it back.
    privmsg($src->{svr}, $src->{chan}, "\002Submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
    privmsg($src->{svr}, $src->{chan}, '> '.$data[3]);
}

sub qdb_count {
    my ($src,@argv) = @_;
    # Get count.
    my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or notice($src->{svr}, $src->{nick}, trans('I have no quotes in my database.')) and return;
    # Send it back.
    privmsg($src->{svr}, $src->{chan}, "There is currently \002$count\002 quotes in my database.");    
}

sub qdb_rand {
    my ($src,@argv) = @_;
    # Get count.
    my $count = $Auto::DB->selectrow_array('SELECT COUNT(*) FROM qdb') or notice($src->{svr}, $src->{nick}, trans('I have no quotes in my database.')) and return;
    # Random number.
    my $rand = int(rand($count));
    if ($rand == 0) { $rand = $count }
    # Get quote.
    my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE quoteid = ?') or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
    $dbq->execute($rand) or notice($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
    my @data = $dbq->fetchrow_array;
    $last_id = $data[0];
    # Send it back.
    privmsg($src->{svr}, $src->{chan}, "\002ID:\002 $data[0] - \002Submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
    privmsg($src->{svr}, $src->{chan}, '> '.$data[3]);
}

sub qdb_latest {
    my ($src,@argv) = @_;
    # Get quote.
    my $dbq = $Auto::DB->prepare('SELECT * FROM qdb ORDER BY quoteid DESC LIMIT 1') or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    $dbq->execute() or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    my @data = $dbq->fetchrow_array;
    # Check for an unusual issue.
    if (!defined $data[1]) { notice($src->{svr}, $src->{nick}, trans('That quote does not exist, it may have been deleted.')); return }
    $last_id = $data[0];
    # Send it back.
    privmsg($src->{svr}, $src->{chan}, "\002Quote ID\002 $data[0], \002submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
    privmsg($src->{svr}, $src->{chan}, '> '.$data[3]);    
}

sub qdb_search {
    my ($src,@argv) = @_;
    # QDB SEARCH.
    # Get all quotes.
    my $dbq = $Auto::DB->prepare('SELECT * FROM qdb') or return;
    $dbq->execute or return;
    my $quotes = $dbq->fetchall_hashref('quoteid') or return;
    # Set expression.
    my $expr = my $rexpr = join ' ', @argv[1 .. $#argv];
    $rexpr =~ s{\(}{\\\(}g;
    $rexpr =~ s{\)}{\\\)}g;
    $rexpr =~ s{\?}{\\\?}g;
    $rexpr =~ s{\*}{\\\*}g;
    $rexpr =~ s{\[}{\\\[}g;
    $rexpr =~ s{\]}{\\\]}g;
    $rexpr =~ s{\.}{\\\.}g;
    $rexpr =~ s{\$}{\\\$}g;
    $rexpr =~ s{\^}{\\\^}g;
    $rexpr =~ s{\|}{\\\|}g;
    $rexpr =~ s{\+}{\\\+}g;
    $rexpr =~ s{\\}{\\\\}g;
    $rexpr =~ s{\?}{\\\?}g;
    $rexpr =~ s{\{}{\\\{}g;
    $rexpr =~ s{\}}{\\\}}g;
    # Clear the buffer.
    @BUFFER = ();
    # Iterate through all quotes.
    foreach my $qkt (keys %$quotes) {
        # Check if we have a match.
        if ($quotes->{$qkt}->{quote} =~ m/$rexpr/ism) {
            # Match. Add to buffer.
            push @BUFFER, "\2ID:\2 $qkt - ".$quotes->{$qkt}->{quote};
        }
    }
    # Check if we had any matches.
    if (!defined $BUFFER[0]) {
        privmsg($src->{svr}, $src->{chan}, "No results for \2$expr\2.");
        return;
    }
    # Return four quotes.
    privmsg($src->{svr}, $src->{chan}, "\2".scalar @BUFFER."\2 results for \2$expr\2:");
    my $i = 0;
    my $si = 3;
    if (conf_get('qdb_search_resnum')) { $si = (conf_get('qdb_search_resnum'))[0][0] - 1 }
    while ($i <= $si) {
        if (!defined $BUFFER[0]) {
            last;
        }

        privmsg($src->{svr}, $src->{chan}, shift @BUFFER);
        $i++;
    }
}

sub qdb_more {
    my ($src,@argv) = @_;
    # Check if there's any quotes in the buffer.
    if (!defined $BUFFER[0]) { 
        notice($src->{svr}, $src->{nick}, 'No quotes in buffer.');
        return; 
    }
    # Return four quotes.
    my $i = 0;
    my $si = 3;
    if (conf_get('qdb_search_resnum')) { $si = (conf_get('qdb_search_resnum'))[0][0] - 1 }
    while ($i <= $si) {
        if (!defined $BUFFER[0]) {
            last;
        }
        privmsg($src->{svr}, $src->{chan}, shift @BUFFER);
        $i++;
    }    
}

sub qdb_back {
    my ($src,@argv) = @_;
        
    if ($last_id == 0 or $last_id == 1 ) {
        notice($src->{svr}, $src->{nick}, trans("There does not seem to be a quote before the last one!"));
        return;
    }
    my $li;
    # hack, we don't want it to loop forever, but I can't think of a better way to find the next quote if a few have been deleted, giveup after 20... it's unlikely that 20 quotes in a row will have been deleted and it won't effect performance as much as 50. 
    my @data;
    for ($li = 1; $li < 20; $li++) {
        my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE quoteid = ?');
        $dbq->execute($last_id - $li); 
        @data = $dbq->fetchrow_array;
        if (defined $data[1]) { 
            last;
        }
    }        
    # Check for an unusual issue.
    if (!defined $data[1]) { notice($src->{svr}, $src->{nick}, trans('There does not seem to be a quote before the last one!')); return }
    $last_id = $data[0];
    
    # Send it back.
    privmsg($src->{svr}, $src->{chan}, "\002Quote ID\002 $data[0], \002submitted by\002 $data[1] \002on\002 ".POSIX::strftime('%F', localtime($data[2]))." \002at\002 ".POSIX::strftime('%I:%M %p', localtime($data[2])));
    privmsg($src->{svr}, $src->{chan}, '> '.$data[3]);   
}

sub qdb_del {
    my ($src,@argv) = @_;
    # Check for the cmd.qdbdel privilege.
    if (!has_priv(match_user(%$src), 'cmd.qdbdel')) {
        notice($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
        return;
    }
    # Check for the needed parameter.
    if (!defined $argv[1]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    my $dbq = $Auto::DB->prepare('SELECT * FROM qdb WHERE quoteid = ?') or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    $dbq->execute($argv[1]) or notice($src->{svr}, $src->{nick}, trans('An error occurred').'. Quote might not exist.') and return;
    my @data = $dbq->fetchrow_array;
    # Check for an unusual issue.
    if (!defined $data[1]) { notice($src->{svr}, $src->{nick}, trans('That quote does not exist, it may have been deleted.')); return }            
    # Update database.
    $dbq = $Auto::DB->do("DELETE FROM qdb WHERE quoteid = $argv[1]");
    notice($src->{svr}, $src->{nick}, (($dbq) ? 'Done.' : trans('An error occurred').q{.}));
}

API::Std::mod_init('QDB', 'Xelhua', '1.05', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

QDB - Quote database module.

=head1 VERSION

 1.05

=head1 SYNOPSIS

 <JohnSmith> !qdb add <JohnDoe> moocows
 <Auto> Quote successfully submitted. ID: 732

=head1 DESCRIPTION

This module adds the QDB (ADD|VIEW|SEARCH|MORE|COUNT|LATEST|BACK|RAND|DEL) command, for
adding, viewing, listing number of, viewing a random, deleting a quote from the
Auto database.

=head1 INSTALL

Before using QDB, we'd recommend adding the following to your configuration
file:

 qdb_search_resnum <number>;

Where <number> is the amount of results returned per SEARCH/MORE load.

This is not required, 4 will be used if it is not specified.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
