# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: usertrack.tag,v 1.3 2005-02-10 14:38:39 docelic Exp $

UserTag usertrack Order   tag value
UserTag usertrack Version $Revision: 1.3 $
UserTag usertrack Routine sub { $Vend::Track->user(@_) if $Vend::Track; }
