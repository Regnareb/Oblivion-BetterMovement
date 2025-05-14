
local sprint_start = 0
local walk_start = 0
local sneak_start = 0
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
-- - **You have to have two key binds set for the "Hold Walk" to work (restart the game)**
-- - When automoving sprinting, it continues to sprint while exhausted
-- - Automove on a Horse don't allow to Gallop yet
-- I tested a lot of use cases but let me know if you encounter some weird things


-- You can configurate the mod to:
-- - Set the time where the mode goes from toggle to hold, or deactivate the hold mode completely (0)
-- - Deactivate the automove sprint alltogether (automove_sprint)
-- - When automove sprint is activated and you are sneaking/walking, either choose to stay in sneak/walk or force sprint (force_automove_sprint)
-- - Remove inertia when stopping (StopXXXXDuration)

-- How To Install:
-- - Install UE4SS
-- - Copy the files to 
-- - Add a second bind to the "Walk" keybind if you want to use "Hold Walk" mode

-- VERSION 1.1


config = require('config')
local UEHelpers = require("UEHelpers")


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
    pawn.CharacterMovement.StopRunDuration = config.StopRunDuration
    pawn.CharacterMovement.StopWalkDuration = config.StopWalkDuration
    pawn.CharacterMovement.StopSprintDuration = config.StopSprintDuration
end


local function StopSprint()
    if is_automoving then
        playerCharacter.PairedPawnMovementComponent:StopSprint()
        is_automoving = false
    end
end


local function IsSneaking() return playerController.Character.bIsCrouched end
local function IsSprinting() return playerCharacter.PairedPawnMovementComponent.IsSprinting() end
local function IsRidingHorse() return playerController.IsHorseRiding() end


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleSprint",
    function(ctx)
        if not IsSprinting() then
            sprint_start = os.clock()
        elseif IsSprinting() and (os.clock() - sprint_start) > config.SPRINT_HOLD_TIME then
            ctx.Self:DisableSprintToggle()
        end
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleSneak",
    function(ctx)
        if not IsSneaking() then
            sneak_start = os.clock()
            if is_automoving and IsSprinting() then
                playerCharacter.PairedPawnMovementComponent:StopSprint()
            end
        elseif IsSneaking() and (os.clock() - sneak_start) > config.SNEAK_HOLD_TIME then
            ctx.Self:DisableSneakToggle()
            if is_automoving and not playerController.IsWalking() then
                playerCharacter.PairedPawnMovementComponent:StartSprint()
            end
        end
    end
)


RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ToggleWalk",
    function(ctx)
        if not ctx.Self:isWalking() then
            walk_start = os.clock()
            if is_automoving and IsSprinting() then
                playerCharacter.PairedPawnMovementComponent:StopSprint()
            end
        elseif ctx.Self:isWalking() and (os.clock() - walk_start) > config.WALK_HOLD_TIME then
            ctx.Self:DisableWalkToggle()
            if is_automoving and not IsSneaking() then
                playerCharacter.PairedPawnMovementComponent:StartSprint()
            end
        end
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
        if config.automove_sprint then
            if config.force_automove_sprint then
                if playerController.IsWalking() then end
                if IsSneaking() then pawn.SetSneak(false) end
            end
            print(config.force_automove_sprint)
            if is_automoving and (config.force_automove_sprint or not (IsSneaking() or playerController.IsWalking() or IsSprinting())) then
                playerCharacter.PairedPawnMovementComponent:StartSprint()
            else 
                playerCharacter.PairedPawnMovementComponent:StopSprint()
            end
        end
    end
)


RegisterHook("/Script/Altar.VLevelChangeData:OnFadeToGameBeginEventReceived", function(context) GetPlayer() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementForwardInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementBackwardInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementLeftInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:MovementRightInput_Pressed", function(ctx) StopSprint() end)
RegisterHook("/Script/Altar.VEnhancedAltarPlayerController:ShiftKeyInput_Pressed", function(ctx) StopSprint() end)



