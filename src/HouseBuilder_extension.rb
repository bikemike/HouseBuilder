require 'extensions.rb'
require 'LangHandler.rb'

# Extension Manager
$uStrings = LanguageHandler.new("House Builder")
House_Builder_Extension = SketchupExtension.new $uStrings.GetString("House Builder"), "HouseBuilder/HouseBuilderTool.rb"
House_Builder_Extension.description=$uStrings.GetString("Wood frame tools set.")
House_Builder_Extension.name= "House Builder"
House_Builder_Extension.creator = "Steve Hurlbut"
House_Builder_Extension.copyright = "2005, Steve Hurlbut"
House_Builder_Extension.version = "1.0"

Sketchup.register_extension House_Builder_Extension, true

# Run
def exec_on_autoload
  puts("House Builder loaded.")
end

def hb_credits
UI.messagebox("Main program: Steve Hurlbut\nToolbar and metric version: D. Bur", MB_MULTILINE, "Credits")
end

def check_for_wall_selection
wall = HouseBuilder::EditWallTool.get_selected_wall
return wall
end
#-----------------------------------------------------------------------------------------------------
#                                        MENU ITEMS
#-----------------------------------------------------------------------------------------------------

if( not $HouseBuilder_menu_loaded )

  #House builder toolbar
  #-----------------------------------------------------------------------------------------
  hb_tb = UI::Toolbar.new("House builder")

