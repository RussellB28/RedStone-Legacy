# Module: UNO. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::UNO;
use strict;
use warnings;
use feature qw(switch);
use List::Util qw(shuffle);
use API::Std qw(cmd_add cmd_del hook_add hook_del trans conf_get err has_priv match_user awarn);
use API::IRC qw(notice privmsg);

# Set various variables we'll need throughout runtime.
my $UNO = my $UNOW = my $DRAWN = my $ANYEDITION = 0;
my ($UNOCHAN, $UNOTIME, $UNOGCC, $EDITION, $ORDER, $DEALER, @DECK, $CURRTURN, $TOPCARD, %PLAYERS, %NICKS);

# Initialization subroutine.
sub _init {
    # Check for required configuration values.
    if (!conf_get('uno:edition') or !conf_get('uno:msg')) {
        err(3, 'Unable to load UNO: Missing required configuration values.', 0);
        return;
    }
    $EDITION = (conf_get('uno:edition'))[0][0];
    $EDITION = ucfirst $EDITION;

    # Check if the edition is valid.
    if ($EDITION !~ m/^(Original|Super|Advanced|Any)$/xsm) {
        err(3, "Unable to load UNO: Invalid edition: $EDITION", 0);
        return;
    }
    # Check if the message method is valid.
    if ((conf_get('uno:msg'))[0][0] !~ m/^(notice|msg)$/xsmi) {
        err(3, 'Unable to load UNO: Invalid message method: '.(conf_get('uno:msg'))[0][0], 0);
        return;
    }

    # If it's Any, set ANYEDITION.
    if ($EDITION eq 'Any') { $ANYEDITION = 1 }

    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load UNO: PostgreSQL is not supported.', 0); return }

    # Create `unoscores` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS unoscores (player TEXT, score INTEGER)') or return;
    # Create `unorecords` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS unorecords (name TEXT, value TEXT, winner TEXT)') or return;

    # Create UNO command.
    cmd_add('UNO', 0, 0, \%M::UNO::HELP_UNO, \&M::UNO::cmd_uno) or return;

    # Create on_nick hook.
    hook_add('on_nick', 'uno.updatedata.nick', \&M::UNO::on_nick) or return;
    # Create on_quit hook.
    hook_add('on_quit', 'uno.updatedata.quit', \&M::UNO::on_quit) or return;
    # Create on_part hook.
    hook_add('on_part', 'uno.updatedata.part', \&M::UNO::on_part) or return;
    # Create on_kick hook.
    hook_add('on_kick', 'uno.updatedata.kick', \&M::UNO::on_kick) or return;
    # Create on_rehash hook.
    hook_add('on_rehash', 'uno.updatedata.rehash', \&M::UNO::on_rehash) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the UNO command.
    cmd_del('UNO') or return;

    # Delete on_nick hook.
    hook_del('on_nick', 'uno.updatedata.nick') or return;
    # Delete on_quit hook.
    hook_del('on_quit', 'uno.updatedata.quit') or return;
    # Delete on_part hook.
    hook_del('on_part', 'uno.updatedata.part') or return;
    # Delete on_kick hook.
    hook_del('on_kick', 'uno.updatedata.kick') or return;
    # Delete on_rehash hook.
    hook_del('on_rehash', 'uno.updatedata.rehash') or return;

    # Success.
    return 1;
}

# Help hash for UNO command. Spanish, German and French translations needed.
our %HELP_UNO = (
    en => "This command allows you to take various actions in a game of UNO. \2Syntax:\2 UNO (START|JOIN|DEAL|PLAY|DRAW|PASS|CARDS|TOPCARD|STATS|KICK|QUIT|STOP|TOPTEN|RECORDS|SCORE) [parameters]",
);

