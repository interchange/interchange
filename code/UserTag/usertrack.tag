# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: usertrack.tag,v 1.4 2005-11-08 18:14:43 jon Exp $

UserTag usertrack Order   tag value
UserTag usertrack Version $Revision: 1.4 $
UserTag usertrack Routine sub { $Vend::Track->user(@_) if $Vend::Track; }
