# Copyright (C) 2022 Kent Kruckeberg
# See LICENSE for details.

# Copyright (C) 2014 Mike Morrison
# Copyright 2005 Steve Hurlbut, D.Bur

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

require 'sketchup.rb'

Sketchup::require 'StructureBuilder/StructureBuilderDefaults'
Sketchup::require 'StructureBuilder/StructureBuilder'

module StructureBuilder

# these are the states that a tool can be in
STATE_EDIT = 0 if not defined? STATE_EDIT
STATE_PICK = 1 if not defined? STATE_PICK
STATE_PICK_NEXT = 2 if not defined? STATE_PICK_NEXT
STATE_PICK_LAST = 3 if not defined? STATE_PICK_LAST
STATE_MOVING = 4 if not defined? STATE_MOVING
STATE_SELECT = 5 if not defined? STATE_SELECT


def self.min(x, y)
    if (x < y)
        return x
    end
    return y
end

def self.max(x, y)
    if (x > y) 
        return x
    end
    return y
end

# display an input dialog and store the results in an object
def self.display_dialog(title, obj, data)
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
def self.display_global_options_dialog()
	parameters = [
	    # prompt, attr_name, value, enums
	    [ "Wall Lumber Size", "wall.style", SBDEFAULTS[StructureBuilder.units]['wall']['lumber_sizes'].join("|") ],
	    [ "Wall Plate Height", "wall.height", nil ],
	    [ "Wall Justification  ", "window.justify",  "left|center|right" ],
	    [ "Wall Stud Spacing", "wall.stud_spacing", nil ],
	    [ "Roof Joist Spacing", 'roof.joist_spacing', nil ],
	 	[ "Floor Joist Spacing", 'floor.joist_spacing', nil ],
		[ "On-Center Spacing", "on_center_spacing", "true|false"],
	    [ "Header Size", "header_style", SBDEFAULTS[StructureBuilder.units]['global']['header_sizes'].join("|") ],
	    [ "Door Header Height", "door.header_height", nil ],
	    [ "Door Justification  ", "door.justify",  "left|center|right" ],
	    [ "Window Header Height", "window.header_height", nil ],
	    [ "Window Justification  ", "window.justify",  "left|center|right" ],
	    [ "Roof Pitch", "pitch",  nil ],
	   ]
    prompts = []
    attr_names = []
    values = []
    enums = []
    parameters.each { |a| prompts.push(a[0]); attr_names.push(a[1]); values.push(BaseBuilder.get_global_option(a[1])); enums.push(a[2]) }
    results = UI.inputbox(prompts, values, enums, 'Global Properties')
    if results
        i = 0
        attr_names.each do |name|
            BaseBuilder.set_global_option(name,results[i])
            i = i + 1
        end
    end
    return results
end

# draw a 2D rectangle at the base of a wall
def self.draw_outline(view, start_pt, end_pt, width, wall_justify, color, line_width=1)
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
def self.draw_rect_outline(view, start_pt, end_pt, color)
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

def self.create_wall_from_drawing(group)
    name = group.get_attribute("einfo", "name")
    if (name =~ /_skin/)
        name.sub!('_skin', '')
        group = BaseBuilder.find_named_entity(name)
    end
    case group.get_attribute("einfo", "type")
    when "wall"
	    wall = Wall.create_from_drawing(group) 
	when "GableWall" 
	    wall = GableWall.create_from_drawing(group) 
	when "rakewall" 
	    wall = GableWall.create_from_drawing(group) 
	else
	    UI.messagebox "unknown wall type"
	end
	return wall
end
    	
    	
# minimum amount of wall before a window or door opening
# FIXME: this should probably be 2xstud_z_size?
MIN_WALL = 3 if not defined? MIN_WALL


#--------  W A L L T O O L  ------------------------------------------------

# This class is used to draw a wall. It will display a properties dialog and
# then allow you to draw one or more walls using those properties. Press
# ESCAPE to exit the tool.
class WallTool

	attr_reader :properties
	   
def initialize()
	@properties = [
		# prompt, attr_name, enums
		[ "Wall Justification  ", "justify", "left|center|right" ],
		[ "Lumber Size", "style", SBDEFAULTS[StructureBuilder.units]['wall']['lumber_sizes'].join("|") ],
		[ "Plate Height", "height", nil ],
		[ "Stud Spacing", "stud_spacing", nil ],
		[ "Bottom Plate Count  ", "bottom_plate_count", "0|1" ],
		[ "Top Plate Count", "top_plate_count", "0|1|2" ],
	   ]

	@wall = Wall.new() 
	results = StructureBuilder.display_dialog("Wall Properties", @wall, @properties)
	return false if not results
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
    puts "activate wall tool" if VERBOSE
    @ip1 = Sketchup::InputPoint.new
    @ip = Sketchup::InputPoint.new
    self.reset
