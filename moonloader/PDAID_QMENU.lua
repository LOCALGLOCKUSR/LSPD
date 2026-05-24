script_name("LSPD AID - Menu Roue")
script_description("Pie menu actions police (taser, menottes, vehicule...)")
script_version("7.3.0")
script_author("LGU")

-- Compatible : MoonLoader 0.26.5-beta, SAMPFUNCS 5.7.1 rel.25, SA-MP 0.3.DL, GTA SA 1.0 US

require('sampfuncs')
local imgui = require('mimgui')
local ffi   = require('ffi')

-- ════════════════════════════════════════════════════════════════════════════
--  CURSOR POSITION  (Windows API — position absolue ecran)
-- ════════════════════════════════════════════════════════════════════════════

ffi.cdef('typedef struct { long x; long y; } QM_PT; int __stdcall GetCursorPos(QM_PT*);')
local _u32 = ffi.load('user32')
local _pt  = ffi.new('QM_PT')
local function mouseXY()
    pcall(_u32.GetCursorPos, _pt)
    return _pt.x, _pt.y
end

-- ════════════════════════════════════════════════════════════════════════════
--  ETAT GLOBAL
-- ════════════════════════════════════════════════════════════════════════════

local pie_open        = false
local controls_locked = false  -- suivi exact du lockPlayerControl (evite double-lock/unlock)
local taser_out       = false
local beanbag_out     = false
local plaquage_out    = false
local balise_on       = false
local last_toggle     = 0
local hovered         = -1
local target          = nil
local pending_cmd     = nil    -- commande a executer depuis main() (jamais depuis OnFrame)

-- ════════════════════════════════════════════════════════════════════════════
--  ITEMS DU PIE
--  angle : 0=droite, 90=bas, sens horaire
--  needs_id : true = ajoute l'ID du joueur le plus proche a la commande
-- ════════════════════════════════════════════════════════════════════════════

local ITEMS = {
    { angle=  0, cmd="/taser",        cat="arm",  key="1"                },
    { angle= 33, cmd="/beanbag",      cat="arm",  key="2"                },
    { angle= 65, cmd="/plaquage",     cat="arm",  key="3"                },
    { angle= 98, cmd="/menotter",     cat="int",  key="4", needs_id=true },
    { angle=131, cmd="/demenotter",   cat="int",  key="5", needs_id=true },
    { angle=164, cmd="/911",          cat="int",  key="6"                },
    { angle=196, cmd="/v coffre",     cat="veh",  key="7"                },
    { angle=229, cmd="/v coffrelock", cat="veh",  key="8"                },
    { angle=262, cmd="/v lock",       cat="veh",  key="9"                },
    { angle=295, cmd="/vehporte",     cat="veh",  key="0"                },
    { angle=327, cmd="/balise",       cat="nav",  key="B"                },
}

local LABELS = {
    ["/v coffre"]     = "Voir\nCoffre",
    ["/v coffrelock"] = "Coffre\nLock",
    ["/v lock"]       = "Verrouiller",
    ["/vehporte"]     = "Porte",
    ["/menotter"]     = "Menotter",
    ["/demenotter"]   = "Demenotter",
    ["/911"]          = "911\nAccepter",
}

local function getLabel(cmd)
    if cmd == "/taser"    then return taser_out    and "Ranger\nTaser"   or "Sortir\nTaser"   end
    if cmd == "/beanbag"  then return beanbag_out  and "Ranger\nBeanbag" or "Sortir\nBeanbag" end
    if cmd == "/plaquage" then return plaquage_out and "Lacher\nPlaquage" or "Plaquer"         end
    if cmd == "/balise"   then return balise_on    and "Balise\nOFF"     or "Balise\nON"      end
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
}

-- ════════════════════════════════════════════════════════════════════════════
--  GEOMETRIE
-- ════════════════════════════════════════════════════════════════════════════

local R_OUT    = 178
local R_IN     = 58
local SEG_HALF = 360/11/2 - 2.5   -- 11 tranches : ~32.7 degres chacune, 5 degres de gap
local R_TEXT   = (R_IN + R_OUT) * 0.5

-- ════════════════════════════════════════════════════════════════════════════
--  GESTION CONTROLES (centralisee — appelee UNIQUEMENT depuis main())
--  Ne jamais appeler lockControls/unlockControls depuis imgui.OnFrame.
-- ════════════════════════════════════════════════════════════════════════════

local function lockControls()
    if controls_locked then return end
    pcall(lockPlayerControl, true)
    controls_locked = true
end

local function unlockControls()
    pcall(lockPlayerControl, false)
    controls_locked = false  -- reset meme si pcall echoue
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

-- Appelee depuis imgui.OnFrame : ne fait QUE setter les flags.
-- INTERDIT : wait(), lockPlayerControl(), sampSendChat() ici.
-- Tout ca se passe dans main() au prochain tick.
local function selectItem(item)
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

