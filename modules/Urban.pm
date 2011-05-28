# Module: Urban. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Urban;
use strict;
use warnings;
use Furl;
use HTML::Tree;
use URI::Escape;
use API::Std qw(cmd_add cmd_del);
use API::IRC qw(privmsg notice);

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

    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );

    # Grab the data from Urban Dictionary.
    my $res = $ua->get('http://www.urbandictionary.com/define.php?term='.uri_escape(join(q{ }, @argv)));
    
    if ($res->is_success) {
        # Success! Get the content.
        my $tree = HTML::Tree->new();
        $tree->parse($res->content);
        
        # Extract the first definition and example.
        my $def = $tree->look_down('_tag', 'div', 'class', 'definition');
        my $ex = $tree->look_down('_tag', 'div', 'class', 'example');

        # Return them, if they exist.
        if (defined $def) {
            privmsg($src->{svr}, $src->{chan}, "\2Definition:\2 ".$def->as_text);
            privmsg($src->{svr}, $src->{chan}, "\2Example:\2 ".((defined $ex) ? $ex->as_text : 'None.'));
        }
        else {
            privmsg($src->{svr}, $src->{chan}, "No results for \2".join(q{ }, @argv)."\2.");
        }
        $tree->delete;
    }
    else {
        # Aww, something went wrong.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while retrieving the definition.');
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Urban', 'Xelhua', '1.01', '3.0.0a11');
# build: perl=5.010000 cpan=Furl,HTML::Tree,URI::Escape

__END__

=head1 NAME

Urban - IRC interface to Urban Dictionary.

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <starcoder> !ud foobar
 <blue> Definition: A common term found in unix/linux/bsd program help pages as space fillers for a word. Or, can be used as a less intense or childish form of fubar.
 <blue> Example: To run the program, simply cd to the directory you installed it in like this: user@localhost cd foo/bar or The server foobared again?

=head1 DESCRIPTION

This creates the UD command which looks up the given term on
urbandictionary.com and returns the first definition+example.

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

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