end

def deactivate(view)
    puts "deactivate wall tool" if VERBOSE
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
	puts "vec = " + vec.inspect if VERBOSE
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
	puts "draw wall from " + @pts[0].to_s + " to " + @pts[1].to_s + " angle " + new_wall.angle.to_s if VERBOSE
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
    puts "on cancel" if VERBOSE
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
		#puts "wall width3: " + @wall.width.to_s + " " + @wall.width.class.to_s
        (@offset_pt0, @offset_pt1) = StructureBuilder.draw_outline(view, @pts[0], @pts[1], @wall.width, @wall.justify, "gray")
        @drawn = true
    end
end

end # class WallTool

#--------  G A B L E W A L L T O O L  ------------------------------------------------

# Draw a gable wall
class GableWallTool < WallTool

	attr_reader :properties

def initialize()
	@properties = [
		# prompt, attr_name, value, enums
		[ "Pitch", "pitch", nil ],
		[ "Roof type", 'roof_type', "gable|shed" ],
		[ "Wall Justification  ", "justify", "left|center|right" ],
		[ "Lumber Size", "style", SBDEFAULTS[StructureBuilder.units]['wall']['lumber_sizes'].join("|") ],
		[ "Plate Height", "height", nil ],
		[ "Stud Spacing", "stud_spacing", nil ],
		[ "Bottom Plate Count  ", "bottom_plate_count", "0|1" ],
		[ "Top Plate Count", "top_plate_count", "0|1|2" ],
	]

	@wall = GableWall.new() 
	results = StructureBuilder.display_dialog("Gable Wall Properties", @wall, @properties)
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
        
        @wall = StructureBuilder.create_wall_from_drawing(@group)
        
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
    puts "EditWallTool: activate" if VERBOSE
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
        if ((point.y > StructureBuilder.min(obj_start.y, obj_end.y)) &&
            (point.y < StructureBuilder.max(obj_start.y, obj_end.y)) &&
            (point.x > StructureBuilder.min(obj_start.x, obj_start_offset.x)) &&
            (point.x < StructureBuilder.max(obj_start.x, obj_start_offset.x)))
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
	puts "draw wall from " + @pts[0].to_s + " to " + @pts[1].to_s + " angle " + @wall.angle.to_s if VERBOSE
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
    puts "edit object #{obj}" if VERBOSE
    Sketchup.active_model.select_tool EditOpeningTool.new(self, obj)
end

def self.show_prop_dialog
    tool = EditWallTool.new(nil)
    if (tool.wall.kind_of?(GableWall))
		gabletool = GableWallTool.new
        results = StructureBuilder.display_dialog("Gable Wall Properties", tool.wall, gabletool.properties)
    else
		walltool = WallTool.new
        results = StructureBuilder.display_dialog("Wall Properties", tool.wall, walltool.properties)
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
    (a, b) = StructureBuilder.draw_outline(view, @pts[0], @pts[1], @wall.width, @wall.justify, "gray")
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
            StructureBuilder.draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "red", 3)
        else
            StructureBuilder.draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
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

	attr_reader :properties

def initialize(wall_group)
	@properties = [
		# prompt, attr_name, value, enums
		[ "Offset Justification  ", "justify", "left|center|right" ],
		[ "Header Height", "header_height", nil ],
		[ "Header Size", "header_style", SBDEFAULTS[StructureBuilder.units]['global']['header_sizes'].join("|") ],
		[ "Sill Size", "sill_style", SBDEFAULTS[StructureBuilder.units]['window']['sill_sizes'].join("|") ],
		[ "Width", "width", nil ],
		[ "Height", "height", nil ],
	]
	   
	@wall = StructureBuilder.create_wall_from_drawing(wall_group)
	@obj = Window.new(@wall)
    @objtype = "Wall"
end

def show_dialog
	results = StructureBuilder.display_dialog("Window Properties", @obj, @properties)
	if results
		reset()
		return true
	else
		return false
	end
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
	puts "cancel door/wall" if VERBOSE
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
    StructureBuilder.draw_outline(view, @wall.origin, @wall.endpt, @wall.width, @wall.justify, "gray")
    vec = @end_pt - @start_pt
    # draw the outline of each door and window
    @wall.objects.each do |obj|
        vec.length = obj.center_offset - obj.width/2
        obj_start = @wall.origin + vec
        vec.length = obj.width
        obj_end = obj_start + vec
        StructureBuilder.draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
    end
    StructureBuilder.draw_outline(view, @start_pt, @end_pt, @wall.width, @wall.justify, "orange", 2)
    @drawn = true
end

end # class WindowTool

