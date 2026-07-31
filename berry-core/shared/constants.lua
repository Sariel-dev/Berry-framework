BerryConstants = {}

BerryConstants.Version = "1.0.0"
BerryConstants.Name = "Berry Framework"
BerryConstants.ShortName = "Berry"

BerryConstants.Prefixes = {
    Resource = "berry-",
    Event = "berry:",
    InternalEvent = "berry:internal:",
    Table = "berry_",
    Log = "[BERRY]"
}

BerryConstants.Accounts = {
    Cash = "cash",
    Bank = "bank",
    BlackMoney = "black_money"
}

BerryConstants.Permissions = {
    Citoyen = "citoyen",
    Helper = "helper",
    Moderateur = "moderateur",
    Administrateur = "administrateur",
    CoFondateur = "co_fondateur",
    Fondateur = "fondateur"
}

BerryConstants.PermissionHierarchy = {
    -- French Ranks
    citoyen = 0,
    user = 0,
    helper = 1,
    moderateur = 2,
    mod = 2,
    moderator = 2,
    administrateur = 3,
    admin = 3,
    administrator = 3,
    co_fondateur = 4,
    cofondateur = 4,
    superadmin = 4,
    fondateur = 5,
    owner = 5,
    god = 5
}

BerryConstants.LogLevels = {
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4
}
