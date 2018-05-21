/**
My i3status

protocol reference: https://i3wm.org/docs/i3bar-protocol.html
 */

import core.time : seconds;
import core.thread : Thread;

import std.algorithm : canFind, filter, fold, map, max, min, strip, sum;
import std.array : array;
import std.conv : to;
import std.file : readText, slurp;
import std.format : format;
import std.json : JSONValue, toJSON;
import std.process : pipeProcess, Redirect, wait;
import std.range : tail;
import std.stdio : File, writefln, writeln;
import std.string : chop, cmp, join, split, startsWith, strip;

enum
{
    GREEN = "#00FF00",
    PURPLE = "#FF00FF",
    RED = "#FF0000",
    TURQUOISE = "#00FFFF",
    YELLOW = "#FFFF00",
}

/**
battery information: https://www.kernel.org/doc/Documentation/power/power_supply_class.txt
 */
JSONValue batteryStatus()
{
    JSONValue jj = ["name": "battery"];
    auto energyFull = slurp!ulong("/sys/class/power_supply/BAT0/energy_now", "%d")[0];
    auto energyNow = slurp!ulong("/sys/class/power_supply/BAT0/energy_full", "%d")[0];
    auto powerNow = slurp!ulong("/sys/class/power_supply/BAT0/power_now", "%d")[0];
    auto capacity = slurp!ulong("/sys/class/power_supply/BAT0/capacity", "%d")[0];

    // charging
    if (powerNow == 0)
    {
        jj.object["color"] = GREEN;
        jj.object["full_text"] = format("\U0001F50B: %d %% (charging...)", capacity);
        return jj;
    }

    auto status = readText("/sys/class/power_supply/BAT0/status").chop();
    if (status.cmp("Discharging") == 0)
    {
        auto time = energyNow.to!double / powerNow.to!double;
        auto minutes = (time * 60).to!ulong;
        auto hours = minutes / 60;
        auto minute = minutes % 60;
        jj.object["color"] = capacity <= 20 ? RED : YELLOW;
        jj.object["full_text"] = format("\U0001F50B: %d h %d min.", hours, minute);
    }
    else // status == "Full"
    {
        jj.object["color"] = GREEN;
        jj.object["full_text"] = format("\U0001F50B: %d%%", capacity);
    }
    return jj;
}

JSONValue date()
{
    import std.datetime : Clock, DateTime;
    JSONValue jj = [
        "name": "date",
        "full_text": (cast(DateTime)Clock.currTime).toSimpleString()
        ];
    return jj;
}

JSONValue temperature()
{
    JSONValue jj = ["name": "temperature"];

    auto pipes = pipeProcess(["sensors", "-u"], Redirect.stdout);
    scope (exit) wait(pipes.pid);
    long[] temperatures;
    foreach (line; pipes.stdout.byLine)
    {
        if (line.startsWith("  temp"))
        {
            auto rest = line[6 .. $]
                .split("_")
                .map!(a => a.split(" "))
                .fold!((a, b) => a ~= b)
                .map!(a => a.split("."))
                .fold!((a, b) => a ~= b);
            if (rest[1].startsWith("input"))
            {
                temperatures ~= rest[2].to!long;
            }
        }
    }
    auto max = temperatures.fold!max();
    auto min = temperatures.fold!min();
    auto average = temperatures.sum().to!double / temperatures.length;

    if (max >= 61)
    {
        jj["color"] = RED;
    }
    else if (max >= 46)
    {
        jj["color"] = YELLOW;
    }
    jj["full_text"] = format("avg:%.2f\u2103 max:%d\u2103", average, max);
    return jj;
}

JSONValue volumeInfo()
{
    JSONValue jj = ["name": "volume"];

    auto pipes = pipeProcess(["amixer", "get", "Master"], Redirect.stdout);
    scope (exit) wait(pipes.pid);
    auto arr = pipes.stdout()
        .byLineCopy()
        .map!(a => a.strip())
        .array()
        .tail(1)[0]
        .split()
        .filter!(a => a.startsWith('[') && !a.canFind("dB"))
        .map!(a => a.strip!(a => a == '[' || a == ']'))
        .array();
    auto currVolume = arr[0].strip('%').to!uint;
    auto isMute = arr[1] == "off";

    if (isMute)
    {
        jj["color"] = YELLOW;
        jj["full_text"] = "\U0001F507";
    }
    else
    {
        jj["full_text"] = format("\U0001F508: %d%%", currVolume);
    }
    return jj;
}

JSONValue wirelessInfo()
{
    JSONValue jj = ["name": "wireless"];
    auto pipes = pipeProcess(["iwgetid", "-r"], Redirect.stdout);
    scope (exit) wait(pipes.pid);
    auto ssid = pipes.stdout.readln.chop;
    if (ssid.length == 0)
        return jj;
    foreach (line; File("/proc/net/wireless").byLineCopy())
    {
        if (line.startsWith("wlan") || line.startsWith("wlp"))
        {
            auto quality = line.split()[2].strip('.').to!uint;
            if (quality >= 95)
            {
                jj["color"] = GREEN;
            }
            else if (quality >= 50)
            {
                jj["color"] = YELLOW;
            }
            else
            {
                jj["color"] = RED;
            }
            jj["full_text"] = format("\U0001F4F6 %d", quality);
        }
    }
    return jj;
}

void main()
{
    writeln(`{"version": 1}`);
    writeln("[");
    writeln("[],");

    while (true)
    {
        JSONValue[] entries;
        entries ~= wirelessInfo();
        entries ~= temperature();
        entries ~= volumeInfo();
        entries ~= batteryStatus();
        entries ~= date();
        writefln(`[
%s
],`, entries.map!(a => a.toJSON).join(","));
        Thread.sleep(1.seconds);
    }
}
