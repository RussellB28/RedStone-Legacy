# Module: YouTube. See below for documentation.
# Copyright (C) 2012-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::YouTube;
use strict;
use warnings;
use URI::Escape;
use API::Std qw(cmd_add cmd_del trans hook_add hook_del conf_get);
use API::IRC qw(privmsg);
my $IRCRelay;


# Initialization subroutine.
sub _init {
	cmd_add('youtube', 0, 0, \%M::YouTube::HELP_YOUTUBE, \&M::YouTube::cmd_spell) or return;
	hook_add('on_rehash', 'YT.rehash', \&M::YouTube::on_rehash) or return;
	hook_add('on_cprivmsg', 'YT.privmsg', \&M::YouTube::on_privmsg) or return;
	
	$IRCRelay = (conf_get('youtube-echo') ? (conf_get('youtube-echo'))[0][0] : "0");
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('youtube') or return;
	
	hook_del('on_rehash', 'YT.rehash') or return;
	hook_del('on_cprivmsg', 'YT.privmsg') or return;
    # Success.
    return 1;
}

our %HELP_YOUTUBE = (
    en => "Searches YouTube videos. \2SYNTAX:\2 YOUTUBE [TEXT TO SEARCH]",
	#nl => "Zoekt naar YouTube videos. \2SYNTAX:\2 YOUTUBE [TEXT TO SEARCH]",
);

sub cmd_spell {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{target}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{target}, trans('Too many parameters').q{.});
        return;
	}
	my $msg = join(' ',@argv);
	my $url = 'http://www.youtube.com/results?search_query='.uri_escape($msg);
	$Auto::http->request(
		url => $url,
		on_response => sub {
			my $response = shift;
            if (!$response->is_success) {
                privmsg($src->{svr}, $src->{target}, "An error occurred while retrieving the search from YouTube.");
                return;
            }
			my $content = $response->content;
			my ($lol1,$lol2);
			$content =~ s/    //g;
			$content =~ s/  //g;
			
			$content =~ s/(.*)<\/div><div class="result-item-main-content"><h3 dir="ltr"><a href="\/redirect\?q=(.+?)" title="" class="yt-uix-tile-link">//;
			$content =~ s/<\/span><\/p><p class="facets"><span class="ads-by" dir="ltr">(.+?) <a href="\/user\/(.+?)">(.+?)<\/a><\/span>(.*)//;
			$content =~ s/<\/a><\/h3><p class="search-ad-description"><span dir="ltr">/------/;
			
			if($content =~ /(.*)------(.*)/) {
				my $lol1 = $1;
				my $lol2 = $2;
				privmsg($src->{svr},$src->{target},"\x0307\2Title\2: ".$lol1."\x0305 \2Description\2: ".$lol2."");
			}
		},
		on_error => sub {
            my $error = shift;
            privmsg($src->{svr}, $src->{target}, "An error occurred while retrieving the search from YouTube.");
        }
	);
}

sub on_rehash {
	$IRCRelay = (conf_get('youtube-echo') ? (conf_get('youtube-echo'))[0][0] : "0");
}

sub on_privmsg {
	my ($src, $chan, @msg) = @_;
	my $text = join(' ',@msg);
	if($text =~ m,youtube.com/watch\?v=(.*),i) {
		if($IRCRelay == 0) {
			return;
		}
		my $url = "http://www.youtube.com/watch?v=".$1;
		$Auto::http->request(
			url => $url,
			on_response => sub {
				my $response = shift;
				if (!$response->is_success) {
					privmsg($src->{svr}, $chan, "An error occurred while retrieving the search from YouTube.");
					return;
				}
				my $var = $response->content;
				my ($Title,$YoutubeLikes,$YoutubeDislikes,$YoutubeUser,$YoutubeLength,$minutes,$seconds);
				if($var =~ m{<TITLE.*?>(.*?)</TITLE>}is) {
					$Title = $1;
					$Title =~ s/        //;
					$Title =~ s/     //;
					$Title =~ s/  //;
					$Title =~ s/\n//g;
					$Title =~ s/ - YouTube//;
				}
				if($var =~ /<span class="likes">(.+?)<\/span>/) {
					$YoutubeLikes = $1;
				}
				if($var =~ /<span class="dislikes">(.+?)<\/span>/) {
					$YoutubeDislikes = $1;
				}
				#if($var =~ /<a href="\/user\/(.+?)" class="yt-user-name author" rel="author"  dir="ltr">/) {
				if($var =~ /<a href="\/user\/(.+\w)" class="yt-user-name author" rel="author" dir="ltr">(.+\w)<\/a>/) {
					$YoutubeUser = $1;
				}
				if($var =~ /"length_seconds": (.+?),/) {
					$YoutubeLength = $1;
					$minutes = int(eval($YoutubeLength/60));
					$seconds = eval($YoutubeLength-($minutes * 60));
					if(length($seconds) == 1) {
						$YoutubeLength = $minutes.":0".$seconds;
					} else {
						$YoutubeLength = $minutes.":".$seconds;
					}
				}
				
				privmsg($src->{svr},$chan,"\x0306Title: ".$Title." - \x0302Likes: ".$YoutubeLikes." - \x0304Dislikes: ".$YoutubeDislikes." - \x0311Author: ".$YoutubeUser." - \x0309Length: ".$YoutubeLength);
			},
			on_error => sub {
				my $error = shift;
				privmsg($src->{svr}, $chan, "An error occurred while retrieving the search from YouTube.");
			}
		);
	}
}

# Start initialization.
API::Std::mod_init('YouTube', 'Peter', '1.01', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

YouTube - Will search for YouTube videos.

=head1 VERSION

 1.01
 
=head1 SYNOPSIS

 <@Peter> &youtube test
 <+Melon> Title: Zen Magnets require more - intellect than you might think. Description: Certainly harder than in this video
 <@Peter> http://www.youtube.com/watch?v=wOv0AkphLhE
 <+Melon> Title: Never Let Go of Childhood Wonder. - Likes: 7,757 - Dislikes: 205 - Author: ZenMagnet - Length: 4:31
 
=head1 DESCRIPTION

This will search YouTube videos. When something is defined, it can fetch some data of a video.

=head1 CONFIGURATION

 youtube-echo <1/0>;
 
 1 equals echo data of links, 0 equals don't.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=back

=head1 AUTHOR

This module was written by Peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012-2014 RedStone Development Group

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
