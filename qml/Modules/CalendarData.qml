import QtQuick
import Quickshell
import Quickshell.Io

// Minimal RFC 5545 reader. Picks up every .ics file in the configured folders
// and flattens the VEVENTs into a day-keyed map that Calendar.qml renders.
//
// Deliberately dependency free: no vdirsyncer/khal/gcalcli required, though if
// you sync your calendars into ~/Calendar (the default) they just show up.
Item {
    id: data

    // Comma separated list of folders searched for *.ics
    property string folders: "~/Calendar,~/.local/share/calendar,~/Calendar/calendars"
    property int refreshMinutes: 30

    // Recurrences are expanded eagerly into byDay, so these bound that work:
    // how far past today to generate instances, and a hard per-event cap so a
    // pathological RRULE can't spin the parser forever.
    property int horizonMonths: 24
    property int pastMonths: 6
    property int maxOccurrences: 400

    // dayKey -> [{ summary, location, allDay, time, sortKey }]
    property var byDay: ({})

    readonly property int eventCount: {
        let n = 0;
        for (const k in data.byDay) {
            if (Object.prototype.hasOwnProperty.call(data.byDay, k))
                n += data.byDay[k].length;
        }
        return n;
    }

    property string lastError: ""

    Process {
        id: loader

        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: data.parse(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim().length > 0) data.lastError = this.text.trim()
        }
    }

    Timer {
        interval: Math.max(1, data.refreshMinutes) * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: data.reload()
    }

    // ------------------------------------------------ loading

    function reload() {
        const list = [];
        const raw = data.folders.split(",");
        for (let i = 0; i < raw.length; i++) {
            const trimmed = raw[i].trim();
            if (trimmed.length > 0)
                list.push("'" + trimmed.replace(/'/g, "'\\''") + "'");
        }
        if (list.length === 0) {
            loader.running = false;
            return;
        }
        loader.command = ["sh", "-c", "cat " + list.map(d => d + "/*.ics").join(" ") + " 2>/dev/null"];
        loader.running = true;
    }

    // ------------------------------------------------ parsing

    // Local-date day number, so events line up with the rendered grid no
    // matter which timezone the .ics was written in.
    function dayKey(y, m, d) {
        return Math.round(Date.UTC(y, m, d) / 86400000);
    }

    function keyOfDate(date) {
        return dayKey(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function parseStart(line) {
        const sep = line.indexOf(":");
        if (sep < 0)
            return null;
        const head = line.slice(0, sep);
        const value = line.slice(sep + 1).trim();
        const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(value);
        if (!m)
            return null;
        const y = parseInt(m[1]);
        const mo = parseInt(m[2]) - 1;
        const d = parseInt(m[3]);
        if (!m[4]) {
            // VALUE=DATE, or a date-only DTSTART: all-day event.
            return {
                allDay: true,
                time: new Date(y, mo, d, 0, 0, 0),
                minutes: 0
            };
        }
        const hh = parseInt(m[4]);
        const mi = parseInt(m[5]);
        if (m[7]) {
            // UTC stamp: convert into the local wall clock the grid uses.
            const utc = new Date(Date.UTC(y, mo, d, hh, mi, parseInt(m[6] || 0)));
            return {
                allDay: false,
                time: new Date(utc.getFullYear(), utc.getMonth(), utc.getDate(), utc.getHours(), utc.getMinutes()),
                minutes: utc.getHours() * 60 + utc.getMinutes()
            };
        }
        // Floating or TZID-locked local time, used verbatim.
        return {
            allDay: /VALUE=DATE/i.test(head),
            time: new Date(y, mo, d, hh, mi, parseInt(m[6] || 0)),
            minutes: hh * 60 + mi
        };
    }

    // ------------------------------------------------ recurrence

    // FREQ/INTERVAL/COUNT/UNTIL/BYDAY. Enough for the recurrences calendars
    // actually use (daily, weekly, monthly, yearly); anything else falls back
    // to a single instance at DTSTART.
    function parseRrule(line) {
        const sep = line.indexOf(":");
        if (sep < 0)
            return null;
        const rule = {};
        const parts = line.slice(sep + 1).split(";");
        for (let i = 0; i < parts.length; i++) {
            const eq = parts[i].indexOf("=");
            if (eq < 0)
                continue;
            rule[parts[i].slice(0, eq).trim().toUpperCase()] =
                parts[i].slice(eq + 1).trim();
        }
        return rule.FREQ ? rule : null;
    }

    // RFC 5545 weekday codes mapped to JS getUTCDay() values.
    readonly property var weekdayCodes: ({ "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6, "SU": 0 })

    // Number of days since the epoch for a y/m/d triple, so day arithmetic can
    // use plain integer maths instead of Date's DST-aware setters.
    function daysFromYmd(y, m, d) {
        return Math.round(Date.UTC(y, m, d) / 86400000);
    }

    function ymdFromDays(days) {
        const t = new Date(days * 86400000);
        return [t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate()];
    }

    // Occurrence dates for one recurring event, in local wall-clock terms.
    function expandRrule(start, rule) {
        const freq = rule.FREQ.toUpperCase();
        const interval = Math.max(1, parseInt(rule.INTERVAL || "1", 10) || 1);
        const hasCount = rule.COUNT !== undefined;
        const hasUntil = rule.UNTIL !== undefined;
        const limit = hasCount ? parseInt(rule.COUNT, 10) : data.maxOccurrences;
        const hardCap = Math.min(data.maxOccurrences, limit > 0 ? limit : data.maxOccurrences);

        // UNTIL may be a bare date or a UTC stamp; both reduce to a day number.
        let until = null;
        if (hasUntil) {
            const u = parseStart("DTSTART:" + rule.UNTIL);
            if (u)
                until = daysFromYmd(u.time.getFullYear(), u.time.getMonth(), u.time.getDate());
        }

        const now = new Date();
        const horizon = new Date(now.getFullYear(), now.getMonth() + data.horizonMonths, now.getDate());
        // A rule that started years ago would burn the whole occurrence budget
        // on history nobody is looking at, so an open-ended rule skips
        // straight to the recent past.
        const windowStart = new Date(now.getFullYear(), now.getMonth() - data.pastMonths, now.getDate());
        const windowStartDay = daysFromYmd(windowStart.getFullYear(), windowStart.getMonth(), windowStart.getDate());

        const y0 = start.getFullYear();
        const m0 = start.getMonth();
        const d0 = start.getDate();
        const hh = start.getHours();
        const mi = start.getMinutes();
        const ss = start.getSeconds();
        const startDay = daysFromYmd(y0, m0, d0);
        const startDow = new Date(startDay * 86400000).getUTCDay();

        // Weekday list for a WEEKLY rule, defaulting to the start's weekday.
        let byDay = null;
        if (freq === "WEEKLY" && rule.BYDAY) {
            byDay = [];
            const tokens = rule.BYDAY.toUpperCase().split(",");
            for (let i = 0; i < tokens.length; i++) {
                const w = data.weekdayCodes[tokens[i].replace(/[^A-Z]/g, "")];
                if (w !== undefined)
                    byDay.push(w);
            }
            byDay.sort(function (a, b) { return a - b; });
            if (byDay.length === 0)
                byDay = null;
        }

        const out = [];
        // Returns false once generation should stop (past UNTIL, past the
        // horizon, or the occurrence budget is spent).
        const push = function (y, m, d) {
            const day = daysFromYmd(y, m, d);
            if (until !== null && day > until)
                return false;
            const when = new Date(y, m, d, hh, mi, ss);
            if (when > horizon)
                return false;
            out.push(when);
            return out.length < hardCap;
        };

        const skipForward = !hasCount && !hasUntil;

        if (freq === "DAILY") {
            const stride = interval;
            let i = skipForward ? Math.max(0, Math.ceil((windowStartDay - startDay) / stride)) : 0;
            while (push(y0, m0, d0 + i * stride))
                i += 1;
        } else if (freq === "WEEKLY") {
            // Walk week by week, emitting each requested weekday inside it.
            const stride = 7 * interval;
            let week = skipForward ? Math.max(0, Math.floor((windowStartDay - startDay) / stride)) : 0;
            const days = byDay || [startDow];
            while (week < hardCap) {
                // Sunday of this interval's week.
                const weekStart = startDay - startDow + week * stride;
                let keepGoing = true;
                for (let i = 0; i < days.length; i++) {
                    // weekStart is a Sunday, so the weekday is the offset.
                    const target = weekStart + days[i];
                    if (target < startDay)
                        continue;
                    const ymd = ymdFromDays(target);
                    if (!push(ymd[0], ymd[1], ymd[2])) {
                        keepGoing = false;
                        break;
                    }
                }
                if (!keepGoing || out.length >= hardCap)
                    break;
                week += 1;
            }
        } else if (freq === "MONTHLY" || freq === "YEARLY") {
            const months = freq === "YEARLY" ? 12 * interval : interval;
            // Approximate month length is fine for choosing a starting step.
            let step = skipForward
                ? Math.max(0, Math.floor((windowStartDay - startDay) / (30 * months)))
                : 0;
            while (step < hardCap) {
                const total = m0 + step * months;
                const y = y0 + Math.floor(total / 12);
                const m = ((total % 12) + 12) % 12;
                // Clamp so a 31st-of-the-month rule doesn't skip short months.
                const lastDay = new Date(y, m + 1, 0).getDate();
                if (!push(y, m, Math.min(d0, lastDay)))
                    break;
                step += 1;
            }
        } else {
            // Unknown FREQ: show the first instance only.
            push(y0, m0, d0);
        }

        return out;
    }

    // File one parsed VEVENT into the day-keyed map, expanding RRULE into
    // concrete instances as it goes.
    function addEvent(map, ev) {
        if (ev.rrule) {
            const occurrences = expandRrule(ev.time, ev.rrule);
            for (let i = 0; i < occurrences.length; i++) {
                const when = occurrences[i];
                const copy = {
                    summary: ev.summary,
                    location: ev.location,
                    allDay: ev.allDay,
                    time: when,
                    minutes: ev.allDay ? 0 : when.getHours() * 60 + when.getMinutes()
                };
                const key = keyOfDate(when);
                if (!map[key])
                    map[key] = [];
                map[key].push(copy);
            }
            return;
        }
        const key = keyOfDate(ev.time);
        if (!map[key])
            map[key] = [];
        map[key].push(ev);
    }

    function parse(raw) {
        if (!raw || raw.trim().length === 0) {
            data.byDay = ({});
            return;
        }
        // Undo RFC 5545 line folding first, otherwise long SUMMARY values get
        // split across lines and lost.
        const lines = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
        const flat = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if ((line.startsWith(" ") || line.startsWith("\t")) && flat.length > 0)
                flat[flat.length - 1] += line.slice(1);
            else
                flat.push(line);
        }

        const map = {};
        let current = null;

        for (let i = 0; i < flat.length; i++) {
            const line = flat[i];
            if (line.startsWith("BEGIN:VEVENT")) {
                current = {
                    summary: "", location: "", allDay: false,
                    time: null, minutes: 0, rrule: null, cancelled: false
                };
                continue;
            }
            if (line.startsWith("END:VEVENT")) {
                if (current && current.time !== null && !current.cancelled)
                    data.addEvent(map, current);
                current = null;
                continue;
            }
            if (!current)
                continue;

            const sep = line.indexOf(":");
            if (sep < 0)
                continue;
            const name = line.slice(0, sep).split(";")[0].toUpperCase();
            const value = line.slice(sep + 1).trim();

            if (name === "SUMMARY")
                current.summary = value;
            else if (name === "LOCATION")
                current.location = value;
            else if (name === "STATUS" && value.toUpperCase() === "CANCELLED")
                current.cancelled = true;
            else if (name === "RRULE" && current.rrule === null)
                current.rrule = parseRrule(line);
            else if (name === "DTSTART" && current.time === null) {
                const parsed = parseStart(line);
                if (parsed) {
                    current.allDay = parsed.allDay;
                    current.time = parsed.time;
                    current.minutes = parsed.minutes;
                }
            }
        }

        for (const key in map) {
            if (!Object.prototype.hasOwnProperty.call(map, key))
                continue;
            map[key].sort((a, b) => {
                if (a.allDay !== b.allDay)
                    return a.allDay ? -1 : 1;
                return a.minutes - b.minutes;
            });
        }

        data.byDay = map;
    }

    function eventsOn(key) {
        const list = data.byDay[key];
        return list ? list : [];
    }
}