#--------  D O O R T O O L  ------------------------------------------------

# Add a door to a wall. This tool displays a door property dialog and then 
# allows the user to place the door using the mouse. Click the mouse when the
# door is in the correct position.
class DoorTool < WindowTool
	   
	attr_reader :properties

def initialize(wall_group)
	@properties = [
		# prompt, attr_name, value, enums
		[ "Offset Justification  ", "justify", "left|center|right" ],
		[ "Header Height", "header_height", nil ],
		[ "Header Size", "header_style", SBDEFAULTS[StructureBuilder.units]['global']['header_sizes'].join("|") ],
		[ "Width", "width", nil ],
		[ "Height", "height", nil ],
	]

	@wall = StructureBuilder.create_wall_from_drawing(wall_group)
	@obj = Door.new(@wall)
	@objtype = "Door"
end

def show_dialog
	results = StructureBuilder.display_dialog("Door Properties", @obj, @properties)
	if results
		reset()
		return true
	else
		return false
	end
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
	@wall = StructureBuilder.create_wall_from_drawing(wall_group)
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
        if ((point.y > StructureBuilder.min(obj_start.y, obj_end.y)) &&
            (point.y < StructureBuilder.max(obj_start.y, obj_end.y)) &&
            (point.x > StructureBuilder.min(obj_start.x, obj_start_offset.x)) &&
            (point.x < StructureBuilder.max(obj_start.x, obj_start_offset.x)))
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
	puts "cancel edit #{@objtype}" if VERBOSE
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
    puts "executing operation #{@operation}" if VERBOSE
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
		windowtool = WindowTool.new
        results = StructureBuilder.display_dialog("Window Properties", @selected_obj, windowtool.properties)
    when "Door"
		doortool = DoorTool.new
        results = StructureBuilder.display_dialog("Door Properties", @selected_obj, doortool.properties)
    end
	if (results)
        draw_obj
    end
    #Sketchup.active_model.select_tool(nil)
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
    (a, b) = StructureBuilder.draw_outline(view, @corners[0], @corners[1], @wall.width, @wall.justify, "gray")
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
                StructureBuilder.draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "red", 3)
            end
        else
            StructureBuilder.draw_outline(view, obj_start, obj_end, @wall.width, @wall.justify, "gray")
        end
    end
    if (@state == STATE_MOVING)
        StructureBuilder.draw_outline(view, @start_pt, @end_pt, @wall.width, @wall.justify, "red", 2)
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
	attr_reader :properties
    
def initialize()
	@properties = [
		# prompt, attr_name, value, enums
		[ "Type", "roof_style", "gable|shed" ],
		[ "Lumber Size", "style", SBDEFAULTS[StructureBuilder.units]['roof']['lumber_sizes'].join("|") ],
		[ "Joist Spacing", "joist_spacing", nil ],
		[ "Pitch", "pitch", nil ],
		[ "Overhang", "overhang", nil ],
		[ "Rake Overhang", "rake_overhang", nil ],
	]
    @tool_name = "ROOFTOOL"
    wall = Wall.new()
	@obj = Roof.new(wall) 
	results = StructureBuilder.display_dialog("Roof Properties", @obj, @properties)
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
    puts "reset" if VERBOSE
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
	puts "draw from " + @pts[0].to_s + " to " + @pts[2].to_s if VERBOSE
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

	attr_reader :properties
	   
def initialize()
	@properties= [
		# prompt, attr_name, value, enums
		[ "Lumber Size", "style", SBDEFAULTS[StructureBuilder.units]['floor']['lumber_sizes'].join("|") ],
		[ "Joist Spacing", "joist_spacing", nil ],
	]

    @tool_name = "FLOORTOOL"
	@obj = Floor.new() 
	results = StructureBuilder.display_dialog("Floor Properties", @obj, @properties)
	return false if not results
	reset
	@type = "floor"
end

end # class FloorTool



# --------  E S T I M A T E  ------------------------------------------------

