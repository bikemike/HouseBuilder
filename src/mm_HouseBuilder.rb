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

module MM_HouseBuilderExtensionLoader

# Extension Manager
@@mm_HouseBuilder_uStrings = LanguageHandler.new("House Builder")
@@mm_HouseBuilderExtension = SketchupExtension.new @@mm_HouseBuilder_uStrings.GetString("House Builder"), "mm_HouseBuilder/HouseBuilderTool"
@@mm_HouseBuilderExtension .description=@@mm_HouseBuilder_uStrings.GetString("A sketchup extension for creating wood framed buildings.")
@@mm_HouseBuilderExtension .name= "House Builder"
@@mm_HouseBuilderExtension .creator = "Steve Hurlbut"
@@mm_HouseBuilderExtension .copyright = "2014 Mike Morrison, 2005 Steve Hurlbut, D. Bur"
@@mm_HouseBuilderExtension .version = "1.3"
Sketchup.register_extension @@mm_HouseBuilderExtension , true

def self.getExtension()
	return @@mm_HouseBuilderExtension
end


end

file_loaded("mm_HouseBuilder.rb")
