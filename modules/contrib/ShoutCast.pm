# Module: ShoutCast. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::ShoutCast;
use Furl ();
use strict ();
use warnings ();
use API::Std qw(cmd_add cmd_del conf_get trans hook_add hook_del timer_add timer_del);
use API::IRC qw(privmsg notice cjoin);
use API::Log qw(dbug);
our $radiohost;
our $radioport;
our $RadioURL;
our $RadioSvrVersion;
our $radiosid;
our $radioecho;
our $radioechochannel;
our %EchoChannels;

# Initialization subroutine.
sub _init {
	hook_add('on_connect', 'SC.connect', \&M::ShoutCast::on_connect, 1) or return;
	hook_add('on_rehash', 'SC.rehash', \&M::ShoutCast::on_rehash) or return;
	hook_add('on_ucjoin', 'SC.cjoin', \&M::ShoutCast::on_chanjoin) or return;
	cmd_add('shoutcast', 0, 0, \%M::ShoutCast::HELP_SHOUTCAST, \&M::ShoutCast::cmd_shoutcast) or return;
    cmd_add('song', 0, 0, \%M::ShoutCast::HELP_SONG, \&M::ShoutCast::cmd_song) or return;
	cmd_add('dj', 0, 0, \%M::ShoutCast::HELP_DJ, \&M::ShoutCast::cmd_dj) or return;
	cmd_add('genre', 0, 0, \%M::ShoutCast::HELP_GENRE, \&M::ShoutCast::cmd_genre) or return;
	cmd_add('listeners', 0, 0, \%M::ShoutCast::HELP_LISTENERS, \&M::ShoutCast::cmd_listeners) or return;
	cmd_add('listpeak', 0, 0, \%M::ShoutCast::HELP_LISTPEAK, \&M::ShoutCast::cmd_listpeak) or return;
	cmd_add('SCurl', 0, 0, \%M::ShoutCast::HELP_URL, \&M::ShoutCast::cmd_url) or return;
	cmd_add('averagelistentime', 0, 0, \%M::ShoutCast::HELP_AVERAGELISTENTIME, \&M::ShoutCast::cmd_averagelistentime) or return;
	cmd_add('next', 0, 0, \%M::ShoutCast::HELP_NEXT, \&M::ShoutCast::cmd_next) or return;
	$radioecho = (conf_get('radioecho') ? (conf_get('radioecho'))[0][0] : "30");
	$RadioSvrVersion = (conf_get('SCversion') ? (conf_get('SCversion'))[0][0] : "2");
	$radiohost = (conf_get('radiourl') ? (conf_get('radiourl'))[0][0] : "");
	$radioport = (conf_get('radioport') ? (conf_get('radioport'))[0][0] : "");
	if($RadioSvrVersion == 2) {
		$radiosid = (conf_get('StreamID') ? (conf_get('StreamID'))[0][0] : "");
		if($radiohost =~ /http/) {
			$RadioURL = $radiohost.":".$radioport."/index.html?sid=".$radiosid;
		} else {
			$RadioURL = "http://".$radiohost.":".$radioport."/index.html?sid=".$radiosid;
		}
	} else {
		if($radiohost =~ /http/) {
			$RadioURL = $radiohost.":".$radioport;
		} else {
			$RadioURL = "http://".$radiohost.":".$radioport;
		}
	}
	if($radioecho != 0) {
		$Auto::DB->do('CREATE TABLE IF NOT EXISTS radio (net TEXT, chan TEXT)') or return;
	}
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
	hook_del('on_connect', 'SC.connect') or return;
	hook_del('on_rehash', 'SC.rehash') or return;
	hook_del('on_ucjoin', 'SC.cjoin') or return;
	cmd_del('shoutcast') or return;
	cmd_del('song') or return;
	cmd_del('dj') or return;
	cmd_del('genre') or return;
	cmd_del('listeners') or return;
	cmd_del('listpeak') or return;
	cmd_del('SCurl') or return;
	cmd_del('averagelistentime') or return;
	cmd_del('next') or return;
	timer_del('ShoutCast');
    # Success.
    return 1;
}