def self.sb_estimate
	model=Sketchup.active_model
	view=model.active_view
	ents=model.entities
	walls_array = []
	skins_array = []
	floors_array = []
	gables_array = []
	roofs_array = []

	# Output file
	file_name = ""
	if Sketchup.active_model.title != ""
		file_name = Sketchup.active_model.title + "_"
	end
	file_name = file_name + "estimates.txt"

	export_file = File.new( file_name , "w" )
	# Search and sort groups
	ents.each do |e|
		if e.typename == "Group" and e.attribute_dictionary "einfo"
			attrs = (e.attribute_dictionary "einfo").size
			type = e.get_attribute('einfo','type')
			case type
			when 'wall' 
				if (e.get_attribute('einfo','name') =~ /_skin/)
					skins_array.push e
				else
					walls_array.push e
				end
			when 'floor' 
				floors_array.push e
			when 'GableWall' 
				if (e.get_attribute('einfo','name') =~ /_skin/)
					skins_array.push e
				else
					gables_array.push e
				end
			when 'roof'
				roofs_array.push e
				#else
				#puts "Unknown StructureBuilder object type."
			end
		end
	end

	export_file.puts "Walls: " + walls_array.length.to_s
	export_file.puts "Gabbles: " + gables_array.length.to_s
	export_file.puts "Floors: " + floors_array.length.to_s
	export_file.puts "Skins: " + skins_array.length.to_s
	export_file.puts "Roofs: " + roofs_array.length.to_s

	# Rect walls
	export_file.puts "_____________________________"
	export_file.puts " RECTANGULAR WALLS"
	export_file.puts "_____________________________"
	export_file.puts ""

	walls_array.each do |w|
		ad = w.attribute_dictionary "einfo"
		#Compute stud length ratio per ^2
		slr = (stud_length_ratio ad)
		# Check for doors and windows
		objects = ad["object_names"]
		# Related skin group
		skin_group = find_skin_group( ad["name"] )

		# Output
		export_file.puts "Wall ID:\t\t\t" + ad["name"]
		export_file.puts "Lumber section:\t\t" + ad["style"]
		export_file.puts "Start point:\t\t" + ad["origin"].to_s
		export_file.puts "End point:\t\t" + ad["endpt"].to_s
		export_file.puts "Length:\t\t\t" + ad["length"].to_s + ", " + ad["justify"] + " justified"
		export_file.puts "Height:\t\t\t" + ad["height"].to_s
		export_file.puts "Width:\t\t\t" + ad["width"].to_s
		export_file.puts "Bottom plates:\t\t" + ad["bottom_plate_count"].to_s
		export_file.puts "Top plates:\t\t" + ad["top_plate_count"].to_s
		export_file.puts "Stud spacing:\t\t" + ad["stud_spacing"].to_s
		export_file.puts "Stud height:\t\t" + (rect_walls_stud_height ad).to_s
		export_file.puts "Total plates length:\t\t" + ((ad["bottom_plate_count"]*ad["length"]) + (ad["top_plate_count"]*ad["length"])).to_s
		export_file.puts "Total studs length:\t\t" + (rect_walls_total_stud_length ad).to_s
		#export_file.puts "Objects:\t" + objects.gsub("|"," ")
		if skin_group
			export_file.puts "Siding surface:\t\t" + skin_area(skin_group).to_s + "^2"
		else
			export_file.puts "No siding skin found for " + ad["name"]
		end
		export_file.puts "_____________________________"
	end

	# Gabble walls
	export_file.puts " GABLE WALLS"
	export_file.puts "_____________________________"
	export_file.puts ""

	gables_array.each do |w|
		ad = w.attribute_dictionary "einfo"
		#puts ad.keys
		# Compute stud length ratio per ^2
		slr = (stud_length_ratio ad)
		# top plate length
		tpl = (gable_top_plate_length ad["length"], ad["pitch"])
		# Check for doors and windows
		objects = ad["object_names"]
		# Related skin group
		skin_group = find_skin_group( ad["name"] )

		# Output
		export_file.puts "Wall ID:\t\t\t" + ad["name"]
		export_file.puts "Lumber section:\t\t" + ad["style"]
		export_file.puts "Start point:\t\t" + ad["origin"].to_s
		export_file.puts "End point:\t\t" + ad["endpt"].to_s
		export_file.puts "Length:\t\t\t" + ad["length"].to_s + ", " + ad["justify"] + " justified"
		export_file.puts "Height:\t\t\t" + ad["height"].to_s
		export_file.puts "Width:\t\t\t" + ad["width"].to_s
		export_file.puts "Type:\t\t\t" + ad["roof_type"]
		export_file.puts "Roof slope:\t\t" + ad["pitch"].to_s + "°"
		export_file.puts "Bottom plate:\t\t" + ad["bottom_plate_count"].to_s
		export_file.puts "Top plate:\t\t" + ad["top_plate_count"].to_s
		export_file.puts "Stud spacing:\t\t" + ad["stud_spacing"].to_s
		export_file.puts "Top plates length:\t\t" + (ad["top_plate_count"]*tpl).to_s
		export_file.puts "Bot. plates length:\t\t" + (ad["bottom_plate_count"]*ad["length"].to_l).to_s
		export_file.puts "Total studs length:\t\t" + (gables_total_stud_length ad).to_s
		#export_file.puts "Objects:\t" + objects.gsub("|"," ")
		if skin_group
			export_file.puts "Siding surface:\t\t" + skin_area(skin_group).to_s + "^2"
		else
			export_file.puts "No siding skin found for " + ad["name"]
		end
		export_file.puts "_____________________________"
	end

	# Floors
	export_file.puts " FLOORS"
	export_file.puts "_____________________________"
	export_file.puts ""

	floors_array.each do |f|
		ad = f.attribute_dictionary "einfo"
		#puts ad.keys
		# Compute surface
		surf = (floor_surface ad)
		# Compute total joists length
		joists_length = (floor_total_joist_length ad)
		# Output
		export_file.puts "Floor ID:\t\t\t" + ad["name"]
		export_file.puts "Joist section:\t\t" + ad["style"]
		export_file.puts "Joist spacing:\t\t" + ad["joist_spacing"].to_s
		export_file.puts "Total joists length:\t\t" + joists_length.to_s
		export_file.puts "Surface:\t\t\t" + surf.to_s + " ^2"
		export_file.puts "_____________________________"

	end

	# Roofs
	export_file.puts " ROOFS"
	export_file.puts "_____________________________"
	export_file.puts ""

	roofs_array.each do |r|
		ad = r.attribute_dictionary "einfo"
		# Compute projected base surface
		base_surf = (roof_base_proj_surface ad)
		# Compute projected total surface
		tot_surf = (roof_tot_proj_surface ad)
		# Compute real total surface
		real_surf = (roof_real_surface ad)
		# Compute joists length
		joists_length = (roof_total_joist_length ad)

		# Output
		export_file.puts "Roof ID:\t\t\t" + ad["name"]
		export_file.puts "Roof type:\t\t" + ad["roof_style"]
		export_file.puts "Slope:\t\t\t" + ad["pitch"].to_s + "°"
		export_file.puts "Framing:\t\t\t" + ad["framing"]
		export_file.puts "Joist spacing:\t\t" + ad["joist_spacing"].to_s
		export_file.puts "Overhang:\t\t" + ad["overhang"].to_s
		export_file.puts "Rake overhang:\t\t" + ad["rake_overhang"].to_s
		export_file.puts "Base proj. surface:\t\t" + base_surf.to_s + "^2"
		export_file.puts "Total proj. surface:\t\t" + tot_surf.to_s + "^2"
		export_file.puts "Total surface:\t\t" + real_surf.to_s + "^2"
		export_file.puts "Ridge and banks:\t\t" + joists_length[0].to_s
		export_file.puts "Total joists length:\t\t" + joists_length[1].to_s
	end

	export_file.close
	UI.openURL(file_name)
