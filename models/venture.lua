local Venture = {
    level_range = '',
    area = '',
    completion = 0,
    location = ''
};

-- Create new venture instance
function Venture:new(data)
    local instance = setmetatable({}, { __index = Venture });
    instance:update(data);
    return instance;
end

-- Update venture data
function Venture:update(data)
    self.level_range = data.level_range;
    self.area = data.area;
    self.completion = tonumber(data.completion) or 0;
    self.location = data.loc;
end

-- Get completion percentage
function Venture:get_completion()
    return self.completion;
end

-- Get area name
function Venture:get_area()
    return self.area;
end

-- Get level range
function Venture:get_level_range()
    return self.level_range;
end

-- Get location
function Venture:get_location()
    return self.location;
end

return Venture;