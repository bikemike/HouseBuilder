# Copyright (C) 2014 Mike Morrison
# See LICENSE file for details.

# Copyright 2005 Steve Hurlbut, D. Bur
# Copyright 2005 Steve Hurlbut

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

# Some bugfixes (in particular to doors) by tim Rowledge Mar 2010

require 'sketchup.rb'
require 'mm_HouseBuilder/HouseBuilderDefaults.rb'

module MM_HouseBuilder

# set to true for debug output to console
VERBOSE = false


def self.hb_credits
	credits = ""
	#credits += House_Builder_Extension.name + " " + House_Builder_Extension.version + "\n"
	#credits += "Copyright (C) " + House_Builder_Extension.copyright + "\n"
	credits += @@mm_HouseBuilderExtension.description + "\n\n"
	credits += "Mike Morrison - 2014\nBug fixes, merge of metric and imperial versions, and other updates.\n\n"
	credits += "Tim Rowledge - 2010\nBug fixes (in particular to doors).\n\n"
	credits += "D. Bur - 2007\nToolbar, metric version, estimates, tags.\n\n"
	credits += "Steve Hurlbut - 2005\nOriginal program."
	UI.messagebox(credits, MB_MULTILINE, @@mm_HouseBuilderExtension.name + " " + @@mm_HouseBuilderExtension.version)
end

def self.check_for_wall_selection
wall = EditWallTool.get_selected_wall
return wall
end

# This is an example of an observer that watches the options provider.
class HouseBuilderOptionsProviderObserver < Sketchup::OptionsProviderObserver
	# UnitsOptions, LengthUnit
	def onOptionsProviderChanged(provider, name)
		if (name.to_s == "LengthUnit")
			unit_type = provider["LengthUnit"]
			MM_HouseBuilder.hb_update_config(unit_type)
		end
	end
end

# This is an example of an observer that watches the application for
# new models and shows a messagebox.
class HouseBuilderAppObserver < Sketchup::AppObserver
	def onNewModel(model)
		options_provider = Sketchup.active_model.options["UnitsOptions"]
		options_provider.add_observer(HouseBuilderOptionsProviderObserver.new)
	end
	def onOpenModel
		options_provider = Sketchup.active_model.options["UnitsOptions"]
		options_provider.add_observer(HouseBuilderOptionsProviderObserver.new)
	end
end

def self.hb_update_config(unit_type)
	case unit_type
	when 0..1
		new_units = "imperial"
	else
		new_units = "metric"
	end
	if (@house_builder_units != new_units)
		@house_builder_units  = new_units
	end
end

def self.hb_init_config
	# Attach the observer
	Sketchup.add_observer(HouseBuilderAppObserver.new)

	options_provider = Sketchup.active_model.options["UnitsOptions"]
	options_provider.add_observer(HouseBuilderOptionsProviderObserver.new)

	unit_type = options_provider["LengthUnit"]
	hb_update_config(unit_type)
end

@house_builder_units  = "imperial"

def self.units
	return @house_builder_units
end

# Run
if (not file_loaded?("HouseBuilder/HouseBuilderTool.rb"))
	hb_init_config
end


#--------  B A S E B U I L D E R  --------------------------------------------
# This is the base class for the other classes in this module. It provides 
# storage of parameters for the class in a hash table. The parameters are
# accessible using standard ruby dot notation (e.g. wall.width) and can be
# specified in the new() method using key => value notation.
class BaseBuilder
    attr_reader :table
    attr_writer :table

# global defaults that can be modified by caller
GLOBAL_OPTIONS_METRIC = {
	'header_style' => HBDEFAULTS['metric']['global']['header_style'],
	'pitch' => HBDEFAULTS['metric']['global']['pitch'],
	'on_center_spacing' => HBDEFAULTS['metric']['global']['on_center_spacing'], 
	'wall.style' => HBDEFAULTS['metric']['wall']['style'],
	'wall.justify' => HBDEFAULTS['metric']['wall']['justify'],
	'wall.height' => HBDEFAULTS['metric']['wall']['height'],
	'wall.stud_spacing' => HBDEFAULTS['metric']['wall']['stud_spacing'],
	'window.header_height' => HBDEFAULTS['metric']['window']['header_height'],
	'window.justify' => HBDEFAULTS['metric']['window']['justify'],
	'door.header_height' => HBDEFAULTS['metric']['door']['header_height'],
	'door.justify' => HBDEFAULTS['metric']['door']['justify'],
	'floor.joist_spacing' => HBDEFAULTS['metric']['floor']['joist_spacing'],
	'roof.joist_spacing' => HBDEFAULTS['metric']['roof']['joist_spacing'],
	'layer' => nil,
} if not defined?(GLOBAL_OPTIONS_METRIC)

GLOBAL_OPTIONS_IMPERIAL = {
	'header_style' => HBDEFAULTS['imperial']['global']['header_style'],
	'pitch' => HBDEFAULTS['imperial']['global']['pitch'],
	'on_center_spacing' => HBDEFAULTS['imperial']['global']['on_center_spacing'], 
	'wall.style' => HBDEFAULTS['imperial']['wall']['style'],
	'wall.justify' => HBDEFAULTS['imperial']['wall']['justify'],
	'wall.height' => HBDEFAULTS['imperial']['wall']['height'],
	'wall.stud_spacing' => HBDEFAULTS['imperial']['wall']['stud_spacing'],
	'window.header_height' => HBDEFAULTS['imperial']['window']['header_height'],
	'window.justify' => HBDEFAULTS['imperial']['window']['justify'],
	'door.header_height' => HBDEFAULTS['imperial']['door']['header_height'],
	'door.justify' => HBDEFAULTS['imperial']['door']['justify'],
	'floor.joist_spacing' => HBDEFAULTS['imperial']['floor']['joist_spacing'],
	'roof.joist_spacing' => HBDEFAULTS['imperial']['roof']['joist_spacing'],
	'layer' => nil,
} if not defined?(GLOBAL_OPTIONS_IMPERIAL)

	    
# initialize attributes
def initialize(hash=nil)
    @table = {}
	table[:metric] = self.class.is_metric()
    if hash
        for k,v in hash
            table[k.to_sym] = v
            new_member(k)
        end
    end
end

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

def is_metric
	return table[:metric]
end

def is_imperial
	return (!is_metric())
end

def self.is_metric
	return (MM_HouseBuilder.units == "metric")
end

def parameter_changed(name)
	# implement in subclass to handle parameter changes
end

# allow direct access to option table as if they were attributes
def new_member(name)
    unless self.respond_to?(name)
        self.instance_eval %{
            def #{name}; @table[:#{name}]; end
            def #{name}=(x); if (@table[:#{name}] != x); @table[:#{name}] = x; parameter_changed('#{name}'); end; end
        }
    end
end

def self.set_global_option(name, value)
	if (is_metric())
		GLOBAL_OPTIONS_METRIC[name] = value
	else
		GLOBAL_OPTIONS_IMPERIAL[name] = value
	end
end

def self.get_global_option(name)
	if (is_metric())
		return GLOBAL_OPTIONS_METRIC[name]
	else
		return GLOBAL_OPTIONS_IMPERIAL[name]
	end
end

# update object hash table with applicable global options
def apply_global_options(hashtbl)
    classname = self.class.to_s.downcase

	if (is_metric())
		options = GLOBAL_OPTIONS_METRIC
	else
		options = GLOBAL_OPTIONS_IMPERIAL
	end
    
    options.keys.each do |key|
        parts = key.split('.')
        key_class = ''
        if (parts.length == 2)
            key_class = parts[0]
            next if not (classname =~ /#{key_class}/)
            newkey = parts[1]
        else
            newkey = key
        end
        if (hashtbl.has_key?(newkey))
            hashtbl[newkey] = options[key]
        end
    end
end


# constants
GABLE_ROOF = 'gable' if not defined?(GABLE_ROOF)
SHED_ROOF = 'shed' if not defined?(SHED_ROOF)
COMMON_RAFTER = 'common' if not defined?(COMMON_RAFTER)
TRUSS = 'truss' if not defined?(TRUSS)
PLATFORM_FRAMING = 'platform' if not defined?(PLATFORM_FRAMING)
BALLOON_FRAMING = 'balloon' if not defined?(BALLOON_FRAMING)
COMMON_LUMBER = 'common' if not defined?(COMMON_LUMBER)
ENGINEERED = 'engineered' if not defined?(ENGINEERED)
FRONT = 'front' if not defined?(FRONT)
SIDE = 'side' if not defined?(SIDE)
TOP = 'top' if not defined?(TOP)

# find the component with the specified name
# (not used right now)
def self.find_component(name)
	comp = nil
	model = Sketchup.active_model
	model.definitions.each do |d|
		if (d.name == name)
			comp = d
			break;
		end
	end
	return comp
end

# recursively search for a group with the given target name
def self.find_named_entity(target, entities = Sketchup.active_model.entities)
	result = nil
	#puts "entity count = " + entities.count.to_s
	entities.each do |e|
	    # only groups have names
	    next if not (e.kind_of?(Sketchup::Group))
		n = e.get_attribute('einfo', 'name')
		if (n && (n == target))
			result = e
			break
		end
		# recursively search groups for entities
		if (e.entities != nil)
		    result = BaseBuilder.find_named_entity(target, e.entities)
		    break if (result)
		end
	end
	return result
end

# find a name that has not yet been assigned to a group
def self.unique_name(base)
    n = ''
	0.upto(1000) do |i|
		n = base + i.to_s
	    if (BaseBuilder.find_named_entity(n) == nil)
		    #puts "did not find it"
			break
		end
		end
	# puts "returning unique name " + n
	return n
end

# get the object properties from the group's attriibute table
def get_options_from_drawing(group)
    puts "options from drawing: " if VERBOSE
    table.keys.each do |key|
        value = group.get_attribute('einfo', key.to_s)
        table[key] = value 
		puts "#{key} = #{value}" if VERBOSE
    end
    puts if VERBOSE
end

# store object properties in the group's attribute table
def save_options_to_drawing(group)
    if (VERBOSE)
        print "options saved to drawing: "
        table.keys.each { |key| print key.to_s + "=" + table[key].to_s + ", " }
        puts
    end
    table.keys.each { |key| group.set_attribute('einfo', key.to_s, table[key]) }
end

# create a hash table and initialize it with specified key/value pairs from
# the object's properties. Also add any key/value pairs in 'extras' hash table
def fill_options(keys, extras)
    option_array = table.select { |key, value| keys.include?(key.to_s) }
    options = Hash.new
    option_array.each { |pair| options[pair[0].to_s] = pair[1] }
    #print "options: "
    #options.each { |k, v| print k.to_s + " = " + v.to_s }
    #puts
    options.update(extras)
    return options
end

def self.erase!(name)
	if (e = BaseBuilder.find_named_entity(name))
		e.erase!
	end
end

end # class BaseBuilder


#--------  L U M B E R  ------------------------------------------------
# This class draws a piece of lumber. The lumber can be common lumber
# (e.g. a 2x4), an engineered joist (e.g. TJI230), or custom lumber
# that is extruded from a face provided by the caller
# options:
class Lumber < BaseBuilder

JOIST_DATA = {
    # top width, web width, top height
    'TJI110' => [ 1.75, 0.375, 1.375 ],
    'TJI210' => [ 2.0675, 0.375, 1.375 ],
    'TJI230' => [ 2.3125, 0.375, 1.375 ],
    'TJI360' => [ 2.3125, 0.4575, 1.375 ],
    'TJI560' => [ 3.5, 0.4575, 1.375 ],
}.freeze if not defined? JOIST_DATA

JOIST_DATA_METRIC = {
    # top width, web width, top height
    'TJI110' => [ 45.mm, 10.mm, 35.mm ],
    'TJI210' => [ 50.mm, 10.mm, 35.mm ],
    'TJI230' => [ 58.mm, 10.mm, 35.mm ],
    'TJI360' => [ 58.mm, 12.mm, 35.mm ],
    'TJI560' => [ 90.mm, 12.mm, 35.mm ],
}.freeze if not defined? JOIST_DATA

def initialize(options = {})
	super()
	default_options = {
		'style' => HBDEFAULTS[MM_HouseBuilder.units]['global']['style'],
		'origin' => Geom::Point3d.new,
		'orientation' => TOP,
		'rotation' => 0,
		'depth' => 0,
		'profile' => [],
		'layer' => nil,
	}
	default_options.update(options)
	super(default_options)
end

# get nominal length from style
def self.length_from_style(style)
    #puts 'style = ' + style.to_s
    if (style =~ /^(\d+)\s*x\s*(\d+)$/)
        #puts "return " + $2.to_s
        return $2
    end
    return nil
end

# get nominal thickness from style
def self.thickness_from_style(style)
    if (style =~ /^(\d+)\s*x\s*(\d+)$/)
        #puts "return 1" + $1.to_s
        #puts "return 2" + $2.to_s
        return $1
    end
    return nil
end

# get nominal width from style
def self.width_from_style(style)
    #puts 'style = ' + style
    if (style =~ /^(\d+)\s*x\s*(\d+)$/)
        return $1
    end
    return nil
end

# return the actual dimension of a piece of lumber given it nominal dimension
def self.size_from_nominal(model, nominal, metric=false)
    # puts 'nominal = ' + nominal.to_s
    size = nominal.to_f
    
	if (metric)
		size = size.mm
    elsif (model == "common")
        # subtract 1/2 inch if size is an integer
        if ((size - size.to_i) == 0)
            size -= 0.5
        end
    elsif (model =~ /TJI/)
        if (nominal == 10)
            size = 9.5
        elsif (nominal == 12)
            size = 11.875
        else
            size = dim
        end
    end
    return size
end

# draw a board standing on end
def self.draw_vert_lumber(pt, st, h, on_layer, is_metric, r = 90.degrees)
    lumber = Lumber.new('style' => st,
                        'depth' => h,
                        'origin' => pt,
                        'rotation' => r,
                        'orientation' => Lumber::TOP,
                        'layer' => on_layer,
						'metric'=> is_metric)
	group = lumber.draw
	return group
end

# draw a board laying flat
def self.draw_hort_lumber(pt, st, l, on_layer, is_metric, r = 0)
    lumber = Lumber.new('style' => st,
                        'depth' => l,
                        'origin' => pt,
                        'rotation' => r,
                        'orientation' => Lumber::FRONT,
                        'layer' => on_layer,
						'metric'=> is_metric)
	group = lumber.draw
	return group
end

# draw non-rectangular lumber
def self.draw_profile_lumber(pt, points, depth, on_layer, is_metric)
    lumber = Lumber.new('profile' => points,
                        'depth' => depth,
                        'origin' => pt,
                        'style' => 'custom', 
                        'orientation' => Lumber::FRONT,
                        'layer' => on_layer,
						'metric'=>is_metric)
	group = lumber.draw
	return group
end


def ibeam_profile_from_style(model, height)
	# create a list of points for engineered truss corners		
    #  f+----+g
    #  e+-  -+h   
    #    d||i     
    #     ||       
    #    c||j 
    #  b+-  -+k         
    #  a+----+l
    #
	if is_metric()
		dim = JOIST_DATA_METRIC[model]
	else
		dim = JOIST_DATA[model]
	end

    return nil if not dim
    center = dim[0]/2
    
    a = Geom::Point3d.new(0, 0, 0)
	b = Geom::Point3d.new(0, 0, dim[2])
	c = Geom::Point3d.new(0, center - dim[1]/2, b.z)          
	d = Geom::Point3d.new(0, c.y, height - dim[2])
	e = Geom::Point3d.new(0, 0, d.z)
	f = Geom::Point3d.new(0, 0, height)
	g = Geom::Point3d.new(0, dim[0], height)          
	h = Geom::Point3d.new(0, g.y, d.z)
	i = Geom::Point3d.new(0, center + dim[1]/2, d.z)
	j = Geom::Point3d.new(0, i.y, b.z)
	k = Geom::Point3d.new(0, g.y, b.z)
	l = Geom::Point3d.new(0, g.y, 0)          

	points = [ a, b, c, d, e, f, g, h, i, j, k, l ]

	return points
end

# return an array of points that make up the profile of the lumber
# examples of styles:
#    "2x4"         - common lumber
#    "2 x 4"       - same as previous
#    "TJI230 x 12" - engineered TrusJoist 12" in height
#    "custom" - profile has been passed in - side profile
def profile_from_style

    profile_points = []
    # puts "style = " + style
    if (style =~ /^(\d+)\s*x\s*(\d+)$/)
        # common lumber (e.g. 2x4)
        width = Lumber.size_from_nominal("common", $1, is_metric())
        height = Lumber.size_from_nominal("common", $2, is_metric())
        # puts "orientation = " + orientation.to_s
        case orientation
        when TOP
             profile_points = [ Geom::Point3d.new(0, 0, 0), 
                           Geom::Point3d.new(width, 0, 0), 
                           Geom::Point3d.new(width, height, 0), 
                           Geom::Point3d.new(0, height, 0)]
             # puts "TOP profile = " + profile_points.to_s 
        when FRONT
             profile_points = [ Geom::Point3d.new(0, 0, 0), 
                           Geom::Point3d.new(0, 0, height), 
                           Geom::Point3d.new(width, 0, height), 
                           Geom::Point3d.new(width, 0, 0)]
        when SIDE
             profile_points = [ Geom::Point3d.new(0, 0, 0), 
                           Geom::Point3d.new(0, 0, height), 
                           Geom::Point3d.new(0, width, height), 
                           Geom::Point3d.new(0, width, 0)]
        end
    elsif (style =~ /^(TJI\d+)\s*x\s*(\d+)$/)
        model = $1
        height = Lumber.size_from_nominal($model, $2, is_metric())
        profile_points = ibeam_profile_from_style(model, height)
    elsif (style == "custom")
        profile_points = profile
    end
    # puts "profile = " + profile_points.to_s
    return profile_points
end

# create a grouped collection of entities for the piece of lumber
def draw
    profile_points = profile_from_style()

    group = draw_profile_lumber(profile_points)
    # puts "lumber: " + style + " x" + depth.to_s + " at " + origin.to_s
    
    # translate the object to the specified origin point
    t = Geom::Transformation.new(origin)

    group.transform!(t)
    return group
end

# Draw a board given its profile as an array of points.
def draw_profile_lumber(points)
    #print "draw_lumber: points = "
    #points.each { |p| print p.to_s + ", " }
    #puts
	model = Sketchup.active_model
	# model.start_operation "Create Lumber"		
	entities = model.active_entities

	# group the lumber faces and edges
	group = entities.add_group
	entities = group.entities

	case orientation
    when TOP
        axis = Z_AXIS
    when FRONT
        axis = Y_AXIS
    when SIDE
        axis = X_AXIS
    end
    
	# rotate the points (we cannot transform a face)
    if (rotation != 0) 
        t = Geom::Transformation.rotation(points[0], axis, rotation)
        points.each { |p| p.transform!(t) }
        
        # move the face so that all points are positive
        bb = Geom::BoundingBox.new
        points.each { |p| bb.add(p) }
        min_point = bb.min
        # puts "min = " + min_point.inspect
        vec = Geom::Point3d.new - min_point
        # puts "vec = " + min_point.inspect
        t = Geom::Transformation.new(vec)
        points.each { |p| p.transform!(t) }
    end
    
    base = entities.add_face(points)
    
    #$RC = UI.messagebox("face", MB_OKCANCEL) if ($RC < 2)
    
	
	# push-pull for depth
    # puts "depth = " + depth.inspect
    d = depth
    if (base.normal.dot(axis) < 0)
        d = -d
    end
    # puts "d = " + d.to_s
    # puts "base = " + base.inspect
    # puts "axis = " + axis.inspect
	base.pushpull(d)
	
	# put entity on the correct layer
	base.layer = layer if (layer)

	# commit our changes
	# model.commit_operation
	return group
end

# Cut a section out of a board
def self.cut(group, first_corner, second_corner, depth)
	model = Sketchup.active_model

	# create a single undo step
	# model.start_operation "Cut Lumber"		
	entities = group.entities
	#puts "cut: 1st corner = " + first_corner.inspect + " 2nd = " + second_corner.inspect
	#UI.messagebox "ok"

	# create cutting face from two new edges
	top_points = []
	top_points[0] = [first_corner.x,	first_corner.y,		first_corner.z]
	top_points[1] = [first_corner.x,	second_corner.y,    first_corner.z]
	top_points[2] = [second_corner.x,	second_corner.y,	first_corner.z]
	top_points[3] = [second_corner.x,	first_corner.y,		first_corner.z]

	bottom_points = []
	bottom_points[0] = [first_corner.x,	first_corner.y,		first_corner.z + depth]
	bottom_points[1] = [first_corner.x,	second_corner.y,    first_corner.z + depth]
	bottom_points[2] = [second_corner.x,	second_corner.y,	first_corner.z + depth]
	bottom_points[3] = [second_corner.x,	first_corner.y,		first_corner.z + depth]

    # create new edges that will cut the current faces
	edge1 = entities.add_line(top_points[0], top_points[3])
	edge2 = entities.add_line(top_points[1], top_points[2])
	
	edge3 = entities.add_line(bottom_points[0], bottom_points[3])
	edge4 = entities.add_line(bottom_points[1], bottom_points[2])
	
	edge5 = entities.add_line(top_points[0], bottom_points[0])
	edge6 = entities.add_line(top_points[1], bottom_points[1])
	edge7 = entities.add_line(top_points[2], bottom_points[2])
	edge8 = entities.add_line(top_points[3], bottom_points[3])
	
	# find the vertices of the 4 edges that we want to remove
    cut_edge1 = edge5.start.common_edge edge6.start
    cut_edge2 = edge7.start.common_edge edge8.start
    cut_edge3 = edge5.end.common_edge edge6.end
    cut_edge4 = edge7.end.common_edge edge8.end
    
    # remove the edges (and the faces that they define)
    cut_edge1.erase! if cut_edge1
    cut_edge2.erase! if cut_edge2
    cut_edge3.erase! if cut_edge3
    cut_edge4.erase! if cut_edge4
    
    # add in the two new faces
    entities.add_face(top_points[0], top_points[3], bottom_points[3], bottom_points[0])
    entities.add_face(top_points[1], top_points[2], bottom_points[2], bottom_points[1])

	# commit our changes
	# model.commit_operation
end

end # class Lumber


#----------------------------- B U I L D I N G -------------------
# A building encapsulates wall, floors, and roofs.
# options:
class Building < BaseBuilder

def initialize(options = {})
	super()
	default_options = {
		'name' => '',
		'type' => 'building',
		'layer' => nil,
	}
	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	@objects = []
	if (self.name.length == 0)
		self.name = unique_name("building")
	end
end

def add(object, options = {})
	@objects.push(object)
end

def draw
	# draw all walls, roofs
	model = Sketchup.active_model

	# create a single undo step		
	entities = []	
	@objects.each { |object| entities.push(object.draw()) }
	
	# group the building
	group = model.active_entities.add_group(entities)
	save_options_to_drawing(group)
	return group
end


end

#----------------------------- W A L L ---------------------------
# A wall has plates and studs and encapsulates windows and doors.
# options:
class Wall < BaseBuilder
attr_reader :stud_height, :bottom_plate_group, :objects

def initialize(options = {})
	super()
	default_options = {
		'type' => 'wall',
		'style' => HBDEFAULTS[MM_HouseBuilder.units]['wall']['style'],
		'name' => '',
		'width' => 0, # computed below
		'height' => HBDEFAULTS[MM_HouseBuilder.units]['wall']['height'],
		'length' => 0,
		'stud_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['wall']['stud_spacing'],
		'on_center_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['global']['on_center_spacing'],
		'origin' => Geom::Point3d.new,
		'endpt' => Geom::Point3d.new,
		'angle' => 0,
		'bottom_plate_count' => 1,
		'top_plate_count' => 2,
		'first_stud_offset' => 0,
		'justify' => HBDEFAULTS[MM_HouseBuilder.units]['wall']['justify'],
		'layer' => nil,
		'object_names' => ''
	}

	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	@objects = []
	if (self.name.length == 0)
		self.name = BaseBuilder.unique_name("wall")
	end
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(self.style), is_metric());
	self.width = Lumber.size_from_nominal("common", Lumber.length_from_style(self.style), is_metric());
