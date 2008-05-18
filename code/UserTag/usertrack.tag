# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: usertrack.tag,v 1.5 2007-03-30 23:40:57 pajamian Exp $

UserTag usertrack Order   tag value
UserTag usertrack Version $Revision: 1.5 $
UserTag usertrack Routine sub { $Vend::Track->user(@_) if $Vend::Track; }