our %HELP_SHOUTCAST = (
    en => "Allows adding and removing channels from the radio echo. \2SYNTAX:\2 SHOUTCAST <ADD|DEL|LIST> [CHANNEL@NETWORK]",
	#nl => "Zorgt ervoor dat je kanalen kan toevoegen en verwijden van de radio echo. \2SYNTAX:\2 SHOUTCAST <ADD|DEL|LIST> [CHANNEL\@NETWORK]",
);
our %HELP_SONG = (
    en => "Fetches the current song playing \2Syntax:\2 SONG [IP:PORT]",
	#nl => "Haalt de op het moment afspelende liedje op \2Syntax:\2 SONG [IP:POORT]",
);
our %HELP_DJ = (
    en => "Fetches the current DJ playing music \2Syntax:\2 DJ [IP:PORT]",
	#nl => "Haalt de op het moment zijnde DJ op \2Syntax:\2 DJ [IP:POORT]",
);
our %HELP_GENRE = (
    en => "Fetches the current Genre of the DJ \2Syntax:\2 GENRE [IP:PORT]",
	#nl => "Haalt de op het moment zijnde Genre op van de DJ \2Syntax:\2 GENRE [IP:POORT]",
);
our %HELP_LISTENERS = (
    en => "Fetches the current amount of listeners \2Syntax:\2 LISTENERS [IP:PORT]",
	#nl => "Haalt de op het moment aantal luisterende mensen op \2Syntax:\2 LISTENERS [IP:POORT]",
);
our %HELP_LISTPEAK = (
    en => "Fetches the most listeners ever \2Syntax:\2 LISTPEAK [IP:PORT]",
	#nl => "Haalt de de meeste luisteraars ooit op \2Syntax:\2 LISTPEAK [IP:POORT]",
);
our %HELP_URL = (
    en => "Fetches the URL that the DJ submitted \2Syntax:\2 URL [IP:PORT]",
	#nl => "Haalt de URL die de DJ heeft gezet op \2Syntax:\2 URL [IP:POORT]",
);
our %HELP_AVERAGELISTENTIME = (
    en => "Fetches the average listen time of the listeners \2Syntax:\2 AVERAGELISTENTIME [IP:PORT]",
	#nl => "Haalt de gemiddelde luistertijd van luisteraars op \2Syntax:\2 AVERAGELISTENTIME [IP:IP:POORT]",
);
our %HELP_NEXT = (
    en => "Fetches the next song to be played. \2Syntax:\2 NEXT [IP:PORT]",
	#nl => "Haalt het volgende liedje op. \2Syntax:\2 NEXT [IP:POORT]",
);

sub on_connect {
    my ($svr) = @_;
    my $dbh = $Auto::DB->prepare('SELECT * FROM radio WHERE net = ?');
	$dbh->execute(lc $svr);
	my $data = $dbh->fetchall_hashref('chan');
	my $i=0;
	foreach my $key (keys %$data) {
        cjoin($svr, $key);
		$EchoChannels{$svr}{$i} = $key;
		$i++;
    }


	timer_add('ShoutCast',2,$radioecho,sub {
		while(($key,$value) = each(%EchoChannels)) {
			my @arr = ();
			while(($key2,$value2) = each(%{$EchoChannels{$key}})) {
				push(@arr,$value2);
			}
			my $chanvar = join(',',@arr);
			my $ua = Furl->new(
				agent => 'Mozilla/5.0',
				timeout => 5,
			);
			my $response = $ua->get($RadioURL);
			if ($response->is_success) {
				my $html_text = $response->content;
				if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
					if($html_text =~ /Server is currently up/) {
						if($html_text =~ /<tr><td valign="top"><font class="default">Current Song: <\/font><\/td><td><font class="default"><b><a href="currentsong\?sid=(.+?)">(.*)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Next Song: <\/font>/) {
							$song = $2;
						}
						if($html_text =~ /<tr><td valign="top"><font class="default">Next Song: <\/font><\/td><td><font class="default"><b><a href="nextsong\?sid=(.+?)">(.+?)<\/a><\/b><\/td><\/tr><\/table><\/font><\/body><\/html>/) {
							$nextsong = $2;
						}
						if(($song eq $oldsong) && ($nextsong eq $oldnextsong)) {
						} else {
							$oldsong = $song;
							$oldnextsong = $nextsong;
							privmsg($svr, $chanvar, "\2New song:\2 ".$song." \2Next song:\2 ".$nextsong);
						}
					} else {
						if($oldsong eq "NOTHING") {
						} else {
							$oldsong = "NOTHING";
							privmsg($svr, $chanvar, "There is currently no music playing on the radio.");
							return;
						}
					}
					return;
				} else {
					if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
					{
						if($oldsong eq "NOTHING") {
						} else {
							$oldsong = "NOTHING";
							privmsg($svr, $chanvar, "There is currently no music playing on the radio.");
							return;
						}
					} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
						if($html_text =~ /<tr><td width=100 nowrap><font class=default>Current Song: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><\/table>/) {
							$song = $1;
							if($song eq $oldsong) {
							} else {
								privmsg($svr, $chanvar, "New song: ".$song);
								$oldsong = $song;
							}
						}
					}
				}
			}
		}
	});
}

