addon.name    = 'ventures';
addon.author  = 'Commandobill';
addon.version = '1.2.6';
addon.desc    = 'Capture and parse EXP Areas cleanly from !ventures response';

require('common');
local chat = require('chat');
local imgui = require('imgui');
local vnm_data = require('vnms');
local settings = require('config');

-- Runtime state
local capture_active = false;
local capture_lines = {};
local capture_start_time = 0;
local capture_timeout = 5; -- Seconds
local max_lines = 50;
local header_detected = false;

local parsed_exp_areas = {}; -- GUI display
local last_alerted_completion = {}; -- Tracks last alert per area

local zoning = false;
local zone_loaded = false;
local zone_entry_time = 0;

local auto_refresh_timer = os.clock(); -- Initialize timer

local function play_alert_sound(sound)
    local fullpath = string.format('%s\\sounds\\%s', addon.path, sound);
    ashita.misc.play_sound(fullpath);
end

local function sort_exp_areas()
    table.sort(parsed_exp_areas, function(a, b)
        local a_val, b_val;

        if settings.sort_by == 'level' then
            a_val = tonumber(a.level_range:match("(%d+)-")) or 0;
            b_val = tonumber(b.level_range:match("(%d+)-")) or 0;
        elseif settings.sort_by == 'area' then
            a_val = a.area:lower();
            b_val = b.area:lower();
        elseif settings.sort_by == 'completion' then
            a_val = tonumber(a.completion) or 0;
            b_val = tonumber(b.completion) or 0;
        end

        if settings.sort_ascending then
            return a_val < b_val;
        else
            return a_val > b_val;
        end
    end);
end

-- Helper: Parse and store EXP Areas
local function parse_exp_areas(lines)
    
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
    parsed_exp_areas = {}; -- Clear old results

    exp_text = exp_text:gsub("^EXP Areas:%s*", "");

    for part in exp_text:gmatch("[^,]+") do
        local level_range = part:match("%((%d+%-%d+)%)");
        local completion = part:match("@(%d+)%%");
        local area = part:gsub("%(.-%)", ""):gsub("@%d+%%", ""):gsub("^%s*(.-)%s*$", "%1");
        local vnm_position = nil;
        local vnm_zone = vnm_data[area];

        if vnm_zone then
            for _, vnm in ipairs(vnm_zone) do
                if vnm.level_range == level_range then
                    vnm_position = vnm.position;
                    break;
                end
            end
        end

        if level_range and area then
            local completion_str = completion or '0';
            local completion_num = tonumber(completion_str) or 0;

            table.insert(parsed_exp_areas, {
                level_range = level_range,
                area = area,
                completion = completion_str,
                loc = vnm_position and string.format("(%s)", vnm_position) or ""
            });
            -- Check and alert if needed
            if settings.enable_alerts and completion_num > settings.alert_threshold then
                local last = last_alerted_completion[area] or 0;
                if completion_num > last then
                    local location_note = vnm_position and string.format(" at (%s)", vnm_position) or "";
                    print(chat.header(addon.name) .. chat.success(
                        string.format("%s is now %d%% complete%s!", area, completion_num, location_note)
                    ));
                    -- Play audio alert if enabled
                    if settings.enable_audio and completion_num >= settings.audio_alert_threshold then
                        play_alert_sound('alert.wav');
                    end
                    last_alerted_completion[area] = completion_num;
                end
            end
        end
    end

    -- Sort the entries according to current settings
    sort_exp_areas();
end

