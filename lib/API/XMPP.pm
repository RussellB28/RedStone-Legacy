# lib/API/XMPP.pm - XMPP API subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::XMPP;
use strict;
use warnings;
use feature qw(switch);
use Exporter;
use base qw(Exporter);


# work out these later
our @EXPORT_OK = qw(act ban cjoin cpart cmode umode kick privmsg notice quit nick names
                    topic who whois usrc match_mask ison);


1;
# vim: set ai et sw=4 ts=4:

