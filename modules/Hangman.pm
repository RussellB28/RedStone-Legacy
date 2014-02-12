# Module: Hangman. See below for documentation.
# Copyright (C) 2012-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Hangman;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get hook_add hook_del);
use API::IRC qw(privmsg notice);
use API::Log qw(dbug);

my $fantasyprefix;

my $hangman;
my @HangmanWords;
my %HangmanLetters;

my $word;
my $dots;
my $guesses;
my @GuessedLetters;
my @GuessedWords;

# Initialization subroutine.
sub _init {
	hook_add('on_rehash', 'HM.rehash', \&M::Hangman::on_rehash) or return;
	cmd_add('hangman', 0, 0, \%M::Hangman::HELP_HANGMAN, \&M::Hangman::cmd_hangman) or return;
	cmd_add('guess', 0, 0, \%M::Hangman::HELP_GUESS, \&M::Hangman::cmd_guess) or return;
	
	$hangman =0;
	
	@HangmanWords = split(/ /,(conf_get('hangman') ? (conf_get('hangman'))[0][0] : "pearl connected lynch successfully"));
	$fantasyprefix = conf_get('fantasy_pf') ? (conf_get('fantasy_pf'))[0][0] : "!";
	
	foreach my $w (@HangmanWords) {
		my $l = length($w);
		
		$HangmanLetters{$w}{'length'} = $l;
		
		for(my $i=0; $i<$l; $i++) {
			$HangmanLetters{$w}{$1} = substr($w,$i,1);
		}
	}
	
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	hook_del('on_rehash', 'HM.rehash') or return;
	cmd_del('hangman') or return;
	cmd_del('guess') or return;
	
    # Success.
    return 1;
}

our %HELP_HANGMAN = (
    en => "Will start/stop a hangman game. \2Syntax:\2 HANGMAN",
	#nl => "Start of stopt een galgje spel. \2Syntax:\2 HANGMAN",
);

our %HELP_GUESS = (
    en => "Will guess a letter/word for hangman \2Syntax:\2 HANGMAN <letter|word>",
	#nl => "Gokt een ingegeven woord of letter bij galgje. \2Syntax:\2 HANGMAN <letter|woord>",
);

sub cmd_hangman {
	my ($src, @argv) = @_;
	if(defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, 'Too many parameters.');
        return;
	}
	
	if($hangman == 0) {
		$guesses =0;
		$hangman =1;
		@GuessedLetters = ();
		@GuessedWords = ();
		privmsg($src->{svr}, $src->{chan}, "\2Starting\2 new \2hangman\2 game");
		$word = $HangmanWords[int(rand(scalar(@HangmanWords)))];
		dbug("$word");
		$dots = "";
		for(my $i=0;$i<$HangmanLetters{$word}{'length'};$i++) {
			$dots .= ".";
		}
		privmsg($src->{svr}, $src->{chan}, "Word to guess: ".$dots);
	} else {
		privmsg($src->{svr}, $src->{chan}, "Already started a \2hangman\2 game.");
	}
}

sub cmd_guess {
	my ($src, @argv) = @_;
	if($hangman == 0) {
		privmsg($src->{svr}, $src->{chan}, 'There is currently no game of hangman');
        return;
	}
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, 'Too little parameters.');
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, 'Too many parameters.');
        return;
	}
		
	if(length($argv[0]) == 1) {
		foreach my $letter (@GuessedLetters) {
			if(lc($letter) eq lc($argv[0])) {
				privmsg($src->{svr}, $src->{chan}, "You have already guessed this letter.");
				return;
			}
		}
		if(index($word,$argv[0]) < 0) {
			$guesses++;
			push(@GuessedLetters,$argv[0]);
			if($guesses == 1) {
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 2) {
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 3) {
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 4) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 5) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 6) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 7) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 8) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\ /");
				privmsg($src->{svr}, $src->{chan}, "-----");
			}  elsif($guesses == 9) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\ /\\ ");
				privmsg($src->{svr}, $src->{chan}, "-----");
				privmsg($src->{svr}, $src->{chan}, "Game over! \2$word\2 wasn't guessed");
				return;
			}
			privmsg($src->{svr}, $src->{chan}, "\2Used letters:\2 ".join(', ',@GuessedLetters));
		} else {
			for(my $i=0; $i<$HangmanLetters{$word}{'length'}; $i++) {
				if(substr($word,$i,1) eq $argv[0]) {
					$dots = substr($dots,0,$i) . $argv[0] . substr($dots,$i+1);
				}
			}
			if($dots !~ /\./) {
				privmsg($src->{svr}, $src->{chan}, "The word \2$word\2 has been guessed by ".$src->{nick}.". Type \2".$fantasyprefix."hangman\2 to start a new game.");
				$hangman =0;
				return;
			} else {
				privmsg($src->{svr}, $src->{chan}, "Current guessed: ".$dots);
				return;
			}
		}
	} else {
		foreach my $GWords (@GuessedWords) {
			if(lc($GWords) eq lc($argv[0])) {
				privmsg($src->{svr}, $src->{chan}, "You have already guessed this word.");
				return;
			}
		}
		if(lc($argv[0]) eq lc($word)) {
			privmsg($src->{svr}, $src->{chan}, "The word \2$word\2 has been guessed by ".$src->{nick}.". Type \2".$fantasyprefix."hangman\2 to start a new game.");
			$hangman =0;
			return;
		} else {
			$guesses++;
			push(@GuessedWords,$argv[0]);
			if($guesses == 1) {
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 2) {
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 3) {
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 4) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 5) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 6) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 7) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 8) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\ /");
				privmsg($src->{svr}, $src->{chan}, "-----");
			} elsif($guesses == 9) {
				privmsg($src->{svr}, $src->{chan}, "|----");
				privmsg($src->{svr}, $src->{chan}, "|   o");
				privmsg($src->{svr}, $src->{chan}, "|  -x-");
				privmsg($src->{svr}, $src->{chan}, "|\\ /\\ ");
				privmsg($src->{svr}, $src->{chan}, "-----");
				privmsg($src->{svr}, $src->{chan}, "Game over! \2$word\2 wasn't guessed");
				return;
			}
			privmsg($src->{svr}, $src->{chan}, "\2Used words:\2 ".join(', ',@GuessedWords));
		}
	}
}


# on_rehash subroutine.
sub on_rehash {
	@HangmanWords = split(/ /,(conf_get('hangman') ? (conf_get('hangman'))[0][0] : "pearl connected lynch successfully"));
	$fantasyprefix = conf_get('fantasy_pf') ? (conf_get('fantasy_pf'))[0][0] : "!";
}

# Start initialization.
API::Std::mod_init('Hangman', 'Peter', '1.00', '3.0.0a11');
# build: perl=5.010000 cpan=Furl

__END__

=head1 NAME

Hangman - IRC game Hangman

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <~Peter> ^hangman
 <TestBot> Starting new hangman game
 <TestBot> Word to guess: .........
 <~Peter> ^guess connected
 <TestBot> The word connected has been guessed by Peter. Type ^hangman to start a new game.
 <~Peter> ^hangman
 <TestBot> Starting new hangman game
 <TestBot> Word to guess: ............
 <~Peter> ^guess e
 <TestBot> Current guessed: ....e.......
 <~Peter> ^hangman
 <TestBot> Starting new hangman game
 <TestBot> Word to guess: ............
 <~Peter> ^guess e
 <TestBot> Current guessed: ....e.......
 <~Peter> ^guess ere
 <TestBot> -----
 <TestBot> Used words: ere
 <~Peter> ^guess ele
 <TestBot> |
 <TestBot> |
 <TestBot> |
 <TestBot> |
 <TestBot> -----
 <TestBot> Used words: ere, ele
 <~Peter> ^guess peal
 <TestBot> |
 <TestBot> |
 <TestBot> |
 <TestBot> |\
 <TestBot> -----
 <TestBot> Used words: ere, ele, peal
 <~Peter> ^guess derp
 <TestBot> |----
 <TestBot> |
 <TestBot> |
 <TestBot> |\
 <TestBot> -----
 <TestBot> Used words: ere, ele, peal, derp
 <~Peter> ^guess j
 <TestBot> |----
 <TestBot> |   o
 <TestBot> |
 <TestBot> |\
 <TestBot> -----
 <TestBot> Used letters: j
 <~Peter> ^guess l
 <TestBot> Current guessed: ....e....ll.
 <~Peter> ^guess i
 <TestBot> |----
 <TestBot> |   o
 <TestBot> |  -x
 <TestBot> |\
 <TestBot> -----
 <TestBot> Used letters: j, i
 <~Peter> ^guess DAMN
 <TestBot> |----
 <TestBot> |   o
 <TestBot> |  -x-
 <TestBot> |\
 <TestBot> -----
 <TestBot> Used words: ere, ele, peal, derp, DAMN
 <~Peter> ^guess FUUUUUU
 <TestBot> |----
 <TestBot> |   o
 <TestBot> |  -x-
 <TestBot> |\ /
 <TestBot> -----
 <TestBot> Used words: ere, ele, peal, derp, DAMN, FUUUUUU
 <~Peter> ^guess MEAN
 <TestBot> |----
 <TestBot> |   o
 <TestBot> |  -x-
 <TestBot> |\ /\ 
 <TestBot> -----
 <TestBot> Game over! successfully wasn't guessed
 

=head1 DESCRIPTION

This creates several ShoutCast specific commands, that allow you to fetch information from an internet radio station.

=head1 CONFIGURATION

You can add words for hangman to use yourself. Use the following directive:

 hangman "<word1> <word2>";
 
Where <word1> and <word2> are the words you want the module to use.

 hangman "auto rocks your automobile";
 
=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<NONE>

=back

=head1 AUTHOR

This module was written by Peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
