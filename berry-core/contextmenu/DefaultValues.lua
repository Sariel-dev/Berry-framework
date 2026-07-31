
-- debug levels
LOG = {
	-- shows information
	INFO	= false,
	-- shows debug information
	DEBUG	= false,
	-- shows warnings
	WARNING	= false,
	-- shows errors
	ERROR	= true
}

-- default values for the menus

ContextMenuUseNui = true

--   item background
BACKGROUND = {
	-- texture dictionary name
	TXD		= "customSprites",
	-- texture name
	NAME	= "gradient_4_60",
	-- color
	COLOR	= Colors.DarkGrey:Alpha(235),
	-- highlight color
	H_COLOR	= Colors.Hover:Alpha(235),
	-- disabled color
	D_COLOR = Colors.DarkGrey:Alpha(160)
}

--   text values
TEXT = {
	-- font type
	FONT	= TextFont.ChaletComprimeCologne,
	-- color
	COLOR	= Colors.White:Alpha(235),
	-- highlight color
	H_COLOR	= Colors.White:Alpha(255),
	-- disabled color
	D_COLOR = Colors.Grey
}

--   border color
BORDER = {
	COLOR = Colors.Invisible
}