end

def parameter_changed(name)
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(self.style), is_metric());
	self.width = Lumber.size_from_nominal("common", Lumber.length_from_style(self.style), is_metric());
end

def self.create_from_drawing(group)
    wall = Wall.new()
    wall.get_options_from_drawing(group)
    wall.object_names.split('|').each do |name| 
        entity = BaseBuilder.find_named_entity(name)
        next if not entity
        type = entity.get_attribute('einfo', 'type')
        case type 
        when 'window'
            window = Window.create_from_drawing(wall,entity)
            wall.add(window)
        when 'door'
            door = Door.create_from_drawing(wall,entity)
            wall.add(door)
        else
            UI.messagebox "unknown type: " + type + " for " + name
        end
    end
    return wall
end

def add(object, options = {})
	@objects.push(object)
	names = object_names.split('|')
	names.push(object.name.to_s)
	self.object_names = names.uniq.join('|')
end

def delete(name)
	@objects.delete_if {|x| x.name == name }
end

def erase
    group = BaseBuilder.find_named_entity(self.name)
    skin_group = BaseBuilder.find_named_entity(self.name + "_skin")
    group.erase! if (group)
    skin_group.erase! if (skin_group)
end

def hide
    group = BaseBuilder.find_named_entity(self.name)
    skin_group = BaseBuilder.find_named_entity(self.name + "_skin")
    group.hidden = true if (group)
    skin_group.hidden = true if (skin_group)
end

def unhide
    group = BaseBuilder.find_named_entity(self.name)
    skin_group = BaseBuilder.find_named_entity(self.name + "_skin")
    group.hidden = false if (group)
    skin_group.hidden = false if (skin_group)
end

