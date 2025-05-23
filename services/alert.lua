local config = require('configs.config');
local chat = require('chat');

local alert = {
    last_alerted_completion = {}
};

-- Preload sounds
local function load_sounds()
    local folder = AshitaCore:GetInstallPath() .. '/addons/' .. addon.name .. '/sounds/'
    if not ashita.fs.exists(folder) then return {}, {} end

    local files = ashita.fs.get_directory(folder, '.*\\.wav') or {}
    local full = T{}

    for _, f in ipairs(files) do
        full:append(f)
    end

    return full
end

local sound_files = load_sounds()

-- Play alert sound
function alert:play_sound(sound)
    local fullpath = string.format('%s\\sounds\\%s', addon.path, sound);
    ashita.misc.play_sound(fullpath);
end

-- Check and handle alerts for a venture
function alert:check_venture(venture)
    if not config.get('enable_alerts') then
        return;
    end

    local completion = venture:get_completion();
    local area = venture:get_area();
    local location = venture:get_location();

    if completion > config.get('alert_threshold') then
        local last = self.last_alerted_completion[area] or 0;
        if completion > last then
            local location_note = location ~= '' and string.format(" at %s", location) or "";
            print(chat.header('ventures') .. chat.success(
                string.format("%s is now %d%% complete%s!", area, completion, location_note)
            ));

            if config.get('enable_audio') and completion >= config.get('audio_alert_threshold') then
                self:play_sound(sound_files[config.get('selected_sound')]);
            end

            self.last_alerted_completion[area] = completion;
        end
    end
end

return alert;