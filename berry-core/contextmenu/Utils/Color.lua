
local function Clamp(value, min, max)
	return math.max(0, math.min(max, value))
end

local function NewColor(_r, _g, _b, _a)
	assert(
		(not _r or type(_r) == "number") and 
		(not _g or type(_g) == "number") and 
		(not _b or type(_b) == "number") and 
		(not _a or type(_a) == "number"), 
		"Attempted to create Color with incorrect values. Expected number(s)."
	)

	local self = setmetatable({}, Color)

	if (not _r) then
		self = Colors.MISSING_COLOR
	else
		self.r = _r and math.floor(Clamp(_r, 0, 255)) or 0
		self.g = _g and math.floor(Clamp(_g, 0, 255)) or 0
		self.b = _b and math.floor(Clamp(_b, 0, 255)) or 0
		self.a = _a and math.floor(Clamp(_a, 0, 255)) or 255
	end

	-- returns the same color with a different alpha value
	function self:Alpha(alpha)
		return Color(self.r, self.g, self.b, alpha)
	end

	return self
end

Color = {}
Color.__index = Color
setmetatable(Color, {
	__call = function(cls, ...)
		return NewColor(...)
	end
})

Color.__tostring = function(color)
	return string.format("Color(%i, %i, %i, %i)", color.r, color.g, color.b, color.a)
end



Colors = setmetatable({
	White           = Color(255, 255, 255),
	Black           = Color(0, 0, 0),

	Grey            = Color(55, 55, 55),
	LightGrey       = Color(32, 32, 32),
	DarkGrey        = Color(18, 18, 18),
	Gray            = Color(55, 55, 55),
	LightGray       = Color(32, 32, 32),
	DarkGray        = Color(18, 18, 18),
	Hover           = Color(70, 70, 70),

	-- RGB
	Red             = Color(220, 60, 60),
	Green           = Color(60, 200, 120),
	Blue            = Color(80, 140, 255),
	LightRed        = Color(240, 90, 90),
	LightGreen      = Color(90, 220, 150),
	LightBlue       = Color(110, 170, 255),
	DarkRed         = Color(160, 40, 40),
	DarkGreen       = Color(40, 140, 80),
	DarkBlue        = Color(50, 100, 200),

	-- CMY
	Cyan            = Color(70, 200, 200),
	Magenta         = Color(200, 80, 200),
	Yellow          = Color(230, 200, 70),
	LightCyan       = Color(110, 230, 230),
	LightMagenta    = Color(230, 120, 230),
	LightYellow     = Color(240, 220, 110),
	DarkCyan        = Color(40, 140, 140),
	DarkMagenta     = Color(140, 50, 140),
	DarkYellow      = Color(170, 140, 40),

	-- seethrough / invisible
	Invisible		= Color(0, 0, 0, 0),
	SeeThrough		= Color(0, 0, 0, 0),

	-- missing color
	MISSING_COLOR   = Color(0, 0, 0)
}, {
	__index = function(table, key)
		return table.MISSING_COLOR
	end
})
