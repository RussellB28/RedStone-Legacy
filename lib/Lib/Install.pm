# lib/Lib/Install.pm - Installation subroutines.
# Copyright (C) 2013-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Lib::Install;
use strict;
use warnings;
use Exporter;
use English qw(-no_match_vars);

our $VERSION = 1.00;
our @ISA = qw(Exporter);
our @EXPORT = qw(println modfind build checkver checkcore installmods);

sub println {
    my ($out) = @_;

    if (defined $out) {
        print $out.$/;
    }
    else {
        print $/;
    }

    return 1;
}

sub modfind {
    my ($mod) = @_;

    print "    $mod: ";
    eval('require '.$mod.'; 1;') and println "Found" or println "Not Found" and $Install::ERROR = 1;

    return 1;
}

sub build {
    my ($features, $Bin, $syswide) = @_;
    if (!defined $syswide) { $syswide = 0 }

    open(my $FTIME, q{>}, "$Bin/time") or println "Failed to install." and exit;
    print $FTIME time."\n" or println "Failed to install." and exit;
    close $FTIME or println "Failed to install." and exit;

    open(my $FOS, q{>}, "$Bin/os") or println "Failed to install." and exit;
    print $FOS $OSNAME."\n" or println "Failed to install." and exit;
    close $FOS or println "Failed to install." and exit;

    open(my $FFEAT, q{>}, "$Bin/feat") or println "Failed to install." and exit;
    print $FFEAT $features."\n" or println "Failed to install." and exit;
    close $FFEAT or println "Failed to install." and exit;

    open(my $FPERL, q{>}, "$Bin/perl") or println "Failed to install." and exit;
    print $FPERL "$]\n" or println "Failed to install." and exit;
    close $FPERL or println "Failed to install." and exit;

    open(my $FVER, q{>}, "$Bin/ver") or println "Failed to install." and exit;
    print $FVER "3.0.0d\n" or println "Failed to install." and exit;
    close $FVER or println "Failed to install." and exit;

    open my $FSYS, '>', "$Bin/syswide" or println "Failed to install." and exit;
    print {$FSYS} "$syswide\n" or println "Failed to install." and exit;
    close $FSYS or println "Failed to install." and exit;

    return 1;
}

sub checkver {
    my ($ver) = @_;

    println "* Connecting to update server...";
    my $uss = IO::Socket::INET->new(
        'Proto'    => 'tcp',
        'PeerAddr' => 'dist.xelhua.org',
        'PeerPort' => 80,
        'Timeout'  => 30
    ) or println "Cannot connect to update server! Aborting update check.";
    send($uss, "GET http://dist.xelhua.org/auto/version.txt\n", 0);
    my $dll = '';
    while (my $data = readline($uss)) {
        $data =~ s/(\n|\r)//g;
        my ($v, $c) = split('=', $data);

        if ($v eq "url") {
            $dll = $c;
        }
        elsif ($v eq "version") {
            if ($ver ne $c) {
                println("!!! NOTICE !!! Your copy of RedStone is outdated. Current version: ".$ver." - Latest version: ".$c);
                println("!!! NOTICE !!! You can get the latest RedStone by downloading ".$dll);
                println("!!! NOTICE !!! Won't install without force.");
                exit;
            }
            else {
                println("* RedStone is up-to-date.");
            }
        }
    }

    return 1;
}

sub checkcore {
    println "\0";
    modfind('Carp');
    modfind('FindBin');
    modfind('feature');
    modfind('IO::Socket');
    modfind('Sys::Hostname');
    modfind('POSIX');
    modfind('Time::Local');
}

sub installmods {
    my ($prefix) = @_;
    print 'Would you like to install any official modules? [y/N] ';
    my $response = <STDIN>;
    chomp $response;
    if (lc $response eq 'y') {
        println 'What modules would you like to install? (separate by commas)';
        println 'Available modules: ABotStats, AUR, Autojoin, Badwords, Bitly, BotStats, BTC, Calc, ChanTopics, Coin, Dictionary, DNS, EightBall, Etymology Eval, Factoids, FML, Greet, Hangman, HelloChan, HostedBy, Ignore, IMDB, IPLookup, IsItUp, Karma, LastFM, LinkTitle, Logger, LOLCAT, NickPrefix, OnJoin, Oper, PHP, Ping, Pisg, QDB, SASLAuth, Seen, Shoutcast, Sickipedia, Spotify, Twitter, Translate, UnixTime, UNO, Urban, Weather, Werewolf, WerewolfAdmin, WerewolfExtra';
        print '> ';
        my $modules = <STDIN>; chomp $modules;
        $modules =~ s/ //g;
        my @modst = split ',', $modules;
        foreach (@modst) {
            system "perl \"$prefix/bin/buildmod\" $_";
        }
    }
}

1;
# vim: set ai et sw=4 ts=4:
