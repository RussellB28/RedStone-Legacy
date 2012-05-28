# Module: Spell. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Spell;
use strict;
use warnings;
use Furl;
use URI::Escape;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
	cmd_add('spell', 0, 0, \%M::Spell::HELP_SPELL, \&M::Spell::cmd_spell) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('spell') or return;
	
    # Success.
    return 1;
}

our %HELP_SPELL = (
    en => "Will check if the word in the parameter is spelled correctly, if not it will display a few suggestions. \2Syntax:\2 SPELL <WORD>",
	#nl => "Controleert of een engels woord goed gespeld is \2Syntax:\2 SPELL <WORD>",
);

sub cmd_spell {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too many parameters').q{.});
        return;
	}
	# Create an instance of Furl.
	my $ua = Furl->new(
		agent => 'Auto IRC Bot',
		timeout => 5,
	);
	my $url = 'http://www.phigita.net/spell-check/word-suggest?q='.uri_escape($argv[0]);
	my $response = $ua->get($url);
	if ($response->is_success) {
		my $content = $response->content;
		$content =~ s/\n//g;
		$content =~ s/(.*)<\/tr><\/table><\/form><\/div><div id="m" class="l"><ul class="compact"><li><a class="fl" href="http:\/\/www.phigita.net\/">Start<\/a><\/li>//;
		$content =~ s/<\/div><br><div id="o"><div id="p">Copyright (.*)//;
		if($content =~ /<b><font color="#990033">"(.+?)" is misspelled.<\/font>/) { #<\/b><p><\/p><b>Here are some suggestions:<\/b><div><ol>
			privmsg($src->{svr}, $src->{chan},"\2".$argv[0]."\2 is spelled \204incorrectly\2.");
			my @Results = ();
			if($content =~ /Here are some suggestions:/) {
				$content =~ s/<li><a href="http:\/\/www.google.com\/search\?ie=utf-8&amp;oe=utf-8&amp;q=define:(......)">//g;
				while($content =~ m/<li><a href="http:\/\/www.google.com\/search\?ie=utf-8&amp;oe=utf-8&amp;q=define:(.+?)">/) {
					my $var = $1;
					$content =~ s/<li><a href="http:\/\/www.google.com\/search\?ie=utf-8&amp;oe=utf-8&amp;q=define:$1">//;
					push(@Results, $var);
				}
				privmsg($src->{svr}, $src->{chan},"\2Suggestions:\2 ".join(', ',@Results).".");
				return;
			} else {
				privmsg($src->{svr}, $src->{chan},"There are \2no\2 suggestions for \2$argv[0]");
				return;
			}
		} elsif($content =~ /<b><font color="#006600">"(.+?)" is spelled correctly.<\/font><\/b><p><\/p><b>Here are some suggestions:<\/b><div><ol>/) {
			privmsg($src->{svr}, $src->{chan}," \2".$1."\2 is spelled \203correctly\2.");
		} else {
			privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the spelling.");
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the spelling.");
		return;
	}
}

# Start initialization.
API::Std::mod_init('Spell', '[NAS]peter', '1.00', '3.0.0a11');
# build: perl=5.010000 cpan=Furl

__END__

=head1 NAME

Spell - IRC interface to check the spelling of certain words

=head1 VERSION

 1.00
 
=head1 SYNOPSIS

 <~[nas]peter> ^spell sxy
 <&StatsBot> sxy is spelled incorrectly.
 <&StatsBot> Suggestions: sexy, Sky, sky, Say, Sly, say, sly, soy, spy, sty, Sax, sax, sex, six, shy.

=head1 DESCRIPTION

This creates several ShoutCast specific commands, that can check the spelling of a single word.

=head1 CONFIGURATION

No configurable options.

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