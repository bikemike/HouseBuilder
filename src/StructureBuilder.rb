# Copyright (C) 2022 Kent Kruckeberg
# See LICENSE file for details.

# Copyright 2014 Mike Morrison
# Copyright 2005 Steve Hurlbut

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

require 'extensions.rb'
require 'langhandler.rb'

module StructureBuilderExtensionLoader

# Extension Manager
@@StructureBuilder_uStrings = LanguageHandler.new("Structure Builder")
@@StructureBuilderExtension = SketchupExtension.new @@StructureBuilder_uStrings.GetString("Structure Builder"), "StructureBuilder/StructureBuilderTool"
@@StructureBuilderExtension .description=@@StructureBuilder_uStrings.GetString("A sketchup extension for creating wood framed buildings.")
@@StructureBuilderExtension .name= "Structure Builder"
@@StructureBuilderExtension .creator = "Steve Hurlbut"
@@StructureBuilderExtension .copyright = "2022 Kent Kruckeberg, 2014 Mike Morrison, 2005 Steve Hurlbut, D. Bur"
@@StructureBuilderExtension .version = "1.0"
Sketchup.register_extension @@StructureBuilderExtension , true

def self.getExtension()
	return @@StructureBuilderExtension
end


end

file_loaded("StructureBuilder.rb")
