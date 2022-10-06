
-- // Module // --
local Module = {}

-- Backend
Module.MAX_EQUIPPED_MAGICS = 5

Module.MAX_ELEMENTS_PER_ABILITY = 1
Module.MAX_OPERATIONS_PER_ABILITY = 10

Module.MAX_ABILITIES_IN_INVENTORY = 20 -- maximum abilities the player can hold
Module.COOLDOWN_INBETWEEN_ABILITIES = 5

-- Frontend
Module.ABILITY_TRIGGER_ACTION_NAME = 'AbilityTriggerAction'
Module.ABILITY_TRIGGER_START = 'AbilityTriggerSTART'
Module.ABILITY_TRIGGER_END = 'AbilityTriggerEND'
Module.ABILITY_KEYBIND_MAP = {Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V, Enum.KeyCode.G}

return Module