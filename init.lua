local S = core.get_translator(core.get_current_modname())

local rules_path = core.get_worldpath() .. "/rules.txt"

local no_interact_msg =
    S("You must agree to the rules to gain the privilege 'interact'.") .. " " ..
    S("Use /rules when you reconsider.")

local interact_msg =
    S("Thank you for agreeing to the rules.") .. " " ..
    S("You now have the privilege 'interact'.")

local function set_interact_priv(player, enabled)
    local name = player:get_player_name()
    local privs = core.get_player_privs(name)

    if enabled then
        privs.interact = true
    else
        privs.interact = nil
    end

    core.set_player_privs(name, privs)
end

local function has_accepted_rules(player)
    local meta = player:get_meta()
    return meta:get_string("has_accepted_rules") == "true"
end

local function accept_rules(player)
    local meta = player:get_meta()
    meta:set_string("has_accepted_rules", "true")
    set_interact_priv(player, true)
end

local function load_rules()
    local file, err = io.open(rules_path, "r")

    if file then
        local text = file:read("*a") or ""
        file:close()
        return text
    end

    core.log("warning", "[rules] Could not read rules.txt: " .. tostring(err))
    core.log("warning", "[rules] Creating an empty rules.txt")

    local newfile, err2 = io.open(rules_path, "w")
    if not newfile then
        core.log("error", "[rules] Failed to create rules.txt: " .. tostring(err2))
        return ""  -- fallback: empty rules
    end

    newfile:write("")  -- create empty file
    newfile:close()

    return ""
end

local rules_text = load_rules()

local function save_rules(text)
    local file, err = io.open(rules_path, "w")

    if not file then
        core.log("error", "[rules] Failed to open rules.txt: " .. tostring(err))
        return false
    end

    local ok, write_err = file:write(text)
    file:close()

    if not ok then
        core.log("error", "[rules] Error writing to rules.txt: " .. tostring(write_err))
        return false
    end

    rules_text = text

    return true
end

local pad, form_w, form_h, button_h = 0.375, 10, 13, 0.85
local txt_area_pad = 0.15
local content_w    = form_w - pad * 2
local content_h    = form_h - (button_h + pad * 3)

local function get_rules_formspec(player)
    local accepted = has_accepted_rules(player)
    local button_w = (form_w - (pad * 3)) / 2

    local fs = {
        "formspec_version[9]",
        string.format("size[%d,%d]", form_w, form_h),
        
        -- make sure new players can not close the formspec because they must either agree or disagree
        not accepted and "allow_close[false]" or "",
        
        string.format("box[%.3f,%.3f;%.3f,%.3f;#000000]", 
                pad, pad, content_w, content_h),

        string.format("hypertext[%.3f,%.3f;%.3f,%.3f;rules_hypertext;%s]",
            pad + txt_area_pad, pad + txt_area_pad,
            (form_w - (pad + txt_area_pad) * 2),
            (content_h - txt_area_pad * 2),
            core.formspec_escape(rules_text)),
    }

    local button_y = form_h - (button_h + pad)

    if accepted then
        local close_x = (form_w - button_w) / 2
        table.insert(fs,
            string.format("button_exit[%.3f,%.3f;%.3f,%.3f;rules_close;" .. S("Close") .. "]",
                close_x, button_y, button_w, button_h
        ))
    else
        table.insert(fs, "style[rules_disagree;bgcolor=red]")
        table.insert(fs,
            string.format("button[%.3f,%.3f;%.3f,%.3f;rules_disagree;" .. S("I do not agree!") .. "]",
                pad, button_y, button_w, button_h
        ))
        table.insert(fs, "style[rules_agree;bgcolor=green]")
        table.insert(fs,
            string.format("button[%.3f,%.3f;%.3f,%.3f;rules_agree;" .. S("I agree!") .. "]",
                (pad * 2 + button_w), button_y, button_w, button_h
        ))
    end

    return table.concat(fs)
