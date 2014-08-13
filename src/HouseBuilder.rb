# Copyright (C) 2014 Mike Morrison
# See LICENSE file for details.

# Copyright 2005 Steve Hurlbut

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

require 'extensions.rb'
require 'langhandler.rb'

# Extension Manager
$uStrings = LanguageHandler.new("House Builder")
HouseBuilder_extension= SketchupExtension.new $uStrings.GetString("House Builder"), "HouseBuilder/HouseBuilderTool.rb"
HouseBuilder_extension.description=$uStrings.GetString("A sketchup extension for creating wood framed buildings.")
HouseBuilder_extension.name= "House Builder"
HouseBuilder_extension.creator = "Steve Hurlbut"
HouseBuilder_extension.copyright = "2014 Mike Morrison, 2005 Steve Hurlbut, D. Bur"
HouseBuilder_extension.version = "1.3"
Sketchup.register_extension HouseBuilder_extension, true


file_loaded("HouseBuilder.rb")