# Global settings
  cmd5 = UI::Command.new(("Global settings")) { display_global_options_dialog }
  cmd5.small_icon = "HouseBuilder/hb_globalsettings_S.png"
  cmd5.large_icon = "HouseBuilder/hb_globalsettings_L.png"
  cmd5.tooltip = "Change global settings"
  hb_tb.add_item(cmd5)
  
  # Floor tool
  cmd3 = UI::Command.new(("Wall tool")) { Sketchup.active_model.select_tool HouseBuilder::FloorTool.new }
  cmd3.small_icon = "HouseBuilder/hb_floortool_S.png"
  cmd3.large_icon = "HouseBuilder/hb_floortool_L.png"
  cmd3.tooltip = "Creates a floor."
  hb_tb.add_item(cmd3)
  
  # Wall tool
  cmd1 = UI::Command.new(("Wall tool")) { Sketchup.active_model.select_tool HouseBuilder::WallTool.new }
  cmd1.small_icon = "HouseBuilder/hb_walltool_S.png"
  cmd1.large_icon = "HouseBuilder/hb_walltool_L.png"
  cmd1.tooltip = "Creates a wall."
  hb_tb.add_item(cmd1)
  
  # Gable Wall tool
  cmd2 = UI::Command.new(("Gable Wall tool")) { Sketchup.active_model.select_tool HouseBuilder::GableWallTool.new }
  cmd2.small_icon = "HouseBuilder/hb_gablewalltool_S.png"
  cmd2.large_icon = "HouseBuilder/hb_gablewalltool_L.png"
  cmd2.tooltip = "Creates a gable wall."
  hb_tb.add_item(cmd2)
  
  # Change Wall properties
  cmd999 = UI::Command.new(("Edit Wall")) {if (check_for_wall_selection)
                                               HouseBuilder::EditWallTool.show_prop_dialog 
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd999.small_icon = "HouseBuilder/hb_changewallproperties_S.png"
  cmd999.large_icon = "HouseBuilder/hb_changewallproperties_L.png"
  cmd999.tooltip = "Change Wall properties."
  hb_tb.add_item(cmd999)
  
  # Move Wall
  cmd999 = UI::Command.new(("Move Wall")) {if (check_for_wall_selection)
                                               HouseBuilder::EditWallTool.move
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd999.small_icon = "HouseBuilder/hb_movewall_S.png"
  cmd999.large_icon = "HouseBuilder/hb_movewall_L.png"
  cmd999.tooltip = "Move, rotate or extent Wall."
  hb_tb.add_item(cmd999)
  
  # Roof tool
  cmd4 = UI::Command.new(("Roof tool")) { Sketchup.active_model.select_tool HouseBuilder::RoofTool.new }
  cmd4.small_icon = "HouseBuilder/hb_rooftool_S.png"
  cmd4.large_icon = "HouseBuilder/hb_rooftool_L.png"
  cmd4.tooltip = "Creates a roof."
  hb_tb.add_item(cmd4)
  
  # Add window
  cmd998 = UI::Command.new(("Add window")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::WindowTool.new(wall)
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd998.small_icon = "HouseBuilder/hb_addwindow_S.png"
  cmd998.large_icon = "HouseBuilder/hb_addwindow_L.png"
  cmd998.tooltip = "Add a window in a wall"
  hb_tb.add_item(cmd998)
  
  # Change window properties
  cmd996 = UI::Command.new(("Change window properties in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "CHANGE_PROPERTIES")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd996.small_icon = "HouseBuilder/hb_changewindowproperties_S.png"
  cmd996.large_icon = "HouseBuilder/hb_changewindowproperties_L.png"
  cmd996.tooltip = "Change window properties in a wall"
  hb_tb.add_item(cmd996)
  
  # Move window
  cmd994 = UI::Command.new(("Move window in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "MOVE")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd994.small_icon = "HouseBuilder/hb_movewindow_S.png"
  cmd994.large_icon = "HouseBuilder/hb_movewindow_L.png"
  cmd994.tooltip = "Move window in a wall"
  hb_tb.add_item(cmd994)
  
  # Delete window
  cmd994 = UI::Command.new(("Delete window in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "DELETE")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd994.small_icon = "HouseBuilder/hb_deletewindow_S.png"
  cmd994.large_icon = "HouseBuilder/hb_deletewindow_L.png"
  cmd994.tooltip = "Delete window in a wall"
  hb_tb.add_item(cmd994)
  
  # Add door
  cmd997 = UI::Command.new(("Add door")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::DoorTool.new(wall)
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd997.small_icon = "HouseBuilder/hb_adddoor_S.png"
  cmd997.large_icon = "HouseBuilder/hb_adddoor_L.png"
  cmd997.tooltip = "Add a door in a wall"
  hb_tb.add_item(cmd997)
  
  # Change door properties
  cmd996 = UI::Command.new(("Change door properties in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "CHANGE_PROPERTIES")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd996.small_icon = "HouseBuilder/hb_changedoorproperties_S.png"
  cmd996.large_icon = "HouseBuilder/hb_changedoorproperties_L.png"
  cmd996.tooltip = "Change door properties in a wall"
  hb_tb.add_item(cmd996)
  
  # Move door
  cmd996 = UI::Command.new(("Move door in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "MOVE")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd996.small_icon = "HouseBuilder/hb_movedoor_S.png"
  cmd996.large_icon = "HouseBuilder/hb_movedoor_L.png"
  cmd996.tooltip = "Move door in a wall"
  hb_tb.add_item(cmd996)
  
  # Move door
  cmd992 = UI::Command.new(("Delete door in a wall")) {if wall = (check_for_wall_selection)
                                              
                                               Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "DELETE")
                                              else
                                                UI.messagebox "No selection or selection isn't a wall."
                                            end}
  cmd992.small_icon = "HouseBuilder/hb_deletedoor_S.png"
  cmd992.large_icon = "HouseBuilder/hb_deletedoor_L.png"
  cmd992.tooltip = "Delete door in a wall"
  hb_tb.add_item(cmd992)
  
  

  
  # Credits
  cmd1000 = UI::Command.new(("About...")) {(hb_credits)}
  cmd1000.small_icon = "HouseBuilder/hb_credits_S.png"
  cmd1000.large_icon = "HouseBuilder/hb_credits_L.png"
  cmd1000.tooltip = "Credits"
  hb_tb.add_item(cmd1000)
  
  
# End of load
$HouseBuilder_menu_loaded = true

end
file_loaded("HouseBuilder_extension.rb")
