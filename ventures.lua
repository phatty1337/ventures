addon.name    = 'ventures';
addon.author  = 'Commandobill';
addon.version = '1.0';
addon.desc    = 'Capture and parse EXP Areas cleanly from !ventures response';

require('common');
local chat = require('chat');
local imgui = require('imgui');

-- Runtime state
local capture_active = false;
local capture_lines = {};
local capture_start_time = 0;
local capture_timeout = 5; -- Seconds
local max_lines = 50;
local header_detected = false;

local parsed_exp_areas = {}; -- GUI display
local last_alerted_completion = {}; -- Tracks last alert per area

-- Settings
local settings = {
    show_gui = true,
    enable_alerts = true,
    alert_threshold = 90,
    auto_refresh_interval = 60 -- seconds
};

local auto_refresh_timer = os.clock(); -- Initialize timer

-- Helper: Parse and store EXP Areas
local function parse_exp_areas(lines)
    parsed_exp_areas = {}; -- Clear old results
    local exp_text = '';
    local found_exp_start = false;

    for _, entry in ipairs(lines) do
        if not found_exp_start then
            if string.find(entry.message, '^EXP Areas:') then
                exp_text = exp_text .. entry.message;
                found_exp_start = true;
            end
        elseif found_exp_start then
            exp_text = exp_text .. ' ' .. entry.message;
            break;
        end
    end

    if exp_text == '' then
        print(chat.header(addon.name) .. chat.error('EXP Areas section not found.'));
        return;
    end

    exp_text = exp_text:gsub("^EXP Areas:%s*", "");

    for part in exp_text:gmatch("[^,]+") do
        local level_range = part:match("%((%d+%-%d+)%)");
        local completion = part:match("@(%d+)%%");
        local area = part:gsub("%(.-%)", ""):gsub("@%d+%%", ""):gsub("^%s*(.-)%s*$", "%1");

        if level_range and area then
            local completion_str = completion or '0';
            local completion_num = tonumber(completion_str) or 0;

            table.insert(parsed_exp_areas, {
                level_range = level_range,
                area = area,
                completion = completion_str
            });

            -- Check and alert if needed
            if settings.enable_alerts and completion_num > settings.alert_threshold then
                local last = last_alerted_completion[area] or 0;
                if completion_num > last then
                    print(chat.header(addon.name) .. chat.success(
                        string.format("%s is now %d%% complete!", area, completion_num)
                    ));
                    last_alerted_completion[area] = completion_num;
                end
            end
        end
    end
end

-- Draw the GUI window
local function draw_gui()
    if not settings.show_gui then
        return;
    end

    imgui.SetNextWindowSize({ 600, 350 }, ImGuiCond_FirstUseEver);
    if imgui.Begin('Goblin Ventures') then
        -- Set window styles
        imgui.PushStyleColor(ImGuiCol_WindowBg, {0,0.06,0.16,0.9});
        imgui.PushStyleColor(ImGuiCol_TitleBg, {0,0.06,0.16,0.7});
        imgui.PushStyleColor(ImGuiCol_TitleBgActive, {0,0.06,0.16,0.9});
        imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, {0,0.06,0.16,0.5});

        imgui.Columns(3);
        imgui.SetColumnWidth(0, 120);   -- Level Range
        imgui.SetColumnWidth(1, 220);   -- Area

        imgui.Text('Level Range'); imgui.NextColumn();
        imgui.Text('Area'); imgui.NextColumn();
        imgui.Text('Completion'); imgui.NextColumn();
        imgui.Separator();

        for _, entry in ipairs(parsed_exp_areas) do
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
            -- Level Range (white)
            imgui.Text(entry.level_range); 
            imgui.NextColumn();

            -- Area (white)
            imgui.Text(entry.area);
            imgui.NextColumn();

            -- Completion (colored)
            local completion_num = tonumber(entry.completion) or 0;
            if completion_num >= settings.alert_threshold then
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.5, 0.0, 1.0 }); -- Orange
            else
                imgui.PushStyleColor(ImGuiCol_Text, { 0.5, 1.0, 0.5, 1.0 }); -- Green
            end

            imgui.TextUnformatted(entry.completion .. '%');
            imgui.PopStyleColor(); -- Pop completion %
            imgui.NextColumn();
        end

        imgui.Columns(1);
        imgui.PopStyleColor(4); -- Pop window styles
    end
    imgui.End();
