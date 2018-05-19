/**
My i3status

protocol reference: https://i3wm.org/docs/i3bar-protocol.html
 */

import core.time : seconds;
import core.thread : Thread;

import std.algorithm : map;
import std.conv : to;
import std.file : readText, slurp;
import std.format : format;
import std.json : JSONValue, toJSON;
import std.stdio : writeln;
import std.string : chop, cmp, join;

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
JSONValue getBatteryStatus()
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
        jj.object["full_text"] = format("Battery: %d %% (charging...)", capacity);
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
        jj.object["full_text"] = format("Battery: %d h %d min.", hours, minute);
    }
    else // status == "Full"
    {
        jj.object["color"] = GREEN;
        jj.object["full_text"] = format("Battery: %d%%", capacity);
    }
    return jj;
}

JSONValue getDate()
{
    import std.datetime : Clock, DateTime;
    JSONValue jj = [
        "name": "date",
        "full_text": (cast(DateTime)Clock.currTime).toSimpleString()
        ];
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
        entries ~= getDate();
        writeln("[");
        entries.map!(a => a.toJSON)
            .join(",").writeln;
        writeln("],");
        Thread.sleep(5.seconds);
    }
}