def draw
	puts "drawing wall " + name if VERBOSE
	pt = Geom::Point3d.new
	model = Sketchup.active_model
	torigin = Geom::Point3d.new(origin);


	# create a single undo step
	## model.start_operation "Create Wall"		
	entities = []

	@stud_height = height
	# bottom plate
	for i in 1..bottom_plate_count
		@bottom_plate_group = build_plate(pt)
		entities.push(@bottom_plate_group)
		pt.z += @stud_z_thickness
	end
	full_size = [[pt.z, nil]]
	
	# top plate
	pt.z = height
	for i in 1..top_plate_count
		case self.class.to_s
		when "MM_HouseBuilder::GableWall"
			pt.z -= @top_plate_z
			entities.push(build_top_plate(pt))
			@stud_height -= @top_plate_z
		else
			#Rectangular wall
			pt.z -= @stud_z_thickness
			entities.push(build_top_plate(pt))
			@stud_height -= @stud_z_thickness
		end
	end


	# fill in studs
	pt.z = 0 + @stud_z_thickness*bottom_plate_count
	y = 0
	iteration = 0
	while (y < length - 2*@stud_z_thickness)
		pt.y = y
		entities += build_stud(pt.y, full_size, nil)
		y += stud_spacing
		if (iteration == 0 && on_center_spacing == 'true')
			y -= @stud_z_thickness/2 # MIKE MORRISON changed to on-center studs
		end
		iteration += 1
	end

	# draw the last stud
	if ((y < length - @stud_z_thickness) && (y > length - 2*@stud_z_thickness))
		pt.y = length - @stud_z_thickness*2
		entities += build_stud(pt.y, full_size, nil)
	end
	pt.y = length - @stud_z_thickness
	entities += build_stud(pt.y, full_size, nil)
	pt.y += @stud_z_thickness
	endpt.set!(pt.x.to_f, pt.y.to_f, 0)
    
	# draw any windows or doors   
	@objects.each { |object| entities.push(object.draw(self)) }
	
	# group the studs into a wall
	group = model.active_entities.add_group(entities)
	
	# add the skin layer
    skin_group = add_skin

	# justify the wall by moving the zero point back to the origin  
    case justify
    when 'left'
        zero_pt = Geom::Point3d.new(0, 0, 0)
    when 'center'
        zero_pt = Geom::Point3d.new(width/2, 0, 0)
    when 'right'
        zero_pt = Geom::Point3d.new(width, 0, 0)
    end
    
    vec = Geom::Point3d.new - zero_pt
    #puts "vec = " + vec.inspect
    transformation = Geom::Transformation.new(vec)
	group.transform!(transformation)
	skin_group.transform!(transformation)
	# don't translate the endpt
			
	# rotate the wall
	# puts "transformation angle radians = " + angle.degrees.to_s  + " (" + angle.to_s + " degrees)\n"
	transformation = Geom::Transformation.new([0, 0, 0], Z_AXIS, angle.degrees)
	group.transform!(transformation)
	endpt.transform!(transformation)
	skin_group.transform!(transformation)
			
	transformation = Geom::Transformation.new(torigin)
	group.transform!(transformation)
	endpt.transform!(transformation)
	skin_group.transform!(transformation)
	
	## model.commit_operation
	save_options_to_drawing(group)
	skin_group.set_attribute("einfo", "name", name + "_skin")
	skin_group.set_attribute("einfo", "type", table[:type])
	return group, skin_group
end

# add "skin" to the outsides of the wall
def add_skin
	# create a layer for the skin
    model = Sketchup.active_model
    layers = model.layers
    old_layer = model.active_layer
    layer_name = model.active_layer.name + "_skin"
    skin_layer = layers[layer_name]
    if (not skin_layer)
        skin_layer = layers.add(layer_name)
        skin_layer.visible = false;
    end
    model.active_layer = skin_layer
    
    skin_group = model.active_entities.add_group
	entities = skin_group.entities
	
	# draw the skin
    left_corners, right_corners = get_corners
    
    entities.add_face(left_corners)
	entities.add_face(right_corners)
	
	# add the four ends
    for i in 0..left_corners.length - 1
        end_corners = [
            left_corners[i],     
            right_corners[i],
            right_corners[(i+1) % left_corners.length],
            left_corners[(i+1) % left_corners.length],
        ]
        entities.add_face(end_corners)
    end

	# cut openings for windows or doors   
	@objects.each { |object| object.cut_skin(self, entities) }

    # restore the previous layer
    model.active_layer = old_layer
    
    return skin_group
end

def get_corners
    left_corners = [
        Geom::Point3d.new(0, 0, 0),
        Geom::Point3d.new(0, length, 0),
        Geom::Point3d.new(0, length, height),
        Geom::Point3d.new(0, 0, height),
    ]
    
    right_corners = [
        Geom::Point3d.new(width, 0, 0),
        Geom::Point3d.new(width, length, 0),
        Geom::Point3d.new(width, length, height),
        Geom::Point3d.new(width, 0, height),
    ]
    return left_corners, right_corners
end

# draw a bottom plate
def build_plate(pt)
    lumber = Lumber.new(fill_options(%w[style layer metric],
                        'depth' => length,
                        'origin' => pt,
                        'rotation' => 90.degrees,
                        'orientation' => FRONT))
	group = lumber.draw
	# print "group = " + group.to_s + "\n"
	return group
end

# draw a top plate
# this method is different in subclasses
def build_top_plate(pt)
    return build_plate(pt)
end

# draw a stud
def build_stud(y, pts, obj)
    # fill in the top of the stud
    pts.each { |pt| pt[1] = @stud_height if (pt[1] == nil) }
    
    # remove any door or window openings from the stud
    if (obj == nil)
        keep = false
    else
        keep = true
    end
    entities = []
    @objects.each do |object| 
        # skip the object that created the stud
        next if (object == obj)
        pts = object.adjust_stud(y, pts, keep)
        return entities if (pts == nil)
    end

    # draw the stud
    puts "build_stud: pts = " + pts.inspect if VERBOSE

    pts.each do |pt|
        orig_pt = Geom::Point3d.new(0, y, pt[0])
        height = pt[1] - pt[0]
        lumber = Lumber.new(fill_options(%w[style layer metric],
                            'depth' => height,
                            'origin' => orig_pt, 
                            'rotation' => 90.degrees,
                            'orientation' => TOP))
    	entities.push(lumber.draw)
	end
	return entities
end

def self.redraw_all_walls
    model = Sketchup.active_model
    entities = model.entities
    old_layer = model.active_layer
    wall_entities = []
    skin_entities = []
    entities.each do |e|
        next if not (e.kind_of?(Sketchup::Group))
        type = e.get_attribute('einfo', 'type')
        name = e.get_attribute('einfo', 'name')
        # puts "name = #{name} type = #{type}"
        next if ((type != 'wall') and (type != 'GableWall') and (type != 'rakewall'))
        name = e.get_attribute('einfo', 'name')
        # puts "name = #{name}"
        if (name =~ /_skin/)
            skin_entities.push(e)
        else
            wall_entities.push(e)
        end
    end
    
    skin_entities.each { |e| e.erase! }

    wall_entities.each do |e|
        type = e.get_attribute('einfo', 'type')
        if (type == 'wall')
            wall = Wall.create_from_drawing(e)
        else
            wall = GableWall.create_from_drawing(e)
        end
        wall.endpt.z = wall.origin.z    # fix earlier bug
        model.active_layer = e.layer
        e.erase!
        wall.draw
    end
    model.active_layer = old_layer
end

end # class Wall

# ---------------------------- G A B L E W A L L -------------------
# A GableWall is a wall that extends to the rafters (e.g. a gable end
# wall). To create a platform framed gable wall, create a regular wall
# and put a gable wall on top (with bottom_plate_count = 0)
# options:
class GableWall < Wall

def initialize(options = {})
	super()
	default_options = { 
		'name' => '',
		'type' => 'GableWall',
		'length' => 0,
		'origin' => Geom::Point3d.new,
		'angle' => 0,
		'bottom_plate_count' => 1,
		'top_plate_count' => 1,
		'first_stud_offset' => 0,
		'pitch' => HBDEFAULTS[MM_HouseBuilder.units]['global']['pitch'],
		'roof_type' => GABLE_ROOF,
		'layer' => nil,
	}
	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
end

def self.create_from_drawing(group)
    wall = GableWall.new()
    wall.get_options_from_drawing(group)
    wall.object_names.split('|').each do |name| 
        entity = BaseBuilder.find_named_entity(name)
        next if not entity
        type = entity.get_attribute('einfo', 'type')
        case type 
        when 'window'
            window = Window.create_from_drawing(entity)
            wall.add(window)
        when 'door'
            door = Door.create_from_drawing(entity)
            wall.add(door)
        else
            UI.messagebox "unknown type: " + type + " for " + name
        end
    end
    return wall
end

def draw
	@roof_angle = Math.atan(pitch.to_f/12.0)	
	if (is_metric())
		roof_angle = pitch.degrees
	end
    
	# compute start and end of top line of top plate
    start_point = Geom::Point3d.new(0, 0, height)
    # compute the vertical height of the end cut of the top plate
    @stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(self.style), is_metric())
	@top_plate_z = @stud_z_thickness/Math.cos(@roof_angle)
    h = @top_plate_z*top_plate_count
    base_start_point = Geom::Point3d.new(0, 0, height - h)
    # compute start and end of bottom line of top plate
    case roof_type
    when GABLE_ROOF
        mid_point = Geom::Point3d.new(0, length/2, height + length/2*Math.tan(@roof_angle))
        end_point = Geom::Point3d.new(0, length, height)
        base_mid_point = Geom::Point3d.new(0, length/2, mid_point.z - h)
        base_end_point = Geom::Point3d.new(0, length, end_point.z - h)
        @top_plate_line1 = [ start_point, mid_point ]
        @top_plate_line2 = [ end_point, mid_point ]
        @base_plate_line1 = [ base_start_point, base_mid_point ]
        @base_plate_line2 = [ base_end_point, base_mid_point ]
    when SHED_ROOF
        end_point = Geom::Point3d.new(0, length, height + length*Math.tan(@roof_angle))
        base_end_point = Geom::Point3d.new(0, length, end_point.z - h)
        @top_plate_line = [ start_point, end_point ]
        @base_plate_line = [ base_start_point, base_end_point ]     	
    else
        UI.messagebox "unknown roof type " + roof_type.to_s
    end
    
    # call the draw method in the Wall class. Wall.draw() will call the methods below
    super()
