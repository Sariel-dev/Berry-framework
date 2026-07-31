fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'berry-core'
author 'Berry Framework Team'
description 'Single-Resource Core Kernel, Master Berry UI, AntiCheat, Discord RPC & Logger, ContextMenu V6, Emote Engine, Housing Engine, F1 NUI Menu & berry-inventory Engine'
version '1.0.0'

ui_page 'ui/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/init.lua',
    'shared/constants.lua',
    'shared/config.lua',
    'shared/locale.lua',
    'shared/types.lua',
    'shared/utilities.lua',
    'inventory/config.lua'
}

ox_libs {
    'locale',
    'table',
    'math'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/security.lua',
    'server/gameplay.lua',
    'inventory/init.lua',
    'inventory/modules/craftmanager/server.lua',
    'inventory/server/medic.lua'
}

client_scripts {
    'client/core.lua',
    'client/gameplay.lua',
    'client/ui_anticheat.lua',

    -- Context Menu Scripts
    'contextmenu/Utils/screenToWorld.lua',
    'contextmenu/Utils/TextAlignment.lua',
    'contextmenu/Utils/TextFont.lua',
    'contextmenu/Utils/Log.lua',
    'contextmenu/Utils/Color.lua',
    'contextmenu/DefaultValues.lua',
    'contextmenu/Graphics2D/Object2D.lua',
    'contextmenu/Graphics2D/Rect.lua',
    'contextmenu/Graphics2D/Text.lua',
    'contextmenu/Graphics2D/Sprite.lua',
    'contextmenu/Graphics2D/SpriteUV.lua',
    'contextmenu/Graphics2D/Container.lua',
    'contextmenu/Graphics2D/Border.lua',
    'contextmenu/Items/BaseItem.lua',
    'contextmenu/Items/SeparatorItem.lua',
    'contextmenu/Items/ScrollItem.lua',
    'contextmenu/Items/PageItem.lua',
    'contextmenu/Items/TextItem.lua',
    'contextmenu/Items/Item.lua',
    'contextmenu/Items/SpriteItem.lua',
    'contextmenu/Items/SubmenuItem.lua',
    'contextmenu/Items/CheckboxItem.lua',
    'contextmenu/Menu/Menu.lua',
    'contextmenu/Menu/ScrollMenu.lua',
    'contextmenu/Menu/PageMenu.lua',
    'contextmenu/Menu/MenuPool.lua',
    'contextmenu/Menu/ExportMenu.lua',
    'contextmenu/example/player.lua',
    'contextmenu/example/vehicle.lua',

    'inventory/init.lua'
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/preview.html',
    'contextmenu/html/style.css',
    'contextmenu/html/script.js',
    'contextmenu/html/fonts/Inter.ttf',
    'inventory/client.lua',
    'inventory/server.lua',
    'inventory/config_loader.lua',
    'inventory/locales/*.json',
    'inventory/web/build/index.html',
    'inventory/web/build/assets/*.js',
    'inventory/web/build/assets/*.css',
    'inventory/web/images/**/*.png',
    'inventory/web/images/**/*.svg',
    'inventory/web/images/*.png',
    'inventory/web/clothingslotsicons/*.png',
    'inventory/web/svg/*.svg',
    'inventory/web/svg/*.png',
    'inventory/web/bodys/*.*',
    'inventory/modules/**/shared.lua',
    'inventory/modules/**/client.lua',
    'inventory/modules/*.lua',
    'inventory/modules/bridge/**/client.lua',
    'inventory/modules/craftmanager/config.lua',
    'inventory/modules/craftmanager/client.lua',
    'inventory/data/*.lua',
    'inventory/config/*.lua'
}

exports {
    'GetCoreObject',
    'GetPlayer',
    'GetPlayerByIdentifier',
    'GetPlayerByCharacterId',
    'addNotification',
    'Notify',
    'ProgressBar',
    'AddMarker',
    'RemoveMarker',
    'StartSafeCrack',
    'StartHotwire',
    'BanPlayer',
    'PlayEmote',
    'StopEmote',
    'BuyProperty',
    'IsHandcuffed',
    'IsDead',
    'ToggleDisabled',
    'SendDiscordLog'
}

dependencies {
    'oxmysql',
    'ox_lib'
}
