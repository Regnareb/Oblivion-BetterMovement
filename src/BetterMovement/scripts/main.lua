
local sprint_start = 0
local walk_start = 0
local sneak_pressed = false
local sneak_start = 0
local sneak_state = false
local gallop_start = 0
local gallop_state = false
local gallop_pressed = false

local is_automoving = false



-- Works as Hold AND as a Toggle for Sprinting, Walk, Sneak and Gallop.
-- Work as a Hold even if it started as a Toggle.
-- Automove in sprinting mode, you can still switch to sneak, walk or sneakier automove.
-- Sorry I couldn't implement a Hold Automove for all you maniacs out there
-- I wanted to fix the sprint key keeping "running state" after strafing or after exiting a UI, but to not avail... Yet?


-- Known issues: 
-- - You have to have two key binds set for the "Hold Walk" to work (restart the game)
-- - When automoving sprinting, it continues to sprint while exhausted
-- - Automove on a Horse don't allow to Gallop yet
-- I tested A LOT of use cases but let me know if you encounter some weird things



-- Extreme rare occurence bug: When sneaking and walking, then activate autorun and disable sneaking, the sneak state might be unsynced

config = require('config')
local UEHelpers = require("UEHelpers")
local playerCharacter = FindFirstOf("VOblivionPlayerCharacter")
local playerController = UEHelpers.GetPlayerController()
local pawn = playerController.Pawn ---@cast pawn AVPairedPawn




local function GetPlayer() 
    if not playerCharacter or not playerCharacter:IsValid() then
        playerCharacter = FindFirstOf("VOblivionPlayerCharacter")
    end
    if not playerController or not playerController:IsValid() then
        playerController = UEHelpers.GetPlayerController()
    end
    if not pawn or not pawn:IsValid() then
        pawn = playerController.Pawn ---@cast pawn AVPairedPawn
    end
end


local function StopSprint()
    if is_automoving then
        playerCharacter.PairedPawnMovementComponent:StopSprint()
        is_automoving = false
    end
end


local function IsSneaking()
    return playerController.Character.bIsCrouched
end


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleSprint",
    function(ctx)
        -- GetPlayer() 
        if not playerCharacter.PairedPawnMovementComponent:IsSprinting() then
            sprint_start = os.clock()
        elseif playerCharacter.PairedPawnMovementComponent:IsSprinting() and (os.clock() - sprint_start) > config.SPRINT_HOLD_TIME then
            ctx.Self:DisableSprintToggle()
        end
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleSneak",
    function(ctx)
        -- print(pawn.CharacterStatePairingComponent)
        -- print(pawn.CharacterStatePairingComponent.isSneaking))
        sneak_pressed = not sneak_pressed
            -- Hold Sneak       
        if not is_automoving then
            -- If already Toggle Sneaked and pressing Sneak to Hold
            if sneak_pressed and sneak_state then 
                ctx.Self:DisableSneakToggle()
            -- Init for both modes
            if sneak_pressed and sneak_start==0 then
                sneak_state = true
                sneak_start = os.clock()
                return
            -- Hold Sneak
            elseif not sneak_pressed and (os.clock() - sneak_start) > config.SNEAK_HOLD_TIME then
                ctx.Self:DisableSneakToggle()
                sneak_start = 0
                sneak_state = false
                return
            end
            return

        -- Toggle Automove Sneak
        elseif is_automoving and (os.clock() - sneak_start) < config.SNEAK_HOLD_TIME then
            if playerCharacter.PairedPawnMovementComponent.IsSprinting() then
                ctx.Self:DisableSneakToggle()
                sneak_start = 0
                sneak_state = false
            end


            -- BUG

            return
        end
        -- Hold Automove Sneak
        if not playerCharacter.PairedPawnMovementComponent.IsSprinting() and playerController.IsWalking() then  --If both sneaking and walking
            sneak_state = not sneak_state
            if sneak_state then
                sneak_start = os.clock()
            else
                sneak_start = 0
            end
        elseif not playerCharacter.PairedPawnMovementComponent.IsSprinting() then
            sneak_start = 0
            sneak_state = false
            ctx.Self:DisableSneakToggle()
            playerCharacter.PairedPawnMovementComponent:StartSprint()
        elseif playerCharacter.PairedPawnMovementComponent:IsSprinting() then
            sneak_state = true
            sneak_start = os.clock()
            playerCharacter.PairedPawnMovementComponent:StopSprint()
        end
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleWalk",
    function(ctx)
        -- Hold Walk
        if not is_automoving then
            if not ctx.Self:isWalking() then
                walk_start = os.clock()
            elseif ctx.Self:isWalking() and (os.clock() - walk_start) > config.WALK_HOLD_TIME then
                ctx.Self:DisableWalkToggle()
            end
            return
        -- Toggle Automove Walk
        elseif is_automoving and (os.clock() - walk_start) < config.WALK_HOLD_TIME then
            if playerCharacter.PairedPawnMovementComponent.IsSprinting() then
                ctx.Self:DisableWalkToggle()
            end
            return
        end
        -- Hold Automove Walk
        if not playerCharacter.PairedPawnMovementComponent.IsSprinting() and sneak_state then  --If both sneaking and walking
        elseif not playerCharacter.PairedPawnMovementComponent.IsSprinting() then
            ctx.Self:DisableWalkToggle()
            playerCharacter.PairedPawnMovementComponent:StartSprint()
        elseif playerCharacter.PairedPawnMovementComponent:IsSprinting() then
            playerCharacter.PairedPawnMovementComponent:StopSprint()
        end
        walk_start = os.clock()
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleGallop",
    function(ctx)
        gallop_pressed = not gallop_pressed
        if gallop_pressed and gallop_state then 
            ctx.Self:DisableGallopToggle()
        elseif gallop_pressed and gallop_start==0 then
            gallop_state = true
            gallop_start = os.clock()
            return
        elseif not gallop_pressed and (os.clock() - gallop_start) > config.GALLOP_HOLD_TIME then
            ctx.Self:DisableGallopToggle()
            gallop_start = 0
            gallop_state = false
        end
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:AutoMoveInput_Pressed", 
    function(ctx)
        is_automoving = not is_automoving
        if (playerController.IsWalking() or sneak_state) and not config.force_automove_sprint then
            return
        end
        if is_automoving and not (sneak_state or playerController.IsWalking() or playerCharacter.PairedPawnMovementComponent:IsSprinting()) then
            playerCharacter.PairedPawnMovementComponent:StartSprint()
        else 
            playerCharacter.PairedPawnMovementComponent:StopSprint()
        end
    end
)


RegisterHook("/Script/Altar.VLevelChangeData:OnFadeToGameBeginEventReceived", function(context) GetPlayer() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementLeftInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementRightInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementBackwardInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementForwardInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ShiftKeyInput_Pressed", function(ctx) StopSprint() end)