sub on_chanjoin {
	my ($svr, $chan) = @_;
	my $dbh = $Auto::DB->prepare('SELECT * FROM radio WHERE net = ?');
	$dbh->execute(lc $svr);
	my $data = $dbh->fetchall_hashref('chan');
	foreach my $key (keys %$data) {
        if($key eq $chan) {
			my $ua = Furl->new(
				agent => 'Mozilla/5.0',
				timeout => 5,
			);
			my $response = $ua->get($RadioURL);
			if ($response->is_success) {
				if(!defined($response)) {
					privmsg($svr, $chan, "An error occurred while retrieving the song. [1]");
					return;
				}
				my $html_text = $response->content;
				if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
					if($html_text =~ /Server is currently up/) {
						if($html_text =~ /<tr><td valign="top"><font class="default">Current Song: <\/font><\/td><td><font class="default"><b><a href="currentsong\?sid=(.+?)">(.*)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Next Song: <\/font>/) {
							
							$oldsong = $2;
							#return;	
						}
						if($html_text =~ /<tr><td valign="top"><font class="default">Next Song: <\/font><\/td><td><font class="default"><b><a href="nextsong\?sid=(.+?)">(.+?)<\/a><\/b><\/td><\/tr><\/table><\/font><\/body><\/html>/) {
							$oldnextsong = $2;
							#return 1;
						}
						privmsg($svr, $chan, "\2Current Song:\2 ".$oldsong." \2Next Song:\2 ".$oldnextsong);
					} else {
						privmsg($svr, $chan, "There is currently nothing playing on the radio");
						return;
					}
					return;
				} else {
					if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
					{
						privmsg($svr, $chan, "There is currently nothing playing on the radio");
						return;
					} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
						if($html_text =~ /<tr><td width=100 nowrap><font class=default>Current Song: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><\/table>/) {
							privmsg($svr, $chan, "Current Song: ".$1);
							$oldsong = $1;
						}
					}
				}
			} else {
				privmsg($svr, $chan, "An error occurred while retrieving the song. [2]");
				return;
			}
		}
    }
}

