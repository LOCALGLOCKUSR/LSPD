-- Canal IPC inter-scripts PDAID
-- math est une table C du VM Lua, identique dans tous les scripts (meme apres setfenv).
-- On y accroche une table une seule fois ; tous les require() suivants retournent le meme objet.
if not math.PDAID_SHARED then
    math.PDAID_SHARED = { notebook_request = false }
end
return math.PDAID_SHARED
