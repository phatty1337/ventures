local config = require('configs.config');

local sorter = {};

-- Sort ventures based on current settings
function sorter:sort(ventures)
    table.sort(ventures, function(a, b)
        local a_val, b_val;

        if config.sort_by == 'level' then
            a_val = tonumber(a:get_level_range():match("(%d+)-")) or 0;
            b_val = tonumber(b:get_level_range():match("(%d+)-")) or 0;
        elseif config.sort_by == 'area' then
            a_val = a:get_area():lower();
            b_val = b:get_area():lower();
        elseif config.sort_by == 'completion' then
            a_val = a:get_completion();
            b_val = b:get_completion();
        end

        if config.sort_ascending then
            return a_val < b_val;
        else
            return a_val > b_val;
        end
    end);

    return ventures;
end

-- Toggle sort direction
function sorter:toggle_direction()
    config.sort_ascending = not config.sort_ascending;
end

-- Set sort column
function sorter:set_column(column)
    if config.sort_by == column then
        self:toggle_direction();
    else
        config.sort_by = column;
        config.sort_ascending = true;
    end
end

-- Find highest completion
function sorter:get_highest_completion(ventures)
    local highest_completion = 0;
    local highest_area = '';
    local highest_position = '';
    for _, venture in ipairs(ventures) do
        local completion = venture:get_completion();
        if completion > highest_completion then
            highest_completion = completion;
            highest_area = venture:get_area();
            highest_position = venture:get_location();
        end
    end

    return {
        completion = highest_completion,
        area = highest_area,
        position = highest_position
    };
end

return sorter;