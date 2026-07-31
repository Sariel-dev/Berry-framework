fx_version 'cerulean'
games { 'gta5' }
author 's4na.re'
description 'Context Menu V6 - Flashback'
ui_page 'html/index.html'

client_scripts {
	'Utils/screenToWorld.lua',
	'Utils/TextAlignment.lua',
	'Utils/TextFont.lua',
	'Utils/Log.lua',
	'Utils/Color.lua',
	'DefaultValues.lua',

	'Graphics2D/Object2D.lua',
	'Graphics2D/Rect.lua',
	'Graphics2D/Text.lua',
	'Graphics2D/Sprite.lua',
	'Graphics2D/SpriteUV.lua',
	'Graphics2D/Container.lua',
	'Graphics2D/Border.lua',

	'Items/BaseItem.lua',
	'Items/SeparatorItem.lua',
	'Items/ScrollItem.lua',
	'Items/PageItem.lua',
	'Items/TextItem.lua',
	'Items/Item.lua',
	'Items/SpriteItem.lua',
	'Items/SubmenuItem.lua',
	'Items/CheckboxItem.lua',
	'Menu/Menu.lua',
	'Menu/ScrollMenu.lua',
	'Menu/PageMenu.lua',
	'Menu/MenuPool.lua',
	'Menu/ExportMenu.lua',
	'example/*.lua'
}

files {
	'html/index.html',
	'html/style.css',
	'html/script.js',
	'html/fonts/Inter.ttf'
}

exports {
    'ToggleDisabled'
}