-- Draw the GUI window
local function draw_gui()
    if not settings.show_gui then
        return;
    end

    imgui.SetNextWindowSize({ 700, 350 }, ImGuiCond_FirstUseEver);
    if imgui.Begin('Goblin Ventures') then
        -- Set window styles
        imgui.PushStyleColor(ImGuiCol_WindowBg, {0,0.06,0.16,0.9});
        imgui.PushStyleColor(ImGuiCol_TitleBg, {0,0.06,0.16,0.7});
        imgui.PushStyleColor(ImGuiCol_TitleBgActive, {0,0.06,0.16,0.9});
        imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, {0,0.06,0.16,0.5});


        imgui.Columns(4)
        imgui.Text('Level Range'); imgui.NextColumn()
        imgui.Text('Area'); imgui.NextColumn()
        imgui.Text('Completion'); imgui.NextColumn()
        imgui.Text('Loc'); imgui.NextColumn()
        imgui.Separator()

        imgui.Columns(4);

        -- Level Range button
        if settings.sort_by == 'level' then
            imgui.PushStyleColor(ImGuiCol_Button, {0.2, 0.4, 0.8, 1.0});  -- Blue highlight for active sort
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2, 0.4, 0.8, 1.0});  -- Same blue for hover
            imgui.PushStyleColor(ImGuiCol_ButtonActive, {0.2, 0.4, 0.8, 1.0});  -- Same blue for clicked
        end
        if imgui.Button('Level Range' .. (settings.sort_by == 'level' and (settings.sort_ascending and ' (Asc)' or ' (Desc)') or '')) then
            if settings.sort_by == 'level' then
                settings.sort_ascending = not settings.sort_ascending;
            else
                settings.sort_by = 'level';
                settings.sort_ascending = true;
            end
            sort_exp_areas();
        end
        if settings.sort_by == 'level' then
            imgui.PopStyleColor(3);  -- Pop all three colors
        end
        imgui.NextColumn();

        -- Area button
        if settings.sort_by == 'area' then
            imgui.PushStyleColor(ImGuiCol_Button, {0.2, 0.4, 0.8, 1.0});  -- Blue highlight for active sort
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2, 0.4, 0.8, 1.0});  -- Same blue for hover
            imgui.PushStyleColor(ImGuiCol_ButtonActive, {0.2, 0.4, 0.8, 1.0});  -- Same blue for clicked
        end
        if imgui.Button('Area' .. (settings.sort_by == 'area' and (settings.sort_ascending and ' (Asc)' or ' (Desc)') or '')) then
            if settings.sort_by == 'area' then
                settings.sort_ascending = not settings.sort_ascending;
            else
                settings.sort_by = 'area';
                settings.sort_ascending = true;
            end
            sort_exp_areas();
        end
        if settings.sort_by == 'area' then
            imgui.PopStyleColor(3);  -- Pop all three colors
        end
        imgui.NextColumn();

        -- Completion button
        if settings.sort_by == 'completion' then
            imgui.PushStyleColor(ImGuiCol_Button, {0.2, 0.4, 0.8, 1.0});  -- Blue highlight for active sort
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, {0.2, 0.4, 0.8, 1.0});  -- Same blue for hover
            imgui.PushStyleColor(ImGuiCol_ButtonActive, {0.2, 0.4, 0.8, 1.0});  -- Same blue for clicked
        end
        if imgui.Button('Completion' .. (settings.sort_by == 'completion' and (settings.sort_ascending and ' (Asc)' or ' (Desc)') or '')) then
            if settings.sort_by == 'completion' then
                settings.sort_ascending = not settings.sort_ascending;
            else
                settings.sort_by = 'completion';
                settings.sort_ascending = true;
            end
            sort_exp_areas();
        end
        if settings.sort_by == 'completion' then
            imgui.PopStyleColor(3);  -- Pop all three colors
        end
        imgui.NextColumn();

        -- Location header with hyperlink style
        imgui.Text('Location ');  -- Regular text
        imgui.SameLine(0, 0);  -- Keep on same line with no spacing
        imgui.PushStyleColor(ImGuiCol_Text, {0.0, 0.7, 1.0, 1.0});  -- Light blue color for link
        if imgui.Selectable('(wiki)', false, ImGuiSelectableFlags_None, {0, 0}) then
            -- Open URL in default browser
            os.execute('start https://www.bg-wiki.com/ffxi/CatsEyeXI_Content/Ventures#Venture_Bosses');
        end
        imgui.PopStyleColor();
        imgui.NextColumn();
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

            imgui.Text(entry.loc);
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
                print(chat.header(addon.name) .. ('- Audio: ' .. (settings.enable_audio and 'ON' or 'OFF')));
                print(chat.header(addon.name) .. ('- Sort: ' .. settings.sort_by .. ' ' .. (settings.sort_ascending and 'Ascending' or 'Descending')));
            else
                local setting = args[3]:lower();
                if setting == 'gui' then
                    settings.show_gui = not settings.show_gui;
                    print(chat.header(addon.name) .. chat.message('GUI toggled ' .. (settings.show_gui and 'ON' or 'OFF')));
                elseif setting == 'alerts' then
                    settings.enable_alerts = not settings.enable_alerts;
                    print(chat.header(addon.name) .. chat.message('Alerts toggled ' .. (settings.enable_alerts and 'ON' or 'OFF')));
                elseif setting == 'audio' then
                    settings.enable_audio = not settings.enable_audio;
                    print(chat.header(addon.name) .. chat.message('Audio alerts toggled ' .. (settings.enable_audio and 'ON' or 'OFF')));
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

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    local id = e.id;

    -- Zone enter packet
    if id == 0x0A then
        zoning = true;
        zone_loaded = false;
        zone_entry_time = os.clock();
        return;
    end

    -- Wait for first 0x001F packet after zoning starts
    if zoning and not zone_loaded and id == 0x001F then
        zone_loaded = true;
        zoning = false;
        auto_refresh_timer = os.clock() - settings.auto_refresh_interval + 10;
        --send_ventures_command();
        return;
    end
end);

-- GUI + auto-refresh manager
ashita.events.register('d3d_present', 'ventures_present_cb', function()
    draw_gui();

    if zoning and not zone_loaded and os.clock() - zone_entry_time > 30 then
        zoning = false;
        zone_loaded = true;
        print(chat.header(addon.name) .. chat.warning('Fallback: Zone timer expired. Proceeding.'));
        send_ventures_command();
        return;
    end

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