# Callback for UNO command.
sub cmd_uno {
    my ($src, @argv) = @_;

    # Check for action parameter.
    if (!defined $argv[0]) {
        sendmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Iterate through available actions.
    given (uc $argv[0]) {
        when (/^(START|S)$/) {
            # UNO START
            
            # Ensure there is not a game already running.
            if ($UNO or $UNOW) {
                sendmsg($src->{svr}, $src->{nick}, "There is already a game of UNO running in \2$UNOCHAN\2.");
                return;
            }

            # Check if the channel is allowed.
            if (conf_get('uno:reschan')) {
                my ($net, $chan) = split '/', (conf_get('uno:reschan'))[0][0];
                if (lc $src->{svr} ne lc $net or lc $src->{chan} ne lc $chan) {
                    return;
                }
            }

            # If it's Any Edition, do some extra stuff.
            if ($ANYEDITION) {
                # Require the second parameter.
                if (!defined $argv[1]) {
                    sendmsg($src->{svr}, $src->{nick}, "This Auto is configured with Any Edition. You must specify the edition to play with as a second parameter. \2Syntax:\2 UNO START <edition>");
                    return;
                }
                if ($argv[1] !~ m/^(original|super|advanced)$/ixsm) {
                    sendmsg($src->{svr}, $src->{nick}, "Invalid edition \2$argv[1]\2. Must be original, super or advanced.");
                    return;
                }
                # Set the edition.
                $argv[1] = lc $argv[1];
                $EDITION = $argv[1];
                $EDITION = uc(substr $EDITION, 0, 1).substr $EDITION, 1;
            }

            # Set variables.
            $UNOW = 1;
            $UNOCHAN = $src->{svr}.'/'.lc $src->{chan};
            $PLAYERS{lc $src->{nick}} = [];
            $NICKS{lc $src->{nick}} = $src->{nick};
            $DEALER = lc $src->{nick};

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has started \2\00303U\003\00304N\003\00312O\003 for Auto ($EDITION Edition)\2. UNO JOIN to join the game.");
        }
        when (/^(JOIN|J)$/) {
            # UNO JOIN

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Ensure the user is not already playing.
            if (defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re already playing.');
                return;
            }

            # Update variables.
            $PLAYERS{lc $src->{nick}} = []; 
            $NICKS{lc $src->{nick}} = $src->{nick};
            if ($UNO) {
                $ORDER .= ' '.lc $src->{nick};
                for (my $i = 1; $i <= 7; $i++) { _givecard(lc $src->{nick}) }
            }

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has joined the game.");
            if ($UNO) {
                my $cards;
                foreach (@{$PLAYERS{lc $src->{nick}}}) {
                    $cards .= ' '._fmtcard($_);
                }
                $cards = substr $cards, 1;
                sendmsg($src->{svr}, $src->{nick}, "Your cards are: $cards");
            }
        }
        when ('DEAL') {
            # UNO DEAL
            
            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if cards have already been dealt.
            if ($UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'Cards have already been dealt. Game is in progress.');
                return;
            }
            
            # Ensure this is the dealer.
            if (lc $src->{nick} ne $DEALER) {
                sendmsg($src->{svr}, $src->{nick}, 'Only the dealer may deal the cards.');
                return;
            }

            # Check for at least two players.
            if (keys %PLAYERS < 2) {
                sendmsg($src->{svr}, $src->{nick}, 'Two players are required to play.');
                return;
            }

            # Deal the cards.
            @DECK = _newdeck();
            foreach (keys %PLAYERS) {
                for (my $i = 1; $i <= 7; $i++) { _givecard($_) }
                my $cards;
                foreach my $card (@{$PLAYERS{$_}}) {
                    $cards .= ' '._fmtcard($card);
                }
                $cards = substr $cards, 1;
                sendmsg($src->{svr}, $_, "Your cards are: $cards");
                $ORDER .= " $_";
            }
            $ORDER = substr $ORDER, 1;

            $UNO = 1;
            $UNOW = 0;
            $UNOTIME = time;
            $TOPCARD = _givecard();
            my ($tccol, $tcval) = split m/[:]/, $TOPCARD;
            while ($tcval eq 'T' || $tccol =~ m/^W/xsm) {
                $TOPCARD = _givecard();
                ($tccol, $tcval) = split m/[:]/, $TOPCARD;
            }
            $CURRTURN = lc $src->{nick};
            my $left = _nextturn(2);
            $CURRTURN = $left;
            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 has dealt the cards. Game begin.");
            privmsg($src->{svr}, $src->{chan}, "\2".$NICKS{$left}."'s\2 turn. Top Card: "._fmtcard($TOPCARD));
            _runcard($TOPCARD, 1);
        }
        when (/^(PLAY|P)$/) {
            # UNO PLAY
            
            # Check for required parameters.
            if (!defined $argv[2]) {
                sendmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').". \2Syntax:\2 UNO PLAY <color> <card>");
                return;
            }
            
            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                sendmsg($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Fix color.
            $argv[1] =~ s/blue/B/ixsm;
            $argv[1] =~ s/red/R/ixsm;
            $argv[1] =~ s/green/G/ixsm;
            $argv[1] =~ s/yellow/Y/ixsm;
            $argv[2] =~ s/blue/B/ixsm;
            $argv[2] =~ s/red/R/ixsm;
            $argv[2] =~ s/green/G/ixsm;
            $argv[2] =~ s/yellow/Y/ixsm;

            # Check if they have this card.
            if (!_hascard(lc $src->{nick}, uc $argv[1].':'.uc $argv[2])) {
                sendmsg($src->{svr}, $src->{nick}, 'You don\'t have that card.');
                return;
            }

            # Check if this card is valid.
            my ($tcc, $tcv) = split m/[:]/, $TOPCARD;
            if (uc $argv[1] eq 'R' || uc $argv[1] eq 'B' || uc $argv[1] eq 'G' || uc $argv[1] eq 'Y') {
                if (uc $argv[1] ne $tcc and uc $argv[2] ne $tcv) {
                    sendmsg($src->{svr}, $src->{nick}, 'That card cannot be played.');
                    return;
                }
            }

            # If this is a Trade Hands card...
            if (uc $argv[2] eq 'T') {
                # Ensure it has the extra argument.
                if (!defined $argv[3]) {
                    sendmsg($src->{svr}, $src->{nick}, "The Trade Hands card requires the <player> argument. \2Syntax:\2 UNO PLAY <color> T <player>");
                    return;
                }
                # Ensure they're not trading hands with themselves.
                if (lc $argv[3] eq $CURRTURN) {
                    sendmsg($src->{svr}, $src->{nick}, 'You may not trade with yourself.');
                    return;
                }
                # Ensure the player they're trading with is playing.
                if (!defined $PLAYERS{lc $argv[3]}) {
                    sendmsg($src->{svr}, $src->{nick}, "No such user \2$argv[3]\2 is playing.");
                    return;
                }
            }

            # If it's a wildcard...
            if ($argv[1] =~ m/^W/ixsm) {
                # Ensure the third argument is a valid color.
                if ($argv[2] !~ m/^(R|B|G|Y)$/ixsm) {
                    sendmsg($src->{svr}, $src->{nick}, "Invalid color \2$argv[2]\2.");
                    return;
                }
            }

            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 plays "._fmtcard(uc $argv[1].':'.uc $argv[2]));
            
            # Delete the card from the player's hand.
            my $delres = _delcard(lc $src->{nick}, uc $argv[1].':'.uc $argv[2]);
            if ($delres == -1) { return 1 }

            # Play the card.
            if (defined $argv[3]) {
                _runcard(uc $argv[1].':'.uc $argv[2], 0, @argv[3..$#argv]);
            }
            else {
                _runcard(uc $argv[1].':'.uc $argv[2], 0, undef);
            }
            $DRAWN = 0;
            $UNOGCC++;
        }
        when (/^(DRAW|D)$/) {
            # UNO DRAW
            
            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                sendmsg($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Don't allow them to draw more than one card.
            if ($DRAWN eq lc $src->{nick}) {
                sendmsg($src->{svr}, $src->{nick}, 'You may only draw once per turn. Use UNO PASS to pass.');
                return;
            }

            # Now draw card(s) depending on the edition.
            if ($EDITION eq 'Original') {
                sendmsg($src->{svr}, $src->{nick}, 'You drew: '._fmtcard(_givecard(lc $src->{nick})));
                my ($net, $chan) = split '/', $UNOCHAN;
                privmsg($net, $chan, "\2$src->{nick}\2 drew a card.");
            }
            else {
                my $amnt = int rand 11;
                if ($amnt > 0) {
                    my @dcards;
                    for (my $i = $amnt; $i > 0; $i--) { push @dcards, _fmtcard(_givecard(lc $src->{nick})) }
                    sendmsg($src->{svr}, $src->{nick}, 'You drew: '.join(' ', @dcards));
                }
                my ($net, $chan) = split '/', $UNOCHAN;
                privmsg($net, $chan, "\2$src->{nick}\2 drew \2$amnt\2 cards.");
            }
            $DRAWN = lc $src->{nick};
        }
        when ('PASS') {
            # UNO PASS
            
            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                sendmsg($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Make sure they've drawn at least once.
            if ($DRAWN ne lc $src->{nick}) {
                sendmsg($src->{svr}, $src->{nick}, 'You must draw once before passing.');
                return;
            }

            # Pass this user.
            $DRAWN = 0;
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 passes.");
            _nextturn(0);
        }
        when (/^(CARDS|C)$/) {
            # UNO CARDS
            
            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }
         
            # Tell them their cards.
            my $cards;
            foreach (@{$PLAYERS{lc $src->{nick}}}) { $cards .= ' '._fmtcard($_) }
            $cards = substr $cards, 1;
            sendmsg($src->{svr}, $src->{nick}, "Your cards are: $cards");
        }
        when (/^(TOPCARD|TC)$/) {
            # UNO TOPCARD
            
            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Return the top card.
            sendmsg($src->{svr}, $src->{nick}, 'Top card: '._fmtcard($TOPCARD));
        }
        when (/^(KICK|K)$/) {
            # UNO KICK

            # Second parameter required.
            if (!defined $argv[1]) {
                sendmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').". \2Syntax:\2 UNO KICK <player>");
                return;
            }

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Ensure they have permission to perform this action.
            if (lc $src->{nick} ne $DEALER && !has_priv(match_user(%$src), 'uno.override')) {
                sendmsg($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                return;
            }
            
            # Check if the player is in the game.
            if (!defined $PLAYERS{lc $argv[1]}) {
                sendmsg($src->{svr}, $src->{nick}, "No such user \2$argv[1]\2 is playing.");
                return;
            }

            # Delete the player.
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 has kicked \2$argv[1]\2 from the game.");
            _delplyr(lc $argv[1]);
        }
        when (/^(QUIT|Q)$/) {
            # UNO QUIT

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Check if they're playing.
            if (!defined $PLAYERS{lc $src->{nick}}) {
                sendmsg($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Check if it's his/her turn.
            if (lc $src->{nick} ne $CURRTURN) {
                sendmsg($src->{svr}, $src->{nick}, 'It is not your turn.');
                return;
            }

            # Delete them.
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 has left the game.");
            _delplyr(lc $src->{nick});
        }
        when ('STOP') {
            # UNO STOP

            # Ensure a game is running.
            if (!$UNO and !$UNOW) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }

            # Ensure they have permission to perform this action.
            if (lc $src->{nick} ne $DEALER && !has_priv(match_user(%$src), 'uno.override')) {
                sendmsg($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                return;
            }

            # Stop the game.
            my ($net, $chan) = split '/', $UNOCHAN;
            $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = $UNOTIME = $UNOGCC = 0;
            %PLAYERS = ();
            %NICKS = ();
            privmsg($net, $chan, "\2$src->{nick}\2 has stopped the game.");
        }
        when (/^(CARDCOUNT|STATS|CC)$/) {
            # UNO CARDCOUNT

            # Ensure a game is running.
            if (!$UNO) {
                sendmsg($src->{svr}, $src->{nick}, 'There is currently no game of UNO running. UNO START to start a game.');
                return;
            }
            else {
                if ($src->{svr}.'/'.lc $src->{chan} ne $UNOCHAN) {
                    sendmsg($src->{svr}, $src->{nick}, "UNO is currently running in \2$UNOCHAN\2.");
                    return;
                }
            }
        
            # Iterate through all players, getting their card count.
            my $str;
            foreach my $plyr (keys %PLAYERS) {
                $str .= " \2".$NICKS{$plyr}.":".scalar @{$PLAYERS{$plyr}}."\2";
            }
            $str = substr $str, 1;
            
            # Return count.
            sendmsg($src->{svr}, $src->{nick}, "Card count: $str");
        }
        when (/^(TOPTEN|T10|TOP10)$/) {
            # UNO TOPTEN

            # Get data.
            my $dbq = $Auto::DB->prepare('SELECT * FROM unoscores') or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            my $data = $dbq->fetchall_hashref('player') or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            # Check if there's any scores.
            if (keys %$data) {
                my $str;
                my $i = 0;
                foreach (sort {$data->{$b}->{score} <=> $data->{$a}->{score}} keys %$data) {
                    if ($i >= 10) { last }
                    $str .= ", \2$_:".$data->{$_}->{score}."\2";
                    $i++;
                }
                $str = substr $str, 2;
                sendmsg($src->{svr}, $src->{nick}, "Top Ten: $str");
            }
            else {
                sendmsg($src->{svr}, $src->{nick}, trans('No data available').q{.});
            }
        }
        when (/^(RECORDS|R)$/) {
            # UNO RECORDS
            
            # Get data.
            my $dbq = $Auto::DB->prepare('SELECT * FROM unorecords') or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            $dbq->execute or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
            my $data = $dbq->fetchall_hashref('name') or sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;

            # Prepare message.
            my $msg;
            # Check for fastest game.
            if ($data->{fast}) {
                if ($data->{fast}->{value}) {
                    my $durtime = $data->{fast}->{value};
                    my $hours = my $mins = my $secs = 0;
                    while ($durtime >= 3600) { $hours++; $durtime -= 3600 }
                    while ($durtime >= 60) { $mins++; $durtime -= 60 }
                    while ($durtime >= 1) { $secs++; $durtime -= 1 }
                    if (length $mins < 2) { $mins = "0$mins" }
                    if (length $secs < 2) { $secs = "0$secs" }
                    $msg .= " The fastest game ever lasted \2$hours:$mins:$secs\2; the winner was \2$data->{fast}->{winner}\2.";
                }
            }
            # Check for slowest game.
            if ($data->{slow}) {
                if ($data->{slow}->{value}) {
                    my $durtime = $data->{slow}->{value};
                    my $hours = my $mins = my $secs = 0;
                    while ($durtime >= 3600) { $hours++; $durtime -= 3600 }
                    while ($durtime >= 60) { $mins++; $durtime -= 60 }
                    while ($durtime >= 1) { $secs++; $durtime -= 1 }
                    if (length $mins < 2) { $mins = "0$mins" }
                    if (length $secs < 2) { $secs = "0$secs" }
                    $msg .= " The slowest game ever lasted \2$hours:$mins:$secs\2; the winner was \2$data->{slow}->{winner}\2.";
                }
            }
            # Check for most cards played in a game.
            if ($data->{cards}) {
                if ($data->{cards}->{value}) {
                    $msg .= " The most cards ever played was \2$data->{cards}->{value}\2; the winner was \2$data->{cards}->{winner}\2.";
                }
            }
            # Check for most players in a game.
            if ($data->{players}) {
                if ($data->{players}->{value}) {
                    $msg .= " The most players ever was \2$data->{players}->{value}\2; the winner was \2$data->{players}->{winner}\2.";
                }
            }

            # Check if there was any data.
            if (!$msg) {
                # Nope.
                sendmsg($src->{svr}, $src->{nick}, trans('No data available').q{.});
            }
            else {
                # Strip leading space.
                $msg =~ s/^\s//xsm;
                sendmsg($src->{svr}, $src->{nick}, "Records: $msg");
            }
        }
        when ('SCORE') {
            # UNO SCORE

            # Second parameter needed.
            if (!defined $argv[1]) {
                sendmsg($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $target = lc $argv[1];

            if ($Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$target.'"')) {
                # Get score.
                my $score = $Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$target.'"') or
                    sendmsg($src->{svr}, $src->{nick}, trans('An error occurred').q{.}) and return;
                # Return it.
                sendmsg($src->{svr}, $src->{nick}, "Score for \2$argv[1]\2: $score");
            }
            else {
                sendmsg($src->{svr}, $src->{nick}, trans('No data available').q{.});
            }
        }
        default { sendmsg($src->{svr}, $src->{nick}, trans('Unknown action', uc $argv[0]).q{.}) }
    }

    return 1;
}

# Build a deck.
sub _newdeck {
    my @deck = qw/R:1 R:2 R:3 R:4 R:5 R:6 R:7 R:8 R:9 R:1 R:2 R:3 R:4 R:5 R:6 R:7 R:8 R:9
                  B:1 B:2 B:3 B:4 B:5 B:6 B:7 B:8 B:9 B:1 B:2 B:3 B:4 B:5 B:6 B:7 B:8 B:9
                  Y:1 Y:2 Y:3 Y:4 Y:5 Y:6 Y:7 Y:8 Y:9 Y:1 Y:2 Y:3 Y:4 Y:5 Y:6 Y:7 Y:8 Y:9
                  G:1 G:2 G:3 G:4 G:5 G:6 G:7 G:8 G:9 G:1 G:2 G:3 G:4 G:5 G:6 G:7 G:8 G:9
                  R:S R:S B:S B:S Y:S Y:S G:S G:S R:R R:R B:R B:R Y:R Y:R G:R G:R
                  R:D2 R:D2 B:D2 B:D2 Y:D2 Y:D2 G:D2 G:D2 W:* W:* W:* W:*/;

    if ($EDITION eq 'Original') {
        push @deck, qw/R:0 B:0 Y:0 G:0 WD4:* WD4:* WD4:* WD4:*/;
    }
    if ($EDITION =~ m/Super|Advanced/xsm) {
        push @deck, qw/R:T B:T Y:T G:T R:X B:X Y:X G:X WHF:* WHF:* WAH:* WAH:*/;
    }
    if ($EDITION eq 'Advanced') {
        push @deck, qw/R:W B:W Y:W G:W R:B B:B Y:B G:B/;
        for (0..4) { push @deck, @deck }
    }

    for (0..2) { @deck = shuffle(@deck) }

    return @deck;
}

# Subroutine for giving a player a card.
sub _givecard {
    my ($player) = @_;

    # Make sure the player exists.
    if (defined $player) {
        if (!defined $PLAYERS{$player}) { return }
    }

    # Get a card from the deck.
    my $card = pop @DECK;

    # If the deck is empty, create a new one and announce it.
    if (!scalar @DECK) {
        @DECK = _newdeck();
        my ($gsvr, $gchan) = split '/', $UNOCHAN, 2;
        privmsg($gsvr, $gchan, "\2The deck ran out of cards! Refilled.\2");
    }

    # Add the card to the player's arrayref.
    if (defined $player) { push @{$PLAYERS{$player}}, $card }

    # Return the card.
    return $card;
}

# Return an IRC formatted version of a card name.
sub _fmtcard {
    my ($card) = @_;

    my $fmt;
    my ($color, $val) = split m/[:]/, $card;
    if ($color eq 'W' or $color eq 'WD4' or $color eq 'WAH' or $color eq 'WHF') { $val = $color }
    
    # Determine if we should state the color in the output.
    my $code = '[';
    if (conf_get('uno:english')) { if ((conf_get('uno:english'))[0][0] == 1) { $code = '[%s ' } }

    given ($color) {
        when ('R') { $fmt = sprintf "\00301,04$code$val]\003", $_ }
        when ('B') { $fmt = sprintf "\00300,12$code$val]\003", $_ }
        when ('G') { $fmt = sprintf "\00300,03$code$val]\003", $_ }
        when ('Y') { $fmt = sprintf "\00301,08$code$val]\003", $_ }
        default { $fmt = "\002\00300,01[$val]\003\002" }
    }

    return $fmt;
}

# Next turn.
sub _nextturn {
    my ($skip) = @_;
    my @order = split ' ', $ORDER.' '.$ORDER;
    my $br = 0;
    my $nplayer;
    # Iterate through the players.
    foreach (@order) {
        if ($br) {
            if ($skip eq 1) {
                $skip = $_;
                next;
            }
            $nplayer = $_;
            last;
        }
        if ($_ eq $CURRTURN) {
            $br = 1;
            next;
        }
    }
    # Check if there was a result.
    if (!defined $nplayer) {
        # Mind, this should never happen, but must be the next person in order.
        $nplayer = $order[0];
    }
    if ($skip eq 2) { return $nplayer }

    my ($net, $chan) = split '/', $UNOCHAN;
    $CURRTURN = $nplayer;
    privmsg($net, $chan, "\2".$NICKS{$nplayer}."'s\2 turn. Top Card: "._fmtcard($TOPCARD));
    my $cards;
    foreach (@{$PLAYERS{$nplayer}}) { $cards .= ' '._fmtcard($_) }
    $cards = substr $cards, 1;
    sendmsg($net, $NICKS{$nplayer}, "Your cards are: $cards");

    if ($skip) { return $skip }
    return 1;
}

# Subroutine for performing actions depending on the card.
sub _runcard {
    my ($card, $spec, @vals) = @_;
    my ($ccol, $cval) = split m/[:]/, $card;
    if (!defined $spec) { $spec = 0 }
    my ($net, $chan) = split '/', $UNOCHAN;
    if ($ccol ne 'R' && $ccol ne 'B' && $ccol ne 'G' && $ccol ne 'Y') {
        $TOPCARD = $cval.':*';
    }
    else {
        $TOPCARD = uc $card;
    }

    given ($ccol) {
        when (/(R|B|G|Y)/) {
            given ($cval) {
                when (/^[0-9]$/) {
                    if ($spec) { return }
                    _nextturn(0);
                }
                when ('R') {
                    if (keys %PLAYERS > 2) {
                        # Extract current full order.
                        my $ns = 0;
                        my @nop;
                        my @order = split ' ', $ORDER.' '.$ORDER;
                        foreach (@order) {
                            if ($ns) {
                                if ($_ eq $CURRTURN) {
                                    last;
                                }
                                else {
                                    push @nop, $_;
                                }
                            }
                            else {
                                if ($_ eq $CURRTURN) {
                                    push @nop, $_;
                                    $ns = 1;
                                }
                            }
                        }
                        # Set new order.
                        $ORDER = 0;
                        for (my $i = $#nop; $i >= 0; $i--) { $ORDER .= ' '.$nop[$i] }
                        $ORDER = substr $ORDER, 1;
                    }
                    privmsg($net, $chan, 'Game play has been reversed!');
                    if (keys %PLAYERS > 2) { _nextturn(0) }
                    else { _nextturn(1) }
                }
                when ('S') {
                    if ($spec) {
                        privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 is skipped!");
                        _nextturn(0);
                    }
                    else {
                        privmsg($net, $chan, "\2".$NICKS{_nextturn(2)}."\2 is skipped!");
                        _nextturn(1);
                    }
                }
                when ('D2') {
                    if ($spec) {
                        if ($EDITION eq 'Original') {
                            _givecard($CURRTURN);
                            _givecard($CURRTURN);
                            privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 draws 2 cards and is skipped!");
                        }
                        else {
                            my $amnt = int rand 11;
                            if ($amnt > 0) {
                                for (my $i = $amnt; $i > 0; $i--) { _fmtcard(_givecard($CURRTURN)) }
                            }
                            privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 draws \2$amnt\2 cards and is skipped!");
                        }
                        _nextturn(0);
                    }
                    else {
                        my $victim = _nextturn(2);
                        if ($EDITION eq 'Original') {
                            _givecard($victim);
                            _givecard($victim);
                            privmsg($net, $chan, "\2".$NICKS{$victim}."\2 draws 2 cards and is skipped!");
                        }
                        else {
                            my $amnt = int rand 11;
                            if ($amnt > 0) {
                                for (my $i = $amnt; $i > 0; $i--) { _fmtcard(_givecard($victim)) }
                            }
                            privmsg($net, $chan, "\2".$NICKS{$victim}."\2 draws \2$amnt\2 cards and is skipped!");
                        }
                        _nextturn(1);
                    }
                }
                when ('X') {
                    # Get all cards of this color.
                    my @xcards;
                    foreach my $ucard (@{$PLAYERS{$CURRTURN}}) {
                        my ($xhcol, undef) = split m/[:]/, $ucard;
                        if ($xhcol eq $ccol) { push @xcards, $ucard }
                    }
                    # Get a more human-readable version of the color.
                    my $tcol;
                    given ($ccol) {
                        when ('R') { $tcol = "\00304red\003" }
                        when ('B') { $tcol = "\00312blue\003" }
                        when ('G') { $tcol = "\00303green\003" }
                        when ('Y') { $tcol = "\00308yellow\003" }
                    }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 is discarding all his/her cards of color \2$tcol\2.");
                    # Delete all the cards.
                    my $delres;
                    foreach (@xcards) { $delres = _delcard($CURRTURN, $_) }
                    if (defined $delres) {
                        my $str;
                        for (my $i = $#xcards; $i >= 0; $i--) { $str .= ' '._fmtcard($xcards[$i]) }
                        $str = substr $str, 1;
                        if ($delres != -1) { 
                            sendmsg($net, $NICKS{$CURRTURN}, "You discarded: $str");
                            _nextturn(0); 
                        }
                    }
                    else { _nextturn(0) }
                }
                when ('T') {
                    # Get cards.
                    my @ucards = @{$PLAYERS{$CURRTURN}};
                    my @rcards = @{$PLAYERS{lc $vals[0]}};
                    # Reset cards.
                    $PLAYERS{$CURRTURN} = [];
                    $PLAYERS{lc $vals[0]} = [];
                    # Set new cards.
                    foreach (@ucards) { push @{$PLAYERS{lc $vals[0]}}, $_ }
                    foreach (@rcards) { push @{$PLAYERS{$CURRTURN}}, $_ }
                    # The deed, is done.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 has traded hands with \2".$NICKS{lc $vals[0]}."\2!");
                    _nextturn(0);
                }
                when ('B') {
                    # Iterate through all players.
                    foreach my $vplyr (keys %PLAYERS) {
                        # Make sure it isn't the player.
                        if ($vplyr ne $CURRTURN) {
                            for (my $i = 1; $i <= 7; $i++) { _givecard($vplyr) }
                        }
                    }
                    # Finished.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 drops a card bomb on the game! All other players gain 7 cards!");
                    _nextturn(0);
                }
                when ('W') {
                    # Get a list of players.
                    my @plyrs = keys %PLAYERS;
                    # Select a random player.
                    my $rand = int rand scalar @plyrs;
                    # Make sure the player isn't the victim.
                    while ($plyrs[$rand] eq $CURRTURN) { $rand = int rand scalar @plyrs }
                    # Set victim.
                    my $victim = $plyrs[$rand];
                    # Get the cards of the victim.
                    my $cards;
                    foreach (@{$PLAYERS{$victim}}) { $cards .= ' '._fmtcard($_) }
                    $cards = substr $cards, 1;
                    # Give the victim two cards.
                    _givecard($victim); _givecard($victim);
                    # Reveal the cards to the player.
                    sendmsg($net, $NICKS{$CURRTURN}, "\2".$NICKS{$victim}."'s\2 cards are: $cards");
                    # Finished.
                    privmsg($net, $chan, "The magical UNO wizard has revealed \2".$NICKS{$victim}."'s\2 hand to \2".$NICKS{$CURRTURN}."\2! \2".$NICKS{$victim}."\2 gains two cards!");
                    _nextturn(0);
                }
            }
        }
        default {
            given ($ccol) {
                when ('W') {
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003" }
                        when ('B') { $tcol = "\00312blue\003" }
                        when ('G') { $tcol = "\00303green\003" }
                        when ('Y') { $tcol = "\00308yellow\003" }
                    }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2.");
                    _nextturn(0);
                }
                when ('WD4') {
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003" }
                        when ('B') { $tcol = "\00312blue\003" }
                        when ('G') { $tcol = "\00303green\003" }
                        when ('Y') { $tcol = "\00308yellow\003" }
                    }
                    my $victim = _nextturn(2);
                    for (my $i = 1; $i <= 4; $i++) { _givecard($victim) }
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. \2".$NICKS{$victim}."\2 draws 4 cards and is skipped!");
                    _nextturn(1);
                }
                when ('WHF') {
                    # Get more human-readable version of the color.
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003" }
                        when ('B') { $tcol = "\00312blue\003" }
                        when ('G') { $tcol = "\00303green\003" }
                        when ('Y') { $tcol = "\00308yellow\003" }
                    }
                    # Give the next player a random amount of cards.
                    my $victim = _nextturn(2);
                    my $amnt = int rand 11;
                    while ($amnt == 0) { $amnt = int rand 11 }
                    for (my $i = 1; $i <= $amnt; $i++) { _givecard($victim) }
                    # All done.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. \2".$NICKS{$victim}."\2 draws \2$amnt\2 cards and is skipped!");
                    _nextturn(1);
                }
                when ('WAH') {
                    # Get more human-readable version of the color.
                    my $tcol;
                    given ($cval) {
                        when ('R') { $tcol = "\00304red\003" }
                        when ('B') { $tcol = "\00312blue\003" }
                        when ('G') { $tcol = "\00303green\003" }
                        when ('Y') { $tcol = "\00308yellow\003" }
                    }
                    # Iterate through all players.
                    foreach my $vplyr (keys %PLAYERS) {
                        # Make sure it isn't the player.
                        if ($vplyr ne $CURRTURN) {
                            my $amnt = int rand 11;
                            for (my $i = 1; $i <= $amnt; $i++) { _givecard($vplyr) }
                        }
                    }
                    # Finished.
                    privmsg($net, $chan, "\2".$NICKS{$CURRTURN}."\2 changes color to \2$tcol\2. All other players draw 0-10 cards!");
                    _nextturn(0);
                }
            }
        }
    }

    return 1;
}

# Subroutine for checking if a player has a card.
sub _hascard {
    my ($player, $card) = @_;

    # Check for the player arrayref.
    if (!defined $PLAYERS{$player}) { return }

    # Iterate through his/her cards.
    foreach my $pc (@{$PLAYERS{$player}}) {
        if ($pc eq $card) { return 1 }
        my ($pcol, undef) = split m/[:]/, $card;
        if ($pcol ne 'R' && $pcol ne 'B' && $pcol ne 'G' && $pcol ne 'Y') {
            my ($hcol, undef) = split m/[:]/, $pc;
            if ($pcol eq $hcol) { return 1 }
        }
    }

    return;
}

# Subroutine for deleting a card from a player's hand.
sub _delcard {
    my ($player, $card) = @_;

    # Check for the player arrayref.
    if (!defined $PLAYERS{$player}) { return }

    # Iterate through his/her cards and delete the correct card.
    for (my $i = 0; $i < scalar @{$PLAYERS{$player}}; $i++) {
        if ($PLAYERS{$player}[$i] eq $card) {
            undef $PLAYERS{$player}[$i];
            last;
        }
        else {
            my ($pcol, undef) = split m/[:]/, $card;
            if ($pcol !~ m/^(R|B|G|Y)$/xsm) {
                my ($hcol, undef) = split m/[:]/, $PLAYERS{$player}[$i];
                if ($pcol eq $hcol) { undef $PLAYERS{$player}[$i]; last }
            }
        }
    }

    # Rebuild his/her hand.
    my @cards = [];
    foreach my $hc (@{$PLAYERS{$player}}) {
        if (defined $hc) { push @cards, $hc } 
    }
    delete $PLAYERS{$player};
    $PLAYERS{$player} = [];
    if (ref $cards[0] eq 'ARRAY') { shift @cards }
    if (!scalar @cards) {
        _gameover($player);
        return -1;
    }
    elsif (scalar(@cards) == 1) {
        my ($net, $chan) = split '/', $UNOCHAN;
        privmsg($net, $chan, "\2".$NICKS{$player}."\2 has \2\00303U\003\00304N\003\00312O\003\2!");
    }
    foreach (@cards) { push @{$PLAYERS{$player}}, $_ }

    return 1;
}

# Subroutine for deleting a player.
sub _delplyr {
    my ($player) = @_;

    # Check if the player exists.
    if (!defined $PLAYERS{$player}) { return }
    my ($net, $chan) = split '/', $UNOCHAN;
    
    # Delete their player data.
    delete $PLAYERS{$player};
    delete $NICKS{$player};

    # If there is only one player left, end the game.
    if (keys %PLAYERS < 2) {
        $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = $UNOTIME = $UNOGCC = 0;
        %PLAYERS = ();
        %NICKS = ();
        privmsg($net, $chan, 'There is only one player left. Game over.');
        return 1;
    }

    # Update state data.
    if ($UNO) {
        if ($DEALER eq $player) {
            if ($CURRTURN eq $player) { $DEALER = _nextturn(2) }
            else { $DEALER = $CURRTURN }
        }
        if ($CURRTURN eq $player) { _nextturn(0) }
    }
    
    # Update order.
    if ($UNO) {
        my @order;
        foreach (split ' ', $ORDER) {
            if ($_ ne $player) { push @order, $_ }
        }
        $ORDER = join ' ', @order;
    }

    return 1;
}

# For when a player has won.
sub _gameover {
    my ($player) = @_;

    # Update player's score in the database.
    my $score;
    if (!$Auto::DB->selectrow_array('SELECT * FROM unoscores WHERE player = "'.$player.'"')) {
        $Auto::DB->do('INSERT INTO unoscores (player, score) VALUES ("'.$player.'", "0")') or err(3, "Unable to update UNO score for $player!", 0);
        $score = 0;
    }
    else {
        $score = $Auto::DB->selectrow_array('SELECT score FROM unoscores WHERE player = "'.$player.'"') or err(3, "Unable to update UNO score for $player!", 0);
    }
    $score++;
    $Auto::DB->do('UPDATE unoscores SET score = "'.$score.'" WHERE player = "'.$player.'"') or err(3, "Unable to update UNO score for $player!", 0);
    # Check for records in database.
    my ($fastest, $slowest, $mostcards, $mostplayers);
    $fastest = $Auto::DB->selectrow_array('SELECT value FROM unorecords WHERE name = "fast"') or
        $Auto::DB->do('INSERT INTO unorecords (name, value, winner) VALUES ("fast", "0", "NULL")');
    $slowest = $Auto::DB->selectrow_array('SELECT value FROM unorecords WHERE name = "slow"') or
        $Auto::DB->do('INSERT INTO unorecords (name, value, winner) VALUES ("slow", "0", "NULL")');
    $mostcards = $Auto::DB->selectrow_array('SELECT value FROM unorecords WHERE name = "cards"') or
        $Auto::DB->do('INSERT INTO unorecords (name, value, winner) VALUES ("cards", "0", "NULL")');
    $mostplayers = $Auto::DB->selectrow_array('SELECT value FROM unorecords WHERE name = "players"') or
        $Auto::DB->do('INSERT INTO unorecords (name, value, winner) VALUES ("players", "0", "NULL")');
    if (!defined $fastest) { $fastest = 0 }
    if (!defined $slowest) { $slowest = 0 }
    if (!defined $mostcards) { $mostcards = 0 }
    if (!defined $mostplayers) { $mostplayers = 0 }

    # Declare their victory.
    my ($net, $chan) = split '/', $UNOCHAN;
    privmsg($net, $chan, "Game over. \2".$NICKS{$player}."\2 is victorious! Bringing his/her score to \2$score\2! Congratulations!");
    my ($hours, $mins, $secs);
    $hours = $mins = $secs = 0;
    my $durtime = time - $UNOTIME;
    # Update records.
    if (!$fastest || $durtime < $fastest) { $Auto::DB->do('UPDATE unorecords SET value = "'.$durtime.'", winner = "'.$NICKS{$player}.'" WHERE name = "fast"') or
                                                err(3, 'Unable to update UNO record for fastest game!', 0); }
    if (!$slowest || $durtime > $slowest) { $Auto::DB->do('UPDATE unorecords SET value = "'.$durtime.'", winner = "'.$NICKS{$player}.'" WHERE name = "slow"') or
                                                err(3, 'Unable to update UNO record for slowest game!', 0); }
    if (!$mostcards || $UNOGCC > $mostcards) { $Auto::DB->do('UPDATE unorecords SET value = "'.$UNOGCC.'", winner = "'.$NICKS{$player}.'" WHERE name = "cards"') or
                                                    err(3, 'Unable to update UNO record for most cards played!', 0); }
    if (!$mostplayers || keys %PLAYERS > $mostplayers) { $Auto::DB->do('UPDATE unorecords SET value = "'.keys(%PLAYERS).'", winner = "'.$NICKS{$player}.'" WHERE name = "players"') or
                                                    err(3, 'Unable to update UNO record for most players in a game!', 0); }
    # Return data.
    while ($durtime >= 3600) { $hours++; $durtime -= 3600 }
    while ($durtime >= 60) { $mins++; $durtime -= 60 }
    while ($durtime >= 1) { $secs++; $durtime -= 1 }
    if (length $mins < 2) { $mins = "0$mins" }
    if (length $secs < 2) { $secs = "0$secs" }
    privmsg($net, $chan, "Game lasted $hours:$mins:$secs; $UNOGCC cards were played.");

    # Reset variables.
    $UNO = $UNOW = $UNOCHAN = $ORDER = $DEALER = $CURRTURN = $TOPCARD = $DRAWN = $UNOTIME = $UNOGCC = 0;
    %PLAYERS = ();
    %NICKS = ();
    @DECK = ();

    return 1;
}

# Subroutine for when someone changes their nick.
sub on_nick {
    my (($src, $newnick)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if the user is playing.
        if (defined $PLAYERS{lc $src->{nick}}) {
            # Update data.
            $PLAYERS{lc $newnick} = $PLAYERS{lc $src->{nick}};
            $NICKS{lc $newnick} = $newnick;
            if ($UNO) {
                my @order = split ' ', $ORDER;
                for (my $i = 0; $i < scalar @order; $i++) {
                    if ($order[$i] eq lc $src->{nick}) {
                        $order[$i] = lc $newnick;
                    }
                }
                $ORDER = join ' ', @order;
            }
            if ($UNO) { if ($CURRTURN eq lc $src->{nick}) { $CURRTURN = lc $newnick } }
            if ($DEALER eq lc $src->{nick}) { $DEALER = lc $newnick }
            # Delete garbage.
            delete $PLAYERS{lc $src->{nick}};
            delete $NICKS{lc $src->{nick}};
        }
    }

    return 1;
}

# Subroutine for when someone disconnects.
sub on_quit {
    my (($src, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if the user is playing.
        if (defined $PLAYERS{lc $src->{nick}}) {
            my ($net, $chan) = split '/', $UNOCHAN;
            privmsg($net, $chan, "\2$src->{nick}\2 left the game.");
            _delplyr(lc $src->{nick});
        }
    }

    return 1;
}

# Subroutine for when someone parts.
sub on_part {
    my (($src, $chan, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if this is the channel UNO is in.
        my ($net, $uchan) = split '/', $UNOCHAN;
        if ($src->{svr} eq $net and lc $chan eq $uchan) {
            # Check if the user is playing.
            if (defined $PLAYERS{lc $src->{nick}}) {
                privmsg($net, $uchan, "\2$src->{nick}\2 left the game.");
                _delplyr(lc $src->{nick});
            }
        }
    }

    return 1;
}

# Subroutine for when someone is kicked.
sub on_kick {
    my (($src, $chan, $user, undef)) = @_;

    # Check if a game is currently running.
    if ($UNO or $UNOW) {
        # There is.
        
        # Check if this is the channel UNO is in.
        my ($net, $uchan) = split '/', $UNOCHAN;
        if ($src->{svr} eq $net and lc $chan eq $uchan) {
            # Check if the user is playing.
            if (defined $PLAYERS{lc $user}) {
                privmsg($net, $uchan, "\2$user\2 left the game.");
                _delplyr(lc $user);
            }
        }
    }
}

# Subroutine for when a rehash occurs.
sub on_rehash {
    # Ensure a game isn't running right now.
    if ($UNO or $UNOW) { awarn(3, 'on_rehash: Unable to update UNO edition: A game is currently running.'); return }

    # Check if the edition is specified.
    if (conf_get('uno:edition')) {
        # Check if the edition is valid.
        my $ce = (conf_get('uno:edition'))[0][0];
        $ce = lc $ce;
        if ($ce !~ m/^(original|super|advanced|any)$/xsm) {
            awarn(3, 'on_rehash: Unable to update UNO edition: Invalid edition \''.$ce.'\'');
            return;
        }
    
        # Check if the message method is valid.
        if ((conf_get('uno:msg'))[0][0] !~ m/^(notice|msg)$/xsmi) {
            err(3, 'From UNO: Invalid message method: '.(conf_get('uno:msg'))[0][0].' -- Unloading module!', 0);
            API::Std::mod_void('UNO');
            return;
        }
        
        # Set new edition.
        $ce = uc(substr $ce, 0, 1).substr $ce, 1;
        if ($ce eq 'Any') { $ANYEDITION = 1 }
        else { $ANYEDITION = 0 }
        $EDITION = $ce;
    }

    return 1;
}

# Subroutine for sending a private message.
sub sendmsg {
    my ($svr, $target, $msg) = @_;

    # Parse uno:msg.
    given (lc((conf_get('uno:msg'))[0][0])) {
        when ('notice') { notice($svr, $target, $msg) }
        when ('msg') { privmsg($svr, $target, $msg) }
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('UNO', 'Xelhua', '2.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

UNO - Three editions of the UNO card game

=head1 VERSION

 2.00

=head1 SYNOPSIS

 # config block
 uno {
     edition "original";
     msg "notice";
 }

 <starcoder> !uno start
 <blue> starcoder has started UNO for Auto (Original Edition). UNO JOIN to join the game.
 <Crystal> !uno join
 <blue> Crystal has joined the game.
 <starcoder> !uno deal
 -blue- Your cards are: [2] [1] [9] [8] [S] [2] [D2]
 <blue> starcoder has dealt the cards. Game begin.
 <blue> Crystal's turn. Top Card: [4]
 <Crystal> !uno play g d2
 <blue> Crystal plays [D2]
 <blue> starcoder draws 2 cards and is skipped!
 <blue> Crystal's turn. Top Card: [D2]

=head1 DESCRIPTION

This module adds the complete functionality of the classic card game, UNO, to
Auto, with three editions (Original, Super, Advanced) for endless hours of fun.

See DIFFERENCES BETWEEN EDITIONS for the differences between the editions.

The commands this adds are:

 UNO START|S [edition]
 UNO JOIN|J
 UNO DEAL
 UNO PLAY|P <color (or wildcard)> <card (or color if wildcard)> [player if Trade Hands card]
 UNO DRAW|D
 UNO PASS
 UNO CARDS|C
 UNO TOPCARD|TC
 UNO STATS|CARDCOUNT|CC
 UNO KICK|K <player>
 UNO QUIT|Q
 UNO STOP
 UNO TOPTEN|TOP10|T10
 UNO RECORDS|R
 UNO SCORE <user>

All of which describe themselves quite well with just the name.

This module is compatible with Auto v3.0.0a10+.

=head1 INSTALL

You must add the following to your configuration file:

 uno {
     edition "edition here";
     msg "notice";
 }

Edition can be "original", "super", "advanced" or "any".

msg is what method we will use for sending private messages. Can be "notice"
for using notices, or "msg" for using private messages.

If any, edition must be specified per-game in START.

You may also add the reschan option to the block, like so:

 reschan "<server>/<channel>";

This will restrict use of UNO to the specified channel. Often useful since only
one channel at a time may use UNO.

You may also add the english option to the block, like so:

 english 1;

This will make cards display as [<R|G|B|Y> <card>], rather than [<card>] with
IRC color. Useful if players are color blind or their clients do not support
colors.

=head1 DIFFERENCES BETWEEN EDITIONS

This is a list of differences between the three editions.

=over

=item Original

This is the original UNO card game, unmodified.

=item Super

This edition is based on the UNO Attack game, if you're already familiar with
UNO Attack, then no need to read this as it is unmodified other than instead of
0-12 cards, you get 0-10 cards when drawing.

Differences from Original:

* When drawing cards, instead of a set number, a random amount between 0 (0 not
always used) and 10.

* The Trade Hands (T) card, which allows trading your hand with another player.

* The Discard All (X) card, which discards all the cards of the same color from
the player's hand.

* The Wild Hit Fire (WHF) card (replaces WD4), which changes the color and
gives the next player 1-10 cards (0 is disabled here), as well as skips them.

* The Wild All Hit card, which changes the color and gives all other players 0-
10 cards. Play continues as normal.


=item Advanced

This is Xelhua's own edition, based on Super with two new cards.

Also, the deck has 5x the cards when in Advanced.

Differences from Super:

* The Bomb (B) card, which gives all other players a static amount of 7 cards.

* The Wizard (W) card, which selects a random player and reveals their hand to
the user, as well as gives them two new cards that were not shown to the user.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