end

#------------------------------ Skin related
def self.find_skin_group( wall )
	skin_group = wall + "_skin"
	res_group = nil
	Sketchup.active_model.entities.each do |e|
		if (e.kind_of?(Sketchup::Group))
			n = e.get_attribute('einfo', 'name')
			if (n && (n == skin_group))
				res_group = e
				break
			end
		end
	end
	return res_group
end

def self.skin_area ( skin_group )
	ents = skin_group.entities
	surfs = []
	ents.each do |e|
		if (e.kind_of?(Sketchup::Face))
			surfs.push e.area
		end
	end
	return surfs.sort.reverse[0]/1550.0031000062
end
#------------------------------ Floor related
def self.floor_surface( d )
	wid = d["corner1"].distance d["corner2"]
	len = d["corner1"].distance d["corner4"]
	srf = (len*wid) / 1550.0031000062
	#puts srf.to_s
	return srf
end

def self.floor_total_joist_length( d )
	spacing = d["joist_spacing"]
	joist_length = d["corner1"].distance d["corner2"]
	floor_length = d["corner1"].distance d["corner4"]
	#puts "JL: " + joist_length.to_s
	#puts "FL: " + floor_length.to_s
	n_joists = (floor_length / spacing).ceil + 1
	#puts n_joists.to_s
	return (n_joists*joist_length).to_l.ceil
end

#------------------------------ Wall related
def self.stud_length_ratio( d )
	spacing = d["stud_spacing"].to_l
	ratio = (((d["length"].to_l / spacing)+1) / d["length"].to_l)
	#puts ratio.to_s
end

def self.rect_walls_stud_height( d )
	interval = d["stud_spacing"]
	total_height = d["height"].to_l
	thick = d["style"].split("x")[0].to_f
	stud_thick = thick / 10.0
	return total_height - (d["bottom_plate_count"]*stud_thick) - (d["top_plate_count"]*stud_thick)
end

