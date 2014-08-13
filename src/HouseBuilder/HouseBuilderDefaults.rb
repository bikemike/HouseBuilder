# Copyright (C) 2014 Mike Morrison
# See LICENSE file for details.

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

$hb_defaults = 
{ 
	"imperial" => 
	{
		"global" =>
		{
			"lumber_style" => "2x4",
			"header_style" => '4x8',
			"header_sizes" => ["2x4","2x6","4x4","4x6","4x8","4x10","4x12","4x14","6x6","6x8","6x10","8x6","8x8","8x10"],
			"pitch" => 6.0,
			"on_center_spacing" => true,
		},
		"floor" => 
		{
			"style" => "2x6",
			"joist_spacing" => 24,
			"lumber_sizes" => ['2x4','2x6','2x8','2x10','2x12','TJI230x10','TJI230x12'],
		},
		"wall" => 
		{
			"style" => "2x4",
			"stud_spacing" => 16,
			"lumber_sizes" => ['2x4','2x6','2x8'],
			"justify" => "right",
			"height" => 8.feet,
		},
		"door" => 
		{
			"header_height" => 80,
			"width" => 3.feet,
			"height" => 80,
			"justify" => "left",
			"rough_opening" => 0.5,
		},
		"window" => 
		{
			"sill_style" => "2x4",
			"justify" => "left",
			"width" => 5.feet,
			"height" => 3.feet,
			"header_height" => 80,
			"sill_sizes" => ["2x4","2x6","2x8", "4x4", "4x6", "4x8"],

		},
		"roof" => 
		{
			"style" => "2x8",
			"lumber_sizes" => ['2x4','2x6','2x8','2x10','2x12'],
			"ridge_style" => "2x10",
			"overhang" => 18,
			"rake_overhang" => 12,
			"shed_ridge_overhang" => 18,
			"joist_spacing" => 24,
		},
	},
	"metric"=> 
  	{
		"global" =>
		{
			"lumber_style" => "16x50",
			"header_style" => "16x50",
			"header_sizes" => ["16x50","16x75","16x100","16x114","16x150","19x50","19x75","19x100","19x114","19x150","25x75","25x100","25x114","25x150","25x200","25x225","25x300","38x38","38x50","38x75","38x100","38x114","38x150","38x200","38x225","38x300","50x50","50x75","50x100","50x114","50x150","50x200","50x225","50x300","75x75","75x100","75x150","75x200","75x225"],
			"pitch" => 45.0,
			"on_center_spacing" => true,
		},
		"floor" => 
		{
			"style" => "16x50",
			"joist_spacing" => 60.cm,
			"lumber_sizes" => ["16x50","16x75","16x100","16x114","16x150","19x50","19x75","19x100","19x114","19x150","25x75","25x100","25x114","25x150","25x200","25x225","25x300","38x38","38x50","38x75","38x100","38x114","38x150","38x200","38x225","38x300","50x50","50x75","50x100","50x114","50x150","50x200","50x225","50x300","75x75","75x100","75x150","75x200","75x225"],
		},
		"wall" => 
		{
			"style" => "16x50",
			"stud_spacing" => 40.cm,
			"justify" => "right",
			"height" => 244.cm,
			"lumber_sizes" => ["16x50","16x75","16x100","16x114","16x150","19x50","19x75","19x100","19x114","19x150","25x75","25x100","25x114","25x150","25x200","25x225","25x300","38x38","38x50","38x75","38x100","38x114","38x150","38x200","38x225","38x300","50x50","50x75","50x100","50x114","50x150","50x200","50x225","50x300","75x75","75x100","75x150","75x200","75x225"],
		},
		"door" => 
		{
			"header_height" => 204.cm,
			"width" => 100.cm,
			"height" => 204.cm,
			"justify" => "left",
			"rough_opening" => 1.cm,
		},
		"window" => 
		{
			"header_height" => 204.cm,
			"sill_style" => "16x50",
			"justify" => "left",
			"width" => 100.cm,
			"height" => 100.cm,
			"sill_sizes" => ["16x50","16x75","16x100","16x114","16x150","19x50","19x75","19x100","19x114","19x150","25x75","25x100","25x114","25x150","25x200","25x225","25x300","38x38","38x50","38x75","38x100","38x114","38x150","38x200","38x225","38x300","50x50","50x75","50x100","50x114","50x150","50x200","50x225","50x300","75x75","75x100","75x150","75x200","75x225"],

		},
		"roof" => 
		{
			"style" => "16x50",
			"ridge_style" => "16x50",
			"overhang" => 35.cm,
			"rake_overhang" => 30.cm,
			"shed_ridge_overhang" => 35.cm,
			"joist_spacing" => 60.cm,
			"lumber_sizes" => ["16x50","16x75","16x100","16x114","16x150","19x50","19x75","19x100","19x114","19x150","25x75","25x100","25x114","25x150","25x200","25x225","25x300","38x38","38x50","38x75","38x100","38x114","38x150","38x200","38x225","38x300","50x50","50x75","50x100","50x114","50x150","50x200","50x225","50x300","75x75","75x100","75x150","75x200","75x225"],
		},
	}
}