end

def get_corners
    case roof_type
    when GABLE_ROOF
        if (height > 0)
            left_corners = [
                Geom::Point3d.new(0, 0, 0),
                Geom::Point3d.new(0, length, 0),
                Geom::Point3d.new(0, length, height),
                Geom::Point3d.new(0, @top_plate_line1[1].y, @top_plate_line1[1].z),
                Geom::Point3d.new(0, 0, height),
            ]
            right_corners = [
                Geom::Point3d.new(width, 0, 0),
                Geom::Point3d.new(width, length, 0),
                Geom::Point3d.new(width, length, height),
                Geom::Point3d.new(width, @top_plate_line1[1].y, @top_plate_line1[1].z),
                Geom::Point3d.new(width, 0, height),
            ]
        else
            left_corners = [
                Geom::Point3d.new(0, 0, 0),
                Geom::Point3d.new(0, length, 0),
                Geom::Point3d.new(0, @top_plate_line1[1].y, @top_plate_line1[1].z),
            ]
            right_corners = [
                Geom::Point3d.new(width, 0, 0),
                Geom::Point3d.new(width, length, 0),
                Geom::Point3d.new(width, @top_plate_line1[1].y, @top_plate_line1[1].z),
            ]
        end
    when SHED_ROOF  
        left_corners = [
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(0, length, 0),
            Geom::Point3d.new(0, length, @top_plate_line[1].z),
            Geom::Point3d.new(0, 0, height),
        ]
        right_corners = [
            Geom::Point3d.new(width, 0, 0),
            Geom::Point3d.new(width, length, 0),
            Geom::Point3d.new(width, length, @top_plate_line[1].z),
            Geom::Point3d.new(width, 0, height),
        ]   	
    else
        UI.messagebox "unknown roof type " + roof_type.to_s
    end
    return left_corners, right_corners
end

# draw a sloped top plate
def build_top_plate(pt)
    h = @top_plate_z
    case roof_type
    when SHED_ROOF
    	a = Geom::Point3d.new(0, 0, 0)
    	b = Geom::Point3d.new(0, 0, h)
    	c = Geom::Point3d.new(0, @base_plate_line[1].y, @base_plate_line[1].z - @base_plate_line[0].z + h)
    	d = Geom::Point3d.new(0, @base_plate_line[1].y, @base_plate_line[1].z - @base_plate_line[0].z)
        profile = [a, b, c, d ]
        newpt = Geom::Point3d.new(pt.x, pt.y, pt.z)
    
        lumber = Lumber.new('profile' => profile,
                            'depth' => width,
                            'origin' => newpt,
                            'style' => 'custom', 
                            'orientation' => SIDE,
							'metric' => is_metric(),
                            'layer' => layer)
    	group = lumber.draw
    when GABLE_ROOF
        entities = []
    	a = Geom::Point3d.new(0, 0, 0)
    	b = Geom::Point3d.new(0, 0, h)
    	c = Geom::Point3d.new(0, @base_plate_line1[1].y, @base_plate_line1[1].z - @base_plate_line1[0].z + h)
    	d = Geom::Point3d.new(0, @base_plate_line1[1].y, @base_plate_line1[1].z - @base_plate_line1[0].z)
        profile = [a, b, c, d ]
        newpt = Geom::Point3d.new(pt.x, pt.y, pt.z)
        lumber = Lumber.new('profile' => profile,
                            'depth' => width,
                            'origin' => newpt,
                            'style' => 'custom', 
                            'orientation' => SIDE,
							'metric' => is_metric(),
                            'layer' => layer)
    	entities.push(lumber.draw())
    	a = Geom::Point3d.new(0, 0, 0)
    	b = Geom::Point3d.new(0, 0, h)
    	c = Geom::Point3d.new(0, -@base_plate_line2[1].y, @base_plate_line2[1].z - @base_plate_line2[0].z + h)
    	d = Geom::Point3d.new(0, -@base_plate_line2[1].y, @base_plate_line2[1].z - @base_plate_line2[0].z)
        profile = [a, b, c, d ]
        newpt = Geom::Point3d.new(pt.x, pt.y + length, pt.z)
        lumber = Lumber.new('profile' => profile,
                            'depth' => width,
                            'origin' => newpt,
                            'style' => 'custom', 
                            'orientation' => SIDE,
							'metric' => is_metric(),
                            'layer' => layer)
    	entities.push(lumber.draw())
    	model = Sketchup.active_model
    	group = model.active_entities.add_group(entities);
    end
	return group
end

# draw a stud that extends to the top plate and has a sloped top
# TODO: handle case were stud hits center of gable roof
def build_stud(y, points, obj)
    puts "gable build stud, pts = " + points.inspect if VERBOSE
    # fill in the top of the stud
    pts = []
    points.each do |pt| 
        if (pt[1] == nil)
            pts.push([pt[0], stud_height(pt[0], y)])
        else
            pts.push(pt)
        end
    end
    if (obj == nil)
        keep = false
    else
        keep = true
    end
    entities = []   
    # remove any door or window openings from the stud
    @objects.each do |object| 
        # skip the object that created the stud
        next if (object == obj)
        pts = object.adjust_stud(y, pts, keep)
        return entities if (pts == nil)
    end

    # draw the stud
    pts.each do |pt|
        if ((pt != pts.last) || (pt[1] < stud_height(pt[0], y)))
            orig_pt = Geom::Point3d.new(0, y, pt[0])
            height = pt[1] - pt[0]
            lumber = Lumber.new(fill_options(%w[style layer metric],
                                'depth' => height,
                                'origin' => orig_pt, 
                                'rotation' => 90.degrees,
                                'orientation' => TOP))
        	entities.push(lumber.draw)
        else
        	left_stud_height = stud_height(pt[0], y)
        	right_stud_height = stud_height(pt[0], y + @stud_z_thickness)
        	# puts "left, right = #{left_stud_height} #{right_stud_height}"
        	a = Geom::Point3d.new(0, 0, 0)
        	b = Geom::Point3d.new(0, 0, left_stud_height)
        	c = Geom::Point3d.new(0, @stud_z_thickness, right_stud_height)
        	d = Geom::Point3d.new(0, @stud_z_thickness, 0)
        	profile = [ a, b, c, d ]
            orig_pt = Geom::Point3d.new(0, y, pt[0])
            lumber = Lumber.new('profile' => profile,
                                'depth' => width,
                                'origin' => orig_pt,
                                'style' => 'custom', 
                                'orientation' => SIDE,
								'metric' => is_metric(),
                                'layer' => layer)
        	entities.push(lumber.draw)
        end
	end
	return entities
end

# calculate the height of a stud, given its offset from the start of the wall
def stud_height(z_offset, y_offset)
    bottom_point = Geom::Point3d.new(0, y_offset, z_offset)
    vert_line = [bottom_point, Z_AXIS]
    case roof_type
    when SHED_ROOF
        top_point = Geom.intersect_line_line(vert_line, @base_plate_line)
        h = top_point.z - z_offset
    when GABLE_ROOF
        p1 = Geom.intersect_line_line(vert_line, @base_plate_line1)
        p2 = Geom.intersect_line_line(vert_line, @base_plate_line2)
        if (p2 == nil)
            h = p1.z - z_offset
        elsif (p1 == nil)
            h = p2.z = z_offset
        else
            h = min(p1.z, p2.z) - z_offset
        end
    end
	return h
end

end	# class GableWall

#----------------------------- O P E N I N G -----------------------
# base class for doors and windows.
class Opening < BaseBuilder
def adjust_stud_for_opening(y, pts, left, right, bottom, top, keep)
    # if there is no overlap, return original points
    return pts if ((y < left - @stud_z_thickness) || (y > right))
    # if overlap with king stud, return nil
    # puts "adjust: y = " + y.to_s
    if (not keep)
        return nil if (((y > left - @stud_z_thickness) && (y < left + @stud_z_thickness)) || ((y > right - 2*@stud_z_thickness) && (y < right)))
    end
    # return original points if it overlaps the king stud
    return pts if ((y <= left) || (y >= right - @stud_z_thickness))
                     
    # trim stud around opening
    # puts "adjust: opening = l,r,t,b = #{left}, #{right}, #{top}, #{bottom}"
    new_pts = []
    pts.each do |pt|
        b, t = pt[0..1]
        # puts "adjust: (#{b}, #{t}) at y = #{y}"
        # skip section if it doesn't overlap the opening
        if ((b > top) || (t < bottom))
            new_pts.push(pt)
            next
        end
        if (b < bottom)
            if (t < top)
                # overlaps sill
                new_pts.push([b, bottom])
            else 
                # overlaps opening
                # don't display bottom segment if it is an opening stud or it overlaps the trimmer
                if (not (keep || (((y > left) && (y < left + @stud_z_thickness)) || (y > right - @stud_z_thickness) && (y < right))))
                    new_pts.push([b, bottom]) 
                end
                new_pts.push([top, t])
            end
        elsif (b < top)
            if (t < top)
                # entirely within opening, don't add it
            else
                # overlaps header
                new_pts.push([top, t])
            end   
        end
    end
    # puts "ruturning " + new_pts.inspect
    return new_pts