end

local function get_setrules_formspec(current_text)
    local width      = (content_w * 2) + (pad * 3)
    local content_h2 = form_h - (button_h + pad * 3)
    local button_w   = 3

    local escaped = core.formspec_escape(current_text)

    local fs = {
        "formspec_version[9]",
        string.format("size[%.3f,%.3f]", width, form_h),
        "no_prepend[]",
        "bgcolor[#00000000]",
        string.format("background9[0,0;%.3f,%.3f;gui_formbg.png;true;10]", width, form_h),
        
        -- left textarea
        string.format("container[%.3f,%.3f]", pad, (button_h + pad * 2)),

        string.format("textarea[0,0;%.3f,%.3f;edit_rules_input;;%s]",
                content_w, content_h2, escaped),

        -- right preview box
        string.format("box[%.3f,0;%.3f,%.3f;#000000]",
                content_w + pad, content_w, content_h2),

        string.format("container[%.3f,%.3f]",
                content_w + pad + txt_area_pad, txt_area_pad),

        string.format("hypertext[0,0;%.3f,%.3f;edit_rules_preview;%s]",
                (content_w - txt_area_pad * 2),
                (content_h2 - txt_area_pad * 2), current_text),

        "container_end[]",
        "container_end[]",

        -- refresh button
        string.format("image_button[%.3f,%.3f;%.3f,%.3f;refresh.png;refresh_rules;]",
                (width - pad - button_w - pad - button_h), pad,
                button_h, button_h),

        -- save button
        "style[save_rules;bgcolor=green]",
        string.format("button[%.3f,%.3f;%.3f,%.3f;save_rules;" .. S("Save") .. "]",
                (width - pad - button_w), pad, button_w, button_h),

        -- cancel button
        string.format("button[%.3f,%.3f;%.3f,%.3f;cancel_rules;" .. S("Cancel") .. "]",
                pad, pad, button_w, button_h),
    }

    return table.concat(fs)
end

local function show_rules(player)
    local name = player:get_player_name()
    core.show_formspec(name, "rules:main", get_rules_formspec(player))
end

core.register_on_newplayer(function(player)
    set_interact_priv(player, false)
    core.after(0.75, function()
        show_rules(player)
    end)
end)

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    if not has_accepted_rules(player) then
        set_interact_priv(player, false)
        core.after(0.75, function()
            show_rules(player)
        end)
    end
end)

core.register_chatcommand("rules", {
    description = S("Show the server rules."),
    func = function(name)
        local player = core.get_player_by_name(name)
        if player then
            show_rules(player)
        end
    end
})

core.register_chatcommand("set_rules", {
    description = S("Edit the server rules."),
    privs = { server = true },
    func = function(name)
        core.show_formspec(name, "rules:set", get_setrules_formspec(rules_text))
    end
})

core.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    if formname == "rules:main" then
        if fields.rules_agree then
            accept_rules(player)
            core.chat_send_player(name, interact_msg)
            core.close_formspec(name, "rules:main")
            return
        end

        if fields.rules_disagree then
            core.chat_send_player(name, no_interact_msg)
            core.close_formspec(name, "rules:main")
            return
        end

        return
    end
        
    if formname == "rules:set" then
        -- refresh button: re‑open the formspec with updated preview
        if fields.refresh_rules and fields.edit_rules_input then
            core.show_formspec(name, "rules:set", get_setrules_formspec(fields.edit_rules_input))
            return
        end

        -- save button
        if fields.save_rules and fields.edit_rules_input then
            save_rules(fields.edit_rules_input)
            core.chat_send_player(name, S("Rules updated successfully."))
            core.close_formspec(name, "rules:set")
            return
        end

        -- cancel button
        if fields.cancel_rules then
            core.chat_send_player(name, S("Rules edit canceled."))
            core.close_formspec(name, "rules:set")
            return
        end
    end
end)