def self.gable_walls_average_stud_height( d )
	type = d["roof_type"]
	interval = d["stud_spacing"]
	low_height = d["height"].to_l
	ang = d["pitch"].degrees
	thick = d["style"].split("x")[0].to_f
	stud_thick = thick / 10.0
	wl = d["length"].to_l

	case type
	when "gable"
		high_height = low_height + ((wl/2.0)*Math.tan(ang))
		#puts "HH gable" + high_height.to_s
	when "shed"
		high_height = low_height + (wl*Math.tan(ang))
		#puts "HH shed " + high_height.to_s
	end
	ret = (((high_height + low_height)/2.0) - (d["bottom_plate_count"]*stud_thick) - (d["top_plate_count"]*stud_thick))
	#puts "average H " + ret.to_s
	return ret

end

def self.rect_walls_total_stud_length( d )
	sh = rect_walls_stud_height( d )
	wl = d["length"].to_l
	spacing = d["stud_spacing"].to_l
	n_studs = (wl / spacing).ceil + 1
	return n_studs*sh
end
#------------------------------ Gable related
def self.gables_total_stud_length( d )
	sh = gable_walls_average_stud_height( d )
	spacing = d["stud_spacing"]
	wl = d["length"]
	n_studs = (wl / spacing).ceil + 1
	#puts n_studs.to_s
	return n_studs*sh
end

def self.gable_top_plate_length( w_length, pitch )
	ang = pitch.degrees
	#puts ang.to_s
	#puts w_length.class
	return w_length.to_l / Math.cos(ang).abs
end

#------------------------------ Roof related
def self.roof_base_proj_surface( d )
	wid = d["corner1"].distance d["corner2"]
	len = d["corner1"].distance d["corner4"]
	srf = (len*wid) / 1550.0031000062
	return srf
end

def self.roof_tot_proj_surface( d )
	wid = d["corner1"].distance d["corner2"]
	len = d["corner1"].distance d["corner4"]
	over1 = d["overhang"]
	over2 = d["rake_overhang"]
	tot_wid = wid + (2*over1)
	tot_len = len + (2*over2)
	srf = (tot_len*tot_wid) / 1550.0031000062
	return srf
end

def self.roof_real_surface( d )
	ang = d["pitch"].degrees
	wid = d["corner1"].distance d["corner2"]
	len = d["corner1"].distance d["corner4"]
	over1 = d["overhang"]
	over2 = d["rake_overhang"]
	tot_wid = (wid + (2*over1)) / Math.cos(ang).abs
	tot_len = len + (2*over2)
	srf = (tot_len*tot_wid) / 1550.0031000062
	return srf
end

def self.roof_total_joist_length( d )
	ang = d["pitch"].degrees
	spacing = d["joist_spacing"]
	wid = d["corner1"].distance d["corner2"]
	len = d["corner1"].distance d["corner4"]
	over1 = d["overhang"]
	over2 = d["rake_overhang"]
	tot_wid = (wid + (2*over1)) / Math.cos(ang).abs
	tot_len = len + (2*over2)
	n_joists = (tot_len / spacing).ceil + 2
	#puts "NJ " + n_joists.to_s
	#puts "TW " + tot_wid.to_cm.to_s
	return [(tot_len*3).to_l, (tot_wid*n_joists).to_l] 
end


#------------------------------ Label SB objects
def self.sb_tag_objects
	model=Sketchup.active_model
	view=model.active_view
	ents=model.entities
	sb_array = []
	ss = model.selection
	ss.clear
	# Erase previous tags if any
	tag_layer = model.layers.add("SB_tags")
	if tag_layer
		ents.each do |e|
			if e.layer.name == "SB_tags"
				ss.add e
			end
		end
		ss.each do |e|
			e.erase!
		end
	end
	# Set SB_tag layer current
	old_layer = model.active_layer
	model.active_layer = "SB_tags"
	# Search SB groups
	ents.each do |e|
		if e.typename == "Group" and e.attribute_dictionary "einfo"
			sb_array.push e
		end
	end
	# Put a text label from bounding box center with object ID
	sb_array.each do |w|
		ad = w.attribute_dictionary "einfo"
		id = ad["name"]
		center = w.bounds.center
		if id
			if id["_skin"]
				Sketchup.active_model.entities.add_text id, center, Geom::Vector3d.new(50.cm,-50.cm,50.cm)
			else
				Sketchup.active_model.entities.add_text id, center, Geom::Vector3d.new(-50.cm,-50.cm,50.cm)
			end
		end
	end
	# Restore previous layer
	model.active_layer = old_layer
end