end
end # class Opening

#----------------------------- W I N D O W -----------------------
# A window has studs, headers, cripples and a sill.
# options:
class Window < Opening

def initialize(wall, options = {})
	super()
	default_options = { 
		'header_height' => HBDEFAULTS[MM_HouseBuilder.units]['window']['header_height'],
		'name' => '',
		'type' => 'window',
		'center_offset' => 0,
		'width' => HBDEFAULTS[MM_HouseBuilder.units]['window']['width'],
		'height' => HBDEFAULTS[MM_HouseBuilder.units]['window']['height'],
		'header_style' => HBDEFAULTS[MM_HouseBuilder.units]['global']['header_style'],
		'sill_style' => HBDEFAULTS[MM_HouseBuilder.units]['window']['sill_style'],
		'justify' => 'left',
		'rough_opening' => 0,
		'layer' => nil,
	}
	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	if (self.name.length == 0)
		self.name = BaseBuilder.unique_name("window")
	end
	@wall = wall
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(wall.style), is_metric());
end

# create a window object using the properties stored in the drawing
def self.create_from_drawing(wall, group)
    window = Window.new(wall)
    window.get_options_from_drawing(group)
    return window
end

def adjust_stud(y, pts, keep)
    total_width = width + 2*rough_opening + 4*@stud_z_thickness
    left = center_offset - total_width/2
    right = left + total_width
                 
	header_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.length_from_style(header_style),is_metric())
	sill_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.width_from_style(sill_style),is_metric())
    actual_header_height = header_height + rough_opening
    bottom_of_sill = actual_header_height - height - sill_dimension_height - 2*rough_opening
    top_of_header = actual_header_height + header_dimension_height
    return adjust_stud_for_opening(y, pts, left, right, bottom_of_sill, top_of_header, keep)
end

def draw(wall)
	puts "drawing window " + name if VERBOSE
	entities = []
	model = Sketchup.active_model
	
	header_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.length_from_style(header_style),is_metric())
	sill_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.width_from_style(sill_style),is_metric())	

	total_width = width + 2*rough_opening + 4*@stud_z_thickness
	actual_header_height = header_height + rough_opening
	left = center_offset - total_width/2
	y = left
	bottom = wall.bottom_plate_count*@stud_z_thickness
	pt = Geom::Point3d.new(0, y, bottom)
	cripple_z = actual_header_height + header_dimension_height
	full_size = [[bottom, nil]]
	
	# draw the left king stud
	entities += wall.build_stud(y, full_size, self)

	# draw the left trimmer stud and cripple
	y += @stud_z_thickness
	entities += wall.build_stud(y, [[bottom, actual_header_height]], self)

	# draw the header
    pt.y = y
	pt.z = actual_header_height
	entities.push(Lumber.draw_hort_lumber(pt, header_style, width + 2*@stud_z_thickness, layer, is_metric()))

	# draw the sill
	pt.y += @stud_z_thickness
	pt.z = actual_header_height - height - sill_dimension_height - 2*rough_opening
	entities.push(Lumber.draw_hort_lumber(pt, sill_style, width, layer, is_metric(), 90.degrees))

	# draw the right trimmer stud and cripple
    y += width + @stud_z_thickness
	entities += wall.build_stud(y, [[bottom, actual_header_height]], self)

	# draw the left king stud
	y += @stud_z_thickness
	entities += wall.build_stud(y, full_size, self)

	group = model.active_entities.add_group(entities);

	save_options_to_drawing(group)
	return group
end

def cut_skin(wall, entities)
	total_width = width + 2*rough_opening
	bottom_of_header = header_height + rough_opening
	top_of_sill = bottom_of_header - height - 2*rough_opening
	
	left = center_offset - total_width/2
	right = left + total_width

    left_corners = [
        Geom::Point3d.new(0, left, top_of_sill),
        Geom::Point3d.new(0, right, top_of_sill),
        Geom::Point3d.new(0, right, bottom_of_header),
        Geom::Point3d.new(0, left, bottom_of_header),
        Geom::Point3d.new(0, left, top_of_sill),
    ]
    
    right_corners = [
        Geom::Point3d.new(wall.width, left, top_of_sill),
        Geom::Point3d.new(wall.width, right, top_of_sill),
        Geom::Point3d.new(wall.width, right, bottom_of_header),
        Geom::Point3d.new(wall.width, left, bottom_of_header),
        Geom::Point3d.new(wall.width, left, top_of_sill),
    ]
    
    # add the edges that define the outline of the opening
    entities.add_edges(left_corners)
	entities.add_edges(right_corners)
	
	# cut the opening
	face1 = entities.add_face(left_corners[0..3])
	face2 = entities.add_face(right_corners[0..3])
	rc1 = face1.erase!
	rc2 = face2.erase!
	    
	# fill in the four missing faces
    for i in 0..3
        end_corners = [
            left_corners[i],     
            right_corners[i],
            right_corners[i+1],
            left_corners[i+1],
        ]
        entities.add_face(end_corners)
    end
end

end

#----------------------------- D O O R ---------------------------
# A Door has studs, headers, and cripples.
# options:
class Door < Opening

def initialize(wall, options = {})
	super()
	default_options = { 
		'header_height' => HBDEFAULTS[MM_HouseBuilder.units]['door']['header_height'],
		'name' => '',
		'type' => 'door',
		'center_offset' => 0,
		'width' => HBDEFAULTS[MM_HouseBuilder.units]['door']['width'],
		'height' => HBDEFAULTS[MM_HouseBuilder.units]['door']['height'],
		'header_style' => HBDEFAULTS[MM_HouseBuilder.units]['global']['header_style'],
		'justify' => 'left',
		'rough_opening' => HBDEFAULTS[MM_HouseBuilder.units]['door']['rough_opening'],
		'layer' => nil,
	}
	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	if (self.name.length == 0)
		self.name = BaseBuilder.unique_name("door")
	end
	@wall = wall
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(wall.style), is_metric());
end

# create a door object from properties stored in the drawing
def self.create_from_drawing(wall, group)
    door = Door.new(wall)
    door.get_options_from_drawing(group)
    return door
end

def adjust_stud(y, pts, keep)
    total_width = width + 2*rough_opening + 4*@stud_z_thickness
    left = center_offset - total_width/2
    right = left + total_width
                 
	header_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.length_from_style(header_style),is_metric())
    actual_header_height = header_height + rough_opening
    top_of_header = actual_header_height + header_dimension_height
    bottom = header_height - height
    return adjust_stud_for_opening(y, pts, left, right, bottom, top_of_header, keep)
end

def draw(wall)
	puts "drawing door " + name if VERBOSE
	model = Sketchup.active_model
	entities = []	

	header_dimension_height = Lumber.size_from_nominal("common", 
	        Lumber.length_from_style(header_style),is_metric())
	total_width = width + 2*rough_opening + 4*@stud_z_thickness
	actual_header_height = header_height + rough_opening
	left = center_offset - total_width/2
	y = left
	bottom = wall.bottom_plate_count*@stud_z_thickness
	pt = Geom::Point3d.new(0, y, bottom)
	cripple_z = actual_header_height + header_dimension_height
	full_size = [[bottom, nil]]
	
	# draw the left king stud
	entities += wall.build_stud(y, full_size, self)

	# draw the left trimmer stud and cripple
	y += @stud_z_thickness
	entities += wall.build_stud(y, [[bottom, actual_header_height]], self)

	# draw the header
    pt.y = y
	pt.z = actual_header_height
	entities.push(Lumber.draw_hort_lumber(pt, header_style, width + 2*@stud_z_thickness + 2*rough_opening, layer, is_metric()))

	# draw the right trimmer stud and cripple
    y += width + @stud_z_thickness + 2*rough_opening
	entities += wall.build_stud(y, [[bottom, actual_header_height]], self)

	# draw the left king stud
	y += @stud_z_thickness
	entities += wall.build_stud(y, full_size, self)

	# cut out the bottom plate
	first_corner = Geom::Point3d::new(0, left + 2*@stud_z_thickness,
		wall.bottom_plate_count*@stud_z_thickness)
	second_corner = Geom::Point3d::new(wall.width, first_corner.y + width + 2*rough_opening,
		first_corner.z)
	Lumber.cut(wall.bottom_plate_group, first_corner, second_corner, -first_corner.z)

	group = model.active_entities.add_group(entities);

	save_options_to_drawing(group)
	return group