sub cmd_shoutcast {
	my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, 'SYNTAX: SHOUTCAST <ADD|DEL|LIST> [CHANNEL@NETWORK]');
        return;
	}
	if(defined($argv[2])) {
		privmsg($src->{svr}, $src->{chan}, 'SYNTAX: SHOUTCAST <ADD|DEL|LIST> [CHANNEL@NETWORK]');
        return;
	}
	if(uc($argv[0]) eq "ADD") {
		if(!defined($argv[1])) {
			privmsg($src->{svr}, $src->{chan}, "SYNTAX: SHOUTCAST ADD <CHANNEL@NETWORK>");
			return;
		}
		$channel = $src->{chan};
        if (defined $argv[1]) {
            if ($argv[1] =~ m/(#.*)\@(.*)/) {
                $channel = $1;
                $svr = lc($2);
            } else {
				$svr = lc($src->{svr});
                $channel = $argv[1];
            }
        }
		if (add($svr, $channel)) {
			privmsg($src->{svr}, $src->{chan}, "$channel\@$svr was added to my radio echo channel list.");
		} else {
            privmsg($src->{svr}, $src->{chan}, 'Failed to add to radio echo\'ing channels.');
        }
	}
	elsif(uc($argv[0]) eq "DEL") {
		if(!defined($argv[1])) {
			privmsg($src->{svr}, $src->{chan}, "SYNTAX: SHOUTCAST DEL <CHANNEL@NETWORK>");
			return;
		}
		
		$channel = $src->{chan};
        if (defined $argv[1]) {
            if ($argv[1] =~ m/(#.*)\@(.*)/) {
                $channel = $1;
                $svr = lc($2);
            } else {
                $channel = $argv[1];
            }
        }
		if (del($network, $channel)) {
			privmsg($src->{svr}, $src->{chan}, "$channel\@$svr was removed from my radio echo'ing channels list.");
		} else {
            privmsg($src->{svr}, $src->{chan}, 'Failed to delete from radio echo channel list.');
        }
	} elsif(uc($argv[0]) eq "LIST") { 
		my $svr = (defined $argv[1] ? lc($argv[1]) : lc($src->{svr}));
        my $chan = $src->{chan};
		
		my $dbh = $Auto::DB->prepare('SELECT chan FROM radio WHERE net = ?');
        $dbh->execute(lc $svr);
        my @data = $dbh->fetchall_arrayref;
        my @channels = ();
        foreach my $first (@data) {
            foreach my $second (@{$first}) {
                foreach my $channel (@{$second}) {
                    push @channels, $channel;
                }
            }
        }
		if(@channels) {
			privmsg($src->{svr}, $src->{chan}, join ', ', @channels);
		} else {
			privmsg($src->{svr}, $src->{chan}, "No channels configured for $svr");
		}
	} else {
		privmsg($src->{svr}, $target, 'No such command.');
	}
}

sub add {
    my ($net, $chan) = @_;
    my $dbq = $Auto::DB->prepare('INSERT INTO radio (net, chan) VALUES (?, ?)');
    return 1 if $dbq->execute(lc $net, lc $chan);
    return 0;
}
sub del {
    my ($net, $chan) = @_;
    my $dbq = $Auto::DB->prepare('DELETE FROM radio WHERE net = ? AND chan = ?');
    return 1 if $dbq->execute(lc $net, lc $chan);
    return 0;
}

sub cmd_song {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song. [1]");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Current Song: <\/font><\/td><td><font class="default"><b><a href="currentsong\?sid=(.+?)">(.*)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Next Song: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Current Song: ".$2);
						return;	
					} else {
						privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song.");
						return;	
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				}
				return;
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Current Song: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><\/table>/) {
						privmsg($src->{svr}, $src->{chan}, "Current Song: ".$1);
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song. [2]");
			return;
		}
		return;
	}
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song. [1]");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Current Song: <\/font><\/td><td><font class="default"><b><a href="currentsong\?sid=(.+?)">(.*)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Next Song: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Current Song: ".$2);
					return;	
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song.");
					return;	
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			}
			return;
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Current Song: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><\/table>/) {
					privmsg($src->{svr}, $src->{chan}, "Current Song: ".$1);
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the song. [2]");
		return;
	}
    return 1;
}

sub cmd_dj {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Stream Name: <\/font><\/td><td><font class="default"><b>(.*)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Content Type: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Current DJ: ".$1);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Title: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
						privmsg($src->{svr}, $src->{chan}, "Current DJ: ".$1);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Stream Name: <\/font><\/td><td><font class="default"><b>(.*)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Content Type: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Current DJ: ".$1);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
				return;
			}
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Title: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
					privmsg($src->{svr}, $src->{chan}, "Current DJ: ".$1);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the DJ.");
		return;
	}
    return 1;
}

sub cmd_genre {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Stream Genre: <\/font><\/td><td><font class="default"><b>(.*)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Stream URL: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Current Genre: ".$1);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Genre: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><tr><td width=100 nowrap><font class=default>Stream URL:/) {
						privmsg($src->{svr}, $src->{chan}, "Current Genre: ".$1);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Stream Genre: <\/font><\/td><td><font class="default"><b>(.*)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Stream URL: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Current Genre: ".$1);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
				return;
			}
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Genre: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr><tr><td width=100 nowrap><font class=default>Stream URL:/) {
					privmsg($src->{svr}, $src->{chan}, "Current Genre: ".$1);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the Genre.");
		return;
	}
    return 1;
}

