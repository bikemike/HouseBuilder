# Copyright (C) 2014 Mike Morrison
# See LICENSE for details.

# Copyright 2005 Steve Hurlbut

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
# Name        :   HouseBuilderTool
# Description :   tools to build a house
# Menu Item   :   Draw->House Builder
# Context Menu:   Edit Wall
# Version     :   1.0
# Date        :   July 30, 2005
# Type        :   Tool
#-----------------------------------------------------------------------------
require 'sketchup.rb'
require 'HouseBuilder.rb'

# these are the states that a tool can be in
STATE_EDIT = 0 if not defined? STATE_EDIT
STATE_PICK = 1 if not defined? STATE_PICK
STATE_PICK_NEXT = 2 if not defined? STATE_PICK_NEXT
STATE_PICK_LAST = 3 if not defined? STATE_PICK_LAST
STATE_MOVING = 4 if not defined? STATE_MOVING
STATE_SELECT = 5 if not defined? STATE_SELECT


def min(x, y)
    if (x < y)
        return x
    end
    return y
end

def max(x, y)
    if (x > y) 
        return x
    end
    return y
end

# display an input dialog and store the results in an object
def display_dialog(title, obj, data)
    prompts = []
    attr_names = []
    values = []
    enums = []
    data.each { |a| prompts.push(a[0]); attr_names.push(a[1]); values.push(obj.send(a[1])); enums.push(a[2]) }
    results = UI.inputbox(prompts, values, enums, title)
    if results
        i = 0
        attr_names.each do |name|
            if (name)
                eval("obj.#{name} = results[i]")
                # puts "obj = " + obj.inspect
            end
            i = i + 1
        end
    end
    return results
end

# display an input dialog and store the results in the global options hash table
def display_global_options_dialog()
	parameters = [
	    # prompt, attr_name, value, enums
	    [ "Wall Lumber Size", "wall.style", "2x4|2x6|2x8" ],
	    [ "Wall Plate Height", "wall.height", nil ],
	    [ "Wall Stud Spacing", "wall.stud_spacing", nil ],
		[ "On-Center Stud Spacing", "wall.on_center_spacing", "true|false"],
	    [ "Wall Justification  ", "window.justify",  "left|center|right" ],
	    [ "Window Justification  ", "window.justify",  "left|center|right" ],
	    [ "Door Justification  ", "door.justify",  "left|center|right" ],
	    [ "Header Height", "header_height", nil ],
	    [ "Header Size", "header_style", "2x4|2x6|4x4|4x6|4x8|4x10|4x12|4x14|6x6|6x8|6x10|8x6|8x8|8x10" ],
	    [ "Roof Pitch (x/12)  ", "pitch",  nil ],
	    [ "Roof Joist Spacing", 'roof.joist_spacing', nil ],
		[ "On-Center Roof Joist Spacing", "roof.on_center_spacing", "true|false"],
	 	[ "Floor Joist Spacing", 'floor.joist_spacing', nil ],
		[ "On-Center Floor Joist Spacing", "floor.on_center_spacing", "true|false"],
	   ]
    prompts = []
    attr_names = []
    values = []
    enums = []
    parameters.each { |a| prompts.push(a[0]); attr_names.push(a[1]); values.push(HouseBuilder::BaseBuilder::GLOBAL_OPTIONS[a[1]]); enums.push(a[2]) }
    results = UI.inputbox(prompts, values, enums, 'Global Properties')
    if results
        i = 0
        attr_names.each do |name|
            eval("HouseBuilder::BaseBuilder::GLOBAL_OPTIONS['#{name}'] = results[i]")
            i = i + 1
        end
    end
    return results
end

# draw a 2D rectangle at the base of a wall
def draw_outline(view, start_pt, end_pt, width, wall_justify, color, line_width=1)
    # draw a line from the start to the end point
    view.set_color_from_line(start_pt, end_pt)
    view.line_width = line_width
    view.draw(GL_LINE_STRIP, start_pt, end_pt)
    view.drawing_color = color

    # calculate the other points
    # create a perpendicular vector
    vec = end_pt - start_pt
    if (vec.length > 0)
        case wall_justify
    	when "left"
    		transform = Geom::Transformation.new(start_pt, [0, 0, 1], -90.degrees)
    	when "right"
    	    transform = Geom::Transformation.new(start_pt, [0, 0, 1], 90.degrees)
    	when "center"
    	    # TODO
    	else
    	    UI.messagebox "invalid justification"
    	end		
    			
    	vec.transform!(transform)
    	vec.length = width
    	offset_start_pt = start_pt.offset(vec)
    	offset_end_pt = end_pt.offset(vec)
    	view.draw(GL_LINE_STRIP, start_pt, offset_start_pt)
    	view.draw(GL_LINE_STRIP, offset_start_pt, offset_end_pt)
    	view.draw(GL_LINE_STRIP, offset_end_pt, end_pt)
    end
    return offset_start_pt, offset_end_pt
end

# draw a 2D rectangle for a floor or roof
def draw_rect_outline(view, start_pt, end_pt, color)
    # draw a line from the start to the end point
    a = start_pt
    b = Geom::Point3d.new(start_pt.x, end_pt.y, end_pt.z)
    c = end_pt
    d = Geom::Point3d.new(end_pt.x, start_pt.y, end_pt.z)
    view.draw(GL_LINE_STRIP, a, b)
    view.draw(GL_LINE_STRIP, b, c)
    view.draw(GL_LINE_STRIP, c, d)
    view.draw(GL_LINE_STRIP, d, a)
end

def create_wall_from_drawing(group)
    name = group.get_attribute("einfo", "name")
    if (name =~ /_skin/)
        name.sub!('_skin', '')
        group = HouseBuilder::BaseBuilder.find_named_entity(name)
    end
    case group.get_attribute("einfo", "type")
    when "wall"
	    wall = HouseBuilder::Wall.create_from_drawing(group) 
	when "GableWall" 
	    wall = HouseBuilder::GableWall.create_from_drawing(group) 
	when "rakewall" 
	    wall = HouseBuilder::GableWall.create_from_drawing(group) 
	else
	    UI.messagebox "unknown wall type"
	end
	return wall
end
    	
    	
# minimum amount of wall before a window or door opening
MIN_WALL = 3 if not defined? MIN_WALL

module HouseBuilder

#--------  W A L L T O O L  ------------------------------------------------

