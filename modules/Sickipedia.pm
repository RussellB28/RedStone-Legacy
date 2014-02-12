# Module: Sickipedia. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Sickipedia;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get err trans cmd_add cmd_del hook_add hook_del timer_add timer_del);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);
use XML::Simple;
use Furl;
use LWP::Simple;
use HTML::Entities;
use TryCatch;

# Initialization subroutine.
sub _init {
    cmd_add('SP', 0, 0, \%M::Sickipedia::HELP_SP, \&M::Sickipedia::cmd_sp) or return;
    return 1;
}

# Void subroutine.
sub _void {
    cmd_del('SP') or return;
    return 1;
}

our %HELP_SP = (
    en => "This command controls the Sickipedia module. \2Syntax:\2 SP <RAND/STATS/VIEW>",
);

# Callback for the SP command.
sub cmd_sp {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    my %data = (
                'nick' => $src->{nick},
                'user' => $src->{user},
                'host' => $src->{host}
               );

    given(uc $argv[0]) {
             when ('RAND') {
                try
                {
                    my $xml = new XML::Simple;
                    my $xml_url = "http://www.sickipedia.org/xml/getjokes/random/index.xml";


        		my $agent = LWP::UserAgent->new();
        		$agent->agent('RedStone IRC Bot');

        		$agent->timeout(60);

        		my $request = HTTP::Request->new(GET => $xml_url);
        		my $result = $agent->request($request);

			if(!$result->content)
			{
				privmsg($src->{svr}, $src->{chan}, "The Quote from Sickipedia could not be retrieved at this time. Please try again later.");
			}

        		my $data = $xml->XMLin($result->content);


                            my $content = $data->{'joke'}->{'content'};
                            my $author = $data->{'joke'}->{'author'};
                            my $timestamp = $data->{'joke'}->{'timestamp'};
				my $mcat = $data->{'joke'}->{'categories'}->{'category'}->{'name'};
				my $scat = $data->{'joke'}->{'categories'}->{'category'}->{'subcategory'}->{'name'};

				#$content =~ s/<br \/>/ /g;
				$content =~ s/\r\n//g;
				$content =~ s/\n//g;
				$content =~ s/\r//g;
				$content = substr($content, 7, length($content));

				my @lines = split(/<br \/>/, $content);

 				foreach (@lines) {

                            my $t_content = decode_entities($_);


                            privmsg($src->{svr}, $src->{chan}, "$t_content");

				}

				my $output;
				my $timevariable;
				$timevariable = "date -d @".$timestamp;
				$output = `$timevariable`;
				$output =~ s/\n//g;

                            privmsg($src->{svr}, $src->{chan}, "Submitted by \002".$author."\002 under \002".$mcat." > ".$scat."\002 on \002".$output."\002");
                }
                catch
                {
                        privmsg($src->{svr}, $src->{chan}, "The Quote from Sickipedia could not be retrieved at this time. Please try again later.");

                }
            return;
        }
        when ('VIEW') {
                try
                {

            		if (!defined $argv[1]) {
                		notice($src->{svr}, $src->{nick}, trans('Not enough parameters. Syntax: view [joke id]').q{.});
                		return;
            		}

                    my $xml = new XML::Simple;
                    my $xml_url = "http://www.sickipedia.org/xml/joke/view/".$argv[1]."";


        		my $agent = LWP::UserAgent->new();
        		$agent->agent('RedStone IRC Bot');

        		$agent->timeout(60);

        		my $request = HTTP::Request->new(GET => $xml_url);
        		my $result = $agent->request($request);

			if(!$result->content)
			{
				privmsg($src->{svr}, $src->{chan}, "The Quote from Sickipedia could not be retrieved at this time. Please try again later.");
				return;
			}

        		my $data = $xml->XMLin($result->content);


                            my $content = $data->{'content'};
                            my $author = $data->{'author'};
                            my $timestamp = $data->{'timestamp'};
				my $mcat = $data->{'categories'}->{'category'}->{'name'};
				my $scat = $data->{'categories'}->{'category'}->{'subcategory'}->{'name'};

				#$content =~ s/<br \/>/ /g;
				$content =~ s/\r\n//g;
				$content =~ s/\n//g;
				$content =~ s/\r//g;
				$content = substr($content, 5, length($content));

				my @lines = split(/<br \/>/, $content);

 				foreach (@lines) {

                            my $t_content = decode_entities($_);


                            privmsg($src->{svr}, $src->{chan}, "$t_content");

				}

				my $output;
				my $timevariable;
				$timevariable = "date -d @".$timestamp;
				$output = `$timevariable`;
				$output =~ s/\n//g;

                            privmsg($src->{svr}, $src->{chan}, "Submitted by \002".$author."\002 under \002".$mcat." > ".$scat."\002 on \002".$output."\002");
                }
                catch
                {
                        privmsg($src->{svr}, $src->{chan}, "The Quote from Sickipedia could not be retrieved at this time. Please try again later.");
			   return;

                }
            return;
        }
        when ('STATS') {
                try
                {
            		if (!defined $argv[3]) {
                		notice($src->{svr}, $src->{nick}, trans('Not enough parameters. Syntax: rand [day(DD)] [month(MM)] [year(YYYY)]').q{.});
                		return;
            		}

			my $day = $argv[1];
			my $month = $argv[2];
			my $year = $argv[3];


			if($year < 2008 || $year > 2012)
			{
                		notice($src->{svr}, $src->{nick}, trans('Invalid Year').q{.});
                		return;
			}
			if($month < 1 || $month > 12)
			{
                		notice($src->{svr}, $src->{nick}, trans('Invalid Month').q{.});
                		return;
			}
			if($day < 1 || $day > 31)
			{
                		notice($src->{svr}, $src->{nick}, trans('Invalid Day').q{.});
                		return;
			}

                    my $xml = new XML::Simple;
                    my $xml_url = "http://www.sickipedia.org/xml/getjokes/?stats=".$year."".$month."".$day."";


        		my $agent = LWP::UserAgent->new();
        		$agent->agent('RedStone IRC Bot');

        		$agent->timeout(60);

        		my $request = HTTP::Request->new(GET => $xml_url);
        		my $result = $agent->request($request);

			if(!$result->content)
			{
				privmsg($src->{svr}, $src->{chan}, "Statistics for the Date Specified could not be retrieved.");
			}

        		my $data = $xml->XMLin($result->content);


                            my $jsub = $data->{'stat'}->{'jokesSubmitted'}->{'value'};
                            my $jsur = $data->{'stat'}->{'jokesSurvived'}->{'value'};
				my $srate = $data->{'stat'}->{'survivalRate'}->{'value'};
				my $tjscore = $data->{'stat'}->{'topJokeScore'}->{'value'};
				my $ajscore = $data->{'stat'}->{'avgJokeScore'}->{'value'};


                            privmsg($src->{svr}, $src->{chan}, "Statistics for \002".$day."/".$month."/".$year."\002");
                            privmsg($src->{svr}, $src->{chan}, "Jokes Submitted: \002".$jsub."\002 :: Jokes Survived: \002".$jsur."\002 :: Survival Rate: \002".$srate."\002 :: Top Joke Score: \002".$tjscore."\002 :: Average Score: \002".$ajscore."\002");
                }
                catch
                {
                        privmsg($src->{svr}, $src->{chan}, "Statistics for the Date Specified could not be retrieved.");

                }
            return;
        }
    }

   return 1;
}

# Start initialization.
API::Std::mod_init('Sickipedia', 'Russell M Bradford', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Sickipedia

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <user> !sp rand
 <auto> I've always believed that the most important thing in life is family...
 <auto> that's why I'm creating as many as I can with different girls.      
 <auto> Submitted by Unassigned under Sex and shit > ??? General on Sun Dec 21 13:34:30 GMT 2008

 <user> !sp stats 02 12 2012
 <auto> Statistics for 02/12/2012
 <auto> Jokes Submitted: 452 :: Jokes Survived: 294 :: Survival Rate: 65% :: Top Joke Score: 206.6 :: Average Score: 4.04


=head1 DESCRIPTION

This module outputs the random jokes and statistical information from Sickipedia (http://www.sickipedia.org/).

=head1 CONFIGURATION

No Configuration is required for this module.


=head1 AUTHOR

This module was written by Russell Bradford.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:

