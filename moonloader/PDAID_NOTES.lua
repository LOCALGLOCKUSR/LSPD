script_name("LSPD AID - Carnet")
script_description("Carnet d'enquete et de fichage LSPD")
script_version("1.0.1")
script_author("LGU")

-- Compatible : MoonLoader 0.26.5-beta, SAMPFUNCS 5.7.1, SA-MP 0.3.DL

local imgui = require('mimgui')
local ffi   = require('ffi')

-- ============================================================================
--  JSON MINIMAL (LuaJIT 2.1 / Lua 5.1 -- pas de dependances externes)
-- ============================================================================

local function json_escape(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"',  '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local function encode_val(v)
    local t = type(v)
    if     t == 'nil'     then return 'null'
    elseif t == 'boolean' then return v and 'true' or 'false'
    elseif t == 'number'  then return tostring(v)
    elseif t == 'string'  then return '"' .. json_escape(v) .. '"'
    elseif t == 'table'   then
        if #v > 0 then
            local p = {}
            for i = 1, #v do p[i] = encode_val(v[i]) end
            return '[' .. table.concat(p, ',') .. ']'
        else
            local p = {}
            for k, val in pairs(v) do
                if type(k) == 'string' then
                    p[#p+1] = '"' .. json_escape(k) .. '":' .. encode_val(val)
                end
            end
            return '{' .. table.concat(p, ',') .. '}'
        end
    end
    return 'null'
end

local json_src, json_pos
local jval  -- forward declaration

local function jskip()
    while json_pos <= #json_src and json_src:sub(json_pos,json_pos):match('%s') do
        json_pos = json_pos + 1
    end
end

local function jstring()
    json_pos = json_pos + 1
    local parts = {}
    local esc_map = {['"']='"',['\\']='\\',['n']='\n',['r']='\r',['t']='\t',['/']=  '/'}
    while json_pos <= #json_src do
        local c = json_src:sub(json_pos, json_pos)
        if c == '"' then json_pos = json_pos + 1; return table.concat(parts) end
        if c == '\\' then
            json_pos = json_pos + 1
            local e = json_src:sub(json_pos, json_pos)
            parts[#parts+1] = esc_map[e] or e
        else
            parts[#parts+1] = c
        end
        json_pos = json_pos + 1
    end
    return table.concat(parts)
end

local function jarray()
    json_pos = json_pos + 1
    local arr = {}
    jskip()
    if json_src:sub(json_pos,json_pos) == ']' then json_pos = json_pos+1; return arr end
    while json_pos <= #json_src do
        arr[#arr+1] = jval()
        jskip()
        local c = json_src:sub(json_pos,json_pos)
        if c == ']' then json_pos = json_pos+1; return arr end
        if c == ',' then json_pos = json_pos+1 end
        jskip()
    end
    return arr
end

local function jobject()
    json_pos = json_pos + 1
    local obj = {}
    jskip()
    if json_src:sub(json_pos,json_pos) == '}' then json_pos = json_pos+1; return obj end
    while json_pos <= #json_src do
        jskip()
        if json_src:sub(json_pos,json_pos) ~= '"' then break end
        local k = jstring()
        jskip()
        if json_src:sub(json_pos,json_pos) == ':' then json_pos = json_pos+1 end
        jskip()
        obj[k] = jval()
        jskip()
        local c = json_src:sub(json_pos,json_pos)
        if c == '}' then json_pos = json_pos+1; return obj end
        if c == ',' then json_pos = json_pos+1 end
    end
    return obj
end

jval = function()
    jskip()
    local c = json_src:sub(json_pos, json_pos)
    if     c == '"' then return jstring()
    elseif c == '{' then return jobject()
    elseif c == '[' then return jarray()
    elseif json_src:sub(json_pos,json_pos+3) == 'true'  then json_pos=json_pos+4; return true
    elseif json_src:sub(json_pos,json_pos+4) == 'false' then json_pos=json_pos+5; return false
    elseif json_src:sub(json_pos,json_pos+3) == 'null'  then json_pos=json_pos+4; return nil
    else
        local n = json_src:match('^-?%d+%.?%d*[eE]?[+%-]?%d*', json_pos)
        if n then json_pos = json_pos + #n; return tonumber(n) end
    end
    json_pos = json_pos + 1
    return nil
end

local function json_decode(s)
    if not s or s == '' then return nil end
    json_src, json_pos = s, 1
    local ok, r = pcall(jval)
    return ok and r or nil
end

-- ============================================================================
--  ETAT GLOBAL
-- ============================================================================

local notebook_open  = false
local nb_first_open  = true
local dirty          = false
local last_save_time = 0

local data    = { pages = {}, active_page = 1, keywords = {} }
local next_id = 1

local opt_names  = true
local opt_plates = true

local TYPE_KEYS  = { "suspect", "vehicule", "enquete", "libre" }
local TYPE_NAMES = { "Suspect", "Vehicule", "Enquete", "Libre" }
local TYPE_PFX   = { "[S]", "[V]", "[E]", "[L]" }
local TYPE_COLS  = {
    imgui.ImVec4(1.0, 0.3, 0.3, 1.0),
    imgui.ImVec4(1.0, 0.9, 0.2, 1.0),
    imgui.ImVec4(0.2, 0.9, 1.0, 1.0),
    imgui.ImVec4(0.9, 0.9, 0.9, 1.0),
}
local KW_KEYS   = { "cyan", "violet", "vert", "orange" }
local KW_NAMES  = { "Cyan", "Violet", "Vert", "Orange" }
local KW_CVEC   = {
    {0.2, 0.9, 1.0, 1.0},
    {0.7, 0.3, 1.0, 1.0},
    {0.3, 1.0, 0.4, 1.0},
    {1.0, 0.6, 0.1, 1.0},
}

-- Buffers ffi persistants entre frames
local BUF_TITLE   = ffi.new('char[129]')
local BUF_CONTENT = ffi.new('char[8193]')
local BUF_KWORD   = ffi.new('char[65]')
local BUF_NTITLE  = ffi.new('char[129]')

local cur_page_id       = -1
local page_type_idx     = imgui.new.int(3)
local kw_color_idx      = imgui.new.int(0)
local new_page_type_idx = imgui.new.int(3)
local b_names_ref       = imgui.new.bool(true)
local b_plates_ref      = imgui.new.bool(true)
local p_open            = imgui.new.bool(true)

local open_new_flag = false
local open_del_flag = false

-- ============================================================================
--  KEYBINDS UI  (onglet Raccourcis dans la colonne droite)
-- ============================================================================

local KEYBINDS_PATH_NB = "moonloader/config/pdaid_keybinds.json"
local nb_keybinds      = {}
local nb_right_tab     = imgui.new.int(0)   -- 0 = Couleurs, 1 = Raccourcis
local listening_cmd    = nil

local QMENU_ITEMS_CFG = {
    { cmd="/taser",        label="Taser"    },
    { cmd="/beanbag",      label="Beanbag"  },
    { cmd="/plaquage",     label="Plaquage" },
    { cmd="/bdd menu",     label="MDC"      },
    { cmd="/911",          label="911"      },
    { cmd="/v coffre",     label="Coffre"   },
    { cmd="/v coffrelock", label="C.Lock"   },
    { cmd="/v lock",       label="V.Lock"   },
    { cmd="/vehporte",     label="Porte"    },
    { cmd="/balise",       label="Balise"   },
}

local BINDABLE_VKS = {
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,  -- F1-F8
    0x78,                                               -- F9
    -- 0x79 = F10 exclu (toggle carnet)
    0x7A, 0x7B,                                        -- F11-F12
    0x60, 0x61, 0x62, 0x63, 0x64,                     -- Num0-4
    0x65, 0x66, 0x67, 0x68, 0x69,                     -- Num5-9
}

local VK_NAMES = {
    [0x70]="F1",   [0x71]="F2",   [0x72]="F3",   [0x73]="F4",
    [0x74]="F5",   [0x75]="F6",   [0x76]="F7",   [0x77]="F8",
    [0x78]="F9",   [0x7A]="F11",  [0x7B]="F12",
    [0x60]="Num0", [0x61]="Num1", [0x62]="Num2", [0x63]="Num3", [0x64]="Num4",
    [0x65]="Num5", [0x66]="Num6", [0x67]="Num7", [0x68]="Num8", [0x69]="Num9",
}

local function vkname(vk)
    if not vk or vk == 0 then return "Aucun" end
    return VK_NAMES[vk] or ("VK"..vk)
end

local function save_keybinds_nb()
    local f = io.open(KEYBINDS_PATH_NB, "w")
    if not f then return end
    local parts = {}
    for cmd, vk in pairs(nb_keybinds) do
        parts[#parts+1] = '"' .. cmd:gsub('"', '\\"') .. '":' .. tostring(vk)
    end
    f:write("{" .. table.concat(parts, ",") .. "}")
    f:close()
end

local function load_keybinds_nb()
    local f = io.open(KEYBINDS_PATH_NB, "r")
    if not f then nb_keybinds = {}; return end
    local raw = f:read("*a"); f:close()
    local t = {}
    for k, v in raw:gmatch('"([^"]+)"%s*:%s*(%d+)') do
        t[k] = tonumber(v)
    end
    nb_keybinds = t
end

-- ============================================================================
--  SAVE / LOAD
-- ============================================================================

local SAVE_PATH = "moonloader/config/pdaid_notes.json"

local function now_str() return os.date("%Y-%m-%d %H:%M") end

local function save_notebook()
    local f = io.open(SAVE_PATH, "w")
    if not f then return end
    f:write(encode_val(data))
    f:close()
    last_save_time = os.clock()
end

local function make_default_page()
    local pg = { id=next_id, type="libre", title="Notes libres", content="",
                 created=now_str(), modified=now_str() }
    next_id = next_id + 1
    return pg
end

local function load_notebook()
    local f = io.open(SAVE_PATH, "r")
    if not f then
        data = { pages={ make_default_page() }, active_page=1, keywords={} }
        save_notebook()
        return
    end
    local raw = f:read("*a")
    f:close()
    local decoded = json_decode(raw)
    if type(decoded) == 'table' then
        data = decoded
        if type(data.pages)    ~= 'table' then data.pages    = {} end
        if type(data.keywords) ~= 'table' then data.keywords = {} end
        if type(data.active_page) ~= 'number' or data.active_page < 1 then
            data.active_page = 1
        end
        next_id = 1
        for _, p in ipairs(data.pages) do
            if type(p.id) == 'number' and p.id >= next_id then
                next_id = p.id + 1
            end
        end
        if #data.pages == 0 then
            data.pages = { make_default_page() }
            data.active_page = 1
        end
        if data.active_page > #data.pages then
            data.active_page = #data.pages
        end
    else
        data = { pages={ make_default_page() }, active_page=1, keywords={} }
        save_notebook()
    end
end

-- ============================================================================
--  HELPERS
-- ============================================================================

local function get_active_page()
    local idx = data.active_page
    if idx >= 1 and idx <= #data.pages then return data.pages[idx] end
    return nil
end

local function sync_bufs_from_page()
    local pg = get_active_page()
    if not pg then ffi.fill(BUF_TITLE, 129, 0); ffi.fill(BUF_CONTENT, 8193, 0); return end
    imgui.StrCopy(BUF_TITLE,   pg.title   or "")
    imgui.StrCopy(BUF_CONTENT, pg.content or "")
    local tidx = 3
    for i, k in ipairs(TYPE_KEYS) do
        if k == pg.type then tidx = i - 1; break end
    end
    page_type_idx[0] = tidx
    cur_page_id = pg.id
end

local function flush_bufs_to_page()
    local pg = get_active_page()
    if not pg then return end
    local nt = ffi.string(BUF_TITLE)
    local nc = ffi.string(BUF_CONTENT)
    if pg.title ~= nt or pg.content ~= nc then
        pg.title    = nt
        pg.content  = nc
        pg.modified = now_str()
        dirty = true
    end
end

local function trunc(s, n)
    if not s or #s == 0 then return "(sans titre)" end
    if #s <= n then return s end
    return s:sub(1, n-2) .. ".."
end

local function type_index_of(type_key)
    for i, k in ipairs(TYPE_KEYS) do
        if k == type_key then return i end
    end
    return 4
end

-- ============================================================================
--  COLORISATION
-- ============================================================================

local COL_NORMAL = {0.9, 0.9, 0.9, 1.0}
local COL_NAME   = {1.0, 0.3, 0.3, 1.0}
local COL_PLATE  = {1.0, 0.9, 0.2, 1.0}

local function word_color(word, prev_word)
    local lw = word:lower()
    for _, kw in ipairs(data.keywords) do
        if lw == (kw.word or ""):lower() then
            for i, ck in ipairs(KW_KEYS) do
                if ck == kw.color then return KW_CVEC[i] end
            end
            return KW_CVEC[1]
        end
    end
    if opt_plates and word:match('^%u%u%-?%d%d%d%d%d?$') then
        return COL_PLATE
    end
    if opt_names and #word >= 2 then
        local f = word:sub(1,1)
        if f:match('%u') and not f:match('%d') then
            local is_first     = (prev_word == nil)
            local after_period = (prev_word ~= nil and prev_word:sub(-1) == '.')
            if not is_first and not after_period then
                return COL_NAME
            end
        end
    end
    return COL_NORMAL
end

local function colorize_text(text)
    local tokens = {}
    local first_line = true
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        if not first_line then
            tokens[#tokens+1] = { text='\n', col=COL_NORMAL, nl=true }
        end
        first_line = false
        local pos, prev = 1, nil
        while pos <= #line do
            local sp = line:match('^%s+', pos)
            if sp then
                tokens[#tokens+1] = { text=sp, col=COL_NORMAL }
                pos = pos + #sp
            end
            local w = line:match('^[%w%-]+', pos)
            if w then
                tokens[#tokens+1] = { text=w, col=word_color(w, prev) }
                prev = w
                pos  = pos + #w
            elseif pos <= #line then
                local c = line:sub(pos, pos)
                tokens[#tokens+1] = { text=c, col=COL_NORMAL }
                if c == '.' then prev = c end
                pos = pos + 1
            end
        end
    end
    return tokens
end

-- ============================================================================
--  ONGLET RACCOURCIS
-- ============================================================================

local function draw_raccourcis_tab()
    if listening_cmd then
        imgui.Dummy(imgui.ImVec2(0, 4))
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.0, 1.0), "Appuyez sur")
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.0, 1.0), "une touche...")
        imgui.Dummy(imgui.ImVec2(0, 2))
        imgui.TextDisabled("Echap = annuler")
        imgui.Separator()
        imgui.TextDisabled("F1-F9, F11-F12")
        imgui.TextDisabled("Num0 - Num9")

        if isKeyJustPressed(0x1B) then
            listening_cmd = nil
        else
            for _, vk in ipairs(BINDABLE_VKS) do
                if isKeyJustPressed(vk) then
                    nb_keybinds[listening_cmd] = vk
                    listening_cmd = nil
                    save_keybinds_nb()
                    break
                end
            end
        end
        return
    end

    imgui.TextDisabled("-- Raccourcis --")
    imgui.Separator()
    imgui.TextDisabled("Touche directe sans")
    imgui.TextDisabled("ouvrir le menu X.")
    imgui.Dummy(imgui.ImVec2(0, 4))

    for _, entry in ipairs(QMENU_ITEMS_CFG) do
        local vk = nb_keybinds[entry.cmd] or 0
        local kn = vkname(vk)
        imgui.Text(entry.label)
        imgui.SameLine(75)
        if imgui.SmallButton(kn .. "##kb_" .. entry.cmd) then
            listening_cmd = entry.cmd
        end
        if vk > 0 then
            imgui.SameLine()
            if imgui.SmallButton("[X]##rm" .. entry.cmd) then
                nb_keybinds[entry.cmd] = 0
                save_keybinds_nb()
            end
        end
    end
end

-- ============================================================================
--  COLONNE GAUCHE
-- ============================================================================

local function draw_left_col()
    if imgui.Button("[+ Nouvelle page]", imgui.ImVec2(-1, 0)) then
        ffi.fill(BUF_NTITLE, ffi.sizeof(BUF_NTITLE), 0)
        new_page_type_idx[0] = 3
        open_new_flag = true
    end
    imgui.Separator()

    local list_h = imgui.GetContentRegionAvail().y - 30
    imgui.BeginChild("##nb_pagelist", imgui.ImVec2(-1, list_h), false)
    for i, pg in ipairs(data.pages) do
        local tidx = type_index_of(pg.type)
        imgui.TextColored(TYPE_COLS[tidx], TYPE_PFX[tidx])
        imgui.SameLine()
        local label   = trunc(pg.title, 18) .. "##pg" .. tostring(pg.id)
        local sel_flags = 0
        if imgui.Selectable(label, i == data.active_page, sel_flags, imgui.ImVec2(0,0)) then
            if i ~= data.active_page then
                flush_bufs_to_page()
                data.active_page = i
                sync_bufs_from_page()
            end
        end
    end
    imgui.EndChild()

    imgui.Separator()
    if imgui.Button("[Supprimer]", imgui.ImVec2(-1, 0)) then
        if #data.pages > 0 then open_del_flag = true end
    end
end

-- ============================================================================
--  COLONNE CENTRALE
-- ============================================================================

local function draw_mid_col()
    local pg = get_active_page()
    if not pg then imgui.TextDisabled("Aucune page."); return end

    local avail_w = imgui.GetContentRegionAvail().x
    local combo_w = 105
    local sp      = imgui.GetStyle().ItemSpacing.x
    local title_w = avail_w - combo_w - sp

    imgui.SetNextItemWidth(title_w)
    if imgui.InputText("##nb_title", BUF_TITLE, 129) then
        pg.title    = ffi.string(BUF_TITLE)
        pg.modified = now_str()
        dirty = true
    end

    imgui.SameLine()

    imgui.SetNextItemWidth(combo_w)
    local cur_type_name = TYPE_NAMES[page_type_idx[0]+1] or "Libre"
    if imgui.BeginCombo("##nb_type", cur_type_name) then
        for i, name in ipairs(TYPE_NAMES) do
            if imgui.Selectable(name, page_type_idx[0] == i-1) then
                page_type_idx[0] = i - 1
                pg.type     = TYPE_KEYS[i]
                pg.modified = now_str()
                dirty = true
            end
        end
        imgui.EndCombo()
    end

    imgui.Separator()

    -- Zone edition texte
    local avail_h  = imgui.GetContentRegionAvail().y
    local preview_h = 130
    local edit_h    = avail_h - preview_h - 40
    if edit_h < 60 then edit_h = 60 end

    local it_flags = imgui.InputTextFlags.AllowTabInput
    if imgui.InputTextMultiline("##nb_content", BUF_CONTENT, 8193,
                                 imgui.ImVec2(-1, edit_h), it_flags) then
        pg.content  = ffi.string(BUF_CONTENT)
        pg.modified = now_str()
        dirty = true
    end

    -- Apercu colore
    imgui.TextDisabled("Apercu")
    imgui.PushStyleColorU32(imgui.Col.ChildBg, imgui.U32(0.07, 0.07, 0.13, 1.0))
    imgui.BeginChild("##nb_preview", imgui.ImVec2(-1, -1), true)

    local tokens = colorize_text(ffi.string(BUF_CONTENT))
    local line_start = true
    for _, tok in ipairs(tokens) do
        if tok.nl then
            line_start = true
        else
            if not line_start then imgui.SameLine(0, 0) end
            line_start = false
            local c = tok.col
            imgui.TextColored(imgui.ImVec4(c[1], c[2], c[3], c[4]), tok.text)
        end
    end

    imgui.EndChild()
    imgui.PopStyleColor(1)
end

-- ============================================================================
--  COLONNE DROITE
-- ============================================================================

local function draw_right_col()
    -- Onglets manuels (BeginTabBar non disponible dans cette version de mimgui)
    local is_col = (nb_right_tab[0] == 0)
    local is_rc  = (nb_right_tab[0] == 1)
    if is_col then imgui.PushStyleColorU32(imgui.Col.Button, imgui.U32(0.25, 0.25, 0.55, 1.0)) end
    if imgui.SmallButton("Couleurs##rtab0")   then nb_right_tab[0] = 0 end
    if is_col then imgui.PopStyleColor(1) end
    imgui.SameLine()
    if is_rc  then imgui.PushStyleColorU32(imgui.Col.Button, imgui.U32(0.25, 0.25, 0.55, 1.0)) end
    if imgui.SmallButton("Raccourcis##rtab1") then nb_right_tab[0] = 1 end
    if is_rc  then imgui.PopStyleColor(1) end
    imgui.Separator()

    if nb_right_tab[0] == 1 then
        draw_raccourcis_tab()
        return
    end

    -- ---- Onglet 0 : Couleurs ----

    imgui.TextDisabled("-- Colorisation --")
    imgui.Separator()

    b_names_ref[0] = opt_names
    if imgui.Checkbox("Noms (rouge)", b_names_ref) then
        opt_names = b_names_ref[0]
    end

    b_plates_ref[0] = opt_plates
    if imgui.Checkbox("Plaques (jaune)", b_plates_ref) then
        opt_plates = b_plates_ref[0]
    end

    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextDisabled("-- Mots-cles --")
    imgui.Separator()

    imgui.SetNextItemWidth(-1)
    imgui.InputText("##nb_kw", BUF_KWORD, 65)

    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo("##nb_kwcol", KW_NAMES[kw_color_idx[0]+1] or "Cyan") then
        for i, cn in ipairs(KW_NAMES) do
            if imgui.Selectable(cn, kw_color_idx[0] == i-1) then
                kw_color_idx[0] = i - 1
            end
        end
        imgui.EndCombo()
    end

    if imgui.Button("[+ Ajouter]", imgui.ImVec2(-1, 0)) then
        local word = ffi.string(BUF_KWORD):match('^%s*(.-)%s*$')
        if #word > 0 and #data.keywords < 20 then
            local dup = false
            for _, kw in ipairs(data.keywords) do
                if kw.word:lower() == word:lower() then dup = true; break end
            end
            if not dup then
                data.keywords[#data.keywords+1] = {
                    word  = word,
                    color = KW_KEYS[kw_color_idx[0]+1] or "cyan"
                }
                ffi.fill(BUF_KWORD, ffi.sizeof(BUF_KWORD), 0)
                dirty = true
            end
        end
    end

    imgui.Separator()

    local del_kw = nil
    for i, kw in ipairs(data.keywords) do
        local ci = 1
        for j, ck in ipairs(KW_KEYS) do if ck == kw.color then ci = j; break end end
        local c = KW_CVEC[ci]
        imgui.TextColored(imgui.ImVec4(c[1],c[2],c[3],c[4]), kw.word or "")
        imgui.SameLine()
        if imgui.SmallButton("[X]##kw"..tostring(i)) then del_kw = i end
    end
    if del_kw then table.remove(data.keywords, del_kw); dirty = true end

    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextDisabled("-- Infos page --")
    imgui.Separator()

    local pg = get_active_page()
    if pg then
        imgui.TextDisabled("Cree  : " .. (pg.created  or "-"))
        imgui.TextDisabled("Modif : " .. (pg.modified or "-"))
        imgui.TextDisabled("Chars : " .. #(pg.content or ""))
    end
end

-- ============================================================================
--  POPUP NOUVELLE PAGE
-- ============================================================================

local function draw_popup_new()
    if open_new_flag then
        imgui.OpenPopup("Nouvelle page##nbpop")
        open_new_flag = false
    end
    imgui.SetNextWindowSize(imgui.ImVec2(300, 0), imgui.Cond.Always)
    if imgui.BeginPopupModal("Nouvelle page##nbpop", nil,
                              imgui.WindowFlags.AlwaysAutoResize) then
        imgui.Text("Titre :")
        imgui.SetNextItemWidth(-1)
        imgui.InputText("##np_t", BUF_NTITLE, 129)

        imgui.Text("Type :")
        imgui.SetNextItemWidth(-1)
        if imgui.BeginCombo("##np_type", TYPE_NAMES[new_page_type_idx[0]+1] or "Libre") then
            for i, name in ipairs(TYPE_NAMES) do
                if imgui.Selectable(name, new_page_type_idx[0] == i-1) then
                    new_page_type_idx[0] = i - 1
                end
            end
            imgui.EndCombo()
        end

        imgui.Separator()
        if imgui.Button("Creer", imgui.ImVec2(120, 0)) then
            local title = ffi.string(BUF_NTITLE):match('^%s*(.-)%s*$')
            if #title == 0 then title = "Nouvelle page" end
            flush_bufs_to_page()
            local new_pg = {
                id       = next_id,
                type     = TYPE_KEYS[new_page_type_idx[0]+1] or "libre",
                title    = title,
                content  = "",
                created  = now_str(),
                modified = now_str()
            }
            next_id = next_id + 1
            data.pages[#data.pages+1] = new_pg
            data.active_page = #data.pages
            sync_bufs_from_page()
            dirty = true
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button("Annuler", imgui.ImVec2(120, 0)) then
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
end

-- ============================================================================
--  POPUP SUPPRIMER PAGE
-- ============================================================================

local function draw_popup_del()
    if open_del_flag then
        imgui.OpenPopup("Supprimer##nbdel")
        open_del_flag = false
    end
    if imgui.BeginPopupModal("Supprimer##nbdel", nil,
                              imgui.WindowFlags.AlwaysAutoResize) then
        local pg    = get_active_page()
        local title = pg and (pg.title or "cette page") or "cette page"
        imgui.Text('Supprimer "' .. title .. '" ?')
        imgui.Separator()
        if imgui.Button("Oui", imgui.ImVec2(100, 0)) then
            local idx = data.active_page
            table.remove(data.pages, idx)
            if #data.pages == 0 then
                data.pages = { make_default_page() }
            end
            data.active_page = math.min(idx, #data.pages)
            sync_bufs_from_page()
            dirty = true
            imgui.CloseCurrentPopup()
        end
        imgui.SameLine()
        if imgui.Button("Non", imgui.ImVec2(100, 0)) then
            imgui.CloseCurrentPopup()
        end
        imgui.EndPopup()
    end
end

-- ============================================================================
--  RENDU PRINCIPAL
-- ============================================================================

imgui.OnFrame(
    function() return notebook_open end,
    function(self)
        self.HideCursor = false
        self.LockPlayer = false

        if nb_first_open then
            local sw, sh = getScreenResolution()
            if sw and sw > 0 then
                imgui.SetNextWindowPos(imgui.ImVec2((sw-820)*0.5, (sh-560)*0.5),
                                       imgui.Cond.Always)
                nb_first_open = false
            end
        end

        imgui.SetNextWindowSize(imgui.ImVec2(820, 560), imgui.Cond.Always)

        -- Compteur de PushStyleColor pour garantir le PopStyleColor meme en cas d'erreur
        local push_n   = 0
        local began    = false
        local function ps(col, clr) imgui.PushStyleColorU32(col, clr); push_n = push_n + 1 end

        local ok, err = xpcall(function()
            ps(imgui.Col.WindowBg,       imgui.U32(0.10, 0.10, 0.18, 1.0))
            ps(imgui.Col.TitleBgActive,  imgui.U32(0.18, 0.18, 0.38, 1.0))
            ps(imgui.Col.TitleBg,        imgui.U32(0.14, 0.14, 0.28, 1.0))
            ps(imgui.Col.Border,         imgui.U32(0.23, 0.23, 0.36, 1.0))
            ps(imgui.Col.FrameBg,        imgui.U32(0.12, 0.12, 0.22, 1.0))
            ps(imgui.Col.FrameBgHovered, imgui.U32(0.17, 0.17, 0.30, 1.0))
            ps(imgui.Col.Button,         imgui.U32(0.16, 0.26, 0.16, 1.0))
            ps(imgui.Col.ButtonHovered,  imgui.U32(0.22, 0.42, 0.22, 1.0))
            ps(imgui.Col.Header,         imgui.U32(0.20, 0.20, 0.40, 1.0))
            ps(imgui.Col.HeaderHovered,  imgui.U32(0.28, 0.28, 0.55, 1.0))

            p_open[0] = true
            local wflags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse
            local opened = imgui.Begin("[ PDAID - Carnet d'enquete ]##nb_win", p_open, wflags)
            began = true

            if not p_open[0] then
                flush_bufs_to_page()
                notebook_open = false
                nb_first_open = true
            end

            if opened then
                pcall(function()
                    local pg = get_active_page()
                    if pg and pg.id ~= cur_page_id then sync_bufs_from_page() end

                    local avail_w = imgui.GetContentRegionAvail().x
                    local avail_h = imgui.GetContentRegionAvail().y
                    local LEFT_W  = 185
                    local RIGHT_W = 190
                    local sp      = imgui.GetStyle().ItemSpacing.x
                    local MID_W   = avail_w - LEFT_W - RIGHT_W - sp * 2

                    ps(imgui.Col.ChildBg, imgui.U32(0.08, 0.08, 0.15, 0.6))

                    imgui.BeginChild("##nb_left",  imgui.ImVec2(LEFT_W, avail_h), true)
                    pcall(draw_left_col)
                    imgui.EndChild()
                    imgui.SameLine()
                    imgui.BeginChild("##nb_mid", imgui.ImVec2(MID_W, avail_h), true)
                    pcall(draw_mid_col)
                    imgui.EndChild()
                    imgui.SameLine()
                    imgui.BeginChild("##nb_right", imgui.ImVec2(RIGHT_W, avail_h), true)
                    pcall(draw_right_col)
                    imgui.EndChild()

                    imgui.PopStyleColor(1); push_n = push_n - 1

                    pcall(draw_popup_new)
                    pcall(draw_popup_del)
                end)
            end
        end, tostring)

        if began    then imgui.End() end
        if push_n > 0 then imgui.PopStyleColor(push_n) end

        if not ok then
            print("[PDAID_NOTES] ERREUR DRAW: " .. tostring(err))
            notebook_open = false
            nb_first_open = true
        end

        if notebook_open and isKeyJustPressed(0x1B) and not imgui.IsAnyItemActive() then
            flush_bufs_to_page()
            notebook_open = false
            nb_first_open = true
        end
    end
)

-- ============================================================================
--  MAIN + AUTOSAVE DEBOUNCE
-- ============================================================================

local function do_toggle()
    if not notebook_open then
        local pg = get_active_page()
        if pg then sync_bufs_from_page() end
        nb_first_open = true
    else
        flush_bufs_to_page()
    end
    notebook_open = not notebook_open
end

function main()
    load_notebook()
    load_keybinds_nb()
    if isSampAvailable then
        while not isSampAvailable() do wait(100) end
    end
    wait(300)
    sampAddChatMessage("{00AAFF}[LSPD AID]{FFFFFF} Carnet v1.0.1 charge", -1)

    while true do
        wait(0)

        -- Raccourci direct F10 (0x79) pour ouvrir/fermer le carnet
        if isKeyJustPressed(0x79) then
            do_toggle()
        end

        -- Autosave debounce 1.5s
        if dirty and (os.clock() - last_save_time) > 1.5 then
            flush_bufs_to_page()
            save_notebook()
            dirty = false
        end
    end
end

function onScriptTerminate()
    if dirty then
        flush_bufs_to_page()
        save_notebook()
    end
end