# This class is used to draw a wall. It will display a properties dialog and
# then allow you to draw one or more walls using those properties. Press
# ESCAPE to exit the tool.
class WallTool

PROPERTIES = [
    # prompt, attr_name, enums
    [ "Wall Justification  ", "justify", "left|center|right" ],
    [ "Lumber Size", "style", "2x4|2x6|2x8" ],
    [ "Plate Height", "height", nil ],
    [ "Header Height", "header_height", nil ],
    [ "Length", "length", nil ],
    [ "Stud Spacing", "stud_spacing", nil ],
	[ "On-Center Spacing", "on_center_spacing", "true|false"],
    [ "Bottom Plate Count  ", "bottom_plate_count", "0|1" ],
    [ "Top Plate Count", "top_plate_count", "0|1|2" ],
   ].freeze
	   
def initialize()
	@wall = HouseBuilder::Wall.new() 
	results = display_dialog("Wall Properties", @wall, PROPERTIES)
	return false if not results
	@wall.width = Lumber.size_from_nominal("common", Lumber.length_from_style(@wall.style));	
end

def reset
    @pts = []
    @state = STATE_PICK
	Sketchup::set_status_text "", SB_VCB_LABEL
    Sketchup::set_status_text "", SB_VCB_VALUE
    Sketchup::set_status_text "[WALL] Click anywhere to start"
    @drawn = false
end

def activate
    puts "activate wall tool" if $VERBOSE
    @ip1 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    self.reset
end

def deactivate(view)
    puts "deactivate wall tool" if $VERBOSE
    view.invalidate if @drawn
    @ip1 = nil
    self.reset
end

# figure out where the user clicked and add it to the @pts array
def set_current_point(x, y, view)
    if (!@ip.pick(view, x, y, @ip1))
        return false
    end
    need_draw = true
    
    # Set the tooltip that will be displayed
    view.tooltip = @ip.tooltip
        
    # Compute points
    case @state
    when STATE_PICK
        @pts[0] = @ip.position
        need_draw = @ip.display? || @drawn
    when STATE_PICK_NEXT
        @pts[1] = @ip.position
        @length = @pts[0].distance @pts[1]
        Sketchup::set_status_text(@length.to_s, SB_VCB_VALUE)
    end

    view.invalidate if need_draw
end

def onMouseMove(flags, x, y, view)
    # puts "move"
	self.set_current_point(x, y, view)
end

# create a wall in the drawing
def draw_wall
	model = Sketchup.active_model
	model.start_operation "Create Wall"
    new_wall = @wall.clone
    new_wall.name = BaseBuilder.unique_name("wall")
    new_wall.origin = @pts[0]
	new_wall.length = @pts[0].distance(@pts[1])
	vec = @pts[0].vector_to(@pts[1])
	puts "vec = " + vec.inspect if $VERBOSE
	if (vec.x.abs > 0.1)
	    a1 = Math.atan2(vec.y, vec.x).radians 
	    new_wall.angle = a1 - 90
	    #puts "vec = (" + vec.x.to_s + ", " + vec.y.to_s + ") a1 = " + a1.to_s
	else
	    if (vec.y > 0)
	        new_wall.angle = 0
	    else
	        new_wall.angle = 180
	    end
    end
	puts "draw wall from " + @pts[0].to_s + " to " + @pts[1].to_s + " angle " + new_wall.angle.to_s if $VERBOSE
	group, skin_group = new_wall.draw
    model.commit_operation
end

# update the current state
def update_state
    case @state
    when STATE_PICK
        @ip1.copy! @ip
        Sketchup::set_status_text "[WALL] Click for end of wall"
        Sketchup::set_status_text "Length", SB_VCB_LABEL
        Sketchup::set_status_text "", SB_VCB_VALUE
        @state = STATE_PICK_NEXT
	when STATE_PICK_NEXT
		self.draw_wall
		reset
    end
end

def onLButtonDown(flags, x, y, view)
    self.set_current_point(x, y, view)
    self.update_state
end

def onCancel(flag, view)
    puts "on cancel" if $VERBOSE
    view.invalidate if @drawn
    reset
    Sketchup.active_model.select_tool(nil)
end

# if the user types in a number, use as the length of the wall
def onUserText(text, view)
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        value = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value
    
    if (@state == STATE_PICK_NEXT)
        # update the length of the wall
        vec = @pts[1] - @pts[0]
        if( vec.length > 0.0 )
            vec.length = value
            @pts[1] = @pts[0].offset(vec)
            view.invalidate
            self.update_state
        end
    end
end

def getExtents
    # puts "getExtents state = #{@state}"
    bb = Geom::BoundingBox.new
    if (@state == STATE_PICK)
        # We are getting the first point
        if (@ip.valid? && @ip.display?)
            bb.add(@ip.position)
        end
    else
        bb.add(@pts)
    end
    bb
end

# draw a 2D outline that represents the location of the base of the wall
def draw(view)
    # puts "draw state = #{@state}"
    # Show the current input point
    if (@ip.valid? && @ip.display?)
        @ip.draw(view)
        @drawn = true
    end

    # show the wall base outline
    if (@state == STATE_PICK_NEXT)
        (@offset_pt0, @offset_pt1) = draw_outline(view, @pts[0], @pts[1], @wall.width, @wall.justify, "gray")
        @drawn = true
    end
end

end # class WallTool

#--------  G A B L E W A L L T O O L  ------------------------------------------------

# Draw a gable wall
class GableWallTool < WallTool

PROPERTIES = [
    # prompt, attr_name, value, enums
    [ "Pitch (x/12)  ", "pitch", nil ],
    [ "Roof type", 'roof_type', "gable|shed" ],
    [ "Wall Justification  ", "justify", "left|center|right" ],
    [ "Lumber Size", "style", "2x4|2x6|2x8" ],
    [ "Plate Height", "height", nil ],
    [ "Header Height", "header_height", nil ],
    [ "Length", "length", nil ],
    [ "Stud Spacing", "stud_spacing", nil ],
	[ "On-Center Spacing", "on_center_spacing", "true|false"],
    [ "Bottom Plate Count  ", "bottom_plate_count", "0|1" ],
    [ "Top Plate Count", "top_plate_count", "0|1|2" ],
].freeze

def initialize()
	@wall = HouseBuilder::GableWall.new() 
	results = display_dialog("Gable Wall Properties", @wall, PROPERTIES)
	return false if not results
end

end # class GableWallTool

#---------- E D I T W A L L T O O L -------------------------------------------------

# Edit a wall. Initiate this tool by right clicking on a wall. Then right click for 
# a menu:
#    Change Wall Properties - change a wall property (such as the width)
#    Add Door - add a new door to the wall
#    Add Window - add a new window to the wall
#    Move - grab the side of the wall to move the wall. Grab a corner
#        to rotate or stretch a wall.
#    Select Door/Window - pick a door or window to edit
class EditWallTool
attr_accessor :wall, :group, :skin_group, :state, :changed

def initialize(wall)
    puts "EditWallTool: initialize"
    @state = STATE_EDIT
    @drawn = false
    @selection = nil
    @pt_to_move = nil
    @changed = false
    @wall = wall
    
    # Make sure that there is really a wall selected
    if (not (defined?(@group) && defined?(@wall)))
        group = EditWallTool.get_selected_wall
        name = group.get_attribute("einfo", "name")
        if (name =~ /skin/)
            name.sub!('_skin', '')
            @group = BaseBuilder.find_named_entity(name)
            @skin_group = group
        else
            @group = group
            @skin_group = BaseBuilder.find_named_entity(name + "_skin")
        end
        
        @wall = create_wall_from_drawing(@group)
        
        # puts "wall = " + @wall.to_s
        if (not @wall)
            Sketchup.active_model.select_tool nil
            return
        end
    end
    
    # Get the end points
	@pts = [ @wall.origin, @wall.endpt ]
	
    if (not @pts)
        UI.beep
        Sketchup.active_model.select_tool(nil)
        return
    end
    reset
end

def activate
    puts "EditWallTool: activate" if $VERBOSE
    @group.hidden = true
    @skin_group.hidden = true if @skin_group
	@pts = [ @wall.origin, @wall.endpt ]
	@ip = Sketchup::InputPoint.new
    reset
end

def reset
    Sketchup::set_status_text "", SB_VCB_LABEL
    Sketchup::set_status_text "", SB_VCB_VALUE
    Sketchup::set_status_text "[EDITWALL] right click for menu"
end

def deactivate(view)
    #unhide???
    view.invalidate if @drawn
    @ip = nil
end

def resume(view)
    @drawn = false
end

# figure out if the user has picked a side or a corner
def pick_point_to_move(x, y, view)
    return false if not @corners
    old_pt_to_move = @pt_to_move
    ph = view.pick_helper(x, y)
    # puts "corners = " + @corners.inspect
    @selection = ph.pick_segment(@corners)
    # puts "selection = " + @selection.to_s
    if (@selection)
        if (@selection < 0)
            # We got a point on a segment.  Compute the point closest
            # to the pick ray.
            pickray = view.pickray(x, y)
            i = -@selection
            segment = [@corners[i-1], @corners[i]]
            result = Geom.closest_points(segment, pickray)
            @pt_to_move = result[0]
            # if the user grabs and end segment, move the corner
            if (@selection == -2)
                @selection = 2
                @pt_to_move = @pts[1]
            end
            if (@selection == -4)
                @selection = 1
                @pt_to_move = @pts[0]
            end
        else
            # we got a control point
            @pt_to_move = @corners[@selection]
        end
        @start_input_point = Sketchup::InputPoint.new(@pt_to_move)
    else
        @pt_to_move = nil
    end
    return old_pt_to_move != @pt_to_move
end

# determine if the point is inside of a window or door
def find_selected_object(x, y, view)
    return nil if not @corners
    pickray = view.pickray(x, y)
    wall_base_plane = [ @corners[0], Z_AXIS ]
    orig_point = Geom::intersect_line_plane(pickray, wall_base_plane)
    return nil if not orig_point
    point = Geom::Point3d.new(orig_point)
    # create a transformation if wall angle is not zero
    rotate_transform = Geom::Transformation.rotation(@corners[0], Z_AXIS, -@wall.angle.degrees)
           
    wall_start = Geom::Point3d.new(@wall.origin)
    wall_end = Geom::Point3d.new(@wall.endpt)
    if (@wall.angle != 0)
        wall_start.transform!(rotate_transform)
        wall_end.transform!(rotate_transform)
        point.transform!(rotate_transform)
    end
    
    wall_vec = wall_end - wall_start
    
    @wall.objects.each do |obj|
        
        # find the four corners of the object
        wall_vec.length = obj.center_offset - obj.width/2
        obj_start = wall_start + wall_vec
        wall_vec.length = obj.width
        obj_end = obj_start + wall_vec
        obj_vec = obj_end - obj_start
        next if (obj_vec.length <= 0)
        case @wall.justify
    	when "left"
    		transform = Geom::Transformation.new(obj_start, [0, 0, 1], -90.degrees)
    	when "right"
    	    transform = Geom::Transformation.new(obj_start, [0, 0, 1], 90.degrees)
    	when "center"
    	    # TODO
    	else
    	    transform = Geom::Transformation.new
    	    UI.messagebox "invalid justification"
    	end		
    			
    	obj_vec.transform!(transform)
    	obj_vec.length = @wall.width
   	    obj_start_offset = obj_start.offset(obj_vec)

        # determine if the point lies within the rectangle
        # puts "orig_point = " + orig_point.inspect        
        # puts "point = " + point.inspect
        # puts "obj_start = " + obj_start.inspect
        # puts "obj_end = " + obj_end.inspect
        # puts "obj_start_offset = " + obj_start_offset.inspect
        if ((point.y > min(obj_start.y, obj_end.y)) &&
            (point.y < max(obj_start.y, obj_end.y)) &&
            (point.x > min(obj_start.x, obj_start_offset.x)) &&
            (point.x < max(obj_start.x, obj_start_offset.x)))
            # puts "found"
            view.invalidate
            return(obj)
        end
    end
    return(nil)    # didn't find a door or window under the mouse
end

# allow the user to move the door/window a specific distance from 
# the end of the wall
def onUserText(text, view)
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        value = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value
    
    if (@state == STATE_MOVING && @selection)
        vec_back = @start_input_point.position - @pt_to_move
        vec = vec_back.reverse
        vec.length = value
        @pt_to_move = @start_input_point.position + vec
        move_points(vec_back)
        move_points(vec)
        view.invalidate
        draw(view)
        done
    end
end

def onLButtonDown(flags, x, y, view)
    case @state
    when STATE_PICK
        # Select the segment or control point to move
        self.pick_point_to_move(x, y, view)
        @state = STATE_MOVING if (@selection)
        Sketchup::set_status_text "distance", SB_VCB_LABEL
        Sketchup::set_status_text "", SB_VCB_VALUE
        Sketchup::set_status_text "[MOVEWALL] Drag wall to new location"
        @have_moved = false
        @changed = true
    when STATE_MOVING
        # do nothing
    when STATE_SELECT
        edit_object(@selected_obj) if @selected_obj
        @state = STATE_EDIT
    end
    
end

def onLButtonUp(flags, x, y, view)
    # we are finished moving, go back to edit state
    if ((@state == STATE_MOVING) and @have_moved)
        draw(view)
        done
    end
end

def onMouseMove(flags, x, y, view)
    @ip.pick(view, x, y)
    view.tooltip = @ip.tooltip if @ip.valid?
    @have_moved = true
    
    # Move the selected point if state = MOVING
    if (@state == STATE_MOVING && @selection)
        @ip.pick(view, x, y, @start_input_point)
        view.tooltip = @ip.tooltip if @ip.valid?
        return if not @ip.valid?
        pt = @ip.position
        vec = pt - @pt_to_move
        @pt_to_move = pt
        move_points(vec)
        length = pt.distance @start_input_point.position
        Sketchup::set_status_text(length.to_s, SB_VCB_VALUE)
    elsif (@state == STATE_PICK)
        # See if we can select something to move
        self.pick_point_to_move(x, y, view)
    elsif (@state == STATE_SELECT)
        # highlight the selected object
        @selected_obj = find_selected_object(x, y, view) 
    end
    view.invalidate
end

def onCancel(flag, view)
    view.invalidate if @drawn
    if (@state == STATE_MOVING)
        @state = STATE_EDIT
        vec_back =  @start_input_point.position - @pt_to_move
        move_points(vec_back)
    end
    @changed = false;
    done
end

# move the object endpoints the distance specified by the 
# length of the vector
def move_points(vec)
    if (@selection >= 0)
        # Moving a control point
        if ((@selection == 0) or (@selection == 3))
            @pts[0].offset!(vec)
        else
            @pts[1].offset!(vec)
        end
    else
        # moving a segment
        @pts[0].offset!(vec)
        @pts[1].offset!(vec)          
    end
end

def done
    if (@changed)
        draw_wall
    else
        @group.hidden = false;
        @skin_group.hidden = false if (@skin_group)
    end
    Sketchup.active_model.select_tool nil
end

# redraw the wall at the new position
def draw_wall
    @wall.origin = @pts[0]
	@wall.length = @pts[0].distance(@pts[1])
	vec = @pts[0].vector_to(@pts[1])
	# puts "vec = (" + vec.x.to_s + ", " + vec.y.to_s
	if (vec.x.abs > 0.01)
	    a1 = Math.atan2(vec.y, vec.x).radians 
	    @wall.angle = a1 - 90
	    # puts "a1 = " + a1.to_s
	else
	    if (vec.y > 0)
	        @wall.angle = 0
	    else
	        @wall.angle = 180
	    end
    end
	puts "draw wall from " + @pts[0].to_s + " to " + @pts[1].to_s + " angle " + @wall.angle.to_s if $VERBOSE
	@group.erase!
	@skin_group.erase! if (@skin_group)
	
	model = Sketchup.active_model
	model.start_operation "Create Wall"
	@group, @skin_group = @wall.draw
    model.commit_operation
    
	@changed = false
end

# edit a door or window
def edit_object(obj)
    puts "edit object #{obj}" if $VERBOSE
    Sketchup.active_model.select_tool EditOpeningTool.new(self, obj)
end

def self.show_prop_dialog
    tool = EditWallTool.new(nil)
    if (tool.wall.kind_of?(HouseBuilder::GableWall))
        results = display_dialog("Gable Wall Properties", tool.wall, GableWallTool::PROPERTIES)
    else
        results = display_dialog("Wall Properties", tool.wall, WallTool::PROPERTIES)
    end
	if (results)
	    tool.changed = true
        tool.done
    end
end

def self.move
    tool = EditWallTool.new(nil)
    tool.state = STATE_PICK
    Sketchup.active_model.select_tool(tool)
end

def getExtents
    bb = Geom::BoundingBox.new
    bb.add @pts
    bb
end

# draw a 2D outline of the wall and any doors or windows
def draw(view)
    # show the wall base outline

    # draw the outline of the wall
    @corners = [] if not defined?(@corners)
    @corners[0] = @pts[0]
    @corners[1] = @pts[1]
    (a, b) = draw_outline(view, @pts[0], @pts[1], @wall.width, @wall.justify, "gray")
    # puts "a = " + a.inspect
    @corners[2] = b
    @corners[3] = a
    @corners[4] = @pts[0]
    vec = @pts[1] - @pts[0]
    @wall.objects.each do |obj|
        vec.length = obj.center_offset - obj.width/2
        obj_start = @wall.origin + vec
        vec.length = obj.width
        obj_end = obj_start + vec
        if (defined?(@selected_obj) && (obj == @selected_obj))
            draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "red", 3)
        else
            draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
        end
    end
    
    if ((@state == STATE_PICK) || (@state == STATE_MOVING))
        if (@pt_to_move)
            view.draw_points(@pt_to_move, 10, 1, "red");
        end
        if (@state == STATE_MOVING)
           view.set_color_from_line(@start_input_point.position, @pt_to_move)
           view.line_stipple = "."    # dotted line
           view.draw(GL_LINE_STRIP, @start_input_point.position, @pt_to_move)
        end
    end
    
    @drawn = true
end

# Static method to test to see if the selection set contains only a wall
# Returns the wall if there is one or else nil
def self.get_selected_wall
    ss = Sketchup.active_model.selection
    group = ss.first
    if (group.kind_of?(Sketchup::Group))
        wall_type = group.get_attribute("einfo", "type")
        case wall_type
        when "wall", "GableWall", "rakewall"
            return group
        end
    end
    # wall is not selected
    UI.beep
    return nil
end

# Edit a selected wall
def self.edit_wall
    wall = EditWallTool.get_selected_wall
    Sketchup.active_model.select_tool EditWallTool.new(wall)
end


end # class EditWallTool

#--------  W I N D O W T O O L  ------------------------------------------------

# Add a window to a wall. This tool displays a window property dialog and then 
# allows the user to place the window using the mouse. Click the mouse when the
# window is in the correct position.
class WindowTool

PROPERTIES = [
    # prompt, attr_name, value, enums
    [ "Offset Justification  ", "justify", "left|center|right" ],
    [ "Header Height", "header_height", nil ],
    [ "Header Size", "header_style", "2x4|2x6|4x4|4x6|4x8|4x10|4x12|4x14|6x6|6x8|6x10|8x6|8x8|8x10" ],
    [ "Sill Size", "sill_style", "2x4|2x6|2x8|4x4|4x6|4x8" ],
    [ "Width", "width", nil ],
    [ "Height", "height", nil ],
].freeze
	   
def initialize(wall_group)
	@obj = HouseBuilder::Window.new()
	@wall = create_wall_from_drawing(wall_group)
    @objtype = "Wall"
	results = display_dialog("Window Properties", @obj, PROPERTIES)
	return false if not results
	reset
	return true
end

def reset
    @pts = []
    @state = STATE_MOVING
    Sketchup::set_status_text "[ADD #{@objtype}] Use mouse to move #{@objtype}; click to place #{@objtype}"
    Sketchup::set_status_text "#{@obj.justify} Offset", SB_VCB_LABEL
    Sketchup::set_status_text "", SB_VCB_VALUE
    @drawn = false
end

def activate
    @ip1 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    @wall.hide
end

def deactivate(view)
    view.invalidate if @drawn
    @ip1 = nil
    @wall.unhide
end

# find the points on the left and right side of the window
def find_end_points
    vec = @wall.endpt - @wall.origin
    case @obj.justify
    when "left"
        # do nothing
    when "center"
        @offset -= @obj.width/2
    when "right"
        @offset -= @obj.width
    else
        UI.messagebox "invalid justification"
    end
    
    # make sure we have not extended beyond the end of the wall
    if ((@offset + @obj.width) > @wall.length - MIN_WALL)
        @offset = @wall.length - @obj.width - MIN_WALL
    end
    
    # make sure we have not extended beyond the beginning of the wall
    if (@offset <= MIN_WALL)
        vec.length = MIN_WALL
        @start_pt = @wall.origin + vec
    else
        vec.length = @offset
        @start_pt = @wall.origin + vec
    end
    vec.length = @obj.width
    @end_pt = @start_pt + vec
end

# recompute the start and end points as the window is tracking the mouse
def set_current_point(x, y, view)
    if (!@ip.pick(view, x, y, @ip1))
        return false
    end
    need_draw = true
    
    # Set the tooltip that will be displayed
    view.tooltip = @ip.tooltip
        
    # Compute points
    if (@state == STATE_MOVING)
        vec = @wall.endpt - @wall.origin
        point = @ip.position.project_to_line(@wall.origin, @wall.endpt)
        start_vec = point - @wall.origin
        if ((start_vec.length == 0) || (start_vec.samedirection?(vec)))
            @offset = @wall.origin.distance point
        else
            @offset = 0    # point is beyond wall origin
        end
        Sketchup::set_status_text(@offset.to_s, SB_VCB_VALUE)
        
        find_end_points
    end

    view.invalidate if need_draw
end

def onMouseMove(flags, x, y, view)
	self.set_current_point(x, y, view)
end

# add the window to the drawing
def draw_obj
    vec = @end_pt - @start_pt
    vec.length = vec.length/2
    center = @start_pt + vec
    # puts "center = " + center.to_s
    @obj.center_offset = @wall.origin.distance center
	@wall.add(@obj)
	
	model = Sketchup.active_model
	model.start_operation "Add Window/Door"
	@wall.erase
	@wall.draw
    model.commit_operation
end

def onLButtonDown(flags, x, y, view)
    self.set_current_point(x, y, view)
    self.draw_obj
    # TODO
	Sketchup.active_model.select_tool(nil)
end

def onCancel(flag, view)
	puts "cancel door/wall" if $VERBOSE
    view.invalidate if @drawn
    Sketchup.active_model.select_tool(nil)
    reset
end

# allow the user to type in the distance to the window from the 
# start of the wall
def onUserText(text, view)
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        value = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value
    
    # update the offset of the window or door
    @offset = value
    find_end_points
    view.invalidate
    self.draw_obj
    Sketchup.active_model.select_tool(nil)
end

def getExtents
    bb = Geom::BoundingBox.new
    if (@start_pt)
        bb.add(@start_pt)
        bb.add(@end_pt)
    else
        bb.add(@wall.origin)
    end
    return bb
end

# draw a rectangular outline of the wall and window. Highlight the active
# window
def draw(view)
    # Show the current input point
    if (@ip.valid? && @ip.display?)
        @ip.draw(view)
        @drawn = true
    end 

    # draw the outline of the wall
    draw_outline(view, @wall.origin, @wall.endpt, @wall.width, @wall.justify, "gray")
    vec = @end_pt - @start_pt
    # draw the outline of each door and window
    @wall.objects.each do |obj|
        vec.length = obj.center_offset - obj.width/2
        obj_start = @wall.origin + vec
        vec.length = obj.width
        obj_end = obj_start + vec
        draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
    end
    draw_outline(view, @start_pt, @end_pt, @wall.width, @wall.justify, "orange", 2)
    @drawn = true
end

end # class WindowTool

#--------  D O O R T O O L  ------------------------------------------------

# Add a door to a wall. This tool displays a door property dialog and then 
# allows the user to place the door using the mouse. Click the mouse when the
# door is in the correct position.
class DoorTool < WindowTool
    
PROPERTIES = [
    # prompt, attr_name, value, enums
    [ "Offset Justification  ", "justify", "left|center|right" ],
    [ "Header Height", "header_height", nil ],
    [ "Header Size", "header_style", "2x4|2x6|4x4|4x6|4x8|4x10|4x12|4x14|6x6|6x8|6x10|8x6|8x8|8x10" ],
    [ "Width", "width", nil ],
    [ "Height", "height", nil ],
].freeze
	   
def initialize(wall_group)
	@obj = HouseBuilder::Door.new()
	@wall = create_wall_from_drawing(wall_group)
	@objtype = "Door"
	results = display_dialog("Door Properties", @obj, PROPERTIES)
	return false if not results
	reset
	return true
end

def reset
    super
    Sketchup::set_status_text "[DOORTOOL] Use mouse to move door; click to place door"
end

end # class DoorTool

#--------  E D I T O P E N I N G T O O L  ------------------------------------------------

# Edit a window or door. 
#    Change Window Properties - change a window property (such as the width)
#    Move - move the selected window to a new position.
#    Delete Window - remove the window from the drawing
class EditOpeningTool < WindowTool
attr_accessor :obj, :wall, :operation

  
def initialize(wall_group, objtype, operation)
    @operation = operation
	@objtype = objtype
	@wall = create_wall_from_drawing(wall_group)
	@offset = 0
	@selected_obj = nil
	@pt_to_move = nil
	@start_input_point = nil
	@corners = []
	reset
	return true
end

def reset
    @state = STATE_SELECT
    Sketchup::set_status_text "[#{@operation} #{@objtype}] hover over #{@objtype} and click when highlighted"
    Sketchup::set_status_text "", SB_VCB_LABEL
    Sketchup::set_status_text "", SB_VCB_VALUE
    @drawn = false
end

def activate
    @ip1 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    @wall.hide
end

def deactivate(view)
    view.invalidate if @drawn
    @ip1 = nil
    @wall.unhide
end

# determine if the point is inside of a window or door
# todo: only allow selecting objects of the correct type
def find_selected_object(x, y, view)
    # puts "corners = " + @corners.inspect
    return nil if (@corners.length != 5)
    pickray = view.pickray(x, y)
    wall_base_plane = [ @corners[0], Z_AXIS ]
    orig_point = Geom::intersect_line_plane(pickray, wall_base_plane)
    # puts "pt = " + orig_point.inspect
    return nil if not orig_point
    point = Geom::Point3d.new(orig_point)
    # create a transformation if wall angle is not zero
    rotate_transform = Geom::Transformation.rotation(@corners[0], Z_AXIS, -@wall.angle.degrees)
           
    wall_start = Geom::Point3d.new(@wall.origin)
    wall_end = Geom::Point3d.new(@wall.endpt)
    if (@wall.angle != 0)
        wall_start.transform!(rotate_transform)
        wall_end.transform!(rotate_transform)
        point.transform!(rotate_transform)
    end
    
    wall_vec = wall_end - wall_start
    
    @wall.objects.each do |obj|
        
        # find the four corners of the object
        wall_vec.length = obj.center_offset - obj.width/2
        obj_start = wall_start + wall_vec
        wall_vec.length = obj.width
        obj_end = obj_start + wall_vec
        obj_vec = obj_end - obj_start
        next if (obj_vec.length <= 0)
        case @wall.justify
    	when "left"
    		transform = Geom::Transformation.new(obj_start, [0, 0, 1], -90.degrees)
    	when "right"
    	    transform = Geom::Transformation.new(obj_start, [0, 0, 1], 90.degrees)
    	when "center"
    	    # TODO
    	else
    	    transform = Geom::Transformation.new
    	    UI.messagebox "invalid justification"
    	end		
    			
    	obj_vec.transform!(transform)
    	obj_vec.length = @wall.width
   	    obj_start_offset = obj_start.offset(obj_vec)

        # determine if the point lies within the rectangle
        # puts "orig_point = " + orig_point.inspect        
        # puts "point = " + point.inspect
        # puts "obj_start = " + obj_start.inspect
        # puts "obj_end = " + obj_end.inspect
        # puts "obj_start_offset = " + obj_start_offset.inspect
        if ((point.y > min(obj_start.y, obj_end.y)) &&
            (point.y < max(obj_start.y, obj_end.y)) &&
            (point.x > min(obj_start.x, obj_start_offset.x)) &&
            (point.x < max(obj_start.x, obj_start_offset.x)))
            # puts "found"
            view.invalidate
            return(obj)
        end
    end
    return(nil)    # didn't find a door or window under the mouse
end

def onMouseMove(flags, x, y, view)
    @ip.pick(view, x, y)
    view.tooltip = @ip.tooltip if @ip.valid?
    @have_moved = true
    
    # Move the selected point if state = MOVING
    # puts "state = #{@state} sel = #{@selected_obj}"
    if (@state == STATE_MOVING && @selected_obj)
        @ip.pick(view, x, y, @start_input_point)
        view.tooltip = @ip.tooltip if @ip.valid?
        return if not @ip.valid?
        vec = @wall.endpt - @wall.origin
        point = @ip.position.project_to_line(@wall.origin, @wall.endpt)
        start_vec = point - @wall.origin
        if ((start_vec.length == 0) || (start_vec.samedirection?(vec)))
            @offset = @wall.origin.distance point
        else
            @offset = 0    # point is beyond wall origin
        end
        Sketchup::set_status_text(@offset.to_s, SB_VCB_VALUE)
        
        find_end_points
    elsif (@state == STATE_SELECT)
        # highlight the selected object
        @selected_obj = find_selected_object(x, y, view) 
    end
    view.invalidate
end

def draw_obj
	model = Sketchup.active_model
	model.start_operation "Edit #{@objtype}"
	@wall.erase
	@wall.draw
    model.commit_operation
end

def onLButtonDown(flags, x, y, view)
    if ((@state == STATE_MOVING) and @have_moved)
        # puts "LButtonDown"
        vec = @end_pt - @start_pt
        vec.length = vec.length/2
        center = @start_pt + vec
        # puts "center = " + center.to_s
        @obj.center_offset = @wall.origin.distance center
        draw_obj  
        Sketchup.active_model.select_tool(nil) 
    elsif (@state == STATE_SELECT)
        do_operation if @selected_obj
    end
end

def onCancel(flag, view)
	puts "cancel edit #{@objtype}" if $VERBOSE
    Sketchup.active_model.select_tool(nil) 
end

# allow the user to type in the offset from the start of the wall when
# moving a window.
def onUserText(text, view)
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        value = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value
    # puts "user text = " + value.inspect
    case @state
    when STATE_MOVING
        # update the offset of the window or door
        @offset = value
        find_end_points
        view.invalidate
        draw_obj
        Sketchup.active_model.select_tool(nil)
    end
end

def do_operation
    puts "executing operation #{@operation}" if $VERBOSE
    case @operation
    when "CHANGE_PROPERTIES"
        show_prop_dialog
    when "MOVE"
        move
    when "DELETE"
        delete_obj
    end
end

# display the properties dialog for the selected door/window
def show_prop_dialog
    # puts "wall = " + @wall.inspect
    # puts "window = " + @obj.inspect
    case @objtype
    when "Window"
        results = display_dialog("Window Properties", @selected_obj, WindowTool::PROPERTIES)
    when "Door"
        results = display_dialog("Door Properties", @selected_obj, DoorTool::PROPERTIES)
    end
	if (results)
        draw_obj
    end
    Sketchup.active_model.select_tool(nil)
