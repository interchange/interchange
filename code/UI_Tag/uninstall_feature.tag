# Copyright 2005-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: uninstall_feature.tag,v 1.3 2007-03-30 23:40:54 pajamian Exp $

UserTag uninstall_feature Order       name
UserTag uninstall_feature MapRoutine  Vend::Config::uninstall_feature
UserTag uninstall_feature Version     $Revision: 1.3 $
UserTag uninstall_feature Description <<EOD
This tag uninstalls features which were installed with Feature.
EOD