#-----------------------------------------------------------------------------
# Add a menu items
if (not file_loaded?("StructureBuilder/StructureBuilderTool.rb"))
    submenu = UI.menu("Draw").add_submenu("Structure Builder")
    submenu.add_item("Wall Tool") { Sketchup.active_model.select_tool WallTool.new }    
    submenu.add_item("Gable Wall Tool") { Sketchup.active_model.select_tool GableWallTool.new }
    submenu.add_item("Roof Tool") { Sketchup.active_model.select_tool RoofTool.new }
    submenu.add_item("Floor Tool") { Sketchup.active_model.select_tool FloorTool.new }
    submenu.add_item("Change Global Properties") { display_global_options_dialog }
    #submenu.add_item("Reload Tools") { load "StructureBuilder.rb"; load "StructureBuilderTool.rb" }
    
    # Add a context menu handler to let you edit a Wall
    UI.add_context_menu_handler do |menu|
        wall = EditWallTool.get_selected_wall
        if (wall)
            submenu = menu.add_submenu("Edit Wall"){ EditWallTool.edit_wall }

            submenu.add_item("Move Wall")             { EditWallTool.move }
            submenu.add_item("Wall Properties"){ EditWallTool.show_prop_dialog }
			submenu.add_separator()
			cmd = UI::Command.new(("Insert Window")) {
				windowtool = WindowTool.new(wall)
				if windowtool.show_dialog()
					Sketchup.active_model.select_tool windowtool
				end
			}

            submenu.add_item(cmd)
            submenu.add_item("Change Window Properties"){ Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "CHANGE_PROPERTIES") }          
            submenu.add_item("Move Window")             { Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "MOVE") }          
            submenu.add_item("Delete Window")           { Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "DELETE") }   
			submenu.add_separator()
			cmd = UI::Command.new(("Insert Door")) {
				doortool = DoorTool.new(wall)
				if doortool.show_dialog()
					Sketchup.active_model.select_tool doortool
				end
			}
            submenu.add_item(cmd)
            submenu.add_item("Change Door Properties"){ Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "CHANGE_PROPERTIES") }          
            submenu.add_item("Move Door")             { Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "MOVE") }          
            submenu.add_item("Delete Door")           { Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "DELETE") }          
        end
    end
