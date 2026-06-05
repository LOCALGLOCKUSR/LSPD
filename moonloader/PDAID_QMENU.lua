script_name("LSPD AID - Menu Roue")
script_description("Pie menu actions police (taser, MDC, vehicule...)")
script_version("7.5.0")
script_author("LGU")

-- Compatible : MoonLoader 0.26.5-beta, SAMPFUNCS 5.7.1 rel.25, SA-MP 0.3.DL, GTA SA 1.0 US

require('sampfuncs')
local imgui = require('mimgui')
local ffi   = require('ffi')

-- ════════════════════════════════════════════════════════════════════════════
--  WINDOWS API  (curseur + simulation clavier)
-- ════════════════════════════════════════════════════════════════════════════

ffi.cdef('typedef struct { long x; long y; } QM_PT; int __stdcall GetCursorPos(QM_PT*);')
ffi.cdef('void __stdcall keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);')

local _u32 = ffi.load('user32')
local _pt  = ffi.new('QM_PT')

local function mouseXY()
    pcall(_u32.GetCursorPos, _pt)
    return _pt.x, _pt.y
end

-- ════════════════════════════════════════════════════════════════════════════
--  KEYBINDS  (raccourcis directs, configures via PDAID_NOTES > Raccourcis)
-- ════════════════════════════════════════════════════════════════════════════

local KEYBINDS_PATH       = "moonloader/config/pdaid_keybinds.json"
local keybinds            = {}
local last_keybinds_check = 0

local function loadKeybinds()
    local f = io.open(KEYBINDS_PATH, "r")
    if not f then keybinds = {}; return end
    local raw = f:read("*a"); f:close()
    local t = {}
    for k, v in raw:gmatch('"([^"]+)"%s*:%s*(%d+)') do
        t[k] = tonumber(v)
    end
    keybinds = t
end

-- ════════════════════════════════════════════════════════════════════════════
--  ETAT GLOBAL
-- ════════════════════════════════════════════════════════════════════════════

local pie_open           = false
local controls_locked    = false
local taser_out          = false
local beanbag_out        = false
local plaquage_out       = false
local balise_on          = false
local current_in_vehicle = false
local last_toggle        = 0
local hovered            = -1
local last_hovered_id    = -1
local hover_start        = 0
local hover_fired        = false
local target             = nil
local pending_cmd        = nil
local pending_key        = nil

local HOVER_DELAY = 0.40   -- secondes de survol pour auto-selectionner

-- ════════════════════════════════════════════════════════════════════════════
--  ITEMS DU PIE
--  in_veh=true : visible uniquement en vehicule
--  needs_id    : ajoute l'ID du joueur le plus proche (conserve pour extensions)
-- ════════════════════════════════════════════════════════════════════════════

local ITEMS_BASE = {
    { cmd="/taser",        cat="arm",  key="1"            },
    { cmd="/beanbag",      cat="arm",  key="2"            },
    { cmd="/plaquage",     cat="arm",  key="3"            },
    { cmd="/bdd menu",     cat="int",  key="4"            },
    { cmd="/911",          cat="int",  key="5"            },
    { cmd="/v coffre",     cat="veh",  key="6"            },
    { cmd="/v coffrelock", cat="veh",  key="7"            },
    { cmd="/v lock",       cat="veh",  key="8"            },
    { cmd="/vehporte",     cat="veh",  key="9"            },
    { cmd="/balise",       cat="nav",  key="0"            },
    { cmd="__lights__",    cat="veh",  key="L", in_veh=true },
}

local ITEMS    = {}
local SEG_HALF = 360/10/2 - 2.5