sub cmd_listeners {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the listeners.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Stream Status: <\/font><\/td><td><font class="default"><b>Stream is up at (.+?) kbps with (.+?) of (.+?) listeners \((.+?) unique\)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Listener Peak: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Current amount of listeners: ".$2);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the amount of listeners.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Status: <\/font><\/td><td><font class=default><b>Stream is up at (.+?) kbps with <B>(.+?) of (.+?) listeners \((.+?) unique\)<\/b><\/b><\/td><\/tr>/) {
						privmsg($src->{svr}, $src->{chan}, "Current amount of listeners: ".$2);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the amount of listeners.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the listeners.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Stream Status: <\/font><\/td><td><font class="default"><b>Stream is up at (.+?) kbps with (.+?) of (.+?) listeners \((.+?) unique\)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Listener Peak: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Current amount of listeners: ".$2);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the amount of listeners.");
				return;
			}
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Status: <\/font><\/td><td><font class=default><b>Stream is up at (.+?) kbps with <B>(.+?) of (.+?) listeners \((.+?) unique\)<\/b><\/b><\/td><\/tr>/) {
					privmsg($src->{svr}, $src->{chan}, "Current amount of listeners: ".$2);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the amount of listeners.");
		return;
	}
    return 1;
}

sub cmd_listpeak {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Listener Peak: <\/font><\/td><td><font class="default"><b>(.+?)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Average Listen Time: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Peak amount of listeners: ".$1);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "AThere is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Listener Peak: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
						privmsg($src->{svr}, $src->{chan}, "Peak amount of listeners: ".$1);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Listener Peak: <\/font><\/td><td><font class="default"><b>(.+?)<\/b><\/td><\/tr><tr><td valign="top"><font class="default">Average Listen Time: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Peak amount of listeners: ".$1);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
				return;
			}
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "AThere is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Listener Peak: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
					privmsg($src->{svr}, $src->{chan}, "Peak amount of listeners: ".$1);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the peak amount of listeners.");
		return;
	}
    return 1;
}

sub cmd_url {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Stream URL: <\/font><\/td><td><font class="default"><b><a href="(.+?)">(.+?)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Current Song: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "URL: ".$2);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream URL: <\/font><\/td><td><font class=default><b><a href="(.+?)">(.+?)<\/a><\/b><\/td><\/tr>/) {
						privmsg($src->{svr}, $src->{chan}, "URL: ".$2);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Stream URL: <\/font><\/td><td><font class="default"><b><a href="(.+?)">(.+?)<\/a><\/b><\/td><\/tr><tr><td valign="top"><font class="default">Current Song: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "URL: ".$2);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
				return;
			}
		} elsif($html_text =~ /SHOUTcast Server Version 1.9/) {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream URL: <\/font><\/td><td><font class=default><b><a href="(.+?)">(.+?)<\/a><\/b><\/td><\/tr>/) {
					privmsg($src->{svr}, $src->{chan}, "URL: ".$2);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the URL.");
		return;
	}
    return 1;
}

sub cmd_averagelistentime {
    my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Average Listen Time: <\/font><\/td><td><font class="default"><b>(.+?) <\/b><\/td><\/tr><tr><td valign="top"><font class="default">Stream Name: <\/font>/) {
						privmsg($src->{svr}, $src->{chan}, "Average listen time: ".$1);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
					return;
				}
			} else {
				if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
				{
					privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
					return;
				} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
					if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Title: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
						privmsg($src->{svr}, $src->{chan}, "Average listen time: ".$1);
						return 1;
					}
				}
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Average Listen Time: <\/font><\/td><td><font class="default"><b>(.+?) <\/b><\/td><\/tr><tr><td valign="top"><font class="default">Stream Name: <\/font>/) {
					privmsg($src->{svr}, $src->{chan}, "Average listen time: ".$1);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
				return;
			}
		} else {
			if(($html_text =~ /<b>Server is currently down.<\/b>/i) || ($html_text =~ /<font class="st">Available Streams: 0<\/font>/))
			{
				privmsg($src->{svr}, $src->{chan}, "There is currently nothing playing on the radio");
				return;
			} elsif($html_text =~ /<b>Server is currently up and public.<\/b>/i) {
				if($html_text =~ /<tr><td width=100 nowrap><font class=default>Stream Title: <\/font><\/td><td><font class=default><b>(.+?)<\/b><\/td><\/tr>/) {
					privmsg($src->{svr}, $src->{chan}, "Average listen time: ".$1);
					return 1;
				}
			}
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the average listen time.");
		return;
	}
    return 1;
}

