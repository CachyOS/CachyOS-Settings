#!/usr/bin/env lua
local f, concat, sort = string.format, table.concat, table.sort
local found, uv = pcall(require, 'luv')

local function die(err, ...)
    print(err:format(...))
    os.exit(1)
end

if not found then
    die("lua-luv dependency is missing, please install it from repositories")
end

local function printf(pattern, ...)
    print(pattern:format(...))
end

-- Patterns
local pid_pattern = "[0-9]+"
local ksm_profit_pattern = "ksm_process_profit%s*([0-9]+)"
local vm_rss_pattern = "VmRSS:%s*([0-9]+)"
local vm_swap_pattern = "VmSwap:%s*([0-9]+)"

local function get_process_values(pid)
    local path = concat({ "/proc", pid, "status" }, "/")
    local file = io.open(path)

    if not file then
        return nil
    end

    local rss, swap
    local line = file:read()
    while line do
        if rss == nil then
            rss = line:match(vm_rss_pattern)
        elseif swap == nil then
            swap = line:match(vm_swap_pattern)
        else
            break
        end
        line = file:read()
    end
    file:close()
    return tonumber(rss), tonumber(swap)
end

local function get_process_ksm_profit(pid)
    local file = io.open(concat({ "/proc", pid, "ksm_stat" }, "/"))

    if not file then
        return 0
    end

    local stat = file:read("*a")
    local profit = stat:match(ksm_profit_pattern)

    file:close()

    if not profit then
        return 0
    end

    return tonumber(profit)
end

local function get_process_first_arg(pid)
    local file = io.open(concat({ "/proc", pid, "cmdline" }, "/"))

    if not file then
        return nil
    end

    local cmdline = file:read("*all")
    file:close()

    return cmdline:match("([^%z]+)")
end

local function convert_hashmap_table(map)
    local new_hashmap = {}
    for key, value in pairs(map) do
        new_hashmap[#new_hashmap + 1] = { value[1], value[2], value[3], key }
    end

    return new_hashmap
end

local function get_process_map(sort_by)
    local map = {}
    local processes = uv.fs_scandir("/proc")
    local pid, ftype = uv.fs_scandir_next(processes)

    while pid do
        if pid:match(pid_pattern) then
            if ftype == "directory" then
                local rss, swap = get_process_values(pid)
                local name = get_process_first_arg(pid)
                local ksm_profit = get_process_ksm_profit(pid)
                if name and rss then
                    if map[name] then
                        map[name][1] = map[name][1] + rss
                        map[name][2] = map[name][2] + swap
                        map[name][3] = map[name][3] + ksm_profit
                    else
                        map[name] = { rss, swap, ksm_profit }
                    end
                end
            end
        end
        pid, ftype = uv.fs_scandir_next(processes)
    end
    map = convert_hashmap_table(map)
    sort(map, function(a, b) return (a[sort_by] > b[sort_by]) end)
    return map
end

local function truncate(str)
    if #str > 25 then
        return str:sub(1, 25) .. "..."
    else
        return str
    end
end

local function get_filename(path)
    local lastSlash = path:find("/[^/]*$")
    if lastSlash then
        return path:sub(lastSlash + 1)
    else
        return path
    end
end

local function print_top(size, sort_by)
    local map = get_process_map(sort_by)
    printf("%-9s %35s %-9s %-s", "MEMORY", "Top " .. size .. " processes       ", "SWAP", "KSM")
    for i = 1, size do
        local entry = map[i]
        if entry then
            printf(
                "%-9s %-35s %-9s %-s",
                f("%.0f", entry[1] / 1024) .. "M",
                truncate(get_filename(entry[4])),
                f("%.0f", entry[2] / 1024) .. "M",
                f("%.0f", entry[3] / 1024 / 1024) .. "M"
            )
        end
    end
end

local function print_help()
    print([[
Shows names of the top 10 (or N) processes by memory consumption

Usage: topmem [OPTIONS] [N]

Arguments:
  [N] [default: 10]

Options:
  -s, --sort <TYPE>  Column to sort by [possible values: rss (default), swap, ksm]
  -h, --help         Show this message]]
)
    os.exit(0)
end

local function main()
    local sort_types = {
        ["rss"] = 1,
        ["swap"] = 2,
        ["ksm"] = 3
    }
    local sort_by = sort_types["rss"]
    local size
    local i = 1
    while i < #arg + 1 do
        if arg[i] == "--sort" or arg[i] == "-s" or arg[i]:match("--sort=*") then
            local criteria
            local shift = true

            for value in string.gmatch(arg[i], "([^=]+)") do
                if value ~= "--sort" and value ~= "-s" then
                    criteria = value
                    shift = false
                    break
                end
            end

            criteria = criteria or arg[i + 1]
            if not criteria then
                die("Column to sort by is not specified")
            end

            if not sort_types[criteria] then
                die("Wrong sorting criterion. Only available: rss, swap, ksm.")
            else
                sort_by = sort_types[criteria]
                if shift then
                    i = i + 1
                end
            end
        elseif arg[i] == "--help" or arg[i] == "-h" then
            print_help()
        else
            local status, value = pcall(tonumber, arg[i])
            if not status then
                die("The argument must be a number")
            else
                size = value
            end
        end
        i = i + 1
    end

    print_top(size or 10, sort_by)
end

main()
