-- /shy looks: what every housing on screen wears, region by region, in the copy box (UI.LookAudit).
-- (For finding faults: what every housing on screen wears. Not listed.)
Shy.Command("looks", nil, function()
	local text = Shy.UI.LookAudit()
	Shy.UI.ShowCopyBox("Looks", text)
end)
