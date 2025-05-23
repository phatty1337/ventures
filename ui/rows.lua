local imgui = require('imgui');
local config = require('configs.config');

local rows = {};

-- Draw venture row
function rows:draw_venture_row(venture)
    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    
    -- Level Range
    imgui.Text(venture:get_level_range());
    imgui.NextColumn();

    -- Area
    imgui.Text(venture:get_area());
    imgui.NextColumn();

    -- Completion
    local completion = venture:get_completion();
    if completion >= config.alert_threshold then
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.5, 0.0, 1.0 }); -- Orange
    else
        imgui.PushStyleColor(ImGuiCol_Text, { 0.5, 1.0, 0.5, 1.0 }); -- Green
    end
    imgui.TextUnformatted(completion .. '%');
    imgui.PopStyleColor();
    imgui.NextColumn();

    -- Location
    imgui.Text(venture:get_location());
    imgui.NextColumn();
end

-- Draw all venture rows
function rows:draw(ventures)
    for _, venture in ipairs(ventures) do
        self:draw_venture_row(venture);
    end
end

return rows;