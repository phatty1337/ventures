local config = require('configs.config');
local chat = require('chat');

local alert = {
    last_alerted_completion = {}
};

-- Play alert sound
function alert:play_sound(sound)
    local fullpath = string.format('%s\\sounds\\%s', addon.path, sound);
    ashita.misc.play_sound(fullpath);
end

-- Check and handle alerts for a venture
function alert:check_venture(venture)
    if not config.enable_alerts then
        return;
    end

    local completion = venture:get_completion();
    local area = venture:get_area();
    local location = venture:get_location();

    if completion > config.alert_threshold then
        local last = self.last_alerted_completion[area] or 0;
        if completion > last then
            local location_note = location ~= '' and string.format(" at %s", location) or "";
            print(chat.header('ventures') .. chat.success(
                string.format("%s is now %d%% complete%s!", area, completion, location_note)
            ));

            if config.enable_audio and completion >= config.audio_alert_threshold then
                self:play_sound('alert.wav');
            end

            self.last_alerted_completion[area] = completion;
        end
    end
end

return alert;