end

# initiate a 'move' operation
def move
    return if not @selected_obj
    @state = STATE_MOVING
    @obj = @selected_obj
    @offset = @obj.center_offset
    find_end_points
    vec = @end_pt - @start_pt
    vec.length = vec.length/2
    @pt_to_move = @start_pt + vec
    @start_input_point = Sketchup::InputPoint.new(@pt_to_move)
end

# delete the selected object
def delete_obj
    # display confirmation dialog
    result = UI.messagebox("Delete this #{@objtype}?" , MB_YESNO, "Confirm Delete")
    
    # delete if yes
    if (result == 6)
        @wall.objects.delete(@selected_obj)
        draw_obj
    end
    Sketchup.active_model.select_tool(nil)
end

def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@wall.origin)
    bb.add(@wall.endpt)
    return bb
end

# draw a 2D outline of the wall and any doors or windows
def draw(view)
    # show the wall base outline

    # draw the outline of the wall
    @corners[0] = @wall.origin
    @corners[1] = @wall.endpt
    (a, b) = draw_outline(view, @corners[0], @corners[1], @wall.width, @wall.justify, "gray")
    # puts "a = " + a.inspect
    @corners[2] = b
    @corners[3] = a
    @corners[4] = @corners[0]
    vec = @corners[1] - @corners[0]
    @wall.objects.each do |obj|
        vec.length = obj.center_offset - obj.width/2
        obj_start = @wall.origin + vec
        vec.length = obj.width
        obj_end = obj_start + vec
        if (defined?(@selected_obj) && (obj == @selected_obj))
            if (@state != STATE_MOVING)
                draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "red", 3)
            end
        else
            draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
        end
    end
    if (@state == STATE_MOVING)
        draw_outline(view, @start_pt, @end_pt, @wall.width, @wall.justify, "red", 2)
    end
    
    @drawn = true
end

end # class EditOpeningTool

# --------  R O O F T O O L  ------------------------------------------------

# Add a roof. This tool displays a roof property dialog and then 
# allows the user to place the roof using the mouse to select three
# corners of the roof. Choose the following corners in order:
#    left front
#    right front
#    right rear
# Note that the corners should be the corners of the WALLS not the corners
# of the ROOF. The tool will draw the roof overhang using the values
# on the properties dialog.
#
# Gable roofs are drawn with the gable ends facing front and back
#
# Shed roofs are drawn with the lowest side on the side marked by
# the first point. To draw a shed roof with the highest point on 
# the left, draw the points in this order:
#    right front
#    left front
#    left rear
class RoofTool
    attr_accessor :roof_style_name
    
PROPERTIES = [
    # prompt, attr_name, value, enums
    [ "Type", "roof_style", "gable|shed" ],
    [ "Lumber Size", "style", "2x4|2x6|2x8|2x10|2x12" ],
    [ "Joist Spacing", "joist_spacing", nil ],
	[ "On-Center Spacing", "on_center_spacing", "true|false"],
    [ "Pitch (x/12)  ", "pitch", nil ],
    [ "Overhang", "overhang", nil ],
    [ "Rake Overhang", "rake_overhang", nil ],
].freeze

def initialize()
    @tool_name = "ROOFTOOL"
    wall = HouseBuilder::Wall.new()
	@obj = HouseBuilder::Roof.new(wall) 
	results = display_dialog("Roof Properties", @obj, PROPERTIES)
	return false if not results
	reset
	@type = "roof"
end

def reset
    @pts = []
    @state = STATE_PICK
	Sketchup::set_status_text "", SB_VCB_LABEL
    Sketchup::set_status_text "", SB_VCB_VALUE
    Sketchup::set_status_text "[#{@tool_name}] Click front left corner"
    @drawn = false
    puts "reset" if $VERBOSE
end

def activate
    @ip1 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    self.reset
end

def deactivate(view)
    view.invalidate if @drawn
    @ip1 = nil
end

def set_current_point(x, y, view)
    if (!@ip.pick(view, x, y, @ip1))
        return false
    end
    need_draw = true
    
    # Set the tooltip that will be displayed
    view.tooltip = @ip.tooltip
        
    # Compute points
    case @state
    when STATE_PICK
        @pts[0] = @ip.position
        @pts[4] = @pts[0]
        need_draw = @ip.display? || @drawn
    when STATE_PICK_NEXT
        @pts[1] = @ip.position
        @width = @pts[0].distance @pts[1]
        Sketchup::set_status_text @width.to_s, SB_VCB_VALUE
    when STATE_PICK_LAST
        pt1 = @ip.position
        pt2 = pt1.project_to_line @pts
        vec = pt1 - pt2
        @height = vec.length
        if( @height > 0 )
            # test for a square
            square_point = pt2.offset(vec, @width)
            if( view.pick_helper.test_point(square_point, x, y) )
                @height = @width
                @pts[2] = @pts[1].offset(vec, @height)
                @pts[3] = @pts[0].offset(vec, @height)
                view.tooltip = "Square"
            else
                @pts[2] = @pts[1].offset(vec)
                @pts[3] = @pts[0].offset(vec)
            end
        else
            @pts[2] = @pts[1]
            @pts[3] = @pts[0]
        end
        Sketchup::set_status_text @height.to_s, SB_VCB_VALUE
    end   

    view.invalidate if need_draw
end

def onMouseMove(flags, x, y, view)
	self.set_current_point(x, y, view)
end

def draw_obj
    @obj.corner1 = @pts[0]
    @obj.corner2 = @pts[1]
    @obj.corner3 = @pts[2]
    @obj.corner4 = @pts[3]
	puts "draw from " + @pts[0].to_s + " to " + @pts[2].to_s if $VERBOSE
	model = Sketchup.active_model
	model.start_operation "Create #{@type}"
	group = @obj.draw
    model.commit_operation
end

def update_state
    case @state
    when STATE_PICK
        @ip1.copy! @ip
        Sketchup::set_status_text "[#{@tool_name}] Click for second front corner point"
        Sketchup::set_status_text "Width", SB_VCB_LABEL
        Sketchup::set_status_text "", SB_VCB_VALUE
        @state = STATE_PICK_NEXT
    when STATE_PICK_NEXT
        @ip1.clear
        Sketchup::set_status_text "[#{@tool_name}] Click for back corner point"
        Sketchup::set_status_text "Depth", SB_VCB_LABEL
        Sketchup::set_status_text "", SB_VCB_VALUE
        @state = STATE_PICK_LAST
    when STATE_PICK_LAST
        self.draw_obj
        Sketchup.active_model.select_tool(nil)
    end
