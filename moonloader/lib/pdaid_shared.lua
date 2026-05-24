-- Canal IPC inter-scripts PDAID
-- MoonLoader charge ce module une fois PAR script (package.loaded isole par setfenv).
-- On stocke la table dans le registre Lua global (debug.getregistry) qui est
-- le seul espace veritablement partage entre tous les scripts du meme VM.
local reg = debug.getregistry()
if not reg['PDAID_SHARED'] then
    reg['PDAID_SHARED'] = { notebook_request = false }
end
return reg['PDAID_SHARED']
