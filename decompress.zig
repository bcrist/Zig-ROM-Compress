pub fn decompress(input: []const u8, context: anytype) void {
    var data = input;

    var d: u32 = 0;
    var a: u32 = 0;

    while (data.len > 0) {
        const rec = Range.read(data);
        data = data[rec.bytes..];

        d += rec.offset;
        if (rec.offset > 0) {
            a = 0;
        }

        if (rec.count > 0) {
            context.data(d);

            var iter = Range_Iterator {
                .data = data,
                .ranges_remaining = rec.count,
            };
            while (iter.next()) |range| {
                a +%= range.offset;
                var count = range.count;
                while (count > 0) : (count -= 1) {
                    context.address(a);
                    a += 1;
                }
            }

            data = iter.data;
        }
    }
}

pub fn dump(input: []const u8, writer: std.io.AnyWriter) !void {
    var data = input;

    var d: u32 = 0;
    var a: u32 = 0;

    while (data.len > 0) {
        const rec = Range.read(data);
        data = data[rec.bytes..];

        try writer.print("D{}\n", .{ rec });

        d += rec.offset;
        if (rec.offset > 0) {
            a = 0;
        }

        if (rec.count > 0) {
            try writer.print("  D: 0x{X:0>8}\n", .{ d });

            var iter = Range_Iterator {
                .data = data,
                .ranges_remaining = rec.count,
            };
            while (iter.next()) |range| {
                try writer.print("    A{}\tA: [0x{X:0>8}:0x{X:0>8}]\n", .{ range, a +% range.offset, a +% range.offset +% range.count });
                a +%= range.offset;
            }

            data = iter.data;
        }
    }
}

pub const Range = struct {
    offset: u32,
    count: u32,
    bytes: u8,

    pub fn read(data: []const u8) Range {
        var r: Range = undefined;

        const initial = data[0];
        if ((initial & 1) == 0) {
            // ooooooo0
            r.bytes = 1;
            r.count = 1;
            r.offset = @as(u7, @truncate(initial >> 1));
        } else if ((initial & 2) == 0) {
            // ooonnn01 oooooooo
            const encoded_count: u3 = @truncate(initial >> 2);
            r.bytes = 2;
            r.count = if (encoded_count == 0) 256 else @as(u7, 1) << (encoded_count - 1);
            r.offset = bits.concat(.{
                data[1],
                @as(u3, @intCast(initial >> 5)),
            });
        } else if ((initial & 4) == 0) {
            switch (data[1]) {
                1 => {
                    // nnnnn011 00000001 nnnnnnnn oooooooo oooooooo
                    r.bytes = 5;
                    r.count = @as(u32, 2049) + bits.concat(.{
                        data[2],
                        @as(u5, @intCast(initial >> 3)),
                    });
                    r.offset = bits.concat(.{
                        data[3],
                        data[4],
                    });
                },
                5 => {
                    // nnnnn011 00000101 nnnnnnnn oooooooo oooooooo oooooooo
                    r.bytes = 6;
                    r.count = @as(u32, 9) + bits.concat(.{
                        data[2],
                        @as(u5, @intCast(initial >> 3)),
                    });
                    r.offset = bits.concat(.{
                        data[3],
                        data[4],
                        data[5],
                    });
                },
                13 => {
                    // ooooo011 00001101 nnnnnnnn nnnnnnnn nnnnnnnn nnnnnnnn
                    r.bytes = 6;
                    r.offset = initial >> 3;
                    r.count = bits.concat(.{
                        data[2],
                        data[3],
                        data[4],
                        data[5],
                    });
                },
                29 => {
                    // nnnnn011 00011101 oooooooo oooooooo oooooooo oooooooo
                    r.bytes = 6;
                    r.count = initial >> 3;
                    r.offset = bits.concat(.{
                        data[2],
                        data[3],
                        data[4],
                        data[5],
                    });
                },
                else => {
                    // ooooo011 nnnnnnnn
                    r.bytes = 2;
                    r.count = data[1] + @as(u32, 3);
                    r.offset = initial >> 3;
                },
            }
        } else if ((initial & 8) == 0) {
            // nnnn0111 oooooooo nnoooooo
            r.bytes = 3;
            r.count = @as(u32, 1) + bits.concat(.{
                @as(u4, @intCast(initial >> 4)),
                @as(u2, @intCast(data[2] >> 6)),
            });
            r.offset = bits.concat(.{
                data[1],
                @as(u6, @truncate(data[2])),
            });
        } else if ((initial & 16) == 0) {
            // nnn01111 nnnnnnnn oooooooo oooooooo
            r.bytes = 4;
            r.count = @as(u32, 1) + bits.concat(.{
                data[1],
                @as(u3, @intCast(initial >> 5)),
            });
            r.offset = bits.concat(.{
                data[2],
                data[3],
            });
        } else {
            // nnn11111 oooooooo oooooooo oooooooo
            r.bytes = 4;
            r.count = @as(u32, 1) + (initial >> 5);
            r.offset = bits.concat(.{
                data[1],
                data[2],
                data[3],
            });
        }

        return r;
    }

    pub fn format(self: Range, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("R{}[{}:{} ({})]", .{ self.bytes, self.offset, self.offset +% self.count, self.count });
    }
};

const Range_Iterator = struct {
    data: []const u8 = &[_]u8{},
    ranges_remaining: u32 = 0,

    fn next(self: *Range_Iterator) ?Range {
        if (self.ranges_remaining == 0) return null;
        const r = Range.read(self.data);
        self.data = self.data[r.bytes..];
        self.ranges_remaining -= 1;
        return r;
    }
};

const bits = @import("bits");
const std = @import("std");