local function buildActiveItems()
    current_in_vehicle = false
    if PLAYER_PED and PLAYER_PED ~= 0 then
        local ok, r = pcall(isCharInAnyCar, PLAYER_PED)
        current_in_vehicle = ok and r
    end
    ITEMS = {}
    for _, item in ipairs(ITEMS_BASE) do
        if not item.in_veh or current_in_vehicle then
            ITEMS[#ITEMS+1] = item
        end
    end
    local n = #ITEMS
    SEG_HALF = 360/n/2 - 2.5
    for i, item in ipairs(ITEMS) do
        item.angle = (i-1) * (360/n)
    end
end

-- ════════════════════════════════════════════════════════════════════════════
--  LABELS
-- ════════════════════════════════════════════════════════════════════════════

local LABELS = {
    ["/v coffre"]     = "Voir\nCoffre",
    ["/v coffrelock"] = "Coffre\nLock",
    ["/v lock"]       = "Verrouiller",
    ["/vehporte"]     = "Porte",
    ["/bdd menu"]     = "MDC",
    ["/911"]          = "911\nAccepter",
}

local function getLabel(cmd)
    if cmd == "/taser"     then return taser_out    and "Ranger\nTaser"    or "Sortir\nTaser"    end
    if cmd == "/beanbag"   then return beanbag_out  and "Ranger\nBeanbag"  or "Sortir\nBeanbag"  end
    if cmd == "/plaquage"  then return plaquage_out and "Lacher\nPlaquage" or "Plaquer"           end
    if cmd == "/balise"    then return balise_on    and "Balise\nOFF"      or "Balise\nON"        end
    if cmd == "__lights__" then return "Lumieres\nON/OFF"                                         end
    return LABELS[cmd] or cmd
end

-- ════════════════════════════════════════════════════════════════════════════
--  COULEURS  (format DrawList u32 = 0xAABBGGRR)
-- ════════════════════════════════════════════════════════════════════════════

local C = {
    overlay  = 0x55000000,
    arm_def  = 0x88503020,  arm_hov  = 0xCCFF8844,
    int_def  = 0x88304050,  int_hov  = 0xCC22AAFF,
    veh_def  = 0x88305030,  veh_hov  = 0xCC55CC33,
    nav_def  = 0x88203050,  nav_hov  = 0xCC2288FF,
    center   = 0xDD0D0D18,
    text     = 0xEEFFFFFF,
    text_hov = 0xFF00FFFF,
    hint     = 0x55FFFFFF,
    no_tgt   = 0xFF3333CC,
    progress = 0xBBFFFFFF,
}

-- ════════════════════════════════════════════════════════════════════════════
--  GEOMETRIE
-- ════════════════════════════════════════════════════════════════════════════

local R_OUT  = 178
local R_IN   = 58
local R_TEXT = (R_IN + R_OUT) * 0.5

-- ════════════════════════════════════════════════════════════════════════════
--  GESTION CONTROLES
--  lockControls est desactive en vehicule pour eviter le coup de frein brutal.
-- ════════════════════════════════════════════════════════════════════════════

local function lockControls()
    if controls_locked then return end
    if current_in_vehicle then return end
    pcall(lockPlayerControl, true)
    controls_locked = true
end

local function unlockControls()
    pcall(lockPlayerControl, false)
    controls_locked = false
end

-- ════════════════════════════════════════════════════════════════════════════
--  DETECTION DU JOUEUR LE PLUS PROCHE
-- ════════════════════════════════════════════════════════════════════════════

local MAX_TARGET_DIST = 20

local function getValidPed()
    if not PLAYER_PED or PLAYER_PED == 0 then return nil end
    local ok, ex = pcall(doesCharExist, PLAYER_PED)
    return (ok and ex) and PLAYER_PED or nil
end

local function getNearestPlayer()
    local ped = getValidPed()
    if not ped then return nil end
    local ok_p, px, py, pz = pcall(getCharCoordinates, ped)
    if not ok_p then return nil end
    local ok_me, myId = pcall(sampGetLocalPlayerId)
    if not ok_me then return nil end

    local best_id, best_dist, best_name = nil, MAX_TARGET_DIST + 1, "?"
    for id = 0, 999 do
        if id ~= myId then
            local ok_c, conn = pcall(sampIsPlayerConnected, id)
            if ok_c and conn then
                local ok_h, tped = pcall(sampGetCharHandleByPlayerId, id)
                if ok_h and tped and tped ~= 0 then
                    local ok_ex, ex = pcall(doesCharExist, tped)
                    if ok_ex and ex then
                        local ok_tp, tx, ty, tz = pcall(getCharCoordinates, tped)
                        if ok_tp then
                            local d = math.sqrt((tx-px)^2 + (ty-py)^2 + (tz-pz)^2)
                            if d < best_dist then
                                best_dist = d
                                best_id   = id
                                local ok_n, nm = pcall(sampGetPlayerNickname, id)
                                best_name = ok_n and nm or ("ID "..id)
                            end
                        end
                    end
                end
            end
        end
    end
    return best_id and { id=best_id, name=best_name, dist=best_dist } or nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  CONSTRUCTION DE LA COMMANDE FINALE
-- ════════════════════════════════════════════════════════════════════════════

local function buildCmd(item)
    if item.cmd == "/balise" then
        return balise_on and "/balise on" or "/balise off"
    end
    if item.needs_id and target then
        return item.cmd .. " " .. target.id
    end
    return item.cmd
end

-- selectItem() ne fait QUE setter des flags (pas de wait/sampSendChat/lockControl).
-- Peut etre appele depuis imgui.OnFrame ET depuis main().
local function selectItem(item)
    if item.cmd == "__lights__" then
        pending_cmd = "/gyro"
        pending_key = 0x4E
        pie_open    = false
        return
    end
    if item.cmd == "/taser" then
        taser_out = not taser_out
        if taser_out then beanbag_out = false end
    elseif item.cmd == "/beanbag" then
        beanbag_out = not beanbag_out
        if beanbag_out then taser_out = false end
    elseif item.cmd == "/plaquage" then
        plaquage_out = not plaquage_out
    elseif item.cmd == "/balise" then
        balise_on = not balise_on
    end
    pending_cmd = buildCmd(item)
    pie_open    = false
end

-- ════════════════════════════════════════════════════════════════════════════
--  HELPERS DESSIN
-- ════════════════════════════════════════════════════════════════════════════

local function drawSlice(dl, cx, cy, angle_deg, color)
    local a_min = math.rad(angle_deg - SEG_HALF)
    local a_max = math.rad(angle_deg + SEG_HALF)
    local ctr   = imgui.ImVec2(cx, cy)
    dl:PathArcTo(ctr, R_OUT, a_min, a_max, 20)
    dl:PathArcTo(ctr, R_IN,  a_max, a_min, 20)
    dl:PathFillConvex(color)
end

local function drawTextCenter(dl, x, y, color, text)
    local lh    = imgui.GetTextLineHeight()
    local lines = {}
    for l in text:gmatch("[^\n]+") do lines[#lines+1] = l end
    local ty = y - (#lines * lh) * 0.5
    for _, line in ipairs(lines) do
        local ts = imgui.CalcTextSize(line)
        dl:AddText(imgui.ImVec2(x - ts.x*0.5, ty), color, line)
        ty = ty + lh
    end
end

-- Arc de progression blanc a l'interieur de la tranche survolee (hover timer).
local function drawProgressArc(dl, cx, cy, angle_deg, frac)
    if frac <= 0 then return end
    local span  = math.rad(SEG_HALF * 2)
    local a_min = math.rad(angle_deg - SEG_HALF)
    local a_max = a_min + frac * span
    local ctr   = imgui.ImVec2(cx, cy)
    dl:PathArcTo(ctr, R_IN + 9, a_min, a_max, 20)
    dl:PathArcTo(ctr, R_IN + 2, a_max, a_min, 20)
    dl:PathFillConvex(C.progress)
end

-- ════════════════════════════════════════════════════════════════════════════
--  RENDU PIE MENU
--
--  ARCHITECTURE :
--  imgui.OnFrame => hook D3D9 Present, hors coroutine main().
--  wait() / lockPlayerControl() / sampSendChat() INTERDITS ici.
--  Toute action se fait via pending_cmd / pending_key lus dans main().
-- ════════════════════════════════════════════════════════════════════════════

imgui.OnFrame(
    function() return pie_open end,
    function(self)
        self.HideCursor = false

        local sw, sh = getScreenResolution()
        if not sw or sw == 0 then
            pie_open = false
            return
        end
        local cx, cy = sw * 0.5, sh * 0.5

        imgui.SetNextWindowPos(imgui.ImVec2(0, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(sw, sh))
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))

        local wflags = imgui.WindowFlags.NoTitleBar
                     + imgui.WindowFlags.NoResize
                     + imgui.WindowFlags.NoScrollbar
                     + imgui.WindowFlags.NoCollapse
                     + imgui.WindowFlags.NoBackground

        local opened = imgui.Begin("##pdaid_pie", nil, wflags)

        if opened then
            local ok = pcall(function()
                local dl = imgui.GetWindowDrawList()

                local mx, my = mouseXY()
                local dx, dy = mx - cx, my - cy
                local dist   = math.sqrt(dx*dx + dy*dy)
                local mdeg   = math.deg(math.atan2(dy, dx))
                if mdeg < 0 then mdeg = mdeg + 360 end

                -- Calcul de la tranche survolee
                local new_hovered = -1
                if dist >= R_IN then
                    local best = 181
                    for i, item in ipairs(ITEMS) do
                        local d = math.abs(mdeg - item.angle)
                        if d > 180 then d = 360 - d end
                        if d < best then best = d; new_hovered = i end
                    end
                end

                -- Timer hover : reset si la tranche change
                if new_hovered ~= last_hovered_id then
                    last_hovered_id = new_hovered
                    hover_start     = os.clock()
                    hover_fired     = false
                end
                hovered = new_hovered

                -- Fraction de remplissage (0..1) pour l'arc de progression
                local hov_frac = 0
                if hovered > 0 and not hover_fired then
                    hov_frac = math.min(1.0, (os.clock() - hover_start) / HOVER_DELAY)
                    if hov_frac >= 1.0 then
                        hover_fired = true
                        selectItem(ITEMS[hovered])
                    end
                end

                -- Fond semi-transparent
                dl:AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh), C.overlay)

                -- Tranches
                for i, item in ipairs(ITEMS) do
                    local is_h = (i == hovered)
                    local fill
                    if     item.cat == "arm" then fill = is_h and C.arm_hov or C.arm_def
                    elseif item.cat == "int" then fill = is_h and C.int_hov or C.int_def
                    elseif item.cat == "nav" then fill = is_h and C.nav_hov or C.nav_def
                    else                          fill = is_h and C.veh_hov or C.veh_def
                    end
                    drawSlice(dl, cx, cy, item.angle, fill)

                    -- Arc de chargement sur la tranche survolee
                    if is_h and hov_frac > 0 then
                        drawProgressArc(dl, cx, cy, item.angle, hov_frac)
                    end

                    local a   = math.rad(item.angle)
                    local lx  = cx + R_TEXT * math.cos(a)
                    local ly  = cy + R_TEXT * math.sin(a)
                    local txt = "[" .. item.key .. "] " .. getLabel(item.cmd)
                    drawTextCenter(dl, lx, ly, is_h and C.text_hov or C.text, txt)
                end

                -- Cercle central
                dl:AddCircleFilled(imgui.ImVec2(cx, cy), R_IN, C.center, 40)

                -- Info centrale
                if hovered > 0 then
                    local item = ITEMS[hovered]
                    local cl   = getLabel(item.cmd):gsub("\n", " ")
                    local tcol = C.text_hov
                    if item.needs_id then
                        if target then
                            cl = cl
                               .. "\n[" .. target.id .. "] " .. target.name
                               .. "\n" .. string.format("%.1f m", target.dist)
                        else
                            cl   = cl .. "\nAucune cible"
                            tcol = C.no_tgt
                        end
                    end
                    drawTextCenter(dl, cx, cy, tcol, cl)
                else
                    drawTextCenter(dl, cx, cy, C.hint, "Deplacer\nla souris")
                end

                -- Clic gauche = selection immediate (sans attendre le timer)
                if imgui.IsMouseClicked(0) and hovered > 0 and not hover_fired then
                    hover_fired = true
                    selectItem(ITEMS[hovered])
                end

                if imgui.IsMouseClicked(1) then
                    pie_open = false
                end
            end)

            if not ok then
                pie_open = false
            end
        end

        imgui.End()
        imgui.PopStyleVar(1)

        if isKeyJustPressed(0x1B) then
            pie_open = false
        end
    end
)

