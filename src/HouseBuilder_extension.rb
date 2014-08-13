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
require 'LangHandler.rb'

# Extension Manager
$uStrings = LanguageHandler.new("House Builder")
House_Builder_Extension = SketchupExtension.new $uStrings.GetString("House Builder"), "HouseBuilder/HouseBuilderTool.rb"
House_Builder_Extension.description=$uStrings.GetString("A sketchup extension for creating wood framed buildings.")
House_Builder_Extension.name= "House Builder"
House_Builder_Extension.creator = "Steve Hurlbut"
House_Builder_Extension.copyright = "2014 Mike Morrison, 2005 Steve Hurlbut, D. Bur"
House_Builder_Extension.version = "1.3"
Sketchup.register_extension House_Builder_Extension, true


#-----------------------------------------------------------------------------------------------------
#                                        MENU ITEMS
#-----------------------------------------------------------------------------------------------------

if( not $HouseBuilder_menu_loaded )

	#House builder toolbar
	#-----------------------------------------------------------------------------------------
	hb_tb = UI::Toolbar.new("House builder")

	# Global settings
	cmd = UI::Command.new(("Global settings")) {
		display_global_options_dialog
	}
	cmd.small_icon = "HouseBuilder/hb_globalsettings_S.png"
	cmd.large_icon = "HouseBuilder/hb_globalsettings_L.png"
	cmd.tooltip = "Change global settings"
	hb_tb.add_item(cmd)

	hb_tb.add_separator()

	# Floor tool
	cmd = UI::Command.new(("Floor tool")) { 
		Sketchup.active_model.select_tool HouseBuilder::FloorTool.new
	}
	cmd.small_icon = "HouseBuilder/hb_floortool_S.png"
	cmd.large_icon = "HouseBuilder/hb_floortool_L.png"
	cmd.tooltip = "Creates a floor."
	hb_tb.add_item(cmd)

	# Wall tool
	cmd = UI::Command.new(("Wall tool")) {
		Sketchup.active_model.select_tool HouseBuilder::WallTool.new
	}
	cmd.small_icon = "HouseBuilder/hb_walltool_S.png"
	cmd.large_icon = "HouseBuilder/hb_walltool_L.png"
	cmd.tooltip = "Creates a wall."
	hb_tb.add_item(cmd)

	# Gable Wall tool
	cmd = UI::Command.new(("Gable Wall tool")) {
		Sketchup.active_model.select_tool HouseBuilder::GableWallTool.new
	}
	cmd.small_icon = "HouseBuilder/hb_gablewalltool_S.png"
	cmd.large_icon = "HouseBuilder/hb_gablewalltool_L.png"
	cmd.tooltip = "Creates a gable wall."
	hb_tb.add_item(cmd)

	# Roof tool
	cmd = UI::Command.new(("Roof tool")) {
		Sketchup.active_model.select_tool HouseBuilder::RoofTool.new
	}
	cmd.small_icon = "HouseBuilder/hb_rooftool_S.png"
	cmd.large_icon = "HouseBuilder/hb_rooftool_L.png"
	cmd.tooltip = "Creates a roof."
	hb_tb.add_item(cmd)

	hb_tb.add_separator()

	# Change Wall properties
	cmd = UI::Command.new(("Edit Wall")) {
		if (check_for_wall_selection)
			HouseBuilder::EditWallTool.show_prop_dialog 
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_changewallproperties_S.png"
	cmd.large_icon = "HouseBuilder/hb_changewallproperties_L.png"
	cmd.tooltip = "Change Wall properties."
	hb_tb.add_item(cmd)

	# Move Wall
	cmd = UI::Command.new(("Move Wall")) {
		if (check_for_wall_selection)
			HouseBuilder::EditWallTool.move
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_movewall_S.png"
	cmd.large_icon = "HouseBuilder/hb_movewall_L.png"
	cmd.tooltip = "Move, rotate or extent Wall."
	hb_tb.add_item(cmd)

	hb_tb.add_separator()


	# Insert window
	cmd = UI::Command.new(("Insert window")) {
		if wall = (check_for_wall_selection)
			windowtool = HouseBuilder::WindowTool.new(wall)
			if windowtool.show_dialog()
				Sketchup.active_model.select_tool windowtool
			end
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_addwindow_S.png"
	cmd.large_icon = "HouseBuilder/hb_addwindow_L.png"
	cmd.tooltip = "Insert a window into a wall"
	hb_tb.add_item(cmd)

	# Change window properties
	cmd = UI::Command.new(("Change window properties in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "CHANGE_PROPERTIES")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_changewindowproperties_S.png"
	cmd.large_icon = "HouseBuilder/hb_changewindowproperties_L.png"
	cmd.tooltip = "Change window properties in a wall"
	hb_tb.add_item(cmd)

	# Move window
	cmd = UI::Command.new(("Move window in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "MOVE")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_movewindow_S.png"
	cmd.large_icon = "HouseBuilder/hb_movewindow_L.png"
	cmd.tooltip = "Move window in a wall"
	hb_tb.add_item(cmd)

	# Delete window
	cmd = UI::Command.new(("Delete window in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "DELETE")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_deletewindow_S.png"
	cmd.large_icon = "HouseBuilder/hb_deletewindow_L.png"
	cmd.tooltip = "Delete window in a wall"
	hb_tb.add_item(cmd)

	hb_tb.add_separator()

	# Insert door
	cmd = UI::Command.new(("Insert door")) {
		if wall = (check_for_wall_selection)
			doortool = HouseBuilder::DoorTool.new(wall)
			if doortool.show_dialog()
				Sketchup.active_model.select_tool doortool
			end
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_adddoor_S.png"
	cmd.large_icon = "HouseBuilder/hb_adddoor_L.png"
	cmd.tooltip = "Insert a door into a wall"
	hb_tb.add_item(cmd)

	# Change door properties
	cmd = UI::Command.new(("Change door properties in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "CHANGE_PROPERTIES")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	} 
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_changedoorproperties_S.png"
	cmd.large_icon = "HouseBuilder/hb_changedoorproperties_L.png"
	cmd.tooltip = "Change door properties in a wall"
	hb_tb.add_item(cmd)

	# Move door
	cmd = UI::Command.new(("Move door in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "MOVE")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_movedoor_S.png"
	cmd.large_icon = "HouseBuilder/hb_movedoor_L.png"
	cmd.tooltip = "Move door in a wall"
	hb_tb.add_item(cmd)

	# Move door
	cmd = UI::Command.new(("Delete door in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "DELETE")
		else
			UI.messagebox "No selection or selection isn't a wall."
		end
	}
	cmd.set_validation_proc {
		if (check_for_wall_selection)
			MF_ENABLED
		else
			MF_GRAYED
		end
	}
	cmd.small_icon = "HouseBuilder/hb_deletedoor_S.png"
	cmd.large_icon = "HouseBuilder/hb_deletedoor_L.png"
	cmd.tooltip = "Delete door in a wall"
	hb_tb.add_item(cmd)

	hb_tb.add_separator()

	# Tag
	cmd = UI::Command.new(("Tag HB objects")) {
		hb_tag_objects
	}
	cmd.small_icon = "HouseBuilder/hb_tag_S.png"
	cmd.large_icon = "HouseBuilder/hb_tag_L.png"
	cmd.tooltip = "Tag all HouseBuilder objects"
	hb_tb.add_item(cmd)

	# Estimates
	cmd = UI::Command.new(("Estimates")) {
		hb_estimate
	}
	cmd.small_icon = "HouseBuilder/hb_estimate_S.png"
	cmd.large_icon = "HouseBuilder/hb_estimate_L.png"
	cmd.tooltip = "Estimates"
	hb_tb.add_item(cmd)

	hb_tb.add_separator()

	# Credits
	cmd = UI::Command.new(("About...")) {(hb_credits)}
	cmd.small_icon = "HouseBuilder/hb_credits_S.png"
	cmd.large_icon = "HouseBuilder/hb_credits_L.png"
	cmd.tooltip = "Credits"
	hb_tb.add_item(cmd)


	# End of load
	$HouseBuilder_menu_loaded = true

end
(exec_on_autoload)
file_loaded("HouseBuilder_extension.rb")
