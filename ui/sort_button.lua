local imgui = require('imgui');
local config = require('configs.config');
local sorter = require('services.sorter');

local sort_button = {};

-- Draw sort button
function sort_button:draw_sort_button(label, sort_by)
    if config.sort_by == sort_by then
        imgui.PushStyleColor(ImGuiCol_Button, {0.2, 0.4, 0.8, 1.0});
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2, 0.4, 0.8, 1.0});
        imgui.PushStyleColor(ImGuiCol_ButtonActive, {0.2, 0.4, 0.8, 1.0});
    end

    local button_text = label;
    if config.sort_by == sort_by then
        button_text = button_text .. (config.sort_ascending and ' (Asc)' or ' (Desc)');
    end

    if imgui.Button(button_text) then
        sorter:set_column(sort_by);
    end

    if config.sort_by == sort_by then
        imgui.PopStyleColor(3);
    end
end

return sort_button;