end

-- Send !ventures (with zoning check)
local function send_ventures_command()
    local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    if zone_id == 0 then
        print(chat.header(addon.name) .. chat.error('Zoning detected. Skipping !ventures for now.'));
        return;
    end

    AshitaCore:GetChatManager():QueueCommand(1, '/say !ventures');
    capture_active = true;
    capture_lines = {};
    capture_start_time = os.clock();
    header_detected = false;
end

-- /ventures and /ventures settings
ashita.events.register('command', 'ventures_command_cb', function(e)
    local args = e.command:args();
    if #args == 0 then
        return;
    end

    local cmd = args[1]:lower();

    if cmd == '/ventures' then
        if args[2] == nil then
            send_ventures_command();
            return true;
        elseif args[2]:lower() == 'settings' then
            if args[3] == nil then
                print(chat.header(addon.name) .. chat.message('Current Settings:'));
                print(chat.header(addon.name) .. ('- GUI: ' .. (settings.show_gui and 'ON' or 'OFF')));
                print(chat.header(addon.name) .. ('- Alerts: ' .. (settings.enable_alerts and 'ON' or 'OFF')));
            else
                local setting = args[3]:lower();
                if setting == 'gui' then
                    settings.show_gui = not settings.show_gui;
                    print(chat.header(addon.name) .. chat.message('GUI toggled ' .. (settings.show_gui and 'ON' or 'OFF')));
                elseif setting == 'alerts' then
                    settings.enable_alerts = not settings.enable_alerts;
                    print(chat.header(addon.name) .. chat.message('Alerts toggled ' .. (settings.enable_alerts and 'ON' or 'OFF')));
                else
                    print(chat.header(addon.name) .. chat.error('Unknown settings option: ' .. setting));
                end
            end
            return true;
        end
    end
    return false;
end);

-- Capture server replies
ashita.events.register('text_in', 'ventures_textin_cb', function(e)
    if not capture_active then
        return;
    end

    if e.injected then
        return;
    end

    if not e.message or e.message == '' then
        return;
    end

    local mode = e.mode % 256;

    if (mode == 1) and string.find(e.message, "!ventures") then
        e.blocked = true;
        return;
    end

    if not header_detected then
        if (mode == 121) and string.find(e.message, "=== Today's Goblin Ventures ===") then
            header_detected = true;
            e.blocked = true;
        end
        return;
    end

    if mode == 9 then
        e.blocked = true;

        if string.find(e.message, "^Mining:") then
            capture_active = false;
            parse_exp_areas(capture_lines);
            return;
        end

        local entry = { mode = mode, message = e.message };
        table.insert(capture_lines, entry);
    end

    if #capture_lines >= max_lines then
        capture_active = false;
        parse_exp_areas(capture_lines);
    end
end);

-- GUI + auto-refresh manager
ashita.events.register('d3d_present', 'ventures_present_cb', function()
    draw_gui();

    if (os.clock() - auto_refresh_timer) >= settings.auto_refresh_interval then
        auto_refresh_timer = os.clock();
        send_ventures_command();
    end

    if capture_active and (os.clock() - capture_start_time) > capture_timeout then
        capture_active = false;
        parse_exp_areas(capture_lines);
    end
end);

-- Startup message
print(chat.header(addon.name) .. chat.success('Loaded. Type /ventures settings to configure.'));

-- Auto-populate data on load
send_ventures_command();