end

def onLButtonDown(flags, x, y, view)
    self.set_current_point(x, y, view)
    self.update_state
end

def onCancel(flag, view)
    view.invalidate if @drawn
    reset
end

def onUserText(text, view)
    # The user may type in something that we can't parse as a length
    # so we set up some exception handling to trap that
    begin
        value = text.to_l
    rescue
        # Error parsing the text
        UI.beep
        value = nil
        Sketchup::set_status_text "", SB_VCB_VALUE
    end
    return if !value
    
    case @state
    when STATE_PICK_NEXT
        # update the width
        vec = @pts[1] - @pts[0]
        if( vec.length > 0.0 )
            vec.length = value
            @pts[1] = @pts[0].offset(vec)
            view.invalidate
            self.update_state
        end
    when STATE_PICK_LAST
        # update the height
        vec = @pts[3] - @pts[0]
        if( vec.length > 0.0 )
            vec.length = value
            @pts[2] = @pts[1].offset(vec)
            @pts[3] = @pts[0].offset(vec)
            self.update_state
        end
    end
end

def getExtents
    bb = Geom::BoundingBox.new
    case @state
    when STATE_PICK
        # We are getting the first point
        if( @ip.valid? && @ip.display? )
            bb.add @ip.position
        end
    when STATE_PICK_NEXT
        bb.add @pts[0]
        bb.add @pts[1]
    when STATE_PICK_LAST
        bb.add @pts
    end
    return bb
end

def onKeyDown(key, rpt, flags, view)
    if( key == CONSTRAIN_MODIFIER_KEY && rpt == 1 )
        @shift_down_time = Time.now
        
        # if we already have an inference lock, then unlock it
        if( view.inference_locked? )
            view.lock_inference
        elsif( @state == 0 )
            view.lock_inference @ip
        elsif( @state == 1 )
            view.lock_inference @ip, @ip1
        end
    end
end

def onKeyUp(key, rpt, flags, view)
    if( key == CONSTRAIN_MODIFIER_KEY &&
        view.inference_locked? &&
        (Time.now - @shift_down_time) > 0.5 )
        view.lock_inference
    end
end

# draw a 2D rectangle for the outline of the roof
def draw(view)
    @drawn = false
    
    # Show the current input point
    if( @ip.valid? && @ip.display? )
        @ip.draw(view)
        @drawn = true
    end

    case @state
    when STATE_PICK
        # do nothing
    when STATE_PICK_NEXT
        # just draw a line from the start to the end point
        view.set_color_from_line(@ip1, @ip)
        inference_locked = view.inference_locked?
        view.line_width = 3 if inference_locked
        view.draw(GL_LINE_STRIP, @pts[0], @pts[1])
        view.line_width = 1 if inference_locked
        @drawn = true
    else
        # draw a rectangle
        view.drawing_color = "black"
        view.draw(GL_LINE_STRIP, @pts)
        @drawn = true
    end
end

end # class RoofTool

# --------  F L O O R T O O L  ------------------------------------------------

# Draw floors
class FloorTool < RoofTool

PROPERTIES = [
    # prompt, attr_name, value, enums
    [ "Lumber Size", "style", "2x4|2x6|2x8|2x10|2x12|TJI230 x 12|TJI230 x 10" ],
    [ "Joist Spacing", "joist_spacing", nil ],
	[ "On-Center Spacing", "on_center_spacing", "true|false"],
].freeze
	   
def initialize()
    @tool_name = "FLOORTOOL"
	@obj = HouseBuilder::Floor.new() 
	results = display_dialog("Floor Properties", @obj, PROPERTIES)
	return false if not results
	reset
	@type = "floor"
end

end # class FloorTool

end # module HouseBuilder

#-----------------------------------------------------------------------------
# Add a menu items
if (not file_loaded?("HouseBuilderTool.rb"))
    submenu = UI.menu("Draw").add_submenu("House Builder")
    submenu.add_item("Wall Tool") { Sketchup.active_model.select_tool HouseBuilder::WallTool.new }    
    submenu.add_item("Gable Wall Tool") { Sketchup.active_model.select_tool HouseBuilder::GableWallTool.new }
    submenu.add_item("Roof Tool") { Sketchup.active_model.select_tool HouseBuilder::RoofTool.new }
    submenu.add_item("Floor Tool") { Sketchup.active_model.select_tool HouseBuilder::FloorTool.new }
    submenu.add_item("Change Global Properties") { display_global_options_dialog }
    #submenu.add_item("Reload Tools") { load "HouseBuilder.rb"; load "HouseBuilderTool.rb" }
    
    # Add a context menu handler to let you edit a Wall
    UI.add_context_menu_handler do |menu|
        wall = HouseBuilder::EditWallTool.get_selected_wall
        if (wall)
            submenu = menu.add_submenu("Edit Wall") { HouseBuilder::EditWallTool.edit_wall }
            submenu.add_item("-- WALLS --")            { }
            submenu.add_item("Change Wall Properties"){ HouseBuilder::EditWallTool.show_prop_dialog }
            submenu.add_item("Move Wall")             { HouseBuilder::EditWallTool.move }
            submenu.add_item("-- WINDOWS --")         { }
            submenu.add_item("Add Window")            { Sketchup.active_model.select_tool HouseBuilder::WindowTool.new(wall) }    
            submenu.add_item("Change Window Properties"){ Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "CHANGE_PROPERTIES") }          
            submenu.add_item("Move Window")             { Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "MOVE") }          
            submenu.add_item("Delete Window")           { Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Window", "DELETE") }   
            submenu.add_item("-- DOORS --")            { }
            submenu.add_item("Add Door")              { Sketchup.active_model.select_tool HouseBuilder::DoorTool.new(wall) }          
            submenu.add_item("Change Door Properties"){ Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "CHANGE_PROPERTIES") }          
            submenu.add_item("Move Door")             { Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "MOVE") }          
            submenu.add_item("Delete Door")           { Sketchup.active_model.select_tool HouseBuilder::EditOpeningTool.new(wall, "Door", "DELETE") }          
        end
    end
end

file_loaded("HouseBuilderTool.rb")