#-----------------------------------------------------------------------------------------------------
#                                        MENU ITEMS
#-----------------------------------------------------------------------------------------------------
	#Structure builder toolbar
	#-----------------------------------------------------------------------------------------
	sb_tb = UI::Toolbar.new("Structure Builder")

	icon_path = File.join Sketchup.find_support_file("Plugins"), "StructureBuilder"

	# Global settings
	cmd = UI::Command.new(("Global settings")) {
		display_global_options_dialog
	}
	cmd.small_icon = File.join icon_path, "hb_globalsettings_S.png"
	cmd.large_icon = File.join icon_path, "hb_globalsettings_L.png"
	cmd.tooltip = "Change global settings"
	sb_tb.add_item(cmd)

	sb_tb.add_separator()

	# Floor tool
	cmd = UI::Command.new(("Floor tool")) { 
		Sketchup.active_model.select_tool FloorTool.new
	}
	cmd.small_icon = File.join icon_path, "hb_floortool_S.png"
	cmd.large_icon = File.join icon_path, "hb_floortool_L.png"
	cmd.tooltip = "Creates a floor."
	sb_tb.add_item(cmd)

	# Wall tool
	cmd = UI::Command.new(("Wall tool")) {
		Sketchup.active_model.select_tool WallTool.new
	}
	cmd.small_icon = File.join icon_path, "hb_walltool_S.png"
	cmd.large_icon = File.join icon_path, "hb_walltool_L.png"
	cmd.tooltip = "Creates a wall."
	sb_tb.add_item(cmd)

	# Gable Wall tool
	cmd = UI::Command.new(("Gable Wall tool")) {
		Sketchup.active_model.select_tool GableWallTool.new
	}
	cmd.small_icon = File.join icon_path, "hb_gablewalltool_S.png"
	cmd.large_icon = File.join icon_path, "hb_gablewalltool_L.png"
	cmd.tooltip = "Creates a gable wall."
	sb_tb.add_item(cmd)

	# Roof tool
	cmd = UI::Command.new(("Roof tool")) {
		Sketchup.active_model.select_tool RoofTool.new
	}
	cmd.small_icon = File.join icon_path, "hb_rooftool_S.png"
	cmd.large_icon = File.join icon_path, "hb_rooftool_L.png"
	cmd.tooltip = "Creates a roof."
	sb_tb.add_item(cmd)

	sb_tb.add_separator()

	# Change Wall properties
	cmd = UI::Command.new(("Edit Wall")) {
		if (check_for_wall_selection)
			EditWallTool.show_prop_dialog 
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
	cmd.small_icon = File.join icon_path, "hb_changewallproperties_S.png"
	cmd.large_icon = File.join icon_path, "hb_changewallproperties_L.png"
	cmd.tooltip = "Change Wall properties."
	sb_tb.add_item(cmd)

	# Move Wall
	cmd = UI::Command.new(("Move Wall")) {
		if (check_for_wall_selection)
			EditWallTool.move
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
	cmd.small_icon = File.join icon_path, "hb_movewall_S.png"
	cmd.large_icon = File.join icon_path, "hb_movewall_L.png"
	cmd.tooltip = "Move, rotate or extent Wall."
	sb_tb.add_item(cmd)

	sb_tb.add_separator()


	# Insert window
	cmd = UI::Command.new(("Insert window")) {
		if wall = (check_for_wall_selection)
			windowtool = WindowTool.new(wall)
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
	cmd.small_icon = File.join icon_path, "hb_addwindow_S.png"
	cmd.large_icon = File.join icon_path, "hb_addwindow_L.png"
	cmd.tooltip = "Insert a window into a wall"
	sb_tb.add_item(cmd)

	# Change window properties
	cmd = UI::Command.new(("Change window properties in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "CHANGE_PROPERTIES")
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
	cmd.small_icon = File.join icon_path, "hb_changewindowproperties_S.png"
	cmd.large_icon = File.join icon_path, "hb_changewindowproperties_L.png"
	cmd.tooltip = "Change window properties in a wall"
	sb_tb.add_item(cmd)

	# Move window
	cmd = UI::Command.new(("Move window in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "MOVE")
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
	cmd.small_icon = File.join icon_path, "hb_movewindow_S.png"
	cmd.large_icon = File.join icon_path, "hb_movewindow_L.png"
	cmd.tooltip = "Move window in a wall"
	sb_tb.add_item(cmd)

	# Delete window
	cmd = UI::Command.new(("Delete window in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Window", "DELETE")
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
	cmd.small_icon = File.join icon_path, "hb_deletewindow_S.png"
	cmd.large_icon = File.join icon_path, "hb_deletewindow_L.png"
	cmd.tooltip = "Delete window in a wall"
	sb_tb.add_item(cmd)

	sb_tb.add_separator()

	# Insert door
	cmd = UI::Command.new(("Insert door")) {
		if wall = (check_for_wall_selection)
			doortool = DoorTool.new(wall)
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
	cmd.small_icon = File.join icon_path, "hb_adddoor_S.png"
	cmd.large_icon = File.join icon_path, "hb_adddoor_L.png"
	cmd.tooltip = "Insert a door into a wall"
	sb_tb.add_item(cmd)

	# Change door properties
	cmd = UI::Command.new(("Change door properties in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "CHANGE_PROPERTIES")
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
	cmd.small_icon = File.join icon_path, "hb_changedoorproperties_S.png"
	cmd.large_icon = File.join icon_path, "hb_changedoorproperties_L.png"
	cmd.tooltip = "Change door properties in a wall"
	sb_tb.add_item(cmd)

	# Move door
	cmd = UI::Command.new(("Move door in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "MOVE")
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
	cmd.small_icon = File.join icon_path, "hb_movedoor_S.png"
	cmd.large_icon = File.join icon_path, "hb_movedoor_L.png"
	cmd.tooltip = "Move door in a wall"
	sb_tb.add_item(cmd)

	# Move door
	cmd = UI::Command.new(("Delete door in a wall")) {
		if wall = (check_for_wall_selection)
			Sketchup.active_model.select_tool EditOpeningTool.new(wall, "Door", "DELETE")
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
	cmd.small_icon = File.join icon_path, "hb_deletedoor_S.png"
	cmd.large_icon = File.join icon_path, "hb_deletedoor_L.png"
	cmd.tooltip = "Delete door in a wall"
	sb_tb.add_item(cmd)

	sb_tb.add_separator()

	# Tag
	cmd = UI::Command.new(("Tag SB objects")) {
		sb_tag_objects
	}
	cmd.small_icon = File.join icon_path, "hb_tag_S.png"
	cmd.large_icon = File.join icon_path, "hb_tag_L.png"
	cmd.tooltip = "Tag all StructureBuilder objects"
	sb_tb.add_item(cmd)

	# Estimates
	cmd = UI::Command.new(("Estimates")) {
		sb_estimate
	}
	cmd.small_icon = File.join icon_path, "hb_estimate_S.png"
	cmd.large_icon = File.join icon_path, "hb_estimate_L.png"
	cmd.tooltip = "Estimates"
	sb_tb.add_item(cmd)

	sb_tb.add_separator()

	# Credits
	cmd = UI::Command.new(("About...")) {(sb_credits)}
	cmd.small_icon = File.join icon_path, "hb_credits_S.png"
	cmd.large_icon = File.join icon_path, "hb_credits_L.png"
	cmd.tooltip = "Credits"
	sb_tb.add_item(cmd)


	# End of load
end

end # module StructureBuilder

file_loaded("StructureBuilder/StructureBuilderTool.rb")