end

def cut_skin(wall, entities)
	total_width = width + 2*rough_opening
	bottom_of_header = header_height + rough_opening
	
	left = center_offset - total_width/2
	right = left + total_width

    left_corners = [
        Geom::Point3d.new(0, left, 0),
        Geom::Point3d.new(0, right, 0),
        Geom::Point3d.new(0, right, bottom_of_header),
        Geom::Point3d.new(0, left, bottom_of_header),
        Geom::Point3d.new(0, left, 0),
    ]
    
    right_corners = [
        Geom::Point3d.new(wall.width, left, 0),
        Geom::Point3d.new(wall.width, right, 0),
        Geom::Point3d.new(wall.width, right, bottom_of_header),
        Geom::Point3d.new(wall.width, left, bottom_of_header),
        Geom::Point3d.new(wall.width, left, 0),
    ]
    
    # add the edges that define the outline of the opening
    entities.add_edges(left_corners)
	entities.add_edges(right_corners)
	
	entities.add_edges(left_corners[0], right_corners[0])
	entities.add_edges(left_corners[1], right_corners[1])
    entities.each do |e| 
        if (e.kind_of? Sketchup::Face)
            #print "door e = "; 
            #e.vertices.each { |v| print " " + v.position.inspect };
            if ((e.vertices[0].position == right_corners[0]) or (e.vertices[0].position == left_corners[0]))
                #print " erased"
                e.erase!
            end
            # puts
        end
    end
	
	# fill in the four missing faces
    for i in 0..3
        end_corners = [
            left_corners[i],     
            right_corners[i],
            right_corners[i+1],
            left_corners[i+1],
        ]
        face = entities.add_face(end_corners)
        face.erase! if (i == 0)    # remove door sill
    end
    
    # remove the two edges at the bottom of the door
    entities.each do |e| 
        if (e.kind_of? Sketchup::Edge)
            if ((e.start.position == right_corners[0]) and (e.end.position == right_corners[1]))
                e.erase!
            elsif ((e.start.position == left_corners[0]) and (e.end.position == left_corners[1]))
                e.erase!
            end
        end
    end
end

end

#----------------------------- R O O F ---------------------------
# A roof has rafters, a ridge, and facia
# Gable and Shed roofs are currently implemented
class Roof < BaseBuilder

def initialize(wall, options = {})
	super()
	default_options = {
		'name' => '',
		'type' => 'roof',
		'joist_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['joist_spacing'],
		'on_center_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['global']['on_center_spacing'],
		'style' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['style'],
		'ridge_style' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['ridge_style'],
		'roof_style' => GABLE_ROOF,
		'framing' => COMMON_RAFTER,
		'joist_type' => nil,
		'corner1' => [0, 0, 0],
		'corner2' => [0, 0, 0],
		'corner3' => [0, 0, 0],
		'corner4' => [0, 0, 0],
		'pitch' => HBDEFAULTS[MM_HouseBuilder.units]['global']['pitch'],
		'overhang' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['overhang'],
		'rake_overhang' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['rake_overhang'],
		'shed_ridge_overhang' => HBDEFAULTS[MM_HouseBuilder.units]['roof']['shed_ridge_overhang'],
		'layer' => nil,
	}

	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	if (self.name.length == 0)
		self.name = BaseBuilder.unique_name("roof")
	end
	@wall_width = wall.width
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(self.style), is_metric());
end

# create a roof object from properies stored in the drawing
def self.create_from_drawing(group)
    roof = Roof.new()
    roof.get_options_from_drawing(group)
    return roof
end

# transform the rectangle defined by the four corners into a rectangle that
# is aligned with the y axis and has one corner at the origin
def self.rectangle_setup(corner1, corner2, corner3, corner4)
    # rotate such that the edge from corner2 to corner3 is lined up with Y axis
    vec = corner3 - corner2
    angle = Math.atan2(vec.x, vec.y)
    #puts "angle = " + angle.radians.to_s
    t = Geom::Transformation.rotation(corner2, Z_AXIS, angle)

    c1r = corner1.transform(t)
    c2r = corner2.transform(t)
    c3r = corner3.transform(t)
    c4r = corner4.transform(t)
    
    # translate so that leftmost corner is at the origin
    if (c1r.x < c2r.x)
        root = c1r
    else
        root = c2r
    end
    vec = Geom::Point3d.new(0, 0, 0) - root
    t = Geom::Transformation.new(vec)  
        
    c1rt = c1r.transform(t)
    c2rt = c2r.transform(t)
    c3rt = c3r.transform(t)
    c4rt = c4r.transform(t)
    #puts "orig: " + corner1.to_s + ", " + corner2.to_s + ", " + corner3.to_s + ", " + corner4.to_s
    #puts "rotated: " + c1r.to_s + ", " + c2r.to_s + ", " + c3r.to_s
    #puts "rotated and translated: " + c1rt.to_s + ", " + c2rt.to_s + ", " + c3rt.to_s + "," + c4rt.to_s
           
    corner_a = Geom::Point3d.new(0, 0, 0)
    # find the corner opposite 'a'
	if (c1r.x < c2r.x)
    	corner_b = c3rt
    else
    	corner_b = c4rt
    end
    #puts "a, b: " + corner_a.to_s + ", " + corner_b.to_s
    if (c1r.x < c2r.x)
        l_to_r = true
    else
        l_to_r = false
    end
    return corner_a, corner_b, root, c2r, angle, l_to_r
end

def draw
	@roof_angle = Math.atan(1.0*pitch/12.0)
	if (is_metric())
		@roof_angle = pitch.degrees
	end
	puts "drawing roof " + name if VERBOSE
	model = Sketchup.active_model
	entities = []
	is_gable = (roof_style == GABLE_ROOF)
	
	l = Lumber.length_from_style(style)
	@joist_width = Lumber.size_from_nominal("common", l,is_metric())
	
	(corner_a, corner_b, root, rotation_point, angle, left_to_right) = 
	        Roof.rectangle_setup(corner1, corner2, corner3, corner4)
	
 	pt = Geom::Point3d.new()
	x_length = corner_b.x
	y_length = corner_b.y
	y = 0
	
	if (is_gable)
	    x_width = x_length/2
        left_to_right = true
        right_to_left = true
    else
        x_width = x_length
        if (left_to_right)
            right_to_left = false
        else
            right_to_left = true
        end
    end

	# draw the overhanging rafter
	pt.y = y - rake_overhang
	ridge_start = pt.y + @stud_z_thickness
	rafter_length = x_width + @stud_z_thickness;
	rafter_length -= @stud_z_thickness/2 if (is_gable)
	if (left_to_right)
    	pt.x = corner_a.x
    	entities.push(build_rafter(pt, rafter_length, 1, false))
    	left_tail = @tail
    	left_top_of_tail = Geom::Point3d.new(@top_of_tail)
    end
    if (right_to_left)
    	pt.x = corner_b.x
    	entities.push(build_rafter(pt, rafter_length, -1, false))
    	right_tail = @tail
    end

	# fill in the rafters that rest on the walls
	while (y < y_length - 2*@stud_z_thickness)
		pt.y = y
		if (left_to_right)
    		pt.x = corner_a.x
    		entities.push(build_rafter(pt, x_width, 1, true))
        end
        if (right_to_left)
    		pt.x = corner_b.x
    		entities.push(build_rafter(pt, x_width, -1, true))
        end
		y += joist_spacing
	end
    ridge_point = @peak;
    
	# draw the last rafter
	if ((y > y_length - 2*@stud_z_thickness) && (y < y_length - @stud_z_thickness))
		pt.y = y_length - 2*@stud_z_thickness
		if (left_to_right)
    		pt.x = corner_a.x
    		entities.push(build_rafter(pt, x_width, 1, true))
    	end
    	if (right_to_left)
    		pt.x = corner_b.x
    		entities.push(build_rafter(pt, x_width, -1, true))
    	end
	end
	pt.y = y_length - @stud_z_thickness
	if (left_to_right)
		pt.x = corner_a.x
		entities.push(build_rafter(pt, x_width, 1, true))
	end
	if (right_to_left)
		pt.x = corner_b.x
		entities.push(build_rafter(pt, x_width, -1, true))
	end
	
	# draw the overhanging rafter
	pt.y = y_length + rake_overhang - @stud_z_thickness
	ridge_end = pt.y
	if (left_to_right)
    	pt.x = corner_a.x
    	entities.push(build_rafter(pt, rafter_length, 1, false))
    end
    if (right_to_left)
    	pt.x = corner_b.x
    	entities.push(build_rafter(pt, rafter_length, -1, false))
    end

    # draw the ridge
    if (right_to_left)
        ridge_point.x -= @stud_z_thickness
    end
    ridge_point.y = ridge_start;
    ridge_height = Lumber.size_from_nominal("common", Lumber.length_from_style(ridge_style),is_metric())
    ridge_point.z -= ridge_height
    ridge_length = ridge_end - ridge_start
    entities.push(Lumber.draw_hort_lumber(ridge_point, ridge_style, ridge_length, layer, is_metric()))  # TODO

    # draw the facia
    facia_length = ridge_length + 2*@stud_z_thickness
    if (left_to_right)
        entities.push(draw_facia(left_tail, -@roof_angle, facia_length))
    end
    if (right_to_left)
        entities.push(draw_facia(right_tail, @roof_angle, facia_length))
    end
    
	group = model.active_entities.add_group(entities);
	
	# create a layer for the skin
    model = Sketchup.active_model
    layers = model.layers
    old_layer = model.active_layer
    layer_name = model.active_layer.name + "_skin"
    skin_layer = layers[layer_name]
    if (not skin_layer)
        skin_layer = layers.add(layer_name)
        skin_layer.visible = false;
    end
    model.active_layer = skin_layer
    skin_group = model.active_entities.add_group
	entities = skin_group.entities
	
	# draw the skin
    if (left_to_right)
        # todo fix x, z
        corners = [
            Geom::Point3d.new(x_width, ridge_start - @stud_z_thickness, @peak.z),
            Geom::Point3d.new(x_width, ridge_end + @stud_z_thickness, @peak.z),
            Geom::Point3d.new(left_top_of_tail.x, ridge_end + @stud_z_thickness, @top_of_tail.z),
            Geom::Point3d.new(left_top_of_tail.x, ridge_start - @stud_z_thickness, @top_of_tail.z),
        ]
        # puts "l_to_r corners = " + corners.inspect
        entities.add_face(corners)
    end
    if (right_to_left)
        corners = [
            Geom::Point3d.new(x_width, ridge_start - @stud_z_thickness, @peak.z),
            Geom::Point3d.new(x_width, ridge_end + @stud_z_thickness, @peak.z),
            Geom::Point3d.new(@top_of_tail.x, ridge_end + @stud_z_thickness, @top_of_tail.z),
            Geom::Point3d.new(@top_of_tail.x, ridge_start - @stud_z_thickness, @top_of_tail.z),
        ]
        # puts "r_to_l corners = " + corners.inspect
        entities.add_face(corners)
    end     

    # restore the previous layer
    model.active_layer = old_layer
	
	# translate and rotate the roof back into place
    t = Geom::Transformation.new(root)

    group.transform!(t)
    skin_group.transform!(t)
    #UI.messagebox "translate"
    
    t = Geom::Transformation.rotation(rotation_point, Z_AXIS, -angle)
    group.transform!(t)
    skin_group.transform!(t)

	save_options_to_drawing(group)
	return group
