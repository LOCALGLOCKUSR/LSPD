-- Canal de communication inter-scripts SAK
-- require('sak_shared') retourne la meme table dans tous les scripts
return {
    notebook_request = false,   -- SAK_QuickMenu le passe a true, SAK_Notebook le consomme
}
