/**
My i3status bar

protocol reference: https://i3wm.org/docs/i3bar-protocol.html
 */

import core.time : seconds;
import core.thread : Thread;
import std.conv : to;
import std.file : readText;
import std.format : format;
import std.json : JSONValue, toJSON;
import std.stdio : writeln;
import std.string : chop, cmp;

enum
{
    GREEN = "#00FF00",
    PURPLE = "#FF00FF",
    RED = "#FF0000",
    TURQUOISE = "#00FFFF",
    YELLOW = "#FFFF00",
}

JSONValue getBatteryStatus()
{
    JSONValue jj = ["name": "battery"];
    auto energy = readText("/sys/class/power_supply/BAT0/energy_now").chop().to!ulong;
    auto power = readText("/sys/class/power_supply/BAT0/power_now").chop().to!ulong;

    if (power == 0)
    {
        jj.object["color"] = GREEN;
        jj.object["full_text"] = "Battery:charging..";
        return jj;
    }

    auto status = readText("/sys/class/power_supply/BAT0/status").chop();
    if (status.cmp("Discharging"))
    {
        auto time = energy.to!double / power.to!double;
        auto minutes = (time * 60).to!ulong;
        auto hours = minutes / 60;
        auto minute = minutes % 60;
        jj.object["color"] = YELLOW;
        jj.object["full_text"] = format("Battery: %d h %d min.", hours, minute);
        return jj;
    }
    jj.object["color"] = GREEN;
    jj.object["full_text"] = "Battery:full";
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
        entries ~= getBatteryStatus();
        writeln("[");
        foreach (entry; entries)
            writeln(entry.toJSON);
        writeln("],");
        Thread.sleep(5.seconds);
    }
}