-- ════════════════════════════════════════════════════════════════════════════
--  NETTOYAGE A L'ARRET DU SCRIPT
-- ════════════════════════════════════════════════════════════════════════════

function onScriptTerminate()
    unlockControls()
end

-- ════════════════════════════════════════════════════════════════════════════
--  BOUCLE PRINCIPALE (seul endroit sur pour wait/lock/sampSendChat)
-- ════════════════════════════════════════════════════════════════════════════

function main()
    while not isSampAvailable() do wait(100) end
    wait(500)
    loadKeybinds()

    sampAddChatMessage(
        "{00AAFF}[LSPD AID]{FFFFFF} Menu Roue v7.5 -- {FFFF00}X{FFFFFF} = ouvrir",
        -1)

    while true do
        wait(0)

        -- Execution de la commande selectionnee dans le pie
        if pending_cmd then
            local cmd = pending_cmd
            pending_cmd = nil
            pcall(sampSendChat, cmd)
        end

        -- Watchdog : liberation des controles si pie ferme
        if not pie_open and controls_locked then
            unlockControls()
        end

        -- Simulation de touche Windows (ex. N = lumieres)
        if pending_key then
            local vk = pending_key
            pending_key = nil
            _u32.keybd_event(vk, 0, 0, 0)
            _u32.keybd_event(vk, 0, 2, 0)
        end

        -- Rechargement des keybinds depuis le fichier (toutes les 5s)
        local now = os.clock()
        if now - last_keybinds_check > 5 then
            loadKeybinds()
            last_keybinds_check = now
        end

        -- Detection chat/dialog actif (reutilise pour X et hotkeys)
        local ok1, ch = pcall(sampIsChatInputActive)
        local ok2, dg = pcall(sampIsDialogActive)
        local input_active = (ok1 and ch) or (ok2 and dg)

        -- Raccourcis directs (configures via PDAID_NOTES > Raccourcis)
        if not pie_open and not input_active then
            for _, item in ipairs(ITEMS_BASE) do
                if item.cmd ~= "__lights__" then
                    local vk = keybinds[item.cmd]
                    if vk and vk > 0 and isKeyJustPressed(vk) then
                        target = getNearestPlayer()
                        selectItem(item)
                        break
                    end
                end
            end
        end

        -- Touche X : ouvrir / fermer le pie (debounce 250ms)
        if not input_active and now - last_toggle > 0.25 and isKeyJustPressed(0x58) then
            last_toggle = now
            pie_open    = not pie_open
            if pie_open then
                buildActiveItems()
                target          = getNearestPlayer()
                lockControls()
                last_hovered_id = -1
                hover_start     = 0
                hover_fired     = false
            else
                unlockControls()
            end
        end
    end
end