sub cmd_next {
	my ($src, @argv) = @_;
	if(defined($argv[0])) {
		my $ua = Furl->new(
			agent => 'Mozilla/5.0',
			timeout => 5,
		);
		my $url = 'http://'.$argv[0];
		my $response = $ua->get($url);
		if ($response->is_success) {
			if(!defined($response)) {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
				return;
			}
			my $html_text = $response->content;
			if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
				if($html_text =~ /Server is currently up/) {
					if($html_text =~ /<tr><td valign="top"><font class="default">Next Song: <\/font><\/td><td><font class="default"><b><a href="nextsong\?sid=(.+?)">(.+?)<\/a><\/b><\/td><\/tr><\/table><\/font><\/body><\/html>/) {
						privmsg($src->{svr}, $src->{chan}, "Next Song: ".$2);
						return 1;
					}
				} else {
					privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
					return;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "Shoutcast Server 1.9.* is not supported.");
				return 1;
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
			return;
		}
		return;
	}
	
	my $ua = Furl->new(
		agent => 'Mozilla/5.0',
		timeout => 5,
	);
	my $response = $ua->get($RadioURL);
	if ($response->is_success) {
		if(!defined($response)) {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
			return;
		}
		my $html_text = $response->content;
		if($html_text =~ /<a target="_blank" id="ltv" href="http:\/\/www.shoutcast.com\/">SHOUTcast Server v2\.0/) {
			if($html_text =~ /Server is currently up/) {
				if($html_text =~ /<tr><td valign="top"><font class="default">Next Song: <\/font><\/td><td><font class="default"><b><a href="nextsong\?sid=(.+?)">(.+?)<\/a><\/b><\/td><\/tr><\/table><\/font><\/body><\/html>/) {
					privmsg($src->{svr}, $src->{chan}, "Next Song: ".$2);
					return 1;
				}
			} else {
				privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
				return;
			}
		} else {
			privmsg($src->{svr}, $src->{chan}, "Shoutcast Server 1.9.* is not supported.");
			return 1;
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the next song.");
		return;
	}
    return 1;
}

# on_rehash subroutine.
sub on_rehash {
    # Reset $radiourl
	$radioecho = (conf_get('radioecho') ? (conf_get('radioecho'))[0][0] : "30");
	$RadioSvrVersion = (conf_get('SCversion') ? (conf_get('SCversion'))[0][0] : "2");
	$radiohost = (conf_get('radiourl') ? (conf_get('radiourl'))[0][0] : "");
	$radioport = (conf_get('radioport') ? (conf_get('radioport'))[0][0] : "");
	if($RadioSvrVersion == 2) {
		$radiosid = (conf_get('StreamID') ? (conf_get('StreamID'))[0][0] : "");
		if($radiohost =~ /http/) {
			$RadioURL = $radiohost.":".$radioport."/index.html?sid=".$radiosid;
		} else {
			$RadioURL = "http://".$radiohost.":".$radioport."/index.html?sid=".$radiosid;
		}
	} else {
		if($radiohost =~ /http/) {
			$RadioURL = $radiohost.":".$radioport;
		} else {
			$RadioURL = "http://".$radiohost.":".$radioport;
		}
	}
}

# Start initialization.
API::Std::mod_init('ShoutCast', '[NAS]peter', '1.04', '3.0.0a11');
# build: perl=5.010000 cpan=Furl

__END__

=head1 NAME

ShoutCast - IRC interface to ShoutCast Stream Information

=head1 VERSION

 1.04

=head1 SYNOPSIS

 <Peter> !song
 <StatsBot> Current Song: X-Mass In Hell

=head1 DESCRIPTION

This creates several ShoutCast specific commands, that allow you to fetch information from an internet radio station. This module is not reloadable when it's set to fetch radio details automatically, a restart is needed for that.

=head1 CONFIGURATION

Simply add the following to your configuration file:

 radioecho "<TIME>";
 
Where <TIME> is the amount of seconds between checking if a new song is being played. 30 is default. 0 means not doing it.

 radioecho 30;

 
 radiourl "<IP>";
 
Where <IP> is the IP of the internet radio station.

 radiourl "13.37.13.37";
 
 
 
 radioport <Port>;
 
Where <Port> is the port of the internet radio station.

 radioport 8000;

 
 
 SCversion <1/2>;
 
Where <1/2> is the version of ShoutCast on the station.

 SCversion 1;
 
 
 
 StreamID <ID>;
 
Where <ID> is the ID of the stream in the ShoutCast server

 StreamID 1;
 
=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

The HTTP agent used.

=back

=head1 AUTHOR

This module was written by [NAS]peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012 [NAS]peter.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4: