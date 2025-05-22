local config = {
    show_gui = true,
    enable_alerts = true,
    enable_audio = true,
    alert_threshold = 90,
    audio_alert_threshold = 100,
    auto_refresh_interval = 60, -- seconds
    sort_by = 'completion', -- 'level', 'area', 'completion'
    sort_ascending = false
}

-- Helper function to get a setting
function config.get(key)
    return config[key];
end

-- Helper function to set a setting
function config.set(key, value)
    config[key] = value;
end

-- Helper function to toggle a boolean setting
function config.toggle(key)
    if type(config[key]) == 'boolean' then
        config[key] = not config[key];
        return config[key];
    end
    return nil;
end

return config