end

# draw a facia board
def draw_facia(pt, angle, length)
    lumber = Lumber.new('style' => style,
                        'depth' => length,
                        'origin' => pt,
                        'rotation' => 0,
                        'orientation' => FRONT,
						'metric' => is_metric(),
                        'layer' => layer)
	group = lumber.draw

	if (angle < 0)
	    distance = -1.5;
    	t = Geom::Transformation.new([distance, 0, 0])
    	group.transform!(t);
	end
	t = Geom::Transformation.rotation(pt, Y_AXIS, angle)
	group.transform!(t);
end

# origin is the point on the outside of the wall top plate
# x_width is the distance from the origin to the peak of the roof
def build_rafter(origin, x_width, direction, has_birdsmouth)
	# create a list of points for rafter corners a-g:		
	# (c is the peak, e-f-g is the birdsmouth)
    #  b+---------------------------------------------------/c
    #   |                                                  /
    #   |                f                                /
    #   |               /\                               /
    #   |              /   \                            /
    #  a+-------------/      \-------------------------/d
    #                g        e

	# rafter width is the horizontal distance from the roof peak
	# to the end of the overhang (not including facia)
	rafter_width = 	x_width + overhang - @stud_z_thickness/2
	a = Geom::Point3d.new(0, 0, 0)
	b = Geom::Point3d.new(0, @joist_width, 0)
	c = Geom::Point3d.new(direction*rafter_width/Math.cos(@roof_angle), @joist_width, 0)	
	d = Geom::Point3d.new(c.x - direction*@joist_width*Math.tan(@roof_angle), 0, 0)
	length_d_to_e = (x_width - @wall_width - @stud_z_thickness/2)/Math.cos(@roof_angle)
	e = Geom::Point3d.new(d.x - direction*length_d_to_e, 0, 0)
	f = Geom::Point3d.new(e.x - direction*@wall_width*Math.cos(@roof_angle), @wall_width*Math.sin(@roof_angle), 0)
	g = Geom::Point3d.new(f.x - direction*f.y*Math.tan(@roof_angle), 0, 0)
	@peak = Geom::Point3d.new(c)
	@tail = Geom::Point3d.new(a)
	@top_of_tail = Geom::Point3d.new(b)
	if (has_birdsmouth)
		points = [ a, b, c, d, e, f, g ]
	else
		points = [ a, b, c, d ]
	end
	x = Math.sin(@roof_angle)
	zero = Geom::Point3d.new(0, 0, 0)
	rafter = Lumber.draw_profile_lumber(zero, points, @stud_z_thickness, layer,is_metric())
	root_point = Geom::Point3d.new(f)

	# now translate the rafter into position
	t = Geom::Transformation.rotation(zero, [1, 0, 0], 90.degrees)
	rafter.transform!(t)
	root_point.transform!(t)
	@peak.transform!(t)
	@tail.transform!(t)
	@top_of_tail.transform!(t)
	# first rotate it to the roof pitch
	t = Geom::Transformation.rotation(zero, [0, 1, 0], -direction*@roof_angle)
	rafter.transform!(t)
	root_point.transform!(t)
	@peak.transform!(t)
	@tail.transform!(t)
	@top_of_tail.transform!(t)
	# translate point f to zero origin
	vec = zero - root_point
	t = Geom::Transformation.translation(vec)
	rafter.transform!(t)
	@peak.transform!(t)
	@tail.transform!(t)
	@top_of_tail.transform!(t)
	t = Geom::Transformation.translation(origin)
	rafter.transform!(t)
	@peak.transform!(t)
	@tail.transform!(t)
	@top_of_tail.transform!(t)
	return rafter
end

end # class Roof

#----------------------------- F L O O R ----------------------
# Draw floor joists or ceiling joists
class Floor < BaseBuilder

def initialize(options = {})
	super()
	default_options = {
		'name' => '',
		'type' => 'floor',
		'joist_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['floor']['joist_spacing'],
		'on_center_spacing' => HBDEFAULTS[MM_HouseBuilder.units]['global']['on_center_spacing'],
		'style' => HBDEFAULTS[MM_HouseBuilder.units]['floor']['style'],
		'corner1' => [0, 0, 0],
		'corner2' => [0, 0, 0],
		'corner3' => [0, 0, 0],
		'corner4' => [0, 0, 0],
		'layer' => nil,
	}

	apply_global_options(default_options)
	default_options.update(options)
	super(default_options)
	if (self.name.length == 0)
		self.name = BaseBuilder.unique_name("floor")
	end
	@stud_z_thickness = Lumber.size_from_nominal("common", Lumber.thickness_from_style(self.style), is_metric());
end

# create floor object from properties stored in drawing
def self.create_from_drawing(group)
    floor = Floor.new()
    floor.get_options_from_drawing(group)
    floor
end

def draw
	puts "drawing floor " + name if VERBOSE
	model = Sketchup.active_model
	entities = []
	
	(corner_a, corner_b, root, rotation_point, angle, left_to_right) = 
	        Roof.rectangle_setup(corner1, corner2, corner3, corner4)
	
 	pt = Geom::Point3d.new()
	x_length = corner_b.x
	y_length = corner_b.y
	y = 0
	
	@joist_thickness = @stud_z_thickness
	@joist_length = x_length

	# fill in the joists
	y = pt.y
	iteration = 0
	while (y < y_length - 2*@joist_thickness)
		entities.push(build_joist(pt))
		y += joist_spacing
		if (iteration == 0 && on_center_spacing == 'true')
			y -= @joist_thickness/2 # MIKE MORRISON - changed joists to be on center
		end
		pt.y = y
		iteration += 1
	end

	# draw the last joist
	y -= joist_spacing
	if (y < y_length - @joist_thickness)
		pt.y = y_length - @joist_thickness
		# puts "pt.y = " + pt.y.to_s
		entities.push(build_joist(pt))
	end

	group = model.active_entities.add_group(entities);
    # translate and rotate the floor back into place
    t = Geom::Transformation.new(root)

    group.transform!(t)
    #UI.messagebox "translate"
    
    t = Geom::Transformation.rotation(rotation_point, Z_AXIS, -angle)
    group.transform!(t)

	save_options_to_drawing(group)
	return group
end

def build_joist(pt)
    lumber = Lumber.new('style' => style,
                        'depth' => @joist_length,
                        'origin' => pt,
                        'rotation' => 0,
                        'orientation' => SIDE,
						'metric' => is_metric(),
                        'layer' => layer)
	group = lumber.draw
    return group
end

end # class Floor

end # module MM_HouseBuilder


#-----------------------------------------------------------------------------
file_loaded("HouseBuilder/HouseBuilder.rb")