-- ════════════════════════════════════════════════════════════════════════════
--  RENDU PIE MENU
--
--  ARCHITECTURE IMPORTANTE :
--  imgui.OnFrame tourne dans le hook D3D9 Present, PAS dans la coroutine main().
--  => wait() est INTERDIT ici (yield du mauvais contexte = freeze garanti)
--  => lockPlayerControl() est INTERDIT ici (gere dans main())
--  => sampSendChat() est INTERDIT ici (gere dans main() via pending_cmd)
--
--  Le corps de rendu est entoure d'un pcall : si une erreur Lua survient
--  pendant le dessin, le menu se ferme proprement et main() libere les controles.
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
            -- pcall sur le contenu uniquement : Begin/End et PushStyleVar/PopStyleVar
            -- restent toujours equilibres meme en cas d'erreur.
            local ok = pcall(function()
                local dl = imgui.GetWindowDrawList()

                local mx, my = mouseXY()
                local dx, dy = mx - cx, my - cy
                local dist   = math.sqrt(dx*dx + dy*dy)
                local mdeg   = math.deg(math.atan2(dy, dx))
                if mdeg < 0 then mdeg = mdeg + 360 end

                hovered = -1
                if dist >= R_IN then
                    local best = 181
                    for i, item in ipairs(ITEMS) do
                        local d = math.abs(mdeg - item.angle)
                        if d > 180 then d = 360 - d end
                        if d < best then best = d; hovered = i end
                    end
                end

                -- Fond semi-transparent
                dl:AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh), C.overlay)

                -- Tranches + labels
                for i, item in ipairs(ITEMS) do
                    local is_h = (i == hovered)
                    local fill
                    if     item.cat == "arm"  then fill = is_h and C.arm_hov  or C.arm_def
                    elseif item.cat == "int"  then fill = is_h and C.int_hov  or C.int_def
                    elseif item.cat == "nav"  then fill = is_h and C.nav_hov  or C.nav_def
                    else                           fill = is_h and C.veh_hov  or C.veh_def
                    end
                    drawSlice(dl, cx, cy, item.angle, fill)

                    local a   = math.rad(item.angle)
                    local lx  = cx + R_TEXT * math.cos(a)
                    local ly  = cy + R_TEXT * math.sin(a)
                    local txt = "[" .. item.key .. "] " .. getLabel(item.cmd)
                    drawTextCenter(dl, lx, ly, is_h and C.text_hov or C.text, txt)
                end

                -- Cercle central
                dl:AddCircleFilled(imgui.ImVec2(cx, cy), R_IN, C.center, 40)

                -- Texte central : info tranche survolee
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

                -- Clic gauche : selectionner la tranche
                if imgui.IsMouseClicked(0) and hovered > 0 then
                    selectItem(ITEMS[hovered])
                end

                -- Clic droit : annuler sans action
                if imgui.IsMouseClicked(1) then
                    pie_open = false
                end
            end)

            -- Si erreur de rendu : fermeture de securite (main() liberera les controles)
            if not ok then
                pie_open = false
            end
        end

        -- Toujours appeles pour maintenir l'etat ImGui coherent
        imgui.End()
        imgui.PopStyleVar(1)

        -- Echap : annuler (hors du Begin/End, toujours evalue)
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
--  BOUCLE PRINCIPALE (coroutine main — seul endroit sur pour wait/lock/samp)
-- ════════════════════════════════════════════════════════════════════════════

function main()
    while not isSampAvailable() do wait(100) end
    wait(500)

    sampAddChatMessage(
        "{00AAFF}[LSPD AID]{FFFFFF} Menu Roue v7.3 -- {FFFF00}X{FFFFFF} = ouvrir",
        -1)

    while true do
        wait(0)

        -- Execution de la commande selectionnee dans le pie (set par selectItem)
        -- Fait ici car sampSendChat est sur dans le contexte coroutine main().
        if pending_cmd then
            local cmd = pending_cmd
            pending_cmd = nil
            pcall(sampSendChat, cmd)
        end

        -- Watchdog : si le pie est ferme (par clic, clic droit, Echap, ou erreur)
        -- mais que les controles sont encore bloques, on les libere ici.
        -- C'est le filet de securite contre tous les cas de fermeture imprevisibles.
        if not pie_open and controls_locked then
            unlockControls()
        end

        -- Touche X : ouvrir / fermer le pie (debounce 250ms)
        local now = os.clock()
        if now - last_toggle > 0.25 and isKeyJustPressed(0x58) then
            local ok1, ch = pcall(sampIsChatInputActive)
            local ok2, dg = pcall(sampIsDialogActive)
            if (not ok1 or not ch) and (not ok2 or not dg) then
                last_toggle = now
                pie_open = not pie_open
                if pie_open then
                    target = getNearestPlayer()
                    lockControls()
                else
                    unlockControls()
                end
            end
        end
    end
end
