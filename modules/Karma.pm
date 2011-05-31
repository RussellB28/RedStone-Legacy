# Module: Karma. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Karma;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(notice);

# Initialization subroutine.
sub _init {
    # Create the SCORE command.
