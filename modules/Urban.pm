# Module: Urban. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Urban;
use strict;
use warnings;
use Furl;
use HTML::Tree;
use URI::Escape;
use API::Std qw(cmd_add cmd_del conf_get trans);
use API::IRC qw(privmsg notice);
my $LASTUSE = 0;

# Initialization subroutine.
sub _init {
    # Create the UD command.
    cmd_add('UD', 0, 0, \%M::Urban::HELP_UD, \&M::Urban::cmd_ud) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the UD command.
    cmd_del('UD') or return;

    # Success.
    return 1;
}

# Help hash for UD.
our %HELP_UD = (
    en => "Look up a term on Urban Dictionary. \2Syntax:\2 UD <term>",
);

# Callback for UD command.
sub cmd_ud {
    my ($src, @argv) = @_;

    # One parameter required.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Ratelimit?
    if (conf_get('urban_ratelimit')) {
        if (time - $LASTUSE <= (conf_get('urban_ratelimit'))[0][0]) {
            notice($src->{svr}, $src->{nick}, 'This command has been used recently. Please wait a moment before using it again.');
            return;
        }
    }
    
    # Get the definition.
    my @def = grab(join(q{ }, @argv));
    
    if ($def[0] == -1) {
        # Needs to be reran with the ID.
        @def = grab(join(q{ }, @argv), $def[1]);
    }

    if ($def[0] == 2) {
        # No results.
        privmsg($src->{svr}, $src->{chan}, "No results for \2".join(q{ }, @argv)."\2.");
    }
    elsif ($def[0] == 0) {
        # Something went wrong...
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while retrieving the definition.');
    }
    else {
        # All good, return data.
        if (length $def[1] > 1536) { $def[1] = substr $def[1], 0, 1536; $def[1] .= '.....' }
        if (length $def[2] > 1536) { $def[2] = substr $def[2], 0, 1536; $def[2] .= '.....' }
        privmsg($src->{svr}, $src->{chan}, "\2Definition:\2 ".$def[1]);
        privmsg($src->{svr}, $src->{chan}, "\2Example:\2 ".$def[2]);
        $LASTUSE = time;
    }

    return 1;
}

# Grab a term from Urban Dictionary. (this is made separate for special occasions)
sub grab {
    my ($term, $id) = @_;

    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );

    # Grab the data from Urban Dictionary.
    my $url = 'http://www.urbandictionary.com/define.php?term='.uri_escape($term);
    if (defined $id) { $url .= "&defid=$id" }
    my $res = $ua->get($url);
    
    if ($res->is_success) {
        # Success! Get the content.
        my $tree = HTML::Tree->new();
        $tree->parse($res->content);
        
        # Extract the first definition and example.
        my $def = $tree->look_down('_tag', 'div', 'class', 'definition');
        my $ex = $tree->look_down('_tag', 'div', 'class', 'example');

        # Return them, if they exist.
        if (defined $def) {
            # Almost there, make sure we're getting the whole thing.
            if ($def->as_text =~ m/\.\.\.$/xsm) {
                my $id = $tree->look_down('_tag', 'td', 'id', qr/entry_[0-9]+/);
                $id = $id->attr('id');
                $id =~ s/[^0-9]//gxsm;
                
                my $href = $tree->look_down('_tag', 'a', 'href', qr/\/define\.php\?term=(.+)&defid=$id/);
                if (defined $href) {
                    $tree->delete;
                    return (-1, $id);
                }
            }

            my $dtxt = $def->as_text;
            my $dex = 'None';
            if (defined $ex) { $dex = $ex->as_text }
            $tree->delete;
            return (1, $dtxt, $dex);
        }
        else {
            # No results.
            $tree->delete;
            return (2);
        }
        $tree->delete;
    }
    else {
        # An error occurred.
        return (0);
    }

    return (0);
}

# Start initialization.
API::Std::mod_init('Urban', 'Xelhua', '1.03', '3.0.0a11');
# build: perl=5.010000 cpan=Furl,HTML::Tree,URI::Escape

__END__

=head1 NAME

Urban - IRC interface to Urban Dictionary.

=head1 VERSION

 1.03

=head1 SYNOPSIS

 <starcoder> !ud foobar
 <blue> Definition: A common term found in unix/linux/bsd program help pages as space fillers for a word. Or, can be used as a less intense or childish form of fubar.
 <blue> Example: To run the program, simply cd to the directory you installed it in like this: user@localhost cd foo/bar or The server foobared again?

=head1 DESCRIPTION

This creates the UD command which looks up the given term on
urbandictionary.com and returns the first definition+example.

=head1 CONFIGURATION

Simply add the following to your configuration file:

 urban_ratelimit <time in seconds>;

Where <time in seconds> is how often the UD command may be used. Like so:

 urban_ratelimit 3;

Not including this will make it use no ratelimit. (discouraged, unless you use
a good value for the bot-wide ratelimit)

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

The HTTP agent used.

=item L<URI::Escape>

The tool used to encode unsafe URL characters.

=item L<HTML::Tree>

The tool used to parse the data returned by Urban Dictionary.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
