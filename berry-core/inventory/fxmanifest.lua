fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
name 'ox_inventory'
author 'Overextended'
version '2.44.1'
repository 'https://github.com/overextended/ox_inventory'
description 'Slot-based inventory with item metadata support'
escrow_ignore { '**/*' }
dependencies {
    '/server:6116',
    '/onesync',
    'oxmysql',
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

ox_libs {
    'locale',
    'table',
    'math',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'init.lua',
    'modules/craftmanager/server.lua',
    'server/medic.lua'
}

client_script 'init.lua'

ui_page 'web/build/index.html'

files {
    'client.lua',
    'server.lua',
    'config_loader.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/images/**/*.png',
    'web/images/**/*.svg',
    'web/images/*.png',
    'web/clothingslotsicons/*.png',
    'web/svg/*.svg',
    'web/svg/*.png',
    'web/bodys/*.*',
    'modules/**/shared.lua',
    'modules/**/client.lua',
    'modules/*.lua',
    'modules/bridge/**/client.lua',
    'modules/craftmanager/config.lua',
    'modules/craftmanager/client.lua',
    'data/*.lua',
    'config/*.lua',
}

escrow_ignore {
    'config.lua',
    'config/*.lua',
    'modules/**/config.lua',
    'data/*.lua',
    'modules/items/containers.lua',
    'client.lua',
    'server.lua',
    'init.lua',
    'config_loader.lua',
    'modules/*.lua',
    'modules/**/client.lua',
    'modules/**/server.lua',
    'modules/**/shared.lua',
}

dependency '/assetpacks'