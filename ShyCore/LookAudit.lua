-- /shy looks: what every housing on screen wears, region by region, in the copy box (UI.LookAudit).
Shy.Command("looks", "what every housing on screen wears, to copy when a look draws wrong", function()
	local text = Shy.UI.LookAudit()
	Shy.UI.ShowCopyBox("Looks", text)
end)
